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
  display_name: string | null
  email: string | null
  email_verified: boolean
  phone: string | null
  phone_verified: boolean
  user_type: string
  is_verified: boolean
  profile_complete: boolean
  profile_photo_url: string | null
  auth_provider: string | null
  birth_date: Date | null
  identity_document: string | null
  is_active: boolean
  created_at: Date
}

export async function GET(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  const user = await maybeOne<UserRow>(
    `SELECT id, full_name, display_name, email, email_verified, phone, phone_verified,
            user_type, is_verified, profile_complete, profile_photo_url, auth_provider,
            birth_date, identity_document,
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
      displayName: user.display_name,
      email: user.email,
      emailVerified: user.email_verified,
      phone: user.phone,
      phoneVerified: user.phone_verified,
      userType: user.user_type,
      isVerified: user.is_verified,
      profileComplete: user.profile_complete,
      profilePhotoUrl: user.profile_photo_url,
      authProvider: user.auth_provider,
      birthDate: user.birth_date,
      identityDocument: user.identity_document,
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

  // Ronda 151: validar campos user-editable antes de tocar la DB.
  //  - fullName ≤ 200 chars (schema típico VARCHAR(255)) evita overflow 22001
  //  - birthDate: ISO date YYYY-MM-DD, año entre 1900 y hoy
  //  - identityDocument: 8-15 chars alfanuméricos (DNI/CE/PAS peruanos)
  if (body.fullName !== undefined && typeof body.fullName === 'string') {
    const trimmed = body.fullName.trim()
    if (trimmed.length === 0 || trimmed.length > 200) {
      return NextResponse.json(
        { success: false, error: 'invalid_full_name', message: 'fullName debe tener 1-200 caracteres' },
        { status: 400 },
      )
    }
  }
  if (body.birthDate !== undefined && body.birthDate !== null) {
    if (typeof body.birthDate !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(body.birthDate)) {
      return NextResponse.json(
        { success: false, error: 'invalid_birth_date', message: 'birthDate debe ser YYYY-MM-DD' },
        { status: 400 },
      )
    }
    const d = new Date(body.birthDate)
    const year = d.getFullYear()
    if (Number.isNaN(d.getTime()) || year < 1900 || d > new Date()) {
      return NextResponse.json(
        { success: false, error: 'invalid_birth_date', message: 'birthDate fuera de rango' },
        { status: 400 },
      )
    }
  }
  if (body.identityDocument !== undefined && body.identityDocument !== null && body.identityDocument !== '') {
    if (typeof body.identityDocument !== 'string' || !/^[A-Za-z0-9]{6,15}$/.test(body.identityDocument.trim())) {
      return NextResponse.json(
        { success: false, error: 'invalid_identity_document', message: 'DNI/CE/Pasaporte inválido' },
        { status: 400 },
      )
    }
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
    `SELECT id, full_name, display_name, email, email_verified, phone, phone_verified,
            user_type, is_verified, profile_complete, profile_photo_url, auth_provider,
            birth_date, identity_document,
            is_active, created_at
       FROM users WHERE id = $1 LIMIT 1`,
    [auth.userId],
  )
  if (!updated) {
    return NextResponse.json({ success: false, error: 'user_not_found' }, { status: 404 })
  }

  // Ronda 16 MEDIUM#6: incluir displayName/birthDate/identityDocument en el
  // response del PATCH — GET los devuelve, PATCH no lo hacía → el cliente
  // Flutter que rehidrataba desde este response veía los campos como null
  // inmediatamente después de guardarlos.
  return NextResponse.json({
    success: true,
    user: {
      id: updated.id,
      fullName: updated.full_name,
      displayName: updated.display_name,
      email: updated.email,
      emailVerified: updated.email_verified,
      phone: updated.phone,
      phoneVerified: updated.phone_verified,
      userType: updated.user_type,
      isVerified: updated.is_verified,
      profileComplete: updated.profile_complete,
      profilePhotoUrl: updated.profile_photo_url,
      authProvider: updated.auth_provider,
      birthDate: updated.birth_date,
      identityDocument: updated.identity_document,
      createdAt: updated.created_at,
    },
  })
}
