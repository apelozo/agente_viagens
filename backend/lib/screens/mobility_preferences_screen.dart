import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/trip_preferences_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_screen_chrome.dart';

/// Tela de configuração de mobilidade (padrão visual do app).
class MobilityPreferencesScreen extends StatefulWidget {
  final ApiService api;
  final int viagemId;
  final Map<String, dynamic>? current;

  const MobilityPreferencesScreen({
    super.key,
    required this.api,
    required this.viagemId,
    this.current,
  });

  @override
  State<MobilityPreferencesScreen> createState() => _MobilityPreferencesScreenState();
}

class _MobilityPreferencesScreenState extends State<MobilityPreferencesScreen> {
  Map<String, dynamic>? prefs;
  bool loading = true;
  bool saving = false;
  String modo = 'driving';
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      prefs = widget.current ?? await TripPreferencesService(widget.api).get(widget.viagemId);
      modo = (prefs?['mobility_pref'] ?? 'driving').toString().trim();
      if (modo != 'walking' && modo != 'transit' && modo != 'driving') modo = 'driving';
    } catch (e) {
      error = 'Falha ao carregar preferências: $e';
      prefs = widget.current;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _save() async {
    final svc = TripPreferencesService(widget.api);
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final current = prefs ?? await svc.get(widget.viagemId);
      await svc.put(widget.viagemId, {
        'prefer_categorias': current?['prefer_categorias'],
        'dietary': current?['dietary'],
        'budget_level': current?['budget_level'],
        'pace': current?['pace'],
        'touristic_level': current?['touristic_level'],
        'mobility_pref': modo,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = 'Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppScreenChrome.appBar(context, title: 'Mobilidade nesta viagem'),
      body: AppGradientBackground(
        child: SafeArea(
          child: loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.accentOrange))
              : SingleChildScrollView(
                  padding: AppLayout.screenPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Preferência de deslocamento', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      const Text(
                        'Define qual modal fica em destaque quando você calcular o tempo entre eventos.',
                        style: TextStyle(fontSize: 13, color: AppColors.neutralGray),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: modo,
                        decoration: const InputDecoration(labelText: 'Prioridade de deslocamento'),
                        items: const [
                          DropdownMenuItem(value: 'driving', child: Text('Carro')),
                          DropdownMenuItem(value: 'walking', child: Text('A pé')),
                          DropdownMenuItem(value: 'transit', child: Text('Transporte público')),
                        ],
                        onChanged: saving ? null : (v) => setState(() => modo = v ?? 'driving'),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(error!, style: const TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.w700)),
                      ],
                      const SizedBox(height: 18),
                      AppButton(
                        label: saving ? 'Salvando…' : 'Guardar',
                        onPressed: saving ? null : _save,
                      ),
                      const SizedBox(height: 8),
                      AppButton(
                        label: 'Cancelar',
                        type: AppButtonType.secondary,
                        onPressed: saving ? null : () => Navigator.pop(context, false),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

