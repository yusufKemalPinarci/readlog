import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String cancelText = 'İptal',
  String confirmText = 'Evet, Sil',
  bool isDangerous = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(cancelText),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: isDangerous ? context.danger : Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(confirmText),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
  return result ?? false;
}


