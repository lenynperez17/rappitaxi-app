/**
 * POST /api/auth/phone/verify
 * Auth: Bearer JWT
 * Body: { phoneNumber, code }
 *
 * Verifica el código OTP y **actualiza el phone del user autenticado**
 * (no crea sesión nueva ni user nuevo — a diferencia de /api/auth/sms/verify).
 *
 * Uso: tras login Google/Apple, en la pantalla de completar perfil.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { query, maybeOne } from '@/lib/db'
import { TwilioVerifyService } from '@/services/TwilioVerifyService'
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
  auth_provider: string | null
  profile_photo_url: string | null
}

export async function POST(req: NextRequest) {
  // Rate limit por IP contra fuerza bruta del código (defensa adicional a
  // los 5 intentos internos de Twilio Verify).
  const rl = ipRateLimit(req, 'phone-verify', {
    max: 30,
    windowMs: 60 * 60 * 1000,
  })
  if (!rl.ok) {
    return NextResponse.json(
      { success: false, error: 'ip_rate_limited', message: 'Demasiados intentos. Intenta más tarde.' },
      { status: 429 },
    )
  }

  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  let body: { phoneNumber?: string; code?: string }
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

  // Verificar ANTES de consumir el OTP que el teléfono no esté tomado por
  // otro user — evita gastar el código si el resultado sería 409.
  const takenPre = await maybeOne<{ id: string }>(
    `SELECT id FROM users WHERE (phone = $1 OR phone_number = $1) AND id != $2 AND deleted_at IS NULL LIMIT 1`,
    [phoneNumber, auth.userId],
  )
  if (takenPre) {
    return NextResponse.json(
      { success: false, error: 'phone_taken', message: 'Este número ya está registrado en otra cuenta.' },
      { status: 409 },
    )
  }

  const phoneKey = phoneNumber.replace('+', '')

  // Ronda 19 HIGH#1: doble guard test-phone (env + DB row) + invalidación tras uso
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
    await query(
      `UPDATE phone_verifications SET test_code = NULL, test_code_expires = NULL WHERE phone_key = $1`,
      [phoneKey],
    )
  } else {
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

  // Segundo check por race condition entre pre-check y verify
  const taken = await maybeOne<{ id: string }>(
    `SELECT id FROM users WHERE (phone = $1 OR phone_number = $1) AND id != $2 AND deleted_at IS NULL LIMIT 1`,
    [phoneNumber, auth.userId],
  )
  if (taken) {
    return NextResponse.json(
      { success: false, error: 'phone_taken', message: 'Este número ya está registrado en otra cuenta.' },
      { status: 409 },
    )
  }

  // Actualizar el user autenticado con el teléfono verificado
  const updated = await maybeOne<UserRow>(
    `UPDATE users
        SET phone = $1,
            phone_number = $1,
            phone_verified = true,
            updated_at = now()
      WHERE id = $2 AND deleted_at IS NULL
      RETURNING id, full_name, email, phone, user_type, profile_complete, is_active,
                auth_provider, profile_photo_url`,
    [phoneNumber, auth.userId],
  )

  if (!updated) {
    return NextResponse.json({ success: false, error: 'user_not_found' }, { status: 404 })
  }

  // Auditoría
  await query(
    `INSERT INTO auth_events (user_id, event_type, provider, ip_address, user_agent)
     VALUES ($1, 'phone_verified', $2, $3, $4)`,
    [
      auth.userId,
      updated.auth_provider ?? 'phone',
      req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? null,
      req.headers.get('user-agent'),
    ],
  )

  return NextResponse.json({
    success: true,
    user: {
      id: updated.id,
      fullName: updated.full_name,
      email: updated.email,
      phone: updated.phone,
      userType: updated.user_type,
      profileComplete: updated.profile_complete,
      profilePhotoUrl: updated.profile_photo_url,
    },
  })
}
