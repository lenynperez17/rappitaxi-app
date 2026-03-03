import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

/// Utilidades para formatear moneda según el país configurado
///
/// USO:
/// ```dart
/// // Formatear con moneda actual (Perú = 'S/')
/// 150.50.toCurrency() // → 'S/ 150.50'
///
/// // Formatear sin espacios
/// 150.50.toCurrency(includeSpace: false) // → 'S/150.50'
///
/// // Solo el valor formateado
/// 150.50.toCurrencyValue() // → '150.50'
/// ```
class CurrencyFormatter {
  /// Formatea un monto con el símbolo de moneda actual
  ///
  /// Usa la configuración de [AppConstants.CURRENT_COUNTRY]
  ///
  /// **Ejemplos:**
  /// ```dart
  /// formatCurrency(150.50) // → 'S/ 150.50' (Perú)
  /// formatCurrency(150.50) // → '\$ 150.50' (USA)
  /// formatCurrency(150.50, includeSpace: false) // → 'S/150.50'
  /// formatCurrency(150.5000) // → 'S/ 150.50' (redondea a 2 decimales)
  /// ```
  static String formatCurrency(
    double amount, {
    bool includeSpace = true,
    int? decimals,
  }) {
    final symbol = AppConstants.currencySymbol;
    final decimalDigits = decimals ?? AppConstants.decimalDigits;
    final formattedValue = _formatNumber(amount, decimalDigits);

    return includeSpace
        ? '$symbol $formattedValue'
        : '$symbol$formattedValue';
  }

  /// Formatea solo el valor numérico sin símbolo de moneda
  ///
  /// **Ejemplos:**
  /// ```dart
  /// formatCurrencyValue(1500.5) // → '1,500.50'
  /// formatCurrencyValue(1500.5, decimals: 0) // → '1,501' (redondea)
  /// ```
  static String formatCurrencyValue(
    double amount, {
    int? decimals,
  }) {
    final decimalDigits = decimals ?? AppConstants.decimalDigits;
    return _formatNumber(amount, decimalDigits);
  }

  /// Formatea el número con separadores de miles y decimales
  /// según el locale actual
  ///
  /// Privado - usado internamente por las funciones públicas
  static String _formatNumber(double amount, int decimalDigits) {
    final locale = AppConstants.currentLocale;
    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: '', // Sin símbolo, lo agregamos manualmente
      decimalDigits: decimalDigits,
    );

    return formatter.format(amount).trim();
  }

  /// Formatea un monto con signo (+ o -)
  ///
  /// Útil para mostrar transacciones, ganancias, pérdidas, etc.
  ///
  /// **Ejemplos:**
  /// ```dart
  /// formatCurrencyWithSign(150.50) // → '+S/ 150.50'
  /// formatCurrencyWithSign(-50.00) // → '-S/ 50.00'
  /// formatCurrencyWithSign(150.50, showPlusSign: false) // → 'S/ 150.50'
  /// ```
  static String formatCurrencyWithSign(
    double amount, {
    bool showPlusSign = true,
  }) {
    final isPositive = amount >= 0;
    final absAmount = amount.abs();
    final formatted = formatCurrency(absAmount);

    if (isPositive && showPlusSign) {
      return '+$formatted';
    } else if (!isPositive) {
      return '-$formatted';
    }

    return formatted;
  }

  /// Formatea un monto en formato compacto (K, M, B)
  ///
  /// Útil para dashboards y estadísticas
  ///
  /// **Ejemplos:**
  /// ```dart
  /// formatCurrencyCompact(1500) // → 'S/ 1.5K'
  /// formatCurrencyCompact(1500000) // → 'S/ 1.5M'
  /// formatCurrencyCompact(1500000000) // → 'S/ 1.5B'
  /// ```
  static String formatCurrencyCompact(double amount) {
    final symbol = AppConstants.currencySymbol;
    final absAmount = amount.abs();
    String suffix = '';
    double value = absAmount;

    if (absAmount >= 1000000000) {
      value = absAmount / 1000000000;
      suffix = 'B';
    } else if (absAmount >= 1000000) {
      value = absAmount / 1000000;
      suffix = 'M';
    } else if (absAmount >= 1000) {
      value = absAmount / 1000;
      suffix = 'K';
    }

    final formattedValue = value.toStringAsFixed(1);
    final sign = amount < 0 ? '-' : '';

    return suffix.isEmpty
        ? formatCurrency(amount)
        : '$sign$symbol $formattedValue$suffix';
  }
}

/// Extension methods para formatear doubles como moneda directamente
///
/// **Uso:**
/// ```dart
/// 150.50.toCurrency() // → 'S/ 150.50'
/// 150.50.toCurrencyValue() // → '150.50'
/// 150.50.toCurrencyCompact() // → 'S/ 150.50'
/// 1500000.0.toCurrencyCompact() // → 'S/ 1.5M'
/// ```
extension CurrencyFormatterExtension on double {
  /// Convierte el double a formato de moneda
  String toCurrency({bool includeSpace = true, int? decimals}) {
    return CurrencyFormatter.formatCurrency(
      this,
      includeSpace: includeSpace,
      decimals: decimals,
    );
  }

  /// Convierte el double a formato numérico sin símbolo
  String toCurrencyValue({int? decimals}) {
    return CurrencyFormatter.formatCurrencyValue(this, decimals: decimals);
  }

  /// Convierte el double a formato compacto con K, M, B
  String toCurrencyCompact() {
    return CurrencyFormatter.formatCurrencyCompact(this);
  }

  /// Convierte el double a formato con signo
  String toCurrencyWithSign({bool showPlusSign = true}) {
    return CurrencyFormatter.formatCurrencyWithSign(
      this,
      showPlusSign: showPlusSign,
    );
  }
}

/// ✅ Extension para num (cubre int y double literales)
/// Previene NoSuchMethodError cuando se usan literales numéricos o ints
extension CurrencyFormatterNumExtension on num {
  /// Convierte el num a formato de moneda (convierte a double internamente)
  String toCurrency({bool includeSpace = true, int? decimals}) {
    return CurrencyFormatter.formatCurrency(
      toDouble(),
      includeSpace: includeSpace,
      decimals: decimals,
    );
  }

  /// Convierte el num a formato numérico sin símbolo
  String toCurrencyValue({int? decimals}) {
    return CurrencyFormatter.formatCurrencyValue(toDouble(), decimals: decimals);
  }

  /// Convierte el num a formato compacto con K, M, B
  String toCurrencyCompact() {
    return CurrencyFormatter.formatCurrencyCompact(toDouble());
  }

  /// Convierte el num a formato con signo
  String toCurrencyWithSign({bool showPlusSign = true}) {
    return CurrencyFormatter.formatCurrencyWithSign(
      toDouble(),
      showPlusSign: showPlusSign,
    );
  }
}
