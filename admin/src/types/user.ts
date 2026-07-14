// Timestamp alias (Firebase retirado del panel)
type Timestamp = { seconds: number; nanoseconds: number } | Date | string

export type UserType = 'admin' | 'driver' | 'passenger' | 'dual'
export type DriverStatus = 'pending_approval' | 'approved' | 'suspended' | 'rejected'

export interface GeoLocation {
  lat: number
  lng: number
}

export interface User {
  id: string
  name?: string
  fullName?: string
  email: string
  phone?: string
  phoneNumber?: string
  userType: UserType
  isAdmin?: boolean
  isOnline?: boolean
  balance?: number
  fcmToken?: string
  currentLocation?: GeoLocation
  driverStatus?: DriverStatus
  createdAt?: Timestamp
  rating?: number
  totalTrips?: number
  profilePhotoUrl?: string
  // Documento for billing
  documentType?: 'DNI' | 'RUC' | 'CE' | 'PASAPORTE'
  documentNumber?: string
  fiscalAddress?: string
  // Mode flags
  activeMode?: 'driver' | 'passenger'
  availableRoles?: string[]
  isVerified?: boolean
  isActive?: boolean
}

export interface VehicleInfo {
  type: string
  color: string
  year: number
  brand: string
  model: string
}

export interface Driver {
  id: string
  currentLocation?: GeoLocation
  isAvailable: boolean
  licensePlate: string
  vehicleInfo: VehicleInfo
  driverStatus: DriverStatus
}

export interface Wallet {
  id: string
  userId: string
  balance: number
  totalEarnings: number
  totalWithdrawals?: number
  pendingBalance?: number
  serviceCredits?: number
  currency?: 'PEN'
  status?: 'active' | 'suspended'
}
