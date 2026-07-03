-- =============================================================================
-- Rapi Team API - Schema inicial (PostgreSQL)
-- Version: 001_initial_schema
-- =============================================================================
-- Estrategia: schema mínimo para el flow de auth híbrido (login).
-- Las tablas de dominio (rides, wallet, chats, etc.) las agregamos en FASE 3.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS schema_migrations (
  version     TEXT PRIMARY KEY,
  applied_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  description TEXT
);

-- users
--   id = mismo string que Firebase Auth UID durante fase híbrida
--   (permite firmar Firebase Custom Token con el mismo UID)
CREATE TABLE IF NOT EXISTS users (
  id                          TEXT PRIMARY KEY,
  full_name                   TEXT,
  display_name                TEXT,
  email                       TEXT,
  phone                       TEXT,
  phone_number                TEXT,
  profile_photo_url           TEXT,
  user_type                   TEXT NOT NULL DEFAULT 'passenger',
  auth_provider               TEXT,
  is_admin                    BOOLEAN NOT NULL DEFAULT false,
  is_active                   BOOLEAN NOT NULL DEFAULT true,
  is_verified                 BOOLEAN NOT NULL DEFAULT false,
  phone_verified              BOOLEAN NOT NULL DEFAULT false,
  email_verified              BOOLEAN NOT NULL DEFAULT false,
  profile_complete            BOOLEAN NOT NULL DEFAULT false,
  google_uid                  TEXT UNIQUE,
  apple_uid                   TEXT UNIQUE,
  suspended_at                TIMESTAMPTZ,
  suspended_reason            TEXT,
  created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS users_email_lower_idx ON users (LOWER(email)) WHERE email IS NOT NULL;
CREATE INDEX IF NOT EXISTS users_phone_idx ON users (phone) WHERE phone IS NOT NULL;
CREATE INDEX IF NOT EXISTS users_type_idx ON users (user_type);

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- phone_verifications (cooldown de OTP + test phones para reviewers)
CREATE TABLE IF NOT EXISTS phone_verifications (
  phone_key           TEXT PRIMARY KEY,
  phone_number        TEXT NOT NULL,
  last_sent_at        TIMESTAMPTZ,
  test_code           TEXT,
  test_code_expires   TIMESTAMPTZ,
  is_test_phone       BOOLEAN NOT NULL DEFAULT false,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- fcm_tokens (dispositivos registrados para push notifications)
CREATE TABLE IF NOT EXISTS fcm_tokens (
  token         TEXT PRIMARY KEY,
  user_id       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform      TEXT NOT NULL,
  device_info   JSONB,
  last_seen_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS fcm_tokens_user_idx ON fcm_tokens (user_id);

-- auth_events (auditoría de logins)
CREATE TABLE IF NOT EXISTS auth_events (
  id            BIGSERIAL PRIMARY KEY,
  user_id       TEXT REFERENCES users(id) ON DELETE SET NULL,
  event_type    TEXT NOT NULL,
  provider      TEXT,
  ip_address    INET,
  user_agent    TEXT,
  metadata      JSONB,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS auth_events_user_idx ON auth_events (user_id, created_at DESC);

INSERT INTO schema_migrations (version, description) VALUES
  ('001_initial_schema', 'users + phone_verifications + fcm_tokens + auth_events')
ON CONFLICT (version) DO NOTHING;
