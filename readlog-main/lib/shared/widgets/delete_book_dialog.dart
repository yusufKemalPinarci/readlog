
import 'dart:math';

import 'package:flutter/material.dart';

class DeleteBookDialog extends StatefulWidget {
  const DeleteBookDialog({super.key, required this.onConfirm});

  final VoidCallback onConfirm;

  @override
  State<DeleteBookDialog> createState() => _DeleteBookDialogState();
}

class _DeleteBookDialogState extends State<DeleteBookDialog> {
  late String _verificationCode;
  final TextEditingController _codeController = TextEditingController();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _verificationCode = _generateVerificationCode();
  }

  @override
  void dispose() {
    _codeController.dispose(); // T2.20: was leaked
    super.dispose();
  }

  String _generateVerificationCode() {
    final random = Random();
    String code = '';
    for (int i = 0; i < 6; i++) {
      code += random.nextInt(10).toString();
    }
    return code;
  }

  void _verifyAndConfirm() {
    if (_codeController.text == _verificationCode) {
      widget.onConfirm();
      Navigator.of(context).pop();
    } else {
      setState(() {
        _errorText = 'Kod hatalı. Lütfen tekrar deneyin.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('Kitabı Sil?'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Bu kitabı silmek istediğinize emin misiniz? Bu işlem geri alınamaz ve ilgili okuma kayıtları da silinecektir.',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  'Onay Kodu',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _verificationCode,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, letterSpacing: 4, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: '6 haneli kodu yazın',
              hintStyle: TextStyle(
                fontSize: 14,
                letterSpacing: 0,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              errorText: _errorText,
              counterText: '',
            ),
            onChanged: (_) {
              if (_errorText != null) {
                setState(() => _errorText = null);
              }
            },
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('İptal'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _verifyAndConfirm,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Sil'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
