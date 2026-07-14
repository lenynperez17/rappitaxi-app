-- Comprobantes electrónicos (Facturación) y Notas de Crédito.
-- Sin integración SUNAT todavía: se emiten como "documentos internos" que
-- pueden convertirse a comprobantes electrónicos cuando SUNAT esté cableado.

CREATE TABLE IF NOT EXISTS invoices (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  -- Serie + correlativo (F001-00000001 para factura, B001-XXXXXXXX para boleta)
  series            TEXT NOT NULL,
  correlative       INTEGER NOT NULL,
  document_type     TEXT NOT NULL CHECK (document_type IN ('receipt', 'invoice', 'boleta')),
  -- Cliente (customer_id opcional — puede ser usuario del sistema)
  customer_id       TEXT REFERENCES users(id) ON DELETE SET NULL,
  customer_doc_type TEXT CHECK (customer_doc_type IN ('DNI', 'RUC', 'CE', 'PASSPORT')),
  customer_doc      TEXT,
  customer_name     TEXT NOT NULL,
  customer_email    TEXT,
  customer_address  TEXT,
  -- Origen del cobro
  recharge_id       UUID REFERENCES driver_recharges(id) ON DELETE SET NULL,
  ride_id           UUID REFERENCES rides(id) ON DELETE SET NULL,
  -- Montos (soles peruanos)
  subtotal          NUMERIC(10,2) NOT NULL,
  igv               NUMERIC(10,2) NOT NULL DEFAULT 0,
  total             NUMERIC(10,2) NOT NULL,
  currency          TEXT NOT NULL DEFAULT 'PEN',
  -- Items del comprobante (JSON: [{description, quantity, unitPrice, total}])
  items             JSONB NOT NULL DEFAULT '[]'::jsonb,
  -- Estado
  status            TEXT NOT NULL DEFAULT 'issued' CHECK (
    status IN ('issued', 'sent', 'paid', 'voided', 'sunat_pending', 'sunat_sent', 'sunat_error')
  ),
  -- SUNAT (opcional, cuando se integre)
  sunat_hash        TEXT,
  sunat_response    JSONB,
  pdf_url           TEXT,
  xml_url           TEXT,
  -- Auditoría
  issued_by         TEXT REFERENCES users(id) ON DELETE SET NULL,
  issued_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  voided_at         TIMESTAMPTZ,
  metadata          JSONB DEFAULT '{}'::jsonb,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT invoices_series_correlative_unique UNIQUE (series, correlative)
);

CREATE INDEX IF NOT EXISTS idx_invoices_customer ON invoices (customer_id, issued_at DESC);
CREATE INDEX IF NOT EXISTS idx_invoices_status ON invoices (status, issued_at DESC);
CREATE INDEX IF NOT EXISTS idx_invoices_issued ON invoices (issued_at DESC);
CREATE INDEX IF NOT EXISTS idx_invoices_recharge ON invoices (recharge_id) WHERE recharge_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS credit_notes (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  series            TEXT NOT NULL,
  correlative       INTEGER NOT NULL,
  invoice_id        UUID NOT NULL REFERENCES invoices(id) ON DELETE RESTRICT,
  reason            TEXT NOT NULL CHECK (
    reason IN ('anulacion', 'devolucion', 'descuento_global', 'descuento_item', 'ajuste_precio', 'otros')
  ),
  reason_notes      TEXT,
  amount            NUMERIC(10,2) NOT NULL,
  status            TEXT NOT NULL DEFAULT 'issued' CHECK (
    status IN ('issued', 'sunat_pending', 'sunat_sent', 'sunat_error')
  ),
  sunat_hash        TEXT,
  sunat_response    JSONB,
  pdf_url           TEXT,
  xml_url           TEXT,
  issued_by         TEXT REFERENCES users(id) ON DELETE SET NULL,
  issued_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  metadata          JSONB DEFAULT '{}'::jsonb,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT credit_notes_series_correlative_unique UNIQUE (series, correlative)
);

CREATE INDEX IF NOT EXISTS idx_credit_notes_invoice ON credit_notes (invoice_id);
CREATE INDEX IF NOT EXISTS idx_credit_notes_issued ON credit_notes (issued_at DESC);

-- Triggers para updated_at
CREATE TRIGGER trg_invoices_updated_at BEFORE UPDATE ON invoices
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_credit_notes_updated_at BEFORE UPDATE ON credit_notes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

GRANT ALL PRIVILEGES ON invoices TO rapi_team_user;
GRANT ALL PRIVILEGES ON credit_notes TO rapi_team_user;
