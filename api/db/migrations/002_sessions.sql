-- =============================================================================
-- Rapi Team — Migración 002: tabla `sessions` (auth JWT propio)
-- =============================================================================
-- IDEMPOTENTE — usa IF NOT EXISTS. Diseñada para correr sobre una DB que YA
-- pueda tener la tabla `sessions` creada por un agente paralelo (Google OAuth
-- helper). Sólo añade columnas e índices que faltan para session lifecycle:
--
--   - last_used_at            (para listado de dispositivos)
--   - replaced_by_session_id  (auditoría de la cadena de rotation)
--
-- Modelo:
--   - access token = JWT firmado HS256 con JWT_SECRET, TTL 1h, NO se persiste
--     (stateless). Contiene { sub, type:'access', sid, iat, exp, iss:'rapi-team' }.
--   - refresh token = JWT con `jti` (= sessions.id), TTL 30 días. SE persiste
--     solo como SHA256 hex hash en `refresh_token_hash`. Single-use: al usarlo
--     se invalida (revoked_at=now()) y se crea una NUEVA fila (rotation) —
--     atomicidad garantizada por transacción en `refreshSession()`.
--
--   - Para listar dispositivos: SELECT … WHERE user_id=$1 AND revoked_at IS NULL
--     AND expires_at > now().
--   - Para logout 1 device: UPDATE sessions SET revoked_at=now() WHERE id=$1.
--   - Para logout TODOS: UPDATE sessions SET revoked_at=now() WHERE user_id=$1
--     AND revoked_at IS NULL.
--   - Cleanup cron (daily 03:00): DELETE FROM sessions WHERE expires_at < now().
-- =============================================================================

CREATE TABLE IF NOT EXISTS sessions (
  id                 TEXT PRIMARY KEY,
  user_id            TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  refresh_token_hash TEXT NOT NULL,
  expires_at         TIMESTAMPTZ NOT NULL,
  device_info        JSONB,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  revoked_at         TIMESTAMPTZ
);

-- Columnas adicionales (idempotente) para session lifecycle:
ALTER TABLE sessions
  ADD COLUMN IF NOT EXISTS last_used_at TIMESTAMPTZ NOT NULL DEFAULT now();

ALTER TABLE sessions
  ADD COLUMN IF NOT EXISTS replaced_by_session_id TEXT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conname = 'sessions_replaced_by_session_id_fkey'
  ) THEN
    ALTER TABLE sessions
      ADD CONSTRAINT sessions_replaced_by_session_id_fkey
      FOREIGN KEY (replaced_by_session_id) REFERENCES sessions(id) ON DELETE SET NULL;
  END IF;
END
$$;

-- Lookup por refresh token hash (cada call a /refresh hace SELECT por aquí).
CREATE UNIQUE INDEX IF NOT EXISTS sessions_refresh_hash_unique_idx
  ON sessions (refresh_token_hash);

-- Lookup por usuario (listar dispositivos / revocar todos).
CREATE INDEX IF NOT EXISTS sessions_user_active_idx
  ON sessions (user_id, revoked_at, expires_at DESC);

-- Cleanup cron (DELETE WHERE expires_at < now()).
CREATE INDEX IF NOT EXISTS sessions_expires_at_idx
  ON sessions (expires_at)
  WHERE revoked_at IS NULL;
