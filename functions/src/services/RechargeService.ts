import * as admin from 'firebase-admin'
import { calculateRechargeBreakdown } from '../utils/mercadopagoFees'

/**
 * RechargeService
 * ----------------
 * Centraliza el flujo de recargas de conductores via MercadoPago.
 *
 * Flujo:
 * 1. Webhook MercadoPago notifica un pago aprobado
 * 2. Se calcula el desglose (gross / commission / igv / net)
 * 3. Se crea documento en `driverRecharges/{id}` con el desglose completo
 * 4. Se acredita SOLO el `netAmount` al wallet del conductor
 * 5. Se registra entry en `walletTransactions` con metadata
 *
 * El monto bruto NUNCA se acredita: la comision MercadoPago se descuenta antes.
 */

export interface CreateRechargeInput {
  driverId: string
  driverName: string
  driverEmail: string
  driverPhone?: string
  driverDocumentType?: 'DNI' | 'RUC' | 'CE' | 'PASAPORTE'
  driverDocumentNumber?: string

  grossAmount: number
  paymentMethod: 'mercadopago' | 'cash' | 'admin_manual' | 'transfer'
  mpPaymentId?: string
  mpPreferenceId?: string
  mpPaymentStatus?: 'approved' | 'pending' | 'rejected' | 'in_process'

  createdBy?: string // 'system' | adminUid
}

export interface RechargeRecord {
  id: string
  driverId: string
  driverName: string
  driverEmail: string
  driverPhone?: string
  driverDocumentType?: string
  driverDocumentNumber?: string

  grossAmount: number
  mpCommission: number
  mpIgv: number
  totalMpFee: number
  netAmount: number

  paymentMethod: string
  mpPaymentId?: string
  mpPreferenceId?: string
  mpPaymentStatus?: string

  status: 'pending' | 'approved' | 'rejected' | 'refunded'
  invoiceId?: string
  invoiceNumber?: string
  invoiceUrl?: string

  createdAt: admin.firestore.Timestamp
  approvedAt?: admin.firestore.Timestamp
  refundedAt?: admin.firestore.Timestamp
  createdBy?: string
}

export class RechargeService {
  private readonly db: admin.firestore.Firestore

  constructor() {
    this.db = admin.firestore()
  }

  /**
   * Crea una recarga aprobada y acredita el monto neto al wallet.
   * Idempotente: si ya existe una recarga con el mismo `mpPaymentId`,
   * retorna la existente sin duplicar.
   */
  async createApprovedRecharge(input: CreateRechargeInput): Promise<RechargeRecord> {
    if (!input.driverId) throw new Error('driverId es requerido')
    if (!input.grossAmount || input.grossAmount <= 0) throw new Error('grossAmount invalido')

    // Idempotencia: chequear si ya existe por mpPaymentId
    if (input.mpPaymentId) {
      const existing = await this.db
        .collection('driverRecharges')
        .where('mpPaymentId', '==', input.mpPaymentId)
        .limit(1)
        .get()
      if (!existing.empty) {
        const doc = existing.docs[0]
        return { id: doc.id, ...(doc.data() as Omit<RechargeRecord, 'id'>) }
      }
    }

    const breakdown = calculateRechargeBreakdown(input.grossAmount)
    const now = admin.firestore.Timestamp.now()
    const rechargeRef = this.db.collection('driverRecharges').doc()

    const rechargeData: Omit<RechargeRecord, 'id'> = {
      driverId: input.driverId,
      driverName: input.driverName,
      driverEmail: input.driverEmail,
      driverPhone: input.driverPhone,
      driverDocumentType: input.driverDocumentType,
      driverDocumentNumber: input.driverDocumentNumber,

      grossAmount: breakdown.grossAmount,
      mpCommission: breakdown.mpCommission,
      mpIgv: breakdown.mpIgv,
      totalMpFee: breakdown.totalMpFee,
      netAmount: breakdown.netAmount,

      paymentMethod: input.paymentMethod,
      mpPaymentId: input.mpPaymentId,
      mpPreferenceId: input.mpPreferenceId,
      mpPaymentStatus: input.mpPaymentStatus ?? 'approved',

      status: 'approved',
      createdAt: now,
      approvedAt: now,
      createdBy: input.createdBy ?? 'system',
    }

    // Atomic transaction. Firestore exige: TODAS las lecturas antes de TODAS las escrituras.
    await this.db.runTransaction(async (tx) => {
      const walletRef = this.db.collection('wallets').doc(input.driverId)

      // FASE 1: lecturas
      const walletSnap = await tx.get(walletRef)

      // FASE 2: escrituras
      tx.set(rechargeRef, rechargeData)

      if (walletSnap.exists) {
        tx.update(walletRef, {
          balance: admin.firestore.FieldValue.increment(breakdown.netAmount),
          totalEarnings: admin.firestore.FieldValue.increment(breakdown.netAmount),
          lastActivityDate: now,
        })
      } else {
        tx.set(walletRef, {
          userId: input.driverId,
          balance: breakdown.netAmount,
          totalEarnings: breakdown.netAmount,
          totalWithdrawals: 0,
          pendingBalance: 0,
          currency: 'PEN',
          status: 'active',
          createdAt: now,
          lastActivityDate: now,
        })
      }

      // Log wallet transaction
      const txnRef = this.db.collection('walletTransactions').doc()
      tx.set(txnRef, {
        walletId: input.driverId,
        userId: input.driverId,
        type: 'recharge',
        amount: breakdown.netAmount,
        status: 'completed',
        description: `Recarga MercadoPago - bruto S/ ${breakdown.grossAmount.toFixed(2)}, neto S/ ${breakdown.netAmount.toFixed(2)}`,
        rechargeId: rechargeRef.id,
        metadata: {
          paymentMethod: input.paymentMethod,
          mpPaymentId: input.mpPaymentId,
          mpPreferenceId: input.mpPreferenceId,
          grossAmount: breakdown.grossAmount,
          mpCommission: breakdown.mpCommission,
          mpIgv: breakdown.mpIgv,
          totalMpFee: breakdown.totalMpFee,
          netAmount: breakdown.netAmount,
          effectiveFeePercentage: breakdown.effectiveFeePercentage,
        },
        createdAt: now,
      })
    })

    console.log(`✅ Recarga aprobada: ${rechargeRef.id}`)
    console.log(`   Conductor: ${input.driverName} (${input.driverId})`)
    console.log(`   Bruto: S/ ${breakdown.grossAmount.toFixed(2)}`)
    console.log(`   Comision MP: S/ ${breakdown.totalMpFee.toFixed(2)}`)
    console.log(`   Neto acreditado: S/ ${breakdown.netAmount.toFixed(2)}`)

    return { id: rechargeRef.id, ...rechargeData }
  }

  /**
   * Marca una recarga como rechazada (sin acreditar wallet).
   */
  async createRejectedRecharge(input: CreateRechargeInput, reason?: string): Promise<RechargeRecord> {
    const breakdown = calculateRechargeBreakdown(input.grossAmount)
    const now = admin.firestore.Timestamp.now()
    const rechargeRef = this.db.collection('driverRecharges').doc()

    const data: Omit<RechargeRecord, 'id'> = {
      driverId: input.driverId,
      driverName: input.driverName,
      driverEmail: input.driverEmail,
      driverPhone: input.driverPhone,
      driverDocumentType: input.driverDocumentType,
      driverDocumentNumber: input.driverDocumentNumber,
      grossAmount: breakdown.grossAmount,
      mpCommission: breakdown.mpCommission,
      mpIgv: breakdown.mpIgv,
      totalMpFee: breakdown.totalMpFee,
      netAmount: breakdown.netAmount,
      paymentMethod: input.paymentMethod,
      mpPaymentId: input.mpPaymentId,
      mpPreferenceId: input.mpPreferenceId,
      mpPaymentStatus: 'rejected',
      status: 'rejected',
      createdAt: now,
      createdBy: input.createdBy ?? 'system',
    }
    await rechargeRef.set({ ...data, errorMessage: reason })
    return { id: rechargeRef.id, ...data }
  }
}
