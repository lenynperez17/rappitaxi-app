import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../utils/logger.dart';
import '../services/firebase_service.dart';

/// Provider para gestión completa de vehículos, documentos, mantenimiento y recordatorios
class VehicleProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseService().firestore;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Estados de carga
  bool _isLoading = false;
  bool _isLoadingDocuments = false;
  bool _isLoadingMaintenance = false;
  bool _isLoadingReminders = false;
  bool _isSaving = false;
  String? _error;
  double _uploadProgress = 0.0;

  // Datos del vehículo
  Map<String, dynamic> _vehicleData = {};
  List<VehicleDocument> _documents = [];
  List<MaintenanceRecord> _maintenanceRecords = [];
  List<Reminder> _reminders = [];

  // Getters
  bool get isLoading => _isLoading;
  bool get isLoadingDocuments => _isLoadingDocuments;
  bool get isLoadingMaintenance => _isLoadingMaintenance;
  bool get isLoadingReminders => _isLoadingReminders;
  bool get isSaving => _isSaving;
  String? get error => _error;
  double get uploadProgress => _uploadProgress;
  Map<String, dynamic> get vehicleData => _vehicleData;
  List<VehicleDocument> get documents => _documents;
  List<MaintenanceRecord> get maintenanceRecords => _maintenanceRecords;
  List<Reminder> get reminders => _reminders;

  // Cargar todos los datos del vehículo
  Future<void> loadVehicleData(String driverId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      AppLogger.info('Cargando datos del vehículo para driver: $driverId');
      
      // Cargar en paralelo
      await Future.wait([
        _loadBasicVehicleInfo(driverId),
        _loadDocuments(driverId),
        _loadMaintenanceRecords(driverId),
        _loadReminders(driverId),
      ]);

      AppLogger.info('Datos del vehículo cargados exitosamente');
    } catch (e) {
      _error = 'Error al cargar datos del vehículo: $e';
      AppLogger.error('Error cargando datos del vehículo', e);
    }

    _isLoading = false;
    notifyListeners();
  }

  // Cargar información básica del vehículo
  Future<void> _loadBasicVehicleInfo(String driverId) async {
    final vehicleDoc = await _firestore
        .collection('drivers')
        .doc(driverId)
        .collection('vehicle')
        .doc('info')
        .get();

    if (vehicleDoc.exists) {
      _vehicleData = vehicleDoc.data() ?? {};
    } else {
      // Crear datos iniciales
      _vehicleData = {
        'brand': '',
        'model': '',
        'year': DateTime.now().year,
        'plate': '',
        'color': '',
        'vin': '',
        'mileage': 0,
        'seats': 4,
        'fuelType': 'Gasolina',
        'transmission': 'Manual',
        'photos': [],
        'isActive': false,
        'registeredAt': FieldValue.serverTimestamp(),
      };
    }
  }

  // Cargar documentos del vehículo
  Future<void> _loadDocuments(String driverId) async {
    _isLoadingDocuments = true;
    notifyListeners();

    try {
      final docsSnapshot = await _firestore
          .collection('drivers')
          .doc(driverId)
          .collection('vehicle')
          .doc('documents')
          .collection('list')
          .orderBy('expiryDate', descending: false)
          .get();

      _documents = docsSnapshot.docs
          .map((doc) => VehicleDocument.fromFirestore(doc))
          .toList();

      AppLogger.info('Documentos cargados: ${_documents.length}');
    } catch (e) {
      AppLogger.error('Error cargando documentos', e);
    }

    _isLoadingDocuments = false;
    notifyListeners();
  }

  // Cargar registros de mantenimiento
  Future<void> _loadMaintenanceRecords(String driverId) async {
    _isLoadingMaintenance = true;
    notifyListeners();

    try {
      final maintenanceSnapshot = await _firestore
          .collection('drivers')
          .doc(driverId)
          .collection('vehicle')
          .doc('maintenance')
          .collection('records')
          .orderBy('date', descending: true)
          .limit(20)
          .get();

      _maintenanceRecords = maintenanceSnapshot.docs
          .map((doc) => MaintenanceRecord.fromFirestore(doc))
          .toList();

      AppLogger.info('Registros de mantenimiento cargados: ${_maintenanceRecords.length}');
    } catch (e) {
      AppLogger.error('Error cargando mantenimiento', e);
    }

    _isLoadingMaintenance = false;
    notifyListeners();
  }

  // Cargar recordatorios
  Future<void> _loadReminders(String driverId) async {
    _isLoadingReminders = true;
    notifyListeners();

    try {
      final remindersSnapshot = await _firestore
          .collection('drivers')
          .doc(driverId)
          .collection('vehicle')
          .doc('reminders')
          .collection('list')
          .where('completed', isEqualTo: false)
          .orderBy('date', descending: false)
          .get();

      _reminders = remindersSnapshot.docs
          .map((doc) => Reminder.fromFirestore(doc))
          .toList();

      AppLogger.info('Recordatorios cargados: ${_reminders.length}');
    } catch (e) {
      AppLogger.error('Error cargando recordatorios', e);
    }

    _isLoadingReminders = false;
    notifyListeners();
  }

  // Actualizar información básica del vehículo
  Future<bool> updateVehicleInfo(String driverId, Map<String, dynamic> newData) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      // Validar datos básicos
      if (newData['plate'] == null || newData['plate'].toString().isEmpty == true) {
        _error = 'La placa del vehículo es obligatoria';
        _isSaving = false;
        notifyListeners();
        return false;
      }

      await _firestore
          .collection('drivers')
          .doc(driverId)
          .collection('vehicle')
          .doc('info')
          .set({
        ...newData,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Actualizar datos locales
      _vehicleData = {
        ..._vehicleData,
        ...newData,
        'updatedAt': DateTime.now(),
      };

      AppLogger.info('Información del vehículo actualizada');
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al actualizar información del vehículo: $e';
      AppLogger.error('Error actualizando vehículo', e);
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  // Subir foto del vehículo
  Future<bool> uploadVehiclePhoto(String driverId, File photoFile) async {
    _isSaving = true;
    _uploadProgress = 0.0;
    _error = null;
    notifyListeners();

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'vehicle_photo_$timestamp.jpg';
      final ref = _storage
          .ref()
          .child('drivers')
          .child(driverId)
          .child('vehicle')
          .child('photos')
          .child(fileName);

      // Subir con progreso
      final uploadTask = ref.putFile(photoFile);
      
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        notifyListeners();
      });

      await uploadTask;
      final downloadUrl = await ref.getDownloadURL();

      // Actualizar lista de fotos
      final currentPhotos = List<String>.from(_vehicleData['photos'] ?? []);
      currentPhotos.add(downloadUrl);
      
      await updateVehicleInfo(driverId, {'photos': currentPhotos});

      AppLogger.info('Foto del vehículo subida exitosamente');
      _isSaving = false;
      _uploadProgress = 0.0;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al subir foto del vehículo: $e';
      AppLogger.error('Error subiendo foto', e);
      _isSaving = false;
      _uploadProgress = 0.0;
      notifyListeners();
      return false;
    }
  }

  // Agregar documento del vehículo
  Future<bool> addDocument({
    required String driverId,
    required String type,
    required String number,
    required DateTime issueDate,
    DateTime? expiryDate,
    File? documentFile,
  }) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      String? documentUrl;
      
      // Si hay archivo, subirlo
      if (documentFile != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = '$type$timestamp.jpg';
        final ref = _storage
            .ref()
            .child('drivers')
            .child(driverId)
            .child('vehicle')
            .child('documents')
            .child(fileName);

        final uploadTask = ref.putFile(documentFile);
        await uploadTask;
        documentUrl = await ref.getDownloadURL();
      }

      // Guardar en Firestore
      final docRef = await _firestore
          .collection('drivers')
          .doc(driverId)
          .collection('vehicle')
          .doc('documents')
          .collection('list')
          .add({
        'type': type,
        'number': number,
        'issueDate': Timestamp.fromDate(issueDate),
        'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
        'documentUrl': documentUrl,
        'status': 'valid',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Agregar a la lista local
      final newDoc = VehicleDocument(
        id: docRef.id,
        type: type,
        number: number,
        issueDate: issueDate,
        expiryDate: expiryDate,
        documentUrl: documentUrl,
        status: DocumentStatus.valid,
      );
      
      _documents.add(newDoc);
      _documents.sort((a, b) => (a.expiryDate ?? DateTime.now()).compareTo(b.expiryDate ?? DateTime.now()));

      AppLogger.info('Documento agregado: $type');
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al agregar documento: $e';
      AppLogger.error('Error agregando documento', e);
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  // Agregar registro de mantenimiento
  Future<bool> addMaintenanceRecord({
    required String driverId,
    required String type,
    required DateTime date,
    required int mileage,
    required double cost,
    required String workshop,
    DateTime? nextDue,
    String? notes,
  }) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final docRef = await _firestore
          .collection('drivers')
          .doc(driverId)
          .collection('vehicle')
          .doc('maintenance')
          .collection('records')
          .add({
        'type': type,
        'date': Timestamp.fromDate(date),
        'mileage': mileage,
        'cost': cost,
        'workshop': workshop,
        'nextDue': nextDue != null ? Timestamp.fromDate(nextDue) : null,
        'notes': notes,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Agregar a la lista local
      final newRecord = MaintenanceRecord(
        id: docRef.id,
        type: type,
        date: date,
        mileage: mileage,
        cost: cost,
        workshop: workshop,
        nextDue: nextDue,
        notes: notes,
      );
      
      _maintenanceRecords.insert(0, newRecord); // Agregar al inicio

      // Crear recordatorio si hay próximo mantenimiento
      if (nextDue != null) {
        await addReminder(
          driverId: driverId,
          title: 'Mantenimiento programado',
          description: 'Recuerda realizar el $type',
          date: nextDue,
          type: ReminderType.maintenance,
          priority: Priority.medium,
        );
      }

      AppLogger.info('Registro de mantenimiento agregado: $type');
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al agregar registro de mantenimiento: $e';
      AppLogger.error('Error agregando mantenimiento', e);
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  // Agregar recordatorio
  Future<bool> addReminder({
    required String driverId,
    required String title,
    required String description,
    required DateTime date,
    required ReminderType type,
    required Priority priority,
  }) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final docRef = await _firestore
          .collection('drivers')
          .doc(driverId)
          .collection('vehicle')
          .doc('reminders')
          .collection('list')
          .add({
        'title': title,
        'description': description,
        'date': Timestamp.fromDate(date),
        'type': type.index,
        'priority': priority.index,
        'completed': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Agregar a la lista local
      final newReminder = Reminder(
        id: docRef.id,
        title: title,
        description: description,
        date: date,
        type: type,
        priority: priority,
        completed: false,
      );
      
      _reminders.add(newReminder);
      _reminders.sort((a, b) => a.date.compareTo(b.date));

      AppLogger.info('Recordatorio agregado: $title');
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al agregar recordatorio: $e';
      AppLogger.error('Error agregando recordatorio', e);
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  // Marcar recordatorio como completado
  Future<bool> completeReminder(String driverId, String reminderId) async {
    try {
      await _firestore
          .collection('drivers')
          .doc(driverId)
          .collection('vehicle')
          .doc('reminders')
          .collection('list')
          .doc(reminderId)
          .update({'completed': true});

      // Actualizar localmente
      final reminderIndex = _reminders.indexWhere((r) => r.id == reminderId);
      if (reminderIndex != -1) {
        _reminders.removeAt(reminderIndex);
        notifyListeners();
      }

      AppLogger.info('Recordatorio completado: $reminderId');
      return true;
    } catch (e) {
      _error = 'Error al completar recordatorio: $e';
      AppLogger.error('Error completando recordatorio', e);
      return false;
    }
  }

  // Eliminar documento
  Future<bool> deleteDocument(String driverId, String documentId) async {
    try {
      await _firestore
          .collection('drivers')
          .doc(driverId)
          .collection('vehicle')
          .doc('documents')
          .collection('list')
          .doc(documentId)
          .delete();

      // Eliminar localmente
      _documents.removeWhere((doc) => doc.id == documentId);
      notifyListeners();

      AppLogger.info('Documento eliminado: $documentId');
      return true;
    } catch (e) {
      _error = 'Error al eliminar documento: $e';
      AppLogger.error('Error eliminando documento', e);
      return false;
    }
  }

  // Obtener documentos próximos a vencer
  List<VehicleDocument> getExpiringDocuments({int daysAhead = 30}) {
    final cutoffDate = DateTime.now().add(Duration(days: daysAhead));
    return _documents.where((doc) {
      if (doc.expiryDate == null) return false;
      return doc.expiryDate!.isBefore(cutoffDate) && doc.expiryDate!.isAfter(DateTime.now());
    }).toList();
  }

  // Obtener recordatorios de alta prioridad
  List<Reminder> getHighPriorityReminders() {
    return _reminders.where((reminder) => 
      reminder.priority == Priority.high && !reminder.completed
    ).toList();
  }

  // Obtener resumen del vehículo
  Map<String, dynamic> getVehicleSummary() {
    return {
      'totalDocuments': _documents.length,
      'validDocuments': _documents.where((doc) => doc.status == DocumentStatus.valid).length,
      'expiringDocuments': getExpiringDocuments().length,
      'totalMaintenanceRecords': _maintenanceRecords.length,
      'totalCostThisYear': _maintenanceRecords
          .where((record) => record.date.year == DateTime.now().year)
          .fold(0.0, (double sum, record) => sum + record.cost),
      'pendingReminders': _reminders.where((r) => !r.completed).length,
      'highPriorityReminders': getHighPriorityReminders().length,
    };
  }

  // Limpiar error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Limpiar todos los datos
  void clearData() {
    _vehicleData = {};
    _documents = [];
    _maintenanceRecords = [];
    _reminders = [];
    _error = null;
    _isLoading = false;
    _isSaving = false;
    notifyListeners();
  }
}

// Modelos
class VehicleDocument {
  final String id;
  final String type;
  final String number;
  final DateTime issueDate;
  final DateTime? expiryDate;
  final String? documentUrl;
  final DocumentStatus status;
  final DateTime? createdAt;

  VehicleDocument({
    required this.id,
    required this.type,
    required this.number,
    required this.issueDate,
    this.expiryDate,
    this.documentUrl,
    required this.status,
    this.createdAt,
  });

  factory VehicleDocument.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return VehicleDocument(
      id: doc.id,
      type: data['type'] ?? '',
      number: data['number'] ?? '',
      issueDate: (data['issueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiryDate: data['expiryDate'] != null 
          ? (data['expiryDate'] as Timestamp).toDate() 
          : null,
      documentUrl: data['documentUrl'],
      status: _getDocumentStatus(data),
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : null,
    );
  }

  static DocumentStatus _getDocumentStatus(Map<String, dynamic> data) {
    if (data['expiryDate'] == null) return DocumentStatus.valid;
    
    final expiryDate = (data['expiryDate'] as Timestamp).toDate();
    final now = DateTime.now();
    final daysDiff = expiryDate.difference(now).inDays;
    
    if (daysDiff < 0) return DocumentStatus.expired;
    if (daysDiff <= 30) return DocumentStatus.expiringSoon;
    return DocumentStatus.valid;
  }

  // Getters para UI
  IconData get icon {
    switch (type.toLowerCase()) {
      case 'soat':
        return Icons.security;
      case 'revisión técnica':
      case 'revision_tecnica':
        return Icons.build_circle;
      case 'tarjeta de propiedad':
      case 'tarjeta_propiedad':
        return Icons.badge;
      case 'permiso de circulación':
      case 'permiso_circulacion':
        return Icons.directions_car;
      default:
        return Icons.description;
    }
  }

  Color get color {
    switch (status) {
      case DocumentStatus.valid:
        return Colors.green;
      case DocumentStatus.expiringSoon:
        return Colors.orange;
      case DocumentStatus.expired:
        return Colors.red;
      case DocumentStatus.pending:
        return Colors.blue;
    }
  }
}

class MaintenanceRecord {
  final String id;
  final String type;
  final DateTime date;
  final int mileage;
  final double cost;
  final String workshop;
  final DateTime? nextDue;
  final String? notes;
  final DateTime? createdAt;

  MaintenanceRecord({
    required this.id,
    required this.type,
    required this.date,
    required this.mileage,
    required this.cost,
    required this.workshop,
    this.nextDue,
    this.notes,
    this.createdAt,
  });

  factory MaintenanceRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return MaintenanceRecord(
      id: doc.id,
      type: data['type'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      mileage: data['mileage'] ?? 0,
      cost: (data['cost'] ?? 0).toDouble(),
      workshop: data['workshop'] ?? '',
      nextDue: data['nextDue'] != null 
          ? (data['nextDue'] as Timestamp).toDate() 
          : null,
      notes: data['notes'],
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : null,
    );
  }

  IconData get icon {
    switch (type.toLowerCase()) {
      case 'cambio de aceite':
        return Icons.oil_barrel;
      case 'alineación':
        return Icons.compare_arrows;
      case 'frenos':
        return Icons.disc_full;
      case 'neumáticos':
        return Icons.trip_origin;
      case 'filtros':
        return Icons.filter_alt;
      case 'transmisión':
        return Icons.settings;
      default:
        return Icons.build;
    }
  }
}

class Reminder {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final ReminderType type;
  final Priority priority;
  final bool completed;
  final DateTime? createdAt;

  Reminder({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.type,
    required this.priority,
    required this.completed,
    this.createdAt,
  });

  factory Reminder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Reminder(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      type: ReminderType.values[data['type'] ?? 0],
      priority: Priority.values[data['priority'] ?? 2],
      completed: data['completed'] ?? false,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : null,
    );
  }
}

enum DocumentStatus { valid, expiringSoon, expired, pending }
enum ReminderType { document, maintenance, payment, other }
enum Priority { high, medium, low }