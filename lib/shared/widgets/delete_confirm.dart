// lib/shared/widgets/delete_confirm.dart
// Dialogue de confirmation de suppression + undo via Snackbar

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Affiche un dialogue de confirmation.
/// Retourne true si l'utilisateur confirme la suppression.
Future<bool> showDeleteConfirm(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppColors.retard.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.delete_outline,
            color: AppColors.retard, size: 20),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 16)),
      ]),
      content: Text(message,
        style: const TextStyle(color: AppColors.textSecondary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.retard,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Affiche un Snackbar avec un bouton "Annuler" (undo).
void showUndoSnackbar(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
  Duration duration = const Duration(seconds: 4),
}) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10)),
      action: SnackBarAction(
        label: 'Annuler',
        textColor: Colors.amber,
        onPressed: onUndo,
      ),
    ),
  );
}
