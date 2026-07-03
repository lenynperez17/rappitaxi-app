/**
 * POST /api/auth/sms/verify
 * Body: { phoneNumber, code }
 *
 * Valida OTP con Twilio Verify (o test code local). Al éxito:
 *  1. Upsert user en Postgres (usando phone como identity)
 *  2. Crea session JWT (access + refresh)
 *  3. Firma Firebase Custom Token (para que el Flutter siga usando Firebase)
 *
 * Response: { user, jwt, refreshToken, firebaseCustomToken }
 */
import { NextRequest, NextResponse } from 'next/server'
import { randomUUID } from 'crypto'
import { query, maybeOne } from '@/lib/db'
import { TwilioVerifyService } from '@/services/TwilioVerifyService'
import { createSession } from '@/lib/sessions'
import { ACCESS_TTL_SECONDS, REFRESH_TTL_SECONDS } from '@/lib/jwt'
import { auth as firebaseAuth } from '@/lib/firebase-admin'

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

  // Path test phone: validación local sin llamar a Twilio
  const testRow = await maybeOne<{ test_code: string | null; test_code_expires: Date | null; is_test_phone: boolean }>(
    'SELECT test_code, test_code_expires, is_test_phone FROM phone_verifications WHERE phone_key = $1',
    [phoneKey],
  )
  const isTestPhone = testRow?.is_test_phone && testRow?.test_code
  if (isTestPhone) {
    const expired = testRow!.test_code_expires && new Date(testRow!.test_code_expires) < new Date()
    if (expired) {
      return NextResponse.json({ success: false, error: 'code_expired' }, { status: 410 })
    }
    if (code !== testRow!.test_code) {
      return NextResponse.json({ success: false, error: 'code_incorrect' }, { status: 400 })
    }
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

  // Upsert user (por phone). Si no existe, crear con UUID nuevo.
  let user = await maybeOne<UserRow>(
    `SELECT id, full_name, email, phone, user_type, profile_complete, is_active
       FROM users WHERE phone = $1 OR phone_number = $1 LIMIT 1`,
    [phoneNumber],
  )
  let isNewUser = false

  if (!user) {
    isNewUser = true
    const newId = randomUUID()
    user = await maybeOne<UserRow>(
      `INSERT INTO users (id, phone, phone_number, phone_verified, auth_provider, user_type, is_active)
       VALUES ($1, $2, $2, true, 'phone', 'passenger', true)
       RETURNING id, full_name, email, phone, user_type, profile_complete, is_active`,
      [newId, phoneNumber],
    )
  } else if (!user.is_active) {
    return NextResponse.json(
      { success: false, error: 'account_suspended', message: 'Cuenta suspendida. Contacta a soporte.' },
      { status: 403 },
    )
  }

  // Session (JWT propio) + Firebase Custom Token
  const session = await createSession(user!.id, (body.deviceInfo as Record<string, unknown>) ?? {})

  const firebaseCustomToken = await firebaseAuth.createCustomToken(user!.id, {
    provider: 'phone',
    phone: phoneNumber,
  })

  // Auditoría
  await query(
    `INSERT INTO auth_events (user_id, event_type, provider, ip_address, user_agent, metadata)
     VALUES ($1, 'login_phone', 'phone', $2, $3, $4)`,
    [
      user!.id,
      req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? null,
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
    firebaseCustomToken,
  })
}
