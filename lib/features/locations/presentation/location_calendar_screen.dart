// lib/features/locations/presentation/location_calendar_screen.dart
//
// Vue planning visuelle : une ligne par véhicule, les barres représentent
// les locations sur une fenêtre glissante de 21 jours. Permet de repérer
// en un coup d'œil les disponibilités et les conflits, ce qu'une simple
// liste ne permet pas. Lecture seule pour l'instant (tap → détail location).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/extensions/date_extensions.dart';
import '../../../shared/widgets/modern_app_bar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../vehicules/presentation/vehicules_provider.dart';
import '../domain/location_model.dart';
import 'locations_provider.dart';

const double _dayWidth = 42;
const double _rowHeight = 56;
const double _vehiculeColWidth = 130;

final _calendarWindowStartProvider = StateProvider.autoDispose<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 2));
});

class LocationCalendarScreen extends ConsumerWidget {
  const LocationCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiculesAsync = ref.watch(vehiculesProvider);
    final locationsAsync = ref.watch(locationsAllProvider);
    final windowStart = ref.watch(_calendarWindowStartProvider);
    final days = List.generate(21, (i) => windowStart.add(Duration(days: i)));

    return Scaffold(
      appBar: ModernAppBar(
        title: context.l10n.planningLocations,
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => ref.read(_calendarWindowStartProvider.notifier).state =
                windowStart.subtract(const Duration(days: 7)),
          ),
          TextButton(
            onPressed: () => ref.read(_calendarWindowStartProvider.notifier).state =
                DateTime.now().subtract(const Duration(days: 2)),
            child: Text(context.l10n.aujourdhui, style: const TextStyle(color: Colors.white)),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => ref.read(_calendarWindowStartProvider.notifier).state =
                windowStart.add(const Duration(days: 7)),
          ),
        ],
      ),
      body: vehiculesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(context.l10n.erreurAvecDetail(e.toString()))),
        data: (vehicules) {
          if (vehicules.isEmpty) {
            return EmptyState(
              icon: Icons.directions_car_outlined,
              message: context.l10n.aucunVehiculeAAfficher,
            );
          }
          return locationsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(context.l10n.erreurAvecDetail(e.toString()))),
            data: (locations) {
              final byVehicule = <String, List<Location>>{};
              for (final l in locations) {
                byVehicule.putIfAbsent(l.vehiculeId, () => []).add(l);
              }

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DateHeaderRow(days: days),
                      const Divider(height: 1),
                      for (final v in vehicules)
                        _VehiculeRow(
                          label: '${v.marque} ${v.modele}',
                          sublabel: v.immatriculation ?? '',
                          days: days,
                          locations: byVehicule[v.id] ?? const [],
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DateHeaderRow extends StatelessWidget {
  final List<DateTime> days;
  const _DateHeaderRow({required this.days});

  static const _moisAbrege = [
    'jan', 'fév', 'mar', 'avr', 'mai', 'jun',
    'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: _vehiculeColWidth,
          height: 44,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(context.l10n.vehicule, style: AppTextStyles.bold(AppTextStyles.bodySmall)),
        ),
        ...days.map((d) {
          final isToday = d.isToday;
          return Container(
            width: _dayWidth,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isToday ? AppColors.primary.withOpacity(0.08) : null,
              border: Border(left: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_moisAbrege[d.month - 1], style: AppTextStyles.caption),
                Text('${d.day}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isToday ? AppColors.primary : AppColors.textPrimary,
                    )),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _VehiculeRow extends StatelessWidget {
  final String label;
  final String sublabel;
  final List<DateTime> days;
  final List<Location> locations;

  const _VehiculeRow({
    required this.label,
    required this.sublabel,
    required this.days,
    required this.locations,
  });

  @override
  Widget build(BuildContext context) {
    final start = days.first;
    final totalWidth = days.length * _dayWidth;

    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: _vehiculeColWidth,
            height: _rowHeight,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: AppTextStyles.bold(AppTextStyles.bodySmall),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(sublabel, style: AppTextStyles.caption,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          SizedBox(
            width: totalWidth,
            height: _rowHeight,
            child: Stack(
              children: [
                // Grille de fond (une ligne verticale par jour)
                Row(
                  children: days
                      .map((_) => Container(
                            width: _dayWidth,
                            decoration: BoxDecoration(
                              border: Border(left: BorderSide(color: Colors.grey.shade100)),
                            ),
                          ))
                      .toList(),
                ),
                // Barres de location
                for (final loc in locations)
                  ..._buildBar(context, loc, start, totalWidth),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBar(BuildContext context, Location loc, DateTime windowStart, double totalWidth) {
    final debut = DateTime(loc.dateDebut.year, loc.dateDebut.month, loc.dateDebut.day);
    final fin = loc.dateFinReelle ?? loc.dateFinPrevue ?? debut.add(const Duration(days: 1));
    final finDay = DateTime(fin.year, fin.month, fin.day);

    final offsetDays = debut.difference(windowStart).inDays;
    final durationDays = (finDay.difference(debut).inDays + 1).clamp(1, 1000);

    // Ignore les barres totalement hors fenêtre visible
    if (offsetDays + durationDays < 0 || offsetDays > days.length) return [];

    final left = (offsetDays * _dayWidth).clamp(-_dayWidth * 60, totalWidth);
    final width = (durationDays * _dayWidth).clamp(_dayWidth * 0.5, totalWidth + _dayWidth * 60);

    final color = _statusColor(loc);

    return [
      Positioned(
        left: left,
        top: 8,
        child: GestureDetector(
          onTap: () => context.push('/locations/${loc.id}/retour'),
          child: Container(
            width: width,
            height: _rowHeight - 16,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: color.withOpacity(0.85),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Text(
              loc.clientNom ?? 'Client',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    ];
  }

  Color _statusColor(Location loc) => switch (loc.statut) {
        LocationStatut.en_cours => loc.isOverdue ? AppColors.retard : AppColors.secondary,
        LocationStatut.termine => AppColors.vendu,
        LocationStatut.annule => Colors.grey,
        LocationStatut.retard => AppColors.retard,
      };
}
