import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/viagem.dart';
import '../services/api_service.dart';
import '../services/realtime_service.dart';
import '../theme/app_theme.dart';
import '../services/trip_preferences_service.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/timeline_mobility_segment.dart';
import '../widgets/app_screen_chrome.dart';
import 'suggestions_bloco_screen.dart';
import 'timeline_block_form_screen.dart';
import 'mobility_preferences_screen.dart';

class TimelineScreen extends StatefulWidget {
  final ApiService api;
  final Viagem viagem;
  final RealtimeService realtime;

  const TimelineScreen({super.key, required this.api, required this.viagem, required this.realtime});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  List<Map<String, dynamic>> blocks = [];
  bool loading = true;
  StreamSubscription<RealtimePush>? _realtimeSub;
  List<Map<String, dynamic>> _cidadesCache = [];
  Map<String, dynamic>? _prefs;
  String? _selectedDateBr;

  bool _sameViagem(Map<String, dynamic>? map) {
    if (map == null || !map.containsKey('viagem_id')) return false;
    final v = map['viagem_id'];
    final id = widget.viagem.id;
    return v == id || v.toString() == id.toString();
  }

  /// Converte API (ISO, yyyy-mm-dd ou dd/mm/aaaa) para exibicao dd/mm/aaaa.
  String _toDisplayDateBr(dynamic value) {
    final s = (value ?? '').toString().trim();
    if (s.isEmpty) return '';
    final br = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');
    if (br.hasMatch(s)) return s;
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');
    final m = iso.firstMatch(s);
    if (m != null) {
      return '${m.group(3)}/${m.group(2)}/${m.group(1)}';
    }
    final parsed = DateTime.tryParse(s);
    if (parsed != null) {
      final d = parsed.day.toString().padLeft(2, '0');
      final mo = parsed.month.toString().padLeft(2, '0');
      final y = parsed.year.toString();
      return '$d/$mo/$y';
    }
    return s;
  }

  String _formatTime(dynamic value) {
    final text = (value ?? '').toString();
    if (text.isEmpty) return '';
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(text.trim());
    if (m != null) {
      final hh = m.group(1)!.padLeft(2, '0');
      return '$hh:${m.group(2)}';
    }
    if (text.length >= 5) return text.substring(0, 5);
    return text;
  }

  (double, double)? _anchorLatLng() {
    double sumLat = 0, sumLng = 0;
    var n = 0;
    for (final c in _cidadesCache) {
      final lat = c['latitude'];
      final lng = c['longitude'];
      if (lat == null || lng == null) continue;
      final la = lat is num ? lat.toDouble() : double.tryParse(lat.toString());
      final ln = lng is num ? lng.toDouble() : double.tryParse(lng.toString());
      if (la == null || ln == null) continue;
      sumLat += la;
      sumLng += ln;
      n++;
    }
    if (n == 0) return null;
    return (sumLat / n, sumLng / n);
  }

  String _mobilityPref() {
    final m = _prefs?['mobility_pref']?.toString().trim();
    if (m == null || m.isEmpty) return 'driving';
    if (m == 'walking' || m == 'transit' || m == 'driving') return m;
    return 'driving';
  }

  /// Deslocamento só entre dois eventos fixos; blocos de tempo livre não disparam Places/Distance Matrix.
  bool _mobilidadeEntreEventosFixos(Map<String, dynamic> a, Map<String, dynamic> b) {
    final ambosFixos = a['tipo']?.toString() == 'Evento Fixo' && b['tipo']?.toString() == 'Evento Fixo';
    if (!ambosFixos) return false;
    final localA = (a['local'] ?? '').toString().trim();
    final localB = (b['local'] ?? '').toString().trim();
    return localA.isNotEmpty && localB.isNotEmpty;
  }

  int _compareBlockTime(Map<String, dynamic> a, Map<String, dynamic> b) {
    final ta = _formatTime(a['hora_inicio']);
    final tb = _formatTime(b['hora_inicio']);
    final ida = a['id'];
    final idb = b['id'];
    int idCmp() {
      final ia = ida is int ? ida : int.tryParse('$ida') ?? 0;
      final ib = idb is int ? idb : int.tryParse('$idb') ?? 0;
      return ia.compareTo(ib);
    }

    if (ta.isEmpty && tb.isEmpty) return idCmp();
    if (ta.isEmpty) return 1;
    if (tb.isEmpty) return -1;
    final c = ta.compareTo(tb);
    if (c != 0) return c;
    return idCmp();
  }

  List<Map<String, dynamic>> _sortedDayBlocks(List<Map<String, dynamic>> day) {
    final copy = List<Map<String, dynamic>>.from(day);
    copy.sort(_compareBlockTime);
    return copy;
  }

  Future<void> _openMobilidadePreferencias() async {
    final svc = TripPreferencesService(widget.api);
    final current = _prefs ?? await svc.get(widget.viagem.id);
    var modo = (current?['mobility_pref'] ?? 'driving').toString().trim();
    if (modo != 'walking' && modo != 'transit' && modo != 'driving') modo = 'driving';

    if (!mounted) return;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MobilityPreferencesScreen(api: widget.api, viagemId: widget.viagem.id, current: current),
      ),
    );
    if (ok == true) {
      final p = await svc.get(widget.viagem.id);
      if (mounted) setState(() => _prefs = p);
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupByDate(List<Map<String, dynamic>> list) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final block in list) {
      final raw = block['data'];
      final date = _toDisplayDateBr(raw);
      final key = date.isEmpty ? 'Sem data' : date;
      grouped.putIfAbsent(key, () => []).add(block);
    }
    return grouped;
  }

  DateTime? _parseApiDateOnly(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return null;
    final br = RegExp(r'^(\d{2})\/(\d{2})\/(\d{4})$').firstMatch(raw);
    if (br != null) {
      final dt = DateTime.tryParse('${br.group(3)}-${br.group(2)}-${br.group(1)}');
      if (dt != null) return DateTime(dt.year, dt.month, dt.day);
    }
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
    if (iso == null) return null;
    final dt = DateTime.tryParse('${iso.group(1)}-${iso.group(2)}-${iso.group(3)}');
    if (dt == null) return null;
    return DateTime(dt.year, dt.month, dt.day);
  }

  String _dateBr(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  List<String> _travelDateKeys() {
    final ini = _parseApiDateOnly(widget.viagem.dataInicial);
    final fim = _parseApiDateOnly(widget.viagem.dataFinal);
    if (ini == null || fim == null || fim.isBefore(ini)) return const [];
    final out = <String>[];
    var cur = ini;
    while (!cur.isAfter(fim)) {
      out.add(_dateBr(cur));
      cur = cur.add(const Duration(days: 1));
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    load();
    _realtimeSub = widget.realtime.pushes.listen((push) {
      if (!mounted) return;
      if (!push.event.startsWith('timeline_block')) return;
      final raw = push.payload;
      final map = raw is Map<String, dynamic> ? raw : (raw is Map ? Map<String, dynamic>.from(raw) : null);
      if (_sameViagem(map)) load();
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<void> gerarTempoLivrePorDia() async {
    try {
      final raw = await widget.api.postRequest('/api/timeline/${widget.viagem.id}/gerar-tempo-livre-dias', {});
      if (!mounted) return;
      final map = raw is Map ? Map<String, dynamic>.from(raw) : null;
      final n = map?['criados'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(n != null ? '$n evento(s) de Tempo Livre gerado(s).' : 'Geração concluída.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) await load();
    }
  }

  Future<void> load() async {
    setState(() => loading = true);
    final data = await widget.api.getRequest('/api/timeline/${widget.viagem.id}') as List<dynamic>;
    blocks = data.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      m['data'] = _toDisplayDateBr(m['data']);
      m['hora_inicio'] = _formatTime(m['hora_inicio']);
      m['hora_fim'] = _formatTime(m['hora_fim']);
      return m;
    }).toList();
    try {
      final rawC = await widget.api.getRequest('/api/viagens/cidades/${widget.viagem.id}') as List<dynamic>;
      _cidadesCache = rawC.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      _cidadesCache = [];
    }
    try {
      _prefs = await TripPreferencesService(widget.api).get(widget.viagem.id);
    } catch (_) {
      _prefs = null;
    }
    if (mounted) {
      final travelDays = _travelDateKeys();
      final currentSelected = _selectedDateBr;
      String? nextSelected = currentSelected;
      if (travelDays.isNotEmpty) {
        if (currentSelected == null || !travelDays.contains(currentSelected)) {
          nextSelected = travelDays.first;
        }
      } else {
        nextSelected = null;
      }
      setState(() {
        _selectedDateBr = nextSelected;
        loading = false;
      });
    }
  }

  Future<void> openForm({Map<String, dynamic>? item}) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TimelineBlockFormScreen(
          api: widget.api,
          viagemId: widget.viagem.id,
          viagemDataInicial: widget.viagem.dataInicial,
          viagemDataFinal: widget.viagem.dataFinal,
          item: item,
        ),
      ),
    );
    if (ok == true && mounted) {
      await load();
    }
  }

  Future<void> remove(int id) async {
    await widget.api.deleteRequest('/api/timeline/item/$id');
    await load();
  }

  Uri? _normalizeLink(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(text);
    final candidate = hasScheme ? text : 'https://$text';
    return Uri.tryParse(candidate);
  }

  Future<void> _openEventLink(String raw) async {
    final uri = _normalizeLink(raw);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link inválido para abrir.')),
      );
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o link.')),
      );
    }
  }

  Color badgeColor(String type) {
    return type == 'Tempo Livre' ? AppColors.accentOrange : AppColors.primaryBlue;
  }

  Widget _blocoCard(Map<String, dynamic> block) {
    final type = (block['tipo'] ?? '').toString();
    final passeioId = block['passeio_id'];
    final isLinkedToPasseio = passeioId != null && passeioId.toString().trim().isNotEmpty;
    final start = _formatTime(block['hora_inicio']);
    final end = _formatTime(block['hora_fim']);
    final local = (block['local'] ?? '').toString();
    final link = (block['link_url'] ?? '').toString();
    final desc = (block['descricao'] ?? '').toString();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (block['titulo'] ?? '').toString(),
                  style: const TextStyle(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor(type),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(type, style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
          if (isLinkedToPasseio) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF10B981), width: 1),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.link_rounded, size: 14, color: Color(0xFF047857)),
                  SizedBox(width: 6),
                  Text(
                    'Vinculado a passeio',
                    style: TextStyle(
                      color: Color(0xFF047857),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text('${start.isNotEmpty ? start : '--:--'}${end.isNotEmpty ? ' - $end' : ''}'),
          if (local.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Local: $local'),
          ],
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(desc),
          ],
          if (link.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _openEventLink(link),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Abrir link do evento'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
            ),
          ],
          if (type == 'Tempo Livre') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final bid = block['id'];
                  final id = bid is int ? bid : int.tryParse('$bid') ?? 0;
                  final changed = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SuggestionsBlocoScreen(
                        api: widget.api,
                        viagem: widget.viagem,
                        blocoId: id,
                      ),
                    ),
                  );
                  if (changed == true && mounted) await load();
                },
                icon: const Icon(Icons.lightbulb_outline, color: AppColors.accentOrange),
                label: const Text('Ver sugestões da wishlist'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryBlue,
                  side: const BorderSide(color: AppColors.accentOrange),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: 'Editar',
                onPressed: () => openForm(item: block),
                icon: const Icon(Icons.edit_outlined, color: AppColors.accentOrange),
              ),
              IconButton(
                tooltip: 'Excluir',
                onPressed: () {
                  final bid = block['id'];
                  final id = bid is int ? bid : int.tryParse('$bid') ?? 0;
                  remove(id);
                },
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.errorRed),
              ),
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDate(blocks);
    final travelDays = _travelDateKeys();
    final selectedDay = _selectedDateBr ?? (travelDays.isNotEmpty ? travelDays.first : null);
    final dayEventsRaw = selectedDay == null ? const <Map<String, dynamic>>[] : (grouped[selectedDay] ?? const <Map<String, dynamic>>[]);
    final dayEvents = _sortedDayBlocks(List<Map<String, dynamic>>.from(dayEventsRaw));
    final anchor = _anchorLatLng();

    return Scaffold(
      appBar: AppScreenChrome.appBar(
        context,
        title: 'Eventos da Viagem',
        actions: [
          IconButton(
            tooltip: 'Modal de deslocamento preferido (carro, a pé, transporte)',
            onPressed: loading ? null : _openMobilidadePreferencias,
            icon: const Icon(Icons.alt_route_rounded, color: AppColors.primaryBlue),
          ),
          IconButton(
            tooltip: 'Gerar bloco Tempo livre para cada dia da viagem',
            onPressed: loading ? null : gerarTempoLivrePorDia,
            icon: const Icon(Icons.calendar_month_outlined, color: AppColors.primaryBlue),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Novo evento',
        onPressed: () => openForm(),
        child: const Icon(Icons.add),
      ),
      body: AppGradientBackground(
        child: loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.accentOrange))
            : travelDays.isEmpty
                ? Padding(
                    padding: AppLayout.screenPadding,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timeline, size: 72, color: AppColors.primaryBlue),
                          const SizedBox(height: 12),
                          Text(
                            'Período da viagem inválido para listar os dias.',
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : Padding(
                    padding: AppLayout.screenPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Dia selecionado', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: selectedDay,
                          decoration: const InputDecoration(
                            labelText: 'Data dos eventos',
                            helperText: 'Mostra somente os eventos do dia selecionado',
                          ),
                          items: travelDays.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                          onChanged: (v) => setState(() => _selectedDateBr = v ?? travelDays.first),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: dayEvents.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.event_busy_outlined, size: 64, color: AppColors.primaryBlue),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Nenhum evento para ${selectedDay ?? 'este dia'}.',
                                        style: Theme.of(context).textTheme.titleLarge,
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 20),
                                      AppButton(label: 'Criar evento para este dia', onPressed: () => openForm()),
                                    ],
                                  ),
                                )
                              : ListView(
                                  children: [
                                    for (var bi = 0; bi < dayEvents.length; bi++) ...[
                                      _blocoCard(dayEvents[bi]),
                                      if (bi < dayEvents.length - 1 &&
                                          _mobilidadeEntreEventosFixos(dayEvents[bi], dayEvents[bi + 1]))
                                        TimelineMobilitySegment(
                                          api: widget.api,
                                          anchorLat: anchor?.$1,
                                          anchorLng: anchor?.$2,
                                          blocoOrigem: dayEvents[bi],
                                          blocoDestino: dayEvents[bi + 1],
                                          modoPreferido: _mobilityPref(),
                                        ),
                                    ],
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class DateTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 8) return oldValue;

    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      if ((i == 1 || i == 3) && i != digits.length - 1) {
        buffer.write('/');
      }
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class TimeTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 4) return oldValue;

    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      if (i == 1 && i != digits.length - 1) {
        buffer.write(':');
      }
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

