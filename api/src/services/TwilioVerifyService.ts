/**
 * Twilio Verify Service — OTP por SMS usando Twilio Verify API v2.
 *
 * Reemplaza al TelnyxVerifyService que usaba App-Plus (v140+). Twilio Verify
 * maneja generación del código, TTL, rate limit y Fraud Guard nativos.
 *
 * Sender ID: "Rapi Team" — configurado en Twilio Verify Service Console
 * (Branded Sender). No requiere phone number dedicado.
 *
 * Env vars:
 *   TWILIO_ACCOUNT_SID          (ACxxx...)
 *   TWILIO_AUTH_TOKEN           (32 hex chars)
 *   TWILIO_VERIFY_SERVICE_SID   (VAxxx...)
 *
 * Docs: https://www.twilio.com/docs/verify/api
 */

import twilio, { Twilio } from 'twilio'

export interface StartVerificationResult {
  success: boolean
  verificationSid?: string
  rateLimited?: boolean
  noBalance?: boolean
  error?: string
}

export type CheckRejectReason = 'expired' | 'incorrect' | 'unknown'

export interface CheckVerificationResult {
  success: boolean
  accepted: boolean
  reason?: CheckRejectReason
  error?: string
}

export class TwilioVerifyService {
  private client: Twilio
  private serviceSid: string

  constructor() {
    const accountSid = process.env.TWILIO_ACCOUNT_SID
    const authToken = process.env.TWILIO_AUTH_TOKEN
    this.serviceSid = process.env.TWILIO_VERIFY_SERVICE_SID || ''

    if (!accountSid) throw new Error('TWILIO_ACCOUNT_SID no configurado')
    if (!authToken) throw new Error('TWILIO_AUTH_TOKEN no configurado')
    if (!this.serviceSid) throw new Error('TWILIO_VERIFY_SERVICE_SID no configurado')

    this.client = twilio(accountSid, authToken)
  }

  async startVerification(toPhone: string): Promise<StartVerificationResult> {
    try {
      const v = await this.client.verify.v2
        .services(this.serviceSid)
        .verifications
        .create({ to: toPhone, channel: 'sms' })

      console.log(`[Twilio Verify] OTP iniciado a ${toPhone} sid=${v.sid} status=${v.status}`)
      return { success: true, verificationSid: v.sid }
    } catch (error: unknown) {
      const { msg, isRateLimit, isNoBalance } = this.parseError(error)
      console.error(`[Twilio Verify] Error iniciando OTP a ${toPhone}: ${msg}`)
      return { success: false, rateLimited: isRateLimit, noBalance: isNoBalance, error: msg }
    }
  }

  async checkVerification(toPhone: string, code: string): Promise<CheckVerificationResult> {
    try {
      const check = await this.client.verify.v2
        .services(this.serviceSid)
        .verificationChecks
        .create({ to: toPhone, code })

      const accepted = check.status === 'approved'
      console.log(`[Twilio Verify] check ${toPhone}: status=${check.status} accepted=${accepted}`)
      if (accepted) return { success: true, accepted: true }

      // Otros status: 'pending', 'canceled'. Twilio ya no diferencia expirado
      // vs incorrecto — trata todo como incorrecto.
      return { success: true, accepted: false, reason: 'incorrect' }
    } catch (error: unknown) {
      const { msg, isExpired, isNotFound } = this.parseError(error)
      console.warn(`[Twilio Verify] check ${toPhone} falló: ${msg}`)
      return {
        success: true,
        accepted: false,
        reason: isExpired || isNotFound ? 'expired' : 'incorrect',
        error: msg,
      }
    }
  }

  /**
   * Normaliza errores de Twilio (formato { code, message, moreInfo, status }).
   *
   * Códigos relevantes:
   *   60200 — Invalid parameter (ej phone_number mal formateado)
   *   60203 — Max send attempts reached (rate limit)
   *   60212 — Too many concurrent requests for phone number
   *   60510 — Verification not found (expiró después de 10 min)
   *   60600 — Fraud detection triggered
   *   20003 — Authentication failed
   *   20429 — Too many requests
   */
  private parseError(error: unknown): {
    msg: string
    isRateLimit: boolean
    isNoBalance: boolean
    isExpired: boolean
    isNotFound: boolean
  } {
    const e = error as {
      code?: number | string
      message?: string
      status?: number
      moreInfo?: string
    }
    const code = String(e?.code ?? '')
    const msg = e?.message || 'Error desconocido'
    const httpStatus = e?.status ?? 0

    const isRateLimit =
      code === '60203' ||
      code === '60212' ||
      code === '20429' ||
      httpStatus === 429 ||
      /max.*attempts|too many|rate limit/i.test(msg)

    const isNoBalance =
      code === '20005' ||
      /insufficient|balance|funds/i.test(msg)

    const isExpired =
      code === '60510' ||
      /expired|not found|no verification/i.test(msg)

    const isNotFound = code === '60510'

    return { msg: `Twilio ${code}: ${msg}`, isRateLimit, isNoBalance, isExpired, isNotFound }
  }
}
