import 'package:flutter/material.dart';
import 'dart:io';
import '../utils/logger.dart';
import '../services/rapi_api_client.dart';

/// Provider para gestión completa de vehículos, documentos, mantenimiento y recordatorios
class VehicleProvider extends ChangeNotifier {
  final RapiApiClient _api = RapiApiClient.instance;

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
  final List<MaintenanceRecord> _maintenanceRecords = [];
  final List<Reminder> _reminders = [];

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

      // Cargar en paralelo desde el backend
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

  // Cargar información básica del vehículo desde /api/drivers/me/profile
  Future<void> _loadBasicVehicleInfo(String driverId) async {
    try {
      final profile = await _api.myDriverProfile();
      final vehicle = profile['vehicle'];

      if (vehicle is Map) {
        _vehicleData = Map<String, dynamic>.from(vehicle);
      } else {
        // Datos iniciales cuando el conductor aún no registró vehículo
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
          'photos': <String>[],
          'isActive': false,
          'registeredAt': null,
        };
      }
    } catch (e) {
      AppLogger.error('Error cargando información del vehículo', e);
      rethrow;
    }
  }

  // Cargar documentos del vehículo desde /api/drivers/me/documents
  Future<void> _loadDocuments(String driverId) async {
    _isLoadingDocuments = true;
    notifyListeners();

    try {
      final response = await _api.myDocuments();
      final docs = response['documents'];

      if (docs is List) {
        _documents = docs
            .whereType<Map>()
            .map((d) => VehicleDocument.fromJson(Map<String, dynamic>.from(d)))
            .toList();

        _documents.sort((a, b) {
          final ea = a.expiryDate ?? DateTime(9999);
          final eb = b.expiryDate ?? DateTime(9999);
          return ea.compareTo(eb);
        });
      } else {
        _documents = [];
      }

      AppLogger.info('Documentos cargados: ${_documents.length}');
    } catch (e) {
      AppLogger.error('Error cargando documentos', e);
    }

    _isLoadingDocuments = false;
    notifyListeners();
  }

  // Los registros de mantenimiento aún no están persistidos en el backend Node;
  // se mantienen en memoria durante la sesión.
  Future<void> _loadMaintenanceRecords(String driverId) async {
    _isLoadingMaintenance = true;
    notifyListeners();

    try {
      // TODO: reemplazar por endpoint /api/drivers/me/maintenance cuando exista
      AppLogger.info('Registros de mantenimiento en memoria: ${_maintenanceRecords.length}');
    } catch (e) {
      AppLogger.error('Error cargando mantenimiento', e);
    }

    _isLoadingMaintenance = false;
    notifyListeners();
  }

  // Recordatorios en memoria (backend Node aún no expone endpoint dedicado)
  Future<void> _loadReminders(String driverId) async {
    _isLoadingReminders = true;
    notifyListeners();

    try {
      // TODO: reemplazar por endpoint /api/drivers/me/reminders cuando exista
      AppLogger.info('Recordatorios en memoria: ${_reminders.length}');
    } catch (e) {
      AppLogger.error('Error cargando recordatorios', e);
    }

    _isLoadingReminders = false;
    notifyListeners();
  }

  // Actualizar información básica del vehículo usando upsertVehicle
  Future<bool> updateVehicleInfo(String driverId, Map<String, dynamic> newData) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      // Validar datos básicos
      final plate = (newData['plate'] ?? _vehicleData['plate'])?.toString() ?? '';
      if (plate.isEmpty) {
        _error = 'La placa del vehículo es obligatoria';
        _isSaving = false;
        notifyListeners();
        return false;
      }

      // Componer el merge para consultar con el backend
      final merged = <String, dynamic>{
        ..._vehicleData,
        ...newData,
      };

      final vehicleType = (merged['vehicleType'] ?? merged['type'] ?? 'sedan').toString();
      final make = (merged['make'] ?? merged['brand'])?.toString();
      final model = merged['model']?.toString();
      final color = merged['color']?.toString();
      final yearRaw = merged['year'];
      final year = yearRaw is int ? yearRaw : int.tryParse(yearRaw?.toString() ?? '');

      await _api.upsertVehicle(
        vehicleType: vehicleType,
        plate: plate,
        make: make,
        model: model,
        color: color,
        year: year,
      );

      // Actualizar datos locales
      _vehicleData = {
        ..._vehicleData,
        ...newData,
        'updatedAt': DateTime.now().toIso8601String(),
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

  // Subir foto del vehículo — usa storage genérico del backend
  Future<bool> uploadVehiclePhoto(String driverId, File photoFile) async {
    _isSaving = true;
    _uploadProgress = 0.0;
    _error = null;
    notifyListeners();

    try {
      _uploadProgress = 0.3;
      notifyListeners();

      final uploaded = await _api.uploadFile(file: photoFile, scope: 'vehicle_photos');
      final downloadUrl = uploaded['url']?.toString() ?? '';
      if (downloadUrl.isEmpty) {
        throw Exception('El servidor no devolvió URL de la foto');
      }

      _uploadProgress = 0.8;
      notifyListeners();

      // Agregar la foto a la lista y persistir el vehículo
      final currentPhotos = List<String>.from(_vehicleData['photos'] ?? const <String>[]);
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

  // Agregar documento del vehículo (uploadFile → uploadDocument)
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

      // Si hay archivo, subirlo al storage genérico
      if (documentFile != null) {
        final uploaded = await _api.uploadFile(file: documentFile, scope: 'documents');
        documentUrl = uploaded['url']?.toString();
      }

      // Registrar el documento en el backend
      if (documentUrl != null && documentUrl.isNotEmpty) {
        await _api.uploadDocument(docType: type, fileUrl: documentUrl);
      }

      // Agregar a la lista local con un ID local (backend regenera al recargar)
      final localId = '${type}_${DateTime.now().millisecondsSinceEpoch}';
      final newDoc = VehicleDocument(
        id: localId,
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

  // Agregar registro de mantenimiento (solo en memoria hasta que exista endpoint)
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
      final localId = 'maint_${DateTime.now().millisecondsSinceEpoch}';
      final newRecord = MaintenanceRecord(
        id: localId,
        type: type,
        date: date,
        mileage: mileage,
        cost: cost,
        workshop: workshop,
        nextDue: nextDue,
        notes: notes,
        createdAt: DateTime.now(),
      );

      _maintenanceRecords.insert(0, newRecord);

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

  // Agregar recordatorio (solo en memoria hasta que exista endpoint)
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
      final localId = 'rem_${DateTime.now().millisecondsSinceEpoch}';
      final newReminder = Reminder(
        id: localId,
        title: title,
        description: description,
        date: date,
        type: type,
        priority: priority,
        completed: false,
        createdAt: DateTime.now(),
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

  // Marcar recordatorio como completado (solo local)
  Future<bool> completeReminder(String driverId, String reminderId) async {
    try {
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

  // Eliminar documento (backend Node aún no expone DELETE por docType)
  Future<bool> deleteDocument(String driverId, String documentId) async {
    try {
      _documents.removeWhere((doc) => doc.id == documentId);
      notifyListeners();

      AppLogger.info('Documento eliminado localmente: $documentId');
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
    _maintenanceRecords.clear();
    _reminders.clear();
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

  factory VehicleDocument.fromJson(Map<String, dynamic> data) {
    final id = (data['id'] ?? data['docType'] ?? data['type'] ?? '').toString();
    final type = (data['docType'] ?? data['type'] ?? '').toString();

    return VehicleDocument(
      id: id,
      type: type,
      number: (data['number'] ?? '').toString(),
      issueDate: _parseDate(data['issueDate']) ?? DateTime.now(),
      expiryDate: _parseDate(data['expiryDate']),
      documentUrl: (data['fileUrl'] ?? data['documentUrl'] ?? data['url'])?.toString(),
      status: _getDocumentStatus(data),
      createdAt: _parseDate(data['createdAt'] ?? data['uploadedAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static DocumentStatus _getDocumentStatus(Map<String, dynamic> data) {
    // Estado explícito del backend
    final status = data['status']?.toString();
    if (status == 'rejected') return DocumentStatus.pending;
    if (status == 'pending' || status == 'under_review') return DocumentStatus.pending;

    final expiry = _parseDate(data['expiryDate']);
    if (expiry == null) return DocumentStatus.valid;

    final now = DateTime.now();
    final daysDiff = expiry.difference(now).inDays;

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
      case 'technical_review':
        return Icons.build_circle;
      case 'tarjeta de propiedad':
      case 'tarjeta_propiedad':
      case 'vehicle_card':
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

  factory MaintenanceRecord.fromJson(Map<String, dynamic> data) {
    return MaintenanceRecord(
      id: (data['id'] ?? '').toString(),
      type: (data['type'] ?? '').toString(),
      date: _parseDate(data['date']) ?? DateTime.now(),
      mileage: (data['mileage'] is int)
          ? data['mileage'] as int
          : int.tryParse(data['mileage']?.toString() ?? '0') ?? 0,
      cost: (data['cost'] is num)
          ? (data['cost'] as num).toDouble()
          : double.tryParse(data['cost']?.toString() ?? '0') ?? 0.0,
      workshop: (data['workshop'] ?? '').toString(),
      nextDue: _parseDate(data['nextDue']),
      notes: data['notes']?.toString(),
      createdAt: _parseDate(data['createdAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
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

  factory Reminder.fromJson(Map<String, dynamic> data) {
    final typeIdx = (data['type'] is int)
        ? data['type'] as int
        : int.tryParse(data['type']?.toString() ?? '') ?? 0;
    final priorityIdx = (data['priority'] is int)
        ? data['priority'] as int
        : int.tryParse(data['priority']?.toString() ?? '') ?? 2;

    return Reminder(
      id: (data['id'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      date: _parseDate(data['date']) ?? DateTime.now(),
      type: ReminderType.values[typeIdx.clamp(0, ReminderType.values.length - 1)],
      priority: Priority.values[priorityIdx.clamp(0, Priority.values.length - 1)],
      completed: data['completed'] == true,
      createdAt: _parseDate(data['createdAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}

enum DocumentStatus { valid, expiringSoon, expired, pending }
enum ReminderType { document, maintenance, payment, other }
enum Priority { high, medium, low }
