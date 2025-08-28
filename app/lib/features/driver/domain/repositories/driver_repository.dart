import '../entities/ride_request.dart';
import '../../../../shared/models/ride_model.dart';

abstract class DriverRepository {
  // Estado del conductor
  Stream<String> getDriverStatus();
  Future<void> updateDriverStatus(String status);
  
  // Solicitudes de viaje
  Stream<List<RideRequest>> getRideRequests();
  Future<void> acceptRideRequest(String requestId);
  Future<void> rejectRideRequest(String requestId);
  
  // Viaje actual
  Stream<RideModel?> getCurrentRide();
  Future<void> startRide(String rideId);
  Future<void> completeRide(String rideId);
  Future<void> cancelRide(String rideId, String reason);
  
  // Ubicación
  Future<void> updateDriverLocation(double latitude, double longitude);
  
  // Ganancias
  Future<double> getTodayEarnings();
  Future<double> getWeeklyEarnings();
  Future<double> getMonthlyEarnings();
  Future<List<RideModel>> getEarningsHistory(DateTime startDate, DateTime endDate);
  
  // Calificación
  Future<double> getDriverRating();
  Future<int> getTotalTrips();
}