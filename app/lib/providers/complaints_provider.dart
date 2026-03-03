// Provider para gestionar el Libro de Reclamaciones
// Cumple con Ley N° 29571 - Código de Protección y Defensa del Consumidor (Perú)

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/complaint_model.dart';
import '../utils/firestore_error_handler.dart';

class ComplaintsProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<ComplaintRecord> _complaints = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<ComplaintRecord> get complaints => _complaints;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Colección en Firestore
  static const String _collection = 'complaints_book';

  // Cargar reclamos del usuario actual
  Future<void> loadUserComplaints() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      _error = 'Debes iniciar sesión para ver tus reclamos';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('consumerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      _complaints = snapshot.docs
          .map((doc) => ComplaintRecord.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error cargando reclamos: $e');
      _error = FirestoreErrorHandler.getSpanishMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Generar número correlativo de reclamo
  Future<String> _generateComplaintNumber() async {
    final year = DateTime.now().year;
    final prefix = 'REC-$year-';

    try {
      // Obtener el último número del año actual
      final snapshot = await _firestore
          .collection(_collection)
          .where('complaintNumber', isGreaterThanOrEqualTo: prefix)
          .where('complaintNumber', isLessThan: 'REC-${year + 1}-')
          .orderBy('complaintNumber', descending: true)
          .limit(1)
          .get();

      int nextNumber = 1;
      if (snapshot.docs.isNotEmpty) {
        final lastNumber = snapshot.docs.first.data()['complaintNumber'] as String;
        final parts = lastNumber.split('-');
        if (parts.length == 3) {
          nextNumber = int.tryParse(parts[2]) ?? 0;
          nextNumber++;
        }
      }

      return '$prefix${nextNumber.toString().padLeft(5, '0')}';
    } catch (e) {
      debugPrint('Error generando número de reclamo: $e');
      // Fallback: usar timestamp
      return '$prefix${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // Crear nuevo reclamo
  Future<ComplaintRecord?> createComplaint({
    required ComplaintType type,
    required String consumerName,
    required String consumerDni,
    required String consumerAddress,
    required String consumerPhone,
    required String consumerEmail,
    String? tripId,
    double? claimedAmount,
    required String serviceDescription,
    required String complaintDetail,
    required String consumerRequest,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      _error = 'Debes iniciar sesión para presentar un reclamo';
      notifyListeners();
      return null;
    }

    // Validaciones
    if (complaintDetail.length < 50) {
      _error = 'El detalle del reclamo debe tener al menos 50 caracteres';
      notifyListeners();
      return null;
    }

    if (consumerDni.isEmpty || consumerDni.length < 8) {
      _error = 'Ingresa un DNI válido';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final complaintNumber = await _generateComplaintNumber();
      final now = DateTime.now();

      final complaint = ComplaintRecord(
        id: '', // Se asignará después de crear el documento
        complaintNumber: complaintNumber,
        createdAt: now,
        type: type,
        consumerId: userId,
        consumerName: consumerName,
        consumerDni: consumerDni,
        consumerAddress: consumerAddress,
        consumerPhone: consumerPhone,
        consumerEmail: consumerEmail,
        tripId: tripId,
        claimedAmount: claimedAmount,
        serviceDescription: serviceDescription,
        complaintDetail: complaintDetail,
        consumerRequest: consumerRequest,
        status: ComplaintStatus.pending,
      );

      final docRef = await _firestore
          .collection(_collection)
          .add(complaint.toFirestore());

      final newComplaint = complaint.copyWith(id: docRef.id);

      // Agregar a la lista local
      _complaints.insert(0, newComplaint);

      return newComplaint;
    } catch (e) {
      debugPrint('Error creando reclamo: $e');
      _error = FirestoreErrorHandler.getSpanishMessage(e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Obtener un reclamo por ID
  Future<ComplaintRecord?> getComplaintById(String complaintId) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(complaintId)
          .get();

      if (doc.exists) {
        return ComplaintRecord.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error obteniendo reclamo: $e');
      _error = FirestoreErrorHandler.getSpanishMessage(e);
      notifyListeners();
      return null;
    }
  }

  // Escuchar cambios en tiempo real de un reclamo
  Stream<ComplaintRecord?> watchComplaint(String complaintId) {
    return _firestore
        .collection(_collection)
        .doc(complaintId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return ComplaintRecord.fromFirestore(doc);
      }
      return null;
    });
  }

  // Obtener estadísticas de reclamos del usuario
  Map<String, int> getStatistics() {
    return {
      'total': _complaints.length,
      'pending': _complaints.where((c) => c.status == ComplaintStatus.pending).length,
      'inReview': _complaints.where((c) => c.status == ComplaintStatus.inReview).length,
      'resolved': _complaints.where((c) => c.status == ComplaintStatus.resolved).length,
      'closed': _complaints.where((c) => c.status == ComplaintStatus.closed).length,
      'reclamos': _complaints.where((c) => c.type == ComplaintType.reclamo).length,
      'quejas': _complaints.where((c) => c.type == ComplaintType.queja).length,
    };
  }

  // Limpiar error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Limpiar datos
  void clear() {
    _complaints = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
