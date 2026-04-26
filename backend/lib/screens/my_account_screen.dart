import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_input.dart';
import '../widgets/app_screen_chrome.dart';

class MyAccountScreen extends StatefulWidget {
  final AuthService authService;

  const MyAccountScreen({super.key, required this.authService});

  @override
  State<MyAccountScreen> createState() => _MyAccountScreenState();
}

class _MyAccountScreenState extends State<MyAccountScreen> {
  late final TextEditingController emailController;
  final TextEditingController senhaAtualController = TextEditingController();
  final TextEditingController novaSenhaController = TextEditingController();
  final TextEditingController confirmarSenhaController = TextEditingController();
  final TextEditingController inviteTokenController = TextEditingController();
  bool saving = false;
  bool acceptingInvite = false;
  bool loadingInvites = false;
  int? acceptingInviteId;
  int? decliningInviteId;
  List<Map<String, dynamic>> pendingInvites = [];
  String? errorText;

  UserModel? get user => widget.authService.currentUser;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController(text: user?.email ?? '');
    _loadPendingInvites();
  }

  @override
  void dispose() {
    emailController.dispose();
    senhaAtualController.dispose();
    novaSenhaController.dispose();
    confirmarSenhaController.dispose();
    inviteTokenController.dispose();
    super.dispose();
  }

  Future<void> _aceitarConvite() async {
    final token = inviteTokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o token do convite.')),
      );
      return;
    }
    setState(() => acceptingInvite = true);
    try {
      await widget.authService.acceptTripInvite(token);
      if (!mounted) return;
      inviteTokenController.clear();
      await _loadPendingInvites();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Convite aceito. A viagem já deve aparecer na Home.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao aceitar convite: $e')),
      );
    } finally {
      if (mounted) setState(() => acceptingInvite = false);
    }
  }

  Future<void> _loadPendingInvites() async {
    setState(() => loadingInvites = true);
    try {
      final invites = await widget.authService.getMyPendingInvites();
      if (!mounted) return;
      setState(() => pendingInvites = invites);
    } catch (_) {
      if (!mounted) return;
      setState(() => pendingInvites = []);
    } finally {
      if (mounted) setState(() => loadingInvites = false);
    }
  }

  Future<void> _aceitarConviteDaLista(Map<String, dynamic> invite) async {
    final token = (invite['token'] ?? '').toString();
    final inviteId = invite['id'];
    if (token.isEmpty) return;
    setState(() => acceptingInviteId = inviteId is int ? inviteId : null);
    try {
      await widget.authService.acceptTripInvite(token);
      if (!mounted) return;
      await _loadPendingInvites();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Convite aceito.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao aceitar convite: $e')),
      );
    } finally {
      if (mounted) setState(() => acceptingInviteId = null);
    }
  }

  Future<void> _recusarConviteDaLista(Map<String, dynamic> invite) async {
    final id = invite['id'];
    if (id is! int) return;
    setState(() => decliningInviteId = id);
    try {
      await widget.authService.declineTripInvite(id);
      if (!mounted) return;
      await _loadPendingInvites();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Convite recusado.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao recusar convite: $e')),
      );
    } finally {
      if (mounted) setState(() => decliningInviteId = null);
    }
  }

  Future<void> _alterarSenha() async {
    final email = emailController.text.trim();
    final senhaAtual = senhaAtualController.text.trim();
    final novaSenha = novaSenhaController.text.trim();
    final confirmarSenha = confirmarSenhaController.text.trim();

    if (email.isEmpty || senhaAtual.isEmpty || novaSenha.isEmpty || confirmarSenha.isEmpty) {
      setState(() => errorText = 'Preencha todos os campos para alterar a senha.');
      return;
    }
    if (novaSenha.length < 6) {
      setState(() => errorText = 'A nova senha deve ter pelo menos 6 caracteres.');
      return;
    }
    if (novaSenha != confirmarSenha) {
      setState(() => errorText = 'A confirmação da senha não confere.');
      return;
    }

    setState(() {
      saving = true;
      errorText = null;
    });
    try {
      await widget.authService.changePassword(
        email: email,
        senhaAtual: senhaAtual,
        novaSenha: novaSenha,
      );
      if (!mounted) return;
      senhaAtualController.clear();
      novaSenhaController.clear();
      confirmarSenhaController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Senha alterada com sucesso.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => errorText = 'Não foi possível alterar a senha.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = user;
    return Scaffold(
      appBar: AppScreenChrome.appBar(context, title: 'Minha conta'),
      body: AppGradientBackground(
        child: ListView(
          padding: AppLayout.screenPadding,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Agente Pessoal da Viagem', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Gerencie seus dados de acesso.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dados do perfil',
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                  ),
                  const SizedBox(height: 12),
                  Text('Nome: ${currentUser?.nome ?? '-'}'),
                  const SizedBox(height: 4),
                  Text('Tipo: ${currentUser?.tipo ?? '-'}'),
                  const SizedBox(height: 4),
                  Text('E-mail: ${currentUser?.email ?? '-'}'),
                ],
              ),
            ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Meus convites pendentes',
                          style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Atualizar convites',
                        onPressed: loadingInvites ? null : _loadPendingInvites,
                        icon: const Icon(Icons.refresh, color: AppColors.primaryBlue),
                      ),
                    ],
                  ),
                  if (loadingInvites)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: CircularProgressIndicator(color: AppColors.accentOrange),
                      ),
                    )
                  else if (pendingInvites.isEmpty)
                    const Text(
                      'Nenhum convite pendente no momento.',
                      style: TextStyle(fontSize: 13, color: AppColors.neutralGray),
                    )
                  else
                    ...pendingInvites.map((invite) {
                      final viagem = (invite['viagem_descricao'] ?? '').toString();
                      final role = (invite['role'] ?? '').toString();
                      final by = (invite['invited_by_nome'] ?? invite['invited_by_email'] ?? '').toString();
                      final id = invite['id'];
                      final isAcceptingThis = acceptingInviteId != null && id == acceptingInviteId;
                      final isDecliningThis = decliningInviteId != null && id == decliningInviteId;
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                viagem.isEmpty ? 'Viagem' : viagem,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text('Papel: $role · Convite por: $by', style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: AppButton(
                                      label: isAcceptingThis ? 'Aceitando...' : 'Aceitar convite',
                                      onPressed: (isAcceptingThis || isDecliningThis)
                                          ? null
                                          : () => _aceitarConviteDaLista(invite),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: AppButton(
                                      label: isDecliningThis ? 'Recusando...' : 'Recusar',
                                      onPressed: (isAcceptingThis || isDecliningThis)
                                          ? null
                                          : () => _recusarConviteDaLista(invite),
                                      type: AppButtonType.secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Aceitar convite por token',
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Cole o token recebido por e-mail para vincular este perfil a uma viagem.',
                    style: TextStyle(fontSize: 12, color: AppColors.neutralGray),
                  ),
                  const SizedBox(height: 10),
                  AppInput(label: 'Token do convite', controller: inviteTokenController),
                  const SizedBox(height: 12),
                  AppButton(
                    label: acceptingInvite ? 'Aceitando...' : 'Aceitar convite',
                    onPressed: acceptingInvite ? null : _aceitarConvite,
                  ),
                ],
              ),
            ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Alterar senha',
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                  ),
                  const SizedBox(height: 12),
                  AppInput(label: 'E-mail', controller: emailController),
                  const SizedBox(height: 10),
                  AppInput(label: 'Senha atual', controller: senhaAtualController, obscureText: true),
                  const SizedBox(height: 10),
                  AppInput(label: 'Nova senha', controller: novaSenhaController, obscureText: true),
                  const SizedBox(height: 10),
                  AppInput(
                    label: 'Confirmar nova senha',
                    controller: confirmarSenhaController,
                    obscureText: true,
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorText!,
                      style: const TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.w600),
                    ),
                  ],
                  const SizedBox(height: 16),
                  AppButton(
                    label: saving ? 'Salvando...' : 'Salvar nova senha',
                    onPressed: saving ? null : _alterarSenha,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
