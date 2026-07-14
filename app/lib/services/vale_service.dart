import '../models/corporate_vale_model.dart';
import '../core/utils/logger.dart';
import 'rapi_api_client.dart';

/// Servicio para gestión de vales corporativos (backend Node del VPS).
class ValeService {
  final RapiApiClient _api = RapiApiClient.instance;

  /// Validar código de vale
  Future<Map<String, dynamic>> validateVale(String valeCode) async {
    try {
      Logger.info('Validando código de vale: $valeCode');
      final data = await _api.validateVale(code: valeCode);
      if (data['valid'] == true || data['success'] == true) {
        return {'success': true, 'vale': data['vale']};
      }
      return {
        'success': false,
        'error': data['error'] ?? 'Código de vale inválido',
      };
    } on RapiApiException catch (e) {
      Logger.warning('Vale inválido: ${e.code}');
      return {'success': false, 'error': e.message ?? 'Código de vale inválido'};
    } catch (e) {
      Logger.error('Error validando vale: $e');
      return {'success': false, 'error': 'Error al validar el código de vale'};
    }
  }

  /// Aplicar vale a un viaje
  Future<Map<String, dynamic>> applyValeToRide({
    required String valeCode,
    required String rideId,
    required double rideTotalFare,
    required String passengerId,
    required String passengerName,
    required String driverId,
    required String driverName,
  }) async {
    try {
      Logger.info('Aplicando vale $valeCode al viaje $rideId');
      final data = await _api.applyVale(
        code: valeCode,
        rideId: rideId,
        rideAmount: rideTotalFare,
      );
      if (data['success'] == true) {
        return {
          'success': true,
          'valeAppliedAmount': data['discountApplied'] ?? data['valeAppliedAmount'],
          'passengerPaidAmount': data['finalAmount'] ?? data['passengerPaidAmount'],
        };
      }
      return {
        'success': false,
        'error': data['error'] ?? 'Error al aplicar el vale',
      };
    } on RapiApiException catch (e) {
      Logger.error('Error aplicando vale: ${e.code}');
      return {'success': false, 'error': e.message ?? 'Error al aplicar el vale'};
    } catch (e) {
      Logger.error('Error aplicando vale: $e');
      return {'success': false, 'error': 'Error al aplicar el vale al viaje'};
    }
  }

  /// Calcular monto a aplicar de un vale (para preview)
  double calculateApplicableAmount({
    required CorporateValeModel vale,
    required double rideFare,
  }) {
    if (!vale.canBeUsed) return 0.0;

    switch (vale.valeType) {
      case ValeType.creditBalance:
        final balance = vale.currentBalance ?? 0;
        return rideFare <= balance ? rideFare : balance;

      case ValeType.percentDiscount:
        final discount = (vale.discountPercentage ?? 0) / 100;
        return rideFare * discount;

      case ValeType.freeRides:
        final maxValue = vale.maxRideValue ?? double.infinity;
        return rideFare <= maxValue ? rideFare : 0;

      case ValeType.unlimited:
        return rideFare;
    }
  }

  /// Obtener texto descriptivo del tipo de vale
  String getValeTypeDescription(ValeType valeType) {
    switch (valeType) {
      case ValeType.creditBalance:
        return 'Saldo Prepagado Reutilizable';
      case ValeType.percentDiscount:
        return 'Descuento Porcentual por Viaje';
      case ValeType.freeRides:
        return 'Viajes Gratis hasta Límite';
      case ValeType.unlimited:
        return 'Ilimitado con Liquidación Mensual';
    }
  }

  /// Obtener texto de estado del vale
  String getValeStatusText(ValeStatus status) {
    switch (status) {
      case ValeStatus.active:
        return 'Activo';
      case ValeStatus.depleted:
        return 'Agotado';
      case ValeStatus.expired:
        return 'Expirado';
      case ValeStatus.cancelled:
        return 'Cancelado';
      case ValeStatus.suspended:
        return 'Suspendido';
    }
  }

  /// Validar formato de código de vale
  bool isValidValeCodeFormat(String code) {
    // Formato esperado: VALE-2024-001-0001-ABC123XYZ
    final regex = RegExp(r'^VALE-\d{4}-\d{3}-\d{4}-[A-Z0-9]{7,9}$');
    return regex.hasMatch(code);
  }

  /// Limpiar código de vale (remover espacios, guiones extras, etc.)
  String cleanValeCode(String code) {
    return code.toUpperCase().trim().replaceAll(RegExp(r'\s+'), '');
  }
}
