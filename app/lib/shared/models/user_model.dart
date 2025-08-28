import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
class UserModel with _$UserModel {
  const factory UserModel({
    required String id,
    required String email,
    required String phone,
    required String name,
    String? photoUrl,
    @Default('passenger') String role, // passenger, driver, admin
    @Default(true) bool isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    
    // Role specific data
    PassengerData? passengerData,
    DriverData? driverData,
    AdminData? adminData,
  }) = _UserModel;
  
  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);
}

@freezed
class PassengerData with _$PassengerData {
  const factory PassengerData({
    @Default([]) List<FavoriteLocation> favoriteLocations,
    @Default([]) List<PaymentMethod> paymentMethods,
    @Default(5.0) double rating,
    @Default(0) int totalRides,
    @Default(0.0) double totalSpent,
  }) = _PassengerData;
  
  factory PassengerData.fromJson(Map<String, dynamic> json) =>
      _$PassengerDataFromJson(json);
}

@freezed
class FavoriteLocation with _$FavoriteLocation {
  const factory FavoriteLocation({
    required String id,
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    String? placeId,
    @Default('home') String type, // home, work, other
  }) = _FavoriteLocation;
  
  factory FavoriteLocation.fromJson(Map<String, dynamic> json) =>
      _$FavoriteLocationFromJson(json);
}

@freezed
class PaymentMethod with _$PaymentMethod {
  const factory PaymentMethod({
    required String id,
    required String type, // cash, card, mercadopago, yape
    @Default(true) bool isDefault,
    String? cardLast4,
    String? cardBrand,
    String? externalId, // ID de Mercado Pago, etc
    Map<String, dynamic>? metadata,
  }) = _PaymentMethod;
  
  factory PaymentMethod.fromJson(Map<String, dynamic> json) =>
      _$PaymentMethodFromJson(json);
}

@freezed
class DriverData with _$DriverData {
  const factory DriverData({
    required String licenseNumber,
    required String licenseExpiry,
    required VehicleInfo vehicleInfo,
    @Default(5.0) double rating,
    @Default(0) int totalRides,
    @Default(0.0) double totalEarnings,
    @Default(95.0) double acceptanceRate,
    @Default(5.0) double cancellationRate,
    @Default('offline') String status, // offline, online, busy, in_ride
    @Default(false) bool isVerified,
    @Default(true) bool isAvailable,
    Map<String, DocumentInfo>? documents, // license, soat, criminal_record, etc
    List<String>? workingZones,
    Map<String, dynamic>? preferences,
  }) = _DriverData;
  
  factory DriverData.fromJson(Map<String, dynamic> json) =>
      _$DriverDataFromJson(json);
}

@freezed
class AdminData with _$AdminData {
  const factory AdminData({
    required String employeeId,
    required String department,
    @Default([]) List<String> permissions,
    @Default(true) bool canManageDrivers,
    @Default(true) bool canManagePassengers,
    @Default(true) bool canViewReports,
    @Default(true) bool canManagePromotions,
    @Default(false) bool canManageAdmins,
    @Default(false) bool isSuperAdmin,
    DateTime? lastLogin,
    Map<String, dynamic>? metadata,
  }) = _AdminData;
  
  factory AdminData.fromJson(Map<String, dynamic> json) =>
      _$AdminDataFromJson(json);
}

@freezed
class VehicleInfo with _$VehicleInfo {
  const factory VehicleInfo({
    required String plate,
    required String brand,
    required String model,
    required String color,
    required int year,
    required String type, // economy, standard, premium
    String? soatNumber,
    String? soatExpiry,
    List<String>? photos,
    Map<String, dynamic>? maintenance,
  }) = _VehicleInfo;
  
  factory VehicleInfo.fromJson(Map<String, dynamic> json) =>
      _$VehicleInfoFromJson(json);
}

@freezed
class DocumentInfo with _$DocumentInfo {
  const factory DocumentInfo({
    required String type,
    required String number,
    required String fileUrl,
    required DateTime uploadedAt,
    DateTime? expiryDate,
    @Default('pending') String status, // pending, approved, rejected
    String? rejectionReason,
  }) = _DocumentInfo;
  
  factory DocumentInfo.fromJson(Map<String, dynamic> json) =>
      _$DocumentInfoFromJson(json);
}