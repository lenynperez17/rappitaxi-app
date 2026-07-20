/**
 * POST /api/auth/sms/verify
 * Body: { phoneNumber, code }
 *
 * Valida OTP con Twilio Verify (o test code local). Al éxito:
 *  1. Upsert user en Postgres (usando phone como identity)
 *  2. Crea session JWT (access + refresh)
 *  3. Firma Firebase Custom Token (para que el Flutter siga usando Firebase)
 *
 * Response: { user, jwt, refreshToken, accessTtlSec, refreshTtlSec }
 */
import { NextRequest, NextResponse } from 'next/server'
import { randomUUID } from 'crypto'
import { query, maybeOne } from '@/lib/db'
import { TwilioVerifyService } from '@/services/TwilioVerifyService'
import { createSession } from '@/lib/sessions'
import { ACCESS_TTL_SECONDS, REFRESH_TTL_SECONDS } from '@/lib/jwt'
import { ipRateLimit } from '@/lib/rate-limit'

export const runtime = 'nodejs'

function isValidE164(p: string) {
  return /^\+[1-9][0-9]{9,14}$/.test(p)
}

interface UserRow {
  id: string
  full_name: string | null
  email: string | null
  phone: string | null
  user_type: string
  profile_complete: boolean
  is_active: boolean
}

export async function POST(req: NextRequest) {
  // B#6: rate-limit por IP. 15 verificaciones / hora es holgado para uso
  // legítimo (usuario típico intenta 1-3 códigos) y bloquea el brute-force
  // sobre los test-phones (código fijo `1234`, espacio de 10⁴).
  const rl = ipRateLimit(req, 'sms-verify', { max: 15, windowMs: 60 * 60_000 })
  if (!rl.ok) {
    return NextResponse.json(
      { success: false, error: 'rate_limited', message: 'Demasiados intentos. Espera 1 hora.' },
      { status: 429 },
    )
  }

  let body: { phoneNumber?: string; code?: string; deviceInfo?: unknown }
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  const phoneNumber = body.phoneNumber?.trim()
  const code = body.code?.trim()

  if (!phoneNumber || !isValidE164(phoneNumber)) {
    return NextResponse.json({ success: false, error: 'invalid_phone' }, { status: 400 })
  }
  if (!code || !/^\d{4,6}$/.test(code)) {
    return NextResponse.json({ success: false, error: 'invalid_code' }, { status: 400 })
  }

  const phoneKey = phoneNumber.replace('+', '')

  // Ronda 19 HIGH#1: doble guard — la rama test-phone requiere BOTH
  //   (a) TEST_PHONES_ENABLED=true en el env actual
  //   (b) is_test_phone=true en la fila
  // Sin la condición (a), un dump de DB de staging importado a prod dejaba filas
  // is_test_phone=true persistidas → cualquiera con el código fijo obtiene sesión
  // sin tocar Twilio. Además invalidamos test_code tras uso exitoso para bloquear
  // OTP replay dentro de la ventana de 1h.
  const testPhonesEnabled = process.env.TEST_PHONES_ENABLED === 'true'
  const testRow = await maybeOne<{ test_code: string | null; test_code_expires: Date | null; is_test_phone: boolean }>(
    'SELECT test_code, test_code_expires, is_test_phone FROM phone_verifications WHERE phone_key = $1',
    [phoneKey],
  )
  const isTestPhone = testPhonesEnabled && testRow?.is_test_phone && testRow?.test_code
  if (isTestPhone) {
    const expired = testRow!.test_code_expires && new Date(testRow!.test_code_expires) < new Date()
    if (expired) {
      return NextResponse.json({ success: false, error: 'code_expired' }, { status: 410 })
    }
    if (code !== testRow!.test_code) {
      return NextResponse.json({ success: false, error: 'code_incorrect' }, { status: 400 })
    }
    // Invalidar el test_code tras uso exitoso — evita replay dentro de la ventana
    await query(
      `UPDATE phone_verifications SET test_code = NULL, test_code_expires = NULL WHERE phone_key = $1`,
      [phoneKey],
    )
  } else {
    // Path Twilio real
    const twilio = new TwilioVerifyService()
    const result = await twilio.checkVerification(phoneNumber, code)
    if (!result.accepted) {
      const status = result.reason === 'expired' ? 410 : 400
      return NextResponse.json(
        { success: false, error: result.reason === 'expired' ? 'code_expired' : 'code_incorrect' },
        { status },
      )
    }
  }

  // Upsert user (por phone). Solo matchear filas con phone_verified=true —
  // sin este filtro, un atacante que setea `phone` a un número ajeno via
  // PATCH podía secuestrar la cuenta cuando el dueño real hacía SMS login.
  // Además ordenamos por phone_verified DESC + created_at ASC para lookup
  // determinista si por alguna razón hay múltiples filas.
  let user = await maybeOne<UserRow>(
    `SELECT id, full_name, email, phone, user_type, profile_complete, is_active
       FROM users
       WHERE (phone = $1 OR phone_number = $1)
         AND phone_verified = true
       ORDER BY phone_verified DESC, created_at ASC
       LIMIT 1`,
    [phoneNumber],
  )
  let isNewUser = false

  if (!user) {
    isNewUser = true
    const newId = randomUUID()
    user = await maybeOne<UserRow>(
      `INSERT INTO users (id, phone, phone_number, phone_verified, auth_provider, user_type, is_active, created_from)
       VALUES ($1, $2, $2, true, 'phone', 'passenger', true, 'mobile')
       RETURNING id, full_name, email, phone, user_type, profile_complete, is_active`,
      [newId, phoneNumber],
    )
  } else if (!user.is_active) {
    return NextResponse.json(
      { success: false, error: 'account_suspended', message: 'Cuenta suspendida. Contacta a soporte.' },
      { status: 403 },
    )
  }

  // Session JWT propia — sin Firebase
  const session = await createSession(user!.id, (body.deviceInfo as Record<string, unknown>) ?? {})

  // Auditoría.
  // Ronda 128 BUG: X-Forwarded-For puede venir vacío ("") o con texto no-IP
  // ("unknown", legado de proxies antiguos/CDNs). `?? null` NO convierte
  // "" a null (nullish coalescing solo agarra null/undefined), y la columna
  // ip_address es INET → PostgreSQL rechaza "invalid input syntax for type
  // inet" y tira 500 DESPUÉS de que Twilio consumió el OTP y de que se creó
  // la session. Cliente queda sin token con OTP quemado. Validamos con
  // regex y forzamos NULL cuando no es una IPv4/IPv6 plausible.
  const xffRaw = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim()
  const clientIp = xffRaw && /^[0-9a-fA-F:.]+$/.test(xffRaw) && xffRaw.length <= 45 ? xffRaw : null
  await query(
    `INSERT INTO auth_events (user_id, event_type, provider, ip_address, user_agent, metadata)
     VALUES ($1, 'login_phone', 'phone', $2, $3, $4)`,
    [
      user!.id,
      clientIp,
      req.headers.get('user-agent'),
      JSON.stringify({ isNewUser }),
    ],
  )

  return NextResponse.json({
    success: true,
    isNewUser,
    user: {
      id: user!.id,
      fullName: user!.full_name,
      email: user!.email,
      phone: user!.phone,
      userType: user!.user_type,
      profileComplete: user!.profile_complete,
    },
    jwt: session.accessToken,
    refreshToken: session.refreshToken,
    accessTtlSec: ACCESS_TTL_SECONDS,
    refreshTtlSec: REFRESH_TTL_SECONDS,
  })
}
