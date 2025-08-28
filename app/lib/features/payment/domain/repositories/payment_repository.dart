import '../../../../shared/models/user_model.dart';
import '../entities/payment_method.dart' as pm;

abstract class PaymentRepository {
  // Métodos de pago
  Future<List<pm.PaymentMethod>> getPaymentMethods();
  Future<pm.PaymentMethod> addCreditCard({
    required String cardNumber,
    required String cardholderName,
    required String expiryMonth,
    required String expiryYear,
    required String cvv,
  });
  Future<pm.PaymentMethod> addMercadoPagoAccount({
    required String email,
  });
  Future<void> removePaymentMethod(String paymentMethodId);
  Future<pm.PaymentMethod> setDefaultPaymentMethod(String paymentMethodId);
  
  // Procesamiento de pagos
  Future<String> createPaymentIntent({
    required double amount,
    required String paymentMethodId,
    required String description,
    Map<String, dynamic>? metadata,
  });
  Future<bool> confirmPayment({
    required String paymentIntentId,
    required String rideId,
  });
  Future<void> cancelPayment(String paymentIntentId);
  
  // Historial de pagos
  Future<List<PaymentTransaction>> getPaymentHistory();
  Future<PaymentTransaction> getPaymentDetails(String transactionId);
  
  // Validaciones
  Future<bool> validateCard({
    required String cardNumber,
    required String expiryMonth,
    required String expiryYear,
    required String cvv,
  });
  Future<bool> validateMercadoPagoAccount(String email);
}

class PaymentTransaction {
  final String id;
  final double amount;
  final String status; // pending, completed, failed, cancelled
  final String paymentMethodId;
  final String paymentMethodType;
  final String description;
  final DateTime createdAt;
  final DateTime? completedAt;
  final Map<String, dynamic>? metadata;
  
  PaymentTransaction({
    required this.id,
    required this.amount,
    required this.status,
    required this.paymentMethodId,
    required this.paymentMethodType,
    required this.description,
    required this.createdAt,
    this.completedAt,
    this.metadata,
  });
  
  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    return PaymentTransaction(
      id: json['id'],
      amount: json['amount'].toDouble(),
      status: json['status'],
      paymentMethodId: json['payment_method_id'],
      paymentMethodType: json['payment_method_type'],
      description: json['description'],
      createdAt: DateTime.parse(json['created_at']),
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at']) 
          : null,
      metadata: json['metadata'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'status': status,
      'payment_method_id': paymentMethodId,
      'payment_method_type': paymentMethodType,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }
}