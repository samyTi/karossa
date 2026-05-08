// lib/features/vehicules/presentation/vehicule_quick_financial.dart

// Widget résumé financier rapide affiché dans la fiche véhicule



import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';

import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';

import '../../../core/extensions/money_extensions.dart';




final vehiculeQuickFinancialsProvider =

    FutureProvider.autoDispose.family<Map<String, double>, String>((ref, vehiculeId) async {

  // Total revenus locations

  final locs = await ref.read(supabaseClientProvider)

    .from('locations')

    .select('montant_brut')

    .eq('vehicule_id', vehiculeId)

    .eq('statut', 'termine');

  final totalLoc = (locs as List)

    .fold(0.0, (s, l) => s + ((l['montant_brut'] as num?)?.toDouble() ?? 0));



  // Total réparations

  final reps = await ref.read(supabaseClientProvider)

    .from('reparations')

    .select('cout')

    .eq('vehicule_id', vehiculeId);

  final totalRep = (reps as List)

    .fold(0.0, (s, r) => s + ((r['cout'] as num?)?.toDouble() ?? 0));



  // Nombre de locations

  final nbLocs = locs.length;



  return {

    'revenus': totalLoc,

    'depenses': totalRep,

    'net': totalLoc - totalRep,

    'nb_locations': nbLocs.toDouble(),

  };

});



class VehiculeQuickFinancial extends ConsumerWidget {

  final String vehiculeId;

  const VehiculeQuickFinancial({super.key, required this.vehiculeId});



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    final async = ref.watch(vehiculeQuickFinancialsProvider(vehiculeId));



    return async.when(

      loading: () => const SizedBox(

        height: 80,

        child: Center(child: LinearProgressIndicator())),

      error: (_, __) => const SizedBox.shrink(),

      data: (fin) => Container(

        padding: const EdgeInsets.all(14),

        decoration: BoxDecoration(

          gradient: LinearGradient(

            colors: [

              AppColors.primary.withValues(alpha: 0.08),

              AppColors.secondary.withValues(alpha: 0.05),

            ],

          ),

          borderRadius: BorderRadius.circular(14),

          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),

        ),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Row(

              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              children: [

                const Text('Bilan financier',

                  style: TextStyle(

                    fontWeight: FontWeight.bold, fontSize: 14)),

                TextButton.icon(

                  onPressed: () =>

                    context.push('/vehicules/\$vehiculeId/financials'),

                  icon: const Icon(Icons.open_in_new, size: 14),

                  label: const Text('Détail', style: TextStyle(fontSize: 12)),

                  style: TextButton.styleFrom(

                    foregroundColor: AppColors.primary,

                    padding: EdgeInsets.zero,

                    minimumSize: const Size(0, 30),

                  ),

                ),

              ],

            ),

            const SizedBox(height: 10),

            Row(children: [

              _FinStat('Revenus', fin['revenus']!.toDA(),

                AppColors.secondary, Icons.trending_up),

              const SizedBox(width: 10),

              _FinStat('Dépenses', fin['depenses']!.toDA(),

                AppColors.retard, Icons.trending_down),

              const SizedBox(width: 10),

              _FinStat('Net', fin['net']!.toDA(),

                fin['net']! >= 0 ? AppColors.secondary : AppColors.retard,

                Icons.account_balance_wallet_outlined),

            ]),

            const SizedBox(height: 6),

            Text("${fin['nb_locations']!.toInt()} location(s) effectuée(s)",

              style: const TextStyle(

                fontSize: 11, color: AppColors.textSecondary)),

          ],

        ),

      ),

    );

  }

}



class _FinStat extends StatelessWidget {

  final String label, value;

  final Color color;

  final IconData icon;

  const _FinStat(this.label, this.value, this.color, this.icon);



  @override

  Widget build(BuildContext context) => Expanded(

    child: Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        Icon(icon, color: color, size: 16),

        const SizedBox(height: 4),

        Text(value,

          style: TextStyle(color: color,

            fontWeight: FontWeight.bold, fontSize: 13)),

        Text(label,

          style: const TextStyle(

            fontSize: 10, color: AppColors.textSecondary)),

      ],

    ),

  );

}

