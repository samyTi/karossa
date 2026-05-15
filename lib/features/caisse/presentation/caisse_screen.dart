import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../../shared/services/export_service.dart';

// Import des composants du module
import '../data/caisse_operation.dart';
import '../domain/caisse_providers.dart';
import './caisse_op_tile.dart';
import './caisse_stats_bar.dart';
import './caisse_filter_bar.dart';

class CaisseScreen extends ConsumerStatefulWidget {
  const CaisseScreen({super.key});
  @override
  ConsumerState<CaisseScreen> createState() => _CaisseScreenState();
}

class _CaisseScreenState extends ConsumerState<CaisseScreen> {
  @override
  Widget build(BuildContext context) {
    // Utilisation du provider global (défini dans caisse_providers.dart)
    // qui gère déjà les filtres et les jointures SQL
    final opsAsync = ref.watch(caisseOperationsProvider);
    final canEdit = ref.watch(canManageCaisseProvider);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Gestion de Caisse',
        showBackButton: false,
        showHomeButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Exporter CSV',
            onPressed: () async {
              final data = opsAsync.valueOrNull ?? [];
              // Conversion des objets CaisseOperation en Map pour l'export
              await ExportService.exportCaisseCSV(
                data.map((e) => e.toMap()).toList(),
              );
            },
          ),
        ],
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _showOpDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Nouvelle opération'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            )
          : null,
      body: Column(
        children: [
          // 1. Barre de Statistiques (Solde, Entrées, Sorties)
          const CaisseStatsBar(),
          
          // 2. Barre de Filtres (Mois, Type, Catégorie)
          const CaisseFilterBar(),

          // 3. Liste des opérations
          Expanded(
            child: opsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(
                    child: Text('Aucune opération enregistrée'),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(caisseOperationsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: list.length,
                    // ✅ Utilisation du composant corrigé
                    itemBuilder: (_, i) => CaisseOpTile(op: list[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Dialogue d'ajout d'opération
  void _showOpDialog(BuildContext context, WidgetRef ref) {
    String type = 'entree';
    String categorie = 'autre';
    final montantCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Nouvelle opération'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'entree', child: Text('Entrée (+)')),
                    DropdownMenuItem(value: 'sortie', child: Text('Sortie (-)')),
                  ],
                  onChanged: (v) => setS(() => type = v!),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: categorie,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: CaisseOperation.categorieLabels.entries.map((e) {
                    return DropdownMenuItem(value: e.key, child: Text(e.value));
                  }).toList(),
                  onChanged: (v) => setS(() => categorie = v!),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: montantCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Montant',
                    suffixText: 'DA',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                final mnt = double.tryParse(montantCtrl.text.trim());
                if (mnt == null || mnt <= 0 || descCtrl.text.trim().isEmpty) return;

                // On utilise CaisseActions pour l'insertion (défini dans caisse_providers.dart)
                // Cela permet de rafraîchir automatiquement tous les écrans
                final newOp = CaisseOperation(
                  id: '', // La DB générera l'ID
                  type: type,
                  categorie: categorie,
                  montant: mnt,
                  description: descCtrl.text.trim(),
                  dateOp: DateTime.now(),
                );

                try {
                  await ref.read(caisseActionsProvider).insert(newOp);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  // Gérer l'erreur ici (ex: SnackBar)
                }
              },
              child: const Text('Enregistrer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}