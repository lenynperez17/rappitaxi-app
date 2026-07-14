import 'package:flutter/foundation.dart';

/// Servicio centralizado de configuración.
///
/// Antes leía la config desde Firestore (`config/system_config`); tras la
/// migración al backend Node, la config se sirve mediante valores por defecto
/// hardcodeados en el cliente. Si en el futuro el backend expone
/// `/api/config`, este servicio puede llamarlo desde `getConfig()`.
///
/// La API pública (SystemConfig, FareConfig, CommissionConfig,
/// ServiceConfig, CompanyConfig, `calculateFare`, `calculateSimpleFare`,
/// `getPlatformCommission`, `clearCache`, `watchConfig`) se mantiene igual
/// para no romper pantallas existentes.
class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  // Cache de configuración
  SystemConfig? _cachedConfig;
  DateTime? _lastFetch;
  static const Duration _cacheExpiration = Duration(minutes: 5);

  /// Obtiene la configuración del sistema (con cache de 5 min).
  ///
  /// Actualmente retorna la config por defecto. Si el backend Node expone un
  /// endpoint `/api/config`, se puede añadir la llamada aquí.
  Future<SystemConfig> getConfig() async {
    if (_cachedConfig != null && _lastFetch != null) {
      final elapsed = DateTime.now().difference(_lastFetch!);
      if (elapsed < _cacheExpiration) {
        return _cachedConfig!;
      }
    }

    // TODO: cuando el backend Node exponga /api/config, invocar aquí.
    _cachedConfig = SystemConfig.defaultConfig();
    _lastFetch = DateTime.now();
    debugPrint('Configuration loaded (defaults)');
    return _cachedConfig!;
  }

  /// Obtiene la configuración de tarifas.
  Future<FareConfig> getFares() async {
    final config = await getConfig();
    return config.fares;
  }

  /// Calcula la tarifa dinámica según distancia, tiempo y modificadores.
  Future<double> calculateFare({
    required double distanceKm,
    required int durationMinutes,
    String serviceType = 'standard',
    bool isNightTime = false,
    bool isHoliday = false,
  }) async {
    final fares = await getFares();

    double baseFare = fares.baseFare;
    double perKm = fares.perKm;
    double perMinute = fares.perMinute;

    // Multiplicadores por tipo de servicio
    double serviceMultiplier;
    switch (serviceType.toLowerCase()) {
      case 'express':
        serviceMultiplier = 1.0;
        break;
      case 'ejecutivo':
        serviceMultiplier = 1.15;
        break;
      case 'vip':
        serviceMultiplier = 1.3;
        break;
      case 'mototaxi':
      case 'moto':
        serviceMultiplier = 0.7;
        break;
      case 'entregas':
      case 'delivery':
        serviceMultiplier = 0.8;
        break;
      case 'ciudadaciudad':
        serviceMultiplier = 1.8;
        break;
      default:
        serviceMultiplier = 1.0;
    }

    double fare = baseFare + (distanceKm * perKm) + (durationMinutes * perMinute);
    fare *= serviceMultiplier;

    if (isNightTime && fares.nightSurcharge > 0) {
      fare *= (1 + fares.nightSurcharge / 100);
    }
    if (isHoliday && fares.holidaySurcharge > 0) {
      fare *= (1 + fares.holidaySurcharge / 100);
    }

    if (fare < fares.minimumFare) {
      fare = fares.minimumFare;
    }

    return double.parse(fare.toStringAsFixed(2));
  }

  /// Cálculo simple por distancia (para estimados rápidos).
  Future<double> calculateSimpleFare(double distanceKm) async {
    final fares = await getFares();
    double fare = fares.baseFare + (distanceKm * fares.perKm);
    return fare < fares.minimumFare
        ? fares.minimumFare
        : double.parse(fare.toStringAsFixed(2));
  }

  /// Comisión de la plataforma (porcentaje).
  Future<double> getPlatformCommission() async {
    final config = await getConfig();
    return config.commission.platformPercentage;
  }

  /// Fuerza recargar la config en la próxima llamada.
  void clearCache() {
    _cachedConfig = null;
    _lastFetch = null;
    debugPrint('Configuration cache cleared');
  }

  /// Stream de config. Como ya no hay observadores en tiempo real, emite una
  /// única vez la config actual.
  Stream<SystemConfig> watchConfig() async* {
    yield await getConfig();
  }
}

/// Modelo de configuración del sistema.
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

class FareConfig {
  final double baseFare;
  final double perKm;
  final double perMinute;
  final double minimumFare;
  final double maximumFare;
  final double nightSurcharge; // %
  final double holidaySurcharge; // %

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
      baseFare: (json['baseFare'] ?? 3.5).toDouble(),
      perKm: (json['perKm'] ?? 1.8).toDouble(),
      perMinute: (json['perMinute'] ?? 0.3).toDouble(),
      minimumFare: (json['minimumFare'] ?? 5.0).toDouble(),
      maximumFare: (json['maximumFare'] ?? 200.0).toDouble(),
      nightSurcharge: (json['nightSurcharge'] ?? 20.0).toDouble(),
      holidaySurcharge: (json['holidaySurcharge'] ?? 30.0).toDouble(),
    );
  }

  factory FareConfig.defaultConfig() {
    return FareConfig(
      baseFare: 3.5,
      perKm: 1.8,
      perMinute: 0.3,
      minimumFare: 5.0,
      maximumFare: 200.0,
      nightSurcharge: 20.0,
      holidaySurcharge: 30.0,
    );
  }
}

class CommissionConfig {
  final double platformPercentage;

  CommissionConfig({required this.platformPercentage});

  factory CommissionConfig.fromJson(Map<String, dynamic> json) {
    return CommissionConfig(
      platformPercentage: (json['platformPercentage'] ?? 20.0).toDouble(),
    );
  }

  factory CommissionConfig.defaultConfig() {
    return CommissionConfig(platformPercentage: 12.0);
  }
}

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
