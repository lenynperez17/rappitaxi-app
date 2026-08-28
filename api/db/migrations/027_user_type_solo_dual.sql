-- Ronda 282 — se acaba el tipo de usuario 'driver'.
--
-- Para ser conductor hay que pasar por pasajero: la cuenta nace como
-- 'passenger' y `drivers/me/upgrade` la promueve escribiendo 'dual', nunca
-- 'driver'. Lo mismo hacen la aprobación de documentos desde el panel
-- (`admin/documents/[id]`) y el alta de un viaje a nombre de un conductor
-- (`admin/trips`). O sea que el sistema lleva tiempo funcionando con dos tipos
-- y nadie lo había escrito.
--
-- Lo que quedaba de 'driver' era una sola cuenta anterior a ese flujo, y un
-- camino paralelo repetido en una decena de comprobaciones con la forma
-- `user_type <> 'driver' AND user_type <> 'dual'`. Duplicaba cada puerta sin
-- añadir nada, y hacía que el panel contara los conductores mal: la tarjeta
-- del dashboard sumaba 'driver' + 'dual' y daba 6, mientras la fila "Total
-- conductores" justo debajo mostraba solo los 'driver' y daba 1.
--
-- Migrar la fila no le quita nada a esa cuenta: su perfil, su vehículo, sus
-- documentos y sus viajes cuelgan de su `id`, no de su tipo. Y 'dual' le añade
-- poder pedir viajes como pasajero, que antes no podía.
--
-- Aplicar en el VPS con:
--   sudo -u postgres psql -d rapi_team_api -f 027_user_type_solo_dual.sql

BEGIN;

-- 1. La cuenta que quedaba. Se hace antes de tocar la restricción para que,
--    si algo fallara, la tabla siga siendo válida.
UPDATE users SET user_type = 'dual', updated_at = now()
 WHERE user_type = 'driver';

-- 2. Que no puedan volver a aparecer. Sin esto, el desplegable del panel
--    seguiría pudiendo crear cuentas 'driver' y volveríamos al punto de
--    partida.
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_type_valid;
ALTER TABLE users ADD CONSTRAINT users_type_valid
  CHECK (user_type = ANY (ARRAY['passenger'::text, 'dual'::text, 'admin'::text]));

COMMIT;

-- Comprobación posterior: debe devolver passenger, dual y admin, nada más.
--   SELECT user_type, COUNT(*) FROM users WHERE deleted_at IS NULL
--    GROUP BY user_type ORDER BY 2 DESC;
