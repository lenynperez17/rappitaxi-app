import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/ride_model.dart';
import '../../data/repositories/ride_repository_impl.dart';
import '../../domain/repositories/ride_repository.dart';

// Re-exportar el RideProvider de Firebase para mantener compatibilidad
export '../../../../providers/ride_provider_firebase.dart';

// Provider para el repositorio
final rideRepositoryProvider = Provider<RideRepository>((ref) {
  return RideRepositoryImpl(ref);
});

// Clase para parámetros del historial
class RideHistoryParams {
  final int limit;
  final DateTime? startDate;
  final DateTime? endDate;
  
  RideHistoryParams({
    this.limit = 20,
    this.startDate,
    this.endDate,
  });
}

// Provider para historial de viajes
final rideHistoryProvider = FutureProvider.family<List<RideModel>, RideHistoryParams>((ref, params) async {
  final repository = ref.watch(rideRepositoryProvider);
  return await repository.getRideHistory(
    limit: params.limit,
    startDate: params.startDate,
    endDate: params.endDate,
  );
});

// Provider para estadísticas de viajes
final rideStatisticsProvider = FutureProvider<RideStatistics>((ref) async {
  final repository = ref.watch(rideRepositoryProvider);
  return await repository.getRideStatistics();
});