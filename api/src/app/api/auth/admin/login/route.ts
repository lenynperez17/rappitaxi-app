/**
 * POST /api/auth/admin/login
 * Body: { email, password }
 *
 * Login del panel admin — email + password. Solo funciona para users con
 * is_admin=true o user_type='admin'. Emite JWT session igual que SMS.
 */
import { NextRequest, NextResponse } from 'next/server'
import bcrypt from 'bcryptjs'
import { query, maybeOne } from '@/lib/db'
import { createSession, deviceInfoFromHeaders } from '@/lib/sessions'
import { ACCESS_TTL_SECONDS, REFRESH_TTL_SECONDS } from '@/lib/jwt'
import { getClientIp } from '@/lib/auth-middleware'
import { ipRateLimit, keyedRateLimit } from '@/lib/rate-limit'

export const runtime = 'nodejs'

interface UserRow {
  id: string
  full_name: string | null
  email: string | null
  phone: string | null
  user_type: string
  is_admin: boolean
  is_active: boolean
  suspended_at: Date | null
  deleted_at: Date | null
  password_hash: string | null
  profile_complete: boolean
}

export async function POST(req: NextRequest) {
  // B#5: rate-limit por IP para bloquear brute-force. 5 intentos / 15min.
  const rl = ipRateLimit(req, 'admin-login', { max: 5, windowMs: 15 * 60_000 })
  if (!rl.ok) {
    return NextResponse.json(
      { success: false, error: 'rate_limited', message: 'Demasiados intentos. Espera 15 minutos.' },
      { status: 429 },
    )
  }

  let body: { email?: string; password?: string }
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  const email = body.email?.trim().toLowerCase()
  const password = body.password

  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return NextResponse.json({ success: false, error: 'invalid_email' }, { status: 400 })
  }
  // B#5: password mínima 8 caracteres (era 4, brute-forceable).
  if (!password || password.length < 8) {
    return NextResponse.json({ success: false, error: 'invalid_password' }, { status: 400 })
  }

  // Ronda 57 Bug#2: rate-limit adicional por email (además del IP). Sin esto,
  // botnet distribuido con IPs rotativas puede brute-forcear un email admin
  // sin disparar ipRateLimit. 10 intentos/hora por email es amplio para
  // usuarios legítimos y bloquea brute-force distribuido.
  const emailRl = keyedRateLimit(`admin-login:email:${email}`, { max: 10, windowMs: 60 * 60_000 })
  if (!emailRl.ok) {
    return NextResponse.json(
      { success: false, error: 'rate_limited', message: 'Demasiados intentos para esta cuenta. Espera 1 hora.' },
      { status: 429 },
    )
  }

  const user = await maybeOne<UserRow>(
    `SELECT id, full_name, email, phone, user_type, is_admin, is_active,
            suspended_at, deleted_at, password_hash, profile_complete
       FROM users
      WHERE LOWER(email) = $1 AND deleted_at IS NULL
      LIMIT 1`,
    [email],
  )

  // Anti-enumeración: SIEMPRE ejecutar bcrypt.compare (timing uniforme) y
  // devolver el mismo error 401 para cualquier fallo pre-auth. Un atacante no
  // puede distinguir "no existe" / "no es admin" / "sin contraseña" / "clave incorrecta".
  const DUMMY_HASH = '$2b$10$CwTycUXWue0Thq9StjUM0uJ8VkQqL0e6zJhZ5X9Q0Xk6H8QhE7uYK'
  const hashToCheck = user?.password_hash ?? DUMMY_HASH
  const passwordOk = await bcrypt.compare(password, hashToCheck)

  const isEligible =
    user &&
    user.password_hash &&
    (user.is_admin || user.user_type === 'admin') &&
    !user.suspended_at &&
    user.is_active &&
    passwordOk

  if (!isEligible) {
    // Log server-side el motivo real (para observabilidad interna), NO se envía al cliente
    if (user) {
      const reason = !user.password_hash ? 'password_not_set'
                   : (!user.is_admin && user.user_type !== 'admin') ? 'not_admin'
                   : user.suspended_at ? 'account_suspended'
                   : !user.is_active ? 'account_inactive'
                   : 'invalid_password'
      await query(
        `INSERT INTO auth_events (user_id, event_type, provider, ip_address, user_agent, metadata)
         VALUES ($1, 'admin_login_failed', 'admin', $2, $3, $4)`,
        [user.id, getClientIp(req), req.headers.get('user-agent'), JSON.stringify({ email, reason })],
      )
    }
    return NextResponse.json({ success: false, error: 'invalid_credentials' }, { status: 401 })
  }

  const session = await createSession(user.id, deviceInfoFromHeaders(req.headers))

  await query(
    `INSERT INTO auth_events (user_id, event_type, provider, ip_address, user_agent, metadata)
     VALUES ($1, 'admin_login_success', 'admin', $2, $3, $4)`,
    [user.id, getClientIp(req), req.headers.get('user-agent'), JSON.stringify({ email })],
  )

  return NextResponse.json({
    success: true,
    user: {
      id: user.id,
      fullName: user.full_name,
      email: user.email,
      phone: user.phone,
      userType: user.user_type,
      isAdmin: user.is_admin,
      isActive: user.is_active,
      profileComplete: user.profile_complete,
    },
    jwt: session.accessToken,
    refreshToken: session.refreshToken,
    accessTtlSec: ACCESS_TTL_SECONDS,
    refreshTtlSec: REFRESH_TTL_SECONDS,
  })
}
