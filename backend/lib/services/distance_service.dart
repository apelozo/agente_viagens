import 'api_service.dart';

class DistanceService {
  final ApiService api;
  DistanceService(this.api);

  Future<Map<String, dynamic>> calculate({
    required double origemLat,
    required double origemLng,
    required double destinoLat,
    required double destinoLng,
  }) async {
    final data = await api.postRequest('/api/distance/calculate', {
      'origem': {'latitude': origemLat, 'longitude': origemLng},
      'destino': {'latitude': destinoLat, 'longitude': destinoLng},
    });
    return Map<String, dynamic>.from(data);
  }
}
