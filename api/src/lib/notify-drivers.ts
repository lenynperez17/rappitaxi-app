/**
 * Notifica a uno o varios conductores sobre una nueva oferta de viaje.
 * Emite:
 *   - Fila en `notifications` (visible en el SSE stream del conductor)
 *   - Push FCM real a todos los tokens del conductor (best-effort)
 *
 * Errores en push no rompen el flujo (best-effort).
 */
import { query } from '@/lib/db'
import { messaging } from '@/lib/firebase-admin'

interface RideOfferData {
  rideId: string
  pickupAddress: string | null
  destinationAddress: string | null
  pickupLat: number
  pickupLng: number
  destinationLat: number
  destinationLng: number
  estimatedFare: number | null
  passengerName: string | null
  passengerPhone: string | null
  vehicleType: string | null
  /** Ronda 280: el servicio que pidió el pasajero (express, vip, minivan…). */
  serviceLabel?: string | null
  paymentMethod: string | null
}

/**
 * Encuentra conductores en línea (heartbeat < 5 min) a menos de `radiusKm` del
 * punto de recogida.
 *
 * RONDA 280 — POR QUÉ CAMBIÓ EL FILTRO DE VEHÍCULO
 * ------------------------------------------------
 * Antes comparaba contra `driver_presence.vehicle_type`, y ese campo estaba
 * **NULL para todos los conductores**: la app manda el heartbeat sin él
 * (`modern_driver_home.dart`). Con NULL, la condición
 * `(dp.vehicle_type IS NULL OR ...)` se cumplía siempre y el filtro no filtraba
 * nada. Todos recibían todo.
 *
 * Ahora se mira `driver_vehicles`, que es donde el conductor SÍ registró su
 * vehículo al darse de alta. La diferencia importa: funciona de inmediato para
 * los conductores que ya están, **sin que actualicen la app**. Si dependiera
 * del heartbeat, solo funcionaría para quien instale la versión nueva.
 *
 * `allowedVehicleTypes` en `null` significa "no filtres" — y quien llama lo
 * pone en null cuando el servicio no restringe. Un conductor **sin vehículo
 * activo registrado** también pasa: cortarle el trabajo por un dato que quizá
 * nunca rellenó sería quitárselo sin avisar.
 */
export async function findNearbyOnlineDrivers(
  pickupLat: number,
  pickupLng: number,
  radiusKm: number,
  allowedVehicleTypes?: string[] | null,
): Promise<string[]> {
  const filtra = Array.isArray(allowedVehicleTypes) && allowedVehicleTypes.length > 0
  const rows = await query<{ driver_id: string }>(
    `SELECT dp.driver_id
       FROM driver_presence dp
       JOIN users u ON u.id = dp.driver_id
      WHERE dp.is_online = true
        AND dp.last_heartbeat > NOW() - INTERVAL '5 minutes'
        AND u.deleted_at IS NULL
        AND dp.latitude IS NOT NULL AND dp.longitude IS NOT NULL
        AND (
          6371 * acos(
            LEAST(1.0, GREATEST(-1.0,
              cos(radians($1)) * cos(radians(dp.latitude::float8))
              * cos(radians(dp.longitude::float8) - radians($2))
              + sin(radians($1)) * sin(radians(dp.latitude::float8))
            ))
          )
        ) < $3
        ${filtra ? `AND (
             NOT EXISTS (
               SELECT 1 FROM driver_vehicles dv
                WHERE dv.driver_id = dp.driver_id AND dv.is_active = true
             )
             OR EXISTS (
               SELECT 1 FROM driver_vehicles dv
                WHERE dv.driver_id = dp.driver_id
                  AND dv.is_active = true
                  AND dv.vehicle_type = ANY($4::text[])
             )
           )` : ''}
      ORDER BY dp.last_heartbeat DESC
      LIMIT 50`,
    filtra
      ? [pickupLat, pickupLng, radiusKm, allowedVehicleTypes]
      : [pickupLat, pickupLng, radiusKm],
  )
  return rows.map((r) => r.driver_id)
}

/**
 * Emite una oferta de viaje a los drivers indicados.
 * Best-effort: si FCM falla para uno, se continúa con los demás.
 */
export async function notifyRideOffer(
  driverIds: string[],
  ride: RideOfferData,
): Promise<{ notified: number; fcmSent: number }> {
  if (driverIds.length === 0) return { notified: 0, fcmSent: 0 }

  const title = 'Nuevo viaje disponible'
  const bodyText = ride.pickupAddress
    ? `Recogida: ${ride.pickupAddress.slice(0, 80)}`
    : 'Toca para ver los detalles'
  const dataJson = {
    type: 'new_ride_offer',
    rideId: ride.rideId,
    pickup: {
      address: ride.pickupAddress,
      lat: ride.pickupLat,
      lng: ride.pickupLng,
    },
    destination: {
      address: ride.destinationAddress,
      lat: ride.destinationLat,
      lng: ride.destinationLng,
    },
    estimatedFare: ride.estimatedFare,
    passenger: {
      name: ride.passengerName,
      phone: ride.passengerPhone,
    },
    vehicleType: ride.vehicleType,
    // Ronda 280: el conductor cobraba la tarifa VIP sin enterarse de que le
    // habían pedido VIP. Ahora el servicio viaja con la solicitud.
    serviceLabel: ride.serviceLabel ?? null,
    paymentMethod: ride.paymentMethod,
    createdAt: new Date().toISOString(),
  }

  // 1. Insert notifications en batch — el SSE stream lo recogerá en el próximo tick
  const placeholders = driverIds.map((_, i) => `($${i + 1}, 'new_ride_offer', $${driverIds.length + 1}, $${driverIds.length + 2}, $${driverIds.length + 3})`).join(',')
  await query(
    `INSERT INTO notifications (user_id, type, title, body, data)
     VALUES ${placeholders}`,
    [...driverIds, title, bodyText, JSON.stringify(dataJson)],
  )

  // 2. Push FCM real (best-effort, en paralelo)
  let fcmSent = 0
  try {
    const tokens = await query<{ user_id: string; token: string }>(
      `SELECT user_id, token FROM fcm_tokens
        WHERE user_id = ANY($1::text[])`,
      [driverIds],
    )
    if (tokens.length > 0) {
      const results = await Promise.allSettled(
        tokens.map((t) =>
          messaging.send({
            token: t.token,
            notification: { title, body: bodyText },
            data: {
              type: 'new_ride_offer',
              rideId: ride.rideId,
              json: JSON.stringify(dataJson),
            },
            android: {
              priority: 'high',
              notification: {
                sound: 'ride_request',
                // Ronda 223: coincidir con canal creado por Flutter en
                // notification_service.dart (era 'ride_offers' → canal
                // inexistente → sonido default → drivers pierden solicitudes).
                channelId: 'rappi_rides',
              },
            },
            apns: {
              payload: {
                aps: {
                  sound: 'ride_request.wav',
                  contentAvailable: true,
                },
              },
            },
          }).then(() => ({ ok: true, token: t.token, err: null as string | null }))
           .catch((e: unknown) => ({
              ok: false,
              token: t.token,
              err: (e as { code?: string; message?: string }).code ?? (e as Error).message ?? 'unknown',
            })),
        ),
      )
      const deadTokens: string[] = []
      for (const r of results) {
        if (r.status !== 'fulfilled') continue
        const v = r.value
        if (v.ok) { fcmSent += 1; continue }
        if (v.err && (
          v.err.includes('registration-token-not-registered')
          || v.err.includes('invalid-registration-token')
          || v.err.includes('invalid-argument')
          || v.err.includes('messaging/invalid-recipient')
        )) {
          deadTokens.push(v.token)
        }
      }
      // Limpieza de tokens muertos — evita acumulación indefinida
      if (deadTokens.length > 0) {
        await query(
          `DELETE FROM fcm_tokens WHERE token = ANY($1::text[])`,
          [deadTokens],
        )
      }
    }
  } catch (err) {
    console.warn('[notify-drivers] FCM push falló (best-effort):', err instanceof Error ? err.message : err)
  }

  return { notified: driverIds.length, fcmSent }
}
