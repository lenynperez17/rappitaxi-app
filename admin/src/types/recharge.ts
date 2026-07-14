// Timestamp alias (Firebase retirado del panel)
type Timestamp = { seconds: number; nanoseconds: number } | Date | string

export type RechargePaymentMethod = 'mercadopago' | 'cash' | 'admin_manual' | 'transfer'
export type RechargeStatus = 'pending' | 'approved' | 'rejected' | 'refunded' | 'cancelled'

export interface DriverRecharge {
  id: string
  driverId: string
  driverName: string
  driverEmail: string
  driverPhone?: string
  driverDocumentType?: 'DNI' | 'RUC' | 'CE' | 'PASAPORTE'
  driverDocumentNumber?: string

  // Amounts (PEN)
  grossAmount: number      // Monto pagado por el conductor
  mpCommission: number     // Comisión MercadoPago 4.49% del bruto
  mpIgv: number            // IGV financiero fijo 0.55 PEN
  totalMpFee: number       // mpCommission + mpIgv
  netAmount: number        // Acreditado al wallet (gross - totalMpFee)

  paymentMethod: RechargePaymentMethod
  mpPaymentId?: string                  // ID de MercadoPago si aplica
  mpPaymentStatus?: 'approved' | 'pending' | 'rejected' | 'in_process'
  mpPreferenceId?: string

  // Invoice link
  invoiceId?: string                    // ID del documento `invoices`
  invoiceNumber?: string                // Ej: B001-00000001 o F001-00000001
  invoiceUrl?: string                   // URL del PDF en Storage

  status: RechargeStatus
  errorMessage?: string

  createdAt: Timestamp
  approvedAt?: Timestamp
  refundedAt?: Timestamp
  createdBy?: string                    // 'system' | adminUid
}
