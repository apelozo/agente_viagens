import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

/// Guarda localmente o e-mail para pré-preencher o login ("Lembrar de mim").
/// Pode guardar também a palavra-passe quando o utilizador optar por lembrar.
class LoginRememberService {
  static const _rememberKey = 'login_remember_me';
  static const _emailKey = 'login_remember_email';
  static const _passwordKey = 'login_remember_password';

  static Future<SharedPreferences?> _prefsOrNull() async {
    try {
      return await SharedPreferences.getInstance();
    } on MissingPluginException {
      // Em alguns builds/plataformas o plugin pode não estar registrado.
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<bool> isRememberEnabled() async {
    final p = await _prefsOrNull();
    if (p == null) return false;
    return p.getBool(_rememberKey) ?? false;
  }

  static Future<String?> savedEmail() async {
    final p = await _prefsOrNull();
    if (p == null) return null;
    return p.getString(_emailKey);
  }

  static Future<String?> savedPassword() async {
    final p = await _prefsOrNull();
    if (p == null) return null;
    return p.getString(_passwordKey);
  }

  static Future<void> save({
    required bool remember,
    required String email,
    required String password,
  }) async {
    final p = await _prefsOrNull();
    if (p == null) return;
    if (remember && email.trim().isNotEmpty) {
      await p.setBool(_rememberKey, true);
      await p.setString(_emailKey, email.trim());
      await p.setString(_passwordKey, password);
    } else {
      await p.setBool(_rememberKey, false);
      await p.remove(_emailKey);
      await p.remove(_passwordKey);
    }
  }
}
