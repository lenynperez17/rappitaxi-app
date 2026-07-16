-- Ronda 134: agregar 'charged_back' al CHECK constraint de mp_payments.status.
-- MercadoPago envía este status cuando el banco resuelve un chargeback a favor
-- del comprador. Sin este valor válido, el UPDATE del webhook rebotaba con
-- constraint_violation → catch → 500 → MP reintentaba → deadlock de webhooks.
-- Peor: sin el mapping en código el status quedaba en 'pending' y NO se
-- reversaba el crédito del wallet, dejando saldo al usuario que ya cobró de
-- vuelta con el banco.

ALTER TABLE mp_payments DROP CONSTRAINT IF EXISTS mp_payments_status_check;
ALTER TABLE mp_payments ADD CONSTRAINT mp_payments_status_check
  CHECK (status IN ('created','pending','approved','rejected','cancelled','refunded','charged_back','discrepancy'));
