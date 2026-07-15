-- 019: Excluir type='commission' del cálculo de balance del usuario.
--
-- Bug (Ronda 17 CRITICAL#2): en rides pagados con wallet, la fila de
-- comisión se inserta con user_id=passenger_id + amount=+commissionAmount
-- (positivo) por el TODO inline en rides/[id]/complete/route.ts:216-232 —
-- el bucket contable de la comisión NO tenía a dónde ir porque
-- wallet_transactions.user_id es NOT NULL. Como la función 014 suma
-- TODOS los amounts del user, la comisión positive se acredita al
-- pasajero → platform pierde la comisión permanentemente.
--
-- Ejemplo: pasajero con S/100 en wallet, ride S/100, comisión 20%
--   debit(-100) + credit_driver(+80 al driver) + commission(+20 al pasajero)
--   balance pasajero = 100 - 100 + 20 = S/20 en vez de S/0. Platform pierde S/20.
--
-- Fix: excluir type='commission' del cálculo del balance del pasajero.
-- La fila queda para audit trail (endpoint filtra por type != 'commission' al
-- serializar el historial), pero no infla el balance real.

CREATE OR REPLACE FUNCTION rapi_team_user_balance(u TEXT) RETURNS NUMERIC AS $$
  SELECT COALESCE(SUM(amount), 0)
    FROM wallet_transactions
   WHERE user_id = u
     AND status IN ('completed', 'pending')
     AND type != 'commission'
$$ LANGUAGE sql STABLE;
