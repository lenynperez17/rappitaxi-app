/**
 * Cloud Functions de verificación OTP por SMS via Telnyx Verify API.
 *
 * Reemplaza Firebase Phone Auth (más caro en Perú y sin soporte alphanumeric).
 *
 * Política "1 código por número":
 *  - Telnyx genera el código y maneja su TTL (5 min default en el Verify Profile)
 *  - NOSOTROS imponemos cooldown server-side de 15 min entre envíos al mismo
 *    número (persistido en phone_verifications/{phoneKey}.lastSentAt) para
 *    forzar al usuario a usar Google/Apple si no recibe el SMS, en vez de
 *    seguir martillando el endpoint.
 *
 * El envío usa alphanumeric sender ID ("RapiTeam") — no se necesita un
 * phone number propio.
 */

import { onRequest } from 'firebase-functions/v2/https'
import * as admin from 'firebase-admin'
import {
  TelnyxVerifyService,
  type CheckRejectReason,
} from '../services/TelnyxVerifyService'

const VERIFICATION_COLLECTION = 'phone_verifications'
const SEND_COOLDOWN_MS = 15 * 60 * 1000 // 15 minutos

// Test phone numbers para Apple/Google review (no llaman a Telnyx).
// El código es de 4 dígitos para coincidir con la UI del pin code.
const TEST_PHONE_NUMBERS: Record<string, string> = {
  '+51999000100': '1234',
  '+51999000101': '1234',
}

function formatPhone(phoneNumber: string): string {
  if (phoneNumber.startsWith('+')) return phoneNumber
  return `+51${phoneNumber.replace(/^0+/, '')}`
}

async function storeTestCode(formattedPhone: string, code: string): Promise<void> {
  const db = admin.firestore()
  const phoneKey = formattedPhone.replace('+', '')
  const now = new Date()
  const expiresAt = new Date(now.getTime() + 60 * 60 * 1000) // 1 hora para reviewer
  await db.collection(VERIFICATION_COLLECTION).doc(phoneKey).set({
    code,
    phoneNumber: formattedPhone,
    createdAt: admin.firestore.Timestamp.fromDate(now),
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    used: false,
    isTestPhone: true,
  })
}

/**
 * POST /sendVerificationCode
 * Body: { phoneNumber: "+51999999999" }
 * Respuesta: { success: true, provider: "sms" | "test", status: "pending" }
 */
export const sendVerificationCode = onRequest(
  {
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 30,
    cors: true,
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({ success: false, error: 'Método no permitido' })
      return
    }
    const { phoneNumber } = req.body
    if (!phoneNumber) {
      res.status(400).json({ success: false, error: 'Número de teléfono requerido' })
      return
    }

    const formattedPhone = formatPhone(phoneNumber)
    const phoneKey = formattedPhone.replace('+', '')
    const db = admin.firestore()
    console.log(`📱 [OTP] Solicitud de envío a ${formattedPhone}`)

    try {
      // Test phones (Apple/Google Review) — sin Telnyx, sin rate limit
      if (TEST_PHONE_NUMBERS[formattedPhone]) {
        const testCode = TEST_PHONE_NUMBERS[formattedPhone]!
        await storeTestCode(formattedPhone, testCode)
        console.log(`🧪 [TEST] ${formattedPhone}, código fijo ${testCode}`)
        res.json({ success: true, provider: 'test', status: 'pending' })
        return
      }

      // Cooldown server-side 15 min
      const phoneDocRef = db.collection(VERIFICATION_COLLECTION).doc(phoneKey)
      const phoneDocSnap = await phoneDocRef.get()
      if (phoneDocSnap.exists) {
        const data = phoneDocSnap.data()
        const lastSentTs = data?.lastSentAt as admin.firestore.Timestamp | undefined
        const lastSentMs = lastSentTs?.toMillis?.() ?? 0
        const elapsed = Date.now() - lastSentMs
        if (lastSentMs > 0 && elapsed < SEND_COOLDOWN_MS) {
          const remainingMin = Math.ceil((SEND_COOLDOWN_MS - elapsed) / 60000)
          res.status(429).json({
            success: false,
            error: 'rate_limited',
            message: `Ya enviamos un código a este número. Espera ${remainingMin} minuto${remainingMin !== 1 ? 's' : ''} antes de pedir otro o usa Google/Apple.`,
            retryAfterMinutes: remainingMin,
          })
          return
        }
      }

      const telnyx = new TelnyxVerifyService()
      const result = await telnyx.startVerification(formattedPhone)

      if (!result.success) {
        if (result.rateLimited) {
          res.status(429).json({
            success: false,
            error: 'rate_limited',
            message: 'Ya hay un código pendiente. Espera unos minutos o usa Google/Apple.',
          })
          return
        }
        if (result.noBalance) {
          res.status(503).json({
            success: false,
            error: 'sms_unavailable',
            message: 'Servicio de SMS temporalmente no disponible. Usa Google o Apple para continuar.',
          })
          return
        }
        res.status(500).json({ success: false, error: 'Error enviando código por SMS' })
        return
      }

      await phoneDocRef.set(
        {
          phoneNumber: formattedPhone,
          lastSentAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      )

      res.json({ success: true, provider: 'sms', status: 'pending' })
    } catch (error) {
      console.error('❌ [OTP] sendVerificationCode error:', error)
      res.status(500).json({ success: false, error: 'Error enviando código de verificación' })
    }
  },
)

/**
 * POST /verifyCode
 * Body: { phoneNumber: "+51999999999", code: "1234" }
 * Respuesta: { success: true, token: "<custom_token>", uid, isNewUser }
 */
export const verifyCode = onRequest(
  {
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 30,
    cors: true,
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({ success: false, error: 'Método no permitido' })
      return
    }
    const { phoneNumber, code } = req.body
    if (!phoneNumber || !code) {
      res.status(400).json({
        success: false,
        error: 'Número de teléfono y código requeridos',
      })
      return
    }

    const formattedPhone = formatPhone(phoneNumber)
    console.log(`🔐 [OTP] Verificando código para ${formattedPhone}`)

    try {
      const validation = await validateCode(formattedPhone, code)
      if (!validation.accepted) {
        if (validation.reason === 'expired') {
          res.status(410).json({
            success: false,
            error: 'code_expired',
            message: 'El código SMS expiró. Espera 15 minutos para pedir otro o usa Google/Apple.',
          })
          return
        }
        res.status(400).json({
          success: false,
          error: 'code_incorrect',
          message: 'Código incorrecto. Verifica los 4 dígitos del SMS.',
        })
        return
      }

      // Crear/obtener usuario Firebase Auth
      const db = admin.firestore()
      const phoneWithoutPrefix = formattedPhone.replace('+51', '')

      let uid: string
      let isNewUser = false

      const existingUserSnap = await db
        .collection('users')
        .where('phone', 'in', [phoneWithoutPrefix, formattedPhone])
        .limit(1)
        .get()

      if (!existingUserSnap.empty) {
        uid = existingUserSnap.docs[0]!.id
      } else {
        try {
          const newUser = await admin.auth().createUser({ phoneNumber: formattedPhone })
          uid = newUser.uid
          isNewUser = true
          await db.collection('users').doc(uid).set({
            phone: phoneWithoutPrefix,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            authProvider: 'phone',
            isProfileComplete: false,
            phoneVerified: true,
          })
        } catch (authError: unknown) {
          const errCode = (authError as { code?: string })?.code
          if (errCode === 'auth/phone-number-already-exists') {
            const existingAuthUser = await admin
              .auth()
              .getUserByPhoneNumber(formattedPhone)
            uid = existingAuthUser.uid
          } else {
            throw authError
          }
        }
      }

      const customToken = await admin.auth().createCustomToken(uid)
      res.json({ success: true, token: customToken, uid, isNewUser })
    } catch (error) {
      console.error('❌ [OTP] verifyCode error:', error)
      res.status(500).json({ success: false, error: 'Error verificando código' })
    }
  },
)

interface ValidationResult {
  accepted: boolean
  reason?: CheckRejectReason
}

async function validateCode(
  formattedPhone: string,
  code: string,
): Promise<ValidationResult> {
  // Test phones: validación local + auto-create on first use
  if (TEST_PHONE_NUMBERS[formattedPhone]) {
    const expectedCode = TEST_PHONE_NUMBERS[formattedPhone]!
    if (code !== expectedCode) return { accepted: false, reason: 'incorrect' }
    const db = admin.firestore()
    const phoneKey = formattedPhone.replace('+', '')
    const doc = await db.collection(VERIFICATION_COLLECTION).doc(phoneKey).get()
    const docExpired =
      doc.exists &&
      doc.data()?.expiresAt?.toDate &&
      doc.data()!.expiresAt.toDate() < new Date()
    if (!doc.exists || docExpired) {
      await storeTestCode(formattedPhone, expectedCode)
    }
    await db.collection(VERIFICATION_COLLECTION).doc(phoneKey).delete().catch(() => {})
    return { accepted: true }
  }

  // Teléfonos reales: delegar a Telnyx Verify
  const telnyx = new TelnyxVerifyService()
  const result = await telnyx.checkVerification(formattedPhone, code)
  return { accepted: result.accepted, reason: result.reason }
}
