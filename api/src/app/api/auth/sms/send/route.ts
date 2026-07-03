/**
 * POST /api/auth/sms/send
 * Body: { phoneNumber: "+5193..." }
 *
 * Envía OTP vía Twilio Verify + cooldown 15 min server-side en Postgres.
 * Rate limit por IP en memoria (proceso PM2).
 */
import { NextRequest, NextResponse } from 'next/server'
import { query } from '@/lib/db'
import { TwilioVerifyService } from '@/services/TwilioVerifyService'

export const runtime = 'nodejs'

const SEND_COOLDOWN_MS = 15 * 60 * 1000

// Test phones (App Store / Play Store review)
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

const ipBuckets = new Map<string, { count: number; resetAt: number }>()
const IP_WINDOW_MS = 60 * 60 * 1000

function ipRateLimit(req: NextRequest): { ok: boolean; remaining: number } {
  const max = Number(process.env.SMS_RATE_LIMIT_PER_IP_PER_HOUR ?? 10)
  const ip =
    req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ??
    req.headers.get('x-real-ip') ??
    'unknown'
  const now = Date.now()
  const bucket = ipBuckets.get(ip)
  if (!bucket || bucket.resetAt < now) {
    ipBuckets.set(ip, { count: 1, resetAt: now + IP_WINDOW_MS })
    return { ok: true, remaining: max - 1 }
  }
  if (bucket.count >= max) return { ok: false, remaining: 0 }
  bucket.count += 1
  return { ok: true, remaining: max - bucket.count }
}

export async function POST(req: NextRequest) {
  const rl = ipRateLimit(req)
  if (!rl.ok) {
    return NextResponse.json(
      { success: false, error: 'ip_rate_limited', message: 'Demasiadas solicitudes. Intenta más tarde.' },
      { status: 429 },
    )
  }

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

  const phoneKey = phoneNumber.replace('+', '')

  // Test phones bypass
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
    console.log(`🧪 [TEST] ${phoneNumber} código fijo ${testCode}`)
    return NextResponse.json({ success: true, provider: 'test', status: 'pending' })
  }

  // Cooldown 15 min
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
        message: `Ya enviamos un código. Espera ${remainingMin} minuto${remainingMin !== 1 ? 's' : ''} o usa Google/Apple.`,
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
        { success: false, error: 'rate_limited', message: 'Demasiados intentos. Usa Google/Apple.' },
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
