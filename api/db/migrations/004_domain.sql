-- Rapi Team — dominio de app (vales + wallet + rides mínimo)
-- ============================================================================
-- Tablas para operaciones que el backend Node maneja server-side:
--   * vales (códigos promocionales aplicables a viajes)
--   * wallet_transactions (recargas MP, ajustes, débitos)
--   * mp_payments (registro de payments para conciliar con webhooks)
-- La tabla `rides` la mantiene Firestore durante la transición híbrida —
-- aquí solo referenciamos ride_id como TEXT sin FK cross-store.
-- ============================================================================

INSERT INTO schema_migrations (version, description)
VALUES ('004', 'domain')
ON CONFLICT DO NOTHING;

-- Vales / cupones -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS vales (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code           TEXT NOT NULL UNIQUE,           -- código público (case-insensitive: se guarda upper)
  description    TEXT,
  discount_type  TEXT NOT NULL CHECK (discount_type IN ('percent','flat')),
  discount_value NUMERIC(10,2) NOT NULL,          -- % o soles
  max_uses       INTEGER,                        -- NULL = ilimitado
  used_count     INTEGER NOT NULL DEFAULT 0,
  per_user_limit INTEGER NOT NULL DEFAULT 1,     -- cuántas veces por usuario
  min_ride_amount NUMERIC(10,2),                 -- monto mínimo del viaje
  starts_at      TIMESTAMPTZ,
  expires_at     TIMESTAMPTZ,
  is_active      BOOLEAN NOT NULL DEFAULT true,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_vales_code ON vales(code);
CREATE INDEX IF NOT EXISTS idx_vales_active ON vales(is_active, expires_at);

-- Uso de vales por usuario ----------------------------------------------------
CREATE TABLE IF NOT EXISTS vale_usages (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vale_id      UUID NOT NULL REFERENCES vales(id) ON DELETE CASCADE,
  user_id      TEXT NOT NULL,
  ride_id      TEXT,                              -- Firestore ride id
  discount_applied NUMERIC(10,2) NOT NULL,
  applied_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(vale_id, ride_id)
);
CREATE INDEX IF NOT EXISTS idx_vale_usages_user ON vale_usages(user_id, applied_at DESC);
CREATE INDEX IF NOT EXISTS idx_vale_usages_vale ON vale_usages(vale_id);

-- Transacciones de wallet -----------------------------------------------------
CREATE TABLE IF NOT EXISTS wallet_transactions (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id        TEXT NOT NULL,
  type           TEXT NOT NULL CHECK (type IN
                   ('recharge','debit','refund','withdrawal','commission','bonus','adjustment')),
  amount         NUMERIC(12,2) NOT NULL,          -- signo lógico: recharge/bonus > 0, debit < 0
  balance_after  NUMERIC(12,2),                   -- opcional snapshot
  description    TEXT,
  status         TEXT NOT NULL DEFAULT 'completed' CHECK (status IN
                   ('pending','completed','failed','refunded','cancelled')),
  external_ref   TEXT,                            -- payment_id de MP u otro
  ride_id        TEXT,
  metadata       JSONB,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at   TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_wallet_tx_user_created ON wallet_transactions(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wallet_tx_extref ON wallet_transactions(external_ref) WHERE external_ref IS NOT NULL;

-- Payments MercadoPago (idempotencia + auditoría) -----------------------------
CREATE TABLE IF NOT EXISTS mp_payments (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id             TEXT NOT NULL,
  mp_preference_id    TEXT UNIQUE,
  mp_payment_id       TEXT UNIQUE,
  amount              NUMERIC(12,2) NOT NULL,
  status              TEXT NOT NULL DEFAULT 'created' CHECK (status IN
                        ('created','pending','approved','rejected','cancelled','refunded')),
  external_reference  TEXT,                       -- correlación interna
  purpose             TEXT NOT NULL DEFAULT 'wallet_recharge',
  raw                 JSONB,                      -- último payload recibido
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_mp_payments_user ON mp_payments(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_mp_payments_status ON mp_payments(status);

-- Balance derivado (por eficiencia): materializada corta.
-- Si crece mucho el histórico, migrar a snapshot periódico.
CREATE OR REPLACE FUNCTION rapi_team_user_balance(u TEXT) RETURNS NUMERIC AS $$
  SELECT COALESCE(SUM(amount), 0)
    FROM wallet_transactions
   WHERE user_id = u AND status = 'completed'
$$ LANGUAGE sql STABLE;

-- Trigger updated_at para vales y mp_payments ---------------------------------
DROP TRIGGER IF EXISTS trg_vales_updated_at ON vales;
CREATE TRIGGER trg_vales_updated_at BEFORE UPDATE ON vales
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trg_mp_payments_updated_at ON mp_payments;
CREATE TRIGGER trg_mp_payments_updated_at BEFORE UPDATE ON mp_payments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
