-- 015: UNIQUE partial index en (phone) para usuarios verificados y no eliminados.
--
-- CRÍTICO: sin este constraint, dos filas podían compartir el mismo phone
-- verificado (ej. atacante seteó phone via PATCH y no reseteó verified,
-- o migración vieja dejó duplicados), lo que abre ventana de account hijack.
--
-- Este índice bloquea nuevos inserts/updates que dupliquen un phone
-- verificado activo. Si hay duplicados históricos, esta migración fallará;
-- limpiar primero con un query manual identificando y desactivando los
-- extras (`DELETE ... WHERE ... AND id NOT IN (SELECT id FROM ...
-- ORDER BY created_at ASC LIMIT 1)`).

CREATE UNIQUE INDEX IF NOT EXISTS ux_users_phone_verified
  ON users (phone)
  WHERE phone IS NOT NULL
    AND phone_verified = true
    AND deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ux_users_email_verified
  ON users (LOWER(email))
  WHERE email IS NOT NULL
    AND email_verified = true
    AND deleted_at IS NULL;
