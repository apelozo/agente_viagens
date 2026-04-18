import 'package:flutter/material.dart';
import '../models/viagem.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_screen_chrome.dart';
import 'trip_detail_screen.dart';

/// Detalhe de uma cidade: hotéis, restaurantes e passeios (sem repetir o bloco na lista principal).
class CityDetailScreen extends StatefulWidget {
  final ApiService api;
  final Viagem viagem;
  final Map<String, dynamic> cidade;

  const CityDetailScreen({
    super.key,
    required this.api,
    required this.viagem,
    required this.cidade,
  });

  @override
  State<CityDetailScreen> createState() => _CityDetailScreenState();
}

class _CityDetailScreenState extends State<CityDetailScreen> {
  List<Map<String, dynamic>> hoteis = [];
  List<Map<String, dynamic>> restaurantes = [];
  List<Map<String, dynamic>> passeios = [];
  bool loading = true;

  int get _cityId => widget.cidade['id'] as int;

  String asText(dynamic value) => value == null ? '' : value.toString();

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final hid = _cityId;
    final hotels = await widget.api.getRequest('/api/viagens/hoteis/$hid') as List<dynamic>;
    final rests = await widget.api.getRequest('/api/viagens/restaurantes/$hid') as List<dynamic>;
    final tours = await widget.api.getRequest('/api/viagens/passeios/$hid') as List<dynamic>;
    if (!mounted) return;
    setState(() {
      hoteis = hotels.map((e) => Map<String, dynamic>.from(e)).toList();
      restaurantes = rests.map((e) => Map<String, dynamic>.from(e)).toList();
      passeios = tours.map((e) => Map<String, dynamic>.from(e)).toList();
      loading = false;
    });
  }

  Future<void> deleteByPath(String path) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: const Text('Tem certeza que deseja excluir este item?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirm != true) return;
    await widget.api.deleteRequest(path);
    await load();
  }

  Future<void> openForm(EntityType type, {Map<String, dynamic>? item}) async {
    final parent = type == EntityType.cidade ? widget.viagem.id : _cityId;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EntityFormScreen(
          api: widget.api,
          type: type,
          parentId: parent,
          item: item,
          cidade: widget.cidade,
        ),
      ),
    );
    await load();
  }

  Widget _sectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required EntityType type,
    required String apiEntity,
    required List<Map<String, dynamic>> items,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 23, 42, 0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Adicionar',
                  onPressed: () => openForm(type),
                  icon: const Icon(Icons.add_rounded, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Nenhum item cadastrado.', style: TextStyle(color: Color(0xFF64748B))),
              )
            else
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => openForm(type, item: item),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${asText(item['nome'])}${asText(item['situacao']).isNotEmpty ? ' · ${asText(item['situacao'])}' : ''}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Editar',
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                              onPressed: () => openForm(type, item: item),
                              icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primaryBlue),
                            ),
                            IconButton(
                              tooltip: 'Excluir',
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                              onPressed: () => deleteByPath('/api/viagens/$apiEntity/item/${item['id']}'),
                              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.errorRed),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nomeCidade = asText(widget.cidade['descricao']);
    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(8, 6, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      tooltip: 'Voltar',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    ),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_city_rounded, color: Colors.white70, size: 26),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              nomeCidade,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Editar cidade',
                      onPressed: () => openForm(EntityType.cidade, item: widget.cidade),
                      icon: const Icon(Icons.edit_outlined, color: Colors.white),
                    ),
                    IconButton(
                      tooltip: 'Excluir cidade',
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Excluir cidade'),
                            content: const Text('Todos os itens desta cidade serão removidos. Continuar?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
                            ],
                          ),
                        );
                        if (ok == true && mounted) {
                          await widget.api.deleteRequest('/api/viagens/cidades/item/$_cityId');
                          if (!mounted) return;
                          navigator.pop();
                        }
                      },
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  decoration: AppDecor.whiteTopSheet(radius: 24),
                  child: loading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.accentOrange))
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                          children: [
                            _sectionCard(
                              icon: Icons.hotel_rounded,
                              iconColor: const Color(0xFF6366F1),
                              title: 'Hotéis',
                              type: EntityType.hotel,
                              apiEntity: 'hoteis',
                              items: hoteis,
                            ),
                            _sectionCard(
                              icon: Icons.restaurant_rounded,
                              iconColor: const Color(0xFFF59E0B),
                              title: 'Restaurantes',
                              type: EntityType.restaurante,
                              apiEntity: 'restaurantes',
                              items: restaurantes,
                            ),
                            _sectionCard(
                              icon: Icons.attractions_rounded,
                              iconColor: const Color(0xFF10B981),
                              title: 'Passeios / Ingressos',
                              type: EntityType.passeio,
                              apiEntity: 'passeios',
                              items: passeios,
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
