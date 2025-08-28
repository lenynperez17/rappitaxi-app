// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserModelImpl _$$UserModelImplFromJson(Map<String, dynamic> json) =>
    _$UserModelImpl(
      id: json['id'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      name: json['name'] as String,
      photoUrl: json['photoUrl'] as String?,
      role: json['role'] as String? ?? 'passenger',
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      passengerData: json['passengerData'] == null
          ? null
          : PassengerData.fromJson(
              json['passengerData'] as Map<String, dynamic>),
      driverData: json['driverData'] == null
          ? null
          : DriverData.fromJson(json['driverData'] as Map<String, dynamic>),
      adminData: json['adminData'] == null
          ? null
          : AdminData.fromJson(json['adminData'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$UserModelImplToJson(_$UserModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'phone': instance.phone,
      'name': instance.name,
      'photoUrl': instance.photoUrl,
      'role': instance.role,
      'isActive': instance.isActive,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'passengerData': instance.passengerData,
      'driverData': instance.driverData,
      'adminData': instance.adminData,
    };

_$PassengerDataImpl _$$PassengerDataImplFromJson(Map<String, dynamic> json) =>
    _$PassengerDataImpl(
      favoriteLocations: (json['favoriteLocations'] as List<dynamic>?)
              ?.map((e) => FavoriteLocation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      paymentMethods: (json['paymentMethods'] as List<dynamic>?)
              ?.map((e) => PaymentMethod.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      totalRides: (json['totalRides'] as num?)?.toInt() ?? 0,
      totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$$PassengerDataImplToJson(_$PassengerDataImpl instance) =>
    <String, dynamic>{
      'favoriteLocations': instance.favoriteLocations,
      'paymentMethods': instance.paymentMethods,
      'rating': instance.rating,
      'totalRides': instance.totalRides,
      'totalSpent': instance.totalSpent,
    };

_$FavoriteLocationImpl _$$FavoriteLocationImplFromJson(
        Map<String, dynamic> json) =>
    _$FavoriteLocationImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      placeId: json['placeId'] as String?,
      type: json['type'] as String? ?? 'home',
    );

Map<String, dynamic> _$$FavoriteLocationImplToJson(
        _$FavoriteLocationImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'address': instance.address,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'placeId': instance.placeId,
      'type': instance.type,
    };

_$PaymentMethodImpl _$$PaymentMethodImplFromJson(Map<String, dynamic> json) =>
    _$PaymentMethodImpl(
      id: json['id'] as String,
      type: json['type'] as String,
      isDefault: json['isDefault'] as bool? ?? true,
      cardLast4: json['cardLast4'] as String?,
      cardBrand: json['cardBrand'] as String?,
      externalId: json['externalId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$PaymentMethodImplToJson(_$PaymentMethodImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'isDefault': instance.isDefault,
      'cardLast4': instance.cardLast4,
      'cardBrand': instance.cardBrand,
      'externalId': instance.externalId,
      'metadata': instance.metadata,
    };

_$DriverDataImpl _$$DriverDataImplFromJson(Map<String, dynamic> json) =>
    _$DriverDataImpl(
      licenseNumber: json['licenseNumber'] as String,
      licenseExpiry: json['licenseExpiry'] as String,
      vehicleInfo:
          VehicleInfo.fromJson(json['vehicleInfo'] as Map<String, dynamic>),
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      totalRides: (json['totalRides'] as num?)?.toInt() ?? 0,
      totalEarnings: (json['totalEarnings'] as num?)?.toDouble() ?? 0.0,
      acceptanceRate: (json['acceptanceRate'] as num?)?.toDouble() ?? 95.0,
      cancellationRate: (json['cancellationRate'] as num?)?.toDouble() ?? 5.0,
      status: json['status'] as String? ?? 'offline',
      isVerified: json['isVerified'] as bool? ?? false,
      isAvailable: json['isAvailable'] as bool? ?? true,
      documents: (json['documents'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, DocumentInfo.fromJson(e as Map<String, dynamic>)),
      ),
      workingZones: (json['workingZones'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      preferences: json['preferences'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$DriverDataImplToJson(_$DriverDataImpl instance) =>
    <String, dynamic>{
      'licenseNumber': instance.licenseNumber,
      'licenseExpiry': instance.licenseExpiry,
      'vehicleInfo': instance.vehicleInfo,
      'rating': instance.rating,
      'totalRides': instance.totalRides,
      'totalEarnings': instance.totalEarnings,
      'acceptanceRate': instance.acceptanceRate,
      'cancellationRate': instance.cancellationRate,
      'status': instance.status,
      'isVerified': instance.isVerified,
      'isAvailable': instance.isAvailable,
      'documents': instance.documents,
      'workingZones': instance.workingZones,
      'preferences': instance.preferences,
    };

_$AdminDataImpl _$$AdminDataImplFromJson(Map<String, dynamic> json) =>
    _$AdminDataImpl(
      employeeId: json['employeeId'] as String,
      department: json['department'] as String,
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      canManageDrivers: json['canManageDrivers'] as bool? ?? true,
      canManagePassengers: json['canManagePassengers'] as bool? ?? true,
      canViewReports: json['canViewReports'] as bool? ?? true,
      canManagePromotions: json['canManagePromotions'] as bool? ?? true,
      canManageAdmins: json['canManageAdmins'] as bool? ?? false,
      isSuperAdmin: json['isSuperAdmin'] as bool? ?? false,
      lastLogin: json['lastLogin'] == null
          ? null
          : DateTime.parse(json['lastLogin'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$AdminDataImplToJson(_$AdminDataImpl instance) =>
    <String, dynamic>{
      'employeeId': instance.employeeId,
      'department': instance.department,
      'permissions': instance.permissions,
      'canManageDrivers': instance.canManageDrivers,
      'canManagePassengers': instance.canManagePassengers,
      'canViewReports': instance.canViewReports,
      'canManagePromotions': instance.canManagePromotions,
      'canManageAdmins': instance.canManageAdmins,
      'isSuperAdmin': instance.isSuperAdmin,
      'lastLogin': instance.lastLogin?.toIso8601String(),
      'metadata': instance.metadata,
    };

_$VehicleInfoImpl _$$VehicleInfoImplFromJson(Map<String, dynamic> json) =>
    _$VehicleInfoImpl(
      plate: json['plate'] as String,
      brand: json['brand'] as String,
      model: json['model'] as String,
      color: json['color'] as String,
      year: (json['year'] as num).toInt(),
      type: json['type'] as String,
      soatNumber: json['soatNumber'] as String?,
      soatExpiry: json['soatExpiry'] as String?,
      photos:
          (json['photos'] as List<dynamic>?)?.map((e) => e as String).toList(),
      maintenance: json['maintenance'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$VehicleInfoImplToJson(_$VehicleInfoImpl instance) =>
    <String, dynamic>{
      'plate': instance.plate,
      'brand': instance.brand,
      'model': instance.model,
      'color': instance.color,
      'year': instance.year,
      'type': instance.type,
      'soatNumber': instance.soatNumber,
      'soatExpiry': instance.soatExpiry,
      'photos': instance.photos,
      'maintenance': instance.maintenance,
    };

_$DocumentInfoImpl _$$DocumentInfoImplFromJson(Map<String, dynamic> json) =>
    _$DocumentInfoImpl(
      type: json['type'] as String,
      number: json['number'] as String,
      fileUrl: json['fileUrl'] as String,
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
      expiryDate: json['expiryDate'] == null
          ? null
          : DateTime.parse(json['expiryDate'] as String),
      status: json['status'] as String? ?? 'pending',
      rejectionReason: json['rejectionReason'] as String?,
    );

Map<String, dynamic> _$$DocumentInfoImplToJson(_$DocumentInfoImpl instance) =>
    <String, dynamic>{
      'type': instance.type,
      'number': instance.number,
      'fileUrl': instance.fileUrl,
      'uploadedAt': instance.uploadedAt.toIso8601String(),
      'expiryDate': instance.expiryDate?.toIso8601String(),
      'status': instance.status,
      'rejectionReason': instance.rejectionReason,
    };
