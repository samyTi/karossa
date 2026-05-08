import { prisma } from '@/lib/prisma';

const SPEED_LIMIT_KMH = 130;   // Alerte au-delà de 130 km/h
const GEOFENCE_RADIUS_M = 50_000; // 50 km autour d'Alger par défaut

/** Calcule la distance entre deux points (formule Haversine) en mètres */
export function haversineDistance(
  lat1: number, lon1: number,
  lat2: number, lon2: number,
): number {
  const R = 6_371_000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

interface AlerteInput {
  vehiculeId:  string;
  vehiculeNom: string;
  speedKmh?:   number;
  latitude?:   number;
  longitude?:  number;
}

/** Retourne un objet GpsAlerte si la vitesse est dépassée, sinon null */
export async function checkSpeed(input: AlerteInput) {
  const { vehiculeId, vehiculeNom, speedKmh } = input;
  if (!speedKmh || speedKmh <= SPEED_LIMIT_KMH) return null;

  // Évite les doublons d'alertes vitesse sur 5 minutes
  const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
  const recent = await prisma.gpsAlerte.findFirst({
    where: {
      vehiculeId,
      type: 'vitesse',
      dateAlerte: { gte: fiveMinutesAgo },
    },
  });
  if (recent) return null;

  return {
    vehiculeId,
    vehiculeNom,
    type: 'vitesse',
    message: `Vitesse excessive détectée : ${Math.round(speedKmh)} km/h (limite : ${SPEED_LIMIT_KMH} km/h)`,
  };
}

/** Retourne un objet GpsAlerte si le véhicule sort de sa zone, sinon null */
export async function checkGeofencing(input: AlerteInput) {
  const { vehiculeId, vehiculeNom, latitude, longitude } = input;
  if (!latitude || !longitude) return null;

  // Centre de zone par défaut : Alger (36.7372, 3.0865)
  const centerLat = 36.7372;
  const centerLon = 3.0865;

  const distM = haversineDistance(centerLat, centerLon, latitude, longitude);
  if (distM <= GEOFENCE_RADIUS_M) return null;

  // Évite les doublons sur 15 minutes
  const fifteenMinutesAgo = new Date(Date.now() - 15 * 60 * 1000);
  const recent = await prisma.gpsAlerte.findFirst({
    where: {
      vehiculeId,
      type: 'geofence',
      dateAlerte: { gte: fifteenMinutesAgo },
    },
  });
  if (recent) return null;

  const distKm = (distM / 1000).toFixed(1);
  return {
    vehiculeId,
    vehiculeNom,
    type: 'geofence',
    message: `Le véhicule a quitté la zone autorisée — ${distKm} km du centre (rayon : ${GEOFENCE_RADIUS_M / 1000} km)`,
  };
}
