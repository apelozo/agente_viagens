import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Padrão visual da dashboard: fundo em gradiente + AppBar com faixa [lightBlue].
/// Usar em novas telas para manter identidade consistente.
class AppGradientBackground extends StatelessWidget {
  final Widget child;
  const AppGradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(gradient: AppGradients.screenBackground),
      child: child,
    );
  }
}

abstract final class AppScreenChrome {
  AppScreenChrome._();

  static AppBar appBar(
    BuildContext context, {
    required String title,
    List<Widget>? actions,
    PreferredSizeWidget? bottom,
    bool centerTitle = false,
    Widget? leading,
  }) {
    return AppBar(
      backgroundColor: AppColors.lightBlue,
      foregroundColor: AppColors.primaryBlue,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: centerTitle,
      leading: leading,
      title: Text(title, style: Theme.of(context).textTheme.titleLarge),
      actions: actions,
      bottom: bottom,
    );
  }
}
