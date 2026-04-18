import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_screen_chrome.dart';

/// Tela de resultados da busca Google Places (proxy backend), no padrão visual do app.
class PlacesSearchResultsScreen extends StatelessWidget {
  final String title;
  final String cidadeNome;
  final String queryUsada;
  final List<Map<String, dynamic>> resultados;
  final IconData placeholderIcon;

  const PlacesSearchResultsScreen({
    super.key,
    required this.title,
    required this.cidadeNome,
    required this.queryUsada,
    required this.resultados,
    this.placeholderIcon = Icons.place,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: AppColors.primaryBlue),
                    ),
                    Expanded(
                      child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: AppLayout.screenPaddingSymmetricH,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cidadeNome.isNotEmpty ? 'Cidade: $cidadeNome' : 'Busca de locais',
                      style: const TextStyle(color: AppColors.primaryBlue, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Consulta: $queryUsada',
                      style: const TextStyle(color: AppColors.neutralGray, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: AppDecor.whiteTopSheet(),
                  child: resultados.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Nenhum resultado encontrado.\nAjuste o nome ou tente outro termo.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: resultados.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final p = resultados[index];
                            final nome = (p['nome'] ?? '').toString();
                            final endereco = (p['endereco'] ?? '').toString();
                            final rating = p['rating'];
                            final fotoUrl = p['foto_url']?.toString();

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.pop(context, p),
                                borderRadius: BorderRadius.circular(16),
                                child: AppCard(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: fotoUrl != null && fotoUrl.isNotEmpty
                                            ? Image.network(
                                                fotoUrl,
                                                width: 72,
                                                height: 72,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => _placeholderThumb(),
                                              )
                                            : _placeholderThumb(),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              nome,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                                color: AppColors.blue,
                                              ),
                                            ),
                                            if (endereco.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                endereco,
                                                style: const TextStyle(
                                                  color: Color(0xFF64748B),
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                            if (rating != null) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                'Nota: $rating',
                                                style: const TextStyle(
                                                  color: Color(0xFF475569),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderThumb() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.lightBlue,
      ),
      child: Icon(placeholderIcon, color: AppColors.primaryBlue, size: 32),
    );
  }
}
