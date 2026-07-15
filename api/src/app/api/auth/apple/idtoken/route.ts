/**
 * POST /api/auth/apple/idtoken
 * Body: { identityToken, authorizationCode?, fullName?, deviceInfo? }
 *
 * Verifica el identity token de Sign in with Apple. Upsert user en Postgres.
 * Emite JWT session + opcional Firebase Custom Token.
 *
 * Verificación: se descarga JWKS público de Apple, se valida firma + iss + aud.
 */
import { NextRequest, NextResponse } from 'next/server'
import { randomUUID } from 'crypto'
import { jwtVerify, createRemoteJWKSet } from 'jose'
import { query, maybeOne } from '@/lib/db'
import { createSession } from '@/lib/sessions'
import { ACCESS_TTL_SECONDS, REFRESH_TTL_SECONDS } from '@/lib/jwt'

export const runtime = 'nodejs'

const APPLE_JWKS = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'))
const APPLE_ISSUER = 'https://appleid.apple.com'

// Bundle ID + Service ID aceptados como audience.
// El Bundle ID viene desde el app iOS/Android; el Service ID desde web (no aplica aquí).
const ACCEPTED_AUDIENCES = ['com.rapiteam.app']

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
  let body: {
    identityToken?: string
    fullName?: string
    deviceInfo?: unknown
  }
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  const identityToken = body.identityToken?.trim()
  if (!identityToken || identityToken.length < 20) {
    return NextResponse.json({ success: false, error: 'missing_identity_token' }, { status: 400 })
  }

  let payload: {
    sub?: string
    email?: string
    email_verified?: boolean | string
    is_private_email?: boolean | string
  }
  try {
    const { payload: p } = await jwtVerify(identityToken, APPLE_JWKS, {
      issuer: APPLE_ISSUER,
      audience: ACCEPTED_AUDIENCES,
    })
    payload = p as typeof payload
  } catch (err) {
    console.warn('[apple/idtoken] verify failed:', err instanceof Error ? err.message : err)
    return NextResponse.json({ success: false, error: 'invalid_identity_token' }, { status: 401 })
  }

  if (!payload?.sub) {
    return NextResponse.json({ success: false, error: 'no_subject' }, { status: 401 })
  }

  const appleUid = payload.sub
  const email = payload.email?.toLowerCase() ?? null
  const emailVerified =
    payload.email_verified === true || payload.email_verified === 'true'
  const fullName = body.fullName?.trim() || null

  // Ronda 36/37 CRITICAL: matcheo por email SOLO si (a) Apple verificó,
  // (b) auth_provider EXPLÍCITAMENTE 'apple', (c) email_verified=true en DB,
  // (d) sin claim de otro provider. Ver comentario simétrico en google/idtoken.
  let user = await maybeOne<UserRow>(
    emailVerified && email
      ? `SELECT id, full_name, email, phone, user_type, profile_complete, is_active
           FROM users
           WHERE apple_uid = $1
              OR (email IS NOT NULL AND LOWER(email) = $2
                  AND email_verified = true
                  AND apple_uid IS NULL AND google_uid IS NULL
                  AND auth_provider = 'apple')
           LIMIT 1`
      : `SELECT id, full_name, email, phone, user_type, profile_complete, is_active
           FROM users
           WHERE apple_uid = $1
           LIMIT 1`,
    emailVerified && email ? [appleUid, email] : [appleUid],
  )
  let isNewUser = false

  if (!user) {
    isNewUser = true
    const newId = randomUUID()
    user = await maybeOne<UserRow>(
      `INSERT INTO users (id, apple_uid, email, email_verified, full_name,
                         auth_provider, user_type, is_active)
       VALUES ($1, $2, $3, $4, $5, 'apple', 'passenger', true)
       RETURNING id, full_name, email, phone, user_type, profile_complete, is_active`,
      [newId, appleUid, email, emailVerified, fullName],
    )
  } else {
    await query(
      `UPDATE users
         SET apple_uid = COALESCE(apple_uid, $2),
             email = COALESCE(email, $3),
             email_verified = COALESCE(email_verified, false) OR $4,
             full_name = COALESCE(full_name, $5),
             updated_at = now()
       WHERE id = $1`,
      [user.id, appleUid, email, emailVerified, fullName],
    )
  }

  if (!user!.is_active) {
    return NextResponse.json({ success: false, error: 'account_suspended' }, { status: 403 })
  }

  const session = await createSession(user!.id, (body.deviceInfo as Record<string, unknown>) ?? {})

  await query(
    `INSERT INTO auth_events (user_id, event_type, provider, ip_address, user_agent, metadata)
     VALUES ($1, 'login_apple', 'apple', $2, $3, $4)`,
    [
      user!.id,
      req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? null,
      req.headers.get('user-agent'),
      JSON.stringify({ isNewUser, email }),
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
