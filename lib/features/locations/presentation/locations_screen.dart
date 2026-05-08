import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';

import '../../../core/theme/app_text_styles.dart';

import '../../../shared/widgets/custom_app_bar.dart';

import '../../../shared/widgets/empty_state.dart';

import '../../../shared/widgets/shimmer_loading.dart';

import '../domain/location_model.dart';

import 'locations_provider.dart';

import '../../../shared/widgets/filter_chips_widget.dart';



class LocationsScreen extends ConsumerStatefulWidget {

  const LocationsScreen({super.key});

  @override

  ConsumerState<LocationsScreen> createState() => _LocationsScreenState();

}



class _LocationsScreenState extends ConsumerState<LocationsScreen> {

  String? _filterStatut;



  @override

  Widget build(BuildContext context) {

    final actives = ref.watch(locationsActivesProvider);

    return Scaffold(

      appBar: const CustomAppBar(

        title: 'Locations',

        showBackButton: false,

        showHomeButton: true,

      ),

      floatingActionButton: FloatingActionButton.extended(

        onPressed: () => context.push('/locations/new'),

        icon: const Icon(Icons.add),

        label: const Text('Nouveau contrat'),

        backgroundColor: AppColors.secondary,

        foregroundColor: Colors.white,

      ),

      body: Column(children: [

        FilterChipsRow(

          chips: const [

            FilterChipData(label: 'En cours', value: 'en_cours', color: AppColors.secondary, icon: Icons.play_circle_outline),

            FilterChipData(label: 'Retard', value: 'retard', color: AppColors.retard, icon: Icons.access_time),

            FilterChipData(label: 'Terminé', value: 'termine', color: AppColors.vendu, icon: Icons.check_circle_outline),

          ],

          selected: _filterStatut,

          onSelected: (v) => setState(() => _filterStatut = v),

        ),

        Expanded(child: actives.when(

          loading: () => const LocationsListShimmer(itemCount: 5),

          error: (e, _) => Center(child: Text('Erreur: $e')),

          data: (list) => list.isEmpty

            ? const EmptyState(

                icon: Icons.car_rental,

                message: 'Aucune location active')

            : ListView.builder(

                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),

                itemCount: list.length,

                itemBuilder: (_, i) => _LocationCard(

                  location: list[i]),

              ),

        )),

      ]),

    );

  }

}



class _LocationCard extends StatelessWidget {

  final Location location;

  const _LocationCard({required this.location});



  @override

  Widget build(BuildContext context) {

    final color = location.isOverdue

      ? AppColors.retard : AppColors.secondary;

    return Card(

      margin: const EdgeInsets.only(bottom: 10),

      child: Padding(

        padding: const EdgeInsets.all(14),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

          Row(children: [

            Expanded(child: Text(

              location.vehiculeNom ?? '---',

              style: AppTextStyles.heading3)),

            if (location.isOverdue)

              Container(

                padding: const EdgeInsets.symmetric(

                  horizontal: 8, vertical: 3),

                decoration: BoxDecoration(

                  color: AppColors.retard.withValues(alpha: 0.1),

                  borderRadius: BorderRadius.circular(8)),

                child: Text('${location.joursRetard}j retard',

                  style: const TextStyle(

                    color: AppColors.retard,

                    fontSize: 11, fontWeight: FontWeight.w700))),

          ]),

          const SizedBox(height: 4),

          Text(location.clientNom ?? '---',

            style: AppTextStyles.bodySecondary),

          const SizedBox(height: 6),

          Row(children: [

            Icon(Icons.calendar_today, size: 12, color: color),

            const SizedBox(width: 4),

            Text(

              'Retour : '

              '${location.dateFinPrevue.day.toString().padLeft(2,"0")}/'

              '${location.dateFinPrevue.month.toString().padLeft(2,"0")}/'

              '${location.dateFinPrevue.year}',

              style: TextStyle(fontSize: 12,

                color: color, fontWeight: FontWeight.w600)),

            const Spacer(),

            Text('${(location.prixJour * location.nbJours).toInt()} DA',

              style: AppTextStyles.money.copyWith(fontSize: 14)),

          ]),

          const SizedBox(height: 10),

          Row(mainAxisAlignment: MainAxisAlignment.end,

            children: [

            OutlinedButton.icon(

              style: OutlinedButton.styleFrom(

                foregroundColor: AppColors.secondary,

                side: const BorderSide(

                  color: AppColors.secondary),

                padding: const EdgeInsets.symmetric(

                  horizontal: 12, vertical: 6),

                textStyle: const TextStyle(fontSize: 12)),

              icon: const Icon(Icons.keyboard_return, size: 14),

              label: const Text('Retour vehicule'),

              onPressed: () => context.push(

                '/locations/${location.id}/retour'),

            ),

          ]),

        ]),

      ),

    );

  }

}

