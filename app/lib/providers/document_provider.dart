import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../services/firebase_service.dart';

class DocumentProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseService().firestore;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Estados
  bool _isLoading = false;
  String? _error;
  double _uploadProgress = 0.0;

  // Documentos del conductor
  Map<String, dynamic>? _driverDocuments;
  List<Map<String, dynamic>> _vehicleDocuments = [];
  Map<String, dynamic>? _verificationStatus;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get uploadProgress => _uploadProgress;
  Map<String, dynamic>? get driverDocuments => _driverDocuments;
  List<Map<String, dynamic>> get vehicleDocuments => _vehicleDocuments;
  Map<String, dynamic>? get verificationStatus => _verificationStatus;

  // Tipos de documentos requeridos
  final List<Map<String, dynamic>> requiredDocuments = [
    {
      'id': 'license',
      'name': 'Licencia de Conducir',
      'description': 'Foto clara de tu licencia de conducir vigente',
      'icon': Icons.badge,
      'required': true,
    },
    {
      'id': 'dni',
      'name': 'DNI',
      'description': 'Foto de ambos lados de tu DNI',
      'icon': Icons.credit_card,
      'required': true,
    },
    {
      'id': 'criminal_record',
      'name': 'Antecedentes Penales',
      'description': 'Certificado de antecedentes penales reciente',
      'icon': Icons.gavel,
      'required': true,
    },
    {
      'id': 'vehicle_card',
      'name': 'Tarjeta de Propiedad',
      'description': 'Tarjeta de propiedad del vehículo',
      'icon': Icons.directions_car,
      'required': true,
    },
    {
      'id': 'soat',
      'name': 'SOAT',
      'description': 'Seguro obligatorio vigente',
      'icon': Icons.security,
      'required': true,
    },
    {
      'id': 'technical_review',
      'name': 'Revisión Técnica',
      'description': 'Certificado de revisión técnica vigente',
      'icon': Icons.build,
      'required': true,
    },
    {
      'id': 'vehicle_photo',
      'name': 'Foto del Vehículo',
      'description': 'Foto clara del vehículo (frontal y lateral)',
      'icon': Icons.photo_camera,
      'required': true,
    },
  ];

  // Cargar documentos del conductor
  Future<void> loadDriverDocuments(String driverId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final doc = await _firestore
          .collection('drivers')
          .doc(driverId)
          .collection('documents')
          .doc('info')
          .get();

      if (doc.exists) {
        _driverDocuments = doc.data();
      } else {
        _driverDocuments = {};
      }

      // Cargar estado de verificación
      await loadVerificationStatus(driverId);
    } catch (e) {
      _error = 'Error al cargar documentos: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Cargar estado de verificación
  // ✅ FIX 2026-01-05: Leer de 'users' (fuente de verdad) en lugar de 'drivers'
  Future<void> loadVerificationStatus(String driverId) async {
    try {
      debugPrint('📄 DocumentProvider: Cargando estado de verificación para: $driverId');

      // Leer de 'users' que es la fuente de verdad (admin panel también lee de aquí)
      final doc = await _firestore
          .collection('users')
          .doc(driverId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        debugPrint('📄 DocumentProvider: Documento encontrado en users/$driverId');
        debugPrint('📄 DocumentProvider: isVerified=${data?['isVerified']}, driverStatus=${data?['driverStatus']}');

        // Mapear campos de 'users' al formato esperado
        final isVerified = data?['isVerified'] == true;
        final driverStatus = data?['driverStatus'] ?? 'pending_approval';

        // Determinar verificationStatus basado en driverStatus
        String verificationStatus;
        if (isVerified || driverStatus == 'approved') {
          verificationStatus = 'approved';
        } else if (driverStatus == 'rejected') {
          verificationStatus = 'rejected';
        } else {
          verificationStatus = 'pending';
        }

        _verificationStatus = {
          'isVerified': isVerified,
          'verificationStatus': verificationStatus,
          'verificationDate': data?['approvedAt'],
          'rejectionReason': data?['rejectionReason'],
        };

        debugPrint('📄 DocumentProvider: Estado final: $_verificationStatus');
      } else {
        debugPrint('📄 DocumentProvider: ⚠️ Documento NO existe en users/$driverId');
        // Si no existe documento de usuario, no mostrar banner
        _verificationStatus = null;
      }
    } catch (e) {
      debugPrint('📄 DocumentProvider: ❌ Error: $e');
      _error = 'Error al cargar estado de verificación: $e';
    }
    notifyListeners();
  }

  // Subir documento
  Future<bool> uploadDocument({
    required String driverId,
    required String documentType,
    required File file,
  }) async {
    _isLoading = true;
    _uploadProgress = 0.0;
    _error = null;
    notifyListeners();

    try {
      // Crear referencia en Storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${documentType}_$timestamp.jpg';
      final ref = _storage
          .ref()
          .child('drivers')
          .child(driverId)
          .child('documents')
          .child(fileName);

      // Subir archivo con progreso
      final uploadTask = ref.putFile(file);
      
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        notifyListeners();
      });

      // Esperar a que termine la subida
      await uploadTask;

      // Obtener URL de descarga
      final downloadUrl = await ref.getDownloadURL();

      // Guardar información en Firestore
      await _firestore
          .collection('drivers')
          .doc(driverId)
          .collection('documents')
          .doc('info')
          .set({
        documentType: {
          'url': downloadUrl,
          'uploadedAt': FieldValue.serverTimestamp(),
          'fileName': fileName,
          'status': 'pending',
          'verified': false,
        }
      }, SetOptions(merge: true));

      // Actualizar estado local
      _driverDocuments ??= {};
      _driverDocuments![documentType] = {
        'url': downloadUrl,
        'uploadedAt': DateTime.now(),
        'fileName': fileName,
        'status': 'pending',
        'verified': false,
      };

      _isLoading = false;
      _uploadProgress = 0.0;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al subir documento: $e';
      _isLoading = false;
      _uploadProgress = 0.0;
      notifyListeners();
      return false;
    }
  }

  // Eliminar documento
  Future<bool> deleteDocument({
    required String driverId,
    required String documentType,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Obtener información del documento
      final docInfo = _driverDocuments?[documentType];
      if (docInfo != null && docInfo['fileName'] != null) {
        // Eliminar de Storage
        final ref = _storage
            .ref()
            .child('drivers')
            .child(driverId)
            .child('documents')
            .child(docInfo['fileName']);
        
        await ref.delete();
      }

      // Eliminar de Firestore
      await _firestore
          .collection('drivers')
          .doc(driverId)
          .collection('documents')
          .doc('info')
          .update({
        documentType: FieldValue.delete(),
      });

      // Actualizar estado local
      _driverDocuments?.remove(documentType);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al eliminar documento: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Verificar si todos los documentos están completos
  bool areAllDocumentsComplete() {
    if (_driverDocuments == null) return false;

    for (var doc in requiredDocuments) {
      if (doc['required'] == true) {
        if (!_driverDocuments!.containsKey(doc['id'])) {
          return false;
        }
      }
    }
    return true;
  }

  // Obtener estado del documento
  String getDocumentStatus(String documentType) {
    if (_driverDocuments == null || !_driverDocuments!.containsKey(documentType)) {
      return 'not_uploaded';
    }
    
    final doc = _driverDocuments![documentType];
    if (doc['verified'] == true) {
      return 'verified';
    } else if (doc['status'] == 'rejected') {
      return 'rejected';
    } else {
      return 'pending';
    }
  }

  // Solicitar verificación
  Future<bool> requestVerification(String driverId) async {
    if (!areAllDocumentsComplete()) {
      _error = 'Por favor sube todos los documentos requeridos';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firestore.collection('drivers').doc(driverId).update({
        'verificationStatus': 'under_review',
        'verificationRequestedAt': FieldValue.serverTimestamp(),
      });

      // Crear notificación para admin
      await _firestore.collection('admin_notifications').add({
        'type': 'verification_request',
        'driverId': driverId,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      _verificationStatus = {
        ..._verificationStatus ?? {},
        'verificationStatus': 'under_review',
      };

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al solicitar verificación: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Cargar documentos del vehículo
  Future<void> loadVehicleDocuments(String driverId, String vehicleId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('drivers')
          .doc(driverId)
          .collection('vehicles')
          .doc(vehicleId)
          .collection('documents')
          .get();

      _vehicleDocuments = snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      _error = 'Error al cargar documentos del vehículo: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Limpiar error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Limpiar datos
  void clearData() {
    _driverDocuments = null;
    _vehicleDocuments = [];
    _verificationStatus = null;
    _error = null;
    notifyListeners();
  }
}