-- =============================================================================
-- Rapi Team - Migración 002: Passkeys (WebAuthn / FIDO2)
-- Fecha: 2026-06-26
-- =============================================================================
-- Esta migración crea:
--   1. passkey_credentials  -> credenciales WebAuthn registradas por usuario
--   2. webauthn_challenges  -> challenges temporales (TTL 5min) emitidos en
--                              register/begin y authenticate/begin.
--
-- Notas:
--   * credential_id se guarda en BYTEA (bytes crudos del Credential ID), con
--     índice UNIQUE para soportar lookup O(1) en authenticate/finish.
--   * public_key es la representación COSE serializada (BYTEA) que devuelve
--     @simplewebauthn/server tras verifyRegistrationResponse().
--   * counter es BIGINT por las dudas (autenticadores roamming pueden subirlo
--     bastante; INTEGER se quedaría corto si superan 2^31).
--   * transports es TEXT[] (ej: ['internal','hybrid','usb','nfc','ble']).
--   * device_type discrimina entre 'singleDevice' (cross-platform, ej Yubikey
--     físico) y 'multiDevice' (platform, ej iCloud Keychain / Google PM).
--     Mapeamos a los strings devueltos por @simplewebauthn/server:
--       'singleDevice' | 'multiDevice'.
--   * webauthn_challenges.user_id es NULLABLE: las authentications "discoverable"
--     (sin email previo) emiten challenge sin user, y verify usa la credencial
--     para resolver el usuario.
-- =============================================================================

-- =============================================================================
-- 1) passkey_credentials
-- =============================================================================
CREATE TABLE IF NOT EXISTS passkey_credentials (
  id              TEXT PRIMARY KEY,                       -- id app-side (uuid o random)
  user_id         TEXT NOT NULL
                   REFERENCES users(id) ON DELETE CASCADE,
  credential_id   BYTEA NOT NULL UNIQUE,                  -- WebAuthn credentialId crudo
  public_key      BYTEA NOT NULL,                         -- COSE pubkey serializada
  counter         BIGINT NOT NULL DEFAULT 0
                   CHECK (counter >= 0),
  transports      TEXT[],                                  -- ['internal','hybrid','usb','nfc','ble',...]
  device_type     TEXT
                   CHECK (device_type IS NULL OR device_type IN ('singleDevice','multiDevice')),
  backed_up       BOOLEAN,
  nickname        TEXT,                                    -- nombre amigable definido por el user
  last_used_at    TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE  passkey_credentials IS
  'Credenciales WebAuthn/FIDO2 registradas por usuario. 1 user puede tener varias passkeys (iCloud, Yubikey, etc.).';
COMMENT ON COLUMN passkey_credentials.credential_id IS
  'Credential ID bruto (bytes). Lookup principal en authenticate/finish.';
COMMENT ON COLUMN passkey_credentials.public_key    IS
  'Clave pública en formato COSE serializado, tal cual la devuelve @simplewebauthn/server.';
COMMENT ON COLUMN passkey_credentials.counter       IS
  'Contador firmado por el autenticador. Se incrementa en cada uso; rechazar si baja.';
COMMENT ON COLUMN passkey_credentials.device_type   IS
  'singleDevice = cross-platform (Yubikey); multiDevice = platform sincronizado (iCloud Keychain, Google Password Manager).';

CREATE INDEX IF NOT EXISTS passkey_credentials_user_id_idx
  ON passkey_credentials (user_id);

CREATE INDEX IF NOT EXISTS passkey_credentials_user_created_idx
  ON passkey_credentials (user_id, created_at DESC);

-- =============================================================================
-- 2) webauthn_challenges
-- =============================================================================
-- Storage temporal para challenges emitidos. Se borran tras verify (one-shot)
-- o cuando expiran (5 min). Background cleanup opcional via DELETE WHERE expires_at < now().
CREATE TABLE IF NOT EXISTS webauthn_challenges (
  challenge   TEXT PRIMARY KEY,                            -- base64url, único
  user_id     TEXT
               REFERENCES users(id) ON DELETE CASCADE,     -- NULL para authentications discoverable
  purpose     TEXT NOT NULL
               CHECK (purpose IN ('registration','authentication')),
  expires_at  TIMESTAMPTZ NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE  webauthn_challenges IS
  'Challenges WebAuthn pendientes (TTL 5min). Se eliminan al consumir o expirar.';
COMMENT ON COLUMN webauthn_challenges.user_id IS
  'NULL permitido: authenticate/begin sin email (discoverable credentials).';

CREATE INDEX IF NOT EXISTS webauthn_challenges_expires_idx
  ON webauthn_challenges (expires_at);
CREATE INDEX IF NOT EXISTS webauthn_challenges_user_purpose_idx
  ON webauthn_challenges (user_id, purpose);

-- =============================================================================
-- 3) Tracking de migración
-- =============================================================================
INSERT INTO schema_migrations (version, description)
VALUES ('002_passkeys', 'Passkeys WebAuthn: passkey_credentials + webauthn_challenges')
ON CONFLICT (version) DO NOTHING;
