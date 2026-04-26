import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import '../services/login_remember_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_input.dart';

class LoginScreen extends StatefulWidget {
  final AuthService authService;
  final void Function() onLogin;
  final VoidCallback onGoRegister;
  const LoginScreen({super.key, required this.authService, required this.onLogin, required this.onGoRegister});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final senhaController = TextEditingController();
  String? error;
  bool _rememberMe = false;
  bool _prefsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadRememberPrefs();
  }

  Future<void> _loadRememberPrefs() async {
    final remember = await LoginRememberService.isRememberEnabled();
    final email = await LoginRememberService.savedEmail();
    final password = await LoginRememberService.savedPassword();
    if (!mounted) return;
    setState(() {
      _rememberMe = remember;
      if (remember && email != null && email.isNotEmpty) {
        emailController.text = email;
      }
      if (remember && password != null && password.isNotEmpty) {
        senhaController.text = password;
      }
      _prefsLoaded = true;
    });
  }

  @override
  void dispose() {
    emailController.dispose();
    senhaController.dispose();
    super.dispose();
  }

  String _extractApiMessage(Object error) {
    final raw = error.toString();
    final prefix = 'Exception:';
    final cleaned = raw.startsWith(prefix) ? raw.substring(prefix.length).trim() : raw;
    if (cleaned.startsWith('{') || cleaned.startsWith('[')) {
      try {
        final decoded = jsonDecode(cleaned);
        if (decoded is Map && decoded['message'] != null) {
          return decoded['message'].toString();
        }
      } catch (_) {
        // Keep raw message if payload is not valid JSON.
      }
    }
    return cleaned;
  }

  String _friendlyLoginError(Object error) {
    final msg = _extractApiMessage(error).trim();
    final lower = msg.toLowerCase();
    if (lower.contains('credenciais inválidas') || lower.contains('credenciais invalidas')) {
      return 'E-mail ou senha inválidos.';
    }
    if (lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('connection closed') ||
        lower.contains('socketexception') ||
        lower.contains('xmlhttprequest error')) {
      return 'Não foi possível conectar à API. Verifique se o backend está ativo e a URL configurada.';
    }
    if (lower.contains('timeout')) {
      return 'A API demorou para responder. Tente novamente em instantes.';
    }
    if (lower.contains('500') ||
        lower.contains('internal server error') ||
        lower.contains('jwt_secret')) {
      return 'Erro interno no servidor. Confira os logs do backend.';
    }
    return msg.isNotEmpty ? msg : 'Falha no login.';
  }

  Future<void> submit() async {
    setState(() => error = null);
    try {
      await widget.authService.login(emailController.text.trim(), senhaController.text.trim());
      await LoginRememberService.save(
        remember: _rememberMe,
        email: emailController.text.trim(),
        password: senhaController.text,
      );
      if (!mounted) return;
      widget.onLogin();
    } catch (e) {
      if (!mounted) return;
      setState(() => error = _friendlyLoginError(e));
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailCtrl = TextEditingController(text: emailController.text.trim());
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Esqueci minha senha'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Informe seu e-mail para receber uma senha temporária.',
              style: TextStyle(fontSize: 13, color: AppColors.neutralGray),
            ),
            const SizedBox(height: 12),
            AppInput(label: 'E-mail', controller: emailCtrl),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              try {
                await widget.authService.forgotPassword(emailCtrl.text.trim());
                if (!mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Se o e-mail existir, enviamos uma senha temporária.')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
              }
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final emailCtrl = TextEditingController(text: emailController.text.trim());
    final atualCtrl = TextEditingController();
    final novaCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alterar senha'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppInput(label: 'E-mail', controller: emailCtrl),
              const SizedBox(height: 10),
              AppInput(label: 'Senha atual', controller: atualCtrl, obscureText: true),
              const SizedBox(height: 10),
              AppInput(label: 'Nova senha', controller: novaCtrl, obscureText: true),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              try {
                await widget.authService.changePassword(
                  email: emailCtrl.text.trim(),
                  senhaAtual: atualCtrl.text.trim(),
                  novaSenha: novaCtrl.text.trim(),
                );
                if (!mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Senha alterada com sucesso.')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.screenBackground),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: AppLayout.screenPadding,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Agente Pessoal da Viagem', style: Theme.of(context).textTheme.headlineLarge),
                      const SizedBox(height: 8),
                      Text(
                        'Acesse sua conta para gerenciar itinerarios, reservas e passeios.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      AppInput(
                        label: 'E-mail',
                        controller: emailController,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      AppInput(
                        label: 'Senha',
                        controller: senhaController,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => submit(),
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _rememberMe,
                        onChanged: _prefsLoaded
                            ? (v) => setState(() => _rememberMe = v ?? false)
                            : null,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          'Lembrar usuário e senha',
                          style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      AppButton(label: 'Entrar', onPressed: submit),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _showForgotPasswordDialog,
                          child: const Text('Esqueci minha senha'),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _showChangePasswordDialog,
                          child: const Text('Alterar senha'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      AppButton(label: 'Criar conta', onPressed: widget.onGoRegister, type: AppButtonType.secondary),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          error!,
                          style: const TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
