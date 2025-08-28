import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/crash_reporting_service.dart';
import 'package:rappitaxi_app/shared/utils/logger.dart';
import '../../../../shared/models/location_model.dart';
import '../../../../shared/models/ride_model.dart';
import '../../domain/repositories/ride_repository.dart';

class RideRepositoryImpl implements RideRepository {
  final Ref _ref;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();
  
  RideRepositoryImpl(this._ref)
      : _auth = FirebaseAuth.instance,
        _firestore = FirebaseFirestore.instance;
  
  AnalyticsService get _analytics => _ref.read(analyticsServiceProvider);
  CrashReportingService get _crashReporting => _ref.read(crashReportingServiceProvider);
  
  @override
  Future<RideModel> requestRide({
    required LocationModel pickup,
    required LocationModel destination,
    required String vehicleType,
    required String paymentMethod,
    required double estimatedFare,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('Usuario no autenticado');
      
      final rideId = _uuid.v4();
      final ride = RideModel(
        id: rideId,
        passengerId: userId,
        driverId: '', // Se asignará cuando un conductor acepte
        pickup: pickup,
        destination: destination,
        requestedAt: DateTime.now(),
        status: 'requested',
        vehicleType: vehicleType,
        fare: estimatedFare,
        distance: 0, // Se calculará durante el viaje
        duration: 0, // Se calculará durante el viaje
        paymentMethod: paymentMethod,
      );
      
      // Guardar en Firestore
      await _firestore.collection('rides').doc(rideId).set(
        ride.toJson()..['requestedAt'] = FieldValue.serverTimestamp(),
      );
      
      // Analytics
      await _analytics.logRideRequested(
        pickupAddress: pickup.address,
        destinationAddress: destination.address,
        vehicleType: vehicleType,
        estimatedFare: estimatedFare,
      );
      
      Logger.info('Ride requested', {'rideId': rideId});
      
      return ride;
    } catch (e, stack) {
      Logger.error('Error requesting ride', e, stack);
      await _crashReporting.recordError(e, stack);
      rethrow;
    }
  }
  
  @override
  Future<RideModel?> getCurrentRide() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;
      
      final snapshot = await _firestore
          .collection('rides')
          .where('passengerId', isEqualTo: userId)
          .where('status', whereIn: ['requested', 'accepted', 'arriving', 'in_progress'])
          .orderBy('requestedAt', descending: true)
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) return null;
      
      final data = snapshot.docs.first.data();
      data['id'] = snapshot.docs.first.id;
      
      return RideModel.fromJson(data);
    } catch (e, stack) {
      Logger.error('Error getting current ride', e, stack);
      _crashReporting.recordError(e, stack);
      return null;
    }
  }
  
  @override
  Stream<RideModel?> watchCurrentRide() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value(null);
    
    return _firestore
        .collection('rides')
        .where('passengerId', isEqualTo: userId)
        .where('status', whereIn: ['requested', 'accepted', 'arriving', 'in_progress'])
        .orderBy('requestedAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          
          final data = snapshot.docs.first.data();
          data['id'] = snapshot.docs.first.id;
          
          return RideModel.fromJson(data);
        });
  }
  
  @override
  Future<List<RideModel>> getRideHistory({
    int limit = 20,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];
      
      Query<Map<String, dynamic>> query = _firestore
          .collection('rides')
          .where('passengerId', isEqualTo: userId)
          .where('status', whereIn: ['completed', 'cancelled']);
      
      if (startDate != null) {
        query = query.where('requestedAt', isGreaterThanOrEqualTo: startDate);
      }
      
      if (endDate != null) {
        query = query.where('requestedAt', isLessThanOrEqualTo: endDate);
      }
      
      final snapshot = await query
          .orderBy('requestedAt', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return RideModel.fromJson(data);
      }).toList();
    } catch (e, stack) {
      Logger.error('Error getting ride history', e, stack);
      _crashReporting.recordError(e, stack);
      return [];
    }
  }
  
  @override
  Future<RideModel> getRideDetails(String rideId) async {
    try {
      final doc = await _firestore.collection('rides').doc(rideId).get();
      
      if (!doc.exists) {
        throw Exception('Viaje no encontrado');
      }
      
      final data = doc.data()!;
      data['id'] = doc.id;
      
      return RideModel.fromJson(data);
    } catch (e, stack) {
      Logger.error('Error getting ride details', e, stack);
      _crashReporting.recordError(e, stack);
      rethrow;
    }
  }
  
  @override
  Future<void> cancelRide({
    required String rideId,
    required String reason,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('Usuario no autenticado');
      
      await _firestore.collection('rides').doc(rideId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancellationReason': reason,
        'cancelledBy': 'passenger',
      });
      
      // Analytics
      await _analytics.logRideCancelled(
        rideId: rideId,
        reason: reason,
        cancelledBy: 'passenger',
      );
      
      Logger.info('Ride cancelled', {'rideId': rideId});
    } catch (e, stack) {
      Logger.error('Error cancelling ride', e, stack);
      await _crashReporting.recordError(e, stack);
      rethrow;
    }
  }
  
  @override
  Future<void> rateRide({
    required String rideId,
    required double rating,
    String? comment,
  }) async {
    try {
      await _firestore.collection('rides').doc(rideId).update({
        'rating': rating,
        'comment': comment,
      });
      
      // También actualizar la calificación del conductor
      final ride = await getRideDetails(rideId);
      if (ride.driverId.isNotEmpty) {
        await _firestore.collection('drivers').doc(ride.driverId).update({
          'totalRatings': FieldValue.increment(1),
          'sumRatings': FieldValue.increment(rating),
        });
      }
      
      Logger.info('Ride rated', {
        'rideId': rideId,
        'rating': rating,
      });
    } catch (e, stack) {
      Logger.error('Error rating ride', e, stack);
      _crashReporting.recordError(e, stack);
      rethrow;
    }
  }
  
  @override
  Future<void> updateRideLocation({
    required String rideId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final routePoint = RoutePoint(
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now(),
      );
      
      await _firestore.collection('rides').doc(rideId).update({
        'routePoints': FieldValue.arrayUnion([routePoint.toJson()]),
      });
      
      Logger.info('Ride location updated');
    } catch (e, stack) {
      Logger.error('Error updating ride location', e, stack);
      _crashReporting.recordError(e, stack);
    }
  }
  
  @override
  Future<List<RoutePoint>> getRideRoute(String rideId) async {
    try {
      final ride = await getRideDetails(rideId);
      return ride.routePoints;
    } catch (e, stack) {
      Logger.error('Error getting ride route', e, stack);
      _crashReporting.recordError(e, stack);
      return [];
    }
  }
  
  @override
  Future<RideStatistics> getRideStatistics() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return RideStatistics(
          totalRides: 0,
          totalSpent: 0,
          totalDistance: 0,
          totalTime: 0,
          averageRating: 0,
          ridesByVehicleType: {},
          spentByMonth: {},
        );
      }
      
      // Obtener todos los viajes completados
      final rides = await getRideHistory(limit: 1000);
      
      if (rides.isEmpty) {
        return RideStatistics(
          totalRides: 0,
          totalSpent: 0,
          totalDistance: 0,
          totalTime: 0,
          averageRating: 0,
          ridesByVehicleType: {},
          spentByMonth: {},
        );
      }
      
      // Calcular estadísticas
      double totalSpent = 0;
      double totalDistance = 0;
      int totalTime = 0;
      double totalRating = 0;
      int ratedRides = 0;
      final ridesByType = <String, int>{};
      final spentByMonth = <String, double>{};
      
      for (final ride in rides) {
        if (ride.status == 'completed') {
          totalSpent += ride.fare;
          totalDistance += ride.distance;
          totalTime += ride.duration;
          
          // Conteo por tipo
          ridesByType[ride.vehicleType] = (ridesByType[ride.vehicleType] ?? 0) + 1;
          
          // Gasto por mes
          final monthKey = '${ride.completedAt!.year}-${ride.completedAt!.month.toString().padLeft(2, '0')}';
          spentByMonth[monthKey] = (spentByMonth[monthKey] ?? 0) + ride.fare;
          
          // Rating
          if (ride.rating != null) {
            totalRating += ride.rating!;
            ratedRides++;
          }
        }
      }
      
      return RideStatistics(
        totalRides: rides.where((r) => r.status == 'completed').length,
        totalSpent: totalSpent,
        totalDistance: totalDistance,
        totalTime: totalTime,
        averageRating: ratedRides > 0 ? totalRating / ratedRides : 0,
        ridesByVehicleType: ridesByType,
        spentByMonth: spentByMonth,
      );
    } catch (e, stack) {
      Logger.error('Error getting ride statistics', e, stack);
      _crashReporting.recordError(e, stack);
      return RideStatistics(
        totalRides: 0,
        totalSpent: 0,
        totalDistance: 0,
        totalTime: 0,
        averageRating: 0,
        ridesByVehicleType: {},
        spentByMonth: {},
      );
    }
  }
  
  @override
  Future<List<FavoriteRoute>> getFavoriteRoutes() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];
      
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favoriteRoutes')
          .orderBy('usageCount', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return FavoriteRoute(
          id: doc.id,
          name: data['name'],
          pickup: LocationModel.fromJson(data['pickup']),
          destination: LocationModel.fromJson(data['destination']),
          usageCount: data['usageCount'] ?? 0,
          lastUsed: (data['lastUsed'] as Timestamp).toDate(),
        );
      }).toList();
    } catch (e, stack) {
      Logger.error('Error getting favorite routes', e, stack);
      _crashReporting.recordError(e, stack);
      return [];
    }
  }
  
  @override
  Future<void> saveFavoriteRoute({
    required LocationModel pickup,
    required LocationModel destination,
    required String name,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('Usuario no autenticado');
      
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('favoriteRoutes')
          .add({
        'name': name,
        'pickup': pickup.toJson(),
        'destination': destination.toJson(),
        'usageCount': 0,
        'lastUsed': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      Logger.info('Favorite route saved');
    } catch (e, stack) {
      Logger.error('Error saving favorite route', e, stack);
      _crashReporting.recordError(e, stack);
      rethrow;
    }
  }
  
  @override
  Future<void> removeFavoriteRoute(String routeId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('Usuario no autenticado');
      
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('favoriteRoutes')
          .doc(routeId)
          .delete();
      
      Logger.info('Favorite route removed');
    } catch (e, stack) {
      Logger.error('Error removing favorite route', e, stack);
      _crashReporting.recordError(e, stack);
      rethrow;
    }
  }
}