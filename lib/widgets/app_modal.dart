import 'package:flutter/material.dart';

Future<T?> showAppModal<T>(BuildContext context, Widget child) {
  return showDialog<T>(
    context: context,
    barrierColor: const Color.fromRGBO(0, 0, 0, 0.5),
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(padding: const EdgeInsets.all(24), child: child),
      ),
    ),
  );
}
