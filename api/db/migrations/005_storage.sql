-- Rapi Team — storage local en VPS
-- ============================================================================
-- Los archivos físicos viven en /var/www/Rapi-Team-App-Api/storage/{scope}/{userId}/{uuid}.{ext}
-- Metadatos en Postgres: audit trail + validación de propietario.
-- Servido vía Nginx bajo /media/... (con X-Accel-Redirect para autorización).
-- ============================================================================

INSERT INTO schema_migrations (version, description)
VALUES ('005', 'storage')
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS storage_files (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       TEXT NOT NULL,
  scope         TEXT NOT NULL CHECK (scope IN
                  ('profile_photo','driver_license','vehicle_photo','vehicle_registration',
                   'criminal_record','identity_front','identity_back','soat','chat_attachment','misc')),
  storage_key   TEXT NOT NULL UNIQUE,   -- ruta relativa: profile_photo/UID/uuid.jpg
  mime          TEXT NOT NULL,
  size_bytes    BIGINT NOT NULL,
  width         INTEGER,
  height        INTEGER,
  sha256_hex    TEXT,                    -- para dedup opcional
  is_public     BOOLEAN NOT NULL DEFAULT false,
  metadata      JSONB,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at    TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_storage_user_scope ON storage_files(user_id, scope) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_storage_key ON storage_files(storage_key);
