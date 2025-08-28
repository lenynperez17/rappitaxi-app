import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/ride_model.dart';
import '../../data/repositories/driver_repository_impl.dart';
import '../../domain/entities/ride_request.dart';
import '../../domain/repositories/driver_repository.dart';

// Provider del repositorio
final driverRepositoryProvider = Provider<DriverRepository>((ref) {
  return DriverRepositoryImpl(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
  );
});

// Provider para el estado del conductor
final driverStatusProvider = StreamProvider<String>((ref) {
  final repository = ref.watch(driverRepositoryProvider);
  return repository.getDriverStatus();
});

// Provider para actualizar el estado del conductor
final driverStatusNotifierProvider = StateNotifierProvider<DriverStatusNotifier, AsyncValue<void>>((ref) {
  return DriverStatusNotifier(ref.watch(driverRepositoryProvider));
});

class DriverStatusNotifier extends StateNotifier<AsyncValue<void>> {
  final DriverRepository _repository;
  
  DriverStatusNotifier(this._repository) : super(const AsyncValue.data(null));
  
  Future<void> updateStatus(String status) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateDriverStatus(status);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

// Provider para las solicitudes de viaje
final rideRequestsProvider = StreamProvider<List<RideRequest>>((ref) {
  final repository = ref.watch(driverRepositoryProvider);
  return repository.getRideRequests();
});

// Provider para el viaje actual
final currentDriverRideProvider = StreamProvider<RideModel?>((ref) {
  final repository = ref.watch(driverRepositoryProvider);
  return repository.getCurrentRide();
});

// Provider para las ganancias de hoy
final todayEarningsProvider = FutureProvider<double>((ref) async {
  final repository = ref.watch(driverRepositoryProvider);
  return repository.getTodayEarnings();
});

// Provider para la calificación del conductor
final driverRatingProvider = FutureProvider<double>((ref) async {
  final repository = ref.watch(driverRepositoryProvider);
  return repository.getDriverRating();
});

// Provider para el total de viajes
final totalTripsProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(driverRepositoryProvider);
  return repository.getTotalTrips();
});

// Provider para aceptar/rechazar solicitudes
final rideRequestActionsProvider = Provider((ref) {
  final repository = ref.watch(driverRepositoryProvider);
  return RideRequestActions(repository);
});

class RideRequestActions {
  final DriverRepository _repository;
  
  RideRequestActions(this._repository);
  
  Future<void> acceptRequest(String requestId) async {
    await _repository.acceptRideRequest(requestId);
  }
  
  Future<void> rejectRequest(String requestId) async {
    await _repository.rejectRideRequest(requestId);
  }
}

// Provider para acciones del viaje actual
final currentRideActionsProvider = Provider((ref) {
  final repository = ref.watch(driverRepositoryProvider);
  return CurrentRideActions(repository);
});

class CurrentRideActions {
  final DriverRepository _repository;
  
  CurrentRideActions(this._repository);
  
  Future<void> startRide(String rideId) async {
    await _repository.startRide(rideId);
  }
  
  Future<void> completeRide(String rideId) async {
    await _repository.completeRide(rideId);
  }
  
  Future<void> cancelRide(String rideId, String reason) async {
    await _repository.cancelRide(rideId, reason);
  }
}