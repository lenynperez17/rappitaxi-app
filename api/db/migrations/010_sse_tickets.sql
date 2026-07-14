-- Tickets de un solo uso para autenticar SSE stream sin exponer el JWT en la URL.
-- El flujo es:
--   1) Cliente autenticado hace POST /api/events/ticket (Bearer JWT)
--   2) Server crea ticket UUID, TTL 60s, ligado al user_id
--   3) Cliente abre GET /api/events/stream?ticket=UUID
--   4) Server valida ticket, lo marca como consumido, abre stream
-- El JWT NO aparece en logs de nginx, referer headers ni history del navegador.

INSERT INTO schema_migrations (version, description)
VALUES ('010', 'sse_tickets')
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS sse_tickets (
  ticket        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at    TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '60 seconds'),
  consumed_at   TIMESTAMPTZ,
  ip_address    INET,
  user_agent    TEXT
);
CREATE INDEX IF NOT EXISTS idx_sse_tickets_expires ON sse_tickets(expires_at);
CREATE INDEX IF NOT EXISTS idx_sse_tickets_user ON sse_tickets(user_id, created_at DESC);
