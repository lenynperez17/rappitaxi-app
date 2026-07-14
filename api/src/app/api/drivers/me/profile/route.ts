/**
 * /api/drivers/me/profile
 * Auth: Bearer <access_token> (driver o dual)
 *
 * GET   → devuelve el perfil completo del propio driver: datos de users +
 *         vehículo activo + documentos + rating promedio + estado de presencia.
 * PATCH → actualiza campos editables del perfil del driver.
 *         Body admite: fullName, displayName, phone, phoneNumber,
 *         profilePhotoUrl.
 *         (email/user_type NO se editan aquí — hay endpoints propios.)
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
  phone: string | null
  phone_number: string | null
  user_type: string
  is_admin: boolean
  is_active: boolean
  is_verified: boolean
  phone_verified: boolean
  email_verified: boolean
  profile_complete: boolean
  profile_photo_url: string | null
  created_at: Date
  updated_at: Date
}

interface VehicleRow {
  id: string
  vehicle_type: string
  plate: string
  make: string | null
  model: string | null
  color: string | null
  year: number | null
  is_active: boolean
  is_verified: boolean
  created_at: Date
  updated_at: Date
}

interface DocRow {
  id: string
  doc_type: string
  file_url: string
  status: string
  rejection_reason: string | null
  reviewed_at: Date | null
  expires_at: Date | null
  created_at: Date
  updated_at: Date
}

interface PresenceRow {
  is_online: boolean
  latitude: string | null
  longitude: string | null
  heading: string | null
  vehicle_type: string | null
  active_ride_id: string | null
  last_heartbeat: Date | null
  updated_at: Date
}

interface StatsRow {
  total_trips: string
  avg_rating: string | null
}

interface ProfileBody {
  fullName?: unknown
  displayName?: unknown
  phone?: unknown
  phoneNumber?: unknown
  profilePhotoUrl?: unknown
}

function normalizeString(v: unknown): string | null | undefined {
  if (v === undefined) return undefined
  if (v === null) return null
  if (typeof v !== 'string') return undefined
  const t = v.trim()
  return t === '' ? null : t
}

export async function GET(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response
  const driverId = auth.userId

  const user = await maybeOne<UserRow>(
    `SELECT id, full_name, display_name, email, phone, phone_number, user_type,
            is_admin, is_active, is_verified, phone_verified, email_verified,
            profile_complete, profile_photo_url, created_at, updated_at
       FROM users
      WHERE id = $1
        AND deleted_at IS NULL`,
    [driverId],
  )
  if (!user) {
    return NextResponse.json(
      { success: false, error: 'user_not_found' },
      { status: 404 },
    )
  }
  if (user.user_type !== 'driver' && user.user_type !== 'dual') {
    return NextResponse.json(
      { success: false, error: 'forbidden', message: 'Solo drivers' },
      { status: 403 },
    )
  }

  const vehicle = await maybeOne<VehicleRow>(
    `SELECT id, vehicle_type, plate, make, model, color, year, is_active,
            is_verified, created_at, updated_at
       FROM driver_vehicles
      WHERE driver_id = $1
      ORDER BY is_active DESC, updated_at DESC
      LIMIT 1`,
    [driverId],
  )

  const documents = await query<DocRow>(
    `SELECT id, doc_type, file_url, status, rejection_reason,
            reviewed_at, expires_at, created_at, updated_at
       FROM driver_documents
      WHERE driver_id = $1
      ORDER BY doc_type ASC`,
    [driverId],
  )

  const presence = await maybeOne<PresenceRow>(
    `SELECT is_online, latitude, longitude, heading, vehicle_type,
            active_ride_id, last_heartbeat, updated_at
       FROM driver_presence
      WHERE driver_id = $1`,
    [driverId],
  )

  const stats = await maybeOne<StatsRow>(
    `SELECT COUNT(*)::text AS total_trips,
            ROUND(AVG(driver_rating)::numeric, 2)::text AS avg_rating
       FROM rides
      WHERE driver_id = $1
        AND status = 'completed'`,
    [driverId],
  )

  return NextResponse.json({
    success: true,
    profile: {
      id: user.id,
      fullName: user.full_name,
      displayName: user.display_name,
      email: user.email,
      phone: user.phone,
      phoneNumber: user.phone_number,
      userType: user.user_type,
      isAdmin: user.is_admin,
      isActive: user.is_active,
      isVerified: user.is_verified,
      phoneVerified: user.phone_verified,
      emailVerified: user.email_verified,
      profileComplete: user.profile_complete,
      profilePhotoUrl: user.profile_photo_url,
      createdAt: user.created_at,
      updatedAt: user.updated_at,
    },
    vehicle: vehicle
      ? {
          id: vehicle.id,
          vehicleType: vehicle.vehicle_type,
          plate: vehicle.plate,
          make: vehicle.make,
          model: vehicle.model,
          color: vehicle.color,
          year: vehicle.year,
          isActive: vehicle.is_active,
          isVerified: vehicle.is_verified,
          createdAt: vehicle.created_at,
          updatedAt: vehicle.updated_at,
        }
      : null,
    documents: documents.map((d) => ({
      id: d.id,
      docType: d.doc_type,
      fileUrl: d.file_url,
      status: d.status,
      rejectionReason: d.rejection_reason,
      reviewedAt: d.reviewed_at,
      expiresAt: d.expires_at,
      createdAt: d.created_at,
      updatedAt: d.updated_at,
    })),
    presence: presence
      ? {
          isOnline: presence.is_online,
          latitude: presence.latitude !== null ? Number(presence.latitude) : null,
          longitude: presence.longitude !== null ? Number(presence.longitude) : null,
          heading: presence.heading !== null ? Number(presence.heading) : null,
          vehicleType: presence.vehicle_type,
          activeRideId: presence.active_ride_id,
          lastHeartbeat: presence.last_heartbeat,
          updatedAt: presence.updated_at,
        }
      : null,
    stats: {
      totalTrips: stats ? Number(stats.total_trips) : 0,
      avgRating: stats?.avg_rating ? Number(stats.avg_rating) : null,
    },
  })
}

export async function PATCH(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response
  const driverId = auth.userId

  let body: ProfileBody = {}
  try {
    body = (await req.json()) as ProfileBody
  } catch {
    return NextResponse.json(
      { success: false, error: 'bad_json' },
      { status: 400 },
    )
  }

  const user = await maybeOne<{ user_type: string }>(
    `SELECT user_type FROM users WHERE id = $1 AND deleted_at IS NULL`,
    [driverId],
  )
  if (!user) {
    return NextResponse.json(
      { success: false, error: 'user_not_found' },
      { status: 404 },
    )
  }
  if (user.user_type !== 'driver' && user.user_type !== 'dual') {
    return NextResponse.json(
      { success: false, error: 'forbidden', message: 'Solo drivers' },
      { status: 403 },
    )
  }

  const sets: string[] = []
  const params: unknown[] = []

  // CRÍTICO: NUNCA aceptar `phone`/`phoneNumber` via PATCH aquí — mismo
  // attack vector que PATCH /auth/me (setear phone ajeno → víctima entra
  // por SMS y cae en cuenta del attacker). Cambio de teléfono debe ir por
  // el flow verificado /api/auth/phone/verify con OTP.
  const fields: Array<[keyof ProfileBody, string]> = [
    ['fullName', 'full_name'],
    ['displayName', 'display_name'],
    ['profilePhotoUrl', 'profile_photo_url'],
  ]

  for (const [key, col] of fields) {
    const v = normalizeString(body[key])
    if (v === undefined) continue
    params.push(v)
    sets.push(`${col} = $${params.length}`)
  }

  if (sets.length === 0) {
    return NextResponse.json(
      { success: false, error: 'no_fields', message: 'Nada que actualizar' },
      { status: 400 },
    )
  }

  params.push(driverId)

  try {
    const updated = await maybeOne<UserRow>(
      `UPDATE users SET ${sets.join(', ')}
        WHERE id = $${params.length}
          AND deleted_at IS NULL
        RETURNING id, full_name, display_name, email, phone, phone_number,
                  user_type, is_admin, is_active, is_verified, phone_verified,
                  email_verified, profile_complete, profile_photo_url,
                  created_at, updated_at`,
      params,
    )
    if (!updated) {
      return NextResponse.json(
        { success: false, error: 'user_not_found' },
        { status: 404 },
      )
    }
    return NextResponse.json({
      success: true,
      profile: {
        id: updated.id,
        fullName: updated.full_name,
        displayName: updated.display_name,
        email: updated.email,
        phone: updated.phone,
        phoneNumber: updated.phone_number,
        userType: updated.user_type,
        isAdmin: updated.is_admin,
        isActive: updated.is_active,
        isVerified: updated.is_verified,
        phoneVerified: updated.phone_verified,
        emailVerified: updated.email_verified,
        profileComplete: updated.profile_complete,
        profilePhotoUrl: updated.profile_photo_url,
        createdAt: updated.created_at,
        updatedAt: updated.updated_at,
      },
    })
  } catch (err) {
    console.error('[drivers/me/profile PATCH] error:', err)
    return NextResponse.json(
      { success: false, error: 'server_error' },
      { status: 500 },
    )
  }
}
