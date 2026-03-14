import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Centralized configuration service
/// Reads fares and configuration from Firestore (config/system_config)
/// Configurable from the admin panel
class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _configDocId = 'system_config';

  // Configuration cache
  SystemConfig? _cachedConfig;
  DateTime? _lastFetch;
  static const Duration _cacheExpiration = Duration(minutes: 5);

  /// Get system configuration
  /// Reads from Firestore with 5-minute cache
  Future<SystemConfig> getConfig() async {
    // Use cache if valid
    if (_cachedConfig != null && _lastFetch != null) {
      final elapsed = DateTime.now().difference(_lastFetch!);
      if (elapsed < _cacheExpiration) {
        return _cachedConfig!;
      }
    }

    try {
      final doc = await _firestore.collection('config').doc(_configDocId).get();

      if (doc.exists && doc.data() != null) {
        _cachedConfig = SystemConfig.fromJson(doc.data()!);
        _lastFetch = DateTime.now();
        debugPrint('Configuration loaded from Firestore');
        return _cachedConfig!;
      }
    } catch (e) {
      debugPrint('Error loading configuration: $e');
    }

    // Return default configuration on failure
    debugPrint('Using default configuration');
    return SystemConfig.defaultConfig();
  }

  /// Get fare configuration
  Future<FareConfig> getFares() async {
    final config = await getConfig();
    return config.fares;
  }

  /// Calculate fare based on distance and time
  /// Uses fares configured in the admin panel
  Future<double> calculateFare({
    required double distanceKm,
    required int durationMinutes,
    String serviceType = 'standard',
    bool isNightTime = false,
    bool isHoliday = false,
  }) async {
    final fares = await getFares();

    // Base fare by service type
    double baseFare = fares.baseFare;
    double perKm = fares.perKm;
    double perMinute = fares.perMinute;

    // Multipliers by service type
    double serviceMultiplier = 1.0;
    switch (serviceType.toLowerCase()) {
      case 'premium':
        serviceMultiplier = 1.5;
        break;
      case 'xl':
        serviceMultiplier = 1.3;
        break;
      case 'moto':
        serviceMultiplier = 0.7;
        break;
      case 'delivery':
        serviceMultiplier = 0.8;
        break;
      default:
        serviceMultiplier = 1.0;
    }

    // Base calculation
    double fare = baseFare + (distanceKm * perKm) + (durationMinutes * perMinute);

    // Apply service multiplier
    fare *= serviceMultiplier;

    // Apply night surcharge (if applicable)
    if (isNightTime && fares.nightSurcharge > 0) {
      fare *= (1 + fares.nightSurcharge / 100);
    }

    // Apply holiday surcharge (if applicable)
    if (isHoliday && fares.holidaySurcharge > 0) {
      fare *= (1 + fares.holidaySurcharge / 100);
    }

    // Apply minimum fare
    if (fare < fares.minimumFare) {
      fare = fares.minimumFare;
    }

    return double.parse(fare.toStringAsFixed(2));
  }

  /// Calculate simple fare by distance only (for quick estimates)
  Future<double> calculateSimpleFare(double distanceKm) async {
    final fares = await getFares();
    double fare = fares.baseFare + (distanceKm * fares.perKm);
    return fare < fares.minimumFare ? fares.minimumFare : double.parse(fare.toStringAsFixed(2));
  }

  /// Get platform commission configuration
  Future<double> getPlatformCommission() async {
    final config = await getConfig();
    return config.commission.platformPercentage;
  }

  /// Clear cache to force reload
  void clearCache() {
    _cachedConfig = null;
    _lastFetch = null;
    debugPrint('Configuration cache cleared');
  }

  /// Watch config changes in real time (for immediate updates)
  Stream<SystemConfig> watchConfig() {
    return _firestore
        .collection('config')
        .doc(_configDocId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        _cachedConfig = SystemConfig.fromJson(doc.data()!);
        _lastFetch = DateTime.now();
        return _cachedConfig!;
      }
      return SystemConfig.defaultConfig();
    });
  }
}

/// System configuration model
class SystemConfig {
  final CompanyConfig company;
  final FareConfig fares;
  final CommissionConfig commission;
  final ServiceConfig service;

  SystemConfig({
    required this.company,
    required this.fares,
    required this.commission,
    required this.service,
  });

  factory SystemConfig.fromJson(Map<String, dynamic> json) {
    return SystemConfig(
      company: CompanyConfig.fromJson(json['company'] ?? {}),
      fares: FareConfig.fromJson(json['fares'] ?? {}),
      commission: CommissionConfig.fromJson(json['commission'] ?? {}),
      service: ServiceConfig.fromJson(json['service'] ?? {}),
    );
  }

  factory SystemConfig.defaultConfig() {
    return SystemConfig(
      company: CompanyConfig.defaultConfig(),
      fares: FareConfig.defaultConfig(),
      commission: CommissionConfig.defaultConfig(),
      service: ServiceConfig.defaultConfig(),
    );
  }
}

/// Company configuration
class CompanyConfig {
  final String name;
  final String phone;
  final String email;
  final String address;
  final String logo;

  CompanyConfig({
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.logo,
  });

  factory CompanyConfig.fromJson(Map<String, dynamic> json) {
    return CompanyConfig(
      name: json['name'] ?? 'Rappi Team',
      phone: json['phone'] ?? '',
      email: json['email'] ?? 'facturacion.rapiteam@gmail.com',
      address: json['address'] ?? 'Perú',
      logo: json['logo'] ?? '',
    );
  }

  factory CompanyConfig.defaultConfig() {
    return CompanyConfig(
      name: 'Rappi Team',
      phone: '+51 999 999 999',
      email: 'facturacion.rapiteam@gmail.com',
      address: 'Perú',
      logo: '',
    );
  }
}

/// Fare configuration
class FareConfig {
  final double baseFare;
  final double perKm;
  final double perMinute;
  final double minimumFare;
  final double maximumFare; // Maximum fare to limit excessive prices
  final double nightSurcharge; // Percentage
  final double holidaySurcharge; // Percentage

  FareConfig({
    required this.baseFare,
    required this.perKm,
    required this.perMinute,
    required this.minimumFare,
    required this.maximumFare,
    required this.nightSurcharge,
    required this.holidaySurcharge,
  });

  factory FareConfig.fromJson(Map<String, dynamic> json) {
    return FareConfig(
      baseFare: (json['baseFare'] ?? 5.0).toDouble(),
      perKm: (json['perKm'] ?? 2.0).toDouble(),
      perMinute: (json['perMinute'] ?? 0.3).toDouble(),
      minimumFare: (json['minimumFare'] ?? 6.0).toDouble(),
      maximumFare: (json['maximumFare'] ?? 200.0).toDouble(),
      nightSurcharge: (json['nightSurcharge'] ?? 20.0).toDouble(),
      holidaySurcharge: (json['holidaySurcharge'] ?? 30.0).toDouble(),
    );
  }

  factory FareConfig.defaultConfig() {
    return FareConfig(
      baseFare: 5.0,
      perKm: 2.0,
      perMinute: 0.3,
      minimumFare: 6.0,
      maximumFare: 200.0,
      nightSurcharge: 20.0,
      holidaySurcharge: 30.0,
    );
  }
}

/// Commission configuration
class CommissionConfig {
  final double platformPercentage;

  CommissionConfig({required this.platformPercentage});

  factory CommissionConfig.fromJson(Map<String, dynamic> json) {
    return CommissionConfig(
      platformPercentage: (json['platformPercentage'] ?? 20.0).toDouble(),
    );
  }

  factory CommissionConfig.defaultConfig() {
    return CommissionConfig(platformPercentage: 20.0);
  }
}

/// Service configuration
class ServiceConfig {
  final double maxDistanceKm;
  final int maxWaitTimeMinutes;
  final double cancelPenaltyAmount;

  ServiceConfig({
    required this.maxDistanceKm,
    required this.maxWaitTimeMinutes,
    required this.cancelPenaltyAmount,
  });

  factory ServiceConfig.fromJson(Map<String, dynamic> json) {
    return ServiceConfig(
      maxDistanceKm: (json['maxDistanceKm'] ?? 50.0).toDouble(),
      maxWaitTimeMinutes: (json['maxWaitTimeMinutes'] ?? 10).toInt(),
      cancelPenaltyAmount: (json['cancelPenaltyAmount'] ?? 5.0).toDouble(),
    );
  }

  factory ServiceConfig.defaultConfig() {
    return ServiceConfig(
      maxDistanceKm: 50.0,
      maxWaitTimeMinutes: 10,
      cancelPenaltyAmount: 5.0,
    );
  }
}
