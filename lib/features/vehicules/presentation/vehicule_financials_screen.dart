// lib/features/vehicules/presentation/vehicule_financials_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/extensions/money_extensions.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/vehicule_financials_repository.dart';
import '../domain/vehicule_financials.dart';

// Provider local à cet écran
final _financialsProvider =
    FutureProvider.autoDispose.family<VehiculeFinancials, String>((ref, id) {
  return VehiculeFinancialsRepository(Supabase.instance.client).getFinancials(id);
});

class VehiculeFinancialsScreen extends ConsumerWidget {
  final String vehiculeId;
  final String vehiculeNom;

  const VehiculeFinancialsScreen({
    super.key,
    required this.vehiculeId,
    required this.vehiculeNom,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final financialsAsync = ref.watch(_financialsProvider(vehiculeId));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(vehiculeNom,
                style: const TextStyle(fontSize: 16)),
            const Text('Analyse financière',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_financialsProvider(vehiculeId)),
          ),
        ],
      ),
      body: financialsAsync.when(
        loading: () => const Center(child: const CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Erreur: $e', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(_financialsProvider(vehiculeId)),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (f) => RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(_financialsProvider(vehiculeId)),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _MargeBanner(f: f),
                const SizedBox(height: 14),
                _DepensesCard(f: f),
                const SizedBox(height: 12),
                _RevenusCard(f: f),
                const SizedBox(height: 12),
                _OccupationCard(f: f),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Bannière marge ────────────────────────────────────────────────────────
class _MargeBanner extends StatelessWidget {
  final VehiculeFinancials f;
  const _MargeBanner({required this.f});

  @override
  Widget build(BuildContext context) {
    final color = f.isRentable ? Colors.green : Colors.red;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 2),
      ),
      child: Column(
        children: [
          Icon(
            f.isRentable ? Icons.trending_up : Icons.trending_down,
            size: 36,
            color: color,
          ),
          const SizedBox(height: 8),
          Text(
            f.margeBrute.toDA(),
            style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            'Marge brute ${f.margePctLabel}',
            style: TextStyle(fontSize: 13, color: color),
          ),
        ],
      ),
    );
  }
}

// ─── Dépenses ──────────────────────────────────────────────────────────────
class _DepensesCard extends StatelessWidget {
  final VehiculeFinancials f;
  const _DepensesCard({required this.f});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.arrow_circle_down, color: Colors.red),
              const SizedBox(width: 8),
              const Text('DÉPENSES',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
            const Divider(height: 20),
            _Ligne('Prix d\'achat', f.prixAchat),
            _Ligne('Réparations', f.totalReparations),
            _Ligne('Entretiens & frais', f.totalEntretiens),
            const Divider(height: 16),
            _Ligne('PRIX DE REVIENT', f.totalDepenses, bold: true),
          ],
        ),
      ),
    );
  }
}

// ─── Revenus ───────────────────────────────────────────────────────────────
class _RevenusCard extends StatelessWidget {
  final VehiculeFinancials f;
  const _RevenusCard({required this.f});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.arrow_circle_up, color: Colors.green),
              const SizedBox(width: 8),
              const Text('REVENUS',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
            const Divider(height: 20),
            _Ligne('Locations', f.revenusLocations),
            if (f.revenusVente != null)
              _Ligne('Vente', f.revenusVente!),
            const Divider(height: 16),
            _Ligne('TOTAL REVENUS', f.revenusTotal,
                bold: true, color: Colors.green),
          ],
        ),
      ),
    );
  }
}

// ─── Occupation ────────────────────────────────────────────────────────────
class _OccupationCard extends StatelessWidget {
  final VehiculeFinancials f;
  const _OccupationCard({required this.f});

  @override
  Widget build(BuildContext context) {
    final occupColor = f.tauxOccupationPct >= 60
        ? Colors.green
        : f.tauxOccupationPct >= 30
            ? Colors.orange
            : Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.car_rental, color: Colors.blue),
              const SizedBox(width: 8),
              const Text('LOCATIONS',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatBox('${f.nbLocations}', 'Locations'),
                _StatBox('${f.joursLoues}j', 'Jours loués'),
                _StatBox(f.tauxOccupationLabel, 'Occupation',
                    color: occupColor),
                _StatBox(
                  '${f.revenusParJour.toStringAsFixed(0)} DA',
                  '/jour moy.',
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: f.tauxOccupationPct / 100,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(occupColor),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Taux d\'occupation: ${f.tauxOccupationLabel}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets utilitaires ───────────────────────────────────────────────────
class _Ligne extends StatelessWidget {
  final String label;
  final double valeur;
  final bool bold;
  final Color? color;

  const _Ligne(this.label, this.valeur,
      {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: color,
      fontSize: bold ? 15 : 13,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(valeur.toDA(),
              style: style.copyWith(fontFeatures: null)),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;

  const _StatBox(this.value, this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: color)),
        Text(label,
            style:
                TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }
}