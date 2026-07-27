/**
 * GET /api/events/stream
 * -----------------------------------------------------------------------------
 * Server-Sent Events (SSE) — canal en tiempo real hacia la app.
 *
 * Auth: query param `?ticket=<uuid>` — ticket de un solo uso obtenido en
 * `POST /api/events/ticket` (Bearer JWT). El ticket vive 60 s, se marca como
 * `consumed_at` en el primer uso, y así el JWT NUNCA viaja en la URL del
 * stream (evita que quede en logs de nginx, headers Referer, ni en el historial
 * del navegador). El JWT sigue viajando solo por Authorization header al pedir
 * el ticket.
 *
 * Eventos emitidos:
 *   - :ping                                (comentario SSE — keepalive cada 20s)
 *   - event: notification    data: {...}   (nueva fila en `notifications`)
 *   - event: ride_update     data: {...}   (cambio de estado en un ride del user)
 *   - event: new_message     data: {...}   (nuevo mensaje en un ride del user,
 *                                            enviado por otro user)
 *   - event: driver_location data: {...}   (nueva posición del driver de un
 *                                            ride activo del pasajero)
 *
 * Implementación:
 * Como todavía no hay Redis / LISTEN/NOTIFY, el stream hace polling interno
 * cada 2 segundos con 4 queries pequeñas usando cursores por evento
 * (last*At) que se actualizan al máximo timestamp devuelto en cada tick.
 *
 * El stream se cierra limpiamente cuando el cliente aborta la request.
 */
import { NextRequest } from 'next/server'
import { query, maybeOne } from '@/lib/db'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

// --------------------------------------------------------------------------
// Tipos de filas devueltas por las queries
// --------------------------------------------------------------------------
interface NotificationRow {
  id: string
  user_id: string
  type: string
  title: string
  body: string | null
  data: unknown
  read_at: Date | null
  created_at: Date
}

interface RideUpdateRow {
  id: string
  passenger_id: string | null
  driver_id: string | null
  status: string
  pickup_address: string | null
  pickup_lat: string | null
  pickup_lng: string | null
  destination_address: string | null
  destination_lat: string | null
  destination_lng: string | null
  estimated_fare: string | null
  final_fare: string | null
  payment_method: string | null
  vehicle_type: string | null
  cancelled_by: string | null
  cancelled_reason: string | null
  updated_at: Date
  created_at: Date
  accepted_at: Date | null
  arrived_at: Date | null
  started_at: Date | null
  completed_at: Date | null
}

interface RideMessageRow {
  sender_name?: string | null
  sender_photo?: string | null
  id: string
  ride_id: string
  sender_id: string | null
  body: string | null
  attachment_url: string | null
  created_at: Date
}

interface DriverLocationRow {
  driver_id: string
  ride_id: string
  latitude: string | null
  longitude: string | null
  heading: string | null
  speed_kmh: string | null
  accuracy_meters: string | null
  updated_at: Date
}

// --------------------------------------------------------------------------
// Constantes de configuración del stream
// --------------------------------------------------------------------------
const POLL_INTERVAL_MS = 2_000
const PING_INTERVAL_MS = 20_000

// Estados de ride considerados "activos" para el pasajero → interesan para
// notificar cambios de estado y ubicación del driver.
const ACTIVE_RIDE_STATUSES = [
  // Ronda 245: 'requested' y 'searching' faltaban. Justo esos son los estados
  // en los que el pasajero está ESPERANDO OFERTAS — al excluirlos, mientras
  // el ride estaba en 'requested' no se emitía ningún ride_update, así que
  // el pasajero nunca se enteraba de que un conductor le había ofertado
  // ("le mandé la oferta y no le llega"). Sin polling en esa pantalla, la
  // única vía era cerrar y reabrir.
  'requested',
  'searching',
  'accepted',
  'on_way',
  'arrived',
  'in_progress',
  'completed',
  'cancelled',
] as const

const DRIVER_TRACKABLE_STATUSES = [
  'accepted',
  'on_way',
  'arrived',
  'in_progress',
] as const

// --------------------------------------------------------------------------
// Helpers SSE
// --------------------------------------------------------------------------
const encoder = new TextEncoder()

/** Codifica un evento SSE con `event:` + `data:` como bytes UTF-8. */
function sseEvent(event: string, data: unknown): Uint8Array {
  const payload = typeof data === 'string' ? data : JSON.stringify(data)
  // Cada línea del payload prefijada con `data: ` (por si tuviera `\n`).
  const lines = payload.split('\n').map((l) => `data: ${l}`).join('\n')
  return encoder.encode(`event: ${event}\n${lines}\n\n`)
}

/** Ping SSE (comentario) — mantiene la conexión viva a través de proxies. */
function ssePing(): Uint8Array {
  return encoder.encode(`:ping ${Date.now()}\n\n`)
}

/** Devuelve el max Date de un array de filas leyendo la key indicada. */
function maxDate<T>(rows: T[], key: keyof T, fallback: Date): Date {
  let out = fallback
  for (const r of rows) {
    const v = r[key] as unknown as Date | string | null
    if (!v) continue
    const d = v instanceof Date ? v : new Date(v)
    if (d.getTime() > out.getTime()) out = d
  }
  return out
}

// --------------------------------------------------------------------------
// Handler
// --------------------------------------------------------------------------
export async function GET(req: NextRequest) {
  // 1) Auth por ticket (?ticket=<uuid>) — un solo uso, TTL 60 s.
  const ticket = req.nextUrl.searchParams.get('ticket') ?? ''
  const TICKET_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
  if (!ticket || !TICKET_RE.test(ticket)) {
    return new Response(
      JSON.stringify({ success: false, error: 'missing_ticket' }),
      { status: 401, headers: { 'Content-Type': 'application/json' } },
    )
  }
  // Consumir atómicamente: UPDATE ... WHERE ticket=$1 AND consumed_at IS NULL
  //   AND expires_at > now() RETURNING user_id
  const consumed = await maybeOne<{ user_id: string }>(
    `UPDATE sse_tickets
        SET consumed_at = now()
      WHERE ticket = $1
        AND consumed_at IS NULL
        AND expires_at > now()
      RETURNING user_id`,
    [ticket],
  )
  if (!consumed) {
    return new Response(
      JSON.stringify({ success: false, error: 'invalid_token' }),
      { status: 401, headers: { 'Content-Type': 'application/json' } },
    )
  }
  const userId: string = consumed.user_id

  // 2) Cursores iniciales — al abrir el stream solo interesa lo *nuevo*
  // (no queremos volver a empujar el historial en cada reconexión).
  const startedAt = new Date()
  let lastNotificationCreatedAt: Date = startedAt
  let lastRideUpdateAt: Date = startedAt
  let lastMessageAt: Date = startedAt
  let lastDriverLocationAt: Date = startedAt
  let lastPingAt: number = Date.now()

  // 3) Timer + guardas de estado (evitan double-close / enqueue tras cierre).
  let pollTimer: NodeJS.Timeout | null = null
  let closed = false
  let polling = false

  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      const cleanup = () => {
        if (closed) return
        closed = true
        if (pollTimer) {
          clearInterval(pollTimer)
          pollTimer = null
        }
        try {
          controller.close()
        } catch {
          // ignorar — puede estar ya cerrado
        }
      }

      // Enviar un evento "ready" inicial para que el cliente Flutter sepa
      // que el canal está abierto (no bloquea el keepalive).
      try {
        controller.enqueue(
          sseEvent('ready', { userId, at: startedAt.toISOString() }),
        )
      } catch {
        // Si falla al iniciar, cerramos silenciosamente.
        cleanup()
        return
      }

      // Cierre limpio si el cliente desconecta
      const onAbort = () => cleanup()
      if (req.signal.aborted) {
        cleanup()
        return
      }
      req.signal.addEventListener('abort', onAbort, { once: true })

      // Emite bytes al stream. Si el consumer ya cerró (backpressure infinita
      // o cliente muerto), abortamos todo el ciclo.
      const send = (bytes: Uint8Array): boolean => {
        if (closed) return false
        // Si `desiredSize` es null, el stream ya está cerrado o roto.
        if (controller.desiredSize === null) {
          cleanup()
          return false
        }
        try {
          controller.enqueue(bytes)
          return true
        } catch {
          cleanup()
          return false
        }
      }

      // 4) Loop de polling
      const tick = async () => {
        if (closed || polling) return
        polling = true
        try {
          // Ronda 144 SECURITY: verificar que el user tenga AL MENOS una
          // sesión activa antes de servir datos. Sin esto, el SSE stream
          // sobrevive al logout: un attacker con ticket consumido sigue
          // recibiendo notifs, rides, driver GPS, chat en vivo horas después
          // de que la víctima haya hecho POST /account/logout (que llama
          // revokeAllUserSessions). El chequeo cierra streams huérfanos.
          const alive = await maybeOne<{ id: string }>(
            `SELECT id FROM sessions
              WHERE user_id = $1 AND revoked_at IS NULL AND expires_at > now()
              LIMIT 1`,
            [userId],
          )
          if (!alive) {
            send(sseEvent('session_revoked', { at: new Date().toISOString() }))
            cleanup()
            return
          }
          // 4.1) notificaciones nuevas para este user
          const notifs = await query<NotificationRow>(
            `SELECT id, user_id, type, title, body, data, read_at, created_at
               FROM notifications
              WHERE user_id = $1
                AND created_at > $2
              ORDER BY created_at ASC
              LIMIT 100`,
            [userId, lastNotificationCreatedAt],
          )
          for (const n of notifs) {
            if (
              !send(
                sseEvent('notification', {
                  id: n.id,
                  type: n.type,
                  title: n.title,
                  body: n.body,
                  data: n.data,
                  readAt: n.read_at?.toISOString() ?? null,
                  createdAt: n.created_at.toISOString(),
                }),
              )
            )
              return
          }
          lastNotificationCreatedAt = maxDate(
            notifs,
            'created_at',
            lastNotificationCreatedAt,
          )

          // 4.2) rides del user con cambios de estado
          //   OJO: la tabla `rides` no tiene `updated_at` — reconstruimos
          //   uno "efectivo" = GREATEST(created_at, accepted_at, started_at,
          //   completed_at) usando COALESCE con created_at como base.
          const rides = await query<RideUpdateRow>(
            `SELECT id, passenger_id, driver_id, status,
                    pickup_address, pickup_lat, pickup_lng,
                    destination_address, destination_lat, destination_lng,
                    estimated_fare, final_fare, payment_method, vehicle_type,
                    cancelled_by, cancelled_reason,
                    created_at, accepted_at, started_at, completed_at, arrived_at,
                    GREATEST(
                      created_at,
                      COALESCE(accepted_at,  created_at),
                      COALESCE(arrived_at,   created_at),
                      COALESCE(started_at,   created_at),
                      COALESCE(completed_at, created_at)
                    ) AS updated_at
               FROM rides
              WHERE (passenger_id = $1 OR driver_id = $1)
                AND status = ANY($2::text[])
                AND GREATEST(
                      created_at,
                      COALESCE(accepted_at,  created_at),
                      COALESCE(arrived_at,   created_at),
                      COALESCE(started_at,   created_at),
                      COALESCE(completed_at, created_at)
                    ) > $3
              ORDER BY updated_at ASC
              LIMIT 50`,
            [userId, ACTIVE_RIDE_STATUSES as unknown as string[], lastRideUpdateAt],
          )
          // Ronda 259: incluir las ofertas pendientes del ride.
          //
          // El cliente del conductor usa `driverOffers` para saber si su
          // oferta sigue viva: si NO la encuentra, cierra el overlay diciendo
          // "El pasajero rechazó tu oferta". Como este evento nunca enviaba el
          // campo, el cliente leía una lista vacía y anunciaba un rechazo
          // inexistente en cuanto llegaba cualquier actualización — la
          // pantalla se le cerraba sola al ofertar. El cliente ya se blindó
          // (solo concluye rechazo si la lista viene de verdad), pero además
          // enviamos el dato para que el rechazo REAL se siga detectando.
          const offersByRide = new Map<string, Array<Record<string, unknown>>>()
          if (rides.length > 0) {
            const offerRows = await query<{
              ride_id: string
              driver_id: string
              amount: string
              eta_seconds: number | null
              status: string
            }>(
              `SELECT ride_id, driver_id, amount::text, eta_seconds, status
                 FROM ride_offers
                WHERE ride_id = ANY($1::uuid[]) AND status = 'pending'`,
              [rides.map((r) => r.id)],
            )
            for (const o of offerRows) {
              const list = offersByRide.get(o.ride_id) ?? []
              list.push({
                driverId: o.driver_id,
                amount: Number(o.amount),
                etaSeconds: o.eta_seconds,
                status: o.status,
              })
              offersByRide.set(o.ride_id, list)
            }
          }

          for (const r of rides) {
            if (
              !send(
                sseEvent('ride_update', {
                  rideId: r.id,
                  driverOffers: offersByRide.get(r.id) ?? [],
                  passengerId: r.passenger_id,
                  driverId: r.driver_id,
                  status: r.status,
                  pickup: {
                    address: r.pickup_address,
                    lat: r.pickup_lat != null ? Number(r.pickup_lat) : null,
                    lng: r.pickup_lng != null ? Number(r.pickup_lng) : null,
                  },
                  destination: {
                    address: r.destination_address,
                    lat:
                      r.destination_lat != null
                        ? Number(r.destination_lat)
                        : null,
                    lng:
                      r.destination_lng != null
                        ? Number(r.destination_lng)
                        : null,
                  },
                  estimatedFare:
                    r.estimated_fare != null ? Number(r.estimated_fare) : null,
                  finalFare:
                    r.final_fare != null ? Number(r.final_fare) : null,
                  paymentMethod: r.payment_method,
                  vehicleType: r.vehicle_type,
                  cancelledBy: r.cancelled_by,
                  cancelledReason: r.cancelled_reason,
                  createdAt: r.created_at.toISOString(),
                  acceptedAt: r.accepted_at?.toISOString() ?? null,
                  startedAt: r.started_at?.toISOString() ?? null,
                  completedAt: r.completed_at?.toISOString() ?? null,
                  updatedAt: r.updated_at.toISOString(),
                }),
              )
            )
              return
          }
          lastRideUpdateAt = maxDate(rides, 'updated_at', lastRideUpdateAt)

          // 4.3) nuevos mensajes en rides del user, enviados por otros
          const messages = await query<RideMessageRow>(
            // Ronda 246: incluimos el nombre y la foto del remitente. Sin
            // ellos el chat mostraba el avatar como "?" y sin nombre en cada
            // mensaje que llegaba en vivo (por HTTP sí venía, por eso solo
            // fallaban los mensajes recién recibidos).
            `SELECT rm.id, rm.ride_id, rm.sender_id, rm.body,
                    rm.attachment_url, rm.created_at,
                    COALESCE(u.display_name, u.full_name) AS sender_name,
                    u.profile_photo_url AS sender_photo
               FROM ride_messages rm
               JOIN rides r ON r.id = rm.ride_id
               LEFT JOIN users u ON u.id = rm.sender_id
              WHERE (r.passenger_id = $1 OR r.driver_id = $1)
                AND rm.sender_id <> $1
                AND rm.created_at > $2
              ORDER BY rm.created_at ASC
              LIMIT 100`,
            [userId, lastMessageAt],
          )
          for (const m of messages) {
            if (
              !send(
                sseEvent('new_message', {
                  id: m.id,
                  rideId: m.ride_id,
                  senderId: m.sender_id,
                  senderName: m.sender_name,
                  senderPhoto: m.sender_photo,
                  body: m.body,
                  attachmentUrl: m.attachment_url,
                  createdAt: m.created_at.toISOString(),
                }),
              )
            )
              return
          }
          lastMessageAt = maxDate(messages, 'created_at', lastMessageAt)

          // 4.4) ubicación del driver de un ride activo del pasajero
          const locations = await query<DriverLocationRow>(
            `SELECT dp.driver_id,
                    r.id AS ride_id,
                    dp.latitude, dp.longitude, dp.heading,
                    dp.speed_kmh, dp.accuracy_meters, dp.updated_at
               FROM driver_presence dp
               JOIN rides r ON r.driver_id = dp.driver_id
              WHERE r.passenger_id = $1
                AND r.status = ANY($2::text[])
                AND dp.updated_at > $3
              ORDER BY dp.updated_at ASC
              LIMIT 50`,
            [
              userId,
              DRIVER_TRACKABLE_STATUSES as unknown as string[],
              lastDriverLocationAt,
            ],
          )
          for (const loc of locations) {
            if (
              !send(
                sseEvent('driver_location', {
                  driverId: loc.driver_id,
                  rideId: loc.ride_id,
                  latitude:
                    loc.latitude != null ? Number(loc.latitude) : null,
                  longitude:
                    loc.longitude != null ? Number(loc.longitude) : null,
                  heading:
                    loc.heading != null ? Number(loc.heading) : null,
                  speedKmh:
                    loc.speed_kmh != null ? Number(loc.speed_kmh) : null,
                  accuracyMeters:
                    loc.accuracy_meters != null
                      ? Number(loc.accuracy_meters)
                      : null,
                  updatedAt: loc.updated_at.toISOString(),
                }),
              )
            )
              return
          }
          lastDriverLocationAt = maxDate(
            locations,
            'updated_at',
            lastDriverLocationAt,
          )

          // 4.5) keepalive — si no mandamos nada en PING_INTERVAL_MS,
          // enviamos un `:ping` para que proxies (nginx, cloudflare) no
          // corten la conexión por idle-timeout.
          const noEvents =
            notifs.length === 0 &&
            rides.length === 0 &&
            messages.length === 0 &&
            locations.length === 0
          const now = Date.now()
          if (noEvents && now - lastPingAt >= PING_INTERVAL_MS) {
            if (!send(ssePing())) return
            lastPingAt = now
          } else if (!noEvents) {
            // Cualquier byte enviado cuenta como keepalive.
            lastPingAt = now
          }
        } catch (err) {
          // Un error en una query no debe matar el stream, solo lo logueamos.
          // Si el error persiste, el cliente igual reconecta con EventSource.
          console.error('[events/stream] tick error:', err)
        } finally {
          polling = false
        }
      }

      // Kick inicial + interval
      pollTimer = setInterval(tick, POLL_INTERVAL_MS)
      // Primer tick inmediato para no esperar 2s al abrir la conexión.
      void tick()
    },

    cancel() {
      // El consumidor cerró el stream (cliente desconectó o el runtime hace
      // teardown). Limpiar el timer para no seguir consultando la DB.
      closed = true
      if (pollTimer) {
        clearInterval(pollTimer)
        pollTimer = null
      }
    },
  })

  return new Response(stream, {
    status: 200,
    headers: {
      'Content-Type': 'text/event-stream; charset=utf-8',
      'Cache-Control': 'private, no-cache, no-store, no-transform',
      Connection: 'keep-alive',
      // Desactiva el buffering de nginx para SSE.
      'X-Accel-Buffering': 'no',
      // Impide filtrar la URL (con el ticket) via Referer a terceros.
      'Referrer-Policy': 'no-referrer',
      // Endurecimiento defensivo.
      'X-Content-Type-Options': 'nosniff',
    },
  })
}
