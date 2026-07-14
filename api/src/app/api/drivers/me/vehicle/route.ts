/**
 * /api/drivers/me/vehicle
 * Auth: Bearer <access_token> (driver o dual)
 *
 * GET → devuelve el vehículo activo del driver actual (o null si no tiene).
 * PUT → crea o actualiza el vehículo del driver.
 *       Body: { vehicleType, plate, make?, model?, color?, year? }
 *       En el schema (`driver_vehicles`) existe UNIQUE(driver_id, plate).
 *       Convención de este endpoint: cada driver tiene UN solo vehículo activo,
 *       así que si ya tenía uno lo actualizamos (aunque cambie la plate).
 *       Cambiar la plate resetea `is_verified` a false, ya que el vehículo
 *       nuevo debe ser reverificado por admin. Registra notification al driver
 *       cuando se cambia.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { maybeOne, tx, isUniqueViolation } from '@/lib/db'

export const runtime = 'nodejs'

const ALLOWED_VEHICLE_TYPES = new Set([
  'taxi',
  'moto',
  'moto_taxi',
  'car',
  'van',
  'truck',
  'bicycle',
])

interface VehicleRow {
  id: string
  driver_id: string
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

interface VehicleBody {
  vehicleType?: unknown
  plate?: unknown
  make?: unknown
  model?: unknown
  color?: unknown
  year?: unknown
}

function serialize(v: VehicleRow) {
  return {
    id: v.id,
    driverId: v.driver_id,
    vehicleType: v.vehicle_type,
    plate: v.plate,
    make: v.make,
    model: v.model,
    color: v.color,
    year: v.year,
    isActive: v.is_active,
    isVerified: v.is_verified,
    createdAt: v.created_at,
    updatedAt: v.updated_at,
  }
}

function optionalString(v: unknown): string | null {
  if (v === undefined || v === null) return null
  if (typeof v !== 'string') return null
  const t = v.trim()
  return t === '' ? null : t
}

export async function GET(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response
  const driverId = auth.userId

  const vehicle = await maybeOne<VehicleRow>(
    `SELECT id, driver_id, vehicle_type, plate, make, model, color, year,
            is_active, is_verified, created_at, updated_at
       FROM driver_vehicles
      WHERE driver_id = $1
      ORDER BY is_active DESC, updated_at DESC
      LIMIT 1`,
    [driverId],
  )

  return NextResponse.json({
    success: true,
    vehicle: vehicle ? serialize(vehicle) : null,
  })
}

export async function PUT(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response
  const driverId = auth.userId

  let body: VehicleBody = {}
  try {
    body = (await req.json()) as VehicleBody
  } catch {
    return NextResponse.json(
      { success: false, error: 'bad_json' },
      { status: 400 },
    )
  }

  const user = await maybeOne<{ user_type: string }>(
    'SELECT user_type FROM users WHERE id = $1 AND deleted_at IS NULL',
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

  const vehicleType =
    typeof body.vehicleType === 'string' ? body.vehicleType.trim() : ''
  const plate =
    typeof body.plate === 'string'
      ? body.plate.trim().toUpperCase()
      : ''

  if (!vehicleType || !ALLOWED_VEHICLE_TYPES.has(vehicleType)) {
    return NextResponse.json(
      { success: false, error: 'invalid_input', message: 'vehicleType inválido' },
      { status: 400 },
    )
  }
  if (!plate) {
    return NextResponse.json(
      { success: false, error: 'invalid_input', message: 'plate requerido' },
      { status: 400 },
    )
  }

  const make = optionalString(body.make)
  const model = optionalString(body.model)
  const color = optionalString(body.color)

  let year: number | null = null
  if (body.year !== undefined && body.year !== null && body.year !== '') {
    const y = Number(body.year)
    const currentYear = new Date().getFullYear()
    if (!Number.isInteger(y) || y < 1950 || y > currentYear + 1) {
      return NextResponse.json(
        { success: false, error: 'invalid_year' },
        { status: 400 },
      )
    }
    year = y
  }

  try {
    const result = await tx(async (client) => {
      // ¿Ya tiene vehículo? Convención: un solo vehículo activo por driver.
      const existingRes = await client.query<VehicleRow>(
        `SELECT id, driver_id, vehicle_type, plate, make, model, color, year,
                is_active, is_verified, created_at, updated_at
           FROM driver_vehicles
          WHERE driver_id = $1
          ORDER BY is_active DESC, updated_at DESC
          LIMIT 1`,
        [driverId],
      )
      const existing = existingRes.rows[0]

      if (existing) {
        // Si cambió la plate se debe re-verificar.
        const plateChanged = existing.plate !== plate
        const upd = await client.query<VehicleRow>(
          `UPDATE driver_vehicles
              SET vehicle_type = $1,
                  plate = $2,
                  make = $3,
                  model = $4,
                  color = $5,
                  year = $6,
                  is_active = true,
                  is_verified = CASE WHEN $7::boolean THEN false ELSE is_verified END,
                  updated_at = now()
            WHERE id = $8
            RETURNING id, driver_id, vehicle_type, plate, make, model, color,
                      year, is_active, is_verified, created_at, updated_at`,
          [vehicleType, plate, make, model, color, year, plateChanged, existing.id],
        )
        return { row: upd.rows[0]!, created: false, plateChanged }
      }

      const ins = await client.query<VehicleRow>(
        `INSERT INTO driver_vehicles
           (driver_id, vehicle_type, plate, make, model, color, year, is_active, is_verified)
         VALUES ($1, $2, $3, $4, $5, $6, $7, true, false)
         RETURNING id, driver_id, vehicle_type, plate, make, model, color, year,
                   is_active, is_verified, created_at, updated_at`,
        [driverId, vehicleType, plate, make, model, color, year],
      )
      return { row: ins.rows[0]!, created: true, plateChanged: false }
    })

    // Notificación in-app para el driver
    await tx(async (client) => {
      await client.query(
        `INSERT INTO notifications (user_id, type, title, body, data)
         VALUES ($1, $2, $3, $4, $5::jsonb)`,
        [
          driverId,
          'vehicle_updated',
          result.created ? 'Vehículo registrado' : 'Vehículo actualizado',
          result.created
            ? 'Tu vehículo fue registrado. Espera la verificación del equipo.'
            : result.plateChanged
              ? 'Cambiaste la placa; tu vehículo debe ser reverificado.'
              : 'Datos de tu vehículo actualizados.',
          JSON.stringify({ vehicleId: result.row.id, plate: result.row.plate }),
        ],
      )
    })

    return NextResponse.json({
      success: true,
      created: result.created,
      vehicle: serialize(result.row),
    })
  } catch (err) {
    if (isUniqueViolation(err)) {
      return NextResponse.json(
        {
          success: false,
          error: 'plate_conflict',
          message: 'Esa placa ya está registrada para otro vehículo',
        },
        { status: 409 },
      )
    }
    console.error('[drivers/me/vehicle PUT] error:', err)
    return NextResponse.json(
      { success: false, error: 'server_error' },
      { status: 500 },
    )
  }
}
