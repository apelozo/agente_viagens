import 'api_service.dart';

class MobilityService {
  final ApiService api;
  MobilityService(this.api);

  Future<Map<String, dynamic>> estimate({
    required double origemLat,
    required double origemLng,
    required double destinoLat,
    required double destinoLng,
    String mode = 'driving',
  }) async {
    final data = await api.postRequest('/api/mobility/estimate', {
      'origem': {'latitude': origemLat, 'longitude': origemLng},
      'destino': {'latitude': destinoLat, 'longitude': destinoLng},
      'mode': mode,
      'departure_time': 'now',
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> compare({
    required double origemLat,
    required double origemLng,
    required double destinoLat,
    required double destinoLng,
    List<String> modes = const ['driving', 'walking', 'transit'],
  }) async {
    final data = await api.postRequest('/api/mobility/compare', {
      'origem': {'latitude': origemLat, 'longitude': origemLng},
      'destino': {'latitude': destinoLat, 'longitude': destinoLng},
      'modes': modes,
      'departure_time': 'now',
    });
    return Map<String, dynamic>.from(data as Map);
  }
}
