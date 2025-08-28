import { LocationData, VehicleType } from '@shared/types';

/**
 * Calculate distance between two points using Haversine formula
 * Returns distance in kilometers
 */
export function calculateDistance(point1: LocationData, point2: LocationData): number {
  const R = 6371; // Earth's radius in kilometers
  const dLat = toRad(point2.latitude - point1.latitude);
  const dLon = toRad(point2.longitude - point1.longitude);
  
  const a = 
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(point1.latitude)) * Math.cos(toRad(point2.latitude)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  const distance = R * c;
  
  return Math.round(distance * 100) / 100; // Round to 2 decimal places
}

/**
 * Convert degrees to radians
 */
function toRad(degrees: number): number {
  return degrees * (Math.PI / 180);
}

/**
 * Calculate estimated time based on distance
 * Returns time in minutes
 */
export function calculateEstimatedTime(distanceKm: number): number {
  // Base assumptions:
  // - Average speed in city: 25 km/h
  // - Average speed on highway: 60 km/h
  // - Traffic multiplier: 1.3
  
  let avgSpeed = 25; // km/h for city driving
  
  // If distance is more than 10km, assume some highway driving
  if (distanceKm > 10) {
    const cityPortion = 10;
    const highwayPortion = distanceKm - 10;
    const cityTime = (cityPortion / 25) * 60; // minutes
    const highwayTime = (highwayPortion / 60) * 60; // minutes
    return Math.round((cityTime + highwayTime) * 1.3); // Apply traffic multiplier
  }
  
  const timeHours = distanceKm / avgSpeed;
  const timeMinutes = timeHours * 60;
  
  // Apply traffic multiplier
  return Math.round(timeMinutes * 1.3);
}

/**
 * Calculate fare based on distance, time, and vehicle type
 * Returns fare in ARS (Argentine Pesos)
 */
export function calculateFare(distanceKm: number, timeMinutes: number, vehicleType: VehicleType): number {
  // Base pricing structure (in ARS)
  const pricing = {
    standard: {
      baseFare: 500,        // Base fare
      perKm: 180,           // Per kilometer
      perMinute: 12,        // Per minute
      minimumFare: 800,     // Minimum fare
    },
    premium: {
      baseFare: 700,
      perKm: 250,
      perMinute: 16,
      minimumFare: 1200,
    },
    xl: {
      baseFare: 900,
      perKm: 320,
      perMinute: 20,
      minimumFare: 1500,
    },
  };

  const rates = pricing[vehicleType] || pricing.standard;
  
  // Calculate total fare
  let totalFare = rates.baseFare + (distanceKm * rates.perKm) + (timeMinutes * rates.perMinute);
  
  // Apply minimum fare
  totalFare = Math.max(totalFare, rates.minimumFare);
  
  // Round to nearest peso
  return Math.round(totalFare);
}

/**
 * Calculate surge pricing multiplier based on demand and supply
 */
export function calculateSurgeMultiplier(
  activeRides: number,
  availableDrivers: number,
  location: LocationData,
  currentTime: Date
): { multiplier: number; reason?: string } {
  let multiplier = 1.0;
  let reason = '';

  // Supply/demand ratio
  const demandRatio = activeRides / Math.max(availableDrivers, 1);
  
  if (demandRatio > 3) {
    multiplier = 2.0;
    reason = 'Alta demanda';
  } else if (demandRatio > 2) {
    multiplier = 1.5;
    reason = 'Demanda elevada';
  } else if (demandRatio > 1.5) {
    multiplier = 1.25;
    reason = 'Demanda moderada';
  }

  // Time-based surge (peak hours)
  const hour = currentTime.getHours();
  const isPeakHour = (hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 20);
  
  if (isPeakHour) {
    multiplier = Math.max(multiplier, 1.3);
    if (reason) reason += ' - Hora pico';
    else reason = 'Hora pico';
  }

  // Weather-based surge (this would integrate with weather API)
  // For now, simulate random weather events
  const isWeatherEvent = Math.random() < 0.1; // 10% chance
  if (isWeatherEvent) {
    multiplier = Math.max(multiplier, 1.4);
    if (reason) reason += ' - Condiciones climáticas';
    else reason = 'Condiciones climáticas';
  }

  // Special events/areas (this would be configured per city)
  const isSpecialArea = isSpecialEventArea(location, currentTime);
  if (isSpecialArea.active) {
    multiplier = Math.max(multiplier, isSpecialArea.multiplier);
    if (reason) reason += ` - ${isSpecialArea.reason}`;
    else reason = isSpecialArea.reason;
  }

  // Cap maximum surge at 3x
  multiplier = Math.min(multiplier, 3.0);

  return { multiplier: Math.round(multiplier * 100) / 100, reason };
}

/**
 * Check if location is in special event area
 */
function isSpecialEventArea(location: LocationData, currentTime: Date): {
  active: boolean;
  multiplier: number;
  reason: string;
} {
  // This would integrate with a database of special events and areas
  // For now, simulate some common scenarios
  
  const specialAreas = [
    {
      name: 'Aeropuerto Internacional',
      center: { latitude: -34.8222, longitude: -58.5358 }, // Ezeiza
      radius: 5, // km
      multiplier: 1.5,
      reason: 'Zona aeroportuaria',
    },
    {
      name: 'Puerto Madero',
      center: { latitude: -34.6118, longitude: -58.3630 },
      radius: 2,
      multiplier: 1.3,
      reason: 'Zona premium',
    },
    {
      name: 'Palermo',
      center: { latitude: -34.5895, longitude: -58.4203 },
      radius: 3,
      multiplier: 1.2,
      reason: 'Zona de entretenimiento',
      timeRestriction: { start: 20, end: 4 }, // 8 PM to 4 AM
    },
  ];

  for (const area of specialAreas) {
    const distance = calculateDistance(location, area.center);
    
    if (distance <= area.radius) {
      // Check time restriction if exists
      if (area.timeRestriction) {
        const hour = currentTime.getHours();
        const { start, end } = area.timeRestriction;
        
        const isInTimeRange = end < start 
          ? (hour >= start || hour <= end) // Crosses midnight
          : (hour >= start && hour <= end); // Same day
        
        if (!isInTimeRange) continue;
      }
      
      return {
        active: true,
        multiplier: area.multiplier,
        reason: area.reason,
      };
    }
  }

  return { active: false, multiplier: 1.0, reason: '' };
}

/**
 * Calculate ETA (Estimated Time of Arrival)
 */
export function calculateETA(
  driverLocation: LocationData,
  pickupLocation: LocationData,
  destinationLocation: LocationData
): {
  etaToPickup: number; // minutes
  etaToDestination: number; // minutes
  totalEta: number; // minutes
} {
  const distanceToPickup = calculateDistance(driverLocation, pickupLocation);
  const distanceToDestination = calculateDistance(pickupLocation, destinationLocation);
  
  const etaToPickup = calculateEstimatedTime(distanceToPickup);
  const etaToDestination = calculateEstimatedTime(distanceToDestination);
  
  return {
    etaToPickup,
    etaToDestination,
    totalEta: etaToPickup + etaToDestination,
  };
}

/**
 * Calculate driver score for ride matching
 */
export function calculateDriverScore(
  driverLocation: LocationData,
  pickupLocation: LocationData,
  driverData: {
    rating: number;
    totalRides: number;
    acceptanceRate: number;
    cancellationRate: number;
  }
): number {
  const distance = calculateDistance(driverLocation, pickupLocation);
  
  // Distance score (closer is better, max 10 points)
  const distanceScore = Math.max(0, 10 - distance);
  
  // Rating score (max 5 points)
  const ratingScore = driverData.rating;
  
  // Experience score (max 3 points)
  const experienceScore = Math.min(3, driverData.totalRides / 100);
  
  // Reliability score (max 2 points)
  const reliabilityScore = (driverData.acceptanceRate * 1.2) - (driverData.cancellationRate * 0.8);
  
  // Total score
  const totalScore = distanceScore + ratingScore + experienceScore + reliabilityScore;
  
  return Math.round(totalScore * 100) / 100;
}

/**
 * Calculate cancellation fee
 */
export function calculateCancellationFee(
  rideCreatedAt: Date,
  driverAssignedAt: Date | null,
  currentTime: Date,
  baseFare: number
): number {
  const timeSinceCreation = (currentTime.getTime() - rideCreatedAt.getTime()) / (1000 * 60); // minutes
  
  // No fee if cancelled within 2 minutes of creation
  if (timeSinceCreation <= 2) {
    return 0;
  }
  
  // No fee if no driver assigned yet
  if (!driverAssignedAt) {
    return 0;
  }
  
  const timeSinceDriverAssigned = (currentTime.getTime() - driverAssignedAt.getTime()) / (1000 * 60);
  
  // No fee if cancelled within 1 minute of driver assignment
  if (timeSinceDriverAssigned <= 1) {
    return 0;
  }
  
  // Standard cancellation fee: 20% of base fare, minimum 300 ARS
  const cancellationFee = Math.max(300, baseFare * 0.2);
  
  return Math.round(cancellationFee);
}

/**
 * Calculate dynamic pricing based on various factors
 */
export function calculateDynamicPricing(
  baseFare: number,
  factors: {
    demandMultiplier: number;
    weatherMultiplier: number;
    timeMultiplier: number;
    areaMultiplier: number;
    driverIncentive: number;
  }
): {
  adjustedFare: number;
  breakdown: {
    base: number;
    demand: number;
    weather: number;
    time: number;
    area: number;
    incentive: number;
  };
} {
  const breakdown = {
    base: baseFare,
    demand: baseFare * (factors.demandMultiplier - 1),
    weather: baseFare * (factors.weatherMultiplier - 1),
    time: baseFare * (factors.timeMultiplier - 1),
    area: baseFare * (factors.areaMultiplier - 1),
    incentive: factors.driverIncentive,
  };
  
  const adjustedFare = Math.round(
    baseFare * 
    factors.demandMultiplier * 
    factors.weatherMultiplier * 
    factors.timeMultiplier * 
    factors.areaMultiplier +
    factors.driverIncentive
  );
  
  return { adjustedFare, breakdown };
}