import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../shared/models/ride_model.dart';

/// Proveedor de servicios de viajes con Firebase
class RideProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<RideModel> _rides = [];
  RideModel? _currentRide;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<RideModel> get rides => _rides;
  RideModel? get currentRide => _currentRide;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasActiveRide => _currentRide != null;

  /// Crear una nueva solicitud de viaje
  Future<RideModel?> createRideRequest({
    required String passengerId,
    required Map<String, dynamic> pickupLocation,
    required Map<String, dynamic> destinationLocation,
    required String vehicleType,
    required double estimatedFare,
    required String paymentMethod,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final rideData = {
        'passengerId': passengerId,
        'pickupLocation': pickupLocation,
        'destinationLocation': destinationLocation,
        'vehicleType': vehicleType,
        'estimatedFare': estimatedFare,
        'paymentMethod': paymentMethod,
        'status': 'requested',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore.collection('rides').add(rideData);
      
      final doc = await docRef.get();
      final ride = RideModel.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
      
      _currentRide = ride;
      _setLoading(false);
      return ride;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return null;
    }
  }

  /// Obtener viajes del usuario
  Future<void> getUserRides(String userId, {bool isDriver = false}) async {
    try {
      _setLoading(true);
      _clearError();

      Query query;
      if (isDriver) {
        query = _firestore
            .collection('rides')
            .where('driverId', isEqualTo: userId)
            .orderBy('createdAt', descending: true);
      } else {
        query = _firestore
            .collection('rides')
            .where('passengerId', isEqualTo: userId)
            .orderBy('createdAt', descending: true);
      }

      final querySnapshot = await query.get();
      
      _rides = querySnapshot.docs
          .map((doc) => RideModel.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
          .toList();

      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  /// Actualizar estado del viaje
  Future<bool> updateRideStatus(String rideId, String status, [Map<String, dynamic>? additionalData]) async {
    try {
      _setLoading(true);
      _clearError();

      final updateData = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        ...?additionalData,
      };

      await _firestore.collection('rides').doc(rideId).update(updateData);

      // Actualizar el ride actual si es el mismo
      if (_currentRide?.id == rideId) {
        final doc = await _firestore.collection('rides').doc(rideId).get();
        _currentRide = RideModel.fromFirestore(rideId, doc.data() as Map<String, dynamic>);
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Asignar conductor al viaje
  Future<bool> assignDriverToRide(String rideId, String driverId, Map<String, dynamic> driverInfo) async {
    return await updateRideStatus(rideId, 'driver_assigned', {
      'driverId': driverId,
      'driverInfo': driverInfo,
      'assignedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Completar viaje
  Future<bool> completeRide(String rideId, {
    required double finalFare,
    required int rating,
    String? review,
  }) async {
    return await updateRideStatus(rideId, 'completed', {
      'finalFare': finalFare,
      'rating': rating,
      'review': review,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cancelar viaje
  Future<bool> cancelRide(String rideId, String reason, {String? cancelledBy}) async {
    return await updateRideStatus(rideId, 'cancelled', {
      'cancellationReason': reason,
      'cancelledBy': cancelledBy,
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream de viajes en tiempo real para conductores
  Stream<List<RideModel>> getAvailableRidesStream(double driverLat, double driverLng, double radiusKm) {
    return _firestore
        .collection('rides')
        .where('status', isEqualTo: 'requested')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RideModel.fromFirestore(doc.id, doc.data()))
          .where((ride) {
        // Filtrar por radio de distancia
        // Nota: En producción se debería usar geopoints y consultas geoespaciales
        return true; // Por simplicidad, retornar todos por ahora
      }).toList();
    });
  }

  /// Stream del viaje actual
  Stream<RideModel?> getCurrentRideStream(String rideId) {
    return _firestore
        .collection('rides')
        .doc(rideId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        final ride = RideModel.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
        _currentRide = ride;
        return ride;
      }
      return null;
    });
  }

  /// Limpiar ride actual
  void clearCurrentRide() {
    _currentRide = null;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }
}