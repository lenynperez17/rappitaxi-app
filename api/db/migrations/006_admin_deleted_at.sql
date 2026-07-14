-- Rapi Team — soft delete de usuarios + índice para admin listing
INSERT INTO schema_migrations (version, description)
VALUES ('006', 'admin_deleted_at')
ON CONFLICT DO NOTHING;

-- Soft delete column (si ya existe no falla)
ALTER TABLE users ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- Índice compuesto para listing con filtros de admin
CREATE INDEX IF NOT EXISTS idx_users_admin_listing
  ON users(user_type, is_active, created_at DESC)
  WHERE deleted_at IS NULL;

-- Índice por email para búsqueda case-insensitive
CREATE INDEX IF NOT EXISTS idx_users_email_search
  ON users(lower(email))
  WHERE email IS NOT NULL AND deleted_at IS NULL;
