-- Panel admin login por email + password
INSERT INTO schema_migrations (version, description)
VALUES ('008', 'admin_password')
ON CONFLICT DO NOTHING;

ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash TEXT;
CREATE INDEX IF NOT EXISTS idx_users_admin_email_login
  ON users(lower(email))
  WHERE is_admin = true AND deleted_at IS NULL;
