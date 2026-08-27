//lib/features/caisse/presentation/caisse_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../../shared/services/export_service.dart';
import '../../admin/presentation/users_provider.dart';
import '../../finance/presentation/proprietaire_finance_provider.dart';

// Import des composants du module
import '../domain/caisse_operation.dart';
import '../domain/caisse_providers.dart';
import './caisse_op_tile.dart';
import './caisse_stats_bar.dart';
import './caisse_filter_bar.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

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
        title: context.l10n.gestionDeCaisse,
        showBackButton: false,
        showHomeButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: context.l10n.exporterCsv,
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
              onPressed: () => _showAjoutMenu(context, ref),
              icon: const Icon(Icons.add),
              label: Text(context.l10n.nouvelleOperation),
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
              error: (e, _) => Center(
                child: Text(context.l10n.erreurAvecDetail(e.toString())), // ✅ MODIFIÉ L75
              ),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Text(context.l10n.aucuneOperationEnregistree),
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

  // Menu affiché au clic sur le "+" : opération de caisse classique, ou
  // transfert d'argent entre deux utilisateurs (n'impacte pas la caisse).
  void _showAjoutMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.point_of_sale_outlined),
              title: Text(context.l10n.nouvelleOperation),
              subtitle: Text(context.l10n.caisseOperationSubtitle), // ✅ MODIFIÉ L111
              onTap: () {
                Navigator.pop(ctx);
                _showOpDialog(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: Text(context.l10n.transfertEntreUtilisateurs), // ✅ MODIFIÉ L119
              subtitle: Text(context.l10n.transfertSubtitle), // ✅ MODIFIÉ L120
              onTap: () {
                Navigator.pop(ctx);
                _showTransfertDialog(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Dialogue d'ajout d'opération
  void _showOpDialog(BuildContext context, WidgetRef ref) {
    String type = 'entree';
    String categorie = 'autre';
    String payeePar = 'showroom';
    String? proprietairePayeurId;
    final montantCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(context.l10n.nouvelleOperation),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: InputDecoration(labelText: context.l10n.champType), // ✅ MODIFIÉ L152
                  items: [
                    DropdownMenuItem(value: 'entree', child: Text(context.l10n.entree)),
                    DropdownMenuItem(value: 'sortie', child: Text(context.l10n.sortie)),
                  ],
                  onChanged: (v) => setS(() => type = v!),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: categorie,
                  decoration: InputDecoration(labelText: context.l10n.categorie),
                  items: CaisseOperation.categorieLabels.entries.map((e) {
                    return DropdownMenuItem(value: e.key, child: Text(e.value));
                  }).toList(),
                  onChanged: (v) => setS(() => categorie = v!),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: montantCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.l10n.champMontant,
                    suffixText: 'DA',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(labelText: context.l10n.description),
                  textCapitalization: TextCapitalization.sentences,
                ),
                // Uniquement pertinent pour une sortie d'argent : qui a
                // réellement payé. Si un propriétaire/associé a avancé la
                // somme de sa poche, ça n'impacte pas la caisse réelle du
                // showroom mais crée une créance à lui rembourser.
                if (type == 'sortie') ...[
                  const SizedBox(height: 10),
                  Consumer(builder: (context, ref, _) {
                    final profiles = ref.watch(usersProvider).valueOrNull ?? [];
                    return DropdownButtonFormField<String>(
                      value: payeePar == 'showroom'
                          ? 'showroom'
                          : 'proprietaire:${proprietairePayeurId ?? ''}',
                      isExpanded: true,
                      decoration: InputDecoration(labelText: context.l10n.payePar), // ✅ MODIFIÉ L196
                      items: [
                        DropdownMenuItem(
                          value: 'showroom', 
                          child: Text(context.l10n.showroomCaisse), // ✅ MODIFIÉ L199
                        ),
                        ...profiles.map((p) => DropdownMenuItem(
                              value: 'proprietaire:${p.id}',
                              child: Text(
                                '${p.fullName} ${context.l10n.aRembourser}', // ✅ MODIFIÉ L202
                                overflow: TextOverflow.ellipsis,
                              ),
                            )),
                      ],
                      onChanged: (v) => setS(() {
                        if (v == null || v == 'showroom') {
                          payeePar = 'showroom';
                          proprietairePayeurId = null;
                        } else {
                          payeePar = 'proprietaire';
                          proprietairePayeurId = v.split(':').last;
                        }
                      }),
                    );
                  }),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.btnAnnuler),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                final mnt = double.tryParse(montantCtrl.text.trim());
                if (mnt == null || mnt <= 0 || descCtrl.text.trim().isEmpty) return;
                if (type == 'sortie' && payeePar == 'proprietaire' && proprietairePayeurId == null) {
                  return;
                }

                // On utilise CaisseActions pour l'insertion (défini dans caisse_providers.dart)
                // Cela permet de rafraîchir automatiquement tous les écrans
                final newOp = CaisseOperation(
                  id: '', // La DB générera l'ID
                  type: type,
                  categorie: categorie,
                  montant: mnt,
                  description: descCtrl.text.trim(),
                  dateOp: DateTime.now(),
                  payeePar: type == 'sortie' ? payeePar : 'showroom',
                  proprietairePayeurId:
                      type == 'sortie' && payeePar == 'proprietaire' ? proprietairePayeurId : null,
                );

                try {
                  await ref.read(caisseActionsProvider).insert(newOp);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(context.l10n.erreurAvecDetail(e.toString())), // ✅ MODIFIÉ L255
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: Text(
                context.l10n.enregistrer,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dialogue de transfert d'argent entre deux utilisateurs.
  void _showTransfertDialog(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    String? payeurId = currentUserId;
    String? beneficiaireId;
    bool remboursable = false;
    final montantCtrl = TextEditingController();
    final motifCtrl = TextEditingController();
    bool loading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Consumer(builder: (context, ref, _) {
          final profiles = ref.watch(usersProvider).valueOrNull ?? [];
          return AlertDialog(
            title: Text(context.l10n.transfertEntreUtilisateurs), // ✅ MODIFIÉ L284
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: payeurId,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: context.l10n.quiDonne), // ✅ MODIFIÉ L292
                    items: profiles
                        .map((p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(p.fullName, overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) => setS(() => payeurId = v),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: beneficiaireId,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: context.l10n.quiRecoit), // ✅ MODIFIÉ L305
                    items: profiles
                        .where((p) => p.id != payeurId)
                        .map((p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(p.fullName, overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) => setS(() => beneficiaireId = v),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: montantCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Montant', // ❌ À MODIFIER AUSSI ! (L319)
                      suffixText: 'DA',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: motifCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Motif', // ❌ À MODIFIER AUSSI ! (L324)
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: remboursable,
                    onChanged: (v) => setS(() => remboursable = v),
                    title: Text(context.l10n.remboursable), // ✅ MODIFIÉ L332
                    subtitle: Text(
                      remboursable
                          ? 'Le bénéficiaire devra rendre cet argent' // ❌ À TRADUIRE AUSSI !
                          : 'Don définitif, aucun remboursement prévu', // ❌ À TRADUIRE AUSSI !
                      style: AppTextStyles.label,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: loading ? null : () => Navigator.pop(ctx),
                child: Text(context.l10n.btnAnnuler),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: loading
                    ? null
                    : () async {
                        final mnt = double.tryParse(montantCtrl.text.trim());
                        if (payeurId == null ||
                            beneficiaireId == null ||
                            mnt == null ||
                            mnt <= 0 ||
                            motifCtrl.text.trim().isEmpty) {
                          return;
                        }
                        setS(() => loading = true);
                        try {
                          await ref.read(creerTransfertProvider)(
                            payeurId: payeurId!,
                            beneficiaireId: beneficiaireId!,
                            montant: mnt,
                            motif: motifCtrl.text.trim(),
                            remboursable: remboursable,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          setS(() => loading = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(context.l10n.erreurAvecDetail(e.toString())), // ✅ MODIFIÉ L375
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      },
                child: loading
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        context.l10n.enregistrer,
                        style: const TextStyle(color: Colors.white),
                      ),
              ),
            ],
          );
        }),
      ),
    );
  }
}