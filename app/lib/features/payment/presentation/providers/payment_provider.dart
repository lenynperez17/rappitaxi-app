import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/user_model.dart';
import '../../data/repositories/payment_repository_impl.dart';
import '../../domain/repositories/payment_repository.dart';
import '../../domain/entities/payment_method.dart' as pm;

// Provider del repositorio de pagos
final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepositoryImpl(ref);
});

// Provider de métodos de pago
final paymentMethodsProvider = FutureProvider<List<pm.PaymentMethod>>((ref) async {
  final repository = ref.watch(paymentRepositoryProvider);
  return await repository.getPaymentMethods();
});

// Provider del método de pago seleccionado
final selectedPaymentMethodProvider = StateProvider<pm.PaymentMethod?>((ref) {
  // Por defecto, seleccionar el método default o efectivo
  ref.watch(paymentMethodsProvider).whenData((methods) {
    final defaultMethod = methods.firstWhere(
      (m) => m.isDefault,
      orElse: () => methods.firstWhere(
        (m) => m.type == 'cash',
        orElse: () => methods.first,
      ),
    );
    ref.controller.state = defaultMethod;
  });
  
  return null;
});

// Provider del historial de pagos
final paymentHistoryProvider = FutureProvider<List<PaymentTransaction>>((ref) async {
  final repository = ref.watch(paymentRepositoryProvider);
  return await repository.getPaymentHistory();
});

// Provider para procesar pagos
final processPaymentProvider = FutureProvider.family<bool, ProcessPaymentParams>(
  (ref, params) async {
    final repository = ref.read(paymentRepositoryProvider);
    
    // Crear payment intent
    final paymentIntentId = await repository.createPaymentIntent(
      amount: params.amount,
      paymentMethodId: params.paymentMethodId,
      description: params.description,
      metadata: params.metadata,
    );
    
    // Confirmar pago
    return await repository.confirmPayment(
      paymentIntentId: paymentIntentId,
      rideId: params.rideId,
    );
  },
);

// Parámetros para procesar pago
class ProcessPaymentParams {
  final double amount;
  final String paymentMethodId;
  final String description;
  final String rideId;
  final Map<String, dynamic>? metadata;
  
  ProcessPaymentParams({
    required this.amount,
    required this.paymentMethodId,
    required this.description,
    required this.rideId,
    this.metadata,
  });
}

// Provider para agregar tarjeta
final addCreditCardProvider = FutureProvider.family<pm.PaymentMethod, AddCardParams>(
  (ref, params) async {
    final repository = ref.read(paymentRepositoryProvider);
    
    final paymentMethod = await repository.addCreditCard(
      cardNumber: params.cardNumber,
      cardholderName: params.cardholderName,
      expiryMonth: params.expiryMonth,
      expiryYear: params.expiryYear,
      cvv: params.cvv,
    );
    
    // Refrescar lista de métodos
    ref.invalidate(paymentMethodsProvider);
    
    return paymentMethod;
  },
);

// Parámetros para agregar tarjeta
class AddCardParams {
  final String cardNumber;
  final String cardholderName;
  final String expiryMonth;
  final String expiryYear;
  final String cvv;
  
  AddCardParams({
    required this.cardNumber,
    required this.cardholderName,
    required this.expiryMonth,
    required this.expiryYear,
    required this.cvv,
  });
}

// Provider para eliminar método de pago
final removePaymentMethodProvider = FutureProvider.family<void, String>(
  (ref, paymentMethodId) async {
    final repository = ref.read(paymentRepositoryProvider);
    
    await repository.removePaymentMethod(paymentMethodId);
    
    // Refrescar lista de métodos
    ref.invalidate(paymentMethodsProvider);
  },
);

// Provider para establecer método default
final setDefaultPaymentMethodProvider = FutureProvider.family<pm.PaymentMethod, String>(
  (ref, paymentMethodId) async {
    final repository = ref.read(paymentRepositoryProvider);
    
    final paymentMethod = await repository.setDefaultPaymentMethod(paymentMethodId);
    
    // Refrescar lista de métodos
    ref.invalidate(paymentMethodsProvider);
    
    return paymentMethod;
  },
);