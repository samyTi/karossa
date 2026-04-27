import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../main.dart';
import '../../../shared/widgets/empty_state.dart';
import '../domain/vehicule_model.dart';

/// Provider pour récupérer l'historique complet d'un véhicule
final vehiculeHistoryProvider =
    FutureProvider.autoDispose.family<VehiculeHistory, String>((ref, vehiculeId) {
  return _fetchVehiculeHistory(vehiculeId);
});

class VehiculeHistory {
  final Vehicule vehicule;
  final List<LocationHistory> locations;
  final List<ReparationHistory> reparations;
  final List<EntretienHistory> entretiens;
  final List<VenteHistory> ventes;
  final List<EchangeHistory> echanges;

  const VehiculeHistory({
    required this.vehicule,
    required this.locations,
    required this.reparations,
    required this.entretiens,
    required this.ventes,
    required this.echanges,
  });

  double get totalRevenusLocations {
    return locations.fold(0.0, (sum, l) => sum + (l.montantBrut ?? 0));
  }

  double get totalDepensesReparations {
    return reparations.fold(0.0, (sum, r) => sum + r.cout);
  }
}

class LocationHistory {
  final String id;
  final String clientNom;
  final DateTime dateDebut;
  final DateTime? dateFinPrevue;
  final DateTime? dateFinReelle;
  final int kmDepart;
  final int? kmRetour;
  final double? montantBrut;
  final String statut;

  const LocationHistory({
    required this.id,
    required this.clientNom,
    required this.dateDebut,
    this.dateFinPrevue,
    this.dateFinReelle,
    required this.kmDepart,
    this.kmRetour,
    this.montantBrut,
    required this.statut,
  });

  factory LocationHistory.fromJson(Map<String, dynamic> json) {
    final client = json['clients'] ?? {};
    return LocationHistory(
      id: json['id'],
      clientNom: '${client['prenom'] ?? ''} ${client['nom'] ?? ''}'.trim(),
      dateDebut: DateTime.parse(json['date_debut']),
      dateFinPrevue: json['date_fin_prevue'] != null
          ? DateTime.parse(json['date_fin_prevue'])
          : null,
      dateFinReelle: json['date_fin_reelle'] != null
          ? DateTime.parse(json['date_fin_reelle'])
          : null,
      kmDepart: json['km_depart'] ?? 0,
      kmRetour: json['km_retour'],
      montantBrut: json['montant_brut'] != null
          ? (json['montant_brut'] as num).toDouble()
          : null,
      statut: json['statut'] ?? 'en_cours',
    );
  }
}

class ReparationHistory {
  final String id;
  final String typeRep;
  final String description;
  final String? prestataire;
  final double cout;
  final DateTime dateRep;
  final int? kmAuMoment;

  const ReparationHistory({
    required this.id,
    required this.typeRep,
    required this.description,
    this.prestataire,
    required this.cout,
    required this.dateRep,
    this.kmAuMoment,
  });

  factory ReparationHistory.fromJson(Map<String, dynamic> json) {
    return ReparationHistory(
      id: json['id'],
      typeRep: json['type_rep'] ?? 'autre',
      description: json['description'] ?? '',
      prestataire: json['prestataire'],
      cout: (json['cout'] as num?)?.toDouble() ?? 0.0,
      dateRep: DateTime.parse(json['date_rep']),
      kmAuMoment: json['km_au_moment'],
    );
  }

  String get typeLabel => switch (typeRep) {
        'mecanique' => 'Mécanique',
        'carrosserie' => 'Carrosserie',
        'electrique' => 'Électrique',
        'pneus' => 'Pneus',
        _ => 'Autre',
      };
}

class EntretienHistory {
  final String id;
  final String typeAlerte;
  final DateTime? dateEcheance;
  final int? kmEcheance;
  final String statut;

  const EntretienHistory({
    required this.id,
    required this.typeAlerte,
    this.dateEcheance,
    this.kmEcheance,
    required this.statut,
  });

  factory EntretienHistory.fromJson(Map<String, dynamic> json) {
    return EntretienHistory(
      id: json['id'],
      typeAlerte: json['type_alerte'] ?? 'autre',
      dateEcheance: json['date_echeance'] != null
          ? DateTime.parse(json['date_echeance'])
          : null,
      kmEcheance: json['km_echeance'],
      statut: json['statut'] ?? 'active',
    );
  }

  String get typeLabel => switch (typeAlerte) {
        'vidange' => 'Vidange',
        'controle_technique' => 'Contrôle technique',
        'assurance' => 'Assurance',
        'vignette' => 'Vignette',
        'pneus' => 'Pneus',
        _ => 'Autre',
      };
}

class VenteHistory {
  final String id;
  final String clientNom;
  final double prixVente;
  final DateTime dateVente;
  final String statutPaiement;

  const VenteHistory({
    required this.id,
    required this.clientNom,
    required this.prixVente,
    required this.dateVente,
    required this.statutPaiement,
  });

  factory VenteHistory.fromJson(Map<String, dynamic> json) {
    final client = json['clients'] ?? {};
    return VenteHistory(
      id: json['id'],
      clientNom: '${client['prenom'] ?? ''} ${client['nom'] ?? ''}'.trim(),
      prixVente: (json['prix_vente'] as num?)?.toDouble() ?? 0.0,
      dateVente: DateTime.parse(json['date_vente']),
      statutPaiement: json['statut_paiement'] ?? 'partiel',
    );
  }
}

class EchangeHistory {
  final String id;
  final String clientNom;
  final String vehiculeReprisMarque;
  final String vehiculeReprisModele;
  final double valeurReprise;
  final DateTime dateEchange;

  const EchangeHistory({
    required this.id,
    required this.clientNom,
    required this.vehiculeReprisMarque,
    required this.vehiculeReprisModele,
    required this.valeurReprise,
    required this.dateEchange,
  });

  factory EchangeHistory.fromJson(Map<String, dynamic> json) {
    final client = json['clients'] ?? {};
    return EchangeHistory(
      id: json['id'],
      clientNom: '${client['prenom'] ?? ''} ${client['nom'] ?? ''}'.trim(),
      vehiculeReprisMarque: json['vehicule_reprise_marque'] ?? '',
      vehiculeReprisModele: json['vehicule_reprise_modele'] ?? '',
      valeurReprise: (json['valeur_reprise'] as num?)?.toDouble() ?? 0.0,
      dateEchange: DateTime.parse(json['date_echange']),
    );
  }
}

Future<VehiculeHistory> _fetchVehiculeHistory(String vehiculeId) async {
  // Récupérer le véhicule
  final vehiculeData = await supabase
      .from('vehicules')
      .select('*, vehicule_proprietes(*, profiles(prenom, nom))')
      .eq('id', vehiculeId)
      .single();

  final vehicule = Vehicule.fromJson(vehiculeData);

  // Récupérer les locations
  final locationsData = await supabase
      .from('locations')
      .select('*, clients(prenom, nom)')
      .eq('vehicule_id', vehiculeId)
      .order('date_debut', ascending: false);

  final locations = locationsData
      .map((j) => LocationHistory.fromJson(j))
      .toList();

  // Récupérer les réparations
  final reparationsData = await supabase
      .from('reparations')
      .select('*')
      .eq('vehicule_id', vehiculeId)
      .order('date_rep', ascending: false);

  final reparations = reparationsData
      .map((j) => ReparationHistory.fromJson(j))
      .toList();

  // Récupérer les entretiens
  final entretiensData = await supabase
      .from('alertes_entretien')
      .select('*')
      .eq('vehicule_id', vehiculeId)
      .order('created_at', ascending: false);

  final entretiens = entretiensData
      .map((j) => EntretienHistory.fromJson(j))
      .toList();

  // Récupérer les ventes
  final ventesData = await supabase
      .from('ventes')
      .select('*, clients(prenom, nom)')
      .eq('vehicule_id', vehiculeId)
      .order('date_vente', ascending: false);

  final ventes = ventesData
      .map((j) => VenteHistory.fromJson(j))
      .toList();

  // Récupérer les échanges
  final echangesData = await supabase
      .from('echanges')
      .select('*, clients(prenom, nom)')
      .eq('vehicule_cede_id', vehiculeId)
      .order('date_echange', ascending: false);

  final echanges = echangesData
      .map((j) => EchangeHistory.fromJson(j))
      .toList();

  return VehiculeHistory(
    vehicule: vehicule,
    locations: locations,
    reparations: reparations,
    entretiens: entretiens,
    ventes: ventes,
    echanges: echanges,
  );
}

class VehiculeHistoryScreen extends ConsumerWidget {
  final String vehiculeId;
  const VehiculeHistoryScreen({super.key, required this.vehiculeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(vehiculeHistoryProvider(vehiculeId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique du véhicule'),
      ),
      body: history.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (h) => _HistoryBody(history: h),
      ),
    );
  }
}

class _HistoryBody extends StatelessWidget {
  final VehiculeHistory history;
  const _HistoryBody({required this.history});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Résumé financier
        _SummaryCard(
          vehicule: history.vehicule,
          totalRevenusLocations: history.totalRevenusLocations,
          totalDepensesReparations: history.totalDepensesReparations,
          nbLocations: history.locations.length,
          nbReparations: history.reparations.length,
        ),
        const SizedBox(height: 20),

        // Locations
        if (history.locations.isNotEmpty) ...[
          _SectionHeader(
            title: 'Locations',
            count: history.locations.length,
            icon: Icons.car_rental,
            color: AppColors.secondary,
          ),
          const SizedBox(height: 8),
          ...history.locations.map((loc) => _LocationCard(
                location: loc,
                fmt: fmt,
              )),
          const SizedBox(height: 20),
        ],

        // Réparations
        if (history.reparations.isNotEmpty) ...[
          _SectionHeader(
            title: 'Réparations',
            count: history.reparations.length,
            icon: Icons.build,
            color: AppColors.reparation,
          ),
          const SizedBox(height: 8),
          ...history.reparations.map((rep) => _ReparationCard(
                reparation: rep,
                fmt: fmt,
              )),
          const SizedBox(height: 20),
        ],

        // Entretien
        if (history.entretiens.isNotEmpty) ...[
          _SectionHeader(
            title: 'Entretien',
            count: history.entretiens.length,
            icon: Icons.notifications_outlined,
            color: AppColors.accent,
          ),
          const SizedBox(height: 8),
          ...history.entretiens.map((ent) => _EntretienCard(
                entretien: ent,
                fmt: fmt,
              )),
          const SizedBox(height: 20),
        ],

        // Ventes
        if (history.ventes.isNotEmpty) ...[
          _SectionHeader(
            title: 'Ventes',
            count: history.ventes.length,
            icon: Icons.sell,
            color: AppColors.primary,
          ),
          const SizedBox(height: 8),
          ...history.ventes.map((vente) => _VenteCard(
                vente: vente,
                fmt: fmt,
              )),
          const SizedBox(height: 20),
        ],

        // Échanges
        if (history.echanges.isNotEmpty) ...[
          _SectionHeader(
            title: 'Échanges',
            count: history.echanges.length,
            icon: Icons.swap_horiz,
            color: AppColors.accent,
          ),
          const SizedBox(height: 8),
          ...history.echanges.map((echange) => _EchangeCard(
                echange: echange,
                fmt: fmt,
              )),
          const SizedBox(height: 20),
        ],

        // Si aucun historique
        if (history.locations.isEmpty &&
            history.reparations.isEmpty &&
            history.entretiens.isEmpty &&
            history.ventes.isEmpty &&
            history.echanges.isEmpty)
          EmptyState(
            icon: Icons.history,
            message: 'Aucun historique pour ce véhicule',
          ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Vehicule vehicule;
  final double totalRevenusLocations;
  final double totalDepensesReparations;
  final int nbLocations;
  final int nbReparations;

  const _SummaryCard({
    required this.vehicule,
    required this.totalRevenusLocations,
    required this.totalDepensesReparations,
    required this.nbLocations,
    required this.nbReparations,
  });

  @override
  Widget build(BuildContext context) {
    final solde = totalRevenusLocations - totalDepensesReparations;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            vehicule.displayName,
            style: AppTextStyles.heading2,
          ),
          const SizedBox(height: 4),
          Text(
            '${vehicule.marque} ${vehicule.modele} • ${vehicule.annee}',
            style: AppTextStyles.bodySecondary,
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  label: 'Revenus locations',
                  value: '${totalRevenusLocations.toInt()} DA',
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryItem(
                  label: 'Dépenses réparations',
                  value: '${totalDepensesReparations.toInt()} DA',
                  color: AppColors.reparation,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  label: 'Locations',
                  value: '$nbLocations',
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryItem(
                  label: 'Réparations',
                  value: '$nbReparations',
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _SummaryItem(
            label: 'Solde estimé',
            value: '${solde.toInt()} DA',
            color: solde >= 0 ? AppColors.secondary : AppColors.retard,
            isBold: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool isBold;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 18 : 15,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(title, style: AppTextStyles.heading3),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _LocationCard extends StatelessWidget {
  final LocationHistory location;
  final DateFormat fmt;

  const _LocationCard({
    required this.location,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final isEnCours = location.statut == 'en_cours';
    // isTermine supprimé — non utilisé
    final isRetard = location.statut == 'retard';

    Color statusColor;
    if (isEnCours) {
      statusColor = AppColors.secondary;
    } else if (isRetard) {
      statusColor = AppColors.retard;
    } else {
      statusColor = AppColors.vendu;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    location.clientNom.isEmpty ? 'Client inconnu' : location.clientNom,
                    style: AppTextStyles.heading3,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    location.statut.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'Du ${fmt.format(location.dateDebut)}',
                  style: AppTextStyles.label,
                ),
                if (location.dateFinPrevue != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    'au ${fmt.format(location.dateFinPrevue!)}',
                    style: AppTextStyles.label,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.speed, size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${location.kmDepart} km',
                  style: AppTextStyles.label,
                ),
                if (location.kmRetour != null) ...[
                  Text(' → ${location.kmRetour} km', style: AppTextStyles.label),
                ],
                const Spacer(),
                if (location.montantBrut != null)
                  Text(
                    '${location.montantBrut!.toInt()} DA',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReparationCard extends StatelessWidget {
  final ReparationHistory reparation;
  final DateFormat fmt;

  const _ReparationCard({
    required this.reparation,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    reparation.typeLabel,
                    style: AppTextStyles.heading3,
                  ),
                ),
                Text(
                  '${reparation.cout.toInt()} DA',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.reparation,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              reparation.description,
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(fmt.format(reparation.dateRep), style: AppTextStyles.label),
                if (reparation.prestataire != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.business, size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(reparation.prestataire!, style: AppTextStyles.label),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EntretienCard extends StatelessWidget {
  final EntretienHistory entretien;
  final DateFormat fmt;

  const _EntretienCard({
    required this.entretien,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    bool isExpired = entretien.statut == 'fait'
        ? false
        : entretien.dateEcheance != null &&
            DateTime.now().isAfter(entretien.dateEcheance!);
    bool isUrgent = entretien.statut != 'fait' &&
        entretien.dateEcheance != null &&
        entretien.dateEcheance!.difference(DateTime.now()).inDays <= 7;

    Color statusColor;
    String statusText;
    if (entretien.statut == 'fait') {
      statusColor = AppColors.secondary;
      statusText = 'Fait';
    } else if (isExpired) {
      statusColor = AppColors.retard;
      statusText = 'Expiré';
    } else if (isUrgent) {
      statusColor = AppColors.accent;
      statusText = 'Urgent';
    } else {
      statusColor = AppColors.secondary;
      statusText = 'Prévu';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                entretien.typeAlerte == 'vidange'
                    ? Icons.opacity
                    : entretien.typeAlerte == 'controle_technique'
                        ? Icons.fact_check_outlined
                        : entretien.typeAlerte == 'assurance'
                            ? Icons.security_outlined
                            : Icons.notifications_outlined,
                color: statusColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entretien.typeLabel,
                    style: AppTextStyles.heading3,
                  ),
                  if (entretien.dateEcheance != null)
                    Text(
                      'Échéance: ${fmt.format(entretien.dateEcheance!)}',
                      style: AppTextStyles.label,
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VenteCard extends StatelessWidget {
  final VenteHistory vente;
  final DateFormat fmt;

  const _VenteCard({
    required this.vente,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final isComplet = vente.statutPaiement == 'complet';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vente.clientNom.isEmpty ? 'Client inconnu' : vente.clientNom,
                    style: AppTextStyles.heading3,
                  ),
                  Text(
                    fmt.format(vente.dateVente),
                    style: AppTextStyles.label,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${vente.prixVente.toInt()} DA',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: isComplet
                        ? AppColors.secondary.withValues(alpha: 0.1)
                        : AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isComplet ? 'Payé' : 'En cours',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isComplet ? AppColors.secondary : AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EchangeCard extends StatelessWidget {
  final EchangeHistory echange;
  final DateFormat fmt;

  const _EchangeCard({
    required this.echange,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    echange.clientNom.isEmpty ? 'Client inconnu' : echange.clientNom,
                    style: AppTextStyles.heading3,
                  ),
                  Text(
                    '${echange.vehiculeReprisMarque} ${echange.vehiculeReprisModele}',
                    style: AppTextStyles.bodySecondary,
                  ),
                  Text(
                    fmt.format(echange.dateEchange),
                    style: AppTextStyles.label,
                  ),
                ],
              ),
            ),
            Text(
              '${echange.valeurReprise.toInt()} DA',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}