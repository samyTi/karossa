// lib/shared/widgets/delete_confirm.dart
// Dialogue de confirmation de suppression + undo via Snackbar

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';
import 'package:garage_auto/shared/services/notification_service.dart';

/// Flux complet "confirmer puis supprimer", partagé par tous les écrans
/// (véhicules, clients, ventes, échanges, achats, réparations...).
///
/// - Affiche le dialogue de confirmation.
/// - Exécute [onDelete] si confirmé.
/// - Si une contrainte de clé étrangère bloque la suppression (l'élément est
///   encore lié à des locations/ventes/paiements...), affiche un message
///   clair plutôt que l'erreur brute de Postgres.
/// - Appelle [onSuccess] (ex: invalider les providers) puis affiche un toast.
Future<void> confirmAndDelete(
  BuildContext context, {
  required String title,
  required String message,
  required Future<void> Function() onDelete,
  VoidCallback? onSuccess,
}) async {
  final ok = await showDeleteConfirm(context, title: title, message: message);
  if (!ok || !context.mounted) return;

  try {
    await onDelete();
    onSuccess?.call();
    if (context.mounted) {
      NotificationService().success(context.l10n.elementSupprime);
    }
  } catch (e) {
    if (!context.mounted) return;
    final estLie = e is PostgrestException && e.code == '23503';
    NotificationService().error(
      estLie
          ? context.l10n.suppressionImpossibleLiee
          : context.l10n.erreurAvecDetail(e.toString()),
    );
  }
}

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
          child: Text(context.l10n.btnAnnuler),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.retard,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(context.l10n.btnSupprimer),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Affiche un Snackbar avec un bouton 'Annuler' (undo).
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
        label: context.l10n.btnAnnuler,
        textColor: Colors.amber,
        onPressed: onUndo,
      ),
    ),
  );
}
