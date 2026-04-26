import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/viagem.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/realtime_service.dart';
import 'trip_detail_screen.dart';
import 'my_account_screen.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_modal.dart';
import '../services/auth_service.dart';

/// Imagem de fundo da Home. Substitua `assets/images/home_background.png` por uma foto sua (mesmo nome).
const String _kHomeBackgroundAsset = 'assets/images/fundo.png';

class DateTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 8) return oldValue;

    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      if ((i == 1 || i == 3) && i != digits.length - 1) {
        buffer.write('/');
      }
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final ApiService api;
  final RealtimeService realtime;
  final AuthService authService;
  final VoidCallback onLogout;
  const HomeScreen({
    super.key,
    required this.api,
    required this.realtime,
    required this.authService,
    required this.onLogout,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Viagem> viagens = [];
  StreamSubscription<RealtimePush>? _realtimeSub;
  bool _pendingInvitesDialogShown = false;

  bool isValidDateBr(String value) {
    final match = RegExp(r'^(\d{2})\/(\d{2})\/(\d{4})$').firstMatch(value);
    if (match == null) return false;
    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    if (day == null || month == null || year == null) return false;
    final dt = DateTime.tryParse('$year-${match.group(2)}-${match.group(1)}');
    if (dt == null) return false;
    return dt.day == day && dt.month == month && dt.year == year;
  }

  String formatDateToBr(String value) {
    final br = RegExp(r'^(\d{2})\/(\d{2})\/(\d{4})$');
    if (br.hasMatch(value)) return value;

    final isoDateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
    final only = isoDateOnly.firstMatch(value);
    if (only != null) {
      return '${only.group(3)}/${only.group(2)}/${only.group(1)}';
    }

    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final dd = parsed.day.toString().padLeft(2, '0');
    final mm = parsed.month.toString().padLeft(2, '0');
    final yyyy = parsed.year.toString();
    return '$dd/$mm/$yyyy';
  }

  String formatDateRange(String start, String end) {
    return '${formatDateToBr(start)} até ${formatDateToBr(end)}';
  }

  Color statusColor(String status) {
    switch (status) {
      case 'Ativa':
        return const Color(0xFF10B981);
      case 'Cancelada':
        return const Color(0xFFFF6B35);
      case 'Finalizada':
        return const Color(0xFF0055CC);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  void initState() {
    super.initState();
    load();
    widget.realtime.connect();
    _realtimeSub = widget.realtime.pushes.listen(_onRealtimePush);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showPendingInvitesOnLogin();
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  void _onRealtimePush(RealtimePush p) {
    if (!mounted) return;
    switch (p.event) {
      case 'viagem_created':
      case 'viagem_updated':
      case 'viagem_deleted':
        load();
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Lista de viagens atualizada (tempo real).'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
        break;
      default:
        break;
    }
  }

  Future<void> load() async {
    final data = await widget.api.getRequest('/api/viagens');
    setState(() => viagens = (data as List<dynamic>).map((e) => Viagem.fromJson(e)).toList());
  }

  Future<void> addViagem() async {
    await openViagemForm();
  }

  Future<void> openViagemForm({Viagem? viagem}) async {
    final descricaoCtrl = TextEditingController();
    final iniCtrl = TextEditingController();
    final fimCtrl = TextEditingController();
    String situacao = viagem?.situacao ?? 'Ativa';
    if (viagem != null) {
      descricaoCtrl.text = viagem.descricao;
      iniCtrl.text = formatDateToBr(viagem.dataInicial);
      fimCtrl.text = formatDateToBr(viagem.dataFinal);
    }
    String? validationError;
    await showAppModal(
      context,
      StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> submit() async {
            final descricao = descricaoCtrl.text.trim();
            final dataInicial = iniCtrl.text.trim();
            final dataFinal = fimCtrl.text.trim();

            if (descricao.isEmpty || dataInicial.isEmpty || dataFinal.isEmpty) {
              setModalState(() => validationError = 'Preencha todos os campos obrigatorios.');
              return;
            }
            if (!isValidDateBr(dataInicial) || !isValidDateBr(dataFinal)) {
              setModalState(() => validationError = 'Use datas validas no formato DD/MM/AAAA.');
              return;
            }

            if (viagem != null) {
              await widget.api.putRequest('/api/viagens/${viagem.id}', {
                'descricao': descricao,
                'data_inicial': dataInicial,
                'data_final': dataFinal,
                'situacao': situacao,
              });
            } else {
              await widget.api.postRequest('/api/viagens', {
                'descricao': descricao,
                'data_inicial': dataInicial,
                'data_final': dataFinal,
                'situacao': situacao,
              });
            }
            if (!context.mounted) return;
            Navigator.pop(context);
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('✈️ Nova viagem', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(controller: descricaoCtrl, decoration: const InputDecoration(labelText: 'Descrição')),
              const SizedBox(height: 12),
              TextField(
                controller: iniCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [DateTextInputFormatter()],
                decoration: const InputDecoration(labelText: 'Data inicial (DD/MM/AAAA)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: fimCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [DateTextInputFormatter()],
                decoration: const InputDecoration(labelText: 'Data final (DD/MM/AAAA)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: situacao,
                decoration: const InputDecoration(labelText: 'Situação da viagem'),
                items: const [
                  DropdownMenuItem(value: 'Ativa', child: Text('Ativa')),
                  DropdownMenuItem(value: 'Cancelada', child: Text('Cancelada')),
                  DropdownMenuItem(value: 'Finalizada', child: Text('Finalizada')),
                ],
                onChanged: (value) => setModalState(() => situacao = value ?? 'Ativa'),
              ),
              if (validationError != null) ...[
                const SizedBox(height: 12),
                Text(validationError!, style: const TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 16),
              AppButton(label: viagem == null ? 'Salvar viagem' : 'Salvar alterações', onPressed: submit),
            ],
          );
        },
      ),
    );
    await load();
  }

  /// Fundo: gradiente base + imagem opcional + véu claro para o texto continuar legível.
  Widget _homeBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: AppGradients.screenBackground),
        ),
        Positioned.fill(
          child: Image.asset(
            _kHomeBackgroundAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.78),
                  Colors.white.withValues(alpha: 0.88),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> deleteViagem(Viagem viagem) async {
    await widget.api.deleteRequest('/api/viagens/${viagem.id}');
    await load();
  }

  Future<void> _showPendingInvitesOnLogin() async {
    if (!mounted || _pendingInvitesDialogShown) return;
    _pendingInvitesDialogShown = true;

    List<Map<String, dynamic>> invites = [];
    try {
      invites = await widget.authService.getMyPendingInvites();
    } catch (_) {
      return;
    }
    if (!mounted || invites.isEmpty) return;

    int? processingInviteId;

    Future<void> refreshInvites(StateSetter setModalState) async {
      try {
        final fresh = await widget.authService.getMyPendingInvites();
        if (!mounted) return;
        setModalState(() => invites = fresh);
      } catch (_) {}
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            title: const Text('Convites pendentes'),
            content: SizedBox(
              width: 520,
              child: invites.isEmpty
                  ? const Text('Você não possui mais convites pendentes.')
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: invites.map((invite) {
                          final id = invite['id'];
                          final inviteId = id is int ? id : int.tryParse(id.toString());
                          final viagem = (invite['viagem_descricao'] ?? '').toString();
                          final role = (invite['role'] ?? '').toString();
                          final by = (invite['invited_by_nome'] ?? invite['invited_by_email'] ?? '').toString();
                          final isProcessing = inviteId != null && processingInviteId == inviteId;

                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
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
                                        label: isProcessing ? 'Processando...' : 'Aceitar',
                                        onPressed: (isProcessing || inviteId == null)
                                            ? null
                                            : () async {
                                                setModalState(() => processingInviteId = inviteId);
                                                try {
                                                  final token = (invite['token'] ?? '').toString();
                                                  await widget.authService.acceptTripInvite(token);
                                                  if (!mounted) return;
                                                  await load();
                                                  await refreshInvites(setModalState);
                                                  if (!mounted) return;
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Convite aceito.')),
                                                  );
                                                } catch (e) {
                                                  if (!mounted) return;
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Erro ao aceitar convite: $e')),
                                                  );
                                                } finally {
                                                  if (ctx.mounted) setModalState(() => processingInviteId = null);
                                                }
                                              },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: AppButton(
                                        label: isProcessing ? 'Processando...' : 'Recusar',
                                        type: AppButtonType.secondary,
                                        onPressed: (isProcessing || inviteId == null)
                                            ? null
                                            : () async {
                                                setModalState(() => processingInviteId = inviteId);
                                                try {
                                                  await widget.authService.declineTripInvite(inviteId);
                                                  if (!mounted) return;
                                                  await refreshInvites(setModalState);
                                                  if (!mounted) return;
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Convite recusado.')),
                                                  );
                                                } catch (e) {
                                                  if (!mounted) return;
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Erro ao recusar convite: $e')),
                                                  );
                                                } finally {
                                                  if (ctx.mounted) setModalState(() => processingInviteId = null);
                                                }
                                              },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fechar'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTrips = viagens.where((v) => v.situacao == 'Ativa');
    final activeTrip = activeTrips.isNotEmpty ? activeTrips.first : (viagens.isNotEmpty ? viagens.first : null);
    final otherTrips = activeTrip == null ? viagens : viagens.where((v) => v.id != activeTrip.id).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nova viagem',
        onPressed: addViagem,
        child: const Icon(Icons.add),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _homeBackground(),
          SafeArea(
            child: viagens.isEmpty ? _buildEmptyState(context) : _buildContent(context, activeTrip, otherTrips),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, Viagem? activeTrip, List<Viagem> otherTrips) {
    final nomePerfil = widget.authService.currentUser?.nome.trim();
    final saudacaoNome = (nomePerfil == null || nomePerfil.isEmpty) ? 'Viajante' : nomePerfil;
    return RefreshIndicator(
      color: AppColors.accentOrange,
      onRefresh: load,
      child: ListView(
        padding: AppLayout.screenPadding,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Olá, $saudacaoNome!',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ),
              ValueListenableBuilder<RealtimeConnectionStatus>(
                valueListenable: widget.realtime.status,
                builder: (context, st, _) {
                  late final IconData icon;
                  late final String label;
                  late final Color color;
                  switch (st) {
                    case RealtimeConnectionStatus.connected:
                      icon = Icons.cloud_done_outlined;
                      label = 'Ao vivo';
                      color = const Color(0xFF059669);
                      break;
                    case RealtimeConnectionStatus.connecting:
                      icon = Icons.cloud_sync_outlined;
                      label = 'A ligar…';
                      color = AppColors.accentOrange;
                      break;
                    case RealtimeConnectionStatus.reconnecting:
                      icon = Icons.cloud_queue_outlined;
                      label = 'A reconectar…';
                      color = AppColors.accentOrange;
                      break;
                    case RealtimeConnectionStatus.disconnected:
                      icon = Icons.cloud_off_outlined;
                      label = 'Tempo real off';
                      color = const Color(0xFF94A3B8);
                      break;
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Tooltip(
                      message: 'Atualizações em tempo real do servidor',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 18, color: color),
                          const SizedBox(width: 4),
                          Text(
                            label,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                tooltip: 'Minha conta',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MyAccountScreen(authService: widget.authService),
                    ),
                  );
                },
                icon: const Icon(Icons.person_outline, color: AppColors.primaryBlue),
              ),
              IconButton(
                tooltip: 'Sair',
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout_rounded, color: AppColors.primaryBlue),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Gerenciar Viagem', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (activeTrip != null) _nextTripBanner(context, activeTrip),
          if (otherTrips.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Outras Viagens', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...otherTrips.map((trip) => _tripListTile(context, trip)),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.luggage_rounded, size: 80, color: AppColors.primaryBlue),
            const SizedBox(height: 16),
            const Text(
              'Nenhuma viagem cadastrada ainda.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Toque no botão + no canto inferior direito para criar sua primeira viagem e organizar cidades, hotéis e passeios.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _nextTripBanner(BuildContext context, Viagem trip) {
    final status = statusColor(trip.situacao);
    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TripDetailScreen(api: widget.api, viagem: trip, realtime: widget.realtime),
          ),
        );
        if (mounted) await load();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              trip.descricao,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              formatDateRange(trip.dataInicial, trip.dataFinal),
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: status.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                trip.situacao,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tripListTile(BuildContext context, Viagem v) {
    return AppCard(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TripDetailScreen(api: widget.api, viagem: v, realtime: widget.realtime),
          ),
        );
        if (mounted) await load();
      },
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.flight_takeoff_rounded, color: AppColors.primaryBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v.descricao,
                  style: const TextStyle(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(formatDateRange(v.dataInicial, v.dataFinal)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Editar viagem',
            onPressed: () async => openViagemForm(viagem: v),
            icon: const Icon(Icons.edit_outlined, color: AppColors.accentOrange),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ],
      ),
    );
  }
}
