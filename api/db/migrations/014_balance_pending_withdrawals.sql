-- 014: Corregir rapi_team_user_balance para descontar withdrawals `pending`.
--
-- Bug (B#4 CRITICAL): la función solo suma `status='completed'`. Las debits
-- de withdrawals se insertan como `pending`, por lo que dos withdraw requests
-- concurrentes pasan el check `balance >= amount` sobre el mismo saldo →
-- doble spending si admin aprueba ambos.
--
-- Fix: incluir `pending` en la suma. Recharges se mantienen en `completed`
-- (solo aprueban al confirmar MP webhook), así que no infla el balance.

CREATE OR REPLACE FUNCTION rapi_team_user_balance(u TEXT) RETURNS NUMERIC AS $$
  SELECT COALESCE(SUM(amount), 0)
    FROM wallet_transactions
   WHERE user_id = u
     AND status IN ('completed', 'pending')
$$ LANGUAGE sql STABLE;
