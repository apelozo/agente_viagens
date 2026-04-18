import 'package:shared_preferences/shared_preferences.dart';

/// Guarda localmente o e-mail para pré-preencher o login ("Lembrar de mim").
/// A palavra-passe nunca é armazenada.
class LoginRememberService {
  static const _rememberKey = 'login_remember_me';
  static const _emailKey = 'login_remember_email';

  static Future<bool> isRememberEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_rememberKey) ?? false;
  }

  static Future<String?> savedEmail() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_emailKey);
  }

  static Future<void> save({required bool remember, required String email}) async {
    final p = await SharedPreferences.getInstance();
    if (remember && email.trim().isNotEmpty) {
      await p.setBool(_rememberKey, true);
      await p.setString(_emailKey, email.trim());
    } else {
      await p.setBool(_rememberKey, false);
      await p.remove(_emailKey);
    }
  }
}
