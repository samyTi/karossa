-- ========================================================
--  GARAGE AUTO — Migrations Supabase
--  Exécutez ce fichier dans l'éditeur SQL de Supabase
--  Dashboard → SQL Editor → New Query → Coller → Run
-- ========================================================

-- ── 1. Paramètres du showroom ──────────────────────────
CREATE TABLE IF NOT EXISTS showroom_settings (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nom         text NOT NULL DEFAULT 'Garage Auto',
  adresse     text,
  tel         text,
  email       text,
  rc          text,
  logo_url    text,
  traccar_url      text,
  traccar_user     text,
  traccar_password text,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now()
);

-- Données par défaut
INSERT INTO showroom_settings (nom, adresse)
VALUES ('Garage Auto', 'Alger, Algérie')
ON CONFLICT DO NOTHING;

-- ── 2. Templates de contrats ───────────────────────────
CREATE TABLE IF NOT EXISTS contract_templates (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type        text NOT NULL CHECK (type IN ('location','vente','echange')),
  nom         text NOT NULL,
  template_url text,
  config      jsonb DEFAULT '{}',
  is_active   boolean DEFAULT true,
  created_at  timestamptz DEFAULT now()
);

-- ── 3. Colonne GPS sur les véhicules ──────────────────
ALTER TABLE vehicules
  ADD COLUMN IF NOT EXISTS traccar_device_id integer,
  ADD COLUMN IF NOT EXISTS km_alerte_seuil   integer DEFAULT 150000;

-- ── 4. Alertes GPS ────────────────────────────────────
CREATE TABLE IF NOT EXISTS gps_alertes (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicule_id uuid REFERENCES vehicules(id) ON DELETE CASCADE,
  vehicule_nom text,
  type        text NOT NULL,  -- vitesse | zone | kilometrage | connexion
  message     text NOT NULL,
  date_alerte timestamptz DEFAULT now(),
  lue         boolean DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_gps_alertes_vehicule
  ON gps_alertes(vehicule_id);
CREATE INDEX IF NOT EXISTS idx_gps_alertes_lue
  ON gps_alertes(lue) WHERE NOT lue;

-- ── 5. Colonne PDF sur locations et ventes ────────────
ALTER TABLE locations
  ADD COLUMN IF NOT EXISTS contrat_pdf_url text;

ALTER TABLE ventes
  ADD COLUMN IF NOT EXISTS contrat_pdf_url text;

-- ── 6. Bucket Storage pour les contrats ───────────────
-- (Supabase Dashboard → Storage → New Bucket)
-- Nom : "contrats" — Public : Non (privé)
-- Ou via SQL :
INSERT INTO storage.buckets (id, name, public)
VALUES ('contrats', 'contrats', false)
ON CONFLICT (id) DO NOTHING;

-- Policy : lecture réservée aux utilisateurs authentifiés
CREATE POLICY IF NOT EXISTS "contrats_auth_read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'contrats' AND auth.role() = 'authenticated');

CREATE POLICY IF NOT EXISTS "contrats_auth_insert"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'contrats' AND auth.role() = 'authenticated');

-- ── 7. RLS — sécurité de base ─────────────────────────
ALTER TABLE showroom_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE contract_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE gps_alertes ENABLE ROW LEVEL SECURITY;

-- Lecture pour tous les authentifiés
CREATE POLICY IF NOT EXISTS "showroom_auth_read"
  ON showroom_settings FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY IF NOT EXISTS "templates_auth_read"
  ON contract_templates FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY IF NOT EXISTS "gps_alertes_auth_read"
  ON gps_alertes FOR SELECT
  USING (auth.role() = 'authenticated');

-- Écriture réservée aux admins/gérants (ajustez selon vos rôles)
CREATE POLICY IF NOT EXISTS "showroom_admin_write"
  ON showroom_settings FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
        AND role IN ('admin', 'gerant')
    )
  );

-- ── 8. Trigger updated_at ─────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER IF NOT EXISTS showroom_settings_updated_at
  BEFORE UPDATE ON showroom_settings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ========================================================
-- ✓ Migration terminée
-- ========================================================
