/**
 * Telnyx Verify Service — OTP por SMS usando Telnyx Verify API.
 *
 * Telnyx Verify maneja generación del código, expiración (5 min default),
 * rate limit y reintentos. Envía SMS usando alphanumeric sender ID
 * ("RapiTeam" en Rapi Team), por lo que NO se necesita comprar un phone
 * number dedicado.
 *
 * Reemplaza Firebase Phone Auth (más caro en Perú y sin alphanumeric).
 *
 * Docs: https://developers.telnyx.com/api-reference/verify
 */

import axios, { AxiosInstance } from 'axios'

export interface StartVerificationResult {
  success: boolean
  /** ID que devuelve Telnyx — útil para correlacionar en logs. */
  verificationId?: string
  /** Indica si el caller debe pedirle al usuario esperar antes de reintentar. */
  rateLimited?: boolean
  /** Saldo agotado → el caller debe ofrecer auth alternativo. */
  noBalance?: boolean
  error?: string
}

export type CheckRejectReason = 'expired' | 'incorrect' | 'unknown'

export interface CheckVerificationResult {
  success: boolean
  /** true solo si Telnyx respondió status="accepted". */
  accepted: boolean
  reason?: CheckRejectReason
  error?: string
}

export class TelnyxVerifyService {
  private client: AxiosInstance
  private verifyProfileId: string

  constructor() {
    const apiKey = process.env.TELNYX_API_KEY
    this.verifyProfileId = process.env.TELNYX_VERIFY_PROFILE_ID || ''

    if (!apiKey) {
      throw new Error('TELNYX_API_KEY no configurado en .env')
    }
    if (!this.verifyProfileId) {
      throw new Error('TELNYX_VERIFY_PROFILE_ID no configurado en .env')
    }

    this.client = axios.create({
      baseURL: 'https://api.telnyx.com/v2',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      timeout: 15000,
    })
  }

  async startVerification(toPhone: string): Promise<StartVerificationResult> {
    try {
      const response = await this.client.post('/verifications/sms', {
        phone_number: toPhone,
        verify_profile_id: this.verifyProfileId,
      })
      const verificationId = response.data?.data?.id
      console.log(`[Telnyx Verify] OTP iniciado a ${toPhone} id=${verificationId}`)
      return { success: true, verificationId }
    } catch (error: unknown) {
      const { msg, isRateLimit, isNoBalance } = this.parseError(error)
      console.error(`[Telnyx Verify] Error iniciando OTP a ${toPhone}: ${msg}`)
      return {
        success: false,
        rateLimited: isRateLimit,
        noBalance: isNoBalance,
        error: msg,
      }
    }
  }

  async checkVerification(
    toPhone: string,
    code: string,
  ): Promise<CheckVerificationResult> {
    try {
      const response = await this.client.post(
        `/verifications/by_phone_number/${encodeURIComponent(toPhone)}/actions/verify`,
        { code, verify_profile_id: this.verifyProfileId },
      )

      // CRÍTICO: Telnyx Verify API v2 trae el resultado en `response_code`
      // (no `status`). Leer mal este campo causaba que TODOS los códigos
      // válidos se reportaran como `incorrect` (bug detectado y fixeado en
      // App-Plus v140 → v142). Fallback a `status` por defensa.
      const apiStatus =
        (response.data?.data?.response_code as string | undefined) ??
        (response.data?.data?.status as string | undefined)
      const accepted = apiStatus === 'accepted'
      console.log(
        `[Telnyx Verify] check ${toPhone}: response_code=${apiStatus} accepted=${accepted}`,
      )
      if (accepted) return { success: true, accepted: true }

      const reason: CheckRejectReason =
        apiStatus === 'expired' || apiStatus === 'timeout' ? 'expired' : 'incorrect'
      return { success: true, accepted: false, reason }
    } catch (error: unknown) {
      const { msg, isExpired } = this.parseError(error)
      console.warn(`[Telnyx Verify] check ${toPhone} falló: ${msg} expired=${isExpired}`)
      return {
        success: true,
        accepted: false,
        reason: isExpired ? 'expired' : 'incorrect',
        error: msg,
      }
    }
  }

  private parseError(error: unknown): {
    msg: string
    isRateLimit: boolean
    isNoBalance: boolean
    isExpired: boolean
  } {
    const e = error as {
      response?: {
        status?: number
        data?: {
          errors?: Array<{ code: string; title: string; detail?: string }>
        }
      }
      message?: string
    }
    const apiError = e?.response?.data?.errors?.[0]
    const httpStatus = e?.response?.status
    const detail = apiError?.detail || ''
    const title = apiError?.title || ''
    const codeStr = apiError?.code || ''

    const isRateLimit =
      httpStatus === 422 &&
      (codeStr === '10015' ||
        codeStr === '10020' ||
        /in progress|pending|already/i.test(detail) ||
        /in progress|pending|already/i.test(title))

    const isNoBalance =
      codeStr === '10003' ||
      codeStr === '40300' ||
      /insufficient|balance|no funds|fund.*low|wallet/i.test(detail) ||
      /insufficient|balance|no funds|fund.*low|wallet/i.test(title)

    const isExpired =
      codeStr === '10019' ||
      /expired|timeout|timed out|caducad/i.test(detail) ||
      /expired|timeout|timed out|caducad/i.test(title)

    const msg = apiError
      ? `Telnyx ${codeStr}: ${title}${detail ? ` (${detail})` : ''}`
      : e?.message || 'Error desconocido'

    return { msg, isRateLimit, isNoBalance, isExpired }
  }
}
