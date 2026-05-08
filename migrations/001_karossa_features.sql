-- Migration : ajout table gps_positions et colonne prix_achat
-- À exécuter dans Supabase SQL Editor

-- 1. Colonne prix_achat sur vehicules (si absente)
ALTER TABLE public.vehicules
  ADD COLUMN IF NOT EXISTS prix_achat numeric;

-- 2. Table des positions GPS (historique)
CREATE TABLE IF NOT EXISTS public.gps_positions (
  id          uuid NOT NULL DEFAULT gen_random_uuid(),
  vehicule_id uuid NOT NULL,
  latitude    double precision NOT NULL,
  longitude   double precision NOT NULL,
  speed       double precision,
  altitude    double precision,
  cap         double precision,
  fix_time    timestamp with time zone NOT NULL,
  server_time timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT gps_positions_pkey PRIMARY KEY (id),
  CONSTRAINT gps_positions_vehicule_id_fkey FOREIGN KEY (vehicule_id) REFERENCES public.vehicules(id) ON DELETE CASCADE
);

-- Index pour les requêtes par véhicule + temps
CREATE INDEX IF NOT EXISTS idx_gps_positions_vehicule_time
  ON public.gps_positions (vehicule_id, fix_time DESC);

-- 3. Active Realtime sur gps_positions (pour les mises à jour live Flutter)
ALTER PUBLICATION supabase_realtime ADD TABLE public.gps_positions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.gps_alertes;

-- 4. Bucket Storage "contrats" (si absent)
-- À exécuter via l'interface Supabase > Storage > New bucket
-- Nom: contrats | Public: true
