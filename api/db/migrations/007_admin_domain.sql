-- Rapi Team — schema mínimo para admin panel (trips, recharges, emergencies).
-- Los datos reales llegan cuando la app móvil crea rides/recargas.
INSERT INTO schema_migrations (version, description)
VALUES ('007', 'admin_domain')
ON CONFLICT DO NOTHING;

-- Rides / viajes -----------------------------------------------------
CREATE TABLE IF NOT EXISTS rides (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  passenger_id      TEXT REFERENCES users(id) ON DELETE SET NULL,
  driver_id         TEXT REFERENCES users(id) ON DELETE SET NULL,
  status            TEXT NOT NULL DEFAULT 'requested' CHECK (status IN
                      ('requested','searching','accepted','on_way','arrived',
                       'in_progress','completed','cancelled','no_drivers')),
  pickup_address    TEXT,
  pickup_lat        NUMERIC(10,7),
  pickup_lng        NUMERIC(10,7),
  destination_address TEXT,
  destination_lat   NUMERIC(10,7),
  destination_lng   NUMERIC(10,7),
  distance_meters   INTEGER,
  duration_seconds  INTEGER,
  estimated_fare    NUMERIC(10,2),
  final_fare        NUMERIC(10,2),
  payment_method    TEXT,
  vehicle_type      TEXT,
  passenger_rating  NUMERIC(2,1),
  driver_rating     NUMERIC(2,1),
  cancelled_by      TEXT,
  cancelled_reason  TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  accepted_at       TIMESTAMPTZ,
  started_at        TIMESTAMPTZ,
  completed_at      TIMESTAMPTZ,
  metadata          JSONB
);
CREATE INDEX IF NOT EXISTS idx_rides_created ON rides(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_rides_status ON rides(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_rides_passenger ON rides(passenger_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_rides_driver ON rides(driver_id, created_at DESC);

-- Driver recharges (recargas manuales de admin al wallet driver) ----
CREATE TABLE IF NOT EXISTS driver_recharges (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  driver_id         TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount            NUMERIC(12,2) NOT NULL,
  method            TEXT NOT NULL CHECK (method IN
                      ('cash','transfer','mercadopago','yape','plin','admin_manual','other')),
  status            TEXT NOT NULL DEFAULT 'completed' CHECK (status IN
                      ('pending','completed','failed','refunded','cancelled')),
  reference         TEXT,
  notes             TEXT,
  approved_by       TEXT REFERENCES users(id) ON DELETE SET NULL,
  external_ref      TEXT,
  metadata          JSONB,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  approved_at       TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_recharges_created ON driver_recharges(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_recharges_driver ON driver_recharges(driver_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_recharges_status ON driver_recharges(status, created_at DESC);

-- Emergencies ------------------------------------------------------
CREATE TABLE IF NOT EXISTS emergencies (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           TEXT REFERENCES users(id) ON DELETE SET NULL,
  ride_id           UUID REFERENCES rides(id) ON DELETE SET NULL,
  type              TEXT NOT NULL DEFAULT 'panic' CHECK (type IN
                      ('panic','medical','mechanical','accident','harassment','robbery','other')),
  status            TEXT NOT NULL DEFAULT 'active' CHECK (status IN
                      ('active','pending','dispatched','escalated','resolved','cancelled')),
  latitude          NUMERIC(10,7),
  longitude         NUMERIC(10,7),
  address           TEXT,
  description       TEXT,
  resolved_by       TEXT REFERENCES users(id) ON DELETE SET NULL,
  resolved_at       TIMESTAMPTZ,
  metadata          JSONB,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_emergencies_created ON emergencies(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_emergencies_status ON emergencies(status, created_at DESC);
