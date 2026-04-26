import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/viagem.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_screen_chrome.dart';

class RestauranteSearchScreen extends StatefulWidget {
  final ApiService api;
  final Viagem viagem;

  const RestauranteSearchScreen({
    super.key,
    required this.api,
    required this.viagem,
  });

  @override
  State<RestauranteSearchScreen> createState() => _RestauranteSearchScreenState();
}

class _RestauranteSearchScreenState extends State<RestauranteSearchScreen> {
  final Distance _distance = const Distance();
  static const List<String> _tiposComidaPadrao = [
    'Italiana',
    'Japonesa',
    'Steakhouse',
    'Mediterranea',
    'Internacional',
    'Asiatica',
    'Outras',
  ];
  static const List<String> _glutenOpcoesPadrao = [
    'Gluten Free',
    'Gluten Friendly',
    'Normal',
  ];

  bool loading = true;
  bool locating = false;
  String? errorText;
  String? locationInfo;
  Position? myPosition;

  String? filterTipoComida;
  String? filterGluten;

  List<Map<String, dynamic>> _allRestaurants = [];

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  Future<void> _resolveMyLocation() async {
    setState(() => locating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          locationInfo = 'Localização desativada no dispositivo.';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          locationInfo = 'Permissão de localização negada no navegador.';
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() {
        myPosition = pos;
        locationInfo = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        locationInfo = 'Não foi possível obter localização. Verifique permissão do site e HTTPS.';
      });
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      errorText = null;
    });
    try {
      final rawCities = await widget.api.getRequest('/api/viagens/cidades/${widget.viagem.id}') as List<dynamic>;
      final cities = rawCities.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      final list = <Map<String, dynamic>>[];
      for (final c in cities) {
        final cityId = c['id'];
        final cityName = (c['descricao'] ?? '').toString();
        final rawRest = await widget.api.getRequest('/api/viagens/restaurantes/$cityId') as List<dynamic>;
        for (final r in rawRest) {
          final item = Map<String, dynamic>.from(r as Map);
          item['cidade_descricao'] = cityName;
          list.add(item);
        }
      }

      if (!mounted) return;
      _allRestaurants = list;
    } catch (e) {
      if (!mounted) return;
      errorText = 'Erro ao carregar restaurantes: $e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  double? _distanceKm(Map<String, dynamic> item) {
    final pos = myPosition;
    if (pos == null) return null;
    final lat = _toDouble(item['latitude']);
    final lng = _toDouble(item['longitude']);
    if (lat == null || lng == null) return null;
    final meters = _distance.as(
      LengthUnit.Meter,
      LatLng(pos.latitude, pos.longitude),
      LatLng(lat, lng),
    );
    return meters / 1000;
  }

  List<Map<String, dynamic>> _filteredAndSorted() {
    final filtered = _allRestaurants.where((r) {
      final tipo = (r['tipo_comida'] ?? '').toString();
      final gluten = (r['gluten_opcao'] ?? 'Normal').toString();
      if (filterTipoComida != null && tipo != filterTipoComida) return false;
      if (filterGluten != null && gluten != filterGluten) return false;
      return true;
    }).toList();

    filtered.sort((a, b) {
      final ad = _distanceKm(a);
      final bd = _distanceKm(b);
      if (ad == null && bd == null) {
        final an = (a['nome'] ?? '').toString().toLowerCase();
        final bn = (b['nome'] ?? '').toString().toLowerCase();
        return an.compareTo(bn);
      }
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });
    return filtered;
  }

  Future<void> _openGoogleMaps(Map<String, dynamic> item) async {
    final nome = (item['nome'] ?? '').toString().trim();
    final endereco = (item['endereco'] ?? '').toString().trim();
    final destino = endereco.isNotEmpty ? endereco : nome;
    if (destino.isEmpty) return;

    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destino,
      'travelmode': 'driving',
    });
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o Google Maps neste dispositivo.')),
      );
    }
  }

  Uri? _normalizeLink(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(text);
    final candidate = hasScheme ? text : 'https://$text';
    return Uri.tryParse(candidate);
  }

  Future<void> _openRestaurantLink(String raw) async {
    final uri = _normalizeLink(raw);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o link deste restaurante.')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
    _resolveMyLocation();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredAndSorted();

    return Scaffold(
      appBar: AppScreenChrome.appBar(context, title: 'Pesquisa de Restaurantes'),
      body: AppGradientBackground(
        child: loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.accentOrange))
            : errorText != null
                ? Center(
                    child: Padding(
                      padding: AppLayout.screenPadding,
                      child: Text(errorText!, textAlign: TextAlign.center),
                    ),
                  )
                : RefreshIndicator(
                    color: AppColors.accentOrange,
                    onRefresh: _load,
                    child: ListView(
                      padding: AppLayout.screenPadding,
                      children: [
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Filtros',
                                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String?>(
                                initialValue: filterTipoComida,
                                decoration: const InputDecoration(labelText: 'Tipo de comida'),
                                items: [
                                  const DropdownMenuItem<String?>(value: null, child: Text('Todos')),
                                  ..._tiposComidaPadrao.map((t) => DropdownMenuItem<String?>(value: t, child: Text(t))),
                                ],
                                onChanged: (v) => setState(() => filterTipoComida = v),
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String?>(
                                initialValue: filterGluten,
                                decoration: const InputDecoration(labelText: 'Opção de glúten'),
                                items: [
                                  const DropdownMenuItem<String?>(value: null, child: Text('Todas')),
                                  ..._glutenOpcoesPadrao.map((g) => DropdownMenuItem<String?>(value: g, child: Text(g))),
                                ],
                                onChanged: (v) => setState(() => filterGluten = v),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.near_me_rounded, size: 16, color: AppColors.neutralGray),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      myPosition == null
                                          ? 'Ordenação por distância ativa quando sua localização estiver disponível.'
                                          : 'Ordenado por distância: mais próximo → mais distante.',
                                      style: const TextStyle(fontSize: 12, color: AppColors.neutralGray),
                                    ),
                                  ),
                                  if (locating)
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.accentOrange,
                                      ),
                                    ),
                                ],
                              ),
                              if (locationInfo != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  locationInfo!,
                                  style: const TextStyle(fontSize: 12, color: AppColors.errorRed),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton.icon(
                                  onPressed: locating ? null : _resolveMyLocation,
                                  icon: const Icon(Icons.my_location_rounded, size: 16),
                                  label: const Text('Ativar localização'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (list.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 36),
                            child: Text(
                              'Nenhum restaurante encontrado com os filtros selecionados.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.primaryBlue, fontSize: 16),
                            ),
                          ),
                        ...list.map((r) {
                          final nome = (r['nome'] ?? '').toString();
                          final tipo = (r['tipo_comida'] ?? '').toString();
                          final gluten = (r['gluten_opcao'] ?? 'Normal').toString();
                          final endereco = (r['endereco'] ?? '').toString();
                          final cidade = (r['cidade_descricao'] ?? '').toString();
                          final link = (r['link_url'] ?? '').toString();
                          final distKm = _distanceKm(r);

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
                                    IconButton(
                                      tooltip: 'Navegar',
                                      onPressed: () => _openGoogleMaps(r),
                                      icon: const Icon(Icons.navigation_rounded, color: AppColors.primaryBlue),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  [
                                    if (tipo.isNotEmpty) tipo,
                                    gluten,
                                    if (cidade.isNotEmpty) 'Cidade: $cidade',
                                  ].join(' · '),
                                  style: const TextStyle(fontSize: 13, color: AppColors.neutralGray),
                                ),
                                if (endereco.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(endereco),
                                ],
                                if (link.trim().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed: () => _openRestaurantLink(link),
                                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                                    label: const Text('Abrir link'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.primaryBlue,
                                      padding: EdgeInsets.zero,
                                      alignment: Alignment.centerLeft,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Text(
                                  distKm == null
                                      ? 'Distância indisponível (permita localização e/ou preencha latitude/longitude).'
                                      : 'Distância: ${distKm.toStringAsFixed(1)} km',
                                  style: const TextStyle(fontSize: 12, color: AppColors.neutralGray),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
      ),
    );
  }
}
