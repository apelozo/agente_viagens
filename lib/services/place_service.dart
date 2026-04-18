import 'api_service.dart';

class PlaceService {
  final ApiService api;
  PlaceService(this.api);

  Future<List<dynamic>> search({
    required double latitude,
    required double longitude,
    required String tipoLugar,
    required String query,
  }) async {
    final data = await api.postRequest('/api/places/search', {
      'latitude': latitude,
      'longitude': longitude,
      'tipo_lugar': tipoLugar,
      'query': query,
    });
    return (data as List<dynamic>);
  }
}
