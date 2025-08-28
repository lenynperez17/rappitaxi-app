import '../../../../shared/models/location_model.dart';
import '../../../../shared/models/ride_model.dart';

abstract class RideRepository {
  // Solicitar viaje
  Future<RideModel> requestRide({
    required LocationModel pickup,
    required LocationModel destination,
    required String vehicleType,
    required String paymentMethod,
    required double estimatedFare,
  });
  
  // Obtener viaje actual
  Future<RideModel?> getCurrentRide();
  Stream<RideModel?> watchCurrentRide();
  
  // Obtener historial de viajes
  Future<List<RideModel>> getRideHistory({
    int limit = 20,
    DateTime? startDate,
    DateTime? endDate,
  });
  
  // Obtener detalles de un viaje
  Future<RideModel> getRideDetails(String rideId);
  
  // Cancelar viaje
  Future<void> cancelRide({
    required String rideId,
    required String reason,
  });
  
  // Calificar viaje
  Future<void> rateRide({
    required String rideId,
    required double rating,
    String? comment,
  });
  
  // Actualizar ubicación del viaje
  Future<void> updateRideLocation({
    required String rideId,
    required double latitude,
    required double longitude,
  });
  
  // Obtener ruta del viaje
  Future<List<RoutePoint>> getRideRoute(String rideId);
  
  // Estadísticas
  Future<RideStatistics> getRideStatistics();
  
  // Viajes favoritos/frecuentes
  Future<List<FavoriteRoute>> getFavoriteRoutes();
  Future<void> saveFavoriteRoute({
    required LocationModel pickup,
    required LocationModel destination,
    required String name,
  });
  Future<void> removeFavoriteRoute(String routeId);
}

class RideStatistics {
  final int totalRides;
  final double totalSpent;
  final double totalDistance;
  final int totalTime; // en minutos
  final double averageRating;
  final Map<String, int> ridesByVehicleType;
  final Map<String, double> spentByMonth; // últimos 6 meses
  
  RideStatistics({
    required this.totalRides,
    required this.totalSpent,
    required this.totalDistance,
    required this.totalTime,
    required this.averageRating,
    required this.ridesByVehicleType,
    required this.spentByMonth,
  });
}

class FavoriteRoute {
  final String id;
  final String name;
  final LocationModel pickup;
  final LocationModel destination;
  final int usageCount;
  final DateTime lastUsed;
  
  FavoriteRoute({
    required this.id,
    required this.name,
    required this.pickup,
    required this.destination,
    required this.usageCount,
    required this.lastUsed,
  });
}