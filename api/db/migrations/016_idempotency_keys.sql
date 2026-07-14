-- 016: Idempotency keys para operaciones de dinero.
--
-- HIGH: sin este mecanismo, un doble-click / retry del panel crea 2
-- driver_recharges (o 2 wallet_withdrawals) que duplican el crédito/débito
-- real del driver. Solución: header `Idempotency-Key` único por driver;
-- si viene, la 2da request retorna el mismo id sin crear registro nuevo.

ALTER TABLE driver_recharges
  ADD COLUMN IF NOT EXISTS idempotency_key text;

CREATE UNIQUE INDEX IF NOT EXISTS ux_driver_recharges_idempotency
  ON driver_recharges (driver_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

ALTER TABLE wallet_withdrawals
  ADD COLUMN IF NOT EXISTS idempotency_key text;

CREATE UNIQUE INDEX IF NOT EXISTS ux_wallet_withdrawals_idempotency
  ON wallet_withdrawals (driver_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;
