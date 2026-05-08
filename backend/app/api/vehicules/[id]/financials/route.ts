import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { verifySupabaseToken } from '@/lib/auth';
import type { VehiculeFinancialsResult } from '@/lib/types';

export async function GET(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const userId = await verifySupabaseToken(req);
    if (!userId) return NextResponse.json({ error: 'Non autorisé' }, { status: 401 });

    const vehiculeId = params.id;

    const [vehicule, reparations, caisseOps, locations, ventes] = await Promise.all([
      prisma.vehicule.findUnique({
        where: { id: vehiculeId },
        select: { prixAchat: true, dateEntree: true },
      }),
      prisma.reparation.findMany({
        where: { vehiculeId },
        select: { cout: true, deductible: true },
      }),
      prisma.caisseOperation.findMany({
        where: { vehiculeId, type: 'sortie' },
        select: { montant: true, categorie: true },
      }),
      prisma.location.findMany({
        where: { vehiculeId, statut: 'termine' },
        select: { montantBrut: true, retenueCaution: true, dateDebut: true, dateFinReelle: true, dateFinPrevue: true },
      }),
      prisma.vente.findMany({
        where: { vehiculeId },
        select: { prixVente: true },
        take: 1,
      }),
    ]);

    if (!vehicule) return NextResponse.json({ error: 'Véhicule introuvable' }, { status: 404 });

    // ── DÉPENSES ────────────────────────────────────────────────────────────
    const prixAchat        = Number(vehicule.prixAchat ?? 0);
    const totalReparations = reparations
      .filter((r) => r.deductible)
      .reduce((s, r) => s + Number(r.cout), 0);

    const FRAIS_CATS = ['entretien', 'carburant', 'lavage', 'assurance', 'controle_technique'];
    const totalEntretiens = caisseOps
      .filter((op) => FRAIS_CATS.includes(op.categorie))
      .reduce((s, op) => s + Number(op.montant), 0);

    const totalDepenses = prixAchat + totalReparations + totalEntretiens;

    // ── REVENUS ─────────────────────────────────────────────────────────────
    const revenusLocations = locations.reduce((s, loc) => {
      const brut    = Number(loc.montantBrut ?? 0);
      const retenue = Number(loc.retenueCaution ?? 0);
      return s + brut - retenue;
    }, 0);

    const revenusVente = ventes.length ? Number(ventes[0].prixVente) : null;
    const revenusTotal = revenusLocations + (revenusVente ?? 0);

    // ── MARGES ──────────────────────────────────────────────────────────────
    const margeBrute = revenusTotal - totalDepenses;
    const margePct   = totalDepenses > 0 ? (margeBrute / totalDepenses) * 100 : 0;

    // ── TAUX D'OCCUPATION ───────────────────────────────────────────────────
    let joursLoues = 0;
    for (const loc of locations) {
      const debut = loc.dateDebut ? new Date(loc.dateDebut) : null;
      const fin   = loc.dateFinReelle ? new Date(loc.dateFinReelle)
                  : loc.dateFinPrevue ? new Date(loc.dateFinPrevue) : null;
      if (debut && fin) joursLoues += Math.abs(Math.ceil((fin.getTime() - debut.getTime()) / 86_400_000));
    }

    const joursDepuisEntree = vehicule.dateEntree
      ? Math.max(1, Math.ceil((Date.now() - new Date(vehicule.dateEntree).getTime()) / 86_400_000))
      : 365;

    const tauxOccupationPct = Math.round(Math.min(100, (joursLoues / joursDepuisEntree) * 100));
    const revenusParJour    = joursLoues > 0 ? revenusLocations / joursLoues : 0;

    const result: VehiculeFinancialsResult = {
      vehiculeId,
      prixAchat,
      totalReparations,
      totalEntretiens,
      totalDepenses,
      revenusLocations,
      revenusVente,
      revenusTotal,
      margeBrute,
      margePct,
      nbLocations:       locations.length,
      joursLoues,
      tauxOccupationPct,
      revenusParJour,
    };

    return NextResponse.json({ data: result });
  } catch (err: any) {
    console.error('[GET /api/vehicules/:id/financials]', err);
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
