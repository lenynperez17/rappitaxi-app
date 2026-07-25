import 'dart:io';

import 'package:flutter/material.dart';

import '../services/rapi_api_client.dart';
import '../utils/error_messages.dart';
import '../utils/document_storage_scope.dart';

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

  // Ronda 232: IDs alineados con el enum backend
  // (driver_documents.doc_type CHECK: dni_front, dni_back, license_front,
  // license_back, soat, tarjeta_propiedad, ownership, selfie, vehicle_photo).
  // Antes eran IDs Firebase legacy (license, dni, criminal_record,
  // vehicle_card, technical_review) que no matcheaban con nada del backend.
  final List<Map<String, dynamic>> requiredDocuments = [
    {'id': 'dni_front',         'name': 'DNI (frente)',                 'description': 'Cara frontal del DNI',                'icon': Icons.credit_card,      'required': true},
    {'id': 'dni_back',          'name': 'DNI (reverso)',                'description': 'Cara posterior del DNI',              'icon': Icons.credit_card,      'required': true},
    {'id': 'license_front',     'name': 'Licencia (frente)',            'description': 'Licencia de conducir vigente — frente','icon': Icons.badge,            'required': true},
    {'id': 'license_back',      'name': 'Licencia (reverso)',           'description': 'Licencia de conducir vigente — reverso','icon': Icons.badge,           'required': true},
    {'id': 'soat',              'name': 'SOAT vigente',                 'description': 'Seguro Obligatorio de Accidentes',    'icon': Icons.security,         'required': true},
    {'id': 'tarjeta_propiedad', 'name': 'Tarjeta de propiedad (frente)','description': 'Registro vehicular — frente',         'icon': Icons.directions_car,   'required': false},
    {'id': 'ownership',         'name': 'Tarjeta de propiedad (reverso)','description': 'Registro vehicular — reverso',       'icon': Icons.directions_car,   'required': false},
    {'id': 'selfie',            'name': 'Selfie del conductor',         'description': 'Foto de rostro para verificación',    'icon': Icons.person,           'required': false},
    {'id': 'vehicle_photo',     'name': 'Foto del vehículo',            'description': 'Foto del vehículo que usarás',        'icon': Icons.photo_camera,     'required': false},
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
      _error = userFriendlyError(e, fallback: 'Error al cargar documentos');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Cargar estado de verificación desde el perfil del conductor
  Future<void> loadVerificationStatus(String driverId) async {
    try {
      debugPrint('📄 DocumentProvider: Cargando estado de verificación para: $driverId');

      final resp = await _api.myDriverProfile();
      // Ronda 232 fix: el backend responde {success, profile: {isVerified,
      // userType, ...}}. Antes leíamos resp['isVerified'] (path incorrecto)
      // → siempre false → nunca se aprobaba el estado en el DocumentProvider.
      final profile = (resp['profile'] as Map?)?.cast<String, dynamic>() ?? resp;
      debugPrint('📄 DocumentProvider: isVerified=${profile['isVerified']}, userType=${profile['userType']}');

      // Un driver está aprobado si isVerified=true Y userType es dual/driver
      // (backend NO devuelve driverStatus — es campo legacy Firebase).
      final isVerified = profile['isVerified'] == true;
      final userType = (profile['userType'] ?? profile['user_type'] ?? '').toString();
      final driverStatus = (isVerified && (userType == 'dual' || userType == 'driver'))
          ? 'approved'
          : 'pending_approval';

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
      _error = userFriendlyError(e, fallback: 'Error al cargar estado de verificación');
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

      final uploaded = await _api.uploadFile(file: file, scope: storageScopeForDocType(documentType));
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
      _error = userFriendlyError(e, fallback: 'Error al subir documento');
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
      _error = userFriendlyError(e, fallback: 'Error al eliminar documento');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Verificar si todos los documentos están completos.
  // Ronda 95: un doc rechazado NO cuenta como completo. Antes:
  // containsKey era true aunque status='rejected' → requestVerification pasaba
  // con documentos que debían re-subirse y forzaba local under_review
  // ocultando al usuario que aún tenía rechazos pendientes.
  bool areAllDocumentsComplete() {
    if (_driverDocuments == null) return false;

    for (var doc in requiredDocuments) {
      if (doc['required'] == true) {
        final docId = doc['id'] as String;
        if (!_driverDocuments!.containsKey(docId)) return false;
        final status = getDocumentStatus(docId);
        if (status == 'rejected' || status == 'expired') return false;
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
      _error = userFriendlyError(e, fallback: 'Error al solicitar verificación');
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
      _error = userFriendlyError(e, fallback: 'Error al cargar documentos del vehículo');
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
