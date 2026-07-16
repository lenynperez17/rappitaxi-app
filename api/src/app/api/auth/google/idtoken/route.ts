/**
 * POST /api/auth/google/idtoken
 * Body: { idToken, deviceInfo? }
 *
 * Verifica el ID token de Google Sign-In (mobile) contra los OAuth Client IDs
 * del proyecto rapi-team. Upsert user en Postgres. Emite JWT session + opcional
 * Firebase Custom Token.
 */
import { NextRequest, NextResponse } from 'next/server'
import { randomUUID } from 'crypto'
import { OAuth2Client, TokenPayload } from 'google-auth-library'
import { query, maybeOne } from '@/lib/db'
import { createSession } from '@/lib/sessions'
import { ACCESS_TTL_SECONDS, REFRESH_TTL_SECONDS } from '@/lib/jwt'
import { getClientIp } from '@/lib/auth-middleware'

export const runtime = 'nodejs'

// Audiences aceptados: TODOS los Client IDs del proyecto rapi-team (Android, iOS, Web)
// Extraídos de google-services.json + GoogleService-Info.plist
const ACCEPTED_AUDIENCES = [
  '52925359166-769u3ht2os6gguvrsuhsv6qopbhcgtvr.apps.googleusercontent.com',
  '52925359166-a3csdu44dpoj7a2ag4migbv240t8bc8s.apps.googleusercontent.com',
  '52925359166-bcq342paiellpmm8abis65nhap1qf42v.apps.googleusercontent.com',
  '52925359166-htlsmms5opfgpmi4j7gv9ghovhnu56ti.apps.googleusercontent.com',
  '52925359166-ksndlq97t4lbi0dd1bmeu67697eou1dg.apps.googleusercontent.com',
  '52925359166-r1vvt5mtgtdnaiio6akqmt3rrorpc41m.apps.googleusercontent.com',
  '52925359166-tlfbqf1hoi62o07ghu52v3giidgvr2e8.apps.googleusercontent.com',
  '52925359166-vfti1lgqr3027ptjbl15ors0hh7kp1oo.apps.googleusercontent.com',
]

const client = new OAuth2Client()

interface UserRow {
  id: string
  full_name: string | null
  email: string | null
  phone: string | null
  user_type: string
  profile_complete: boolean
  is_active: boolean
  profile_photo_url: string | null
}

export async function POST(req: NextRequest) {
  let body: { idToken?: string; deviceInfo?: unknown }
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  const idToken = body.idToken?.trim()
  if (!idToken || idToken.length < 20) {
    return NextResponse.json({ success: false, error: 'missing_id_token' }, { status: 400 })
  }

  let payload: TokenPayload | undefined
  try {
    const ticket = await client.verifyIdToken({ idToken, audience: ACCEPTED_AUDIENCES })
    payload = ticket.getPayload()
  } catch (err) {
    console.warn('[google/idtoken] verify failed:', err instanceof Error ? err.message : err)
    return NextResponse.json({ success: false, error: 'invalid_id_token' }, { status: 401 })
  }

  if (!payload?.sub) {
    return NextResponse.json({ success: false, error: 'no_subject' }, { status: 401 })
  }

  const googleUid = payload.sub
  const email = payload.email?.toLowerCase() ?? null
  const emailVerified = payload.email_verified ?? false
  const fullName = payload.name ?? null
  const picture = payload.picture ?? null

  // Ronda 36/37 CRITICAL: cross-provider account takeover.
  // Match por email SOLO cuando TODAS aplican:
  //   (a) Google verificó el email (emailVerified true del token)
  //   (b) La fila existente tiene auth_provider EXPLÍCITAMENTE 'google'
  //       (no NULL — legacy/admin-created son vulnerables si dejamos el OR)
  //   (c) La fila existente tiene email_verified=true en DB (rows sin verify
  //       fueron creadas por invitación/import y no deben tomarse por email)
  //   (d) NO tiene otro provider claim (google_uid+apple_uid NULL)
  // El login por google_uid=$1 sigue funcionando en cualquier caso.
  // Ronda 159 SECURITY: filtrar deleted_at. Sin esto, un user borrado
  // (anonimizado por /account/delete) mantenía is_active=false pero el
  // UPDATE de línea "COALESCE(google_uid, $2)" abajo re-escribía el
  // google_uid válido en su fila → "reviviendo" el user borrado desde el
  // punto de vista de auth_provider linking. El chequeo is_active corta el
  // login, pero el side-effect de restaurar PII es indeseado post-delete.
  let user = await maybeOne<UserRow>(
    emailVerified && email
      ? `SELECT id, full_name, email, phone, user_type, profile_complete, is_active, profile_photo_url
           FROM users
           WHERE deleted_at IS NULL
             AND (google_uid = $1
                OR (email IS NOT NULL AND LOWER(email) = $2
                    AND email_verified = true
                    AND google_uid IS NULL AND apple_uid IS NULL
                    AND auth_provider = 'google'))
           LIMIT 1`
      : `SELECT id, full_name, email, phone, user_type, profile_complete, is_active, profile_photo_url
           FROM users
           WHERE google_uid = $1 AND deleted_at IS NULL
           LIMIT 1`,
    emailVerified && email ? [googleUid, email] : [googleUid],
  )
  let isNewUser = false

  if (!user) {
    isNewUser = true
    const newId = randomUUID()
    user = await maybeOne<UserRow>(
      `INSERT INTO users (id, google_uid, email, email_verified, full_name, profile_photo_url,
                         auth_provider, user_type, is_active)
       VALUES ($1, $2, $3, $4, $5, $6, 'google', 'passenger', true)
       RETURNING id, full_name, email, phone, user_type, profile_complete, is_active, profile_photo_url`,
      [newId, googleUid, email, emailVerified, fullName, picture],
    )
  } else {
    // Ronda 160 SECURITY: mover el check is_active ANTES del UPDATE.
    // Antes: UPDATE soldaba google_uid = $2 en una fila suspendida →
    // cuando admin des-suspendía, el llamante entraba por fast path
    // (google_uid = $1) sin re-verificación por email. Ahora los users
    // suspendidos NUNCA reciben write al google_uid — mantienen su estado
    // congelado hasta reactivación explícita.
    if (!user.is_active) {
      return NextResponse.json({ success: false, error: 'account_suspended' }, { status: 403 })
    }
    await query(
      `UPDATE users
         SET google_uid = COALESCE(google_uid, $2),
             email = COALESCE(email, $3),
             email_verified = COALESCE(email_verified, false) OR $4,
             full_name = COALESCE(full_name, $5),
             profile_photo_url = COALESCE(profile_photo_url, $6),
             updated_at = now()
       WHERE id = $1 AND is_active = true AND deleted_at IS NULL`,
      [user.id, googleUid, email, emailVerified, fullName, picture],
    )
  }

  if (!user!.is_active) {
    return NextResponse.json({ success: false, error: 'account_suspended' }, { status: 403 })
  }

  const session = await createSession(user!.id, (body.deviceInfo as Record<string, unknown>) ?? {})

  await query(
    `INSERT INTO auth_events (user_id, event_type, provider, ip_address, user_agent, metadata)
     VALUES ($1, 'login_google', 'google', $2, $3, $4)`,
    [
      user!.id,
      getClientIp(req),
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
      profilePhotoUrl: user!.profile_photo_url,
      userType: user!.user_type,
      profileComplete: user!.profile_complete,
    },
    jwt: session.accessToken,
    refreshToken: session.refreshToken,
    accessTtlSec: ACCESS_TTL_SECONDS,
    refreshTtlSec: REFRESH_TTL_SECONDS,
  })
}
