/**
 * GET /api/admin/stats — stats agregadas para dashboard + páginas
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAdmin } from '@/lib/admin-middleware'
import { one } from '@/lib/db'

export const runtime = 'nodejs'

export async function GET(req: NextRequest) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response

  const s = await one<{
    total_users: string; total_passengers: string; total_drivers: string;
    total_admins: string; total_active: string; total_suspended: string;
    total_trips: string; trips_today: string; trips_completed: string; trips_cancelled: string;
    total_recharges: string; recharges_today: string; recharges_month: string;
    total_emergencies: string; active_emergencies: string;
    // Ronda 283: el estado del servicio ahora mismo, no los totales históricos.
    drivers_online: string; rides_active: string; oldest_active_ride_minutes: string;
    oldest_emergency_days: string; cancellations_pending: string;
    verifications_pending: string;
  }>(`
    SELECT
      (SELECT COUNT(*)::text FROM users WHERE deleted_at IS NULL) AS total_users,
      (SELECT COUNT(*)::text FROM users WHERE user_type = 'passenger' AND deleted_at IS NULL) AS total_passengers,
      -- Ronda 282: 'driver' ya no existe (migración 027) — quien conduce es
      -- 'dual'. Este conteo se quedaba en 1 mientras la tarjeta del dashboard,
      -- que sumaba los dos tipos, mostraba 6: dos cifras contradictorias con
      -- etiquetas casi iguales en la misma pantalla. Ahora hay una sola.
      (SELECT COUNT(*)::text FROM users WHERE user_type = 'dual' AND deleted_at IS NULL) AS total_drivers,
      (SELECT COUNT(*)::text FROM users WHERE (user_type = 'admin' OR is_admin = true) AND deleted_at IS NULL) AS total_admins,
      (SELECT COUNT(*)::text FROM users WHERE is_active = true AND suspended_at IS NULL AND deleted_at IS NULL) AS total_active,
      (SELECT COUNT(*)::text FROM users WHERE suspended_at IS NOT NULL AND deleted_at IS NULL) AS total_suspended,
      (SELECT COUNT(*)::text FROM rides) AS total_trips,
      (SELECT COUNT(*)::text FROM rides WHERE created_at >= (date_trunc('day', now() AT TIME ZONE 'America/Lima') AT TIME ZONE 'America/Lima')) AS trips_today,
      (SELECT COUNT(*)::text FROM rides WHERE status = 'completed') AS trips_completed,
      (SELECT COUNT(*)::text FROM rides WHERE status = 'cancelled') AS trips_cancelled,
      (SELECT COALESCE(SUM(amount), 0)::text FROM driver_recharges WHERE status = 'completed') AS total_recharges,
      (SELECT COALESCE(SUM(amount), 0)::text FROM driver_recharges WHERE status = 'completed' AND created_at >= (date_trunc('day', now() AT TIME ZONE 'America/Lima') AT TIME ZONE 'America/Lima')) AS recharges_today,
      (SELECT COALESCE(SUM(amount), 0)::text FROM driver_recharges WHERE status = 'completed' AND created_at >= (date_trunc('month', now() AT TIME ZONE 'America/Lima') AT TIME ZONE 'America/Lima')) AS recharges_month,
      (SELECT COUNT(*)::text FROM emergencies) AS total_emergencies,
      (SELECT COUNT(*)::text FROM emergencies WHERE status IN ('active','pending','escalated')) AS active_emergencies,

      -- Ronda 283: lo que estaba pasando AHORA no se veía en ningún sitio del
      -- Inicio. Se veían totales históricos —usuarios, viajes de siempre— pero
      -- no el estado del servicio en este momento, que es lo que de verdad
      -- decide si alguien tiene que hacer algo.

      -- Conductores disponibles ahora. Mismo criterio que el mapa en vivo:
      -- en línea y con latido reciente, porque is_online se queda pegado a
      -- true si la app muere sin avisar.
      (SELECT COUNT(*)::text FROM driver_presence
        WHERE is_online = true
          AND (last_heartbeat IS NULL OR last_heartbeat > now() - INTERVAL '5 minutes')
      ) AS drivers_online,

      -- Viajes vivos: pedidos o en marcha. Si este número no baja, algo se
      -- quedó colgado.
      (SELECT COUNT(*)::text FROM rides
        WHERE status IN ('requested','accepted','arrived','in_progress')
      ) AS rides_active,

      -- Antigüedad del viajo vivo más viejo, en minutos. Un viaje "pedido"
      -- hace 16 horas no es actividad: es un viaje huérfano que nadie atendió.
      (SELECT COALESCE(MAX(EXTRACT(EPOCH FROM (now() - created_at)) / 60), 0)::int::text
         FROM rides
        WHERE status IN ('requested','accepted','arrived','in_progress')
      ) AS oldest_active_ride_minutes,

      -- Días que lleva abierta la emergencia más antigua. Un SOS sin cerrar
      -- durante semanas dice más que el número de SOS abiertos.
      (SELECT COALESCE(MAX(EXTRACT(EPOCH FROM (now() - created_at)) / 86400), 0)::int::text
         FROM emergencies WHERE status IN ('active','pending','escalated')
      ) AS oldest_emergency_days,

      -- Cancelaciones con penalidad esperando que alguien las revise.
      (SELECT COUNT(*)::text FROM rides
        WHERE status = 'cancelled' AND cancel_penalty_amount > 0
          AND penalty_review_status = 'pending'
      ) AS cancellations_pending,

      -- Conductores pendientes de aprobar. Mismo criterio que la pantalla de
      -- Verificaciones, para que las dos cifras no puedan discrepar.
      (SELECT COUNT(*)::text FROM users u
        WHERE u.deleted_at IS NULL AND u.is_verified = false
          AND (u.user_type = 'dual'
               OR EXISTS (SELECT 1 FROM driver_documents dd WHERE dd.driver_id = u.id)
               OR EXISTS (SELECT 1 FROM driver_vehicles dv WHERE dv.driver_id = u.id))
      ) AS verifications_pending
  `)

  return NextResponse.json({
    success: true,
    stats: {
      users: {
        total: Number(s.total_users),
        passengers: Number(s.total_passengers),
        drivers: Number(s.total_drivers),
        admins: Number(s.total_admins),
        active: Number(s.total_active),
        suspended: Number(s.total_suspended),
      },
      trips: {
        total: Number(s.total_trips),
        today: Number(s.trips_today),
        completed: Number(s.trips_completed),
        cancelled: Number(s.trips_cancelled),
      },
      recharges: {
        total: Number(s.total_recharges),
        today: Number(s.recharges_today),
        month: Number(s.recharges_month),
      },
      emergencies: {
        total: Number(s.total_emergencies),
        active: Number(s.active_emergencies),
        oldestDays: Number(s.oldest_emergency_days),
      },
      // Ronda 283: el estado del servicio en este momento. Lo de arriba son
      // totales acumulados —cuántos usuarios hay, cuántos viajes hubo—, útiles
      // para hacerse una idea pero incapaces de decir si ahora mismo hay algo
      // que atender. Esto sí.
      ahora: {
        driversOnline: Number(s.drivers_online),
        ridesActive: Number(s.rides_active),
        oldestActiveRideMinutes: Number(s.oldest_active_ride_minutes),
      },
      // Cosas concretas esperando que una persona haga algo con ellas.
      pendientes: {
        cancellations: Number(s.cancellations_pending),
        verifications: Number(s.verifications_pending),
      },
    },
  })
}
