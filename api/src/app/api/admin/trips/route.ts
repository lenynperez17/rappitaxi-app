/**
 * GET  /api/admin/trips?status=&passengerId=&driverId=&search=&fromDate=&toDate=
 * POST /api/admin/trips — crea un viaje manualmente desde el admin.
 */
import { randomUUID } from 'crypto'
import { NextRequest, NextResponse } from 'next/server'
import { requireAdmin } from '@/lib/admin-middleware'
import { getClientIp } from '@/lib/auth-middleware'
import { query, maybeOne, tx } from '@/lib/db'
import {
  findNearbyOnlineDrivers, notifyRideOffer, SIN_LIMITE_KM,
} from '@/lib/notify-drivers'
import { vehicleTypesCompatibleWith } from '@/lib/service-types'

export const runtime = 'nodejs'

const E164 = /^\+[1-9][0-9]{9,14}$/

interface RideRow {
  id: string
  passenger_id: string | null
  driver_id: string | null
  status: string
  pickup_address: string | null
  destination_address: string | null
  distance_meters: number | null
  duration_seconds: number | null
  estimated_fare: string | null
  final_fare: string | null
  payment_method: string | null
  vehicle_type: string | null
  passenger_rating: string | null
  driver_rating: string | null
  created_at: Date
  accepted_at: Date | null
  completed_at: Date | null
  cancelled_by: string | null
  cancelled_reason: string | null
  passenger_name: string | null
  passenger_phone: string | null
  driver_name: string | null
  driver_phone: string | null
  total: string
}

export async function GET(req: NextRequest) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response

  const { searchParams } = new URL(req.url)
  const status = searchParams.get('status')
  const passengerId = searchParams.get('passengerId')
  const driverId = searchParams.get('driverId')
  const search = (searchParams.get('search') ?? '').trim().toLowerCase()
  const fromDate = searchParams.get('fromDate')
  const toDate = searchParams.get('toDate')
  // Ronda 27 Bug#1: Number('abc')=NaN, Math.max(1, NaN)=NaN → LIMIT NaN
  // → Postgres syntax error → 500. Guardar con isFinite antes de propagar.
  const pageRaw = Number(searchParams.get('page') ?? '1')
  const page = Number.isFinite(pageRaw) ? Math.max(1, Math.floor(pageRaw)) : 1
  const pageSizeRaw = Number(searchParams.get('pageSize') ?? '50')
  const pageSize = Number.isFinite(pageSizeRaw) ? Math.min(200, Math.max(1, Math.floor(pageSizeRaw))) : 50
  const offset = (page - 1) * pageSize

  const where: string[] = []
  const params: unknown[] = []

  if (status) { params.push(status); where.push(`r.status = $${params.length}`) }
  if (passengerId) { params.push(passengerId); where.push(`r.passenger_id = $${params.length}`) }
  if (driverId) { params.push(driverId); where.push(`r.driver_id = $${params.length}`) }
  if (fromDate) { params.push(fromDate); where.push(`r.created_at >= $${params.length}::date`) }
  // Ronda 168: same off-by-one fix — toDate='YYYY-MM-DD' → TIMESTAMP 00:00:00
  // excluye viajes de todo el día final. Reports mensuales sub-cuentan.
  if (toDate) { params.push(toDate); where.push(`r.created_at < ($${params.length}::date + interval '1 day')`) }
  if (search) {
    params.push(`%${search}%`)
    where.push(`(LOWER(r.pickup_address) LIKE $${params.length} OR LOWER(r.destination_address) LIKE $${params.length})`)
  }

  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : ''
  const rows = await query<RideRow>(
    `SELECT r.*, p.full_name AS passenger_name, p.phone AS passenger_phone,
            d.full_name AS driver_name, d.phone AS driver_phone,
            COUNT(*) OVER() AS total
       FROM rides r
       LEFT JOIN users p ON p.id = r.passenger_id
       LEFT JOIN users d ON d.id = r.driver_id
       ${whereSql}
       ORDER BY r.created_at DESC
       LIMIT ${pageSize} OFFSET ${offset}`,
    params,
  )

  const total = rows.length ? Number(rows[0].total) : 0
  return NextResponse.json({
    success: true,
    trips: rows.map((r) => ({
      id: r.id,
      passengerId: r.passenger_id,
      driverId: r.driver_id,
      passengerName: r.passenger_name,
      passengerPhone: r.passenger_phone,
      driverName: r.driver_name,
      driverPhone: r.driver_phone,
      status: r.status,
      pickupAddress: r.pickup_address,
      destinationAddress: r.destination_address,
      distanceMeters: r.distance_meters,
      durationSeconds: r.duration_seconds,
      estimatedFare: r.estimated_fare ? Number(r.estimated_fare) : null,
      finalFare: r.final_fare ? Number(r.final_fare) : null,
      paymentMethod: r.payment_method,
      vehicleType: r.vehicle_type,
      passengerRating: r.passenger_rating ? Number(r.passenger_rating) : null,
      driverRating: r.driver_rating ? Number(r.driver_rating) : null,
      cancelledBy: r.cancelled_by,
      cancelledReason: r.cancelled_reason,
      createdAt: r.created_at,
      acceptedAt: r.accepted_at,
      completedAt: r.completed_at,
    })),
    page, pageSize, total, totalPages: Math.ceil(total / pageSize),
  })
}

/**
 * Ronda 271: cliente que llama por teléfono y no tiene la app.
 *
 * Hasta ahora el panel solo sabía crear viajes para alguien ya registrado, así
 * que la central no podía atender la llamada de un cliente nuevo: el operador
 * tenía que irse a Usuarios, darlo de alta a mano, volver al mapa y buscarlo.
 *
 * Se busca primero por teléfono y se reutiliza la ficha si ya existe. El
 * teléfono solo es único cuando está verificado, así que sin esta búsqueda un
 * cliente habitual acabaría con una ficha nueva por cada llamada y su historial
 * repartido entre todas.
 *
 * Devuelve también si la ficha se creó o se reutilizó, para poder decírselo al
 * operador en vez de dejarlo dudando de si acaba de duplicar a alguien.
 */
async function findOrCreateGuestPassenger(
  req: NextRequest,
  adminId: string,
  fullName: string,
  phone: string,
): Promise<{ id: string; created: boolean }> {
  const existing = await maybeOne<{ id: string; user_type: string }>(
    `SELECT id, user_type FROM users
      WHERE phone = $1 AND deleted_at IS NULL
      ORDER BY phone_verified DESC, created_at ASC
      LIMIT 1`,
    [phone],
  )
  if (existing) {
    // Un conductor puede pedir un viaje como pasajero, pero su ficha tiene que
    // pasar a 'dual' o el POST lo rechazaría por no ser pasajero.
    if (existing.user_type === 'driver') {
      await query(`UPDATE users SET user_type = 'dual', updated_at = now() WHERE id = $1`, [existing.id])
    }
    return { id: existing.id, created: false }
  }

  const id = randomUUID()
  await query(
    `INSERT INTO users
       (id, full_name, phone, phone_number, user_type, is_admin, is_active,
        is_verified, profile_complete, auth_provider, created_from)
     VALUES ($1, $2, $3, $3, 'passenger', false, true, false, true, 'admin_manual', 'admin_panel')`,
    [id, fullName, phone],
  )
  await query(
    `INSERT INTO auth_events (user_id, event_type, provider, ip_address, user_agent, metadata)
     VALUES ($1, 'admin_create_user', 'admin', $2, $3, $4)`,
    [
      id, getClientIp(req), req.headers.get('user-agent'),
      JSON.stringify({ createdBy: adminId, userType: 'passenger', phone, via: 'trip_guest' }),
    ],
  )
  return { id, created: true }
}

/**
 * POST /api/admin/trips — crea un viaje manualmente.
 * Body: {
 *   passengerId | guestPassenger: { fullName, phone },
 *   driverId?, pickupAddress, pickupLat, pickupLng,
 *   destinationAddress, destinationLat, destinationLng,
 *   estimatedFare?, vehicleType?, paymentMethod?, status?
 * }
 */
export async function POST(req: NextRequest) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response

  let body: {
    passengerId?: string
    guestPassenger?: { fullName?: string; phone?: string }
    driverId?: string | null
    pickupAddress?: string
    pickupLat?: number
    pickupLng?: number
    destinationAddress?: string
    destinationLat?: number
    destinationLng?: number
    estimatedFare?: number
    vehicleType?: string
    paymentMethod?: string
    status?: string
  } = {}
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  // El pasajero llega de una de dos formas: el id de alguien ya registrado, o
  // el nombre y teléfono de quien llamó por teléfono y no tiene la app.
  const guestName = body.guestPassenger?.fullName?.trim()
  const guestPhone = body.guestPassenger?.phone?.trim()
  const wantsGuest = Boolean(guestName || guestPhone)

  if (!body.passengerId && !wantsGuest) {
    return NextResponse.json({ success: false, error: 'passenger_id_required' }, { status: 400 })
  }
  if (wantsGuest) {
    if (!guestName) {
      return NextResponse.json(
        { success: false, error: 'guest_name_required', message: 'Escribe el nombre del cliente.' },
        { status: 400 },
      )
    }
    if (!guestPhone || !E164.test(guestPhone)) {
      return NextResponse.json(
        { success: false, error: 'guest_phone_invalid', message: 'Teléfono en formato +51999888777.' },
        { status: 400 },
      )
    }
  }
  if (!body.pickupAddress || !body.destinationAddress) {
    return NextResponse.json({ success: false, error: 'addresses_required' }, { status: 400 })
  }
  const inRange = (lat: number, lng: number) =>
    lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180
  if (typeof body.pickupLat !== 'number' || typeof body.pickupLng !== 'number'
      || !inRange(body.pickupLat, body.pickupLng)) {
    return NextResponse.json({ success: false, error: 'pickup_coords_invalid' }, { status: 400 })
  }
  if (typeof body.destinationLat !== 'number' || typeof body.destinationLng !== 'number'
      || !inRange(body.destinationLat, body.destinationLng)) {
    return NextResponse.json({ success: false, error: 'destination_coords_invalid' }, { status: 400 })
  }
  if (body.estimatedFare != null &&
      (typeof body.estimatedFare !== 'number' || body.estimatedFare <= 0 || body.estimatedFare > 10000)) {
    return NextResponse.json({ success: false, error: 'fare_invalid' }, { status: 400 })
  }

  // Enum canónico de vehicleType (alineado con /api/rides). Aceptamos aliases
  // legacy del panel viejo por compatibilidad.
  const VEHICLE_TYPE_ALIASES: Record<string, string> = {
    sedan: 'car', car: 'car',
    moto: 'moto', motorcycle: 'moto',
    mototaxi: 'moto_taxi', moto_taxi: 'moto_taxi',
    taxi: 'taxi',
    van: 'van',
    truck: 'truck', flete: 'truck',
    bicycle: 'bicycle',
  }
  const rawVehicleType = (body.vehicleType ?? 'car').toLowerCase()
  const canonicalVehicleType = VEHICLE_TYPE_ALIASES[rawVehicleType]
  if (!canonicalVehicleType) {
    return NextResponse.json({ success: false, error: 'invalid_vehicle_type' }, { status: 400 })
  }

  // Ronda 153: crear rides directamente en estado terminal
  // (completed/cancelled/no_drivers) dejaba al driver con active_ride_id
  // apuntando a un ride ya cerrado — no podía aceptar rides reales hasta
  // intervención manual + FCM push confuso "nueva oferta" para un ride
  // 'completed'. También faltaban campos requeridos (final_fare,
  // completed_at, cancelled_by, cancelled_reason). Los estados terminales
  // deben lograrse via los endpoints de transición (complete/cancel), no
  // via POST /admin/trips.
  const CREATE_ALLOWED = new Set([
    'requested', 'searching', 'accepted', 'on_way', 'arrived', 'in_progress',
  ])
  if (body.status && !CREATE_ALLOWED.has(body.status)) {
    return NextResponse.json(
      {
        success: false,
        error: 'invalid_status',
        message: `Solo estados iniciales al crear: ${Array.from(CREATE_ALLOWED).join(', ')}. Para cerrar, usar /rides/[id]/complete o /cancel.`,
      },
      { status: 400 },
    )
  }
  const status = body.status
    ? body.status
    : (body.driverId ? 'accepted' : 'requested')

  // El alta del cliente nuevo se hace aquí, después de validar todo lo demás:
  // si se hiciera antes, un viaje rechazado por unas coordenadas o una tarifa
  // mala dejaría igualmente una ficha suelta en Usuarios.
  let guestCreated = false
  let passengerId = body.passengerId
  if (!passengerId && wantsGuest) {
    try {
      const guest = await findOrCreateGuestPassenger(req, auth.userId, guestName!, guestPhone!)
      passengerId = guest.id
      guestCreated = guest.created
    } catch (err) {
      console.error('[admin/trips POST] alta de cliente falló:', err instanceof Error ? err.message : err)
      return NextResponse.json(
        { success: false, error: 'guest_create_failed', message: 'No se pudo registrar al cliente.' },
        { status: 500 },
      )
    }
  }

  // Verificar que el pasajero existe y no está eliminado
  const passenger = await maybeOne<{ id: string }>(
    `SELECT id FROM users WHERE id = $1 AND deleted_at IS NULL AND user_type IN ('passenger', 'dual')`,
    [passengerId],
  )
  if (!passenger) {
    return NextResponse.json({ success: false, error: 'passenger_not_found' }, { status: 404 })
  }

  // Verificar conductor si se pasó (mismo user no puede ser pasajero+conductor)
  if (body.driverId) {
    if (body.driverId === passengerId) {
      return NextResponse.json({ success: false, error: 'passenger_is_driver' }, { status: 400 })
    }
    const driver = await maybeOne<{ id: string }>(
      `SELECT id FROM users WHERE id = $1 AND deleted_at IS NULL AND user_type IN ('driver', 'dual')`,
      [body.driverId],
    )
    if (!driver) {
      return NextResponse.json({ success: false, error: 'driver_not_found' }, { status: 404 })
    }
  }

  // INSERT ride + UPDATE driver_presence en UNA transacción — garantiza
  // que si el driver ya tiene otro `active_ride_id`, todo el POST se
  // rechace (con 409) sin dejar el ride huérfano.
  let created: { id: string; created_at: Date }
  try {
    created = await tx(async (client) => {
      const insertRes = await client.query<{ id: string; created_at: Date }>(
        `INSERT INTO rides (
           passenger_id, driver_id, status,
           pickup_address, pickup_lat, pickup_lng,
           destination_address, destination_lat, destination_lng,
           estimated_fare, vehicle_type, payment_method,
           accepted_at, metadata
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
         RETURNING id, created_at`,
        [
          passengerId, body.driverId ?? null, status,
          body.pickupAddress, body.pickupLat, body.pickupLng,
          body.destinationAddress, body.destinationLat, body.destinationLng,
          body.estimatedFare ?? null, canonicalVehicleType,
          body.paymentMethod ?? 'cash',
          body.driverId ? new Date() : null,
          JSON.stringify({ createdBy: 'admin', adminId: auth.userId }),
        ],
      )
      const newRide = insertRes.rows[0]!
      if (body.driverId) {
        // Solo marcar activo si NO tiene otro ride activo. Si otro admin ya
        // asignó al driver, esto devuelve 0 filas y hacemos rollback (throw).
        const upd = await client.query(
          `UPDATE driver_presence
              SET active_ride_id = $1
            WHERE driver_id = $2
              AND (active_ride_id IS NULL OR active_ride_id = $1)`,
          [newRide.id, body.driverId],
        )
        if ((upd.rowCount ?? 0) === 0) {
          throw new Error('DRIVER_BUSY')
        }
      }
      return newRide
    })
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err)
    if (msg === 'DRIVER_BUSY') {
      return NextResponse.json(
        { success: false, error: 'driver_busy', message: 'El conductor ya tiene un viaje activo.' },
        { status: 409 },
      )
    }
    console.error('[admin/trips POST] insert failed:', msg)
    return NextResponse.json({ success: false, error: 'insert_failed' }, { status: 500 })
  }

  // Fanout: notificar a los conductores que corresponda.
  //   - Si el admin asignó un `driverId`: solo a ese conductor.
  //   - Si NO: broadcast a los conductores online en radio 5km del pickup.
  let notified = { notified: 0, fcmSent: 0 }
  try {
    const passenger = await maybeOne<{ full_name: string | null; phone: string | null }>(
      `SELECT full_name, phone FROM users WHERE id = $1`,
      [passengerId],
    )
    const targetDrivers = body.driverId
      ? [body.driverId]
      // Ronda 280: `findNearbyOnlineDrivers` pasó a recibir una LISTA de tipos
      // de vehículo aceptables, porque un servicio puede admitir varios (Express
      // lo atienden `car` y `taxi`). Aquí el viaje lo crea un administrador
      // indicando un tipo concreto, así que se envuelve en una lista de uno.
      // Ronda 284: SIN límite de distancia cuando el viaje lo crea la central.
      //
      // Con 5 km fijos, un viaje pedido por teléfono no le llegaba a nadie si
      // el único conductor conectado estaba más lejos — y quien atiende la
      // llamada lo que quiere es ofrecérselo a quien esté disponible, no a
      // quien esté cerca. La cercanía la decide el pasajero desde la app; aquí
      // decide una persona.
      : await findNearbyOnlineDrivers(
          body.pickupLat,
          body.pickupLng,
          SIN_LIMITE_KM,
          // Ronda 284: los vehículos que admite el SERVICIO, no el único tipo
          // que el panel escribe en el viaje.
          //
          // El panel guarda `vehicle_type = 'car'` por defecto, y con eso se
          // filtraba por 'car' a secas: un conductor con `taxi` registrado
          // quedaba fuera aunque Express admite los dos ({car,taxi}). En la
          // práctica, la mitad de la flota no recibía ningún viaje creado
          // desde el panel. Es la misma corrección que la ronda 280 hizo en
          // `/api/rides` y que aquí se quedó sin aplicar.
          await vehicleTypesCompatibleWith(canonicalVehicleType),
        )
    if (targetDrivers.length > 0) {
      notified = await notifyRideOffer(targetDrivers, {
        rideId: created.id,
        pickupAddress: body.pickupAddress,
        destinationAddress: body.destinationAddress,
        pickupLat: body.pickupLat,
        pickupLng: body.pickupLng,
        destinationLat: body.destinationLat,
        destinationLng: body.destinationLng,
        estimatedFare: body.estimatedFare ?? null,
        passengerName: passenger?.full_name ?? null,
        passengerPhone: passenger?.phone ?? null,
        vehicleType: canonicalVehicleType,
        // Ronda 285: este viaje nace en la central, y el conductor tiene que
        // verlo distinto de una solicitud normal de la app.
        isManualOrder: true,
        paymentMethod: body.paymentMethod ?? null,
      })
    }
  } catch (err) {
    console.warn('[admin/trips POST] fanout falló (best-effort):', err instanceof Error ? err.message : err)
  }

  return NextResponse.json({
    success: true,
    trip: { id: created.id, status, createdAt: created.created_at },
    fanout: notified,
    // `passenger.created` distingue "se dio de alta ahora" de "ya era cliente":
    // el panel lo dice en el aviso para que el operador sepa si acaba de crear
    // una ficha o si reconoció a un habitual por su teléfono.
    passenger: { id: passengerId, created: guestCreated },
  }, { status: 201 })
}
