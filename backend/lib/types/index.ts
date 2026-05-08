// Types partagés entre toutes les routes API

export interface ApiResponse<T = unknown> {
  data?: T;
  error?: string;
  message?: string;
}

export interface VehiculeFinancialsResult {
  vehiculeId:       string;
  prixAchat:        number;
  totalReparations: number;
  totalEntretiens:  number;
  totalDepenses:    number;   // prix de revient
  revenusLocations: number;
  revenusVente:     number | null;
  revenusTotal:     number;
  margeBrute:       number;
  margePct:         number;
  nbLocations:      number;
  joursLoues:       number;
  tauxOccupationPct:number;
  revenusParJour:   number;
}

export interface GpsPositionPayload {
  vehiculeId: string;
  latitude:   number;
  longitude:  number;
  speed?:     number;
  altitude?:  number;
  cap?:       number;
  fixTime?:   string;
}

export interface GeofenceZone {
  centerLat:  number;
  centerLon:  number;
  radiusM:    number;
  nom:        string;
}

export interface ContratGenerationRequest {
  type:       'location' | 'vente' | 'echange';
  referenceId: string;  // UUID de la location / vente / échange
}
