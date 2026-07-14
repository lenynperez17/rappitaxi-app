/**
 * GET /api/auth/me
 * Auth: Bearer <access_token>
 *
 * Devuelve el perfil del usuario autenticado. La app lo llama al arrancar
 * para verificar que la sesión sigue vigente y obtener el perfil actualizado.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { maybeOne, query } from '@/lib/db'

export const runtime = 'nodejs'

interface UserRow {
  id: string
  full_name: string | null
  email: string | null
  email_verified: boolean
  phone: string | null
  phone_verified: boolean
  user_type: string
  profile_complete: boolean
  profile_photo_url: string | null
  auth_provider: string | null
  is_active: boolean
  created_at: Date
}

export async function GET(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  const user = await maybeOne<UserRow>(
    `SELECT id, full_name, email, email_verified, phone, phone_verified,
            user_type, profile_complete, profile_photo_url, auth_provider,
            is_active, created_at
       FROM users WHERE id = $1 LIMIT 1`,
    [auth.userId],
  )

  if (!user) {
    return NextResponse.json({ success: false, error: 'user_not_found' }, { status: 404 })
  }
  if (!user.is_active) {
    return NextResponse.json({ success: false, error: 'account_suspended' }, { status: 403 })
  }

  return NextResponse.json({
    success: true,
    user: {
      id: user.id,
      fullName: user.full_name,
      email: user.email,
      emailVerified: user.email_verified,
      phone: user.phone,
      phoneVerified: user.phone_verified,
      userType: user.user_type,
      profileComplete: user.profile_complete,
      profilePhotoUrl: user.profile_photo_url,
      authProvider: user.auth_provider,
      createdAt: user.created_at,
    },
  })
}

/**
 * PATCH /api/auth/me
 * Body: { fullName?, email?, phone?, profilePhotoUrl?, birthDate?, identityDocument?,
 *         currentMode? }
 *
 * Actualiza campos permitidos del perfil del user autenticado. Los cambios de
 * email y phone NO afectan flags de verificación — para revalidar hay que pasar
 * por el flujo de OTP correspondiente (endpoint separado).
 */
export async function PATCH(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  let body: {
    fullName?: string
    displayName?: string
    email?: string
    phone?: string
    profilePhotoUrl?: string
    birthDate?: string
    identityDocument?: string
    currentMode?: string
  } = {}
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  const allowedModes = new Set(['passenger', 'driver'])
  if (body.currentMode !== undefined && !allowedModes.has(body.currentMode)) {
    return NextResponse.json({ success: false, error: 'invalid_mode' }, { status: 400 })
  }

  const email = body.email?.trim().toLowerCase()
  if (email !== undefined && email !== '' && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return NextResponse.json({ success: false, error: 'invalid_email' }, { status: 400 })
  }

  // Construir SET dinámico con solo los campos enviados
  const sets: string[] = []
  const params: unknown[] = []
  let idx = 1
  const push = (col: string, val: unknown) => {
    sets.push(`${col} = $${idx++}`)
    params.push(val)
  }
  if (body.fullName !== undefined) push('full_name', body.fullName)
  // CRÍTICO: NUNCA aceptar email/phone via PATCH /auth/me — permitiría al
  // atacante impersonar la cuenta de otro usuario (SMS lookup por phone y
  // Google/Apple lookup por email caerían en su fila). Los cambios de email
  // y phone deben pasar por los flows verificados:
  //   - /api/auth/phone/verify (OTP SMS)
  //   - /api/auth/email/verify (aún no implementado; hasta entonces solo admin)
  // Se aceptan silenciosamente pero se ignoran para no romper clientes viejos.
  if (body.profilePhotoUrl !== undefined) push('profile_photo_url', body.profilePhotoUrl)
  // Campos que la app envía y ahora persisten (migración 018)
  if (body.displayName !== undefined) push('display_name', body.displayName)
  if (body.birthDate !== undefined) push('birth_date', body.birthDate)
  if (body.identityDocument !== undefined) push('identity_document', body.identityDocument)

  if (sets.length === 0 && body.currentMode === undefined) {
    return NextResponse.json({ success: false, error: 'no_fields' }, { status: 400 })
  }

  if (sets.length > 0) {
    sets.push(`updated_at = now()`)
    params.push(auth.userId)
    try {
      await query(
        `UPDATE users SET ${sets.join(', ')} WHERE id = $${idx} AND deleted_at IS NULL`,
        params,
      )
    } catch (e: unknown) {
      const err = e as { code?: string }
      if (err?.code === '23505') {
        return NextResponse.json({ success: false, error: 'email_or_phone_taken' }, { status: 409 })
      }
      throw e
    }
  }

  const updated = await maybeOne<UserRow>(
    `SELECT id, full_name, email, email_verified, phone, phone_verified,
            user_type, profile_complete, profile_photo_url, auth_provider,
            is_active, created_at
       FROM users WHERE id = $1 LIMIT 1`,
    [auth.userId],
  )
  if (!updated) {
    return NextResponse.json({ success: false, error: 'user_not_found' }, { status: 404 })
  }

  return NextResponse.json({
    success: true,
    user: {
      id: updated.id,
      fullName: updated.full_name,
      email: updated.email,
      emailVerified: updated.email_verified,
      phone: updated.phone,
      phoneVerified: updated.phone_verified,
      userType: updated.user_type,
      profileComplete: updated.profile_complete,
      profilePhotoUrl: updated.profile_photo_url,
      authProvider: updated.auth_provider,
      createdAt: updated.created_at,
    },
  })
}
