-- 023: Ronda 173 CONTABLE/SUNAT.
-- Bug: driver_recharges.driver_id → users(id) ON DELETE CASCADE.
-- Si un admin/script hace DELETE FROM users WHERE id = X (hard-delete),
-- CASCADE elimina TODAS las recargas del driver → historial contable
-- perdido, no reportable a SUNAT.
--
-- El flow normal usa soft-delete (UPDATE deleted_at) que no dispara CASCADE.
-- Este fix es defensa en profundidad: RESTRICT bloquea cualquier
-- hard-delete accidental o malicioso de un user con historial de recargas,
-- forzando al operador a usar soft-delete.
--
-- Aplicable también a driver_bank_accounts, wallet_withdrawals, invoices,
-- credit_notes que registran flujos monetarios reportables.

ALTER TABLE driver_recharges
  DROP CONSTRAINT IF EXISTS driver_recharges_driver_id_fkey;
ALTER TABLE driver_recharges
  ADD CONSTRAINT driver_recharges_driver_id_fkey
    FOREIGN KEY (driver_id) REFERENCES users(id) ON DELETE RESTRICT;

-- NOTA deploy: driver_bank_accounts está historial-mente owned por 'postgres'
-- (bug de deploy inicial). Antes de correr esta migración por primera vez:
--   sudo -u postgres psql <db> -c "ALTER TABLE driver_bank_accounts OWNER TO rapi_team_user"
-- El ALTER OWNER es idempotente. Estas dos ALTER TABLE fallan silenciosamente
-- si no se es dueño, así que en re-runs no rompen.
ALTER TABLE driver_bank_accounts
  DROP CONSTRAINT IF EXISTS driver_bank_accounts_driver_id_fkey;
ALTER TABLE driver_bank_accounts
  ADD CONSTRAINT driver_bank_accounts_driver_id_fkey
    FOREIGN KEY (driver_id) REFERENCES users(id) ON DELETE RESTRICT;

ALTER TABLE wallet_withdrawals
  DROP CONSTRAINT IF EXISTS wallet_withdrawals_driver_id_fkey;
ALTER TABLE wallet_withdrawals
  ADD CONSTRAINT wallet_withdrawals_driver_id_fkey
    FOREIGN KEY (driver_id) REFERENCES users(id) ON DELETE RESTRICT;
