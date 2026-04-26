import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_screen_chrome.dart';

class MeioTransporteFormScreenV2 extends StatefulWidget {
  final ApiService api;
  final int viagemId;
  final Map<String, dynamic>? item;

  const MeioTransporteFormScreenV2({
    super.key,
    required this.api,
    required this.viagemId,
    this.item,
  });

  @override
  State<MeioTransporteFormScreenV2> createState() => _MeioTransporteFormScreenV2State();
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

class _TrechoEdit {
  _TrechoEdit({
    required this.pontoA,
    required this.pontoB,
    required this.dataA,
    required this.horaA,
    required this.dataB,
    required this.horaB,
    List<_SeatEdit>? seats,
  })  : focusPontoA = FocusNode(),
        focusPontoB = FocusNode(),
        focusDataA = FocusNode(),
        focusHoraA = FocusNode(),
        focusDataB = FocusNode(),
        focusHoraB = FocusNode(),
        seats = seats ?? [];

  final TextEditingController pontoA;
  final TextEditingController pontoB;
  final TextEditingController dataA;
  final TextEditingController horaA;
  final TextEditingController dataB;
  final TextEditingController horaB;
  final FocusNode focusPontoA;
  final FocusNode focusPontoB;
  final FocusNode focusDataA;
  final FocusNode focusHoraA;
  final FocusNode focusDataB;
  final FocusNode focusHoraB;
  final List<_SeatEdit> seats;

  void dispose() {
    pontoA.dispose();
    pontoB.dispose();
    dataA.dispose();
    horaA.dispose();
    dataB.dispose();
    horaB.dispose();
    focusPontoA.dispose();
    focusPontoB.dispose();
    focusDataA.dispose();
    focusHoraA.dispose();
    focusDataB.dispose();
    focusHoraB.dispose();
    for (final s in seats) {
      s.dispose();
    }
  }
}

class _MeioTransporteFormScreenV2State extends State<MeioTransporteFormScreenV2> {
  late String _tipo;
  final _companhiaCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  final _observacoesCtrl = TextEditingController();
  final _companhiaFocus = FocusNode();
  final _codigoFocus = FocusNode();
  final _observacoesFocus = FocusNode();
  final List<_TrechoEdit> _trechos = [];
  bool _saving = false;

  final _maskData = MaskTextInputFormatter(mask: '##/##/####', filter: {'#': RegExp(r'[0-9]')});
  final _maskHora = MaskTextInputFormatter(mask: '##:##', filter: {'#': RegExp(r'[0-9]')});

  static const _classes = <String, String>{
    'economica': 'Económica',
    'economica_premium': 'Económica Premium',
    'executiva': 'Executiva',
    'primeira': 'Primeira',
  };
  static const _ciasAereas = <String>[
    'Air Canada',
    'Air France',
    'American Airlines',
    'Azul',
    'British Airways',
    'Copa Airlines',
    'Emirates',
    'Gol',
    'Iberia',
    'Ita Airways',
    'KLM',
    'Latam',
    'Lufthansa',
    'Qantas',
    'Qatar',
    'Swiss',
    'TAP',
    'Turkish Airlines',
    'United',
    'Outras',
  ];

  bool get _isEdit => widget.item != null;
  bool get _permiteMultiplosTrechos => _tipo == 'voo' || _tipo == 'trem';
  bool get _mostraAssentos => _tipo == 'voo' || _tipo == 'trem';

  @override
  void initState() {
    super.initState();
    final m = widget.item;
    if (m != null) {
      _tipo = (m['tipo'] ?? 'voo').toString();
      _companhiaCtrl.text = (m['companhia'] ?? '').toString();
      _codigoCtrl.text = (m['codigo_localizador'] ?? '').toString();
      _observacoesCtrl.text = (m['observacoes'] ?? '').toString();
      final rawTrechos = m['trechos'];
      if (rawTrechos is List && rawTrechos.isNotEmpty) {
        for (final t in rawTrechos) {
          if (t is! Map) continue;
          final tm = Map<String, dynamic>.from(t);
          final seats = <_SeatEdit>[];
          if (tm['assentos'] is List) {
            for (final a in tm['assentos']) {
              if (a is! Map) continue;
              final am = Map<String, dynamic>.from(a);
              seats.add(
                _SeatEdit(
                  numero: TextEditingController(text: (am['numero_assento'] ?? '').toString()),
                  nome: TextEditingController(text: (am['nome_passageiro'] ?? '').toString()),
                  classe: (am['classe'] ?? 'economica').toString(),
                ),
              );
            }
          }
          _trechos.add(
            _TrechoEdit(
              pontoA: TextEditingController(text: (tm['ponto_a'] ?? '').toString()),
              pontoB: TextEditingController(text: (tm['ponto_b'] ?? '').toString()),
              dataA: TextEditingController(text: _dataApiParaCampo(tm['data_a'])),
              horaA: TextEditingController(text: _horaApiParaCampo(tm['hora_a'])),
              dataB: TextEditingController(text: _dataApiParaCampo(tm['data_b'])),
              horaB: TextEditingController(text: _horaApiParaCampo(tm['hora_b'])),
              seats: seats,
            ),
          );
        }
      } else {
        final seats = <_SeatEdit>[];
        final rawSeats = m['assentos'];
        if (rawSeats is List) {
          for (final rawSeat in rawSeats) {
            if (rawSeat is! Map) continue;
            final seatMap = Map<String, dynamic>.from(rawSeat);
            seats.add(
              _SeatEdit(
                numero: TextEditingController(text: (seatMap['numero_assento'] ?? '').toString()),
                nome: TextEditingController(text: (seatMap['nome_passageiro'] ?? '').toString()),
                classe: (seatMap['classe'] ?? 'economica').toString(),
              ),
            );
          }
        }
        _trechos.add(
          _TrechoEdit(
            pontoA: TextEditingController(text: (m['ponto_a'] ?? '').toString()),
            pontoB: TextEditingController(text: (m['ponto_b'] ?? '').toString()),
            dataA: TextEditingController(text: _dataApiParaCampo(m['data_a'])),
            horaA: TextEditingController(text: _horaApiParaCampo(m['hora_a'])),
            dataB: TextEditingController(text: _dataApiParaCampo(m['data_b'])),
            horaB: TextEditingController(text: _horaApiParaCampo(m['hora_b'])),
            seats: seats,
          ),
        );
      }
    } else {
      _tipo = 'voo';
    }
    if (_trechos.isEmpty) _trechos.add(_novoTrecho());
    _syncByTipo();
  }

  _TrechoEdit _novoTrecho() => _TrechoEdit(
        pontoA: TextEditingController(),
        pontoB: TextEditingController(),
        dataA: TextEditingController(),
        horaA: TextEditingController(),
        dataB: TextEditingController(),
        horaB: TextEditingController(),
      );

  String _dataApiParaCampo(dynamic v) {
    if (v == null) return '';
    final s = v.toString();
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    return m == null ? '' : '${m[3]}/${m[2]}/${m[1]}';
  }

  String _horaApiParaCampo(dynamic v) {
    if (v == null) return '';
    final parts = v.toString().split(':');
    if (parts.length < 2) return '';
    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
  }

  String? _toIsoDate(String value) {
    final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(value.trim());
    if (m == null) return null;
    return '${m[3]}-${m[2]}-${m[1]}';
  }

  String? _toApiHour(String value) {
    final m = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value.trim());
    if (m == null) return null;
    return '${m[1]}:${m[2]}';
  }

  (String, String) _labelsPontos() {
    switch (_tipo) {
      case 'carro':
        return ('Local de retirada', 'Local de devolução');
      case 'trem':
        return ('Estação de saída', 'Estação de chegada');
      default:
        return ('Aeroporto de saída', 'Aeroporto de chegada');
    }
  }

  (String, String) _labelsHorarios() {
    switch (_tipo) {
      case 'carro':
        return ('Horário de retirada', 'Horário de devolução');
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
      default:
        return 'Companhia aérea';
    }
  }

  void _syncByTipo() {
    if (_tipo == 'voo') {
      final companhiaAtual = _companhiaCtrl.text.trim();
      if (companhiaAtual.isEmpty) {
        _companhiaCtrl.text = _ciasAereas.first;
      } else if (!_ciasAereas.contains(companhiaAtual)) {
        _companhiaCtrl.text = 'Outras';
      }
    }

    if (!_permiteMultiplosTrechos) {
      while (_trechos.length > 1) {
        _trechos.removeLast().dispose();
      }
    }
    if (!_mostraAssentos) {
      for (final t in _trechos) {
        for (final s in t.seats) {
          s.dispose();
        }
        t.seats.clear();
      }
    }
  }

  List<FocusNode> _orderedFocusNodes() {
    final nodes = <FocusNode>[];
    if (_tipo != 'voo') {
      nodes.add(_companhiaFocus);
    }
    nodes.add(_codigoFocus);
    nodes.add(_observacoesFocus);
    for (final t in _trechos) {
      nodes.addAll([
        t.focusPontoA,
        t.focusPontoB,
        t.focusDataA,
        t.focusHoraA,
        t.focusDataB,
        t.focusHoraB,
      ]);
      if (_mostraAssentos) {
        for (final s in t.seats) {
          nodes.addAll([s.focusNumero, s.focusNome]);
        }
      }
    }
    return nodes;
  }

  void _focusNextOrSave(FocusNode current) {
    if (_saving) return;
    final nodes = _orderedFocusNodes();
    final idx = nodes.indexOf(current);
    if (idx < 0 || idx == nodes.length - 1) {
      _save();
      return;
    }
    nodes[idx + 1].requestFocus();
  }

  Future<void> _save() async {
    final (la, lb) = _labelsPontos();
    final trechos = <Map<String, dynamic>>[];
    for (var i = 0; i < _trechos.length; i++) {
      final t = _trechos[i];
      if (t.pontoA.text.trim().isEmpty || t.pontoB.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Trecho ${i + 1}: preencha $la e $lb.')),
        );
        return;
      }
      final assentos = <Map<String, dynamic>>[];
      if (_mostraAssentos) {
        for (final s in t.seats) {
          final n = s.numero.text.trim();
          final p = s.nome.text.trim();
          if (n.isEmpty && p.isEmpty) continue;
          if (n.isEmpty || p.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Trecho ${i + 1}: número e nome do assento são obrigatórios.')),
            );
            return;
          }
          assentos.add({'numero_assento': n, 'nome_passageiro': p, 'classe': s.classe});
        }
      }
      trechos.add({
        'ponto_a': t.pontoA.text.trim(),
        'ponto_b': t.pontoB.text.trim(),
        'data_a': _toIsoDate(t.dataA.text),
        'hora_a': _toApiHour(t.horaA.text),
        'data_b': _toIsoDate(t.dataB.text),
        'hora_b': _toApiHour(t.horaB.text),
        if (_mostraAssentos) 'assentos': assentos,
      });
    }

    setState(() => _saving = true);
    try {
      final body = {
        'tipo': _tipo,
        'companhia': _companhiaCtrl.text.trim().isEmpty ? null : _companhiaCtrl.text.trim(),
        'codigo_localizador': _codigoCtrl.text.trim().isEmpty ? null : _codigoCtrl.text.trim(),
        'observacoes': _observacoesCtrl.text.trim().isEmpty ? null : _observacoesCtrl.text.trim(),
        'trechos': trechos,
      };
      if (_isEdit) {
        await widget.api.putRequest('/api/viagens/${widget.viagemId}/meios-transporte/${widget.item!['id']}', body);
      } else {
        await widget.api.postRequest('/api/viagens/${widget.viagemId}/meios-transporte', body);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao guardar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _companhiaCtrl.dispose();
    _codigoCtrl.dispose();
    _observacoesCtrl.dispose();
    _companhiaFocus.dispose();
    _codigoFocus.dispose();
    _observacoesFocus.dispose();
    for (final t in _trechos) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (la, lb) = _labelsPontos();
    final (ha, hb) = _labelsHorarios();
    return Scaffold(
      appBar: AppScreenChrome.appBar(
        context,
        title: _isEdit ? 'Editar transporte' : 'Novo transporte',
      ),
      body: AppGradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: AppLayout.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _tipo,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'voo', child: Text('Voo')),
                    DropdownMenuItem(value: 'carro', child: Text('Carro')),
                    DropdownMenuItem(value: 'trem', child: Text('Trem')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _tipo = v;
                      _syncByTipo();
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (_tipo == 'voo')
                  DropdownButtonFormField<String>(
                    initialValue: _ciasAereas.contains(_companhiaCtrl.text.trim())
                        ? _companhiaCtrl.text.trim()
                        : _ciasAereas.first,
                    decoration: const InputDecoration(
                      labelText: 'Companhia aérea',
                    ),
                    items: [
                      for (final cia in _ciasAereas)
                        DropdownMenuItem(
                          value: cia,
                          child: Text(cia),
                        ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _companhiaCtrl.text = v);
                    },
                  )
                else
                  TextField(
                    controller: _companhiaCtrl,
                    focusNode: _companhiaFocus,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: _labelCompanhia(), hintText: 'Opcional'),
                    onSubmitted: (_) => _focusNextOrSave(_companhiaFocus),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _codigoCtrl,
                  focusNode: _codigoFocus,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Código localizador da reserva', hintText: 'Opcional'),
                  onSubmitted: (_) => _focusNextOrSave(_codigoFocus),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _observacoesCtrl,
                  focusNode: _observacoesFocus,
                  textInputAction: TextInputAction.next,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Observações da reserva',
                    hintText: 'Opcional',
                  ),
                  onSubmitted: (_) => _focusNextOrSave(_observacoesFocus),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Trechos',
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                      ),
                    ),
                    if (_permiteMultiplosTrechos)
                      TextButton.icon(
                        onPressed: () => setState(() => _trechos.add(_novoTrecho())),
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < _trechos.length; i++) ...[
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Trecho ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
                              const Spacer(),
                              if (_permiteMultiplosTrechos && _trechos.length > 1)
                                IconButton(
                                  onPressed: () => setState(() {
                                    _trechos[i].dispose();
                                    _trechos.removeAt(i);
                                  }),
                                  icon: const Icon(Icons.delete_outline, color: AppColors.errorRed),
                                ),
                            ],
                          ),
                          TextField(
                            controller: _trechos[i].pontoA,
                            focusNode: _trechos[i].focusPontoA,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(labelText: la),
                            onSubmitted: (_) => _focusNextOrSave(_trechos[i].focusPontoA),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _trechos[i].pontoB,
                            focusNode: _trechos[i].focusPontoB,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(labelText: lb),
                            onSubmitted: (_) => _focusNextOrSave(_trechos[i].focusPontoB),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _trechos[i].dataA,
                                  focusNode: _trechos[i].focusDataA,
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: [_maskData],
                                  decoration: InputDecoration(labelText: '$ha (data)', hintText: 'dd/mm/aaaa'),
                                  onSubmitted: (_) => _focusNextOrSave(_trechos[i].focusDataA),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _trechos[i].horaA,
                                  focusNode: _trechos[i].focusHoraA,
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: [_maskHora],
                                  decoration: InputDecoration(labelText: '$ha (hora)', hintText: 'hh:mm'),
                                  onSubmitted: (_) => _focusNextOrSave(_trechos[i].focusHoraA),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _trechos[i].dataB,
                                  focusNode: _trechos[i].focusDataB,
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: [_maskData],
                                  decoration: InputDecoration(labelText: '$hb (data)', hintText: 'dd/mm/aaaa'),
                                  onSubmitted: (_) => _focusNextOrSave(_trechos[i].focusDataB),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _trechos[i].horaB,
                                  focusNode: _trechos[i].focusHoraB,
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: [_maskHora],
                                  decoration: InputDecoration(labelText: '$hb (hora)', hintText: 'hh:mm'),
                                  onSubmitted: (_) => _focusNextOrSave(_trechos[i].focusHoraB),
                                ),
                              ),
                            ],
                          ),
                          if (_mostraAssentos) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Expanded(child: Text('Assentos', style: TextStyle(fontWeight: FontWeight.w700))),
                                TextButton.icon(
                                  onPressed: () => setState(() {
                                    _trechos[i].seats.add(
                                      _SeatEdit(
                                        numero: TextEditingController(),
                                        nome: TextEditingController(),
                                        classe: 'economica',
                                      ),
                                    );
                                  }),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Adicionar'),
                                ),
                              ],
                            ),
                            for (var si = 0; si < _trechos[i].seats.length; si++) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _trechos[i].seats[si].numero,
                                      focusNode: _trechos[i].seats[si].focusNumero,
                                      textInputAction: TextInputAction.next,
                                      decoration: const InputDecoration(labelText: 'Número assento'),
                                      onSubmitted: (_) => _focusNextOrSave(_trechos[i].seats[si].focusNumero),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _trechos[i].seats[si].nome,
                                      focusNode: _trechos[i].seats[si].focusNome,
                                      textInputAction: TextInputAction.next,
                                      decoration: const InputDecoration(labelText: 'Passageiro'),
                                      onSubmitted: (_) => _focusNextOrSave(_trechos[i].seats[si].focusNome),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _trechos[i].seats[si].classe,
                                      decoration: const InputDecoration(labelText: 'Classe'),
                                      items: [
                                        for (final e in _classes.entries)
                                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                                      ],
                                      onChanged: (v) {
                                        if (v == null) return;
                                        setState(() => _trechos[i].seats[si].classe = v);
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => setState(() {
                                      _trechos[i].seats[si].dispose();
                                      _trechos[i].seats.removeAt(si);
                                    }),
                                    icon: const Icon(Icons.delete_outline, color: AppColors.errorRed),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
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
