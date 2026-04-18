import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/viagem.dart';
import '../services/api_service.dart';
import '../services/trip_preferences_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_screen_chrome.dart';

/// Sugestoes deterministicas para um bloco [Tempo Livre] (Fase 3).
class SuggestionsBlocoScreen extends StatefulWidget {
  final ApiService api;
  final Viagem viagem;
  final int blocoId;

  const SuggestionsBlocoScreen({
    super.key,
    required this.api,
    required this.viagem,
    required this.blocoId,
  });

  @override
  State<SuggestionsBlocoScreen> createState() => _SuggestionsBlocoScreenState();
}

class _SuggestionsBlocoScreenState extends State<SuggestionsBlocoScreen> {
  bool loading = true;
  String? errorText;
  Map<String, dynamic>? payload;
  int? acceptingWishId;
  String? filterCategoria;
  String? filterStatus;
  int? filterMemberId;
  String sortOrder = 'score';
  bool locating = false;
  Position? myPosition;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      errorText = null;
    });
    try {
      final raw = await widget.api.getRequest('/api/suggestions/for-bloco/${widget.blocoId}');
      if (!mounted) return;
      payload = raw is Map ? Map<String, dynamic>.from(raw) : null;
    } catch (e) {
      errorText = e.toString();
      payload = null;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openPreferences() async {
    final svc = TripPreferencesService(widget.api);
    Map<String, dynamic>? current;
    try {
      current = await svc.get(widget.viagem.id);
    } catch (_) {}

    final catsCtrl = TextEditingController(text: (current?['prefer_categorias'] ?? '').toString());
    final dietaryCtrl = TextEditingController(text: (current?['dietary'] ?? '').toString());
    var modo = (current?['mobility_pref'] ?? 'driving').toString().trim();
    if (modo != 'walking' && modo != 'transit' && modo != 'driving') modo = 'driving';

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          return AlertDialog(
            title: const Text('Preferências de viagem'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Categorias preferidas (separe por vírgula: Comer, Visitar, Comprar, Outras)',
                    style: TextStyle(fontSize: 12, color: AppColors.neutralGray),
                  ),
                  TextField(controller: catsCtrl),
                  const SizedBox(height: 12),
                  const Text('Restrições alimentares (opcional)', style: TextStyle(fontSize: 12, color: AppColors.neutralGray)),
                  TextField(controller: dietaryCtrl),
                  const SizedBox(height: 16),
                  const Text(
                    'Mobilidade — modal preferido na timeline (carro, a pé, transporte público)',
                    style: TextStyle(fontSize: 12, color: AppColors.neutralGray),
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: modo,
                    items: const [
                      DropdownMenuItem(value: 'driving', child: Text('Carro')),
                      DropdownMenuItem(value: 'walking', child: Text('A pé')),
                      DropdownMenuItem(value: 'transit', child: Text('Transporte público')),
                    ],
                    onChanged: (v) => setModal(() => modo = v ?? 'driving'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              TextButton(
                onPressed: () async {
                  await svc.put(widget.viagem.id, {
                    'prefer_categorias': catsCtrl.text.trim().isEmpty ? null : catsCtrl.text.trim(),
                    'dietary': dietaryCtrl.text.trim().isEmpty ? null : dietaryCtrl.text.trim(),
                    'budget_level': current?['budget_level'],
                    'pace': current?['pace'],
                    'touristic_level': current?['touristic_level'],
                    'mobility_pref': modo,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  await load();
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _accept(int wishlistId) async {
    setState(() => acceptingWishId = wishlistId);
    try {
      await widget.api.postRequest('/api/suggestions/accept', {
        'bloco_id': widget.blocoId,
        'wishlist_item_id': wishlistId,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evento fixo adicionado ao roteiro. Atualize a timeline se necessário.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => acceptingWishId = null);
    }
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  double? _distanceKmFromMe(Map<String, dynamic> item) {
    final pos = myPosition;
    if (pos == null) return null;
    final lat = _toDouble(item['latitude']);
    final lng = _toDouble(item['longitude']);
    if (lat == null || lng == null) return null;
    const distance = Distance();
    final meters = distance.as(
      LengthUnit.Meter,
      LatLng(pos.latitude, pos.longitude),
      LatLng(lat, lng),
    );
    return meters / 1000;
  }

  Future<void> _changeSortOrder(String? value) async {
    if (value == null || value == sortOrder) return;
    if (value == 'alphabetical' || value == 'score') {
      setState(() => sortOrder = value);
      return;
    }

    // "Mais proximo a mim" requer permissao e obtencao da localizacao atual.
    setState(() => locating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ative o GPS/localização para usar este filtro.')),
          );
        }
        setState(() => sortOrder = 'score');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permissão de localização negada.')),
          );
        }
        setState(() => sortOrder = 'score');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() {
        myPosition = pos;
        sortOrder = 'nearest';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível obter sua localização: $e')),
        );
        setState(() => sortOrder = 'score');
      }
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppScreenChrome.appBar(
        context,
        title: 'Sugestões',
        actions: [
          IconButton(
            tooltip: 'Preferências',
            onPressed: loading ? null : _openPreferences,
            icon: const Icon(Icons.tune, color: AppColors.primaryBlue),
          ),
        ],
      ),
      body: AppGradientBackground(
        child: loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.accentOrange))
            : errorText != null
                ? Center(
                    child: Padding(
                      padding: AppLayout.screenPadding,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(errorText!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          AppButton(label: 'Tentar novamente', onPressed: load),
                        ],
                      ),
                    ),
                  )
                : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final list = ((payload?['suggestions'] as List<dynamic>?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final janela = payload?['janela_minutos'];
    final anchor = payload?['anchor'];
    final categorias = <String>{
      for (final s in list) (Map<String, dynamic>.from(s['wishlist_item'] as Map)['categoria'] ?? '').toString(),
    }..remove('');
    final statuses = <String>{
      for (final s in list) (Map<String, dynamic>.from(s['wishlist_item'] as Map)['status'] ?? '').toString(),
    }..remove('');
    final members = ((payload?['members'] as List<dynamic>?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final filtered = list.where((s) {
      final item = Map<String, dynamic>.from(s['wishlist_item'] as Map);
      if (filterCategoria != null && item['categoria']?.toString() != filterCategoria) return false;
      if (filterStatus != null && item['status']?.toString() != filterStatus) return false;
      if (filterMemberId != null) {
        final rawId = item['user_id'];
        final uid = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
        if (uid != filterMemberId) return false;
      }
      return true;
    }).toList();

    if (sortOrder == 'nearest' && myPosition != null) {
      filtered.sort((a, b) {
        final ai = Map<String, dynamic>.from(a['wishlist_item'] as Map);
        final bi = Map<String, dynamic>.from(b['wishlist_item'] as Map);
        final ad = _distanceKmFromMe(ai);
        final bd = _distanceKmFromMe(bi);
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });
    } else if (sortOrder == 'score') {
      filtered.sort((a, b) {
        final as = (a['score'] is num) ? (a['score'] as num).toDouble() : -999999;
        final bs = (b['score'] is num) ? (b['score'] as num).toDouble() : -999999;
        return bs.compareTo(as);
      });
    } else {
      filtered.sort((a, b) {
        final ai = Map<String, dynamic>.from(a['wishlist_item'] as Map);
        final bi = Map<String, dynamic>.from(b['wishlist_item'] as Map);
        final an = (ai['nome'] ?? '').toString().trim().toLowerCase();
        final bn = (bi['nome'] ?? '').toString().trim().toLowerCase();
        return an.compareTo(bn);
      });
    }

    return RefreshIndicator(
      color: AppColors.accentOrange,
      onRefresh: load,
      child: ListView(
        padding: AppLayout.screenPadding,
        children: [
          if (janela != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Janela do tempo livre: ~$janela min (itens que exigem mais tempo foram ocultados).',
                style: const TextStyle(fontSize: 13, color: AppColors.neutralGray),
              ),
            ),
          if (anchor is Map)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Referência de distância: centro das cidades com coordenadas.',
                style: TextStyle(fontSize: 13, color: AppColors.neutralGray),
              ),
            ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filtros',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: filterCategoria,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Todas')),
                    ...categorias.map((c) => DropdownMenuItem<String?>(value: c, child: Text(c))),
                  ],
                  onChanged: (v) => setState(() => filterCategoria = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  initialValue: filterStatus,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Todos')),
                    ...statuses.map((s) => DropdownMenuItem<String?>(value: s, child: Text(s))),
                  ],
                  onChanged: (v) => setState(() => filterStatus = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int?>(
                  initialValue: filterMemberId,
                  decoration: const InputDecoration(labelText: 'Membro da Viagem'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Todos os membros'),
                    ),
                    ...members.map((m) {
                      final rawId = m['user_id'];
                      final id = rawId is int ? rawId : int.tryParse(rawId.toString());
                      final nome = (m['nome'] ?? m['email'] ?? '').toString();
                      if (id == null) return null;
                      return DropdownMenuItem<int?>(
                        value: id,
                        child: Text(nome.isEmpty ? 'Membro #$id' : nome),
                      );
                    }).whereType<DropdownMenuItem<int?>>(),
                  ],
                  onChanged: (v) => setState(() => filterMemberId = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: sortOrder,
                  decoration: const InputDecoration(labelText: 'Ordenação'),
                  items: const [
                    DropdownMenuItem<String>(
                      value: 'score',
                      child: Text('Mais relevantes (pts)'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'alphabetical',
                      child: Text('Ordem Alfabética'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'nearest',
                      child: Text('Mais Próximo a mim'),
                    ),
                  ],
                  onChanged: locating ? null : _changeSortOrder,
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.info_outline, size: 16, color: AppColors.neutralGray),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Os "pts" representam a relevância da sugestão para este bloco de tempo livre. '
                        'A pontuação combina proximidade, status do item, avaliação e aderência à categoria/preferências.',
                        style: TextStyle(fontSize: 12, color: AppColors.neutralGray),
                      ),
                    ),
                  ],
                ),
                if (locating)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentOrange),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Text(
                'Nenhuma sugestão encontrada com os filtros atuais.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.primaryBlue, fontSize: 16),
              ),
            ),
          ...filtered.map((m) {
            final item = Map<String, dynamic>.from(m['wishlist_item'] as Map);
            final score = m['score'];
            final breakdown = m['breakdown'];
            final nome = (item['nome'] ?? '').toString();
            final cat = (item['categoria'] ?? '').toString();
            final end = (item['endereco'] ?? '').toString();
            final id = item['id'] as int;
            final myKm = _distanceKmFromMe(item);
            final membroNome = (item['membro_nome'] ?? item['membro_email'] ?? '').toString();

            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          nome,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                      Text(
                        score != null ? '$score pts' : '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentOrange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('$cat · ${item['status'] ?? ''}', style: const TextStyle(color: AppColors.neutralGray, fontSize: 13)),
                  if (membroNome.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Desejo de: $membroNome',
                      style: const TextStyle(color: AppColors.neutralGray, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                  if (end.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(end, style: const TextStyle(fontSize: 14)),
                  ],
                  if (sortOrder == 'nearest' && myKm != null) ...[
                    const SizedBox(height: 6),
                    Text('Distância até você: ${myKm.toStringAsFixed(1)} km',
                        style: const TextStyle(fontSize: 12, color: AppColors.neutralGray)),
                  ],
                  if (breakdown is Map) ...[
                    const SizedBox(height: 8),
                    Text(
                      _breakdownLine(Map<String, dynamic>.from(breakdown)),
                      style: const TextStyle(fontSize: 12, color: AppColors.neutralGray),
                    ),
                  ],
                  const SizedBox(height: 12),
                  AppButton(
                    label: acceptingWishId == id ? 'Salvando…' : 'Aceitar e criar evento fixo',
                    onPressed: acceptingWishId != null ? null : () => _accept(id),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _breakdownLine(Map<String, dynamic> b) {
    final km = b['distancia_km'];
    final parts = <String>[];
    if (km != null) parts.add('≈ $km km do centro');
    parts.add('prox ${b['pontos_proximidade']} · status ${b['pontos_status']} · aval ${b['pontos_avaliacao']} · cat ${b['pontos_categoria']}');
    return parts.join(' · ');
  }
}
