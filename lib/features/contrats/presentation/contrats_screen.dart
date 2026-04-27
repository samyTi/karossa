// lib/features/contrats/presentation/contrats_screen.dart
// Gestion des templates de contrats et paramètres showroom

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/empty_state.dart';
import 'contrats_provider.dart';
import '../domain/contrat_template_model.dart';
import '../data/contrats_repository.dart';

class ContratsScreen extends ConsumerWidget {
  const ContratsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(contractTemplatesProvider);

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Modèles de contrats',
        showBackButton: true,
        showHomeButton: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau modèle'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Erreur : $e')),
        data: (templates) {
          if (templates.isEmpty) {
            return const EmptyState(
              icon: Icons.description_outlined,
              message: 'Aucun modèle de contrat configuré',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: templates.length,
            itemBuilder: (_, i) => _TemplateCard(template: templates[i]),
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final nomCtrl  = TextEditingController();
    String type    = 'location';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Nouveau modèle de contrat'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nomCtrl,
              decoration: const InputDecoration(labelText: 'Nom du modèle'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: 'location', child: Text('Location')),
                DropdownMenuItem(value: 'vente',    child: Text('Vente')),
                DropdownMenuItem(value: 'echange',  child: Text('Échange')),
              ],
              onChanged: (v) => setS(() => type = v!),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () async {
                if (nomCtrl.text.trim().isEmpty) return;
                await ContratsRepository().createTemplate(
                  ContratTemplate(
                    id:        '',
                    type:      type,
                    nom:       nomCtrl.text.trim(),
                    isActive:  true,
                    createdAt: DateTime.now(),
                  ),
                );
                ref.invalidate(contractTemplatesProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final ContratTemplate template;
  const _TemplateCard({required this.template});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (template.type) {
      'location' => (Icons.car_rental, AppColors.primary),
      'vente'    => (Icons.sell,       AppColors.secondary),
      'echange'  => (Icons.swap_horiz, AppColors.accent),
      _          => (Icons.description, AppColors.textSecondary),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title:    Text(template.nom, style: AppTextStyles.heading3),
        subtitle: Text(
          'Type : ${template.type}   •   '
          '${template.isActive ? "Actif" : "Inactif"}',
          style: AppTextStyles.bodySecondary,
        ),
        trailing: template.isActive
            ? const Icon(Icons.check_circle, color: AppColors.secondary, size: 20)
            : const Icon(Icons.cancel_outlined, color: AppColors.textHint, size: 20),
      ),
    );
  }
}
