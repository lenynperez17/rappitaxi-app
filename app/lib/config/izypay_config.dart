/// Configuración de Izypay para el SDK nativo
///
/// Las claves públicas son seguras de incluir en el cliente.
/// Las claves privadas SOLO están en Cloud Functions (.env).
class IzypayConfig {
  /// URL base de las Cloud Functions (para uso futuro)
  static const String functionsBaseUrl =
      'https://us-central1-rapi-team.cloudfunctions.net';

  /// Determinar si estamos en modo test o producción
  /// Cambiar a true cuando se pase a producción
  static const bool isProduction = false;

  /// Public key de test (formato: shopId:testpublickey_xxxx)
  static const String testPublicKey =
      '69012033:testpublickey_kGeR77fGIiyzLV5a3qYEH2axY3G3eKws3y70X0rca1R99';

  /// Public key de producción (formato: shopId:publickey_xxxx)
  static const String prodPublicKey =
      '69012033:publickey_5fgIsmHwRIKshbUd6ppKrhfzOwKsxwuL2MzTbFZRUhRzY';

  /// Public key según el entorno
  static String get publicKey => isProduction ? prodPublicKey : testPublicKey;

  /// ShopId (código de comercio) - extraído de la public key
  static String get shopId => publicKey.split(':').first;

  /// Tarjeta de prueba para SBOX:
  /// Número: 4970 1000 0000 0014
  /// Vencimiento: cualquier fecha futura
  /// CVV: 123
}
