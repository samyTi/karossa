import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import 'ventes_provider.dart';
import '../../../shared/widgets/vente_detail_widgets.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

class VenteDetailScreen extends ConsumerWidget {
  final String venteId;
  const VenteDetailScreen({super.key, required this.venteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venteAsync = ref.watch(venteDetailProvider(venteId));

    return venteAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text(context.l10n.erreurAvecDetail(e.toString())))),
      data: (vente) => vente == null
          ? Scaffold(body: Center(child: Text(context.l10n.venteIntrouvable)))
          : Scaffold(
              appBar: CustomAppBar(
                title: vente.vehiculeNom ?? 'Détail vente',
                showHomeButton: true,
                actions: [
                  if (!vente.isSolde)
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline),
                      tooltip: context.l10n.marquerCommeSoldee,
                      onPressed: () => marquerVenteCommeSoldee(context, ref, vente),
                    ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    tooltip: context.l10n.genererContrat,
                    onPressed: () => genererContratPdf(context, ref, vente),
                  ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  StatutBanner(isSolde: vente.isSolde),
                  const SizedBox(height: 16),
                  InfoCard(vente: vente),
                  const SizedBox(height: 14),
                  FinanceCard(vente: vente),
                  const SizedBox(height: 14),
                  PaiementSection(vente: vente),
                  const SizedBox(height: 80),
                ],
              ),
              floatingActionButton: vente.isSolde ? null : FloatingActionButton.extended(
                onPressed: () => showAddPaiementModal(context, ref, vente),
                icon: const Icon(Icons.add),
                label: Text(context.l10n.ajouterPaiement),
              ),
            ),
    );
  }
}