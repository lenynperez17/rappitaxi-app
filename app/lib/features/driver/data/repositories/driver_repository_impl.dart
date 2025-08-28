import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/ride_request.dart';
import '../../domain/repositories/driver_repository.dart';
import '../../../../shared/models/ride_model.dart';
import '../../../../shared/models/location_model.dart';

class DriverRepositoryImpl implements DriverRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  
  DriverRepositoryImpl({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;
  
  String? get _currentUserId => _auth.currentUser?.uid;
  
  @override
  Stream<String> getDriverStatus() {
    if (_currentUserId == null) {
      return Stream.value('offline');
    }
    
    return _firestore
        .collection('drivers')
        .doc(_currentUserId)
        .snapshots()
        .map((doc) => doc.data()?['status'] ?? 'offline');
  }
  
  @override
  Future<void> updateDriverStatus(String status) async {
    if (_currentUserId == null) return;
    
    await _firestore.collection('drivers').doc(_currentUserId).update({
      'status': status,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
    
    // Si el conductor se desconecta, eliminar su ubicación
    if (status == 'offline') {
      await _firestore
          .collection('driver_locations')
          .doc(_currentUserId)
          .delete();
    }
  }
  
  @override
  Stream<List<RideRequest>> getRideRequests() {
    if (_currentUserId == null) {
      return Stream.value([]);
    }
    
    // Escuchar solicitudes asignadas a este conductor
    return _firestore
        .collection('ride_requests')
        .where('driverId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return RideRequest(
          id: doc.id,
          passengerId: data['passengerId'],
          passengerName: data['passengerName'],
          passengerPhone: data['passengerPhone'],
          passengerPhoto: data['passengerPhoto'],
          passengerRating: data['passengerRating']?.toDouble() ?? 5.0,
          pickup: LocationModel.fromJson(data['pickup']),
          destination: LocationModel.fromJson(data['destination']),
          estimatedFare: data['estimatedFare']?.toDouble() ?? 0.0,
          estimatedDistance: data['estimatedDistance']?.toDouble() ?? 0.0,
          estimatedDuration: data['estimatedDuration'] ?? 0,
          vehicleType: data['vehicleType'] ?? 'standard',
          paymentMethod: data['paymentMethod'] ?? 'cash',
          requestedAt: (data['requestedAt'] as Timestamp).toDate(),
          timeoutSeconds: data['timeoutSeconds'] ?? 30,
          metadata: data['metadata'],
        );
      }).toList();
    });
  }
  
  @override
  Future<void> acceptRideRequest(String requestId) async {
    if (_currentUserId == null) return;
    
    // Iniciar transacción para evitar condiciones de carrera
    await _firestore.runTransaction((transaction) async {
      final requestDoc = await transaction.get(
        _firestore.collection('ride_requests').doc(requestId),
      );
      
      if (!requestDoc.exists || requestDoc.data()?['status'] != 'pending') {
        throw Exception('La solicitud ya no está disponible');
      }
      
      // Actualizar solicitud
      transaction.update(requestDoc.reference, {
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      
      // Crear viaje
      final rideRef = _firestore.collection('rides').doc();
      transaction.set(rideRef, {
        'id': rideRef.id,
        'requestId': requestId,
        'driverId': _currentUserId,
        'passengerId': requestDoc.data()?['passengerId'],
        'pickup': requestDoc.data()?['pickup'],
        'destination': requestDoc.data()?['destination'],
        'status': 'accepted',
        'fare': requestDoc.data()?['estimatedFare'],
        'distance': requestDoc.data()?['estimatedDistance'],
        'duration': requestDoc.data()?['estimatedDuration'],
        'vehicleType': requestDoc.data()?['vehicleType'],
        'paymentMethod': requestDoc.data()?['paymentMethod'],
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Actualizar estado del conductor
      transaction.update(_firestore.collection('drivers').doc(_currentUserId), {
        'status': 'busy',
        'currentRideId': rideRef.id,
      });
    });
  }
  
  @override
  Future<void> rejectRideRequest(String requestId) async {
    await _firestore.collection('ride_requests').doc(requestId).update({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
      'rejectedBy': _currentUserId,
    });
  }
  
  @override
  Stream<RideModel?> getCurrentRide() {
    if (_currentUserId == null) {
      return Stream.value(null);
    }
    
    return _firestore
        .collection('rides')
        .where('driverId', isEqualTo: _currentUserId)
        .where('status', whereIn: ['accepted', 'arriving', 'in_progress'])
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      
      final doc = snapshot.docs.first;
      return RideModel.fromJson({
        ...doc.data(),
        'id': doc.id,
      });
    });
  }
  
  @override
  Future<void> startRide(String rideId) async {
    await _firestore.collection('rides').doc(rideId).update({
      'status': 'in_progress',
      'startedAt': FieldValue.serverTimestamp(),
    });
    
    // Actualizar estado del conductor
    await updateDriverStatus('in_ride');
  }
  
  @override
  Future<void> completeRide(String rideId) async {
    await _firestore.collection('rides').doc(rideId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
    
    // Actualizar estado del conductor a online
    await updateDriverStatus('online');
    
    // Limpiar el ID del viaje actual
    if (_currentUserId != null) {
      await _firestore.collection('drivers').doc(_currentUserId).update({
        'currentRideId': FieldValue.delete(),
      });
    }
  }
  
  @override
  Future<void> cancelRide(String rideId, String reason) async {
    await _firestore.collection('rides').doc(rideId).update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
      'cancelledBy': 'driver',
      'cancellationReason': reason,
    });
    
    // Actualizar estado del conductor a online
    await updateDriverStatus('online');
    
    // Limpiar el ID del viaje actual
    if (_currentUserId != null) {
      await _firestore.collection('drivers').doc(_currentUserId).update({
        'currentRideId': FieldValue.delete(),
      });
    }
  }
  
  @override
  Future<void> updateDriverLocation(double latitude, double longitude) async {
    if (_currentUserId == null) return;
    
    await _firestore.collection('driver_locations').doc(_currentUserId).set({
      'driverId': _currentUserId,
      'location': GeoPoint(latitude, longitude),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }
  
  @override
  Future<double> getTodayEarnings() async {
    if (_currentUserId == null) return 0.0;
    
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    
    final snapshot = await _firestore
        .collection('rides')
        .where('driverId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: 'completed')
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .get();
    
    double total = 0.0;
    for (final doc in snapshot.docs) {
      total += doc.data()['fare']?.toDouble() ?? 0.0;
    }
    
    return total;
  }
  
  @override
  Future<double> getWeeklyEarnings() async {
    if (_currentUserId == null) return 0.0;
    
    final today = DateTime.now();
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final startDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    
    final snapshot = await _firestore
        .collection('rides')
        .where('driverId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: 'completed')
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .get();
    
    double total = 0.0;
    for (final doc in snapshot.docs) {
      total += doc.data()['fare']?.toDouble() ?? 0.0;
    }
    
    return total;
  }
  
  @override
  Future<double> getMonthlyEarnings() async {
    if (_currentUserId == null) return 0.0;
    
    final today = DateTime.now();
    final startOfMonth = DateTime(today.year, today.month, 1);
    
    final snapshot = await _firestore
        .collection('rides')
        .where('driverId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: 'completed')
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .get();
    
    double total = 0.0;
    for (final doc in snapshot.docs) {
      total += doc.data()['fare']?.toDouble() ?? 0.0;
    }
    
    return total;
  }
  
  @override
  Future<List<RideModel>> getEarningsHistory(DateTime startDate, DateTime endDate) async {
    if (_currentUserId == null) return [];
    
    final snapshot = await _firestore
        .collection('rides')
        .where('driverId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: 'completed')
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('completedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('completedAt', descending: true)
        .get();
    
    return snapshot.docs.map((doc) {
      return RideModel.fromJson({
        ...doc.data(),
        'id': doc.id,
      });
    }).toList();
  }
  
  @override
  Future<double> getDriverRating() async {
    if (_currentUserId == null) return 5.0;
    
    final doc = await _firestore.collection('drivers').doc(_currentUserId).get();
    return doc.data()?['rating']?.toDouble() ?? 5.0;
  }
  
  @override
  Future<int> getTotalTrips() async {
    if (_currentUserId == null) return 0;
    
    final snapshot = await _firestore
        .collection('rides')
        .where('driverId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: 'completed')
        .count()
        .get();
    
    return snapshot.count ?? 0;
  }
}