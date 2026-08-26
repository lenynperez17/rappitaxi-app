-- Ronda 280 · Catálogo de servicios (Express, Ejecutivo, VIP, Minivan)
--
-- CÓMO SE APLICA
-- --------------
-- El ALTER TABLE exige ser dueño de `rides`, y el dueño es `postgres`:
--
--     sudo -u postgres psql -d rapi_team_api -v ON_ERROR_STOP=1 -f 025_...sql
--     sudo -u postgres psql -d rapi_team_api \
--       -c "GRANT SELECT, INSERT, UPDATE, DELETE ON ride_service_types TO rapi_team_user;"
--
-- POR QUÉ
-- -------
-- El dueño pidió un cuarto servicio, Minivan. Al ir a añadirlo apareció que el
-- circuito nunca estuvo cerrado:
--
--   * Express / Ejecutivo / VIP viven en un `enum` dentro de
--     `modern_passenger_home.dart` y solo cambian el precio sugerido
--     (×1.0, ×1.15, ×1.3). Ese dato NUNCA sale del teléfono.
--   * Lo que se manda al servidor es un tipo fijo escrito a mano —'car'—,
--     idéntico para los tres.
--   * El emparejamiento sí filtra por vehículo, pero mira
--     `driver_presence.vehicle_type`, que está NULL para TODOS los conductores
--     porque la app nunca lo envía en el heartbeat. Con NULL, el filtro deja
--     pasar a todo el mundo.
--
-- Resultado: hoy todos los conductores reciben todas las solicitudes, y el
-- servicio que eligió el pasajero no llega a ninguna parte.
--
-- Esta tabla es la fuente única: qué servicios existen, cuánto multiplican y
-- qué vehículos los atienden. Misma forma que `driver_document_types` de la
-- ronda 279, que ya funciona en producción.

CREATE TABLE IF NOT EXISTS ride_service_types (
  code             TEXT PRIMARY KEY,
  label            TEXT NOT NULL,
  description      TEXT NOT NULL DEFAULT '',
  -- Multiplicador sobre la tarifa sugerida. 1.00 = tarifa base.
  price_multiplier NUMERIC(5,2) NOT NULL DEFAULT 1.00
                   CHECK (price_multiplier > 0 AND price_multiplier <= 10),
  -- Qué vehículos pueden atenderlo. Lista vacía = cualquiera.
  vehicle_types    TEXT[] NOT NULL DEFAULT '{}',
  enabled          BOOLEAN NOT NULL DEFAULT true,
  sort_order       INTEGER NOT NULL DEFAULT 100,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Los tres de hoy con sus multiplicadores actuales, para que nada cambie de
-- precio al desplegar.
--
-- `vehicle_types` incluye 'taxi' además de 'car' a propósito: dos de los cuatro
-- conductores tienen registrado 'taxi' —un valor que ni siquiera aparece en el
-- desplegable del alta— y dejarlos fuera les cortaría el trabajo de golpe.
--
-- Minivan nace DESACTIVADA. Hoy ningún conductor tiene una registrada, así que
-- activarla ahora dejaría a esos viajes sin nadie a quien ofrecérselos. Se
-- enciende desde el panel el día que haya conductores con minivan.
INSERT INTO ride_service_types (code, label, description, price_multiplier, vehicle_types, enabled, sort_order) VALUES
  ('express',   'Express',   'Viaja rápido a tu precio',              1.00, ARRAY['car','taxi'], true,  10),
  ('ejecutivo', 'Ejecutivo', 'Auto cómodo y con más espacio',         1.15, ARRAY['car','taxi'], true,  20),
  ('vip',       'VIP',       'La mejor categoría disponible',         1.30, ARRAY['car','taxi'], true,  30),
  ('minivan',   'Minivan',   'Hasta 6 pasajeros y equipaje grande',   1.40, ARRAY['van'],        false, 40)
ON CONFLICT (code) DO NOTHING;

-- El servicio que pidió el pasajero, guardado en el viaje. Antes no se
-- guardaba en ninguna parte: el conductor cobraba la tarifa VIP sin enterarse
-- de que le habían pedido VIP.
ALTER TABLE rides ADD COLUMN IF NOT EXISTS service_type TEXT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'rides_service_type_fkey'
  ) THEN
    ALTER TABLE rides
      ADD CONSTRAINT rides_service_type_fkey
      FOREIGN KEY (service_type) REFERENCES ride_service_types(code)
      -- RESTRICT: borrar un servicio que tiene viajes históricos debe fallar
      -- ruidosamente, no llevarse por delante el historial.
      ON UPDATE CASCADE ON DELETE RESTRICT;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_ride_service_types_enabled
  ON ride_service_types(enabled, sort_order);
