import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/viagem.dart';
import '../services/api_service.dart';
import '../services/realtime_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_screen_chrome.dart';
import 'places_search_results_screen.dart';
import 'wishlist_item_form_screen.dart';

const _categorias = ['Comer', 'Visitar', 'Comprar', 'Outras'];
const _statusValues = ['nao_visitado', 'planejado', 'concluido', 'descartado'];

String _statusLabel(String s) {
  switch (s) {
    case 'nao_visitado':
      return 'Não visitado';
    case 'planejado':
      return 'Planejado';
    case 'concluido':
      return 'Concluído';
    case 'descartado':
      return 'Descartado';
    default:
      return s;
  }
}

class WishlistScreen extends StatefulWidget {
  final ApiService api;
  final Viagem viagem;
  final RealtimeService realtime;

  const WishlistScreen({super.key, required this.api, required this.viagem, required this.realtime});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? filterCategoria;
  String? filterStatus;
  int? filterMemberId;
  String sortOrder = 'recentes';
  List<Map<String, dynamic>> _membrosViagem = [];
  List<Map<String, dynamic>> _cidadesCache = [];
  StreamSubscription<RealtimePush>? _realtimeSub;

  bool _sameViagem(Map<String, dynamic>? map) {
    if (map == null || !map.containsKey('viagem_id')) return false;
    final v = map['viagem_id'];
    final id = widget.viagem.id;
    return v == id || v.toString() == id.toString();
  }

  @override
  void initState() {
    super.initState();
    _loadCidades();
    _loadMembers();
    load();
    _realtimeSub = widget.realtime.pushes.listen((push) {
      if (!mounted) return;
      if (!push.event.startsWith('wishlist')) return;
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

  Future<void> _loadCidades() async {
    try {
      final raw = await widget.api.getRequest('/api/viagens/cidades/${widget.viagem.id}') as List<dynamic>;
      _cidadesCache = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      _cidadesCache = [];
    }
  }

  Future<void> _loadMembers() async {
    try {
      final raw = await widget.api.getRequest('/api/viagens/${widget.viagem.id}/members') as List<dynamic>;
      _membrosViagem = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      _membrosViagem = [];
    }
  }

  (double?, double?) _firstCityCoords() {
    for (final c in _cidadesCache) {
      final lat = c['latitude'];
      final lng = c['longitude'];
      if (lat != null && lng != null) {
        final la = lat is num ? lat.toDouble() : double.tryParse(lat.toString());
        final ln = lng is num ? lng.toDouble() : double.tryParse(lng.toString());
        if (la != null && ln != null) return (la, ln);
      }
    }
    return (null, null);
  }

  String _listPath() {
    final base = '/api/wishlist/${widget.viagem.id}';
    final q = <String>[];
    if (filterCategoria != null) q.add('categoria=${Uri.encodeQueryComponent(filterCategoria!)}');
    if (filterStatus != null) q.add('status=${Uri.encodeQueryComponent(filterStatus!)}');
    if (filterMemberId != null) q.add('member_id=$filterMemberId');
    if (q.isEmpty) return base;
    return '$base?${q.join('&')}';
  }

  Future<void> load() async {
    setState(() => loading = true);
    final data = await widget.api.getRequest(_listPath()) as List<dynamic>;
    items = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    _applyOrdering();
    if (mounted) setState(() => loading = false);
  }

  void _applyOrdering() {
    if (sortOrder == 'alfabetica') {
      items.sort((a, b) {
        final an = (a['nome'] ?? '').toString().trim().toLowerCase();
        final bn = (b['nome'] ?? '').toString().trim().toLowerCase();
        return an.compareTo(bn);
      });
      return;
    }
    if (sortOrder == 'antigos') {
      items.sort((a, b) {
        final ad = DateTime.tryParse((a['created_at'] ?? '').toString());
        final bd = DateTime.tryParse((b['created_at'] ?? '').toString());
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });
      return;
    }
    // recentes (default)
    items.sort((a, b) {
      final ad = DateTime.tryParse((a['created_at'] ?? '').toString());
      final bd = DateTime.tryParse((b['created_at'] ?? '').toString());
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });
  }

  Future<void> _importFromPlaces() async {
    final queryCtrl = TextEditingController();
    String categoria = 'Visitar';
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModal) {
          return AlertDialog(
            title: const Text('Buscar no Google Places'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: queryCtrl,
                    decoration: const InputDecoration(labelText: 'O que procurar? (ex.: shopping, restaurante, museu)'),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'A busca usa só este texto (e a região das cidades com coordenadas). A categoria abaixo só classifica o item na sua wishlist.',
                    style: TextStyle(fontSize: 12, color: AppColors.neutralGray),
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Categoria na wishlist', style: TextStyle(fontSize: 12, color: AppColors.neutralGray)),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: DropdownButton<String>(
                      value: categoria,
                      isExpanded: true,
                      items: _categorias
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setModal(() => categoria = v ?? 'Visitar'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              TextButton(
                onPressed: () async {
                  final q = queryCtrl.text.trim();
                  if (q.isEmpty) return;
                  Navigator.pop(ctx);
                  await _runPlacesSearch(q, categoria);
                },
                child: const Text('Buscar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _runPlacesSearch(String namePart, String categoria) async {
    final (lat, lng) = _firstCityCoords();
    final queryText = namePart.trim();
    try {
      // Sem `tipo_lugar`: a API Places nao restringe por tipo; a categoria so grava no item da wishlist.
      final body = <String, dynamic>{
        'query': queryText,
      };
      if (lat != null) body['latitude'] = lat;
      if (lng != null) body['longitude'] = lng;

      final raw = await widget.api.postRequest('/api/places/search', body) as List<dynamic>;
      if (!mounted) return;
      final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      final selected = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => PlacesSearchResultsScreen(
            title: 'Escolher local',
            cidadeNome: '',
            queryUsada: queryText,
            resultados: list,
            placeholderIcon: Icons.place,
          ),
        ),
      );
      if (selected == null || !mounted) return;

      await widget.api.postRequest('/api/wishlist/${widget.viagem.id}/import-place', {
        'categoria': categoria,
        'nome': selected['nome'],
        'endereco': selected['endereco'],
        'latitude': selected['latitude'],
        'longitude': selected['longitude'],
        'rating': selected['rating'],
        'foto_url': selected['foto_url'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item adicionado à wishlist.')));
        await load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  Future<void> _openForm({Map<String, dynamic>? item}) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WishlistItemFormScreen(api: widget.api, viagem: widget.viagem, item: item),
      ),
    );
    if (ok == true && mounted) {
      await load();
    }
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover item'),
        content: const Text('Deseja remover este item da wishlist?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remover')),
        ],
      ),
    );
    if (ok != true) return;
    await widget.api.deleteRequest('/api/wishlist/item/$id');
    await load();
  }

  List<Map<String, dynamic>> _mappableItems() {
    return items.where((e) {
      final la = e['latitude'];
      final ln = e['longitude'];
      if (la == null || ln == null) return false;
      final a = la is num ? la.toDouble() : double.tryParse(la.toString());
      final b = ln is num ? ln.toDouble() : double.tryParse(ln.toString());
      return a != null && b != null;
    }).toList();
  }

  Uri? _normalizeLink(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(text);
    final candidate = hasScheme ? text : 'https://$text';
    return Uri.tryParse(candidate);
  }

  Future<void> _openLink(String raw) async {
    final uri = _normalizeLink(raw);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link inválido para abrir.')),
      );
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o link neste dispositivo.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha ao abrir o link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mappable = _mappableItems();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppScreenChrome.appBar(
          context,
          title: 'Wishlist',
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Lista', icon: Icon(Icons.list_alt, size: 20)),
              Tab(text: 'Mapa', icon: Icon(Icons.map_outlined, size: 20)),
            ],
          ),
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton.extended(
              heroTag: 'wish_add_places',
              onPressed: loading ? null : _importFromPlaces,
              icon: const Icon(Icons.search),
              label: const Text('Google Places'),
            ),
            const SizedBox(height: 10),
            FloatingActionButton(
              heroTag: 'wish_add',
              tooltip: 'Novo manual',
              onPressed: loading ? null : () => _openForm(),
              child: const Icon(Icons.add),
            ),
          ],
        ),
        body: AppGradientBackground(
          child: loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.accentOrange))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Categoria',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String?>(
                                      isExpanded: true,
                                      value: filterCategoria,
                                      items: [
                                        const DropdownMenuItem<String?>(value: null, child: Text('Todas')),
                                        ..._categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                                      ],
                                      onChanged: (v) async {
                                        setState(() => filterCategoria = v);
                                        await load();
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Status',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String?>(
                                      isExpanded: true,
                                      value: filterStatus,
                                      items: [
                                        const DropdownMenuItem<String?>(value: null, child: Text('Todos')),
                                        ..._statusValues.map(
                                          (s) => DropdownMenuItem(value: s, child: Text(_statusLabel(s))),
                                        ),
                                      ],
                                      onChanged: (v) async {
                                        setState(() => filterStatus = v);
                                        await load();
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Membro da Viagem',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int?>(
                                      isExpanded: true,
                                      value: filterMemberId,
                                      items: [
                                        const DropdownMenuItem<int?>(
                                          value: null,
                                          child: Text('Todos os membros'),
                                        ),
                                        ..._membrosViagem.map((m) {
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
                                      onChanged: (v) async {
                                        setState(() => filterMemberId = v);
                                        await load();
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Ordenação',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      isExpanded: true,
                                      value: sortOrder,
                                      items: const [
                                        DropdownMenuItem(value: 'recentes', child: Text('Mais recentes')),
                                        DropdownMenuItem(value: 'antigos', child: Text('Mais antigos')),
                                        DropdownMenuItem(value: 'alfabetica', child: Text('Ordem alfabética')),
                                      ],
                                      onChanged: (v) async {
                                        setState(() => sortOrder = v ?? 'recentes');
                                        await load();
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildList(),
                          _buildMap(context, mappable),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_outline_rounded, size: 80, color: AppColors.primaryBlue),
              const SizedBox(height: 16),
              const Text(
                'Nenhum desejo salvo ainda.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 24),
              AppButton(label: 'Adicionar manualmente', onPressed: () => _openForm()),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final it = items[i];
        final nome = (it['nome'] ?? '').toString();
        final end = (it['endereco'] ?? '').toString();
        final link = (it['link_url'] ?? '').toString();
        final cat = (it['categoria'] ?? '').toString();
        final st = (it['status'] ?? '').toString();
        final membroNome = (it['membro_nome'] ?? it['membro_email'] ?? '').toString();
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
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.lightBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(cat, style: const TextStyle(color: AppColors.primaryBlue, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(_statusLabel(st), style: const TextStyle(color: AppColors.neutralGray, fontSize: 13)),
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
              if (link.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _openLink(link),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Abrir link'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Editar',
                    onPressed: () => _openForm(item: it),
                    icon: const Icon(Icons.edit_outlined, color: AppColors.accentOrange),
                  ),
                  IconButton(
                    tooltip: 'Excluir',
                    onPressed: () => _delete(it['id'] as int),
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.errorRed),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMap(BuildContext context, List<Map<String, dynamic>> mappable) {
    if (mappable.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nenhum item com localização para exibir no mapa.\nUse a busca Google Places ou cadastre depois com coordenadas.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.neutralGray),
          ),
        ),
      );
    }

    final points = <LatLng>[
      for (final e in mappable)
        LatLng(
          e['latitude'] is num ? (e['latitude'] as num).toDouble() : double.parse(e['latitude'].toString()),
          e['longitude'] is num ? (e['longitude'] as num).toDouble() : double.parse(e['longitude'].toString()),
        ),
    ];

    // Carto Voyager: leitura mais limpa que OSM raster padrão. Sem retina simulada (evita textos minúsculos).
    const tileTemplate = 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';

    final mapOptions = points.length == 1
        ? MapOptions(
            initialCenter: points.first,
            initialZoom: 15,
            minZoom: 2,
            maxZoom: 19,
            backgroundColor: AppColors.lightBlue,
          )
        : MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(points),
              padding: const EdgeInsets.fromLTRB(36, 48, 36, 64),
              maxZoom: 16,
            ),
            minZoom: 2,
            maxZoom: 19,
            backgroundColor: AppColors.lightBlue,
          );

    return FlutterMap(
      options: mapOptions,
      children: [
        TileLayer(
          urlTemplate: tileTemplate,
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.example.app_viagens',
          maxNativeZoom: 20,
          retinaMode: false,
          panBuffer: 1,
        ),
        MarkerLayer(
          markers: [
            for (var i = 0; i < mappable.length; i++)
              Marker(
                width: 172,
                height: 112,
                alignment: Alignment.bottomCenter,
                point: points[i],
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 168),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: const [
                            BoxShadow(color: Color(0x26000000), blurRadius: 6, offset: Offset(0, 2)),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          child: Text(
                            (mappable[i]['nome'] ?? '').toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryBlue,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Icon(
                      Icons.place_rounded,
                      color: AppColors.accentOrange,
                      size: 44,
                      shadows: [
                        Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
        SimpleAttributionWidget(
          alignment: Alignment.bottomRight,
          backgroundColor: Colors.white.withValues(alpha: 0.92),
          source: const Text(
            'CARTO · OpenStreetMap',
            style: TextStyle(fontSize: 10, color: AppColors.neutralGray),
          ),
        ),
      ],
    );
  }
}
