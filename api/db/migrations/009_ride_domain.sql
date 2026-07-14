-- Rapi Team — dominio completo de rides: chat, negotiations, presence
-- ============================================================================
-- Sustituye a las colecciones Firestore:
--   rides (ya existía en 007), ride_messages (chat), ride_negotiations (InDrive),
--   driver_presence (online + last location), ride_offers (driver bids)
-- ============================================================================

INSERT INTO schema_migrations (version, description)
VALUES ('009', 'ride_domain')
ON CONFLICT DO NOTHING;

-- Chat del viaje --------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ride_messages (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ride_id        UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  sender_id      TEXT NOT NULL REFERENCES users(id) ON DELETE SET NULL,
  body           TEXT,
  attachment_url TEXT,
  read_at        TIMESTAMPTZ,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ride_messages_ride ON ride_messages(ride_id, created_at DESC);

-- Negociaciones (InDrive-style) — passenger propone → drivers contraofertan ---
CREATE TABLE IF NOT EXISTS ride_negotiations (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ride_id           UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  proposed_by       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  proposed_by_role  TEXT NOT NULL CHECK (proposed_by_role IN ('passenger', 'driver')),
  amount            NUMERIC(10,2) NOT NULL,
  message           TEXT,
  status            TEXT NOT NULL DEFAULT 'pending' CHECK (status IN
                      ('pending','accepted','rejected','superseded','expired')),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  responded_at      TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_ride_negotiations_ride ON ride_negotiations(ride_id, created_at DESC);

-- Ofertas de driver a un viaje disponible (bid) -------------------------------
CREATE TABLE IF NOT EXISTS ride_offers (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ride_id        UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  driver_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount         NUMERIC(10,2),
  eta_seconds   INTEGER,
  message        TEXT,
  status         TEXT NOT NULL DEFAULT 'pending' CHECK (status IN
                   ('pending','accepted','rejected','withdrawn','expired')),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  responded_at   TIMESTAMPTZ,
  UNIQUE(ride_id, driver_id)
);
CREATE INDEX IF NOT EXISTS idx_ride_offers_ride ON ride_offers(ride_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ride_offers_driver ON ride_offers(driver_id, created_at DESC);

-- Presencia y ubicación del conductor -----------------------------------------
CREATE TABLE IF NOT EXISTS driver_presence (
  driver_id        TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  is_online        BOOLEAN NOT NULL DEFAULT false,
  latitude         NUMERIC(10,7),
  longitude        NUMERIC(10,7),
  heading          NUMERIC(5,2),
  accuracy_meters  NUMERIC(6,2),
  speed_kmh        NUMERIC(6,2),
  vehicle_type     TEXT,
  active_ride_id   UUID REFERENCES rides(id) ON DELETE SET NULL,
  last_heartbeat   TIMESTAMPTZ,
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_driver_presence_online ON driver_presence(is_online) WHERE is_online = true;

-- Chat conversaciones generales (soporte, admin) — opcional --------------------
CREATE TABLE IF NOT EXISTS conversations (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subject       TEXT,
  status        TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed','archived')),
  metadata      JSONB,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_conversations_user ON conversations(user_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS conversation_messages (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  conversation_id   UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id         TEXT REFERENCES users(id) ON DELETE SET NULL,
  is_admin          BOOLEAN NOT NULL DEFAULT false,
  body              TEXT,
  read_at           TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_conversation_messages_conv ON conversation_messages(conversation_id, created_at DESC);

-- Documentos de conductor (docs y verificación) -------------------------------
CREATE TABLE IF NOT EXISTS driver_documents (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  driver_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  doc_type       TEXT NOT NULL CHECK (doc_type IN
                   ('dni_front','dni_back','license_front','license_back',
                    'soat','tarjeta_propiedad','ownership','selfie','vehicle_photo','other')),
  file_url       TEXT NOT NULL,
  status         TEXT NOT NULL DEFAULT 'pending' CHECK (status IN
                   ('pending','approved','rejected','expired')),
  rejection_reason TEXT,
  reviewed_by    TEXT REFERENCES users(id) ON DELETE SET NULL,
  reviewed_at    TIMESTAMPTZ,
  expires_at     TIMESTAMPTZ,
  metadata       JSONB,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(driver_id, doc_type)
);
CREATE INDEX IF NOT EXISTS idx_driver_documents_driver ON driver_documents(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_documents_status ON driver_documents(status);

-- Vehículo del conductor ------------------------------------------------------
CREATE TABLE IF NOT EXISTS driver_vehicles (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  driver_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  vehicle_type   TEXT NOT NULL CHECK (vehicle_type IN ('taxi','moto','moto_taxi','car','van','truck','bicycle')),
  plate          TEXT NOT NULL,
  make           TEXT,
  model          TEXT,
  color          TEXT,
  year           INTEGER,
  is_active      BOOLEAN NOT NULL DEFAULT true,
  is_verified    BOOLEAN NOT NULL DEFAULT false,
  metadata       JSONB,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(driver_id, plate)
);
CREATE INDEX IF NOT EXISTS idx_driver_vehicles_driver ON driver_vehicles(driver_id);

-- Ratings/calificaciones (por viaje) ------------------------------------------
CREATE TABLE IF NOT EXISTS ride_ratings (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ride_id       UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  rated_by      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rated_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role          TEXT NOT NULL CHECK (role IN ('passenger','driver')),
  stars         NUMERIC(2,1) NOT NULL CHECK (stars >= 1 AND stars <= 5),
  comment       TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(ride_id, rated_by)
);
CREATE INDEX IF NOT EXISTS idx_ride_ratings_user ON ride_ratings(rated_user_id, created_at DESC);

-- Contactos de emergencia del usuario -----------------------------------------
CREATE TABLE IF NOT EXISTS emergency_contacts (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name         TEXT NOT NULL,
  phone        TEXT NOT NULL,
  relationship TEXT,
  is_primary   BOOLEAN NOT NULL DEFAULT false,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, phone)
);
CREATE INDEX IF NOT EXISTS idx_emergency_contacts_user ON emergency_contacts(user_id);

-- Favoritos (direcciones guardadas) -------------------------------------------
CREATE TABLE IF NOT EXISTS user_favorites (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  label         TEXT NOT NULL,          -- 'Casa', 'Trabajo', etc.
  address       TEXT NOT NULL,
  latitude      NUMERIC(10,7),
  longitude     NUMERIC(10,7),
  icon          TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_user_favorites_user ON user_favorites(user_id);

-- Notificaciones (in-app) -----------------------------------------------------
CREATE TABLE IF NOT EXISTS notifications (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type          TEXT NOT NULL,           -- 'ride_accepted','driver_arrived','payment_received',...
  title         TEXT NOT NULL,
  body          TEXT,
  data          JSONB,
  read_at       TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, read_at) WHERE read_at IS NULL;

-- Métodos de pago del usuario -------------------------------------------------
CREATE TABLE IF NOT EXISTS user_payment_methods (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id        TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  method_type    TEXT NOT NULL CHECK (method_type IN ('cash','mercadopago','wallet','yape','plin','card')),
  label          TEXT,
  is_default     BOOLEAN NOT NULL DEFAULT false,
  metadata       JSONB,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_user_payment_methods_user ON user_payment_methods(user_id);

-- Fórmula haversine para búsquedas de drivers cercanos (sin PostGIS) ---------
CREATE OR REPLACE FUNCTION haversine_km(lat1 NUMERIC, lon1 NUMERIC, lat2 NUMERIC, lon2 NUMERIC)
RETURNS NUMERIC AS $$
  SELECT 6371 * 2 * asin(sqrt(
    sin(radians((lat2 - lat1)/2))^2 +
    cos(radians(lat1)) * cos(radians(lat2)) * sin(radians((lon2 - lon1)/2))^2
  ))
$$ LANGUAGE SQL IMMUTABLE;

-- updated_at triggers ---------------------------------------------------------
DROP TRIGGER IF EXISTS trg_driver_presence_updated_at ON driver_presence;
CREATE TRIGGER trg_driver_presence_updated_at BEFORE UPDATE ON driver_presence
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trg_conversations_updated_at ON conversations;
CREATE TRIGGER trg_conversations_updated_at BEFORE UPDATE ON conversations
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trg_driver_documents_updated_at ON driver_documents;
CREATE TRIGGER trg_driver_documents_updated_at BEFORE UPDATE ON driver_documents
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trg_driver_vehicles_updated_at ON driver_vehicles;
CREATE TRIGGER trg_driver_vehicles_updated_at BEFORE UPDATE ON driver_vehicles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
