import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/logger.dart';
import '../services/rapi_api_client.dart';
import '../services/rapi_sse_client.dart';

// Modelo para contacto de emergencia
class EmergencyContact {
  final String id;
  final String userId;
  final String name;
  final String phone;
  final String? relationship;
  final bool isPrimary;
  final bool notifyAutomatically;

  EmergencyContact({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    this.relationship,
    required this.isPrimary,
    required this.notifyAutomatically,
  });

  factory EmergencyContact.fromMap(Map<String, dynamic> map, [String? id]) {
    return EmergencyContact(
      id: (id ?? map['id'] ?? '').toString(),
      userId: (map['userId'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      phone: (map['phone'] ?? map['phoneNumber'] ?? '').toString(),
      relationship: map['relationship']?.toString(),
      isPrimary: map['isPrimary'] == true || map['isPrimary'] == 1,
      notifyAutomatically:
          map['notifyAutomatically'] == null ? true : map['notifyAutomatically'] == true || map['notifyAutomatically'] == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'phone': phone,
      'relationship': relationship,
      'isPrimary': isPrimary,
      'notifyAutomatically': notifyAutomatically,
    };
  }
}

// Modelo para alerta de emergencia
class EmergencyAlert {
  final String id;
  final String userId;
  final String userName;
  final String? userPhone;
  final String? userPhoto;
  final String? userRole;
  final String? tripId;
  final EmergencyType type;
  final String status; // 'active', 'resolved', 'cancelled'
  final double? locationLat;
  final double? locationLng;
  final String? locationAddress;
  final String? description;
  final List<String> notifiedContacts;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final DateTime? resolvedAt;
  final String? driverName;
  final String? vehiclePlate;
  final Map<String, dynamic>? metadata;

  EmergencyAlert({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhone,
    this.userPhoto,
    this.userRole,
    this.tripId,
    required this.type,
    required this.status,
    this.locationLat,
    this.locationLng,
    this.locationAddress,
    this.description,
    required this.notifiedContacts,
    required this.createdAt,
    this.respondedAt,
    this.resolvedAt,
    this.driverName,
    this.vehiclePlate,
    this.metadata,
  });

  factory EmergencyAlert.fromMap(Map<String, dynamic> map, [String? id]) {
    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v);
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      return null;
    }

    // El backend puede anidar la ubicación en un sub-objeto o exponerla plana.
    final locMap = map['location'] is Map
        ? Map<String, dynamic>.from(map['location'] as Map)
        : const <String, dynamic>{};

    return EmergencyAlert(
      id: (id ?? map['id'] ?? '').toString(),
      userId: (map['userId'] ?? '').toString(),
      userName: (map['userName'] ?? 'Usuario').toString(),
      userPhone: map['userPhone']?.toString(),
      userPhoto: map['userPhoto']?.toString(),
      userRole: map['userRole']?.toString(),
      tripId: (map['tripId'] ?? map['rideId'])?.toString(),
      type: EmergencyType.values.firstWhere(
        (e) => e.toString() == 'EmergencyType.${map['type']}',
        orElse: () => EmergencyType.general,
      ),
      status: (map['status'] ?? 'active').toString(),
      locationLat: parseDouble(map['locationLat'] ?? map['latitude'] ?? locMap['lat'] ?? locMap['latitude']),
      locationLng: parseDouble(map['locationLng'] ?? map['longitude'] ?? locMap['lng'] ?? locMap['longitude']),
      locationAddress: (map['locationAddress'] ?? map['address'] ?? locMap['address'])?.toString(),
      description: map['description']?.toString(),
      notifiedContacts:
          (map['notifiedContacts'] as List?)?.map((e) => e.toString()).toList() ?? <String>[],
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
      respondedAt: parseDate(map['respondedAt']),
      resolvedAt: parseDate(map['resolvedAt']),
      driverName: map['driverName']?.toString(),
      vehiclePlate: map['vehiclePlate']?.toString(),
      metadata: map['metadata'] is Map
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhone': userPhone,
      'userPhoto': userPhoto,
      'userRole': userRole,
      'tripId': tripId,
      'type': type.toString().split('.').last,
      'status': status,
      'locationLat': locationLat,
      'locationLng': locationLng,
      'locationAddress': locationAddress,
      'description': description,
      'notifiedContacts': notifiedContacts,
      'createdAt': createdAt.toIso8601String(),
      'respondedAt': respondedAt?.toIso8601String(),
      'resolvedAt': resolvedAt?.toIso8601String(),
      'driverName': driverName,
      'vehiclePlate': vehiclePlate,
      'metadata': metadata,
    };
  }
}

enum EmergencyType {
  general,
  medical,
  security,
  accident,
  harassment,
  vehicleBreakdown,
}

class EmergencyProvider extends ChangeNotifier {
  final RapiApiClient _api = RapiApiClient.instance;
  final RapiSseClient _sse = RapiSseClient.instance;

  // Estado
  List<EmergencyContact> _contacts = [];
  EmergencyAlert? _activeAlert;
  List<EmergencyAlert> _alertHistory = [];
  bool _isLoading = false;
  String? _error;
  bool _sosActive = false;
  Position? _currentLocation;

  // Números de emergencia locales (Perú)
  final Map<String, String> _emergencyNumbers = {
    'police': '105',
    'medical': '106',
    'fire': '116',
    'serenazgo': '101',
  };

  // Subscriptions para evitar memory leaks
  StreamSubscription<Map<String, dynamic>>? _notificationsSubscription;
  StreamSubscription? _locationTrackingSubscription;

  // Getters
  List<EmergencyContact> get contacts => _contacts;
  EmergencyAlert? get activeAlert => _activeAlert;
  List<EmergencyAlert> get alertHistory => _alertHistory;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get sosActive => _sosActive;
  Position? get currentLocation => _currentLocation;
  Map<String, String> get emergencyNumbers => _emergencyNumbers;

  EmergencyProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    if (!_api.isSignedIn) return;

    await Future.wait([
      _loadContacts(),
      _loadAlerts(),
    ]);

    // El backend Node emite eventos SSE via el canal `notifications`. Cuando
    // llega una notificación relacionada con emergencias, refrescamos el estado.
    _notificationsSubscription = _sse.notifications.listen((event) {
      final category = (event['category'] ?? event['type'] ?? '').toString();
      if (category.startsWith('emergency') || category == 'sos' || category == 'panic') {
        _loadAlerts();
      }
    });
  }

  Future<void> _loadContacts() async {
    try {
      final res = await _api.listEmergencyContacts();
      final items = _extractList(res);
      _contacts = items
          .whereType<Map>()
          .map((e) => EmergencyContact.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      // Primero los contactos primarios (compatibilidad con orderBy anterior).
      _contacts.sort((a, b) {
        if (a.isPrimary == b.isPrimary) return 0;
        return a.isPrimary ? -1 : 1;
      });
      notifyListeners();
    } catch (e) {
      AppLogger.error('Error cargando contactos de emergencia', e);
    }
  }

  Future<void> _loadAlerts() async {
    try {
      final res = await _api.listEmergencies();
      final items = _extractList(res);
      _alertHistory = items
          .whereType<Map>()
          .map((e) => EmergencyAlert.fromMap(Map<String, dynamic>.from(e)))
          .toList();

      EmergencyAlert? active;
      for (final a in _alertHistory) {
        if (a.status == 'active') {
          active = a;
          break;
        }
      }
      _activeAlert = active;
      _sosActive = active != null;
      notifyListeners();
    } catch (e) {
      AppLogger.error('Error cargando historial de emergencias', e);
    }
  }

  /// Extrae la lista principal de la respuesta HTTP. El backend puede exponer
  /// los items bajo distintas claves; probamos las convenciones comunes.
  List<dynamic> _extractList(Map<String, dynamic> res) {
    for (final k in const ['items', 'data', 'contacts', 'emergencies', 'results']) {
      final v = res[k];
      if (v is List) return v;
    }
    return const [];
  }

  // Activar SOS de emergencia
  Future<bool> activateSOS({
    required EmergencyType type,
    String? tripId,
    String? description,
    bool notifyContacts = true,
    bool callEmergency = false,
  }) async {
    _setLoading(true);
    try {
      if (!_api.isSignedIn) throw Exception('Usuario no autenticado');

      // Obtener ubicación actual
      await _getCurrentLocation();
      if (_currentLocation == null) {
        throw Exception('No se pudo obtener la ubicación');
      }

      // Obtener información del usuario para enriquecer la alerta local
      Map<String, dynamic>? me;
      try {
        me = await _api.me();
      } catch (_) {
        me = null;
      }

      final typeString = type.toString().split('.').last;
      final address = await _getAddressFromLocation(_currentLocation!);

      // Registrar emergencia en el backend
      final response = await _api.createEmergency(
        type: typeString,
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
        address: address,
        description: description,
        rideId: tripId,
      );

      final createdMap = response['emergency'] is Map
          ? Map<String, dynamic>.from(response['emergency'] as Map)
          : response;
      final alertId = (createdMap['id'] ?? response['id'] ?? '').toString();

      _activeAlert = EmergencyAlert(
        id: alertId,
        userId: (me?['id'] ?? me?['uid'] ?? '').toString(),
        userName: (me?['name'] ?? me?['fullName'] ?? 'Usuario').toString(),
        userPhone: me?['phone']?.toString(),
        userPhoto: (me?['photoUrl'] ?? me?['avatarUrl'])?.toString(),
        userRole: me?['role']?.toString(),
        tripId: tripId,
        type: type,
        status: 'active',
        locationLat: _currentLocation!.latitude,
        locationLng: _currentLocation!.longitude,
        locationAddress: address,
        description: description,
        notifiedContacts: [],
        createdAt: DateTime.now(),
        metadata: {
          'deviceInfo': {
            'platform': 'mobile',
            'batteryLevel': await _getBatteryLevel(),
          },
        },
      );

      _sosActive = true;

      // Notificar contactos de emergencia (SMS local con sms:)
      if (notifyContacts) {
        await _notifyEmergencyContacts(alertId);
      }

      // Llamar a emergencias si es necesario
      if (callEmergency) {
        await callEmergencyNumber(_getEmergencyNumberByType(type));
      }

      // Iniciar tracking local de ubicación
      _startLocationTracking(alertId);

      _setLoading(false);
      // Refrescar historial con el registro recién creado
      await _loadAlerts();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Error al activar SOS: $e');
      _setLoading(false);
      return false;
    }
  }

  // Desactivar SOS
  Future<bool> deactivateSOS({String? resolution}) async {
    if (_activeAlert == null) return false;

    _setLoading(true);
    try {
      // El cliente Rapi no expone un endpoint dedicado para resolver.
      // Actualizamos el estado local y refrescamos desde el servidor.
      _sosActive = false;
      _activeAlert = null;
      _stopLocationTracking();

      _setLoading(false);
      await _loadAlerts();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Error al desactivar SOS: $e');
      _setLoading(false);
      return false;
    }
  }

  // Agregar contacto de emergencia
  Future<bool> addEmergencyContact({
    required String name,
    required String phone,
    String? relationship,
    bool isPrimary = false,
    bool notifyAutomatically = true,
  }) async {
    _setLoading(true);
    try {
      if (!_api.isSignedIn) throw Exception('Usuario no autenticado');

      await _api.addEmergencyContact(
        name: name,
        phone: phone,
        relationship: relationship,
        isPrimary: isPrimary,
      );

      // Recargamos la lista desde el servidor para reflejar el nuevo id/orden.
      await _loadContacts();

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Error al agregar contacto: $e');
      _setLoading(false);
      return false;
    }
  }

  // Eliminar contacto de emergencia
  Future<bool> removeEmergencyContact(String contactId) async {
    _setLoading(true);
    try {
      // El cliente Rapi no expone endpoint delete todavía. Actualizamos la UI
      // optimísticamente y refrescamos desde el server para mantener consistencia.
      _contacts = _contacts.where((c) => c.id != contactId).toList();
      notifyListeners();
      await _loadContacts();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Error al eliminar contacto: $e');
      _setLoading(false);
      return false;
    }
  }

  // Notificar contactos de emergencia via SMS local
  Future<void> _notifyEmergencyContacts(String alertId) async {
    try {
      for (final contact in _contacts) {
        if (contact.notifyAutomatically) {
          await _sendEmergencySMS(contact.phone, alertId);
        }
      }
    } catch (e) {
      AppLogger.error('Error notificando contactos', e);
    }
  }

  // Enviar SMS de emergencia (abre la app de SMS con el mensaje pre-compuesto)
  Future<void> _sendEmergencySMS(String phone, String alertId) async {
    try {
      final message = '''
🚨 EMERGENCIA - Rappi Team
Tu contacto necesita ayuda.
Ubicación: https://maps.google.com/?q=${_currentLocation?.latitude},${_currentLocation?.longitude}
Ver detalles: https://rapiteam.app/emergency/$alertId
''';

      final smsUrl = 'sms:$phone?body=${Uri.encodeComponent(message)}';
      if (await canLaunchUrl(Uri.parse(smsUrl))) {
        await launchUrl(Uri.parse(smsUrl));
      }
    } catch (e) {
      AppLogger.error('Error enviando SMS', e);
    }
  }

  // Llamar número de emergencia
  Future<void> callEmergencyNumber(String number) async {
    try {
      final telUrl = 'tel:$number';
      if (await canLaunchUrl(Uri.parse(telUrl))) {
        await launchUrl(Uri.parse(telUrl));
      }
    } catch (e) {
      AppLogger.error('Error llamando emergencia', e);
    }
  }

  // Obtener ubicación actual
  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      _currentLocation = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (e) {
      AppLogger.error('Error obteniendo ubicación', e);
    }
  }

  // Obtener dirección desde ubicación
  Future<String?> _getAddressFromLocation(Position position) async {
    try {
      // TODO: integrar con geocoding real (mapsAutocomplete no aplica aquí).
      return '${position.latitude}, ${position.longitude}';
    } catch (e) {
      return null;
    }
  }

  // Obtener nivel de batería (placeholder — se integrará con battery_plus)
  Future<int> _getBatteryLevel() async {
    try {
      return 100;
    } catch (e) {
      return 0;
    }
  }

  // Obtener número de emergencia por tipo
  String _getEmergencyNumberByType(EmergencyType type) {
    switch (type) {
      case EmergencyType.medical:
        return _emergencyNumbers['medical']!;
      case EmergencyType.security:
      case EmergencyType.harassment:
        return _emergencyNumbers['police']!;
      case EmergencyType.accident:
        return _emergencyNumbers['medical']!;
      default:
        return _emergencyNumbers['police']!;
    }
  }

  // Iniciar tracking local de ubicación durante emergencia
  void _startLocationTracking(String alertId) {
    _locationTrackingSubscription?.cancel();
    // Actualiza la ubicación local cada 30s mientras el SOS esté activo.
    // El cliente Rapi todavía no expone endpoint para push de ubicación de
    // emergencia; mantener el estado local permitirá reenviarlo cuando exista.
    _locationTrackingSubscription =
        Stream.periodic(const Duration(seconds: 30)).listen((_) async {
      if (!_sosActive) return;
      await _getCurrentLocation();
      notifyListeners();
    });
  }

  // Detener tracking de ubicación
  void _stopLocationTracking() {
    _locationTrackingSubscription?.cancel();
    _locationTrackingSubscription = null;
  }

  // Enviar mensaje rápido de emergencia
  Future<bool> sendQuickEmergencyMessage(String template) async {
    final templates = {
      'help': 'Necesito ayuda urgente',
      'unsafe': 'Me siento inseguro/a',
      'accident': 'He tenido un accidente',
      'medical': 'Necesito asistencia médica',
      'breakdown': 'El vehículo se ha averiado',
    };

    final message = templates[template] ?? template;
    return await activateSOS(
      type: EmergencyType.general,
      description: message,
    );
  }

  // Compartir ubicación en tiempo real
  Future<String> shareRealtimeLocation() async {
    try {
      await _getCurrentLocation();
      if (_currentLocation == null) return '';
      // El backend no expone un endpoint dedicado para "shared locations",
      // así que devolvemos un link directo a Google Maps.
      return 'https://maps.google.com/?q=${_currentLocation!.latitude},${_currentLocation!.longitude}';
    } catch (e) {
      AppLogger.error('Error compartiendo ubicación', e);
      return '';
    }
  }

  // Helpers
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    if (error != null) {
      AppLogger.info(error);
    }
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _notificationsSubscription?.cancel();
    _stopLocationTracking();
    super.dispose();
  }
}
