
export type VehicleType = 'economy' | 'sedan' | 'premium' | 'suv' | 'van';

export interface VehicleInfo {
  make: string;
  model: string;
  year: number;
  plate: string;
  color: string;
  type: VehicleType;
  capacity: number;
  accessibilityFeatures?: string[];
  petFriendly?: boolean;
  smokingAllowed?: boolean;
}
