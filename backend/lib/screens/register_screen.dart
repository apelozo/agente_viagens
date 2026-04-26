import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_input.dart';

class RegisterScreen extends StatefulWidget {
  final AuthService authService;
  final VoidCallback onBack;
  const RegisterScreen({super.key, required this.authService, required this.onBack});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nomeController = TextEditingController();
  final emailController = TextEditingController();
  final senhaController = TextEditingController();
  String tipo = 'Usuario';
  String status = 'Ativa';

  Future<void> submit() async {
    await widget.authService.register(
      nomeController.text.trim(),
      tipo,
      emailController.text.trim(),
      senhaController.text.trim(),
      status: status,
    );
    if (mounted) widget.onBack();
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
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('👤 Cadastro', style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 8),
                    Text('Crie um perfil de usuario comum ou agente de viagem.', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 24),
                    AppInput(label: 'Nome', controller: nomeController),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: tipo,
                      items: const [
                        DropdownMenuItem(value: 'Usuario', child: Text('Usuário')),
                        DropdownMenuItem(value: 'Agente de Viagem', child: Text('Agente de Viagem')),
                      ],
                      onChanged: (v) => setState(() => tipo = v ?? 'Usuario'),
                      decoration: const InputDecoration(labelText: 'Tipo'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      items: const [
                        DropdownMenuItem(value: 'Ativa', child: Text('Ativa')),
                        DropdownMenuItem(value: 'Cancelada', child: Text('Cancelada')),
                        DropdownMenuItem(value: 'Finalizada', child: Text('Finalizada')),
                      ],
                      onChanged: (v) => setState(() => status = v ?? 'Ativa'),
                      decoration: const InputDecoration(labelText: 'Status da conta'),
                    ),
                    const SizedBox(height: 12),
                    AppInput(label: 'E-mail', controller: emailController),
                    const SizedBox(height: 12),
                    AppInput(label: 'Senha', controller: senhaController, obscureText: true),
                    const SizedBox(height: 16),
                    AppButton(label: 'Salvar cadastro', onPressed: submit),
                    const SizedBox(height: 8),
                    AppButton(label: 'Voltar', onPressed: widget.onBack, type: AppButtonType.secondary),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
