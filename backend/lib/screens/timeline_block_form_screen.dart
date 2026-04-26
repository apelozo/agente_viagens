import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_screen_chrome.dart';

class _DateTextInputFormatter extends TextInputFormatter {
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
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

class _TimeTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 4) return oldValue;

    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      if (i == 1 && i != digits.length - 1) buffer.write(':');
    }
    final text = buffer.toString();
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

TimeOfDay _timeOfDayFromField(String text) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(text.trim());
  if (m != null) {
    return TimeOfDay(hour: int.parse(m.group(1)!), minute: int.parse(m.group(2)!));
  }
  return TimeOfDay.now();
}

/// Cadastro/edição de um bloco de timeline no mesmo padrão visual do cadastro de cidades.
class TimelineBlockFormScreen extends StatefulWidget {
  final ApiService api;
  final int viagemId;
  final String viagemDataInicial;
  final String viagemDataFinal;
  final Map<String, dynamic>? item;

  const TimelineBlockFormScreen({
    super.key,
    required this.api,
    required this.viagemId,
    required this.viagemDataInicial,
    required this.viagemDataFinal,
    this.item,
  });

  @override
  State<TimelineBlockFormScreen> createState() => _TimelineBlockFormScreenState();
}

class _TimelineBlockFormScreenState extends State<TimelineBlockFormScreen> {
  final titleCtrl = TextEditingController();
  final dateCtrl = TextEditingController();
  final startCtrl = TextEditingController();
  final endCtrl = TextEditingController();
  final localCtrl = TextEditingController();
  final linkCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final titleFocus = FocusNode();
  final dateFocus = FocusNode();
  final startFocus = FocusNode();
  final endFocus = FocusNode();
  final localFocus = FocusNode();
  final linkFocus = FocusNode();
  final descFocus = FocusNode();

  String tipo = 'Evento Fixo';
  String? error;
  bool saving = false;

  DateTime? _parseDateBr(String value) {
    final m = RegExp(r'^(\d{2})\/(\d{2})\/(\d{4})$').firstMatch(value.trim());
    if (m == null) return null;
    final d = int.tryParse(m.group(1)!);
    final mo = int.tryParse(m.group(2)!);
    final y = int.tryParse(m.group(3)!);
    if (d == null || mo == null || y == null) return null;
    final dt = DateTime.tryParse('${m.group(3)}-${m.group(2)}-${m.group(1)}');
    if (dt == null) return null;
    if (dt.day != d || dt.month != mo || dt.year != y) return null;
    return DateTime(dt.year, dt.month, dt.day);
  }

  DateTime? _parseApiDate(String value) {
    final raw = value.trim();
    final br = _parseDateBr(raw);
    if (br != null) return br;
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
    if (iso == null) return null;
    final dt = DateTime.tryParse('${iso.group(1)}-${iso.group(2)}-${iso.group(3)}');
    if (dt == null) return null;
    return DateTime(dt.year, dt.month, dt.day);
  }

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item == null) return;
    titleCtrl.text = (item['titulo'] ?? '').toString();
    dateCtrl.text = (item['data'] ?? '').toString();
    startCtrl.text = (item['hora_inicio'] ?? '').toString();
    endCtrl.text = (item['hora_fim'] ?? '').toString();
    localCtrl.text = (item['local'] ?? '').toString();
    linkCtrl.text = (item['link_url'] ?? '').toString();
    descCtrl.text = (item['descricao'] ?? '').toString();
    tipo = (item['tipo'] ?? 'Evento Fixo').toString();
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    dateCtrl.dispose();
    startCtrl.dispose();
    endCtrl.dispose();
    localCtrl.dispose();
    linkCtrl.dispose();
    descCtrl.dispose();
    titleFocus.dispose();
    dateFocus.dispose();
    startFocus.dispose();
    endFocus.dispose();
    localFocus.dispose();
    linkFocus.dispose();
    descFocus.dispose();
    super.dispose();
  }

  String get _screenTitle => widget.item == null ? 'Novo evento da timeline' : 'Editar evento';

  Future<void> _pickDate() async {
    DateTime? initialDate;
    final dateText = dateCtrl.text.trim();
    final match = RegExp(r'^(\d{2})\/(\d{2})\/(\d{4})$').firstMatch(dateText);
    if (match != null) {
      initialDate = DateTime.tryParse('${match.group(3)}-${match.group(2)}-${match.group(1)}');
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final dd = picked.day.toString().padLeft(2, '0');
    final mm = picked.month.toString().padLeft(2, '0');
    final yyyy = picked.year.toString();
    setState(() => dateCtrl.text = '$dd/$mm/$yyyy');
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _timeOfDayFromField(controller.text),
    );
    if (picked == null) return;
    final hh = picked.hour.toString().padLeft(2, '0');
    final mm = picked.minute.toString().padLeft(2, '0');
    setState(() => controller.text = '$hh:$mm');
  }

  Future<void> _submit() async {
    final titulo = titleCtrl.text.trim();
    final data = dateCtrl.text.trim();
    if (titulo.isEmpty || data.isEmpty) {
      setState(() => error = 'Nome do evento e data do evento são obrigatórios.');
      return;
    }

    final dataEvento = _parseDateBr(data);
    if (dataEvento == null) {
      setState(() => error = 'Use uma data válida no formato DD/MM/AAAA.');
      return;
    }

    final inicioViagem = _parseApiDate(widget.viagemDataInicial);
    final fimViagem = _parseApiDate(widget.viagemDataFinal);
    if (inicioViagem == null || fimViagem == null) {
      setState(() => error = 'Não foi possível validar o período da viagem. Tente novamente.');
      return;
    }
    if (dataEvento.isBefore(inicioViagem) || dataEvento.isAfter(fimViagem)) {
      final ini = '${inicioViagem.day.toString().padLeft(2, '0')}/${inicioViagem.month.toString().padLeft(2, '0')}/${inicioViagem.year}';
      final fim = '${fimViagem.day.toString().padLeft(2, '0')}/${fimViagem.month.toString().padLeft(2, '0')}/${fimViagem.year}';
      setState(() => error = 'A data do evento deve estar dentro do período da viagem ($ini até $fim).');
      return;
    }

    final si = startCtrl.text.trim();
    final ef = endCtrl.text.trim();
    if (si.isNotEmpty && ef.isNotEmpty) {
      final a = _timeOfDayFromField(si);
      final b = _timeOfDayFromField(ef);
      final ma = a.hour * 60 + a.minute;
      final mb = b.hour * 60 + b.minute;
      if (mb <= ma) {
        setState(() => error = 'Hora fim deve ser maior que hora início.');
        return;
      }
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      final payload = <String, dynamic>{
        'titulo': titulo,
        'tipo': tipo,
        'data': data,
        'hora_inicio': si.isEmpty ? null : si,
        'hora_fim': ef.isEmpty ? null : ef,
        'local': localCtrl.text.trim().isEmpty ? null : localCtrl.text.trim(),
        'link_url': linkCtrl.text.trim().isEmpty ? null : linkCtrl.text.trim(),
        'descricao': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      };

      if (widget.item == null) {
        await widget.api.postRequest('/api/timeline/${widget.viagemId}', payload);
      } else {
        await widget.api.putRequest('/api/timeline/item/${widget.item!['id']}', payload);
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
                Text('Dados do evento', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  focusNode: titleFocus,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => FocusScope.of(context).requestFocus(dateFocus),
                  decoration: const InputDecoration(
                    labelText: 'Nome do evento',
                    helperText: 'Ex.: Check-in no hotel, Museu do Louvre, Jantar especial',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: tipo,
                  items: const [
                    DropdownMenuItem(value: 'Evento Fixo', child: Text('Evento Fixo')),
                    DropdownMenuItem(value: 'Tempo Livre', child: Text('Tempo Livre')),
                  ],
                  onChanged: saving ? null : (v) => setState(() => tipo = v ?? 'Evento Fixo'),
                  decoration: const InputDecoration(
                    labelText: 'Tipo de evento',
                    helperText: 'Evento Fixo tem horário definido; Tempo Livre representa uma janela aberta',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dateCtrl,
                  focusNode: dateFocus,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => FocusScope.of(context).requestFocus(startFocus),
                  inputFormatters: [_DateTextInputFormatter()],
                  decoration: InputDecoration(
                    labelText: 'Data do evento (DD/MM/AAAA)',
                    helperText: 'Permitido apenas dentro do período da viagem',
                    suffixIcon: IconButton(
                      tooltip: 'Selecionar data',
                      onPressed: saving ? null : _pickDate,
                      icon: const Icon(Icons.calendar_today, size: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startCtrl,
                        focusNode: startFocus,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => FocusScope.of(context).requestFocus(endFocus),
                        inputFormatters: [_TimeTextInputFormatter()],
                        decoration: InputDecoration(
                          labelText: 'Hora início (HH:mm)',
                          helperText: 'Opcional',
                          suffixIcon: IconButton(
                            tooltip: 'Selecionar hora início',
                            onPressed: saving ? null : () => _pickTime(startCtrl),
                            icon: const Icon(Icons.access_time, size: 18),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: endCtrl,
                        focusNode: endFocus,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => FocusScope.of(context).requestFocus(localFocus),
                        inputFormatters: [_TimeTextInputFormatter()],
                        decoration: InputDecoration(
                          labelText: 'Hora fim (HH:mm)',
                          helperText: 'Opcional',
                          suffixIcon: IconButton(
                            tooltip: 'Selecionar hora fim',
                            onPressed: saving ? null : () => _pickTime(endCtrl),
                            icon: const Icon(Icons.access_time, size: 18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: localCtrl,
                  focusNode: localFocus,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => FocusScope.of(context).requestFocus(linkFocus),
                  decoration: const InputDecoration(
                    labelText: 'Local do evento',
                    helperText: 'Ex.: nome do local, endereço ou ponto de referência',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: linkCtrl,
                  focusNode: linkFocus,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => FocusScope.of(context).requestFocus(descFocus),
                  decoration: const InputDecoration(
                    labelText: 'Link do evento',
                    helperText: 'Instagram, Facebook, TikTok, YouTube ou URL web',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  focusNode: descFocus,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descrição do evento',
                    helperText: 'Detalhes importantes para lembrar depois (opcional)',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.w700)),
                ],
                const SizedBox(height: 18),
                if (saving) ...[
                  const SizedBox(height: 6),
                  const Center(child: CircularProgressIndicator(color: AppColors.accentOrange)),
                  const SizedBox(height: 12),
                ],
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

