/**
 * TwilioSmsSender — enviador de SMS simples (no OTP verify).
 *
 * Usado para notificar a contactos de emergencia que NO son app users
 * (mamá, esposo, hermano) cuando el user activa el panic button.
 *
 * Reutiliza las credenciales de Twilio que ya viven en `.env`
 * (TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN). El sender number debe estar
 * configurado como `TWILIO_SMS_FROM` (número Twilio verificado).
 *
 * Comportamiento:
 *   - Sin credenciales → throw config_error (el caller loguea y sigue).
 *   - Timeout de 10s por request (no bloquea el endpoint por SMS colgado).
 *   - Retorna el SID del mensaje si Twilio lo aceptó.
 */

const TWILIO_BASE = 'https://api.twilio.com/2010-04-01'

export async function sendSmsMessage(toE164: string, body: string): Promise<string> {
  const sid = process.env.TWILIO_ACCOUNT_SID
  const token = process.env.TWILIO_AUTH_TOKEN
  const from = process.env.TWILIO_SMS_FROM
  if (!sid || !token) throw new Error('config_error: TWILIO_ACCOUNT_SID / TWILIO_AUTH_TOKEN missing')
  if (!from) throw new Error('config_error: TWILIO_SMS_FROM missing')
  if (!/^\+[1-9]\d{9,14}$/.test(toE164)) throw new Error(`invalid_phone: ${toE164}`)

  const auth = 'Basic ' + Buffer.from(`${sid}:${token}`).toString('base64')
  const form = new URLSearchParams()
  form.append('To', toE164)
  form.append('From', from)
  form.append('Body', body.slice(0, 1000)) // Twilio hard-limit ~1600, dejar margen

  const r = await fetch(`${TWILIO_BASE}/Accounts/${sid}/Messages.json`, {
    method: 'POST',
    headers: {
      Authorization: auth,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: form.toString(),
    signal: AbortSignal.timeout(10_000),
  })

  const text = await r.text()
  if (!r.ok) throw new Error(`twilio_${r.status}: ${text.slice(0, 200)}`)
  try {
    const parsed = JSON.parse(text) as { sid?: string; status?: string }
    return parsed.sid ?? 'unknown'
  } catch {
    return 'unknown'
  }
}
