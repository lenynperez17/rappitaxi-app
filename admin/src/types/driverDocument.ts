import { Timestamp } from 'firebase/firestore'

export type DocumentStatus = 'pending' | 'approved' | 'rejected' | 'expired'

export type DocumentId =
  | 'license'              // Licencia de Conducir
  | 'id_card'              // DNI o Pasaporte
  | 'vehicle_registration' // Tarjeta de Propiedad
  | 'insurance'            // SOAT
  | 'technical_review'     // Revisión Técnica
  | 'background_check'     // Antecedentes Policiales
  | 'bank_account'         // Certificación Bancaria (opcional)

export interface DriverDocument {
  id: DocumentId | string
  name: string
  description?: string
  status: DocumentStatus
  fileUrl?: string | null
  uploadDate?: Timestamp
  expiryDate?: Timestamp
  rejectionReason?: string
  isRequired: boolean
  category?: string
  updatedAt?: Timestamp
}

/**
 * Lista canónica de documentos esperados — debe coincidir con
 * app/lib/screens/driver/documents_screen.dart#requiredDocTypes
 */
export const EXPECTED_DOCUMENTS: ReadonlyArray<{
  id: DocumentId
  name: string
  description: string
  isRequired: boolean
}> = [
  {
    id: 'license',
    name: 'Licencia de Conducir',
    description: 'Licencia de conducir profesional vigente',
    isRequired: true,
  },
  {
    id: 'id_card',
    name: 'Documento de Identidad',
    description: 'DNI o Pasaporte vigente',
    isRequired: true,
  },
  {
    id: 'vehicle_registration',
    name: 'Tarjeta de Propiedad',
    description: 'Registro vehicular vigente',
    isRequired: true,
  },
  {
    id: 'insurance',
    name: 'SOAT',
    description: 'Seguro Obligatorio de Accidentes de Tránsito',
    isRequired: true,
  },
  {
    id: 'technical_review',
    name: 'Revisión Técnica',
    description: 'Certificado de revisión técnica vehicular',
    isRequired: true,
  },
  {
    id: 'background_check',
    name: 'Antecedentes Policiales',
    description: 'Certificado de antecedentes policiales',
    isRequired: true,
  },
  {
    id: 'bank_account',
    name: 'Certificación Bancaria',
    description: 'Certificado de cuenta bancaria para depósitos',
    isRequired: false,
  },
]

export type DriverApprovalStatus =
  | 'pending_documents'
  | 'pending_approval'
  | 'approved'
  | 'rejected'

export interface DriverForVerification {
  id: string
  fullName?: string
  name?: string
  email?: string
  phone?: string
  phoneNumber?: string
  userType: 'driver' | 'dual'
  driverStatus?: DriverApprovalStatus
  documentVerified?: boolean
  createdAt?: Timestamp
  vehicleInfo?: {
    make?: string
    model?: string
    year?: string | number
    plate?: string
    color?: string
  }
  driverProfile?: {
    documentNumber?: string
    licenseNumber?: string
  }
}
