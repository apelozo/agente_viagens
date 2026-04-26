import 'package:flutter/material.dart';

import '../models/viagem.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_screen_chrome.dart';

const _categorias = ['Comer', 'Visitar', 'Comprar', 'Outras'];
const _statusValues = ['nao_visitado', 'planejado', 'concluido', 'descartado'];

String _statusLabel(String s) {
  switch (s) {
    case 'nao_visitado':
      return 'Não visitado';
    case 'planejado':
      return 'Planejado';
    case 'concluido':
      return 'Concluído';
    case 'descartado':
      return 'Descartado';
    default:
      return s;
  }
}

/// Cadastro/edição manual de item da Wishlist no padrão visual do app (igual ao cadastro de cidades).
class WishlistItemFormScreen extends StatefulWidget {
  final ApiService api;
  final Viagem viagem;
  final Map<String, dynamic>? item;

  const WishlistItemFormScreen({
    super.key,
    required this.api,
    required this.viagem,
    this.item,
  });

  @override
  State<WishlistItemFormScreen> createState() => _WishlistItemFormScreenState();
}

class _WishlistItemFormScreenState extends State<WishlistItemFormScreen> {
  final nomeCtrl = TextEditingController();
  final endCtrl = TextEditingController();
  final notaCtrl = TextEditingController();
  final linkCtrl = TextEditingController();
  final nomeFocus = FocusNode();
  final endFocus = FocusNode();
  final linkFocus = FocusNode();
  final notaFocus = FocusNode();

  String categoria = 'Visitar';
  String status = 'nao_visitado';
  String? error;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    if (it == null) return;
    nomeCtrl.text = (it['nome'] ?? '').toString();
    endCtrl.text = (it['endereco'] ?? '').toString();
    notaCtrl.text = (it['nota'] ?? '').toString();
    linkCtrl.text = (it['link_url'] ?? '').toString();
    categoria = (it['categoria'] ?? 'Visitar').toString();
    status = (it['status'] ?? 'nao_visitado').toString();
    if (!_categorias.contains(categoria)) categoria = 'Visitar';
    if (!_statusValues.contains(status)) status = 'nao_visitado';
  }

  @override
  void dispose() {
    nomeCtrl.dispose();
    endCtrl.dispose();
    notaCtrl.dispose();
    linkCtrl.dispose();
    nomeFocus.dispose();
    endFocus.dispose();
    linkFocus.dispose();
    notaFocus.dispose();
    super.dispose();
  }

  String get _screenTitle => widget.item == null ? 'Novo desejo' : 'Editar item';

  Future<void> _submit() async {
    if (nomeCtrl.text.trim().isEmpty) {
      setState(() => error = 'Nome é obrigatório.');
      return;
    }
    setState(() {
      error = null;
      saving = true;
    });
    try {
      final payload = <String, dynamic>{
        'nome': nomeCtrl.text.trim(),
        'categoria': categoria,
        'endereco': endCtrl.text.trim().isEmpty ? null : endCtrl.text.trim(),
        'link_url': linkCtrl.text.trim().isEmpty ? null : linkCtrl.text.trim(),
        'nota': notaCtrl.text.trim().isEmpty ? null : notaCtrl.text.trim(),
        'status': status,
      };

      if (widget.item == null) {
        await widget.api.postRequest('/api/wishlist/${widget.viagem.id}', payload);
      } else {
        await widget.api.putRequest('/api/wishlist/item/${widget.item!['id']}', payload);
      }

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
      appBar: AppScreenChrome.appBar(context, title: _screenTitle),
      body: AppGradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: AppLayout.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Dados do item', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextField(
                  controller: nomeCtrl,
                  focusNode: nomeFocus,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => FocusScope.of(context).requestFocus(endFocus),
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: categoria,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: _categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: saving ? null : (v) => setState(() => categoria = v ?? 'Visitar'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: _statusValues.map((s) => DropdownMenuItem(value: s, child: Text(_statusLabel(s)))).toList(),
                  onChanged: saving ? null : (v) => setState(() => status = v ?? 'nao_visitado'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: endCtrl,
                  focusNode: endFocus,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => FocusScope.of(context).requestFocus(linkFocus),
                  decoration: const InputDecoration(labelText: 'Endereço (opcional)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: linkCtrl,
                  focusNode: linkFocus,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => FocusScope.of(context).requestFocus(notaFocus),
                  decoration: const InputDecoration(
                    labelText: 'Link (opcional)',
                    helperText: 'Instagram, Facebook, TikTok, YouTube ou qualquer URL web',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notaCtrl,
                  focusNode: notaFocus,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Nota (opcional)'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.w700)),
                ],
                const SizedBox(height: 18),
                AppButton(
                  label: saving ? 'Salvando…' : 'Salvar',
                  onPressed: saving ? null : _submit,
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

