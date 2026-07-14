/**
 * POST /api/auth/phone/send-code
 * Auth: Bearer JWT
 *
 * Envía OTP al `phoneNumber` para asociarlo al user ya autenticado
 * (típicamente tras login Google/Apple donde falta el teléfono).
 *
 * Diferencias con /api/auth/sms/send:
 *   - Requiere JWT del user actual.
 *   - No confunde el flujo de login por SMS (ese endpoint crea sesión nueva).
 *   - Reutiliza el mismo Twilio Verify / test-phones internamente.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { query } from '@/lib/db'
import { TwilioVerifyService } from '@/services/TwilioVerifyService'
import { ipRateLimit } from '@/lib/rate-limit'

export const runtime = 'nodejs'

const SEND_COOLDOWN_MS = 15 * 60 * 1000

const TEST_PHONE_NUMBERS: Record<string, string> = {
  '+51999000100': '1234',
  '+51999000101': '1234',
}
function testPhonesEnabled() {
  return process.env.TEST_PHONES_ENABLED === 'true'
}

function isValidE164(p: string) {
  return /^\+[1-9][0-9]{9,14}$/.test(p)
}

export async function POST(req: NextRequest) {
  // Rate limit por IP (defensa en profundidad + evita enumeración a granel).
  const rl = ipRateLimit(req, 'phone-send', {
    max: Number(process.env.SMS_RATE_LIMIT_PER_IP_PER_HOUR ?? 10),
    windowMs: 60 * 60 * 1000,
  })
  if (!rl.ok) {
    return NextResponse.json(
      { success: false, error: 'ip_rate_limited', message: 'Demasiadas solicitudes. Intenta más tarde.' },
      { status: 429 },
    )
  }

  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  let body: { phoneNumber?: string }
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  const phoneNumber = body.phoneNumber?.trim()
  if (!phoneNumber || !isValidE164(phoneNumber)) {
    return NextResponse.json(
      { success: false, error: 'invalid_phone', message: 'Número inválido. Formato E.164: +51999888777' },
      { status: 400 },
    )
  }

  // NO revelamos aquí si el phone está tomado (evita enumeración de PII).
  // La colisión se detecta silenciosamente en `/api/auth/phone/verify`.
  const phoneKey = phoneNumber.replace('+', '')

  // Test phones bypass — código fijo y no llama Twilio
  if (testPhonesEnabled() && TEST_PHONE_NUMBERS[phoneNumber]) {
    const testCode = TEST_PHONE_NUMBERS[phoneNumber]!
    const expiresAt = new Date(Date.now() + 60 * 60 * 1000)
    await query(
      `INSERT INTO phone_verifications (phone_key, phone_number, test_code, test_code_expires, is_test_phone, last_sent_at)
       VALUES ($1,$2,$3,$4,true,now())
       ON CONFLICT (phone_key) DO UPDATE
         SET test_code=$3, test_code_expires=$4, is_test_phone=true, last_sent_at=now()`,
      [phoneKey, phoneNumber, testCode, expiresAt],
    )
    return NextResponse.json({ success: true, provider: 'test', status: 'pending' })
  }

  // Cooldown 15 min por teléfono
  const rows = await query<{ last_sent_at: Date | null }>(
    'SELECT last_sent_at FROM phone_verifications WHERE phone_key = $1',
    [phoneKey],
  )
  const lastSentMs = rows[0]?.last_sent_at ? new Date(rows[0].last_sent_at).getTime() : 0
  if (lastSentMs > 0 && Date.now() - lastSentMs < SEND_COOLDOWN_MS) {
    const remainingMin = Math.ceil((SEND_COOLDOWN_MS - (Date.now() - lastSentMs)) / 60000)
    return NextResponse.json(
      {
        success: false,
        error: 'rate_limited',
        message: `Ya enviamos un código. Espera ${remainingMin} minuto${remainingMin !== 1 ? 's' : ''}.`,
        retryAfterMinutes: remainingMin,
      },
      { status: 429 },
    )
  }

  const twilio = new TwilioVerifyService()
  const result = await twilio.startVerification(phoneNumber)

  if (!result.success) {
    if (result.rateLimited) {
      return NextResponse.json(
        { success: false, error: 'rate_limited', message: 'Demasiados intentos.' },
        { status: 429 },
      )
    }
    if (result.noBalance) {
      return NextResponse.json(
        { success: false, error: 'sms_unavailable', message: 'Servicio SMS temporalmente no disponible.' },
        { status: 503 },
      )
    }
    return NextResponse.json({ success: false, error: 'sms_error', message: result.error }, { status: 500 })
  }

  await query(
    `INSERT INTO phone_verifications (phone_key, phone_number, last_sent_at)
     VALUES ($1,$2,now())
     ON CONFLICT (phone_key) DO UPDATE SET last_sent_at = now()`,
    [phoneKey, phoneNumber],
  )

  return NextResponse.json({ success: true, provider: 'sms', status: 'pending' })
}
