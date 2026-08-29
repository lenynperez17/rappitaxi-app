/**
 * POST /api/auth/sms/send
 * Body: { phoneNumber: "+5193..." }
 *
 * Envía OTP vía Twilio Verify + cooldown 15 min server-side en Postgres.
 * Rate limit por IP en memoria (proceso PM2).
 */
import { NextRequest, NextResponse } from 'next/server'
import { query } from '@/lib/db'
import { TwilioVerifyService } from '@/services/TwilioVerifyService'
import { ipRateLimit as sharedIpRateLimit } from '@/lib/rate-limit'

export const runtime = 'nodejs'

const SEND_COOLDOWN_MS = 15 * 60 * 1000

/**
 * Teléfonos con código fijo, para que quien revisa la app en App Store y en
 * Play pueda entrar sin recibir un SMS.
 *
 * RONDA 282 — SE ELIMINA +51999000100.
 *
 * Ese número era el del usuario `Administrador`, con `phone_verified = true`.
 * Como este endpoint no pide autenticación y escribe el código fijo en la base
 * de datos, cualquiera podía hacer dos peticiones —una aquí y otra a
 * `/api/auth/sms/verify` con el código 1234— y salir con un token de esa
 * cuenta. `requireAdmin` solo comprueba que el usuario del token sea admin, no
 * cómo se creó la sesión, así que ese token abría entero `/api/admin/*`:
 * usuarios, viajes, finanzas y recargas.
 *
 * Queda solo el número del revisor, que es una cuenta de conductor normal sin
 * ningún privilegio. Aun así, más abajo en `verify` hay una segunda barrera
 * que rechaza este camino para cualquier cuenta administradora, por si algún
 * día se vuelve a añadir un número aquí sin reparar en a quién pertenece.
 */
const TEST_PHONE_NUMBERS: Record<string, string> = {
  '+51999000101': '1234',
}
function testPhonesEnabled() {
  return process.env.TEST_PHONES_ENABLED === 'true'
}

function isValidE164(p: string) {
  return /^\+[1-9][0-9]{9,14}$/.test(p)
}

// Rate-limit por IP: usa el shared en `lib/rate-limit` que tiene purga
// periódica (PURGE_EVERY=500). Antes había un Map local sin purga que
// crecía sin cota → OOM eventual bajo attacker con IPs rotativas.
const IP_MAX_PER_HOUR = Number(process.env.SMS_RATE_LIMIT_PER_IP_PER_HOUR ?? 10)

export async function POST(req: NextRequest) {
  const rl = sharedIpRateLimit(req, 'sms-send', { max: IP_MAX_PER_HOUR, windowMs: 60 * 60 * 1000 })
  if (!rl.ok) {
    return NextResponse.json(
      { success: false, error: 'ip_rate_limited', message: 'Demasiadas solicitudes. Intenta más tarde.' },
      { status: 429 },
    )
  }

  let body: { phoneNumber?: string }
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  const phoneNumber = body.phoneNumber?.trim()
  if (!phoneNumber || !isValidE164(phoneNumber)) {
    return NextResponse.json(
      { success: false, error: 'invalid_phone', message: 'Número inválido. Formato E.164: +51999888777' },
      { status: 400 },
    )
  }

  const phoneKey = phoneNumber.replace('+', '')

  // Test phones bypass
  if (testPhonesEnabled() && TEST_PHONE_NUMBERS[phoneNumber]) {
    const testCode = TEST_PHONE_NUMBERS[phoneNumber]!
    const expiresAt = new Date(Date.now() + 60 * 60 * 1000)
    await query(
      `INSERT INTO phone_verifications (phone_key, phone_number, test_code, test_code_expires, is_test_phone, last_sent_at)
       VALUES ($1,$2,$3,$4,true,now())
       ON CONFLICT (phone_key) DO UPDATE
         SET test_code=$3, test_code_expires=$4, is_test_phone=true, last_sent_at=now()`,
      [phoneKey, phoneNumber, testCode, expiresAt],
    )
    // Ronda 214 SECURITY: en producción NUNCA log OTP + teléfono juntos —
    // cualquiera con acceso a pm2/journald autenticaba como las cuentas de
    // review App Store/Play (+51999000100/101). Solo log en dev; en prod
    // solo confirmación sin datos sensibles.
    if (process.env.NODE_ENV !== 'production') {
      console.log(`🧪 [TEST] ${phoneNumber} código fijo ${testCode}`)
    } else {
      console.log(`[auth/sms] test phone OTP dispatched (code redacted)`)
    }
    return NextResponse.json({ success: true, provider: 'test', status: 'pending' })
  }

  // Cooldown 15 min — reserva atómica via INSERT ON CONFLICT DO UPDATE
  // WHERE last_sent_at < now() - interval. Ronda 57 Bug#1: sin esta reserva
  // atómica, dos requests concurrentes ambos leian last_sent_at antes de
  // que ninguno actualizara → ambos pasaban check y ambos llamaban Twilio →
  // múltiples SMS al mismo número, quemando saldo + spam al user.
  const cooldownIntervalSec = Math.floor(SEND_COOLDOWN_MS / 1000)
  const reserved = await query<{ reserved: boolean; last_sent_at: Date | null }>(
    `INSERT INTO phone_verifications (phone_key, phone_number, last_sent_at)
     VALUES ($1, $2, now())
     ON CONFLICT (phone_key) DO UPDATE
       SET last_sent_at = now(), phone_number = EXCLUDED.phone_number
       WHERE phone_verifications.last_sent_at IS NULL
          OR phone_verifications.last_sent_at < now() - ($3::int * interval '1 second')
     RETURNING true AS reserved, last_sent_at`,
    [phoneKey, phoneNumber, cooldownIntervalSec],
  )
  if (reserved.length === 0) {
    // No se pudo reservar → estamos dentro del cooldown; devolver 429
    const existing = await query<{ last_sent_at: Date }>(
      'SELECT last_sent_at FROM phone_verifications WHERE phone_key = $1',
      [phoneKey],
    )
    const lastSentMs = existing[0]?.last_sent_at ? new Date(existing[0].last_sent_at).getTime() : Date.now()
    const remainingMin = Math.max(1, Math.ceil((SEND_COOLDOWN_MS - (Date.now() - lastSentMs)) / 60000))
    return NextResponse.json(
      {
        success: false,
        error: 'rate_limited',
        message: `Ya enviamos un código. Espera ${remainingMin} minuto${remainingMin !== 1 ? 's' : ''} o usa Google/Apple.`,
        retryAfterMinutes: remainingMin,
      },
      { status: 429 },
    )
  }

  const twilio = new TwilioVerifyService()
  const result = await twilio.startVerification(phoneNumber)

  if (!result.success) {
    if (result.rateLimited) {
      return NextResponse.json(
        { success: false, error: 'rate_limited', message: 'Demasiados intentos. Usa Google/Apple.' },
        { status: 429 },
      )
    }
    if (result.noBalance) {
      return NextResponse.json(
        { success: false, error: 'sms_unavailable', message: 'Servicio SMS temporalmente no disponible.' },
        { status: 503 },
      )
    }
    // Ronda 269: NO devolver al cliente el error crudo del proveedor.
    //
    // `result.error` es el texto literal de Twilio, y con la cuenta suspendida
    // llegaba al móvil de cualquier persona que intentara registrarse:
    //   "Twilio 20003: authentication failed, account AC<redactado>
    //    with status 4 is not active"
    // Dos problemas de golpe: filtra el Account SID de la cuenta —un dato que
    // no debe salir del servidor— y le dice a un usuario normal algo que no
    // entiende ni puede resolver. Es el punto 7 del informe del cliente
    // ("mensajes de error poco claros"), agravado con una fuga de datos.
    //
    // El detalle real queda en los logs del servidor, que es donde sirve.
    console.error('[auth/sms/send] fallo del proveedor SMS:', result.error)
    return NextResponse.json(
      {
        success: false,
        error: 'sms_error',
        message: 'No pudimos enviarte el código ahora mismo. '
          + 'Vuelve a intentarlo en unos minutos o entra con Google o Apple.',
      },
      { status: 500 },
    )
  }

  // Reserva ya se hizo arriba con INSERT ON CONFLICT DO UPDATE — no necesitamos
  // segundo UPDATE aquí (Ronda 57 fix).
  return NextResponse.json({ success: true, provider: 'sms', status: 'pending' })
}
