import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.5.106:5000',
  );
  String? token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> getRequest(String path) async {
    final response = await http.get(Uri.parse('$baseUrl$path'), headers: _headers);
    return _decode(response);
  }

  Future<dynamic> postRequest(String path, Map<String, dynamic> body) async {
    final response = await http.post(Uri.parse('$baseUrl$path'), headers: _headers, body: jsonEncode(body));
    return _decode(response);
  }

  Future<dynamic> putRequest(String path, Map<String, dynamic> body) async {
    final response = await http.put(Uri.parse('$baseUrl$path'), headers: _headers, body: jsonEncode(body));
    return _decode(response);
  }

  Future<void> deleteRequest(String path) async {
    final response = await http.delete(Uri.parse('$baseUrl$path'), headers: _headers);
    if (response.statusCode >= 400) {
      throw Exception(response.body);
    }
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode >= 400) throw Exception(response.body);
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }
}
