/**
 * GET  /api/admin/users?type=&search=&status=&page=&pageSize=
 *   → lista con filtros + paginación
 * POST /api/admin/users
 *   Body: { userType: 'passenger'|'driver'|'dual'|'admin', fullName, email?, phone?, ... }
 *   → crea usuario manualmente
 *
 * Solo admin.
 */
import { NextRequest, NextResponse } from 'next/server'
import { randomUUID } from 'crypto'
import { requireAdmin } from '@/lib/admin-middleware'
import { getClientIp } from '@/lib/auth-middleware'
import { query, maybeOne, isUniqueViolation } from '@/lib/db'

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

function isValidEmail(e: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e)
}
function isValidE164(p: string) {
  return /^\+[1-9][0-9]{9,14}$/.test(p)
}

// ============================================================================
// GET — Listar
// ============================================================================
export async function GET(req: NextRequest) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response

  const { searchParams } = new URL(req.url)
  const type = searchParams.get('type')
  const search = (searchParams.get('search') ?? '').trim()
  const status = searchParams.get('status')  // active | suspended | deleted | all
  // Ronda 30 Bug#1: NaN-safe pagination
  const pageRaw = Number(searchParams.get('page') ?? '1')
  const page = Number.isFinite(pageRaw) ? Math.max(1, pageRaw) : 1
  const pageSizeRaw = Number(searchParams.get('pageSize') ?? '20')
  const pageSize = Number.isFinite(pageSizeRaw) ? Math.min(100, Math.max(1, pageSizeRaw)) : 20
  const offset = (page - 1) * pageSize

  const where: string[] = []
  const params: unknown[] = []

  if (type && ALLOWED_TYPES.includes(type)) {
    params.push(type)
    where.push(`user_type = $${params.length}`)
  }
  if (status === 'active') {
    where.push('is_active = true AND deleted_at IS NULL AND suspended_at IS NULL')
  } else if (status === 'suspended') {
    where.push('suspended_at IS NOT NULL AND deleted_at IS NULL')
  } else if (status === 'deleted') {
    where.push('deleted_at IS NOT NULL')
  } else {
    // Default: excluir borrados
    where.push('deleted_at IS NULL')
  }
  if (search) {
    // Ronda 30 Bug#2: separar búsqueda por texto (lowercase) de búsqueda por
    // teléfono (dígitos). Sin esto, "999" matcheaba email 'abc999@x.com' vía
    // el LIKE contra `phone`. Detectamos "es teléfono" si tiene solo dígitos
    // opcionalmente con + inicial y ≥5 chars.
    const isPhoneLike = /^\+?\d{5,}$/.test(search)
    const searchLower = `%${search.toLowerCase()}%`
    if (isPhoneLike) {
      // Solo buscar en columnas phone (evita falsos positivos cruzados)
      params.push(`%${search}%`)
      where.push(`(phone LIKE $${params.length} OR phone_number LIKE $${params.length})`)
    } else {
      // Solo buscar en texto (nombre/email)
      params.push(searchLower)
      where.push(`(LOWER(full_name) LIKE $${params.length} OR LOWER(email) LIKE $${params.length})`)
    }
  }

  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : ''
  // Ronda 30 Bug#1: total con SELECT COUNT(*) separado + LIMIT parametrizado
  const totalRes = await query<{ total: string }>(
    `SELECT COUNT(*)::text AS total FROM users ${whereSql}`,
    params,
  )
  const total = Number(totalRes[0]?.total ?? 0)

  const pagedParams = [...params, pageSize, offset]
  const rows = await query<UserRow>(
    `SELECT *
       FROM users
       ${whereSql}
       ORDER BY created_at DESC
       LIMIT $${pagedParams.length - 1} OFFSET $${pagedParams.length}`,
    pagedParams,
  )
  return NextResponse.json({
    success: true,
    users: rows.map(serializeUser),
    page,
    pageSize,
    total,
    totalPages: Math.ceil(total / pageSize),
  })
}

// ============================================================================
// POST — Crear
// ============================================================================
export async function POST(req: NextRequest) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response

  let body: {
    userType?: string
    fullName?: string
    email?: string
    phone?: string
    isAdmin?: boolean
    profilePhotoUrl?: string
    profileComplete?: boolean
    isVerified?: boolean
  }
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  const userType = body.userType?.trim()
  if (!userType || !ALLOWED_TYPES.includes(userType)) {
    return NextResponse.json(
      { success: false, error: 'invalid_user_type', message: `Debe ser uno de: ${ALLOWED_TYPES.join(', ')}` },
      { status: 400 },
    )
  }
  const fullName = body.fullName?.trim() || null
  const email = body.email?.trim().toLowerCase() || null
  const phone = body.phone?.trim() || null

  if (!email && !phone) {
    return NextResponse.json(
      { success: false, error: 'missing_identity', message: 'Debes ingresar al menos email o teléfono' },
      { status: 400 },
    )
  }
  if (email && !isValidEmail(email)) {
    return NextResponse.json({ success: false, error: 'invalid_email' }, { status: 400 })
  }
  if (phone && !isValidE164(phone)) {
    return NextResponse.json(
      { success: false, error: 'invalid_phone', message: 'Formato E.164: +51999888777' },
      { status: 400 },
    )
  }

  const newId = randomUUID()
  const isAdmin = userType === 'admin' || body.isAdmin === true

  try {
    const user = await maybeOne<UserRow>(
      `INSERT INTO users
         (id, full_name, email, phone, phone_number, user_type,
          is_admin, is_active, is_verified, profile_complete, auth_provider,
          profile_photo_url)
       VALUES ($1, $2, $3, $4, $4, $5, $6, true, $7, $8, 'admin_manual', $9)
       RETURNING *`,
      [
        newId,
        fullName,
        email,
        phone,
        userType,
        isAdmin,
        body.isVerified ?? false,
        body.profileComplete ?? Boolean(fullName && (email || phone)),
        body.profilePhotoUrl ?? null,
      ],
    )

    // Auditoría
    await query(
      `INSERT INTO auth_events (user_id, event_type, provider, ip_address, user_agent, metadata)
       VALUES ($1, 'admin_create_user', 'admin', $2, $3, $4)`,
      [
        newId,
        getClientIp(req),
        req.headers.get('user-agent'),
        JSON.stringify({ createdBy: auth.userId, userType, email, phone }),
      ],
    )

    return NextResponse.json({ success: true, user: serializeUser(user!) }, { status: 201 })
  } catch (err) {
    if (isUniqueViolation(err)) {
      const msg = String((err as { detail?: string })?.detail ?? '').toLowerCase()
      const field = msg.includes('email') ? 'email' : msg.includes('phone') ? 'phone' : 'unknown'
      return NextResponse.json(
        {
          success: false,
          error: 'already_exists',
          field,
          message: field === 'email' ? 'Ya existe un usuario con ese email'
                : field === 'phone' ? 'Ya existe un usuario con ese teléfono'
                : 'Usuario duplicado',
        },
        { status: 409 },
      )
    }
    console.error('[admin/users POST] error:', err)
    return NextResponse.json({ success: false, error: 'internal_error' }, { status: 500 })
  }
}
