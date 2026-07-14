// Timestamp alias (Firebase retirado del panel)
type Timestamp = { seconds: number; nanoseconds: number } | Date | string

export type RideStatus =
  | 'requested'
  | 'searching'
  | 'searching_driver'
  | 'pending'
  | 'waiting_driver'
  | 'accepted'
  | 'negotiating'
  | 'driver_arriving'
  | 'waiting_verification'
  | 'in_progress'
  | 'completed'
  | 'cancelled'

export type PaymentMethod = 'cash' | 'mercadopago' | 'card'

export interface RideLocation {
  latitude: number
  longitude: number
  address: string
}

export interface Ride {
  id: string
  userId?: string
  passengerId?: string
  driverId?: string
  status: RideStatus
  pickup?: RideLocation
  pickupAddress?: string
  destination?: RideLocation
  destinationAddress?: string
  estimatedFare?: number
  finalFare?: number
  paymentMethod?: PaymentMethod
  paymentProcessed?: boolean
  platformCommission?: number
  driverEarnings?: number
  createdAt?: Timestamp
  acceptedAt?: Timestamp
  startedAt?: Timestamp
  completedAt?: Timestamp
  cancelledAt?: Timestamp
  cancelledBy?: string
  passengerName?: string
  driverName?: string
}
