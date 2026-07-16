-- 022: Ronda 171 SMS-PUMPING FIX.
-- Bug: la FK initiated_by → users(id) usaba ON DELETE CASCADE. Como
-- phone_verifications está keyed por phone_key (E.164), la única fuente
-- de verdad del cooldown de 15 min es la fila del teléfono. Al borrar
-- la cuenta del initiator, CASCADE eliminaba la fila del teléfono → se
-- perdía last_sent_at → el rate-limit por número quedaba reseteado.
--
-- Escenario de fraude Twilio (SMS-pumping):
--   1. Attacker registra cuenta throwaway A + POST /phone/send-code al
--      número real de una víctima → inserta fila con last_sent_at=now().
--   2. Attacker borra su cuenta A (o cleanup admin de no-verificadas).
--   3. CASCADE → phone_verifications se limpia para ese teléfono.
--   4. Attacker reinicia signup y envía otro OTP al mismo número
--      inmediatamente. Rate-limit resetado → Twilio Verify se llama de
--      nuevo. Repite en loop → factura Twilio + SMS flood a la víctima.
--
-- Fix: SET NULL preserva phone_key + last_sent_at (identidad = teléfono,
-- no user). El campo initiated_by es NULLABLE por diseño (comentario en
-- migración 020) para signup público, así que SET NULL es semánticamente
-- correcto.

ALTER TABLE phone_verifications
  DROP CONSTRAINT IF EXISTS phone_verifications_initiated_by_fkey;

ALTER TABLE phone_verifications
  ADD CONSTRAINT phone_verifications_initiated_by_fkey
    FOREIGN KEY (initiated_by) REFERENCES users(id) ON DELETE SET NULL;
