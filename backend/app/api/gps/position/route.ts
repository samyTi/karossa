import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { verifyApiKey } from '@/lib/auth';
import type { GpsPositionPayload } from '@/lib/types';
import { checkGeofencing, checkSpeed } from '@/lib/gps/alertes';

/**
 * POST /api/gps/position
 * Reçoit une position GPS depuis un boîtier (ou depuis Flutter via Traccar).
 * Headers requis: x-api-key: <API_SECRET_KEY>
 */
export async function POST(req: NextRequest) {
  if (!verifyApiKey(req)) {
    return NextResponse.json({ error: 'Clé API invalide' }, { status: 401 });
  }

  try {
    const body: GpsPositionPayload = await req.json();
    const { vehiculeId, latitude, longitude, speed, altitude, cap, fixTime } = body;

    if (!vehiculeId || latitude == null || longitude == null) {
      return NextResponse.json({ error: 'vehiculeId, latitude et longitude sont requis' }, { status: 400 });
    }

    // 1. Récupérer le véhicule
    const vehicule = await prisma.vehicule.findUnique({
      where: { id: vehiculeId },
      select: { id: true, marque: true, modele: true, immatriculation: true, kmAlerteSeuil: true },
    });
    if (!vehicule) {
      return NextResponse.json({ error: 'Véhicule introuvable' }, { status: 404 });
    }
    const vehiculeNom = `${vehicule.marque} ${vehicule.modele}${vehicule.immatriculation ? ' (' + vehicule.immatriculation + ')' : ''}`;

    // 2. Stocker la position
    await prisma.gpsPosition.create({
      data: {
        vehiculeId,
        latitude,
        longitude,
        speed:  speed ?? null,
        altitude: altitude ?? null,
        cap: cap ?? null,
        fixTime: fixTime ? new Date(fixTime) : new Date(),
      },
    });

    // 3. Vérification vitesse (> 130 km/h = alerte)
    if (speed != null) {
      const speedAlerte = await checkSpeed({ vehiculeId, vehiculeNom, speedKmh: speed });
      if (speedAlerte) {
        await prisma.gpsAlerte.create({ data: speedAlerte });
      }
    }

    // 4. Vérification géofencing (zones configurées en DB ou constantes)
    const geofenceAlerte = await checkGeofencing({ vehiculeId, vehiculeNom, latitude, longitude });
    if (geofenceAlerte) {
      await prisma.gpsAlerte.create({ data: geofenceAlerte });
    }

    return NextResponse.json({ success: true });
  } catch (err: any) {
    console.error('[POST /api/gps/position]', err);
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

/**
 * GET /api/gps/position?vehiculeId=xxx
 * Retourne la dernière position connue d'un véhicule.
 */
export async function GET(req: NextRequest) {
  const vehiculeId = req.nextUrl.searchParams.get('vehiculeId');
  if (!vehiculeId) {
    return NextResponse.json({ error: 'vehiculeId requis' }, { status: 400 });
  }

  const pos = await prisma.gpsPosition.findFirst({
    where: { vehiculeId },
    orderBy: { fixTime: 'desc' },
  });

  return NextResponse.json({ data: pos });
}
