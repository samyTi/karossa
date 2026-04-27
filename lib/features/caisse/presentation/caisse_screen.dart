import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../main.dart';
import '../../auth/presentation/auth_provider.dart';

final _caisseProvider = FutureProvider.autoDispose((_) async {
  final data = await supabase
    .from('caisse_operations')
    .select('*, vehicules(marque, modele)')
    .order('date_op', ascending: false);
  return data;
});

class CaisseScreen extends ConsumerWidget {
  const CaisseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ops    = ref.watch(_caisseProvider);
    final canEdit = ref.watch(canManageCaisseProvider);

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Caisse',
        showBackButton: false,
        showHomeButton: true,
      ),
      floatingActionButton: canEdit
        ? FloatingActionButton.extended(
            onPressed: () => _showOpDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Nouvelle operation'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          )
        : null,
      body: ops.when(
        loading: () =>
          const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (list) {
          double entrees = 0, sorties = 0;
          for (final op in list) {
            final mnt = (op['montant'] as num).toDouble();
            if (op['type'] == 'entree') {
              entrees += mnt;
            } else {
              sorties += mnt;
            }
          }
          final solde = entrees - sorties;

          return Column(children: [
            // Solde
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(child: _SoldeCard(
                  'Entrees', '${entrees.toInt()} DA',
                  AppColors.secondary, Icons.arrow_downward)),
                const SizedBox(width: 10),
                Expanded(child: _SoldeCard(
                  'Sorties', '${sorties.toInt()} DA',
                  AppColors.retard, Icons.arrow_upward)),
                const SizedBox(width: 10),
                Expanded(child: _SoldeCard(
                  'Solde', '${solde.toInt()} DA',
                  solde >= 0 ? AppColors.primary : AppColors.retard,
                  Icons.account_balance_wallet)),
              ]),
            ),

            // Liste
            Expanded(child: list.isEmpty
              ? const Center(
                  child: Text('Aucune operation enregistree'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _OpTile(op: list[i]),
                )),
          ]);
        },
      ),
    );
  }

  void _showOpDialog(BuildContext context, WidgetRef ref) {
    String type = 'entree';
    String categorie = 'autre';
    final montantCtrl = TextEditingController();
    final descCtrl    = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Nouvelle operation'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'entree',
                    child: Text('Entree')),
                  DropdownMenuItem(value: 'sortie',
                    child: Text('Sortie')),
                ],
                onChanged: (v) => setS(() => type = v!),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: categorie,
                decoration: const InputDecoration(
                  labelText: 'Categorie'),
                items: const [
                  DropdownMenuItem(value: 'loyer_location',
                    child: Text('Loyer location')),
                  DropdownMenuItem(value: 'vente_vehicule',
                    child: Text('Vente vehicule')),
                  DropdownMenuItem(value: 'reparation',
                    child: Text('Reparation')),
                  DropdownMenuItem(value: 'entretien',
                    child: Text('Entretien')),
                  DropdownMenuItem(value: 'carburant',
                    child: Text('Carburant')),
                  DropdownMenuItem(value: 'assurance',
                    child: Text('Assurance')),
                  DropdownMenuItem(value: 'autre',
                    child: Text('Autre')),
                ],
                onChanged: (v) => setS(() => categorie = v!),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: montantCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Montant', suffixText: 'DA'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description'),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final mnt = double.tryParse(montantCtrl.text.trim());
                if (mnt == null || mnt <= 0 || descCtrl.text.trim().isEmpty) return;
                await supabase.from('caisse_operations').insert({
                  'type':        type,
                  'categorie':   categorie,
                  'montant':     mnt,
                  'description': descCtrl.text.trim(),
                  'date_op':     DateTime.now().toIso8601String(),
                  'created_by':  supabase.auth.currentUser?.id,
                });
                ref.invalidate(_caisseProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
  }
}

class _SoldeCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _SoldeCard(this.label, this.value, this.color, this.icon);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.2))),
    child: Column(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: AppTextStyles.label,
        textAlign: TextAlign.center),
    ]),
  );
}

class _OpTile extends StatelessWidget {
  final Map<String, dynamic> op;
  const _OpTile({required this.op});
  @override
  Widget build(BuildContext context) {
    final isEntree = op['type'] == 'entree';
    final color    = isEntree ? AppColors.secondary : AppColors.retard;
    final mnt      = (op['montant'] as num).toDouble();
    final veh      = op['vehicules'];
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(
            isEntree ? Icons.add : Icons.remove,
            color: color, size: 18)),
        title: Text(op['description'] ?? '---',
          style: AppTextStyles.heading3),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(op['categorie'] ?? '',
            style: AppTextStyles.label),
          if (veh != null)
            Text('${veh["marque"]} ${veh["modele"]}',
              style: AppTextStyles.label),
        ]),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
          Text('${isEntree ? "+" : "-"}${mnt.toInt()} DA',
            style: TextStyle(
              fontWeight: FontWeight.w700, color: color,
              fontSize: 14)),
          Builder(builder: (_) {
              final raw = op['date_op'] as String?;
              if (raw == null || raw.isEmpty) return const SizedBox.shrink();
              try {
                final d = DateTime.parse(raw).toLocal();
                return Text(
                  '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}',
                  style: AppTextStyles.label);
              } catch (_) { return Text(raw, style: AppTextStyles.label); }
            }),
        ]),
      ),
    );
  }
}