import 'package:flutter/foundation.dart';
import '../models/corporate_vale_model.dart';
import '../services/vale_service.dart';
import '../core/utils/logger.dart';
import '../utils/error_messages.dart';

/// Provider para gestión de vales corporativos
class ValeProvider extends ChangeNotifier {
  final ValeService _valeService = ValeService();

  // Estado
  CorporateValeModel? _currentVale;
  bool _isValidating = false;
  String? _validationError;
  double? _applicableAmount;

  // Getters
  CorporateValeModel? get currentVale => _currentVale;
  bool get isValidating => _isValidating;
  String? get validationError => _validationError;
  double? get applicableAmount => _applicableAmount;
  bool get hasVale => _currentVale != null;

  /// Validar y cargar vale por código
  Future<bool> validateAndLoadVale(String valeCode) async {
    try {
      _isValidating = true;
      _validationError = null;
      notifyListeners();

      // Limpiar código
      final cleanCode = _valeService.cleanValeCode(valeCode);

      // Validar formato
      if (!_valeService.isValidValeCodeFormat(cleanCode)) {
        _validationError = 'Formato de código inválido';
        _isValidating = false;
        notifyListeners();
        return false;
      }

      // Validar con backend
      final result = await _valeService.validateVale(cleanCode);

      if (result['success'] == true) {
        _currentVale = CorporateValeModel.fromJson(
          result['vale'] as Map<String, dynamic>,
        );
        _validationError = null;
        Logger.info('Vale cargado exitosamente: ${_currentVale!.valeCode}');
      } else {
        _currentVale = null;
        _validationError = result['error'] as String?;
        Logger.warning(userFriendlyError(_validationError, fallback: 'Error validando vale'));
      }

      _isValidating = false;
      notifyListeners();

      return result['success'] == true;
    } catch (e) {
      Logger.error(userFriendlyError(e, fallback: 'Error en validateAndLoadVale'));
      _validationError = 'Error al validar el código de vale';
      _currentVale = null;
      _isValidating = false;
      notifyListeners();
      return false;
    }
  }

  /// Calcular monto aplicable para un monto de viaje
  void calculateApplicableAmount(double rideFare) {
    if (_currentVale == null) {
      _applicableAmount = null;
      return;
    }

    _applicableAmount = _valeService.calculateApplicableAmount(
      vale: _currentVale!,
      rideFare: rideFare,
    );

    notifyListeners();
  }

  /// Aplicar vale a un viaje
  Future<Map<String, dynamic>> applyValeToRide({
    required String rideId,
    required double rideTotalFare,
    required String passengerId,
    required String passengerName,
    required String driverId,
    required String driverName,
  }) async {
    if (_currentVale == null) {
      return {
        'success': false,
        'error': 'No hay vale seleccionado',
      };
    }

    try {
      final result = await _valeService.applyValeToRide(
        valeCode: _currentVale!.valeCode,
        rideId: rideId,
        rideTotalFare: rideTotalFare,
        passengerId: passengerId,
        passengerName: passengerName,
        driverId: driverId,
        driverName: driverName,
      );

      if (result['success'] == true) {
        // Limpiar vale después de aplicarlo exitosamente
        clearVale();
      }

      return result;
    } catch (e) {
      Logger.error(userFriendlyError(e, fallback: 'Error aplicando vale'));
      return {
        'success': false,
        'error': 'Error al aplicar el vale',
      };
    }
  }

  /// Limpiar vale actual
  void clearVale() {
    _currentVale = null;
    _validationError = null;
    _applicableAmount = null;
    notifyListeners();
  }

  /// Obtener descripción del tipo de vale
  String getValeTypeDescription() {
    if (_currentVale == null) return '';
    return _valeService.getValeTypeDescription(_currentVale!.valeType);
  }

  /// Obtener texto del estado del vale
  String getValeStatusText() {
    if (_currentVale == null) return '';
    return _valeService.getValeStatusText(_currentVale!.status);
  }

  /// Obtener información resumida del vale
  String getValeSummary() {
    if (_currentVale == null) return '';

    final parts = <String>[];

    // Empresa
    parts.add(_currentVale!.companyName);

    // Tipo y valor
    switch (_currentVale!.valeType) {
      case ValeType.creditBalance:
        parts.add('Saldo: S/ ${_currentVale!.currentBalance?.toStringAsFixed(2)}');
        break;
      case ValeType.percentDiscount:
        parts.add('Descuento: ${_currentVale!.discountPercentage}%');
        break;
      case ValeType.freeRides:
        final remaining = (_currentVale!.maxFreeRides ?? 0) - (_currentVale!.currentFreeRides ?? 0);
        parts.add('$remaining viajes gratis disponibles');
        break;
      case ValeType.unlimited:
        parts.add('Vale ilimitado');
        break;
    }

    return parts.join(' • ');
  }

  /// Verificar si el vale puede cubrir el monto total
  bool canCoverFullAmount(double rideFare) {
    if (_currentVale == null || _applicableAmount == null) {
      return false;
    }
    return _applicableAmount! >= rideFare;
  }

  /// Obtener monto que el pasajero debe pagar
  double getPassengerPayableAmount(double rideFare) {
    if (_currentVale == null || _applicableAmount == null) {
      return rideFare;
    }
    return rideFare - _applicableAmount!;
  }
}
