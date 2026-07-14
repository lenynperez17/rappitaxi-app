-- 018: campos extra del perfil del usuario que la app envía pero no persistían.
--
-- HIGH: PATCH /api/auth/me + drivers/me/profile aceptaban birth_date,
-- identity_document, display_name en el body pero solo el backend guardaba
-- display_name. Los otros 2 eran drop silencioso — el user reabrió profile y
-- sus datos "guardados" habían desaparecido.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS birth_date DATE,
  ADD COLUMN IF NOT EXISTS identity_document TEXT;

-- Índice opcional por identity_document para lookups admin (buscar por DNI)
CREATE INDEX IF NOT EXISTS idx_users_identity_document
  ON users (identity_document)
  WHERE identity_document IS NOT NULL AND deleted_at IS NULL;
