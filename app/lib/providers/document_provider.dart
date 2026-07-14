import 'dart:io';

import 'package:flutter/material.dart';

import '../services/rapi_api_client.dart';

class DocumentProvider extends ChangeNotifier {
  final RapiApiClient _api = RapiApiClient.instance;

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

  // Cargar documentos del conductor desde el backend
  Future<void> loadDriverDocuments(String driverId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.myDocuments();
      _driverDocuments = _parseDocumentsResponse(response);

      // Cargar estado de verificación
      await loadVerificationStatus(driverId);
    } catch (e) {
      _error = 'Error al cargar documentos: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Cargar estado de verificación desde el perfil del conductor
  Future<void> loadVerificationStatus(String driverId) async {
    try {
      debugPrint('📄 DocumentProvider: Cargando estado de verificación para: $driverId');

      final profile = await _api.myDriverProfile();
      debugPrint('📄 DocumentProvider: isVerified=${profile['isVerified']}, driverStatus=${profile['driverStatus']}');

      final isVerified = profile['isVerified'] == true;
      final driverStatus = (profile['driverStatus'] ?? 'pending_approval').toString();

      // Determinar verificationStatus basado en driverStatus
      String verificationStatus;
      if (isVerified || driverStatus == 'approved') {
        verificationStatus = 'approved';
      } else if (driverStatus == 'rejected') {
        verificationStatus = 'rejected';
      } else if (driverStatus == 'under_review' || driverStatus == 'pending_verification') {
        verificationStatus = 'under_review';
      } else {
        verificationStatus = 'pending';
      }

      _verificationStatus = {
        'isVerified': isVerified,
        'verificationStatus': verificationStatus,
        'verificationDate': profile['approvedAt'],
        'rejectionReason': profile['rejectionReason'],
      };

      debugPrint('📄 DocumentProvider: Estado final: $_verificationStatus');
    } catch (e) {
      debugPrint('📄 DocumentProvider: ❌ Error: $e');
      _error = 'Error al cargar estado de verificación: $e';
    }
    notifyListeners();
  }

  // Subir documento al backend Node (uploadFile + uploadDocument)
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
      // Paso 1: subir archivo a storage y obtener URL pública
      _uploadProgress = 0.3;
      notifyListeners();

      final uploaded = await _api.uploadFile(file: file, scope: 'documents');
      final fileUrl = uploaded['url']?.toString() ?? '';
      if (fileUrl.isEmpty) {
        throw Exception('El servidor no devolvió URL del archivo');
      }

      _uploadProgress = 0.7;
      notifyListeners();

      // Paso 2: registrar el documento asociado al conductor
      await _api.uploadDocument(docType: documentType, fileUrl: fileUrl);

      _uploadProgress = 1.0;

      // Actualizar estado local
      _driverDocuments ??= {};
      _driverDocuments![documentType] = {
        'url': fileUrl,
        'uploadedAt': DateTime.now(),
        'fileName': (uploaded['key'] ?? file.path.split('/').last).toString(),
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

  // Eliminar documento (el backend no expone endpoint de eliminación por
  // tipo actualmente; se limpia solamente el estado local para reflejar la
  // intención del usuario)
  Future<bool> deleteDocument({
    required String driverId,
    required String documentType,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Actualizar estado local (backend Node aún no expone DELETE por docType)
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

  // Solicitar verificación — el backend evalúa automáticamente al subir todos
  // los documentos requeridos. Aquí solo actualizamos el estado local a
  // "under_review" para reflejar la UI.
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
      // Refrescar perfil para leer el estado real del backend
      await loadVerificationStatus(driverId);

      // Si el backend todavía no cambió de estado, marcarlo localmente
      // como under_review para que la pantalla muestre el estado correcto.
      final currentStatus = _verificationStatus?['verificationStatus']?.toString();
      if (currentStatus == 'pending') {
        _verificationStatus = {
          ..._verificationStatus ?? const {},
          'verificationStatus': 'under_review',
        };
      }

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

  // Cargar documentos del vehículo (mismo endpoint /me/documents)
  Future<void> loadVehicleDocuments(String driverId, String vehicleId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.myDocuments();
      final docs = response['documents'];
      if (docs is List) {
        _vehicleDocuments = docs.whereType<Map>().map<Map<String, dynamic>>((d) {
          final map = Map<String, dynamic>.from(d);
          return {
            'id': (map['id'] ?? map['docType'] ?? '').toString(),
            ...map,
          };
        }).toList();
      } else {
        _vehicleDocuments = [];
      }
    } catch (e) {
      _error = 'Error al cargar documentos del vehículo: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Convierte la respuesta del endpoint /api/drivers/me/documents en el mapa
  // por docType que usan las pantallas existentes.
  Map<String, dynamic> _parseDocumentsResponse(Map<String, dynamic> response) {
    final Map<String, dynamic> mapped = {};
    final docs = response['documents'];
    if (docs is List) {
      for (final entry in docs) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(entry);
        final type = (map['docType'] ?? map['type'])?.toString();
        if (type == null || type.isEmpty) continue;

        final uploadedIso = map['uploadedAt']?.toString();
        DateTime? uploadedAt;
        if (uploadedIso != null && uploadedIso.isNotEmpty) {
          uploadedAt = DateTime.tryParse(uploadedIso);
        }

        final status = (map['status'] ?? 'pending').toString();

        mapped[type] = {
          'url': (map['fileUrl'] ?? map['url'])?.toString(),
          'uploadedAt': uploadedAt,
          'fileName': map['fileName']?.toString(),
          'status': status,
          'verified': map['verified'] == true || status == 'approved' || status == 'verified',
        };
      }
    } else if (docs is Map) {
      mapped.addAll(Map<String, dynamic>.from(docs));
    }
    return mapped;
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
