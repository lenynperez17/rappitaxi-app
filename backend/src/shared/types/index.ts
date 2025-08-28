// User Types
export interface User {
  id: string;
  email: string;
  phone: string;
  name: string;
  photoUrl?: string;
  role: 'passenger' | 'driver' | 'admin';
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
  
  // Role specific data
  passengerData?: PassengerData;
  driverData?: DriverData;
  adminData?: AdminData;
}

export interface PassengerData {
  preferredPaymentMethod: string;
  homeAddress?: LocationData;
  workAddress?: LocationData;
  rating: number;
  totalRides: number;
  favoriteDrivers: string[];
  emergencyContact?: EmergencyContact;
}

export interface DriverData {
  licenseNumber: string;
  licenseExpiry: Date;
  vehicleInfo: VehicleInfo;
  documents: DriverDocument[];
  bankAccount: BankAccount;
  rating: number;
  totalRides: number;
  totalEarnings: number;
  isOnline: boolean;
  isAvailable: boolean;
  currentLocation?: LocationData;
  serviceAreas: string[];
  workingHours?: WorkingHours;
}

export interface AdminData {
  permissions: AdminPermission[];
  department: string;
  lastLogin: Date;
}

// Location Types
export interface LocationData {
  latitude: number;
  longitude: number;
  address: string;
  city: string;
  state: string;
  country: string;
  postalCode?: string;
  placeId?: string;
}

// Ride Types
export interface Ride {
  id: string;
  passengerId: string;
  driverId?: string;
  status: RideStatus;
  pickup: LocationData;
  destination: LocationData;
  vehicleType: VehicleType;
  paymentMethod: PaymentMethod;
  fare: number;
  distance: number;
  duration: number;
  createdAt: Date;
  updatedAt: Date;
  startedAt?: Date;
  completedAt?: Date;
  cancelledAt?: Date;
  cancellationReason?: string;
  notes?: string;
  rating?: RideRating;
}

export enum RideStatus {
  PENDING = 'pending',
  DRIVER_ASSIGNED = 'driver_assigned',
  DRIVER_ARRIVED = 'driver_arrived',
  IN_PROGRESS = 'in_progress',
  COMPLETED = 'completed',
  CANCELLED = 'cancelled',
}

export enum VehicleType {
  STANDARD = 'standard',
  PREMIUM = 'premium',
  XL = 'xl',
}

export enum PaymentMethod {
  CASH = 'cash',
  CREDIT_CARD = 'credit_card',
  MERCADO_PAGO = 'mercado_pago',
  WALLET = 'wallet',
}

// Vehicle Types
export interface VehicleInfo {
  make: string;
  model: string;
  year: number;
  color: string;
  licensePlate: string;
  type: VehicleType;
  capacity: number;
  photos: string[];
}

// Payment Types
export interface Payment {
  id: string;
  rideId: string;
  userId: string;
  amount: number;
  currency: string;
  method: PaymentMethod;
  status: PaymentStatus;
  gatewayTransactionId?: string;
  gatewayResponse?: any;
  createdAt: Date;
  processedAt?: Date;
  failedAt?: Date;
  refundedAt?: Date;
  metadata?: Record<string, any>;
}

export enum PaymentStatus {
  PENDING = 'pending',
  PROCESSING = 'processing',
  COMPLETED = 'completed',
  FAILED = 'failed',
  REFUNDED = 'refunded',
  CANCELLED = 'cancelled',
}

// Notification Types
export interface Notification {
  id: string;
  userId: string;
  type: NotificationType;
  title: string;
  body: string;
  data?: Record<string, any>;
  read: boolean;
  createdAt: Date;
  readAt?: Date;
}

export enum NotificationType {
  RIDE_REQUEST = 'ride_request',
  RIDE_ASSIGNED = 'ride_assigned',
  RIDE_STARTED = 'ride_started',
  RIDE_COMPLETED = 'ride_completed',
  RIDE_CANCELLED = 'ride_cancelled',
  PAYMENT_PROCESSED = 'payment_processed',
  PAYMENT_FAILED = 'payment_failed',
  DRIVER_RATING = 'driver_rating',
  SYSTEM_UPDATE = 'system_update',
  PROMOTION = 'promotion',
}

// Supporting Types
export interface EmergencyContact {
  name: string;
  phone: string;
  relationship: string;
}

export interface DriverDocument {
  type: DocumentType;
  url: string;
  verified: boolean;
  expiryDate?: Date;
  verifiedAt?: Date;
  verifiedBy?: string;
}

export enum DocumentType {
  LICENSE = 'license',
  INSURANCE = 'insurance',
  REGISTRATION = 'registration',
  IDENTITY = 'identity',
  BACKGROUND_CHECK = 'background_check',
}

export interface BankAccount {
  bankName: string;
  accountNumber: string;
  accountType: string;
  routingNumber?: string;
  verified: boolean;
}

export interface WorkingHours {
  monday?: TimeSlot[];
  tuesday?: TimeSlot[];
  wednesday?: TimeSlot[];
  thursday?: TimeSlot[];
  friday?: TimeSlot[];
  saturday?: TimeSlot[];
  sunday?: TimeSlot[];
}

export interface TimeSlot {
  start: string; // HH:mm format
  end: string;   // HH:mm format
}

export interface RideRating {
  passengerId: string;
  driverId: string;
  passengerRating: number;
  driverRating: number;
  passengerComment?: string;
  driverComment?: string;
  createdAt: Date;
}

export interface AdminPermission {
  resource: string;
  actions: string[];
}

// API Response Types
export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  error?: ApiError;
  pagination?: PaginationInfo;
  timestamp: string;
}

export interface ApiError {
  code: string;
  message: string;
  details?: any;
}

export interface PaginationInfo {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
  hasNext: boolean;
  hasPrev: boolean;
}

// Request Types
export interface CreateRideRequest {
  pickup: LocationData;
  destination: LocationData;
  vehicleType: VehicleType;
  paymentMethod: PaymentMethod;
  notes?: string;
}

export interface UpdateRideStatusRequest {
  status: RideStatus;
  location?: LocationData;
  notes?: string;
}

export interface CreatePaymentRequest {
  rideId: string;
  amount: number;
  method: PaymentMethod;
  paymentToken?: string;
}

// Configuration Types
export interface AppConfig {
  ridePricing: RidePricingConfig;
  paymentConfig: PaymentConfig;
  notificationConfig: NotificationConfig;
  businessRules: BusinessRulesConfig;
}

export interface RidePricingConfig {
  baseFare: number;
  perKmRate: number;
  perMinuteRate: number;
  minimumFare: number;
  surgePricing: SurgePricingConfig;
}

export interface SurgePricingConfig {
  enabled: boolean;
  multiplier: number;
  triggers: SurgeTrigger[];
}

export interface SurgeTrigger {
  condition: string;
  multiplier: number;
  duration: number;
}

export interface PaymentConfig {
  supportedMethods: PaymentMethod[];
  merchantAccounts: Record<string, any>;
  webhookEndpoints: Record<string, string>;
}

export interface NotificationConfig {
  fcmServerKey: string;
  templates: Record<NotificationType, NotificationTemplate>;
}

export interface NotificationTemplate {
  title: string;
  body: string;
  icon?: string;
  sound?: string;
}

export interface BusinessRulesConfig {
  maxRideRadius: number;
  maxDriversPerRequest: number;
  rideTimeoutMinutes: number;
  driverResponseTimeoutSeconds: number;
  cancelFeeThresholdMinutes: number;
  refundPolicyHours: number;
}