import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/viagem.dart';
import '../services/api_service.dart';
import '../services/realtime_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_screen_chrome.dart';
import 'city_detail_screen.dart';
import 'meio_transporte_form_screen_v2.dart';
import 'places_search_results_screen.dart';
import 'restaurante_search_screen.dart';
import 'timeline_screen.dart';
import 'wishlist_screen.dart';

enum DetailSection { cidades, transportes }

enum EntityType { cidade, hotel, restaurante, passeio }

double? _parseDecimalField(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  return double.tryParse(t.replaceAll(',', '.'));
}

class DateTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 8) return oldValue;
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      if ((i == 1 || i == 3) && i != digits.length - 1) buffer.write('/');
    }
    final text = buffer.toString();
    return TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

class TimeTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
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

class TripDetailScreen extends StatefulWidget {
  final ApiService api;
  final Viagem viagem;
  final RealtimeService realtime;
  const TripDetailScreen(
      {super.key,
      required this.api,
      required this.viagem,
      required this.realtime});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  DetailSection selected = DetailSection.cidades;
  List<Map<String, dynamic>> cidades = [];
  List<Map<String, dynamic>> _meiosTransporte = [];
  String _filtroTipoTransporte = 'todos';
  String _filtroCiaAerea = 'todas';
  String? _transportesLoadError;
  bool loading = true;
  static const List<String> _ciasAereasFiltro = <String>[
    'Air Canada',
    'Air France',
    'American Airlines',
    'Azul',
    'British Airways',
    'Copa Airlines',
    'Emirates',
    'Gol',
    'Iberia',
    'Ita Airways',
    'KLM',
    'Latam',
    'Lufthansa',
    'Qantas',
    'Qatar',
    'Swiss',
    'TAP',
    'Turkish Airlines',
    'United',
    'Outras',
  ];

  StreamSubscription<RealtimePush>? _realtimeSub;

  Future<void> _openMembersDialog() async {
    final emailCtrl = TextEditingController();
    String role = 'viewer';
    bool loadingMembers = true;
    bool inviting = false;
    List<Map<String, dynamic>> members = [];
    String? loadError;

    Future<void> loadMembers(StateSetter setModalState) async {
      setModalState(() {
        loadingMembers = true;
        loadError = null;
      });
      try {
        final data = await widget.api
                .getRequest('/api/viagens/${widget.viagem.id}/members')
            as List<dynamic>;
        members = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (e) {
        loadError = 'Falha ao carregar membros.';
      } finally {
        setModalState(() => loadingMembers = false);
      }
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          if (loadingMembers && members.isEmpty && loadError == null) {
            loadMembers(setModalState);
          }
          return AlertDialog(
            title: const Text('Perfis da viagem'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Convide outro perfil para esta viagem',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBlue),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                          labelText: 'E-mail do convidado'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      items: const [
                        DropdownMenuItem(
                            value: 'viewer',
                            child: Text('Viewer (somente leitura)')),
                        DropdownMenuItem(
                            value: 'editor',
                            child: Text('Editor (pode editar)')),
                      ],
                      onChanged: (v) =>
                          setModalState(() => role = v ?? 'viewer'),
                      decoration: const InputDecoration(labelText: 'Papel'),
                    ),
                    const SizedBox(height: 10),
                    AppButton(
                      label: inviting ? 'Enviando...' : 'Enviar convite',
                      onPressed: inviting
                          ? null
                          : () async {
                              final email = emailCtrl.text.trim();
                              if (email.isEmpty) return;
                              setModalState(() => inviting = true);
                              try {
                                await widget.api.postRequest(
                                    '/api/viagens/${widget.viagem.id}/members/invite',
                                    {
                                      'email': email,
                                      'role': role,
                                    });
                                if (!mounted) return;
                                emailCtrl.clear();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Convite enviado com sucesso.')),
                                );
                                await loadMembers(setModalState);
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Erro: $e')));
                              } finally {
                                setModalState(() => inviting = false);
                              }
                            },
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Membros atuais',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBlue),
                    ),
                    const SizedBox(height: 8),
                    if (loadingMembers)
                      const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.accentOrange))
                    else if (loadError != null)
                      Text(loadError!,
                          style: const TextStyle(color: AppColors.errorRed))
                    else if (members.isEmpty)
                      const Text('Nenhum perfil vinculado ainda.')
                    else
                      ...members.map((m) {
                        final nome = (m['nome'] ?? '').toString();
                        final email = (m['email'] ?? '').toString();
                        final memberRole = (m['role'] ?? '').toString();
                        final status = (m['status'] ?? '').toString();
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(nome.isEmpty ? email : nome),
                          subtitle: Text(email),
                          trailing: Text(
                            '${memberRole.toUpperCase()} · ${status.toUpperCase()}',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.neutralGray),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Fechar')),
            ],
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    loadAll();
    _realtimeSub = widget.realtime.pushes.listen(_onRealtimePush);
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  bool _sameId(dynamic a, dynamic b) {
    if (a == b) return true;
    if (a == null || b == null) return false;
    return a.toString() == b.toString();
  }

  void _onRealtimePush(RealtimePush p) {
    if (!mounted) return;
    final tid = widget.viagem.id;
    final raw = p.payload;
    Map<String, dynamic>? map;
    if (raw is Map<String, dynamic>) {
      map = raw;
    } else if (raw is Map) {
      map = Map<String, dynamic>.from(raw);
    }

    void notify(String msg) {
      loadAll();
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3)),
      );
    }

    switch (p.event) {
      case 'viagem_deleted':
        if (map != null && _sameId(map['id'], tid)) {
          Navigator.maybeOf(context)?.pop();
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
                content: Text('Esta viagem foi removida.'),
                behavior: SnackBarBehavior.floating),
          );
        }
        return;
      case 'viagem_updated':
        if (map != null && _sameId(map['id'], tid)) {
          notify('Viagem atualizada (tempo real).');
        }
        return;
      default:
        break;
    }

    if (map == null) return;
    final ev = p.event;

    if (map['viagem_id'] != null && _sameId(map['viagem_id'], tid)) {
      if (ev.startsWith('cidades_') ||
          ev.startsWith('timeline_block') ||
          ev.startsWith('wishlist') ||
          ev.startsWith('viagem_meios_transporte')) {
        notify('Dados atualizados (tempo real).');
        return;
      }
    }

    final cid = map['cidade_id'];
    if (cid != null) {
      final inTrip = cidades.any((c) => _sameId(c['id'], cid));
      if (inTrip &&
          (ev.startsWith('hoteis_') ||
              ev.startsWith('restaurantes_') ||
              ev.startsWith('passeios_'))) {
        notify('Dados atualizados (tempo real).');
      }
    }
  }

  String asText(dynamic value) => value == null ? '' : value.toString();

  String _tipoTransporteLabel(String? t) {
    switch (t) {
      case 'voo':
        return 'Voo';
      case 'carro':
        return 'Carro';
      case 'trem':
        return 'Trem';
      default:
        return t ?? '—';
    }
  }

  IconData _tipoTransporteIcon(String? t) {
    switch (t) {
      case 'voo':
        return Icons.flight_takeoff_rounded;
      case 'carro':
        return Icons.directions_car_outlined;
      case 'trem':
        return Icons.train_outlined;
      default:
        return Icons.commute_outlined;
    }
  }

  String _dataApiParaResumo(dynamic v) {
    if (v == null) return '';
    final s = v.toString();
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    if (m != null) return '${m[3]}/${m[2]}/${m[1]}';
    return '';
  }

  String _horaApiParaResumo(dynamic v) {
    if (v == null) return '';
    final s = v.toString();
    final parts = s.split(':');
    if (parts.length >= 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }
    return '';
  }

  /// Junta data e hora da API (`data_a`/`hora_a`) para uma linha legível.
  String _resumoDataHoraPar(Map<String, dynamic> m, String sufixo) {
    final d = _dataApiParaResumo(m['data_$sufixo']);
    final h = _horaApiParaResumo(m['hora_$sufixo']);
    if (d.isEmpty && h.isEmpty) {
      return '—';
    }
    if (d.isEmpty) {
      return h;
    }
    if (h.isEmpty) {
      return d;
    }
    return '$d $h';
  }

  String _classeLabel(String? c) {
    switch (c) {
      case 'economica':
        return 'Económica';
      case 'economica_premium':
        return 'Económica Premium';
      case 'executiva':
        return 'Executiva';
      case 'primeira':
        return 'Primeira';
      default:
        return c ?? '—';
    }
  }

  Future<void> loadAll() async {
    setState(() => loading = true);
    final cityData =
        await widget.api.getRequest('/api/viagens/cidades/${widget.viagem.id}')
            as List<dynamic>;
    cidades = cityData.map((e) => Map<String, dynamic>.from(e)).toList();
    try {
      final mtData = await widget.api
              .getRequest('/api/viagens/${widget.viagem.id}/meios-transporte')
          as List<dynamic>;
      _meiosTransporte =
          mtData.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _transportesLoadError = null;
    } catch (e) {
      _meiosTransporte = [];
      _transportesLoadError = 'Falha ao carregar transportes: $e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _confirmDeleteMeio(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover transporte'),
        content: const Text('Deseja remover este registo de transporte?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remover')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final id = item['id'];
      await widget.api.deleteRequest(
          '/api/viagens/${widget.viagem.id}/meios-transporte/$id');
      await loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível remover: $e')));
    }
  }

  Future<void> _openMeioTransporteEditor(Map<String, dynamic> m) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MeioTransporteFormScreenV2(
          api: widget.api,
          viagemId: widget.viagem.id,
          item: m,
        ),
      ),
    );
    if (changed == true && mounted) await loadAll();
  }

  Widget _buildTransportesPanel() {
    final filtradosPorTipo = _filtroTipoTransporte == 'todos'
        ? _meiosTransporte
        : _meiosTransporte
            .where((m) => (m['tipo'] ?? '').toString() == _filtroTipoTransporte)
            .toList();
    final transportesFiltrados =
        _filtroTipoTransporte == 'voo' && _filtroCiaAerea != 'todas'
            ? filtradosPorTipo
                .where((m) =>
                    (m['companhia'] ?? '').toString().trim() == _filtroCiaAerea)
                .toList()
            : filtradosPorTipo;

    return ListView(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _filtroTipoTransporte,
          decoration: const InputDecoration(
            labelText: 'Filtrar por tipo',
          ),
          items: const [
            DropdownMenuItem(value: 'todos', child: Text('Todos')),
            DropdownMenuItem(value: 'voo', child: Text('Voo')),
            DropdownMenuItem(value: 'carro', child: Text('Carro')),
            DropdownMenuItem(value: 'trem', child: Text('Trem')),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _filtroTipoTransporte = v;
              if (_filtroTipoTransporte != 'voo') {
                _filtroCiaAerea = 'todas';
              }
            });
          },
        ),
        if (_filtroTipoTransporte == 'voo') ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _filtroCiaAerea,
            decoration: const InputDecoration(
              labelText: 'Filtrar por companhia aérea',
            ),
            items: [
              const DropdownMenuItem(value: 'todas', child: Text('Todas')),
              ..._ciasAereasFiltro.map(
                (cia) => DropdownMenuItem(
                  value: cia,
                  child: Text(cia),
                ),
              ),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _filtroCiaAerea = v);
            },
          ),
        ],
        const SizedBox(height: 12),
        if (_transportesLoadError != null) ...[
          Text(
            _transportesLoadError!,
            style: const TextStyle(
              color: AppColors.errorRed,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
        ],
        const Text(
          'Edite pelo ícone de lápis (como nas cidades). Use + para adicionar outro meio de transporte.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 12),
        if (_meiosTransporte.isEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppColors.primaryBlue.withValues(alpha: 0.85)),
                  const SizedBox(height: 10),
                  const Text(
                    'Cadastre os meios de transporte desta viagem (voo, carro ou trem): companhia, locais, código da reserva, '
                    'horários (texto livre ou com calendário/relógio) e, para voo ou trem, os assentos por passageiro.',
                    style: TextStyle(color: Color(0xFF475569), height: 1.45),
                  ),
                ],
              ),
            ),
          ),
        if (transportesFiltrados.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Nenhum transporte encontrado para o filtro selecionado.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
        ...transportesFiltrados.map((m) {
          final tipo = m['tipo']?.toString();
          final comp = asText(m['companhia']);
          final cod = asText(m['codigo_localizador']);
          final obs = asText(m['observacoes']);
          final a = asText(m['ponto_a']);
          final b = asText(m['ponto_b']);
          final trechos = m['trechos'] is List
              ? (m['trechos'] as List)
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
              : <Map<String, dynamic>>[];
          final assentos = m['assentos'];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_tipoTransporteIcon(tipo),
                          color: AppColors.primaryBlue, size: 26),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _tipoTransporteLabel(tipo),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryBlue,
                              fontSize: 16),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Editar transporte',
                        onPressed: () => _openMeioTransporteEditor(
                            Map<String, dynamic>.from(m)),
                        icon: const Icon(Icons.edit_outlined,
                            color: AppColors.primaryBlue),
                      ),
                      IconButton(
                        tooltip: 'Remover',
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: AppColors.errorRed),
                        onPressed: () => _confirmDeleteMeio(m),
                      ),
                    ],
                  ),
                  if (comp.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Companhia: $comp',
                        style: const TextStyle(
                            color: Color(0xFF475569), fontSize: 13)),
                  ],
                  if (cod.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Localizador: $cod',
                        style: const TextStyle(
                            color: Color(0xFF475569), fontSize: 13)),
                  ],
                  if (obs.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Observações: $obs',
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (trechos.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text('$a → $b',
                        style: const TextStyle(
                            color: Color(0xFF334155),
                            fontSize: 14,
                            height: 1.35)),
                    const SizedBox(height: 6),
                    Text(
                      'Saída/retirada: ${_resumoDataHoraPar(m, 'a')} · Chegada/devolução: ${_resumoDataHoraPar(m, 'b')}',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.neutralGray.withValues(alpha: 0.95)),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Trechos',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...trechos.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final trecho = entry.value;
                      final tA = asText(trecho['ponto_a']);
                      final tB = asText(trecho['ponto_b']);
                      final saida = _resumoDataHoraPar(trecho, 'a');
                      final chegada = _resumoDataHoraPar(trecho, 'b');
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '$idx. $tA → $tB\nSaída/retirada: $saida · Chegada/devolução: $chegada',
                          style: const TextStyle(
                            color: Color(0xFF334155),
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      );
                    }),
                  ],
                  if (tipo == 'voo' || tipo == 'trem') ...[
                    if (trechos.isNotEmpty) ...[
                      ...trechos.asMap().entries.map((entry) {
                        final idx = entry.key + 1;
                        final trecho = entry.value;
                        final trechoAssentos = trecho['assentos'];
                        if (trechoAssentos is! List || trechoAssentos.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Assentos do trecho $idx',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryBlue,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ...trechoAssentos.map((raw) {
                                if (raw is! Map) return const SizedBox.shrink();
                                final am = Map<String, dynamic>.from(raw);
                                final nume = asText(am['numero_assento']);
                                final nom = asText(am['nome_passageiro']);
                                final cl = _classeLabel(am['classe']?.toString());
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '• $nume — $nom ($cl)',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      }),
                    ] else if (assentos is List && assentos.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Assentos',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...assentos.map((raw) {
                        if (raw is! Map) return const SizedBox.shrink();
                        final am = Map<String, dynamic>.from(raw);
                        final nume = asText(am['numero_assento']);
                        final nom = asText(am['nome_passageiro']);
                        final cl = _classeLabel(am['classe']?.toString());
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '• $nume — $nom ($cl)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF475569),
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 72),
      ],
    );
  }

  String formatDate(dynamic value) {
    final text = asText(value);
    if (RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(text)) return text;
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return text;
    final dd = parsed.day.toString().padLeft(2, '0');
    final mm = parsed.month.toString().padLeft(2, '0');
    final yyyy = parsed.year.toString();
    return '$dd/$mm/$yyyy';
  }

  Future<void> deleteByPath(String path) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: const Text('Tem certeza que deseja excluir este item?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Excluir')),
        ],
      ),
    );
    if (confirm != true) return;
    await widget.api.deleteRequest(path);
    await loadAll();
  }

  Future<void> openForm(EntityType type,
      {required int parentId,
      Map<String, dynamic>? item,
      Map<String, dynamic>? cidade}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EntityFormScreen(
          api: widget.api,
          type: type,
          parentId: parentId,
          item: item,
          cidade: cidade,
        ),
      ),
    );
    await loadAll();
  }

  Widget _cityListTile(Map<String, dynamic> cidade) {
    final cityId = cidade['id'] as int;
    final nome = asText(cidade['descricao']);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 23, 42, 0.07),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CityDetailScreen(
                          api: widget.api,
                          viagem: widget.viagem,
                          cidade: cidade,
                        ),
                      ),
                    );
                    if (mounted) await loadAll();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.place_rounded,
                            color: AppColors.primaryBlue, size: 26),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            nome,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Editar cidade',
              onPressed: () => openForm(EntityType.cidade,
                  parentId: widget.viagem.id, item: cidade),
              icon:
                  const Icon(Icons.edit_outlined, color: AppColors.primaryBlue),
            ),
            IconButton(
              tooltip: 'Excluir cidade',
              onPressed: () =>
                  deleteByPath('/api/viagens/cidades/item/$cityId'),
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.errorRed),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(gradient: AppGradients.screenBackground),
        child: SafeArea(
          child: loading
              ? const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.accentOrange))
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryBlue,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(18),
                          bottomRight: Radius.circular(18),
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(8, 6, 16, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconButton(
                            tooltip: 'Voltar',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_rounded,
                                color: Colors.white),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.viagem.descricao,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 22,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${formatDate(widget.viagem.dataInicial)} — ${formatDate(widget.viagem.dataFinal)} · ${widget.viagem.situacao}',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Wishlist',
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => WishlistScreen(
                                      api: widget.api,
                                      viagem: widget.viagem,
                                      realtime: widget.realtime),
                                ),
                              );
                            },
                            icon: const Icon(Icons.star_outline_rounded,
                                color: Colors.white),
                          ),
                          IconButton(
                            tooltip: 'Pesquisar restaurantes',
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RestauranteSearchScreen(
                                    api: widget.api,
                                    viagem: widget.viagem,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.restaurant_menu_rounded,
                                color: Colors.white),
                          ),
                          IconButton(
                            tooltip: 'Abrir timeline',
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TimelineScreen(
                                      api: widget.api,
                                      viagem: widget.viagem,
                                      realtime: widget.realtime),
                                ),
                              );
                            },
                            icon: const Icon(Icons.timeline_rounded,
                                color: Colors.white),
                          ),
                          IconButton(
                            tooltip: 'Perfis da viagem',
                            onPressed: _openMembersDialog,
                            icon: const Icon(Icons.group_outlined,
                                color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: AppDecor.whiteTopSheet(),
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SegmentedButton<DetailSection>(
                              style: SegmentedButton.styleFrom(
                                selectedBackgroundColor: AppColors.primaryBlue,
                                selectedForegroundColor: Colors.white,
                                foregroundColor: AppColors.primaryBlue,
                                side:
                                    const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              segments: const [
                                ButtonSegment(
                                  value: DetailSection.cidades,
                                  icon: Icon(Icons.location_city_outlined,
                                      size: 18),
                                  label: Text('Cidades'),
                                ),
                                ButtonSegment(
                                  value: DetailSection.transportes,
                                  icon: Icon(Icons.flight_takeoff_rounded,
                                      size: 18),
                                  label: Text('Transportes'),
                                ),
                              ],
                              selected: <DetailSection>{selected},
                              onSelectionChanged: (Set<DetailSection> next) {
                                if (next.isEmpty) return;
                                setState(() {
                                  selected = next.first;
                                  if (selected == DetailSection.transportes) {
                                    // Evita "sumiço" de itens por filtros antigos.
                                    _filtroTipoTransporte = 'todos';
                                    _filtroCiaAerea = 'todas';
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 14),
                            Expanded(
                              child: selected == DetailSection.transportes
                                  ? _buildTransportesPanel()
                                  : cidades.isEmpty
                                      ? Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.travel_explore_rounded,
                                                  size: 56,
                                                  color: AppColors.primaryBlue
                                                      .withValues(alpha: 0.35)),
                                              const SizedBox(height: 12),
                                              const Text(
                                                'Nenhuma cidade ainda.',
                                                style: TextStyle(
                                                    color: Color(0xFF64748B),
                                                    fontWeight:
                                                        FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        )
                                      : ListView(
                                          children: [
                                            ...cidades.map(_cityListTile),
                                            const SizedBox(height: 72),
                                          ],
                                        ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
      floatingActionButton: !loading
          ? switch (selected) {
              DetailSection.cidades => FloatingActionButton(
                  tooltip: 'Nova cidade',
                  onPressed: () =>
                      openForm(EntityType.cidade, parentId: widget.viagem.id),
                  child: const Icon(Icons.add_location_alt_rounded),
                ),
              DetailSection.transportes => FloatingActionButton(
                  tooltip: 'Novo transporte',
                  onPressed: () async {
                    final ok = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MeioTransporteFormScreenV2(
                          api: widget.api,
                          viagemId: widget.viagem.id,
                        ),
                      ),
                    );
                    if (ok == true && mounted) await loadAll();
                  },
                  child: const Icon(Icons.add_road_rounded),
                ),
            }
          : null,
    );
  }
}

class EntityFormScreen extends StatefulWidget {
  final ApiService api;
  final EntityType type;
  final int parentId;
  final Map<String, dynamic>? item;
  final Map<String, dynamic>? cidade;

  const EntityFormScreen({
    super.key,
    required this.api,
    required this.type,
    required this.parentId,
    this.item,
    this.cidade,
  });

  @override
  State<EntityFormScreen> createState() => _EntityFormScreenState();
}

class _EntityFormScreenState extends State<EntityFormScreen> {
  final nomeCtrl = TextEditingController();
  final descricaoCtrl = TextEditingController();
  final enderecoCtrl = TextEditingController();
  final obsCtrl = TextEditingController();
  final linkCtrl = TextEditingController();
  final latitudeCtrl = TextEditingController();
  final longitudeCtrl = TextEditingController();
  final valorCtrl = TextEditingController();
  static const List<String> _moedas = ['BRL', 'USD', 'EUR', 'GBP'];
  static const List<String> _tiposComida = [
    'Italiana',
    'Japonesa',
    'Steakhouse',
    'Mediterranea',
    'Internacional',
    'Asiatica',
    'Outras',
  ];
  static const List<String> _glutenOpcoes = [
    'Gluten Free',
    'Gluten Friendly',
    'Normal',
  ];
  static const List<String> _tiposPasseio = [
    'Museu',
    'Parque',
    'Cultural',
    'Ao ar Livre',
    'Observatório',
    'Corrida',
    'Praia',
    'Montanha',
    'Neve',
  ];
  String moeda = 'BRL';
  String tipoComida = 'Outras';
  String glutenOpcao = 'Normal';
  String tipoPasseioSel = 'Museu';
  final data1Ctrl = TextEditingController();
  final data2Ctrl = TextEditingController();
  final hora1Ctrl = TextEditingController();
  final hora2Ctrl = TextEditingController();
  String statusReserva = 'A Pagar';
  String situacaoPasseio = 'A Pagar';
  bool reservado = false;
  bool cancelamentoGratuito = false;
  bool permissaoCancelamento = false;
  bool loadingSearch = false;
  String? error;
  final FocusNode _saveButtonFocusNode = FocusNode();

  String _normalizeDateInputValue(dynamic value) {
    if (value == null) return '';
    final raw = value.toString().trim();
    if (raw.isEmpty) return '';
    final br = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(raw);
    if (br != null) return raw;
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
    if (iso != null) return '${iso.group(3)}/${iso.group(2)}/${iso.group(1)}';
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      final dd = parsed.day.toString().padLeft(2, '0');
      final mm = parsed.month.toString().padLeft(2, '0');
      final yyyy = parsed.year.toString();
      return '$dd/$mm/$yyyy';
    }
    return raw;
  }

  String _normalizeTimeInputValue(dynamic value) {
    if (value == null) return '';
    final raw = value.toString().trim();
    if (raw.isEmpty) return '';
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw);
    if (match != null) {
      final hh = match.group(1)!.padLeft(2, '0');
      final mm = match.group(2)!;
      return '$hh:$mm';
    }
    return raw;
  }

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item == null) return;
    nomeCtrl.text = (item['nome'] ?? '').toString();
    descricaoCtrl.text = (item['descricao'] ?? '').toString();
    enderecoCtrl.text = (item['endereco'] ?? '').toString();
    obsCtrl.text = (item['observacoes'] ?? '').toString();
    linkCtrl.text = (item['link_url'] ?? '').toString();
    latitudeCtrl.text = (item['latitude'] ?? '').toString();
    longitudeCtrl.text = (item['longitude'] ?? '').toString();
    valorCtrl.text = (item['valor'] ?? item['valor_medio'] ?? '').toString();
    final m = (item['moeda'] ?? 'BRL').toString().trim().toUpperCase();
    moeda = _moedas.contains(m) ? m : 'BRL';
    final tcRaw = (item['tipo_comida'] ?? '').toString().trim();
    tipoComida = _tiposComida.contains(tcRaw) ? tcRaw : 'Outras';
    final tpRaw = (item['tipo_passeio'] ?? '').toString().trim();
    tipoPasseioSel = _tiposPasseio.contains(tpRaw) ? tpRaw : 'Museu';
    final goRaw = (item['gluten_opcao'] ?? '').toString().trim();
    glutenOpcao = _glutenOpcoes.contains(goRaw) ? goRaw : 'Normal';
    data1Ctrl.text = _normalizeDateInputValue(item['data_checkin'] ?? item['data_reserva']);
    data2Ctrl.text = _normalizeDateInputValue(item['data_checkout']);
    hora1Ctrl.text = _normalizeTimeInputValue(item['hora_checkin'] ?? item['hora_reserva']);
    hora2Ctrl.text = _normalizeTimeInputValue(item['hora_checkout']);
    statusReserva = (item['status_reserva'] ?? 'A Pagar').toString();
    situacaoPasseio = (item['situacao'] ?? 'A Pagar').toString();
    reservado = item['reservado'] == true;
    cancelamentoGratuito = item['cancelamento_gratuito'] == true;
    permissaoCancelamento = item['permissao_cancelamento'] == true;
  }

  @override
  void dispose() {
    _saveButtonFocusNode.dispose();
    nomeCtrl.dispose();
    descricaoCtrl.dispose();
    enderecoCtrl.dispose();
    obsCtrl.dispose();
    linkCtrl.dispose();
    latitudeCtrl.dispose();
    longitudeCtrl.dispose();
    valorCtrl.dispose();
    data1Ctrl.dispose();
    data2Ctrl.dispose();
    hora1Ctrl.dispose();
    hora2Ctrl.dispose();
    super.dispose();
  }

  bool get isCidade => widget.type == EntityType.cidade;
  bool get isHotel => widget.type == EntityType.hotel;
  bool get isRestaurante => widget.type == EntityType.restaurante;
  bool get isPasseio => widget.type == EntityType.passeio;

  String get title {
    if (isCidade) return widget.item == null ? 'Nova Cidade' : 'Editar Cidade';
    if (isHotel) return widget.item == null ? 'Novo Hotel' : 'Editar Hotel';
    if (isRestaurante) {
      return widget.item == null ? 'Novo Restaurante' : 'Editar Restaurante';
    }
    return widget.item == null
        ? 'Novo Passeio/Ingresso'
        : 'Editar Passeio/Ingresso';
  }

  /// Query no padrão: tipo semântico (ex.: restaurant) + nome digitado + nome da cidade (contexto).
  String _buildPlacesQuery(
      String tipoKeyword, String namePart, String cityName) {
    return '$tipoKeyword $namePart $cityName'
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> searchGooglePlaces() async {
    if (widget.cidade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cidade não definida para esta tela.')),
      );
      return;
    }

    final cityName = (widget.cidade!['descricao'] ?? '').toString().trim();
    final namePart = nomeCtrl.text.trim();
    if (namePart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRestaurante
                ? 'Digite pelo menos parte do nome do restaurante.'
                : 'Digite pelo menos parte do nome do local.',
          ),
        ),
      );
      return;
    }

    final latRaw = (widget.cidade!['latitude'] ?? '').toString();
    final lngRaw = (widget.cidade!['longitude'] ?? '').toString();
    final lat = latRaw.isEmpty ? null : double.tryParse(latRaw);
    final lng = lngRaw.isEmpty ? null : double.tryParse(lngRaw);

    String? tipoLugar;
    late final String queryComposite;
    late final String resultsTitle;
    late final IconData thumbIcon;

    if (isRestaurante) {
      tipoLugar = 'restaurant';
      queryComposite = _buildPlacesQuery('restaurant', namePart, cityName);
      resultsTitle = 'Resultados — Restaurantes';
      thumbIcon = Icons.restaurant;
    } else if (isHotel) {
      tipoLugar = 'lodging';
      queryComposite = _buildPlacesQuery('lodging', namePart, cityName);
      resultsTitle = 'Resultados — Hotéis';
      thumbIcon = Icons.hotel;
    } else if (isPasseio) {
      tipoLugar = null;
      queryComposite = '$namePart $cityName'.replaceAll(RegExp(r'\s+'), ' ').trim();
      resultsTitle = 'Resultados — Passeios';
      thumbIcon = Icons.attractions;
    } else {
      return;
    }

    setState(() => loadingSearch = true);
    try {
      final body = <String, dynamic>{
        'query': queryComposite,
      };
      if (tipoLugar != null && tipoLugar.isNotEmpty) {
        body['tipo_lugar'] = tipoLugar;
      }
      if (lat != null) body['latitude'] = lat;
      if (lng != null) body['longitude'] = lng;

      final raw = await widget.api.postRequest('/api/places/search', body)
          as List<dynamic>;
      if (!mounted) return;
      setState(() => loadingSearch = false);

      final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      if (!mounted) return;
      final selected = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => PlacesSearchResultsScreen(
            title: resultsTitle,
            cidadeNome: cityName,
            queryUsada: queryComposite,
            resultados: list,
            placeholderIcon: thumbIcon,
          ),
        ),
      );
      if (selected == null || !mounted) return;
      setState(() {
        nomeCtrl.text = (selected['nome'] ?? '').toString();
        enderecoCtrl.text = (selected['endereco'] ?? '').toString();
        latitudeCtrl.text = (selected['latitude'] ?? '').toString();
        longitudeCtrl.text = (selected['longitude'] ?? '').toString();
      });
    } catch (e) {
      if (mounted) {
        setState(() => loadingSearch = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro na busca: $e')),
        );
      }
    }
  }

  Future<void> submit() async {
    if ((isCidade && descricaoCtrl.text.trim().isEmpty) ||
        (!isCidade && nomeCtrl.text.trim().isEmpty)) {
      setState(() => error = 'Preencha os campos obrigatórios.');
      return;
    }
    Map<String, dynamic> payload;
    String routeEntity;
    if (isCidade) {
      routeEntity = 'cidades';
      payload = {
        'descricao': descricaoCtrl.text.trim(),
        'latitude': latitudeCtrl.text.trim().isEmpty
            ? null
            : double.tryParse(latitudeCtrl.text.trim()),
        'longitude': longitudeCtrl.text.trim().isEmpty
            ? null
            : double.tryParse(longitudeCtrl.text.trim()),
      };
    } else if (isHotel) {
      routeEntity = 'hoteis';
      payload = {
        'nome': nomeCtrl.text.trim(),
        'data_checkin':
            data1Ctrl.text.trim().isEmpty ? null : data1Ctrl.text.trim(),
        'data_checkout':
            data2Ctrl.text.trim().isEmpty ? null : data2Ctrl.text.trim(),
        'endereco':
            enderecoCtrl.text.trim().isEmpty ? null : enderecoCtrl.text.trim(),
        'status_reserva': statusReserva,
        'hora_checkin':
            hora1Ctrl.text.trim().isEmpty ? null : hora1Ctrl.text.trim(),
        'hora_checkout':
            hora2Ctrl.text.trim().isEmpty ? null : hora2Ctrl.text.trim(),
        'cancelamento_gratuito': cancelamentoGratuito,
        'latitude': latitudeCtrl.text.trim().isEmpty
            ? null
            : double.tryParse(latitudeCtrl.text.trim()),
        'longitude': longitudeCtrl.text.trim().isEmpty
            ? null
            : double.tryParse(longitudeCtrl.text.trim()),
        'observacoes': obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim(),
      };
    } else if (isRestaurante) {
      routeEntity = 'restaurantes';
      payload = {
        'nome': nomeCtrl.text.trim(),
        'tipo_comida': tipoComida,
        'gluten_opcao': glutenOpcao,
        'valor_medio': _parseDecimalField(valorCtrl.text),
        'moeda': moeda,
        'endereco':
            enderecoCtrl.text.trim().isEmpty ? null : enderecoCtrl.text.trim(),
        'link_url': linkCtrl.text.trim().isEmpty ? null : linkCtrl.text.trim(),
        'reservado': reservado,
        'data_reserva': reservado
            ? (data1Ctrl.text.trim().isEmpty ? null : data1Ctrl.text.trim())
            : null,
        'hora_reserva': reservado
            ? (hora1Ctrl.text.trim().isEmpty ? null : hora1Ctrl.text.trim())
            : null,
        'latitude': latitudeCtrl.text.trim().isEmpty
            ? null
            : double.tryParse(latitudeCtrl.text.trim()),
        'longitude': longitudeCtrl.text.trim().isEmpty
            ? null
            : double.tryParse(longitudeCtrl.text.trim()),
        'observacoes': obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim(),
      };
    } else {
      routeEntity = 'passeios';
      payload = {
        'nome': nomeCtrl.text.trim(),
        'tipo_passeio': tipoPasseioSel,
        'valor': _parseDecimalField(valorCtrl.text),
        'moeda': moeda,
        'situacao': situacaoPasseio,
        'endereco':
            enderecoCtrl.text.trim().isEmpty ? null : enderecoCtrl.text.trim(),
        'reservado': reservado,
        'data_reserva': reservado
            ? (data1Ctrl.text.trim().isEmpty ? null : data1Ctrl.text.trim())
            : null,
        'hora_reserva': reservado
            ? (hora1Ctrl.text.trim().isEmpty ? null : hora1Ctrl.text.trim())
            : null,
        'latitude': latitudeCtrl.text.trim().isEmpty
            ? null
            : double.tryParse(latitudeCtrl.text.trim()),
        'longitude': longitudeCtrl.text.trim().isEmpty
            ? null
            : double.tryParse(longitudeCtrl.text.trim()),
        'permissao_cancelamento': permissaoCancelamento,
        'observacoes': obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim(),
      };
    }

    if (widget.item == null) {
      await widget.api
          .postRequest('/api/viagens/$routeEntity/${widget.parentId}', payload);
    } else {
      await widget.api.putRequest(
          '/api/viagens/$routeEntity/item/${widget.item!['id']}', payload);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppScreenChrome.appBar(context, title: title),
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.screenBackground),
        child: SafeArea(
          child: FocusTraversalGroup(
            child: Shortcuts(
              shortcuts: const <ShortcutActivator, Intent>{
                SingleActivator(LogicalKeyboardKey.enter): NextFocusIntent(),
              },
              child: Actions(
                actions: <Type, Action<Intent>>{
                  NextFocusIntent: NextFocusAction(),
                },
                child: SingleChildScrollView(
                  padding: AppLayout.screenPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.cidade != null) ...[
                        Text(
                          'Cidade: ${(widget.cidade!['descricao'] ?? '').toString()}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text('Dados', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      if (isCidade)
                        TextField(
                          controller: descricaoCtrl,
                          decoration: const InputDecoration(labelText: 'Descrição da cidade'),
                        )
                      else ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: nomeCtrl,
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                                decoration: const InputDecoration(labelText: 'Nome'),
                              ),
                            ),
                            if (isHotel || isRestaurante || isPasseio) ...[
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 46,
                                height: 46,
                                child: IconButton.filled(
                                  onPressed: loadingSearch ? null : searchGooglePlaces,
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.accentOrange,
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: loadingSearch
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Icon(Icons.search),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: enderecoCtrl,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                          decoration: const InputDecoration(labelText: 'Endereço completo'),
                        ),
                      ],
                      if (isHotel || isRestaurante || isPasseio) ...[
                        const SizedBox(height: 16),
                        Text('Valores e Reserva', style: Theme.of(context).textTheme.titleLarge),
                      ],
                      if (isHotel) ...[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          key: ValueKey<String>(statusReserva),
                          initialValue: statusReserva,
                          items: const [
                            DropdownMenuItem(value: 'A Pagar', child: Text('A Pagar')),
                            DropdownMenuItem(value: 'Pago', child: Text('Pago')),
                          ],
                          onChanged: (v) => setState(() => statusReserva = v ?? 'A Pagar'),
                          decoration: const InputDecoration(labelText: 'Status da reserva'),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: data1Ctrl,
                                inputFormatters: [DateTextInputFormatter()],
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                                decoration: const InputDecoration(labelText: 'Data check-in (DD/MM/AAAA)'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: hora1Ctrl,
                                inputFormatters: [TimeTextInputFormatter()],
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                                decoration: const InputDecoration(labelText: 'Hora check-in (HH:mm)'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: data2Ctrl,
                                inputFormatters: [DateTextInputFormatter()],
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                                decoration: const InputDecoration(labelText: 'Data check-out (DD/MM/AAAA)'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: hora2Ctrl,
                                inputFormatters: [TimeTextInputFormatter()],
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                                decoration: const InputDecoration(labelText: 'Hora check-out (HH:mm)'),
                              ),
                            ),
                          ],
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Cancelamento gratuito'),
                          value: cancelamentoGratuito,
                          onChanged: (v) => setState(() => cancelamentoGratuito = v),
                        ),
                      ],
                      if (isRestaurante) ...[
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: valorCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                                decoration: const InputDecoration(labelText: 'Valor Médio por Pessoa'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                key: ValueKey<String>(moeda),
                                initialValue: moeda,
                                items: _moedas.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                onChanged: (v) => setState(() => moeda = v ?? 'BRL'),
                                decoration: const InputDecoration(labelText: 'Moeda'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          key: ValueKey<String>(tipoComida),
                          initialValue: tipoComida,
                          items: _tiposComida.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (v) => setState(() => tipoComida = v ?? 'Outras'),
                          decoration: const InputDecoration(labelText: 'Tipo de comida'),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          key: ValueKey<String>(glutenOpcao),
                          initialValue: glutenOpcao,
                          items: _glutenOpcoes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (v) => setState(() => glutenOpcao = v ?? 'Normal'),
                          decoration: const InputDecoration(
                            labelText: 'Opção de glúten',
                            helperText: 'Gluten Free / Gluten Friendly / Normal',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: linkCtrl,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                          decoration: const InputDecoration(
                            labelText: 'Link do restaurante',
                            hintText: 'https://...',
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Mesa reservada?'),
                          value: reservado,
                          onChanged: (v) => setState(() => reservado = v),
                        ),
                        if (reservado) ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: data1Ctrl,
                            inputFormatters: [DateTextInputFormatter()],
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                            decoration: const InputDecoration(labelText: 'Data reserva (DD/MM/AAAA)'),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: hora1Ctrl,
                            inputFormatters: [TimeTextInputFormatter()],
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                            decoration: const InputDecoration(labelText: 'Hora reserva (HH:mm)'),
                          ),
                        ],
                      ],
                      if (isPasseio) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: valorCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]'))
                          ],
                          decoration: const InputDecoration(labelText: 'Valor'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey<String>('p_$moeda'),
                          initialValue: moeda,
                          items: _moedas
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) => setState(() => moeda = v ?? 'BRL'),
                          decoration: const InputDecoration(labelText: 'Moeda'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>(tipoPasseioSel),
                    initialValue: tipoPasseioSel,
                    items: _tiposPasseio
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => tipoPasseioSel = v ?? 'Museu'),
                    decoration:
                        const InputDecoration(labelText: 'Tipo de passeio'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>(situacaoPasseio),
                    initialValue: situacaoPasseio,
                    items: const [
                      DropdownMenuItem(
                          value: 'A Pagar', child: Text('A Pagar')),
                      DropdownMenuItem(
                          value: 'Pago Parcial', child: Text('Pago Parcial')),
                      DropdownMenuItem(value: 'Pago', child: Text('Pago')),
                      DropdownMenuItem(
                          value: 'Gratuito', child: Text('Gratuito')),
                    ],
                    onChanged: (v) =>
                        setState(() => situacaoPasseio = v ?? 'A Pagar'),
                    decoration: const InputDecoration(labelText: 'Situação'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Reservado'),
                    value: reservado,
                    onChanged: (v) => setState(() => reservado = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Permissão de cancelamento'),
                    value: permissaoCancelamento,
                    onChanged: (v) => setState(() => permissaoCancelamento = v),
                  ),
                  if (reservado) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: data1Ctrl,
                      inputFormatters: [DateTextInputFormatter()],
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                      decoration: const InputDecoration(
                          labelText: 'Data reserva (DD/MM/AAAA)'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: hora1Ctrl,
                      inputFormatters: [TimeTextInputFormatter()],
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                      decoration: const InputDecoration(
                          labelText: 'Hora reserva (HH:mm)'),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                Text('Localização',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: TextField(
                            controller: latitudeCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Latitude'))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextField(
                            controller: longitudeCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Longitude'))),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: obsCtrl,
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _saveButtonFocusNode.requestFocus(),
                    decoration:
                        const InputDecoration(labelText: 'Observações')),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!,
                      style: const TextStyle(
                          color: AppColors.errorRed,
                          fontWeight: FontWeight.w700)),
                ],
                const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: Focus(
                          focusNode: _saveButtonFocusNode,
                          child: AppButton(
                            label: widget.item == null ? 'Salvar' : 'Atualizar',
                            onPressed: submit,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
