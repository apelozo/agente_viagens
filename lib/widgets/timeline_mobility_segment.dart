import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/distance_service.dart';
import '../services/mobility_service.dart';
import '../theme/app_theme.dart';

/// Estima deslocamento entre dois blocos **Evento Fixo** (mesmo dia): texto de [local] + Places Text Search e Distance Matrix.
/// O cálculo só corre quando o utilizador toca no ícone (evita chamadas em massa ao abrir o dia).
/// [anchorLat]/[anchorLng] opcionais: melhoram a pesquisa de endereços (viés regional).
/// Importante: exige `local` preenchido na origem e no destino (sem fallback para âncora).
class TimelineMobilitySegment extends StatefulWidget {
  final ApiService api;
  final double? anchorLat;
  final double? anchorLng;
  final Map<String, dynamic> blocoOrigem;
  final Map<String, dynamic> blocoDestino;
  /// Uma de: driving, walking, transit
  final String? modoPreferido;

  const TimelineMobilitySegment({
    super.key,
    required this.api,
    required this.anchorLat,
    required this.anchorLng,
    required this.blocoOrigem,
    required this.blocoDestino,
    this.modoPreferido,
  });

  @override
  State<TimelineMobilitySegment> createState() => _TimelineMobilitySegmentState();
}

class _TimelineMobilitySegmentState extends State<TimelineMobilitySegment> {
  /// Só após o utilizador pedir explicitamente (evita N chamadas à API ao abrir o dia).
  bool _pediuCalculo = false;
  bool loading = false;
  String? errorText;
  Map<String, dynamic>? distancias;
  String? _recommendedMode;

  static double? _toD(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.'));
  }

  Future<(double?, double?)> _geocodeLocal(String? texto) async {
    final q = (texto ?? '').trim();
    if (q.isEmpty) return (null, null);
    try {
      final body = <String, dynamic>{'query': q};
      final alat = widget.anchorLat;
      final alng = widget.anchorLng;
      if (alat != null && alng != null) {
        body['latitude'] = alat;
        body['longitude'] = alng;
      }
      final data = await widget.api.postRequest('/api/places/search', body);
      if (data is! List || data.isEmpty) return (null, null);
      final first = data.first;
      if (first is! Map) return (null, null);
      final m = Map<String, dynamic>.from(first);
      return (_toD(m['latitude']), _toD(m['longitude']));
    } catch (_) {
      return (null, null);
    }
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      errorText = null;
      distancias = null;
      _recommendedMode = null;
    });
    final lo = (widget.blocoOrigem['local'] ?? '').toString();
    final ld = (widget.blocoDestino['local'] ?? '').toString();
    if (lo.trim().isEmpty || ld.trim().isEmpty) {
      setState(() {
        loading = false;
        errorText = 'Preencha o campo "Local do evento" nos dois eventos para calcular a rota.';
      });
      return;
    }
    double? olat;
    double? olng;
    double? dlat;
    double? dlng;
    try {
      final (oLat, oLng) = await _geocodeLocal(lo.isEmpty ? null : lo);
      final (dLat, dLng) = await _geocodeLocal(ld.isEmpty ? null : ld);

      if ((oLat == null || oLng == null) && lo.isNotEmpty) {
        setState(() {
          loading = false;
          errorText = 'Não foi possível localizar o endereço do bloco anterior.';
        });
        return;
      }
      if ((dLat == null || dLng == null) && ld.isNotEmpty) {
        setState(() {
          loading = false;
          errorText = 'Não foi possível localizar o endereço do bloco seguinte.';
        });
        return;
      }
      olat = oLat;
      olng = oLng;
      dlat = dLat;
      dlng = dLng;
      if (olat == null || olng == null || dlat == null || dlng == null) return;

      final mobility = MobilityService(widget.api);
      final data = await mobility.compare(
        origemLat: olat,
        origemLng: olng,
        destinoLat: dlat,
        destinoLng: dlng,
      );
      if (!mounted) return;
      setState(() {
        distancias = data['comparison'] is Map
            ? Map<String, dynamic>.from(data['comparison'] as Map)
            : null;
        _recommendedMode = data['recommended_mode']?.toString();
        loading = false;
      });
    } catch (e) {
      if (olat != null && olng != null && dlat != null && dlng != null) {
        try {
          final fallbackSvc = DistanceService(widget.api);
          final fallback = await fallbackSvc.calculate(
            origemLat: olat,
            origemLng: olng,
            destinoLat: dlat,
            destinoLng: dlng,
          );
          if (!mounted) return;
          setState(() {
            distancias = fallback;
            loading = false;
            errorText = null;
            _recommendedMode = widget.modoPreferido;
          });
          return;
        } catch (_) {
          // Fallback também falhou; mantém mensagem amigável abaixo.
        }
      }
      if (!mounted) return;
      setState(() {
        loading = false;
        errorText = 'Falha ao calcular: $e';
      });
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant TimelineMobilitySegment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blocoOrigem['id'] != widget.blocoOrigem['id'] ||
        oldWidget.blocoDestino['id'] != widget.blocoDestino['id'] ||
        oldWidget.blocoOrigem['local'] != widget.blocoOrigem['local'] ||
        oldWidget.blocoDestino['local'] != widget.blocoDestino['local']) {
      setState(() {
        _pediuCalculo = false;
        loading = false;
        errorText = null;
        distancias = null;
        _recommendedMode = null;
      });
    }
  }

  String _fmt(Map<String, dynamic>? m) {
    if (m == null) return '—';
    final min = m['tempo_minutos'];
    final km = m['distancia_km'];
    final t = min == null ? '—' : '$min min';
    final d = km == null ? '—' : '${km is num ? km.toStringAsFixed(1) : km} km';
    if (min == null && km == null) return 'Indisponível';
    return '$t · $d';
  }

  String _modeLabel(String mode) {
    switch (mode) {
      case 'walking':
        return 'A pé';
      case 'transit':
        return 'Transporte público';
      default:
        return 'Carro';
    }
  }

  Future<void> _openNavigation(String mode) async {
    final origem = (widget.blocoOrigem['local'] ?? '').toString().trim();
    final destino = (widget.blocoDestino['local'] ?? '').toString().trim();
    if (origem.isEmpty || destino.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Origem e destino precisam estar preenchidos para abrir a navegação.')),
      );
      return;
    }

    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'origin': origem,
      'destination': destino,
      'travelmode': mode,
    });

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o Google Maps neste dispositivo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pref = widget.modoPreferido ?? 'driving';
    final recommended = _recommendedMode;

    if (!_pediuCalculo && !loading && distancias == null && errorText == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            tooltip: 'Calcular tempo e distância até o próximo bloco',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () {
              setState(() => _pediuCalculo = true);
              _load();
            },
            icon: const Icon(Icons.alt_route_rounded, color: AppColors.accentOrange, size: 22),
          ),
        ),
      );
    }

    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentOrange)),
            SizedBox(width: 10),
            Text('A calcular deslocamento…', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
        ),
      );
    }
    if (errorText != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(errorText!, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), height: 1.3)),
            ),
            IconButton(
              tooltip: 'Tentar novamente',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.primaryBlue),
            ),
          ],
        ),
      );
    }
    final d = distancias;
    if (d == null) return const SizedBox.shrink();

    Widget linha(String key, IconData icon, String label) {
      final map = d[key] is Map ? Map<String, dynamic>.from(d[key] as Map) : null;
      final hasData = map != null && (map['tempo_minutos'] != null || map['distancia_km'] != null);
      final isPref = key == pref;
      final isRecommended = recommended != null && recommended == key;
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isRecommended ? AppColors.accentOrange : (isPref ? AppColors.primaryBlue : const Color(0xFF94A3B8))),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$label: ${_fmt(map)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: (isPref || isRecommended) ? FontWeight.w700 : FontWeight.w400,
                  color: (isPref || isRecommended) ? AppColors.darkGray : const Color(0xFF64748B),
                ),
              ),
            ),
            if (isRecommended)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.accentOrange),
                ),
                child: const Text('recomendado', style: TextStyle(fontSize: 10, color: AppColors.accentOrange)),
              )
            else if (isPref)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('preferido', style: TextStyle(fontSize: 10, color: AppColors.primaryBlue)),
              ),
            if (hasData) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Navegar no Google Maps',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                onPressed: () => _openNavigation(key),
                icon: const Icon(Icons.navigation_rounded, size: 18, color: AppColors.accentOrange),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10, top: 2),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.route_rounded, size: 18, color: AppColors.accentOrange),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Até "${(widget.blocoDestino['titulo'] ?? 'Próximo').toString()}"',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryBlue),
                ),
              ),
              IconButton(
                tooltip: 'Recalcular',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.primaryBlue),
              ),
            ],
          ),
          if (recommended != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDBA74)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, size: 15, color: AppColors.accentOrange),
                  const SizedBox(width: 6),
                  Text(
                    'Melhor opção agora: ${_modeLabel(recommended)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentOrange,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          linha('driving', Icons.directions_car_outlined, 'Carro'),
          linha('walking', Icons.directions_walk_outlined, 'A pé'),
          linha('transit', Icons.directions_transit_outlined, 'Transporte público'),
          const SizedBox(height: 4),
          const Text(
            'Estimativas Google; trânsito real pode variar.',
            style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}
