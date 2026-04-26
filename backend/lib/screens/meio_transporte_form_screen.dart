import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_screen_chrome.dart';

class MeioTransporteFormScreen extends StatefulWidget {
  final ApiService api;
  final int viagemId;
  final Map<String, dynamic>? item;

  const MeioTransporteFormScreen({
    super.key,
    required this.api,
    required this.viagemId,
    this.item,
  });

  @override
  State<MeioTransporteFormScreen> createState() =>
      _MeioTransporteFormScreenState();
}

class _SeatEdit {
  _SeatEdit({
    required this.numero,
    required this.nome,
    required this.classe,
  })  : focusNumero = FocusNode(),
        focusNome = FocusNode();

  final TextEditingController numero;
  final TextEditingController nome;
  String classe;
  final FocusNode focusNumero;
  final FocusNode focusNome;

  void dispose() {
    numero.dispose();
    nome.dispose();
    focusNumero.dispose();
    focusNome.dispose();
  }
}

class _MeioTransporteFormScreenState extends State<MeioTransporteFormScreen> {
  late String _tipo;
  final _companhiaCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  final _pontoACtrl = TextEditingController();
  final _pontoBCtrl = TextEditingController();
  final _dataACtrl = TextEditingController();
  final _horaACtrl = TextEditingController();
  final _dataBCtrl = TextEditingController();
  final _horaBCtrl = TextEditingController();
  bool _saving = false;
  final List<_SeatEdit> _seats = [];

  late final FocusNode _fnCompanhia;
  late final FocusNode _fnCodigo;
  late final FocusNode _fnPontoA;
  late final FocusNode _fnPontoB;
  late final FocusNode _fnDataA;
  late final FocusNode _fnHoraA;
  late final FocusNode _fnDataB;
  late final FocusNode _fnHoraB;

  final _maskDataA = MaskTextInputFormatter(
    mask: '##/##/####',
    filter: {'#': RegExp(r'[0-9]')},
  );
  final _maskHoraA = MaskTextInputFormatter(
    mask: '##:##',
    filter: {'#': RegExp(r'[0-9]')},
  );
  final _maskDataB = MaskTextInputFormatter(
    mask: '##/##/####',
    filter: {'#': RegExp(r'[0-9]')},
  );
  final _maskHoraB = MaskTextInputFormatter(
    mask: '##:##',
    filter: {'#': RegExp(r'[0-9]')},
  );

  static const _classes = <String, String>{
    'economica': 'Económica',
    'economica_premium': 'Económica Premium',
    'executiva': 'Executiva',
    'primeira': 'Primeira',
  };

  /// `dd/MM/yyyy` — dois dígitos em dia e mês.
  static final _reData = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');

  /// `dd/MM/yyyy HH:mm` (legado `horario_*` num só campo).
  static final _reDataHora =
      RegExp(r'^(\d{2})/(\d{2})/(\d{4})\s+(\d{2}):(\d{2})$');

  /// `HH:mm` — 24 h.
  static final _reHora = RegExp(r'^(\d{2}):(\d{2})$');

  bool get _isEdit => widget.item != null;
  bool get _mostraAssentos => _tipo == 'voo' || _tipo == 'trem';

  @override
  void initState() {
    super.initState();
    _fnCompanhia = FocusNode();
    _fnCodigo = FocusNode();
    _fnPontoA = FocusNode();
    _fnPontoB = FocusNode();
    _fnDataA = FocusNode();
    _fnHoraA = FocusNode();
    _fnDataB = FocusNode();
    _fnHoraB = FocusNode();
    final m = widget.item;
    if (m != null) {
      _tipo = (m['tipo'] ?? 'voo').toString();
      _companhiaCtrl.text = (m['companhia'] ?? '').toString();
      _codigoCtrl.text = (m['codigo_localizador'] ?? '').toString();
      _pontoACtrl.text = (m['ponto_a'] ?? '').toString();
      _pontoBCtrl.text = (m['ponto_b'] ?? '').toString();
      _dataACtrl.text = _dataApiParaCampo(m['data_a']);
      _horaACtrl.text = _horaApiParaCampo(m['hora_a']);
      _dataBCtrl.text = _dataApiParaCampo(m['data_b']);
      _horaBCtrl.text = _horaApiParaCampo(m['hora_b']);
      if (_dataACtrl.text.isEmpty &&
          _horaACtrl.text.isEmpty &&
          m['horario_a'] != null) {
        final pa = _splitHorarioFromServer(m['horario_a']);
        _dataACtrl.text = pa.$1;
        _horaACtrl.text = pa.$2;
      }
      if (_dataBCtrl.text.isEmpty &&
          _horaBCtrl.text.isEmpty &&
          m['horario_b'] != null) {
        final pb = _splitHorarioFromServer(m['horario_b']);
        _dataBCtrl.text = pb.$1;
        _horaBCtrl.text = pb.$2;
      }
      final raw = m['assentos'];
      if (raw is List) {
        for (final a in raw) {
          if (a is! Map) continue;
          final map = Map<String, dynamic>.from(a);
          _seats.add(
            _SeatEdit(
              numero: TextEditingController(
                  text: (map['numero_assento'] ?? '').toString()),
              nome: TextEditingController(
                  text: (map['nome_passageiro'] ?? '').toString()),
              classe: (map['classe'] ?? 'economica').toString(),
            ),
          );
        }
      }
    } else {
      _tipo = 'voo';
    }
  }

  String _fmtDateOnly(DateTime d) {
    final l = d.toLocal();
    final dd = l.day.toString().padLeft(2, '0');
    final mm = l.month.toString().padLeft(2, '0');
    final yyyy = l.year.toString();
    return '$dd/$mm/$yyyy';
  }

  String _fmtHoraOnly(DateTime d) {
    final l = d.toLocal();
    final hh = l.hour.toString().padLeft(2, '0');
    final min = l.minute.toString().padLeft(2, '0');
    return '$hh:$min';
  }

  /// API envia `data_*` como aaaa-mm-dd.
  String _dataApiParaCampo(dynamic v) {
    if (v == null) {
      return '';
    }
    final s = v.toString();
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    if (m != null) {
      return '${m[3]}/${m[2]}/${m[1]}';
    }
    return '';
  }

  String _horaApiParaCampo(dynamic v) {
    if (v == null) {
      return '';
    }
    final s = v.toString();
    final parts = s.split(':');
    if (parts.length >= 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }
    return '';
  }

  /// Separa valor legado `horario_*` (texto único) em (data, hora).
  (String, String) _splitHorarioFromServer(dynamic v) {
    if (v == null) {
      return ('', '');
    }
    final s = v.toString().trim();
    if (s.isEmpty) {
      return ('', '');
    }
    final iso = DateTime.tryParse(s);
    if (iso != null) {
      final l = iso.toLocal();
      return (_fmtDateOnly(l), _fmtHoraOnly(l));
    }
    var m = _reDataHora.firstMatch(s);
    if (m != null) {
      return (
        '${m.group(1)}/${m.group(2)}/${m.group(3)}',
        '${m.group(4)}:${m.group(5)}',
      );
    }
    m = _reData.firstMatch(s);
    if (m != null) {
      return (s, '');
    }
    return ('', '');
  }

  String? _erroDataCalendario(int day, int month, int year) {
    if (month < 1 || month > 12) {
      return 'Mês inválido (01–12).';
    }
    if (day < 1 || day > 31) {
      return 'Dia inválido.';
    }
    final dt = DateTime(year, month, day);
    if (dt.year != year || dt.month != month || dt.day != day) {
      return 'Data inexistente.';
    }
    return null;
  }

  /// Data vazia ou formato `dd/mm/aaaa` válido.
  String? _validarCampoData(String raw, String etiqueta) {
    final t = raw.trim();
    if (t.isEmpty) {
      return null;
    }
    final m = _reData.firstMatch(t);
    if (m == null) {
      return '$etiqueta: use dd/mm/aaaa (dois dígitos em dia e mês).';
    }
    final day = int.parse(m.group(1)!);
    final month = int.parse(m.group(2)!);
    final year = int.parse(m.group(3)!);
    final err = _erroDataCalendario(day, month, year);
    return err != null ? '$etiqueta: $err' : null;
  }

  /// Hora vazia ou `HH:mm` (24 h).
  String? _validarCampoHora(String raw, String etiqueta) {
    final t = raw.trim();
    if (t.isEmpty) {
      return null;
    }
    final m = _reHora.firstMatch(t);
    if (m == null) {
      return '$etiqueta: use hh:mm em 24 h (ex.: 09:05 ou 14:30).';
    }
    final hh = int.parse(m.group(1)!);
    final mm = int.parse(m.group(2)!);
    if (hh > 23 || mm > 59) {
      return '$etiqueta: hora inválida.';
    }
    return null;
  }

  /// Ambos vazios OK; caso contrário os dois obrigatórios e válidos.
  String? _validarParDataHora(
    String dataRaw,
    String horaRaw,
    String nomePar,
  ) {
    final d = dataRaw.trim();
    final h = horaRaw.trim();
    if (d.isEmpty && h.isEmpty) {
      return null;
    }
    if (d.isEmpty || h.isEmpty) {
      return '$nomePar: preencha data e hora em conjunto, ou deixe os dois vazios.';
    }
    final errD = _validarCampoData(d, '$nomePar (data)');
    if (errD != null) {
      return errD;
    }
    final errH = _validarCampoHora(h, '$nomePar (hora)');
    if (errH != null) {
      return errH;
    }
    return null;
  }

  String? _dateBrParaIsoApi(String raw) {
    final t = raw.trim();
    if (t.isEmpty) {
      return null;
    }
    final m = _reData.firstMatch(t);
    if (m == null) {
      return null;
    }
    return '${m[3]}-${m[2]}-${m[1]}';
  }

  String? _horaParaApi(String raw) {
    final t = raw.trim();
    if (t.isEmpty) {
      return null;
    }
    final m = _reHora.firstMatch(t);
    if (m == null) {
      return null;
    }
    return '${m[1]}:${m[2]}';
  }

  DateTime? _tryParseData(String raw) {
    final t = raw.trim();
    if (t.isEmpty) {
      return null;
    }
    final m = _reData.firstMatch(t);
    if (m == null) {
      return null;
    }
    return DateTime(
      int.parse(m.group(3)!),
      int.parse(m.group(2)!),
      int.parse(m.group(1)!),
    );
  }

  TimeOfDay? _tryParseHora(String raw) {
    final t = raw.trim();
    if (t.isEmpty) {
      return null;
    }
    final m = _reHora.firstMatch(t);
    if (m == null) {
      return null;
    }
    return TimeOfDay(
      hour: int.parse(m.group(1)!),
      minute: int.parse(m.group(2)!),
    );
  }

  Future<void> _pickData(TextEditingController dataCtrl) async {
    if (!mounted) {
      return;
    }
    final now = DateTime.now();
    final initial = _tryParseData(dataCtrl.text) ?? now;
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (d == null || !mounted) {
      return;
    }
    setState(() {
      dataCtrl.text = _fmtDateOnly(d);
    });
  }

  Future<void> _pickHora(TextEditingController horaCtrl) async {
    if (!mounted) {
      return;
    }
    final parsed = _tryParseHora(horaCtrl.text);
    final initial = parsed ?? TimeOfDay.now();
    final t = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (t == null || !mounted) {
      return;
    }
    setState(() {
      horaCtrl.text =
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    });
  }

  void _addSeat() {
    setState(() {
      _seats.add(
        _SeatEdit(
          numero: TextEditingController(),
          nome: TextEditingController(),
          classe: 'economica',
        ),
      );
    });
  }

  void _removeSeat(int i) {
    setState(() {
      _seats[i].dispose();
      _seats.removeAt(i);
    });
  }

  @override
  void dispose() {
    _fnCompanhia.dispose();
    _fnCodigo.dispose();
    _fnPontoA.dispose();
    _fnPontoB.dispose();
    _fnDataA.dispose();
    _fnHoraA.dispose();
    _fnDataB.dispose();
    _fnHoraB.dispose();
    _companhiaCtrl.dispose();
    _codigoCtrl.dispose();
    _pontoACtrl.dispose();
    _pontoBCtrl.dispose();
    _dataACtrl.dispose();
    _horaACtrl.dispose();
    _dataBCtrl.dispose();
    _horaBCtrl.dispose();
    for (final s in _seats) {
      s.dispose();
    }
    super.dispose();
  }

  (String, String) _labelsPontos() {
    switch (_tipo) {
      case 'carro':
        return ('Local de retirada', 'Local de devolução');
      case 'trem':
        return ('Estação de saída', 'Estação de chegada');
      case 'voo':
      default:
        return ('Aeroporto de saída', 'Aeroporto de chegada');
    }
  }

  (String, String) _labelsHorarios() {
    switch (_tipo) {
      case 'carro':
        return ('Horário de retirada', 'Horário de devolução');
      case 'trem':
      case 'voo':
      default:
        return ('Horário de saída', 'Horário de chegada');
    }
  }

  String _labelCompanhia() {
    switch (_tipo) {
      case 'carro':
        return 'Companhia / locadora';
      case 'trem':
        return 'Companhia / operadora';
      case 'voo':
      default:
        return 'Companhia aérea';
    }
  }

  Widget _blocoDataHora(
    String titulo,
    TextEditingController dataCtrl,
    TextEditingController horaCtrl,
    MaskTextInputFormatter maskData,
    MaskTextInputFormatter maskHora,
    FocusNode focusData,
    FocusNode focusHora,
    VoidCallback onSubmitHora,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.primaryBlue,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: dataCtrl,
                focusNode: focusData,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [maskData],
                decoration: const InputDecoration(
                  labelText: 'Data',
                  hintText: 'dd/mm/aaaa',
                ),
                onSubmitted: (_) => focusHora.requestFocus(),
              ),
            ),
            IconButton(
              tooltip: 'Calendário',
              onPressed: () => _pickData(dataCtrl),
              icon: const Icon(Icons.calendar_today_outlined, size: 22),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: horaCtrl,
                focusNode: focusHora,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [maskHora],
                decoration: const InputDecoration(
                  labelText: 'Hora',
                  hintText: 'hh:mm (24 h)',
                ),
                onSubmitted: (_) => onSubmitHora(),
              ),
            ),
            IconButton(
              tooltip: 'Relógio',
              onPressed: () => _pickHora(horaCtrl),
              icon: const Icon(Icons.schedule, size: 22),
            ),
          ],
        ),
      ],
    );
  }

  void _afterHoraA() {
    _fnDataB.requestFocus();
  }

  void _afterHoraB() {
    if (_mostraAssentos && _seats.isNotEmpty) {
      _seats.first.focusNumero.requestFocus();
    } else {
      _save();
    }
  }

  Future<void> _save() async {
    final (la, lb) = _labelsPontos();
    final (ha, hb) = _labelsHorarios();
    if (_pontoACtrl.text.trim().isEmpty || _pontoBCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preencha $la e $lb.')),
      );
      return;
    }

    final errA = _validarParDataHora(_dataACtrl.text, _horaACtrl.text, ha);
    if (errA != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errA)));
      return;
    }
    final errB = _validarParDataHora(_dataBCtrl.text, _horaBCtrl.text, hb);
    if (errB != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errB)));
      return;
    }

    List<Map<String, dynamic>>? assentosPayload;
    if (_mostraAssentos) {
      assentosPayload = [];
      for (final s in _seats) {
        final nume = s.numero.text.trim();
        final nom = s.nome.text.trim();
        if (nume.isEmpty && nom.isEmpty) {
          continue;
        }
        if (nume.isEmpty || nom.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Em cada assento, preencha número e nome do passageiro.',
              ),
            ),
          );
          return;
        }
        assentosPayload.add({
          'numero_assento': nume,
          'nome_passageiro': nom,
          'classe': s.classe,
        });
      }
    }

    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'tipo': _tipo,
        'companhia': _companhiaCtrl.text.trim().isEmpty
            ? null
            : _companhiaCtrl.text.trim(),
        'codigo_localizador':
            _codigoCtrl.text.trim().isEmpty ? null : _codigoCtrl.text.trim(),
        'ponto_a': _pontoACtrl.text.trim(),
        'ponto_b': _pontoBCtrl.text.trim(),
        'data_a': _dateBrParaIsoApi(_dataACtrl.text),
        'hora_a': _horaParaApi(_horaACtrl.text),
        'data_b': _dateBrParaIsoApi(_dataBCtrl.text),
        'hora_b': _horaParaApi(_horaBCtrl.text),
        if (assentosPayload != null) 'assentos': assentosPayload,
      };

      if (_isEdit) {
        final id = widget.item!['id'];
        await widget.api.putRequest(
          '/api/viagens/${widget.viagemId}/meios-transporte/$id',
          body,
        );
      } else {
        await widget.api.postRequest(
          '/api/viagens/${widget.viagemId}/meios-transporte',
          body,
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao guardar: $e')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final (la, lb) = _labelsPontos();
    final (ha, hb) = _labelsHorarios();
    final title = _isEdit ? 'Editar transporte' : 'Novo transporte';

    return Scaffold(
      appBar: AppScreenChrome.appBar(context, title: title),
      body: AppGradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: AppLayout.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: _tipo,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'voo', child: Text('Voo')),
                    DropdownMenuItem(value: 'carro', child: Text('Carro')),
                    DropdownMenuItem(value: 'trem', child: Text('Trem')),
                  ],
                  onChanged: (v) {
                    if (v == null) {
                      return;
                    }
                    setState(() {
                      _tipo = v;
                      if (!_mostraAssentos) {
                        for (final s in _seats) {
                          s.dispose();
                        }
                        _seats.clear();
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _companhiaCtrl,
                  focusNode: _fnCompanhia,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: _labelCompanhia(),
                    hintText: 'Opcional',
                  ),
                  onSubmitted: (_) => _fnCodigo.requestFocus(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _codigoCtrl,
                  focusNode: _fnCodigo,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Código localizador da reserva',
                    hintText: 'Opcional',
                  ),
                  onSubmitted: (_) => _fnPontoA.requestFocus(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pontoACtrl,
                  focusNode: _fnPontoA,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: la),
                  onSubmitted: (_) => _fnPontoB.requestFocus(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pontoBCtrl,
                  focusNode: _fnPontoB,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: lb),
                  onSubmitted: (_) => _fnDataA.requestFocus(),
                ),
                const SizedBox(height: 16),
                _blocoDataHora(ha, _dataACtrl, _horaACtrl, _maskDataA,
                    _maskHoraA, _fnDataA, _fnHoraA, _afterHoraA),
                const SizedBox(height: 18),
                _blocoDataHora(hb, _dataBCtrl, _horaBCtrl, _maskDataB,
                    _maskHoraB, _fnDataB, _fnHoraB, _afterHoraB),
                if (_mostraAssentos) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Assentos',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBlue,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addSeat,
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text('Adicionar'),
                      ),
                    ],
                  ),
                  const Text(
                    'Número do assento, passageiro e classe (voo ou trem).',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < _seats.length; i++) ...[
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Assento ${i + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () => _removeSeat(i),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: AppColors.errorRed,
                                  ),
                                ),
                              ],
                            ),
                            TextField(
                              controller: _seats[i].numero,
                              focusNode: _seats[i].focusNumero,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Número do assento',
                              ),
                              onSubmitted: (_) =>
                                  _seats[i].focusNome.requestFocus(),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _seats[i].nome,
                              focusNode: _seats[i].focusNome,
                              textInputAction: i == _seats.length - 1
                                  ? TextInputAction.done
                                  : TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Nome do passageiro',
                              ),
                              onSubmitted: (_) {
                                if (i == _seats.length - 1) {
                                  _save();
                                } else {
                                  _seats[i + 1].focusNumero.requestFocus();
                                }
                              },
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _seats[i].classe,
                              decoration:
                                  const InputDecoration(labelText: 'Classe'),
                              items: [
                                for (final e in _classes.entries)
                                  DropdownMenuItem(
                                    value: e.key,
                                    child: Text(e.value),
                                  ),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _seats[i].classe = v);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 24),
                AppButton(
                  label: _saving ? 'A guardar…' : 'Guardar',
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
