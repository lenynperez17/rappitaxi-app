/**
 * Ronda 283 — cerrar solos los viajes que se quedaron a medias.
 *
 * POR QUÉ HACÍA FALTA
 * -------------------
 * Un viaje podía quedarse en 'requested' para siempre. Había caducidad para
 * las OFERTAS de los conductores (`ride_offers.status = 'expired'`), pero
 * ninguna para el viaje en sí: si nadie lo aceptaba, ahí se quedaba. En
 * producción había una solicitud de hace 16 horas y un viaje aceptado hace 20
 * que seguían contando como actividad en curso.
 *
 * Para el pasajero es peor que un número mal contado: pide un viaje, nadie lo
 * coge, y la app se queda esperando indefinidamente sin decirle que no hay
 * nadie. El estado 'no_drivers' ya existía en la tabla y en las etiquetas del
 * panel — solo que nada lo ponía nunca.
 *
 * LOS DOS CASOS, QUE NO SE PARECEN EN NADA
 * ----------------------------------------
 * 1. Nadie lo aceptó. Sin conductor asignado, no hay a quién penalizar ni a
 *    quién avisar: se marca 'no_drivers' y listo. El umbral es corto porque
 *    quien pide un taxi y no encuentra prefiere enterarse en minutos.
 *
 * 2. Se aceptó y nunca se cerró. Aquí hay que ir con mucho más cuidado: hay
 *    un conductor y un pasajero de por medio, y un viaje largo o con una
 *    parada es legítimo. El umbral es deliberadamente generoso —doce horas—
 *    para no cortar nunca un viaje de verdad; a esas alturas no es un viaje
 *    largo, es uno que nadie cerró. Se cancela SIN penalidad: no se sabe de
 *    quién fue la culpa y cobrarle a alguien por una suposición sería peor
 *    que dejar el viaje abierto.
 *
 * CÓMO SE EJECUTA
 * ---------------
 * El proyecto no tiene ningún planificador: `sessions.cleanupExpired` lleva
 * documentado desde siempre que "corre desde cron (worker VPS, daily 03:00)"
 * y en el VPS no hay ningún cron, así que nunca se ha ejecutado. Antes que
 * añadir infraestructura que también se puede quedar sin arrancar, esto se
 * cuelga de peticiones que ya ocurren solas y a menudo: el panel pide
 * estadísticas cada 30 s mientras alguien lo tiene abierto, y los conductores
 * consultan los viajes disponibles continuamente. Con eso la caducidad ocurre
 * en cuestión de segundos sin nada que mantener.
 */
import { query } from '@/lib/db'

/**
 * Minutos sin que nadie acepte antes de darlo por perdido.
 *
 * Corto a propósito: el pasajero está mirando la pantalla. Quince minutos ya
 * es mucho más de lo que nadie espera con el móvil en la mano.
 */
export const MINUTOS_SIN_CONDUCTOR = 15

/**
 * Horas que puede durar un viaje aceptado antes de considerarlo abandonado.
 *
 * Generoso a propósito, en la dirección segura: equivocarse cortando un viaje
 * real es mucho peor que dejar uno muerto un rato de más.
 */
const HORAS_VIAJE_ABANDONADO = 12

/** No tiene sentido barrer en cada request; con una vez por minuto sobra. */
const INTERVALO_MINIMO_MS = 60_000
let ultimoBarrido = 0

export interface ResultadoBarrido {
  sinConductor: number
  abandonados: number
}

/**
 * Cierra los viajes que llevan demasiado tiempo sin avanzar.
 *
 * No lanza nunca: se llama desde endpoints cuyo trabajo es otro, y que una
 * limpieza de fondo tumbe la respuesta del panel o la lista de viajes
 * disponibles de un conductor sería un intercambio pésimo.
 */
export async function expireStaleRides(
  { forzar = false }: { forzar?: boolean } = {},
): Promise<ResultadoBarrido> {
  const vacio: ResultadoBarrido = { sinConductor: 0, abandonados: 0 }

  const ahora = Date.now()
  if (!forzar && ahora - ultimoBarrido < INTERVALO_MINIMO_MS) return vacio
  ultimoBarrido = ahora

  try {
    // 1) Nadie lo aceptó. `driver_id IS NULL` es la condición que hace esto
    //    seguro: si hay conductor asignado, este caso no aplica por mucho que
    //    el estado siga siendo 'requested'.
    const sinConductor = await query<{ id: string }>(
      `UPDATE rides
          SET status = 'no_drivers'
        WHERE status IN ('requested', 'searching')
          AND driver_id IS NULL
          AND created_at < now() - ($1::int * interval '1 minute')
        RETURNING id`,
      [MINUTOS_SIN_CONDUCTOR],
    )

    // 2) Aceptado y nunca cerrado. Se mide desde el último hito conocido, no
    //    desde la creación: un viaje que empezó hace rato pero avanzó hace
    //    poco está vivo.
    const abandonados = await query<{ id: string }>(
      `UPDATE rides
          SET status = 'cancelled',
              cancelled_by = 'system',
              cancelled_reason = $2,
              cancel_reason_code = 'auto_expired',
              cancel_penalty_amount = 0
        WHERE status IN ('accepted', 'on_way', 'arrived', 'in_progress')
          AND COALESCE(started_at, arrived_at, accepted_at, created_at)
              < now() - ($1::int * interval '1 hour')
        RETURNING id`,
      [
        HORAS_VIAJE_ABANDONADO,
        `Cerrado automáticamente tras ${HORAS_VIAJE_ABANDONADO} h sin actividad.`,
      ],
    )

    const resultado: ResultadoBarrido = {
      sinConductor: sinConductor.length,
      abandonados: abandonados.length,
    }

    if (resultado.sinConductor > 0 || resultado.abandonados > 0) {
      console.log(
        `[expire-stale-rides] ${resultado.sinConductor} sin conductor, ` +
        `${resultado.abandonados} abandonados`,
      )
    }
    return resultado
  } catch (err) {
    console.error('[expire-stale-rides] error:', err)
    return vacio
  }
}
