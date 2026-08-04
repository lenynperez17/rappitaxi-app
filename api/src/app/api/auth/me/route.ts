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
  is_admin: boolean
  is_verified: boolean
  profile_complete: boolean
  profile_photo_url: string | null
  auth_provider: string | null
  birth_date: Date | null
  identity_document: string | null
  current_mode: string | null
  rating: string | null
  total_ratings: number
  is_active: boolean
  created_at: Date
}

/**
 * Ronda 269: `driverStatus` derivado.
 *
 * El cliente lleva desde siempre un campo `driverStatus` (`user_model.dart:39`)
 * y el splash decide con él a qué pantalla enviar al conductor
 * (`modern_splash_screen.dart:313`, rama `'pending_approval'`). Pero el backend
 * NUNCA lo ha devuelto: no existe la columna ni el concepto. Como
 * `json['driverStatus']` era siempre `null`, esa rama jamás se cumplía y el
 * conductor con documentos en revisión terminaba en `/upgrade-to-driver`, es
 * decir, se le pedía darse de alta otra vez.
 *
 * No hace falta columna nueva: el estado ya está implícito en los datos que sí
 * existen. Se deriva de ellos para que cliente y servidor digan lo mismo.
 *
 *   approved         → el alta está completa (`users.is_verified`)
 *   pending_approval → subió documentos y aún no están todos aprobados
 *   null             → todavía no ha subido nada, no ha empezado el alta
 */
async function resolveDriverStatus(
  userId: string,
  user: { user_type: string; is_verified: boolean },
): Promise<string | null> {
  if (user.user_type !== 'driver' && user.user_type !== 'dual') return null
  if (user.is_verified) return 'approved'
  const docs = await maybeOne<{ total: string }>(
    'SELECT count(*)::text AS total FROM driver_documents WHERE driver_id = $1',
    [userId],
  )
  return Number(docs?.total ?? 0) > 0 ? 'pending_approval' : null
}

export async function GET(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  const user = await maybeOne<UserRow>(
    `SELECT id, full_name, display_name, email, email_verified, phone, phone_verified,
            user_type, is_admin, is_verified, profile_complete, profile_photo_url, auth_provider,
            birth_date, identity_document, current_mode,
            rating::text, total_ratings,
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

  const driverStatus = await resolveDriverStatus(auth.userId, user)

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
      // Ronda 271: sin `isAdmin` el panel web expulsaba a cualquier
      // administrador cuyo `user_type` no fuera literalmente 'admin'. Su guard
      // acepta `isAdmin || userType === 'admin'`, pero este endpoint nunca
      // enviaba el primero: al dueño, que tiene su cuenta como conductor para
      // probar la app, el panel lo sacaba al instante después de entrar bien.
      isAdmin: user.is_admin,
      isVerified: user.is_verified,
      // Ronda 245: el cliente lee currentMode para decidir a qué home
      // navegar (activeMode = currentMode ?? userType). Sin este campo,
      // un usuario dual siempre caía en /passenger/home.
      currentMode: user.current_mode,
      driverStatus,
      profileComplete: user.profile_complete,
      profilePhotoUrl: user.profile_photo_url,
      authProvider: user.auth_provider,
      birthDate: user.birth_date,
      identityDocument: user.identity_document,
      // Ronda 250: /me nunca devolvía el rating, y el cliente hace
      // `rating: json['rating'] ?? 5.0` — así que TODOS los usuarios
      // aparecían con 5.0 estrellas. Ahora va el promedio real; null
      // significa "sin calificaciones aún", no "cinco estrellas".
      rating: user.rating !== null ? Number(user.rating) : null,
      totalRatings: user.total_ratings ?? 0,
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
  // Ronda 245 BUG BLOQUEANTE: `currentMode` se validaba arriba pero JAMÁS se
  // agregaba al SET, y ni siquiera existía la columna. Efecto: switchMode()
  // devolvía éxito y navegaba a /driver/home, pero el modo no se persistía;
  // en el siguiente arranque en frío `currentMode` volvía null y
  // `activeMode = currentMode ?? userType` daba 'dual', que no matchea
  // 'driver' en el splash → TODO usuario dual aterrizaba en /passenger/home
  // sin importar el modo que había elegido.
  if (body.currentMode !== undefined) push('current_mode', body.currentMode)

  if (sets.length === 0) {
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
            user_type, is_admin, is_verified, profile_complete, profile_photo_url, auth_provider,
            birth_date, identity_document, current_mode,
            rating::text, total_ratings,
            is_active, created_at
       FROM users WHERE id = $1 LIMIT 1`,
    [auth.userId],
  )
  if (!updated) {
    return NextResponse.json({ success: false, error: 'user_not_found' }, { status: 404 })
  }

  const updatedDriverStatus = await resolveDriverStatus(auth.userId, updated)

  // Ronda 16 MEDIUM#6: incluir displayName/birthDate/identityDocument en el
  // response del PATCH — GET los devuelve, PATCH no lo hacía → el cliente
  // Flutter que rehidrataba desde este response veía los campos como null
  // inmediatamente después de guardarlos.
  //
  // Ronda 269: mismo problema, y esta vez con consecuencias de navegación.
  // Faltaban `currentMode`, `rating` y `totalRatings`. `switchMode()` del
  // cliente reconstruye el usuario con ESTE response y lo persiste en el
  // almacenamiento seguro (`auth_provider.dart:612`), así que al cambiar a
  // conductor se guardaba `currentMode: null` — y en el siguiente arranque en
  // frío `activeMode` valía `userType` en vez de `'driver'`, mandando al
  // conductor a la pantalla de pasajero. El rating, además, volvía a 5,0
  // porque el cliente hace `json['rating'] ?? 5.0`.
  //
  // Regla para quien toque esto: el PATCH debe devolver EXACTAMENTE los mismos
  // campos que el GET. Si divergen, el cliente cachea un usuario degradado.
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
      currentMode: updated.current_mode,
      driverStatus: updatedDriverStatus,
      profileComplete: updated.profile_complete,
      profilePhotoUrl: updated.profile_photo_url,
      authProvider: updated.auth_provider,
      birthDate: updated.birth_date,
      identityDocument: updated.identity_document,
      rating: updated.rating !== null ? Number(updated.rating) : null,
      totalRatings: updated.total_ratings ?? 0,
      createdAt: updated.created_at,
    },
  })
}
