/**
 * GET    /api/admin/users/:id     → detalle usuario
 * PATCH  /api/admin/users/:id     → edición parcial
 * DELETE /api/admin/users/:id     → soft delete + revoca sesiones
 *
 * Solo admin.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAdmin } from '@/lib/admin-middleware'
import { getClientIp } from '@/lib/auth-middleware'
import { query, maybeOne, tx, isUniqueViolation } from '@/lib/db'
import { deleteFile } from '@/lib/storage'

export const runtime = 'nodejs'

const ALLOWED_TYPES = ['passenger', 'driver', 'dual', 'admin']

interface UserRow {
  id: string
  full_name: string | null
  display_name: string | null
  email: string | null
  phone: string | null
  phone_number: string | null
  user_type: string
  is_admin: boolean
  is_active: boolean
  is_verified: boolean
  phone_verified: boolean
  email_verified: boolean
  profile_complete: boolean
  auth_provider: string | null
  profile_photo_url: string | null
  suspended_at: Date | null
  suspended_reason: string | null
  deleted_at: Date | null
  created_at: Date
  updated_at: Date
}

function serializeUser(u: UserRow) {
  return {
    id: u.id,
    fullName: u.full_name,
    displayName: u.display_name,
    email: u.email,
    phone: u.phone ?? u.phone_number,
    userType: u.user_type,
    isAdmin: u.is_admin,
    isActive: u.is_active,
    isVerified: u.is_verified,
    phoneVerified: u.phone_verified,
    emailVerified: u.email_verified,
    profileComplete: u.profile_complete,
    authProvider: u.auth_provider,
    profilePhotoUrl: u.profile_photo_url,
    suspendedAt: u.suspended_at,
    suspendedReason: u.suspended_reason,
    deletedAt: u.deleted_at,
    createdAt: u.created_at,
    updatedAt: u.updated_at,
  }
}

function isValidEmail(e: string) { return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e) }
function isValidE164(p: string) { return /^\+[1-9][0-9]{9,14}$/.test(p) }

// ============================================================================
// GET — Detalle
// ============================================================================
export async function GET(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response
  const { id } = await ctx.params

  const user = await maybeOne<UserRow>('SELECT * FROM users WHERE id = $1', [id])
  if (!user) return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
  return NextResponse.json({ success: true, user: serializeUser(user) })
}

// ============================================================================
// PATCH — Editar
// ============================================================================
export async function PATCH(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response
  const { id } = await ctx.params

  let body: {
    fullName?: string | null
    email?: string | null
    phone?: string | null
    userType?: string
    isAdmin?: boolean
    isVerified?: boolean
    profileComplete?: boolean
    profilePhotoUrl?: string | null
  }
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  // Validaciones
  if (body.email !== undefined && body.email !== null && !isValidEmail(body.email)) {
    return NextResponse.json({ success: false, error: 'invalid_email' }, { status: 400 })
  }
  if (body.phone !== undefined && body.phone !== null && !isValidE164(body.phone)) {
    return NextResponse.json({ success: false, error: 'invalid_phone' }, { status: 400 })
  }
  if (body.userType !== undefined && !ALLOWED_TYPES.includes(body.userType)) {
    return NextResponse.json({ success: false, error: 'invalid_user_type' }, { status: 400 })
  }
  // Un admin no puede quitarse a sí mismo el rol de admin (autobloqueo)
  if (body.isAdmin === false && id === auth.userId) {
    return NextResponse.json(
      { success: false, error: 'cannot_demote_self', message: 'No puedes quitarte a ti mismo el rol de admin.' },
      { status: 400 },
    )
  }

  const sets: string[] = []
  const params: unknown[] = []
  const addSet = (col: string, val: unknown) => {
    params.push(val)
    sets.push(`${col} = $${params.length}`)
  }

  if (body.fullName !== undefined) addSet('full_name', body.fullName)
  // B#12: cambiar email/phone via admin desmarca el flag verified para que
  // el usuario tenga que reconfirmar el nuevo dato. Sin esto, un admin
  // podía transferir un phone verificado a otro user sin OTP.
  if (body.email !== undefined) {
    addSet('email', body.email ? body.email.toLowerCase() : null)
    addSet('email_verified', false)
  }
  if (body.phone !== undefined) {
    addSet('phone', body.phone)
    addSet('phone_number', body.phone)
    addSet('phone_verified', false)
  }
  if (body.userType !== undefined) addSet('user_type', body.userType)
  if (body.isAdmin !== undefined) addSet('is_admin', body.isAdmin)
  if (body.isVerified !== undefined) addSet('is_verified', body.isVerified)
  if (body.profileComplete !== undefined) addSet('profile_complete', body.profileComplete)
  if (body.profilePhotoUrl !== undefined) addSet('profile_photo_url', body.profilePhotoUrl)

  if (sets.length === 0) {
    return NextResponse.json({ success: false, error: 'no_fields' }, { status: 400 })
  }

  params.push(id)
  try {
    const user = await maybeOne<UserRow>(
      `UPDATE users SET ${sets.join(', ')}, updated_at = now()
       WHERE id = $${params.length} AND deleted_at IS NULL
       RETURNING *`,
      params,
    )
    if (!user) return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })

    await query(
      `INSERT INTO auth_events (user_id, event_type, provider, ip_address, user_agent, metadata)
       VALUES ($1, 'admin_update_user', 'admin', $2, $3, $4)`,
      [id, getClientIp(req), req.headers.get('user-agent'), JSON.stringify({ updatedBy: auth.userId, changes: body })],
    )

    return NextResponse.json({ success: true, user: serializeUser(user) })
  } catch (err) {
    if (isUniqueViolation(err)) {
      return NextResponse.json({ success: false, error: 'already_exists' }, { status: 409 })
    }
    console.error('[admin/users PATCH] error:', err)
    return NextResponse.json({ success: false, error: 'internal_error' }, { status: 500 })
  }
}

// ============================================================================
// DELETE — Soft delete + revoca sesiones + limpia FCM/passkeys
// ============================================================================
export async function DELETE(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response
  const { id } = await ctx.params

  if (id === auth.userId) {
    return NextResponse.json(
      { success: false, error: 'cannot_delete_self', message: 'No puedes eliminar tu propia cuenta' },
      { status: 400 },
    )
  }

  try {
    const user = await maybeOne<UserRow>('SELECT * FROM users WHERE id = $1', [id])
    if (!user) return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
    if (user.deleted_at) {
      return NextResponse.json({ success: false, error: 'already_deleted' }, { status: 409 })
    }

    // Ronda 16 MEDIUM#4: borrar físicamente los archivos PII del user
    // (DNI frontal/reverso, antecedentes, licencia, SOAT). Sin esto, la
    // fila users queda anonimizada pero los archivos siguen en /var/www/
    // Rapi-Team-Storage/ + accesibles vía /api/media/[key] por cualquier
    // admin. GDPR / LPDP-Perú "derecho al olvido" no se cumpliría.
    const piiScopes = ['identity_front', 'identity_back', 'criminal_record', 'driver_license', 'soat']
    const piiFiles = await query<{ id: string; storage_key: string }>(
      `SELECT id, storage_key FROM storage_files WHERE user_id = $1 AND scope = ANY($2::text[])`,
      [id, piiScopes],
    )
    for (const f of piiFiles) {
      try { await deleteFile(f.storage_key) }
      catch (e) { console.warn(`[admin/users DELETE] no se pudo borrar ${f.storage_key}:`, e) }
    }

    await tx(async (client) => {
      // Purgar registro de storage_files (los archivos físicos ya se intentó
      // borrar arriba). Si algún deleteFile falló, el archivo huérfano queda
      // en disco pero al menos el índice deja de referenciarlo.
      if (piiFiles.length > 0) {
        await client.query(
          `DELETE FROM storage_files WHERE id = ANY($1::uuid[])`,
          [piiFiles.map((f) => f.id)],
        )
      }
      // Soft delete + anonimización PII para liberar email/phone únicos
      await client.query(
        `UPDATE users SET
           full_name = NULL,
           email = 'deleted-' || id || '@rapiteam.local',
           phone = NULL,
           phone_number = NULL,
           profile_photo_url = NULL,
           google_uid = NULL,
           apple_uid = NULL,
           is_active = false,
           deleted_at = now(),
           updated_at = now()
         WHERE id = $1`,
        [id],
      )
      await client.query('DELETE FROM fcm_tokens WHERE user_id = $1', [id])
      await client.query('DELETE FROM passkey_credentials WHERE user_id = $1', [id])
      await client.query('DELETE FROM sessions WHERE user_id = $1', [id])

      // Simetría con /suspend (auditor Ronda 16 HIGH#1): un DELETE debe cancelar
      // rides activos y liberar driver_presence — si no, la contraparte queda
      // enganchada con un ride "in_progress" cuyo conductor/pasajero ya no existe.
      const activeStates = ['requested', 'searching', 'accepted', 'on_way', 'arrived', 'in_progress']
      const cancelled = await client.query<{ id: string; driver_id: string | null }>(
        `UPDATE rides
            SET status = 'cancelled',
                cancelled_by = $1,
                cancelled_reason = 'user_deleted',
                completed_at = now()
          WHERE (passenger_id = $1 OR driver_id = $1)
            AND status = ANY($2::text[])
          RETURNING id, driver_id`,
        [id, activeStates],
      )
      const otherDriverIds = cancelled.rows.map((r) => r.driver_id).filter((d): d is string => d !== null && d !== id)
      if (otherDriverIds.length > 0) {
        await client.query(
          `UPDATE driver_presence SET active_ride_id = NULL, updated_at = now()
            WHERE driver_id = ANY($1::text[]) AND active_ride_id = ANY($2::uuid[])`,
          [otherDriverIds, cancelled.rows.map((r) => r.id)],
        )
      }
      await client.query(
        `UPDATE driver_presence SET is_online = false, active_ride_id = NULL, updated_at = now()
          WHERE driver_id = $1`,
        [id],
      )
      // Cancelar ofertas y negociaciones pending (no dejan huella en el driver
      // eliminado, pero pueden confundir al pasajero contraparte)
      await client.query(
        `UPDATE ride_offers SET status = 'cancelled', updated_at = now()
          WHERE driver_id = $1 AND status = 'pending'`,
        [id],
      )
      await client.query(
        `UPDATE ride_negotiations SET status = 'cancelled', updated_at = now()
          WHERE (offerer_id = $1 OR responder_id = $1) AND status = 'pending'`,
        [id],
      )
    })

    await query(
      `INSERT INTO auth_events (user_id, event_type, provider, ip_address, user_agent, metadata)
       VALUES ($1, 'admin_delete_user', 'admin', $2, $3, $4)`,
      [id, getClientIp(req), req.headers.get('user-agent'), JSON.stringify({ deletedBy: auth.userId })],
    )

    return NextResponse.json({ success: true, message: 'Usuario eliminado' })
  } catch (err) {
    console.error('[admin/users DELETE] error:', err)
    return NextResponse.json({ success: false, error: 'internal_error' }, { status: 500 })
  }
}
