import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/logger.dart';
import 'rapi_api_client.dart';

/// Ronda 279: lo que el administrador decide desde el panel, tal como lo ve la
/// app.
///
/// Hasta esta ronda no existía. El panel guardaba 14 ajustes en la base de
/// datos y la app no leía ninguno: el modo mantenimiento, los interruptores de
/// registro, la tarifa mínima y los mínimos de la billetera se editaban, se
/// guardaban con su mensaje de éxito, y no cambiaban absolutamente nada.
///
/// Cada campo tiene por defecto el valor con el que la app se comportaba antes
/// de que este canal existiera. Así, si el servidor no responde —o responde
/// raro— la app sigue funcionando igual que ayer en vez de quedarse bloqueada.
/// Un documento del catálogo que el administrador mantiene desde el panel.
@immutable
class DocumentTypeConfig {
  final String code;
  final String label;
  final String description;
  final bool required;
  final int sortOrder;

  const DocumentTypeConfig({
    required this.code,
    required this.label,
    this.description = '',
    this.required = false,
    this.sortOrder = 100,
  });

  factory DocumentTypeConfig.fromJson(Map<String, dynamic> json) => DocumentTypeConfig(
        code: (json['code'] ?? '').toString(),
        label: (json['label'] ?? '').toString(),
        description: (json['description'] ?? '').toString(),
        required: json['required'] == true,
        sortOrder: json['sortOrder'] is num ? (json['sortOrder'] as num).toInt() : 100,
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'label': label,
        'description': description,
        'required': required,
        'sortOrder': sortOrder,
      };
}

@immutable
class AppConfig {
  final bool maintenanceMode;
  final bool driverRegistrationEnabled;
  final bool passengerRegistrationEnabled;

  final double minFare;
  final double maxDistanceKm;
  final bool negotiable;

  /// Saldo mínimo que necesita un conductor para aceptar un viaje. Se despliega
  /// en 0 —el comportamiento actual— y lo sube el dueño desde el panel.
  final double minBalanceToAccept;

  final double minRecharge;
  final double minWithdrawal;
  final double withdrawalFee;

  final String companyName;
  final String companyRuc;
  final String companyAddress;
  final String supportEmail;

  /// Los documentos que hay que pedirle al conductor, en orden. Vacío significa
  /// "el servidor no me lo dijo": quien lo consuma debe usar su lista de
  /// siempre, no dejar de pedir documentos.
  final List<DocumentTypeConfig> documents;

  const AppConfig({
    this.maintenanceMode = false,
    this.driverRegistrationEnabled = true,
    this.passengerRegistrationEnabled = true,
    this.minFare = 5,
    this.maxDistanceKm = 50,
    this.negotiable = true,
    this.minBalanceToAccept = 0,
    this.minRecharge = 5,
    this.minWithdrawal = 20,
    this.withdrawalFee = 2,
    this.companyName = 'Rapi Team',
    this.companyRuc = '',
    this.companyAddress = '',
    this.supportEmail = 'facturacion.rapiteam@gmail.com',
    this.documents = const [],
  });

  /// Los valores de fábrica: exactamente el comportamiento previo a la ronda 279.
  static const AppConfig defaults = AppConfig();

  static bool _bool(dynamic v, bool fallback) => v is bool ? v : fallback;

  static double _num(dynamic v, double fallback) {
    final n = v is num ? v.toDouble() : double.tryParse('$v');
    if (n == null || !n.isFinite || n < 0) return fallback;
    return n;
  }

  static String _str(dynamic v, String fallback) =>
      (v is String && v.trim().isNotEmpty) ? v : fallback;

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final registration = (json['registration'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rides = (json['rides'] as Map?)?.cast<String, dynamic>() ?? const {};
    final wallet = (json['wallet'] as Map?)?.cast<String, dynamic>() ?? const {};
    final company = (json['company'] as Map?)?.cast<String, dynamic>() ?? const {};
    const d = AppConfig.defaults;

    return AppConfig(
      maintenanceMode: _bool(json['maintenanceMode'], d.maintenanceMode),
      driverRegistrationEnabled:
          _bool(registration['driverEnabled'], d.driverRegistrationEnabled),
      passengerRegistrationEnabled:
          _bool(registration['passengerEnabled'], d.passengerRegistrationEnabled),
      minFare: _num(rides['minFare'], d.minFare),
      maxDistanceKm: _num(rides['maxDistanceKm'], d.maxDistanceKm),
      negotiable: _bool(rides['negotiable'], d.negotiable),
      minBalanceToAccept: _num(rides['minBalanceToAccept'], d.minBalanceToAccept),
      minRecharge: _num(wallet['minRecharge'], d.minRecharge),
      minWithdrawal: _num(wallet['minWithdrawal'], d.minWithdrawal),
      withdrawalFee: _num(wallet['withdrawalFee'], d.withdrawalFee),
      companyName: _str(company['name'], d.companyName),
      companyRuc: _str(company['ruc'], d.companyRuc),
      companyAddress: _str(company['address'], d.companyAddress),
      supportEmail: _str(company['supportEmail'], d.supportEmail),
      documents: (json['documents'] is List)
          ? (json['documents'] as List)
              .whereType<Map>()
              .map((e) => DocumentTypeConfig.fromJson(e.cast<String, dynamic>()))
              .where((e) => e.code.isNotEmpty && e.label.isNotEmpty)
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'maintenanceMode': maintenanceMode,
        'registration': {
          'driverEnabled': driverRegistrationEnabled,
          'passengerEnabled': passengerRegistrationEnabled,
        },
        'rides': {
          'minFare': minFare,
          'maxDistanceKm': maxDistanceKm,
          'negotiable': negotiable,
          'minBalanceToAccept': minBalanceToAccept,
        },
        'wallet': {
          'minRecharge': minRecharge,
          'minWithdrawal': minWithdrawal,
          'withdrawalFee': withdrawalFee,
        },
        'company': {
          'name': companyName,
          'ruc': companyRuc,
          'address': companyAddress,
          'supportEmail': supportEmail,
        },
        'documents': documents.map((d) => d.toJson()).toList(),
      };
}

/// Trae la configuración del panel y la mantiene disponible para toda la app.
///
/// Se registra como provider en `main.dart` y se carga en el splash. Guarda la
/// última respuesta buena en disco: si el usuario abre la app sin cobertura,
/// arranca con lo último que supo en vez de con los valores de fábrica.
class AppConfigService extends ChangeNotifier {
  AppConfigService._();
  static final AppConfigService instance = AppConfigService._();
  factory AppConfigService() => instance;

  static const String _kCacheKey = 'app_config_cache_v1';

  /// El splash no puede esperar indefinidamente por la configuración: si el
  /// servidor tarda, se arranca con lo cacheado y se sigue.
  static const Duration _kTimeout = Duration(seconds: 6);

  AppConfig _config = AppConfig.defaults;
  AppConfig get config => _config;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Carga la configuración: primero lo cacheado (instantáneo), luego la red.
  ///
  /// Nunca lanza. Un fallo aquí no puede impedir que la app abra.
  Future<AppConfig> load() async {
    await _loadFromCache();
    await refresh();
    return _config;
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCacheKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _config = AppConfig.fromJson(decoded);
        _loaded = true;
        notifyListeners();
      }
    } catch (e) {
      AppLogger.warning('AppConfigService: caché ilegible, se ignora ($e)');
    }
  }

  /// Vuelve a preguntar al servidor. Devuelve true si trajo datos nuevos.
  Future<bool> refresh() async {
    try {
      final res = await http
          .get(Uri.parse('${RapiApiClient.baseUrl}/api/config/app'))
          .timeout(_kTimeout);
      if (res.statusCode != 200) {
        AppLogger.warning('AppConfigService: HTTP ${res.statusCode}');
        return false;
      }
      final body = jsonDecode(res.body);
      if (body is! Map<String, dynamic> || body['config'] is! Map) return false;

      final json = (body['config'] as Map).cast<String, dynamic>();
      _config = AppConfig.fromJson(json);
      _loaded = true;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCacheKey, jsonEncode(_config.toJson()));
      return true;
    } catch (e) {
      // Sin red, servidor caído, JSON raro: seguimos con lo que ya teníamos.
      AppLogger.warning('AppConfigService: no se pudo refrescar ($e)');
      return false;
    }
  }
}
