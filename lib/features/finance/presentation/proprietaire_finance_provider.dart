// lib/features/finance/presentation/proprietaire_finance_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/proprietaire_finance_repository.dart';
import '../domain/proprietaire_solde_model.dart';
import '../domain/versement_model.dart';

final proprietaireFinanceRepositoryProvider =
    Provider<ProprietaireFinanceRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final showroomId = ref.watch(currentShowroomIdProvider) ?? '';
  return ProprietaireFinanceRepository(client, showroomId: showroomId);
});

/// Dossier financier consolidé d'un propriétaire/associé donné
/// (parts de copropriété sur les véhicules).
final proprietaireSoldeProvider = FutureProvider.autoDispose
    .family<ProprietaireSolde, String>((ref, proprietaireId) {
  return ref
      .watch(proprietaireFinanceRepositoryProvider)
      .getSolde(proprietaireId, typePart: TypePart.partProprietaire);
});

/// Dossier financier consolidé d'un gérant donné (commissions perçues sur
/// locations/ventes/échanges) — même repository, filtre différent.
/// Note : un gérant peut être *aussi* copropriétaire d'un véhicule ; ce
/// provider ne consolide que sa commission, pas ses éventuelles parts.
final gerantCommissionProvider = FutureProvider.autoDispose
    .family<ProprietaireSolde, String>((ref, gerantId) {
  return ref
      .watch(proprietaireFinanceRepositoryProvider)
      .getSolde(gerantId, typePart: TypePart.commissionGerant);
});

/// Action : enregistrer un nouveau versement, puis rafraîchir le dossier.
/// [typePart] détermine dans quel solde (propriétaire ou commission gérant)
/// ce versement vient se déduire — voir [ProprietaireFinanceRepository.creerVersement].
final creerVersementProvider = Provider.autoDispose(
  (ref) => (
    {
      required String proprietaireId,
      required double montant,
      required DateTime dateVersement,
      ModeVersement? mode,
      String? notes,
      TypePart typePart = TypePart.partProprietaire,
    }
  ) async {
    final createdBy = ref.read(currentProfileProvider).valueOrNull?.id;
    await ref.read(proprietaireFinanceRepositoryProvider).creerVersement(
          proprietaireId: proprietaireId,
          montant: montant,
          dateVersement: dateVersement,
          mode: mode,
          notes: notes,
          createdBy: createdBy,
          typePart: typePart,
        );
    // Recharge la vue, peu importe que le bénéficiaire soit consulté comme
    // propriétaire ou comme gérant (l'appelant n'a pas forcément invalidé
    // le bon provider lui-même).
    ref.invalidate(proprietaireSoldeProvider(proprietaireId));
    ref.invalidate(gerantCommissionProvider(proprietaireId));
  },
);

/// Action : enregistrer un transfert d'argent entre deux utilisateurs
/// (n'impacte jamais la caisse réelle, voir [TransfertUtilisateur]).
final creerTransfertProvider = Provider.autoDispose(
  (ref) => (
    {
      required String payeurId,
      required String beneficiaireId,
      required double montant,
      required String motif,
      bool remboursable = false,
      String? notes,
    }
  ) async {
    final createdBy = ref.read(currentProfileProvider).valueOrNull?.id;
    await ref.read(proprietaireFinanceRepositoryProvider).creerTransfert(
          payeurId: payeurId,
          beneficiaireId: beneficiaireId,
          montant: montant,
          motif: motif,
          remboursable: remboursable,
          notes: notes,
          createdBy: createdBy,
        );
    // Les deux participants doivent voir leur dossier financier à jour,
    // qu'ils soient consultés comme propriétaire ou comme gérant.
    ref.invalidate(proprietaireSoldeProvider(payeurId));
    ref.invalidate(gerantCommissionProvider(payeurId));
    ref.invalidate(proprietaireSoldeProvider(beneficiaireId));
    ref.invalidate(gerantCommissionProvider(beneficiaireId));
  },
);