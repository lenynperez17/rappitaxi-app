-- Ronda 282 — por qué se revocó una sesión.
--
-- Hasta ahora una sesión revocada solo podía serlo por dos motivos, y
-- `refreshSession` los distinguía por tiempo: si el refresh llegaba dentro de
-- los 30 segundos siguientes al revoke era una rotación normal, y si llegaba
-- después se trataba como token robado y se revocaban TODAS las sesiones del
-- usuario.
--
-- Esa heurística se rompe al añadir un tercer motivo: cerrar la sesión vieja
-- cuando la cuenta entra desde otro teléfono. El teléfono expulsado se queda
-- con un refresh token de una sesión revocada y lo usará cuando despierte —
-- que pueden ser horas después, guardado en un bolsillo. Pasada la ventana de
-- 30 segundos se leía como robo y se revocaba todo, incluida la sesión del
-- teléfono nuevo. Resultado: entrar en un teléfono acabaría echando a los dos.
--
-- Con el motivo escrito en la fila ya no hay que adivinarlo.
--
--   'evicted'  — cerrada porque la cuenta entró desde otro dispositivo.
--   NULL       — todo lo anterior: rotación, logout manual, reuse.
--
-- Aplicar en el VPS con:
--   sudo -u postgres psql -d rapi_team_api -f 026_sessions_revoked_reason.sql

ALTER TABLE sessions ADD COLUMN IF NOT EXISTS revoked_reason TEXT;

COMMENT ON COLUMN sessions.revoked_reason IS
  'Motivo de la revocación. ''evicted'' = la cuenta entró desde otro '
  'dispositivo. NULL = rotación, logout manual o reuse detectado.';

-- El dueño de las tablas es postgres; la aplicación entra como rapi_team_user.
GRANT SELECT, INSERT, UPDATE, DELETE ON sessions TO rapi_team_user;
