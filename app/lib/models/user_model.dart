import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Modelo de Usuario con soporte dual-account estilo InDriver
class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String userType; // 'passenger', 'driver', 'admin', 'dual'
  final String profilePhotoUrl;
  final bool isActive;
  final bool isVerified;
  final bool emailVerified;
  final bool phoneVerified;
  final bool documentVerified; // Verificación de DNI por administrador
  final String? identityDocument; // Número de DNI/documento
  final DateTime createdAt;
  final DateTime updatedAt;
  final double rating;
  final int totalTrips;
  final double balance;
  final LatLng? location;
  final String? fcmToken;
  final bool? isAvailable; // Solo para conductores
  final Map<String, dynamic>? vehicleInfo; // Solo para conductores

  // ✅ NUEVO: Fecha de nacimiento
  final String? birthDate; // Formato: DD/MM/YYYY

  // ✅ NUEVO: Campos para sistema dual-account (InDriver style)
  final String? currentMode; // 'passenger' | 'driver' - Modo activo actual
  final List<String>? availableRoles; // ['passenger'] o ['passenger', 'driver']
  final Map<String, dynamic>? driverProfile; // Datos específicos de conductor

  // ✅ NUEVO: Estado del conductor para flujo de aprobación
  // Valores: 'pending_documents', 'pending_approval', 'approved', 'rejected'
  final String? driverStatus;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.userType,
    this.profilePhotoUrl = '',
    this.isActive = true,
    this.isVerified = false,
    this.emailVerified = false,
    this.phoneVerified = false,
    this.documentVerified = false,
    this.identityDocument,
    required this.createdAt,
    required this.updatedAt,
    this.rating = 5.0,
    this.totalTrips = 0,
    this.balance = 0.0,
    this.location,
    this.fcmToken,
    this.isAvailable,
    this.vehicleInfo,
    // ✅ NUEVO: Fecha de nacimiento
    this.birthDate,
    // ✅ NUEVO: Parámetros para dual-account
    this.currentMode,
    this.availableRoles,
    this.driverProfile,
    // ✅ NUEVO: Estado del conductor
    this.driverStatus,
  });

  /// Crear desde JSON con compatibilidad backward
  factory UserModel.fromJson(Map<String, dynamic> json) {
    final userType = json['userType'] ?? 'passenger';

    // ✅ Compatibilidad backward: derivar currentMode y availableRoles si no existen
    final currentMode = json['currentMode'] ??
        (userType == 'dual' ? 'passenger' : userType);

    final List<String> availableRoles = json['availableRoles'] != null
        ? (json['availableRoles'] as List).cast<String>()
        : (userType == 'dual'
            ? ['passenger', 'driver']
            : [userType]);

    return UserModel(
      id: json['id'] ?? '',
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? json['phoneNumber'] ?? '', // ✅ Compatibilidad con ambos nombres de campo
      userType: userType,
      profilePhotoUrl: json['profilePhotoUrl'] ?? '',
      isActive: json['isActive'] ?? true,
      isVerified: json['isVerified'] ?? false,
      emailVerified: json['emailVerified'] ?? false,
      phoneVerified: json['phoneVerified'] ?? false,
      documentVerified: json['documentVerified'] ?? false,
      identityDocument: json['identityDocument'],
      createdAt: json['createdAt'] is DateTime
          ? json['createdAt']
          : DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: json['updatedAt'] is DateTime
          ? json['updatedAt']
          : DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
      rating: (json['rating'] ?? 5.0).toDouble(),
      totalTrips: json['totalTrips'] ?? 0,
      balance: (json['balance'] ?? 0.0).toDouble(),
      location: json['location'] != null
          ? LatLng(
              (json['location']['lat'] ?? 0.0).toDouble(),
              (json['location']['lng'] ?? 0.0).toDouble(),
            )
          : null,
      fcmToken: json['fcmToken'],
      isAvailable: json['isAvailable'],
      vehicleInfo: json['vehicleInfo'],
      // ✅ NUEVO: Fecha de nacimiento
      birthDate: json['birthDate'],
      // ✅ NUEVO: Campos dual-account
      currentMode: currentMode,
      availableRoles: availableRoles,
      driverProfile: json['driverProfile'],
      // ✅ NUEVO: Estado del conductor
      driverStatus: json['driverStatus'],
    );
  }

  /// Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'userType': userType,
      'profilePhotoUrl': profilePhotoUrl,
      'isActive': isActive,
      'isVerified': isVerified,
      'emailVerified': emailVerified,
      'phoneVerified': phoneVerified,
      'documentVerified': documentVerified,
      'identityDocument': identityDocument,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'rating': rating,
      'totalTrips': totalTrips,
      'balance': balance,
      'location': location != null
          ? {
              'lat': location!.latitude,
              'lng': location!.longitude,
            }
          : null,
      'fcmToken': fcmToken,
      'isAvailable': isAvailable,
      'vehicleInfo': vehicleInfo,
      // ✅ NUEVO: Fecha de nacimiento
      'birthDate': birthDate,
      // ✅ NUEVO: Campos dual-account
      'currentMode': currentMode,
      'availableRoles': availableRoles,
      'driverProfile': driverProfile,
      // ✅ NUEVO: Estado del conductor
      'driverStatus': driverStatus,
    };
  }

  /// Copiar con cambios
  UserModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    String? userType,
    String? profilePhotoUrl,
    bool? isActive,
    bool? isVerified,
    bool? emailVerified,
    bool? phoneVerified,
    bool? documentVerified,
    String? identityDocument,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? rating,
    int? totalTrips,
    double? balance,
    LatLng? location,
    String? fcmToken,
    bool? isAvailable,
    Map<String, dynamic>? vehicleInfo,
    // ✅ NUEVO: Fecha de nacimiento
    String? birthDate,
    // ✅ NUEVO: Parámetros dual-account
    String? currentMode,
    List<String>? availableRoles,
    Map<String, dynamic>? driverProfile,
    // ✅ NUEVO: Estado del conductor
    String? driverStatus,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      userType: userType ?? this.userType,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      emailVerified: emailVerified ?? this.emailVerified,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      documentVerified: documentVerified ?? this.documentVerified,
      identityDocument: identityDocument ?? this.identityDocument,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rating: rating ?? this.rating,
      totalTrips: totalTrips ?? this.totalTrips,
      balance: balance ?? this.balance,
      location: location ?? this.location,
      fcmToken: fcmToken ?? this.fcmToken,
      isAvailable: isAvailable ?? this.isAvailable,
      vehicleInfo: vehicleInfo ?? this.vehicleInfo,
      // ✅ NUEVO: Fecha de nacimiento
      birthDate: birthDate ?? this.birthDate,
      // ✅ NUEVO: Campos dual-account
      currentMode: currentMode ?? this.currentMode,
      availableRoles: availableRoles ?? this.availableRoles,
      driverProfile: driverProfile ?? this.driverProfile,
      // ✅ NUEVO: Estado del conductor
      driverStatus: driverStatus ?? this.driverStatus,
    );
  }

  /// Verificar si es conductor (puro o dual en modo conductor)
  bool get isDriver =>
      userType == 'driver' || (userType == 'dual' && currentMode == 'driver');

  /// Verificar si es pasajero (puro o dual en modo pasajero)
  bool get isPassenger =>
      userType == 'passenger' ||
      (userType == 'dual' && currentMode == 'passenger');

  /// Verificar si es admin
  bool get isAdmin => userType == 'admin';

  // ✅ NUEVOS GETTERS: Sistema dual-account

  /// Verificar si tiene cuenta dual (puede ser pasajero Y conductor)
  bool get isDualAccount => userType == 'dual';

  /// Verificar si puede cambiar a modo conductor
  bool get canSwitchToDriver =>
      isDualAccount && availableRoles?.contains('driver') == true;

  /// Verificar si puede cambiar a modo pasajero
  bool get canSwitchToPassenger =>
      isDualAccount && availableRoles?.contains('passenger') == true;

  /// Obtener modo actual (con fallback a userType para backward compatibility)
  String get activeMode => currentMode ?? userType;

  /// Verificar si está en modo conductor actualmente
  bool get isInDriverMode => activeMode == 'driver';

  /// Verificar si está en modo pasajero actualmente
  bool get isInPassengerMode => activeMode == 'passenger';

  /// Obtener nombre para mostrar
  String get displayName {
    if (fullName.isNotEmpty) return fullName;
    if (email.isNotEmpty) return email;
    return 'Usuario';
  }

  @override
  String toString() {
    return 'UserModel(id: $id, fullName: $fullName, email: $email, userType: $userType)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  /// Constructor para crear desde Firestore Document con compatibilidad backward
  factory UserModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    final userType = data['userType'] ?? 'passenger';

    // ✅ Compatibilidad backward: derivar currentMode y availableRoles si no existen
    final currentMode = data['currentMode'] ??
        (userType == 'dual' ? 'passenger' : userType);

    final List<String> availableRoles = data['availableRoles'] != null
        ? (data['availableRoles'] as List).cast<String>()
        : (userType == 'dual'
            ? ['passenger', 'driver']
            : [userType]);

    return UserModel(
      id: documentId,
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      userType: userType,
      profilePhotoUrl: data['profilePhotoUrl'] ?? '',
      isActive: data['isActive'] ?? true,
      isVerified: data['isVerified'] ?? false,
      emailVerified: data['emailVerified'] ?? false,
      phoneVerified: data['phoneVerified'] ?? false,
      documentVerified: data['documentVerified'] ?? false,
      identityDocument: data['identityDocument'],
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: data['updatedAt']?.toDate() ?? DateTime.now(),
      rating: (data['rating'] ?? 5.0).toDouble(),
      totalTrips: data['totalTrips'] ?? 0,
      balance: (data['balance'] ?? 0.0).toDouble(),
      location: data['location'] != null
          ? LatLng(
              (data['location']['lat'] ?? 0.0).toDouble(),
              (data['location']['lng'] ?? 0.0).toDouble(),
            )
          : null,
      fcmToken: data['fcmToken'],
      isAvailable: data['isAvailable'],
      vehicleInfo: data['vehicleInfo'],
      // ✅ NUEVO: Campos dual-account
      currentMode: currentMode,
      availableRoles: availableRoles,
      driverProfile: data['driverProfile'],
      // ✅ NUEVO: Estado del conductor
      driverStatus: data['driverStatus'],
    );
  }
}