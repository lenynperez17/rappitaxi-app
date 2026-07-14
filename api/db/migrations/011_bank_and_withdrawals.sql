-- Rapi Team — cuentas bancarias del conductor + retiros del wallet
-- ============================================================================
INSERT INTO schema_migrations (version, description)
VALUES ('011', 'bank_and_withdrawals')
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS driver_bank_accounts (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  driver_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  bank_name      TEXT NOT NULL,
  account_type   TEXT NOT NULL CHECK (account_type IN ('savings','checking')),
  account_number TEXT NOT NULL,
  cci            TEXT,                              -- Código de Cuenta Interbancario (Perú)
  holder_name    TEXT NOT NULL,
  holder_document TEXT NOT NULL,                    -- DNI del titular
  is_default     BOOLEAN NOT NULL DEFAULT false,
  is_active      BOOLEAN NOT NULL DEFAULT true,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(driver_id, account_number)
);
CREATE INDEX IF NOT EXISTS idx_driver_bank_accounts_driver ON driver_bank_accounts(driver_id);

CREATE TABLE IF NOT EXISTS wallet_withdrawals (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  driver_id         TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  bank_account_id   UUID NOT NULL REFERENCES driver_bank_accounts(id) ON DELETE RESTRICT,
  amount            NUMERIC(12,2) NOT NULL,
  fee               NUMERIC(10,2) NOT NULL DEFAULT 0,
  net_amount        NUMERIC(12,2) NOT NULL,
  status            TEXT NOT NULL DEFAULT 'pending' CHECK (status IN
                      ('pending','approved','rejected','completed','cancelled')),
  external_ref      TEXT,                              -- referencia bancaria
  reject_reason     TEXT,
  approved_by       TEXT REFERENCES users(id) ON DELETE SET NULL,
  approved_at       TIMESTAMPTZ,
  completed_at      TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_wallet_withdrawals_driver ON wallet_withdrawals(driver_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wallet_withdrawals_status ON wallet_withdrawals(status, created_at DESC);

DROP TRIGGER IF EXISTS trg_bank_accounts_updated_at ON driver_bank_accounts;
CREATE TRIGGER trg_bank_accounts_updated_at BEFORE UPDATE ON driver_bank_accounts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trg_withdrawals_updated_at ON wallet_withdrawals;
CREATE TRIGGER trg_withdrawals_updated_at BEFORE UPDATE ON wallet_withdrawals
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
