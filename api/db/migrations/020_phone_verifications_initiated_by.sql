-- 020: Añadir initiated_by a phone_verifications para prevenir hijack.
--
-- Bug (Ronda 66 CRITICAL): phone/send-code guardaba fila sin user_id →
-- si un attacker obtenía el código (SIM swap, phishing), su llamada a
-- /phone/verify asociaba el phone a SU cuenta en vez de rechazar por
-- mismatch. Ahora send-code registra initiated_by=$auth.userId (o NULL
-- para signup público SMS) y verify chequea que coincida.
--
-- initiated_by es NULLABLE porque /api/auth/sms/send es signup público
-- (no requiere auth previa); pero para /api/auth/phone/send-code (usuario
-- ya logueado agregando/cambiando su phone) sí es NOT NULL.

ALTER TABLE phone_verifications
  ADD COLUMN IF NOT EXISTS initiated_by TEXT REFERENCES users(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_phone_verifications_initiated_by
  ON phone_verifications(initiated_by) WHERE initiated_by IS NOT NULL;
