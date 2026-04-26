import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum AppButtonType { primary, secondary, danger }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonType type;

  const AppButton({super.key, required this.label, required this.onPressed, this.type = AppButtonType.primary});

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final isSecondary = type == AppButtonType.secondary;
    final isDanger = type == AppButtonType.danger;
    final backgroundColor = isSecondary
        ? Colors.transparent
        : (isDanger ? AppColors.errorRed : AppColors.accentOrange).withValues(alpha: disabled ? 0.45 : 1);
    final foregroundColor = isSecondary ? AppColors.primaryBlue : AppColors.white;

    return SizedBox(
      height: 56,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          side: BorderSide(color: isSecondary ? AppColors.primaryBlue : Colors.transparent, width: 1.6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: foregroundColor,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
