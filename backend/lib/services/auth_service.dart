import '../models/user.dart';
import 'api_service.dart';

class AuthService {
  final ApiService api;
  UserModel? currentUser;
  AuthService(this.api);

  Future<UserModel> login(String email, String senha) async {
    final data = await api.postRequest('/api/auth/login', {'email': email, 'senha': senha});
    api.token = data['token'];
    currentUser = UserModel.fromJson(data['user']);
    return currentUser!;
  }

  Future<void> register(String nome, String tipo, String email, String senha, {String status = 'Ativa'}) async {
    await api.postRequest('/api/auth/register', {
      'nome': nome,
      'tipo': tipo,
      'email': email,
      'senha': senha,
      'status': status,
    });
  }

  Future<void> forgotPassword(String email) async {
    await api.postRequest('/api/auth/forgot-password', {
      'email': email,
    });
  }

  Future<void> changePassword({
    required String email,
    required String senhaAtual,
    required String novaSenha,
  }) async {
    await api.postRequest('/api/auth/change-password', {
      'email': email,
      'senhaAtual': senhaAtual,
      'novaSenha': novaSenha,
    });
  }

  Future<void> acceptTripInvite(String token) async {
    await api.postRequest('/api/viagens/invites/accept', {
      'token': token,
    });
  }

  Future<void> declineTripInvite(int inviteId) async {
    await api.postRequest('/api/viagens/invites/decline', {
      'invite_id': inviteId,
    });
  }

  Future<List<Map<String, dynamic>>> getMyPendingInvites() async {
    final data = await api.getRequest('/api/viagens/invites/pending') as List<dynamic>;
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  void logout() {
    api.token = null;
    currentUser = null;
  }
}
