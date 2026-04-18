import 'package:flutter/material.dart';

class AppInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  const AppInput({
    super.key,
    required this.label,
    required this.controller,
    this.obscureText = false,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: textInputAction ?? TextInputAction.next,
      onSubmitted: onSubmitted ??
          (_) {
            final scope = FocusScope.of(context);
            if (scope.hasFocus) scope.nextFocus();
          },
      decoration: InputDecoration(labelText: label),
    );
  }
}
