import 'package:flutter/material.dart';
import '../services/auth_service.dart';
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

  Future<void> submit() async {
    try {
      await widget.authService.login(emailController.text.trim(), senhaController.text.trim());
      widget.onLogin();
    } catch (e) {
      setState(() => error = 'Falha no login');
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
                      Text('✈️ Agente Pessoal da Viagem', style: Theme.of(context).textTheme.headlineLarge),
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
                      const SizedBox(height: 16),
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
