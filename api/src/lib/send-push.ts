/**
 * Helper genérico para enviar push notifications FCM a uno o varios users.
 * Ronda 223: extracto de la lógica de notify-drivers.ts para reutilizar en
 * los 13+ endpoints que hoy solo hacen INSERT INTO notifications sin push
 * (rides/accept, arrived, start, complete, cancel, messages, offers,
 * negotiations, drivers/documents, admin/documents, wallet/withdrawals,
 * MP webhook approved, etc.).
 *
 * Uso:
 *   await sendPush({
 *     userIds: [passengerId],
 *     type: 'ride_accepted',
 *     title: 'Tu conductor está en camino',
 *     body: `${driverName} aceptó tu viaje`,
 *     data: { rideId, driverId },
 *     channel: 'rappi_rides',      // Android channelId
 *     sound: 'ride_accepted',      // sin extensión para Android, .wav agregado para iOS
 *     priority: 'high',
 *   })
 */
import { query } from './db'
import { messaging } from './firebase-admin'

// Canales Android. DEBEN coincidir con los que crea Flutter en
// notification_service.dart. Si un push llega con un channelId que no existe
// en el device, Android usa el default → sonido genérico.
export type PushChannel =
  | 'rappi_rides'       // Solicitudes de viaje, aceptación, llegada, in-progress
  | 'rappi_emergency'   // SOS
  | 'rappi_chat'        // Mensajes entre passenger y driver
  | 'rappi_payments'    // Recargas, cobros, retiros, refunds (nombre coincide con Flutter)
  | 'rappi_documents'   // Aprobación/rechazo de docs del driver
  | 'rappi_general'     // Anuncios/promos (nombre coincide con Flutter)

// Sonidos disponibles en android/app/src/main/res/raw/ y ios/Runner/Sounds/.
// Nombre SIN extensión — el iOS handler agrega .wav antes de enviar a APNs.
export type PushSound =
  | 'ride_request'
  | 'ride_accepted'
  | 'driver_arrived'
  | 'trip_completed'
  | 'chat_message'
  | 'emergency_alert'
  | 'timer_expired'

interface SendPushOptions {
  userIds: string[]
  type: string
  title: string
  body: string
  data?: Record<string, unknown>
  channel?: PushChannel
  sound?: PushSound
  priority?: 'normal' | 'high'
  /** Si true, ADEMÁS del push inserta una fila en `notifications`. Default true. */
  persist?: boolean
}

export interface SendPushResult {
  fcmSent: number
  fcmFailed: number
  inAppInserted: number
  deadTokensRemoved: number
}

export async function sendPush(opts: SendPushOptions): Promise<SendPushResult> {
  const {
    userIds,
    type,
    title,
    body,
    data = {},
    channel = 'rappi_default',
    sound,
    priority = 'high',
    persist = true,
  } = opts

  if (userIds.length === 0) {
    return { fcmSent: 0, fcmFailed: 0, inAppInserted: 0, deadTokensRemoved: 0 }
  }

  // 1) Persistir in-app notification (para que se vea al abrir la app).
  let inAppInserted = 0
  if (persist) {
    try {
      const placeholders = userIds
        .map((_, i) => `($${i + 1}, $${userIds.length + 1}, $${userIds.length + 2}, $${userIds.length + 3}, $${userIds.length + 4})`)
        .join(',')
      const rows = await query<{ id: string }>(
        `INSERT INTO notifications (user_id, type, title, body, data)
         VALUES ${placeholders}
         RETURNING id`,
        [...userIds, type, title, body, JSON.stringify(data)],
      )
      inAppInserted = rows.length
    } catch (err) {
      console.warn('[sendPush] insert notifications failed:', err)
    }
  }

  // 2) Push FCM real. Fire-and-forget: si falla no rompe el caller.
  let fcmSent = 0
  let fcmFailed = 0
  let deadTokensRemoved = 0
  try {
    const tokens = await query<{ user_id: string; token: string }>(
      `SELECT user_id, token FROM fcm_tokens WHERE user_id = ANY($1::text[])`,
      [userIds],
    )
    if (tokens.length > 0) {
      const androidNotif: { sound?: string; channelId: string } = { channelId: channel }
      if (sound) androidNotif.sound = sound
      const apnsSound = sound ? `${sound}.wav` : 'default'

      const results = await Promise.allSettled(
        tokens.map((t) =>
          messaging.send({
            token: t.token,
            notification: { title, body },
            data: {
              type,
              ...Object.fromEntries(
                Object.entries(data).map(([k, v]) => [k, String(v ?? '')]),
              ),
            },
            android: {
              priority,
              notification: androidNotif,
            },
            apns: {
              headers: {
                'apns-priority': priority === 'high' ? '10' : '5',
                'apns-push-type': 'alert',
              },
              payload: {
                aps: {
                  sound: apnsSound,
                  contentAvailable: true,
                },
              },
            },
          }).then(() => ({ ok: true, token: t.token, err: null as string | null }))
           .catch((e: unknown) => ({
              ok: false,
              token: t.token,
              err: (e as { code?: string; message?: string }).code
                ?? (e as Error).message ?? 'unknown',
            })),
        ),
      )
      const deadTokens: string[] = []
      for (const r of results) {
        if (r.status !== 'fulfilled') { fcmFailed += 1; continue }
        const v = r.value
        if (v.ok) { fcmSent += 1; continue }
        fcmFailed += 1
        if (v.err && (
          v.err.includes('registration-token-not-registered')
          || v.err.includes('invalid-registration-token')
          || v.err.includes('invalid-argument')
          || v.err.includes('messaging/invalid-recipient')
        )) {
          deadTokens.push(v.token)
        }
      }
      if (deadTokens.length > 0) {
        await query(
          `DELETE FROM fcm_tokens WHERE token = ANY($1::text[])`,
          [deadTokens],
        )
        deadTokensRemoved = deadTokens.length
      }
    }
  } catch (err) {
    console.warn('[sendPush] FCM send failed (best-effort):', err)
  }

  return { fcmSent, fcmFailed, inAppInserted, deadTokensRemoved }
}
