-- Ronda 282 — de qué sesión nació cada conexión SSE.
--
-- El stream de eventos vive minutos u horas, mucho más que el request que lo
-- abre. Desde la ronda 144 comprueba en cada ciclo que el usuario tenga
-- sesión, porque antes un stream sobrevivía al logout y seguía sirviendo
-- notificaciones, viajes, GPS del conductor y chat.
--
-- Pero comprueba si al usuario le queda ALGUNA sesión viva, no si sigue viva
-- LA SUYA. Con el cierre de sesión al entrar desde otro dispositivo (ronda
-- 282) eso deja un hueco: al expulsar al teléfono viejo, el usuario sigue
-- teniendo una sesión —la del teléfono nuevo—, así que la comprobación pasa y
-- el stream del expulsado sigue abierto. No puede actuar (todos los endpoints
-- le devuelven 401), pero sigue RECIBIENDO los datos privados de la cuenta.
--
-- Guardando aquí la sesión de origen, el stream puede preguntar por la suya.
--
-- Se queda NULL en los tickets ya emitidos; para esos se mantiene la
-- comprobación antigua, que es la que había hasta ahora.
--
-- Aplicar en el VPS con:
--   sudo -u postgres psql -d rapi_team_api -f 028_sse_tickets_session_id.sql

ALTER TABLE sse_tickets ADD COLUMN IF NOT EXISTS session_id TEXT;

COMMENT ON COLUMN sse_tickets.session_id IS
  'Sesión que pidió el ticket. El stream comprueba que siga viva, para que '
  'un dispositivo expulsado deje de recibir datos. NULL en tickets antiguos.';

GRANT SELECT, INSERT, UPDATE, DELETE ON sse_tickets TO rapi_team_user;
