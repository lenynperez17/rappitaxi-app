import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/crash_reporting_service.dart';
import 'package:rappitaxi_app/shared/utils/logger.dart';
import '../../../../shared/models/user_model.dart';
import '../../domain/repositories/payment_repository.dart';
import '../../domain/entities/payment_method.dart' as pm;
import '../services/mercadopago_service.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  final Ref _ref;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  
  PaymentRepositoryImpl(this._ref)
      : _auth = FirebaseAuth.instance,
        _firestore = FirebaseFirestore.instance;
  
  MercadoPagoService get _mercadoPago => _ref.read(mercadoPagoServiceProvider);
  AnalyticsService get _analytics => _ref.read(analyticsServiceProvider);
  CrashReportingService get _crashReporting => _ref.read(crashReportingServiceProvider);
  
  @override
  Future<List<pm.PaymentMethod>> getPaymentMethods() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('Usuario no autenticado');
      
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      
      if (userData != null && userData['passengerData'] != null) {
        final passengerData = PassengerData.fromJson(userData['passengerData']);
        
        // Siempre incluir efectivo como opción
        final methods = [
          const pm.PaymentMethod(
        name: "Efectivo",
        id: 'cash',
            type: 'cash',
            isDefault: false,
          ),
          ...passengerData.paymentMethods.map((m) => pm.PaymentMethod(
            name: m.type,
            id: m.id,
            type: m.type,
            isDefault: m.isDefault,
            cardLast4: m.cardLast4,
            cardBrand: m.cardBrand,
          )),
        ];
        
        return methods;
      }
      
      // Si no hay métodos, devolver solo efectivo
      return [
        const pm.PaymentMethod(
        name: "Efectivo",
        id: 'cash',
          type: 'cash',
          isDefault: true,
        ),
      ];
    } catch (e, stack) {
      Logger.error('Error getting payment methods', e, stack);
      _crashReporting.recordError(e, stack);
      rethrow;
    }
  }
  
  @override
  Future<pm.PaymentMethod> addCreditCard({
    required String cardNumber,
    required String cardholderName,
    required String expiryMonth,
    required String expiryYear,
    required String cvv,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('Usuario no autenticado');
      
      // Validar tarjeta primero
      final isValid = await validateCard(
        cardNumber: cardNumber,
        expiryMonth: expiryMonth,
        expiryYear: expiryYear,
        cvv: cvv,
      );
      
      if (!isValid) {
        throw Exception('Tarjeta inválida');
      }
      
      // Crear token de tarjeta con MercadoPago
      final cardToken = await _mercadoPago.createCardToken(
        cardNumber: cardNumber,
        cardholderName: cardholderName,
        expirationMonth: expiryMonth,
        expirationYear: expiryYear,
        securityCode: cvv,
        identificationType: 'DNI', // TODO: Obtener del usuario
        identificationNumber: '12345678', // TODO: Obtener del usuario
      );
      
      // Obtener o crear customer en MercadoPago
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data()!;
      
      String customerId = userData['mercadoPagoCustomerId'];
      if (customerId == null || customerId.isEmpty) {
        customerId = await _mercadoPago.createCustomer(
          email: userData['email'],
          firstName: userData['name']?.split(' ').first,
          lastName: userData['name']?.split(' ').skip(1).join(' '),
          phone: userData['phone'],
        );
        
        // Guardar customer ID
        await _firestore.collection('users').doc(userId).update({
          'mercadoPagoCustomerId': customerId,
        });
      }
      
      // Asociar tarjeta al customer
      final cardData = await _mercadoPago.addCardToCustomer(
        customerId: customerId,
        cardToken: cardToken,
      );
      
      // Crear método de pago en Firestore
      final paymentMethod = pm.PaymentMethod(
        id: cardData['id'],
        name: cardData['payment_method']['name'] ?? 'Tarjeta',
        type: 'card',
        isDefault: false,
        cardLast4: cardData['last_four_digits'],
        cardBrand: cardData['payment_method']['name'],
        metadata: {
          'issuer': cardData['issuer'],
          'payment_method_id': cardData['payment_method']['id'],
          'external_id': cardData['id'],
        },
      );
      
      // Actualizar usuario con nuevo método de pago
      await _firestore.collection('users').doc(userId).update({
        'passengerData.paymentMethods': FieldValue.arrayUnion([
          paymentMethod.toJson(),
        ]),
      });
      
      // Analytics
      await _analytics.logPaymentMethodAdded('card');
      
      Logger.info('Credit card added');
      return paymentMethod;
    } catch (e, stack) {
      Logger.error('Error adding credit card', e, stack);
      await _crashReporting.recordPaymentError(
        method: 'card',
        error: 'ADD_CARD_ERROR',
        amount: 0.0,
      );
      rethrow;
    }
  }
  
  @override
  Future<pm.PaymentMethod> addMercadoPagoAccount({
    required String email,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('Usuario no autenticado');
      
      // Validar cuenta de MercadoPago
      final isValid = await validateMercadoPagoAccount(email);
      if (!isValid) {
        throw Exception('Cuenta de MercadoPago inválida');
      }
      
      // Crear método de pago
      final paymentMethod = pm.PaymentMethod(
        id: 'mp_${DateTime.now().millisecondsSinceEpoch}',
        name: 'MercadoPago',
        type: 'mercadopago',
        isDefault: false,
        metadata: {
          'email': email,
        },
      );
      
      // Actualizar usuario
      await _firestore.collection('users').doc(userId).update({
        'passengerData.paymentMethods': FieldValue.arrayUnion([
          paymentMethod.toJson(),
        ]),
      });
      
      // Analytics
      await _analytics.logPaymentMethodAdded('mercadopago');
      
      Logger.info('MercadoPago account added');
      return paymentMethod;
    } catch (e, stack) {
      Logger.error('Error adding MercadoPago account', e, stack);
      await _crashReporting.recordPaymentError(
        method: 'mercadopago',
        error: 'ADD_MP_ERROR',
        amount: 0.0,
      );
      rethrow;
    }
  }
  
  @override
  Future<void> removePaymentMethod(String paymentMethodId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('Usuario no autenticado');
      
      // No se puede eliminar efectivo
      if (paymentMethodId == 'cash') {
        throw Exception('No se puede eliminar el método de pago en efectivo');
      }
      
      // Obtener métodos actuales
      final methods = await getPaymentMethods();
      final methodToRemove = methods.firstWhere(
        (m) => m.id == paymentMethodId,
        orElse: () => throw Exception('Método de pago no encontrado'),
      );
      
      // Si es tarjeta, eliminar de MercadoPago
      if (methodToRemove.type == 'card' && methodToRemove.metadata?['external_id'] != null) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final customerId = userDoc.data()?['mercadoPagoCustomerId'];
        
        if (customerId != null) {
          await _mercadoPago.removeCustomerCard(
            customerId: customerId,
            cardId: methodToRemove.metadata!['external_id'] as String,
          );
        }
      }
      
      // Eliminar de Firestore
      await _firestore.collection('users').doc(userId).update({
        'passengerData.paymentMethods': FieldValue.arrayRemove([
          methodToRemove.toJson(),
        ]),
      });
      
      Logger.info('Payment method removed');
    } catch (e, stack) {
      Logger.error('Error removing payment method', e, stack);
      _crashReporting.recordError(e, stack);
      rethrow;
    }
  }
  
  @override
  Future<pm.PaymentMethod> setDefaultPaymentMethod(String paymentMethodId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('Usuario no autenticado');
      
      // Obtener métodos actuales
      final methods = await getPaymentMethods();
      
      // Actualizar el default
      final updatedMethods = methods.map((method) {
        if (method.id == paymentMethodId) {
          return pm.PaymentMethod(
            id: method.id,
            name: method.name,
            type: method.type,
            isDefault: true,
            cardLast4: method.cardLast4,
            cardBrand: method.cardBrand,
            metadata: method.metadata,
          );
        } else {
          return pm.PaymentMethod(
            id: method.id,
            name: method.name,
            type: method.type,
            isDefault: false,
            cardLast4: method.cardLast4,
            cardBrand: method.cardBrand,
            metadata: method.metadata,
          );
        }
      }).toList();
      
      // Actualizar en Firestore (excepto efectivo)
      final methodsToSave = updatedMethods
          .where((m) => m.type != 'cash')
          .map((m) => m.toJson())
          .toList();
      
      await _firestore.collection('users').doc(userId).update({
        'passengerData.paymentMethods': methodsToSave,
      });
      
      Logger.info('Default payment method updated');
      return updatedMethods.firstWhere((m) => m.id == paymentMethodId);
    } catch (e, stack) {
      Logger.error('Error setting default payment method', e, stack);
      _crashReporting.recordError(e, stack);
      rethrow;
    }
  }
  
  @override
  Future<String> createPaymentIntent({
    required double amount,
    required String paymentMethodId,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('Usuario no autenticado');
      
      // Si es efectivo, crear un payment intent local
      if (paymentMethodId == 'cash') {
        final paymentDoc = await _firestore.collection('payment_intents').add({
          'userId': userId,
          'amount': amount,
          'paymentMethodId': paymentMethodId,
          'paymentMethodType': 'cash',
          'description': description,
          'status': 'pending',
          'metadata': metadata,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        return paymentDoc.id;
      }
      
      // Para otros métodos, usar MercadoPago
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data()!;
      final customerId = userData['mercadoPagoCustomerId'];
      final email = userData['email'];
      
      // Obtener el método de pago
      final methods = await getPaymentMethods();
      final paymentMethod = methods.firstWhere(
        (m) => m.id == paymentMethodId,
        orElse: () => throw Exception('Método de pago no encontrado'),
      );
      
      // Crear pago en MercadoPago
      final payment = await _mercadoPago.createPayment(
        amount: amount,
        description: description,
        paymentMethodId: paymentMethod.metadata?['payment_method_id'] ?? 'visa',
        customerId: customerId,
        cardId: paymentMethod.metadata?['external_id'] as String?,
        email: email,
        metadata: metadata,
      );
      
      // Guardar en Firestore
      await _firestore.collection('payment_intents').doc(payment['id'].toString()).set({
        'userId': userId,
        'amount': amount,
        'paymentMethodId': paymentMethodId,
        'paymentMethodType': paymentMethod.type,
        'description': description,
        'status': payment['status'],
        'mercadoPagoId': payment['id'],
        'metadata': metadata,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      return payment['id'].toString();
    } catch (e, stack) {
      Logger.error('Error creating payment intent', e, stack);
      await _crashReporting.recordPaymentError(
        method: paymentMethodId,
        error: 'CREATE_PAYMENT_ERROR: ${e.toString()}',
        amount: amount,
      );
      rethrow;
    }
  }
  
  @override
  Future<bool> confirmPayment({
    required String paymentIntentId,
    required String rideId,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('Usuario no autenticado');
      
      // Actualizar el payment intent
      await _firestore.collection('payment_intents').doc(paymentIntentId).update({
        'status': 'completed',
        'rideId': rideId,
        'completedAt': FieldValue.serverTimestamp(),
      });
      
      // Obtener información del pago
      final paymentDoc = await _firestore
          .collection('payment_intents')
          .doc(paymentIntentId)
          .get();
      final paymentData = paymentDoc.data()!;
      
      // Analytics
      await _analytics.logPaymentCompleted(
        rideId: rideId,
        paymentMethod: paymentData['paymentMethodType'],
        amount: paymentData['amount'].toDouble(),
      );
      
      Logger.info('Payment confirmed');
      return true;
    } catch (e, stack) {
      Logger.error('Error confirming payment', e, stack);
      await _crashReporting.recordPaymentError(
        method: 'unknown',
        error: 'CONFIRM_PAYMENT_ERROR: ${e.toString()}',
        amount: 0.0,
      );
      return false;
    }
  }
  
  @override
  Future<void> cancelPayment(String paymentIntentId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('Usuario no autenticado');
      
      // Obtener información del pago
      final paymentDoc = await _firestore
          .collection('payment_intents')
          .doc(paymentIntentId)
          .get();
      
      if (!paymentDoc.exists) {
        throw Exception('Payment intent no encontrado');
      }
      
      final paymentData = paymentDoc.data()!;
      
      // Si tiene ID de MercadoPago, reembolsar
      if (paymentData['mercadoPagoId'] != null) {
        await _mercadoPago.refundPayment(
          paymentId: paymentData['mercadoPagoId'].toString(),
        );
      }
      
      // Actualizar estado
      await _firestore.collection('payment_intents').doc(paymentIntentId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      
      Logger.info('Payment cancelled');
    } catch (e, stack) {
      Logger.error('Error cancelling payment', e, stack);
      _crashReporting.recordError(e, stack);
      rethrow;
    }
  }
  
  @override
  Future<List<PaymentTransaction>> getPaymentHistory() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('Usuario no autenticado');
      
      final querySnapshot = await _firestore
          .collection('payment_intents')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return PaymentTransaction(
          id: doc.id,
          amount: data['amount'].toDouble(),
          status: data['status'],
          paymentMethodId: data['paymentMethodId'],
          paymentMethodType: data['paymentMethodType'],
          description: data['description'],
          createdAt: (data['createdAt'] as Timestamp).toDate(),
          completedAt: data['completedAt'] != null
              ? (data['completedAt'] as Timestamp).toDate()
              : null,
          metadata: data['metadata'],
        );
      }).toList();
    } catch (e, stack) {
      Logger.error('Error getting payment history', e, stack);
      _crashReporting.recordError(e, stack);
      return [];
    }
  }
  
  @override
  Future<PaymentTransaction> getPaymentDetails(String transactionId) async {
    try {
      final doc = await _firestore
          .collection('payment_intents')
          .doc(transactionId)
          .get();
      
      if (!doc.exists) {
        throw Exception('Transacción no encontrada');
      }
      
      final data = doc.data()!;
      return PaymentTransaction(
        id: doc.id,
        amount: data['amount'].toDouble(),
        status: data['status'],
        paymentMethodId: data['paymentMethodId'],
        paymentMethodType: data['paymentMethodType'],
        description: data['description'],
        createdAt: (data['createdAt'] as Timestamp).toDate(),
        completedAt: data['completedAt'] != null
            ? (data['completedAt'] as Timestamp).toDate()
            : null,
        metadata: data['metadata'],
      );
    } catch (e, stack) {
      Logger.error('Error getting payment details', e, stack);
      _crashReporting.recordError(e, stack);
      rethrow;
    }
  }
  
  @override
  Future<bool> validateCard({
    required String cardNumber,
    required String expiryMonth,
    required String expiryYear,
    required String cvv,
  }) async {
    try {
      // Limpiar número de tarjeta
      final cleanNumber = cardNumber.replaceAll(' ', '');
      
      // Validar longitud
      if (cleanNumber.length < 13 || cleanNumber.length > 19) {
        return false;
      }
      
      // Validar que sea solo números
      if (!RegExp(r'^\d+$').hasMatch(cleanNumber)) {
        return false;
      }
      
      // Validar algoritmo de Luhn
      int sum = 0;
      bool alternate = false;
      
      for (int i = cleanNumber.length - 1; i >= 0; i--) {
        int digit = int.parse(cleanNumber[i]);
        
        if (alternate) {
          digit *= 2;
          if (digit > 9) {
            digit = (digit % 10) + 1;
          }
        }
        
        sum += digit;
        alternate = !alternate;
      }
      
      if (sum % 10 != 0) {
        return false;
      }
      
      // Validar fecha de expiración
      final now = DateTime.now();
      final expiry = DateTime(
        int.parse('20$expiryYear'),
        int.parse(expiryMonth),
      );
      
      if (expiry.isBefore(now)) {
        return false;
      }
      
      // Validar CVV
      if (cvv.length < 3 || cvv.length > 4) {
        return false;
      }
      
      if (!RegExp(r'^\d+$').hasMatch(cvv)) {
        return false;
      }
      
      return true;
    } catch (e) {
      Logger.error('Error validating card', e);
      return false;
    }
  }
  
  @override
  Future<bool> validateMercadoPagoAccount(String email) async {
    try {
      // Validar formato de email
      final emailRegex = RegExp(
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
      );
      
      if (!emailRegex.hasMatch(email)) {
        return false;
      }
      
      // TODO: Implementar validación real con API de MercadoPago
      // Por ahora solo validamos el formato
      
      return true;
    } catch (e) {
      Logger.error('Error validating MercadoPago account', e);
      return false;
    }
  }
}