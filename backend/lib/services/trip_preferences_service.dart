import 'api_service.dart';

/// Preferências da viagem (`travel_preferences`), incl. `mobility_pref`: driving | walking | transit.
class TripPreferencesService {
  final ApiService api;
  TripPreferencesService(this.api);

  Future<Map<String, dynamic>?> get(int viagemId) async {
    final raw = await api.getRequest('/api/suggestions/preferences/$viagemId');
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  Future<Map<String, dynamic>> put(int viagemId, Map<String, dynamic> body) async {
    final raw = await api.putRequest('/api/suggestions/preferences/$viagemId', body);
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }
}
