import { onDocumentCreated } from 'firebase-functions/v2/firestore'
import * as admin from 'firebase-admin'
import { NotificationService } from '../services/NotificationService'

/**
 * Trigger: cuando se crea una entrada en `walletTransactions/{txnId}` de tipo
 * `recharge` con paymentMethod `admin_manual` (o cualquier recarga aprobada),
 * envía push notification al conductor.
 *
 * Funciona en conjunto con `createManualRecharge` (RechargeHandlers.ts) que
 * escribe atómicamente la transacción.
 */
export const onWalletRechargeCredited = onDocumentCreated(
  'walletTransactions/{txnId}',
  async (event) => {
    const snap = event.data
    if (!snap) return

    const txn = snap.data() as any
    if (!txn || txn.type !== 'recharge' || txn.status !== 'completed') return

    const driverId: string | undefined = txn.userId ?? txn.walletId
    if (!driverId) return

    const netAmount = Number(txn.amount ?? 0)
    if (netAmount <= 0) return

    try {
      const userSnap = await admin.firestore().collection('users').doc(driverId).get()
      if (!userSnap.exists) return
      const userData = userSnap.data() ?? {}

      // Recolectar FCM tokens (varios formatos posibles)
      const tokens: string[] = []
      if (Array.isArray(userData.fcmTokens)) tokens.push(...userData.fcmTokens)
      if (typeof userData.fcmToken === 'string' && userData.fcmToken) tokens.push(userData.fcmToken)
      if (userData.deviceTokens && typeof userData.deviceTokens === 'object') {
        tokens.push(...(Object.values(userData.deviceTokens) as string[]))
      }
      const validTokens = [...new Set(tokens.filter((t) => typeof t === 'string' && t.length > 0))]
      if (validTokens.length === 0) {
        console.log(`No FCM tokens for driver ${driverId}; skipping notif`)
        return
      }

      const isAdminManual = txn.metadata?.paymentMethod === 'admin_manual'
      const title = isAdminManual ? '💰 Recarga acreditada' : '💰 Recarga exitosa'
      const body = `Tu billetera fue recargada con S/ ${netAmount.toFixed(2)}. Ya puedes seguir aceptando viajes.`

      const notif = new NotificationService()
      await notif.sendToTokens(
        validTokens,
        { title, body },
        {
          type: 'wallet_recharge',
          driverId,
          amount: String(netAmount),
          rechargeId: txn.rechargeId ?? '',
        },
        'high',
      )

      console.log(`✅ Push enviada a conductor ${driverId} por recarga S/ ${netAmount}`)
    } catch (err) {
      console.error('Error enviando push de recarga:', err)
    }
  },
)
