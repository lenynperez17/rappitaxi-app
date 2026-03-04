/// Constantes centralizadas para el sistema de créditos de conductores
/// Estas constantes se usan en toda la app para mantener consistencia
class CreditConstants {
  // ✅ Mínimo de créditos para operar como conductor
  // Unificado con el mínimo de MercadoPago para evitar inconsistencias
  static const double minServiceCredits = 10.0;

  // ✅ Costo por servicio aceptado (se descuenta al aceptar un viaje)
  static const double defaultServiceFee = 1.0;

  // ✅ Bonificación por primera recarga
  static const double defaultFirstRechargeBonus = 5.0;

  // ✅ Mínimo para recarga via MercadoPago (restricción del procesador de pagos)
  static const double minimumRechargeAmount = 10.0;

  // ✅ Paquetes de recarga por defecto
  static const List<Map<String, dynamic>> defaultCreditPackages = [
    {'amount': 10.0, 'bonus': 0.0, 'label': 'Básico'},
    {'amount': 20.0, 'bonus': 2.0, 'label': 'Popular'},
    {'amount': 50.0, 'bonus': 10.0, 'label': 'Pro'},
    {'amount': 100.0, 'bonus': 25.0, 'label': 'Premium'},
  ];

  // ✅ Mensaje de créditos insuficientes
  static String get insufficientCreditsMessage =>
      'Créditos insuficientes. Necesitas mínimo S/. ${minServiceCredits.toStringAsFixed(2)} para operar.';

  // ✅ Mensaje para el banner
  static String get insufficientCreditsBanner =>
      'Créditos de servicio insuficientes (mín: S/. ${minServiceCredits.toStringAsFixed(0)})';
}
