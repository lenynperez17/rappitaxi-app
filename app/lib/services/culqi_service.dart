import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../config/culqi_config.dart';
import '../models/culqi_models.dart';
import '../utils/firestore_error_handler.dart';

/// Servicio principal de Culqi para Flutter
/// Maneja todas las operaciones de pago con la pasarela Culqi
class CulqiService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton
  static final CulqiService _instance = CulqiService._internal();
  factory CulqiService() => _instance;
  CulqiService._internal();

  /// Obtiene el token de autenticación del usuario actual
  Future<String?> _getAuthToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  /// Headers comunes para las peticiones HTTP
  Future<Map<String, String>> _getHeaders() async {
    final token = await _getAuthToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Obtiene la configuración de Culqi desde el servidor
  Future<CulqiConfigResponse> getConfig() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(CulqiConfig.configEndpoint),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return CulqiConfigResponse(
          success: data['success'] ?? false,
          publicKey: data['publicKey'] ?? '',
          environment: data['environment'] ?? 'test',
        );
      } else {
        final error = jsonDecode(response.body);
        return CulqiConfigResponse(
          success: false,
          error: error['error'] ?? 'Error obteniendo configuración',
        );
      }
    } catch (e) {
      return CulqiConfigResponse(
        success: false,
        error: FirestoreErrorHandler.getSpanishMessage(e),
      );
    }
  }

  /// Crea un cargo usando un token de Culqi
  Future<CulqiChargeResponse> createCharge({
    required String sourceId,
    required int amount,
    required String email,
    String? description,
    Map<String, dynamic>? metadata,
    CulqiAntifraudDetails? antifraudDetails,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({
        'sourceId': sourceId,
        'amount': amount,
        'currencyCode': CulqiConfig.defaultCurrency,
        'email': email,
        'description': description ?? 'Pago RapiTeam',
        'metadata': metadata ?? {},
        if (antifraudDetails != null) 'antifraudDetails': antifraudDetails.toJson(),
      });

      final response = await http.post(
        Uri.parse(CulqiConfig.createChargeEndpoint),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return CulqiChargeResponse(
          success: data['success'] ?? false,
          chargeId: data['chargeId'],
          status: data['status'],
          amount: data['amount'],
        );
      } else {
        final error = jsonDecode(response.body);
        return CulqiChargeResponse(
          success: false,
          error: error['error'] ?? 'Error creando cargo',
          errorCode: error['errorCode'],
        );
      }
    } catch (e) {
      return CulqiChargeResponse(
        success: false,
        error: FirestoreErrorHandler.getSpanishMessage(e),
      );
    }
  }

  /// Procesa una recarga de wallet
  Future<CulqiRechargeResponse> processRecharge({
    required String userId,
    required String sourceId,
    required int amount,
    required String email,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({
        'userId': userId,
        'sourceId': sourceId,
        'amount': amount,
        'email': email,
        'metadata': metadata ?? {},
      });

      final response = await http.post(
        Uri.parse(CulqiConfig.rechargeEndpoint),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return CulqiRechargeResponse(
          success: data['success'] ?? false,
          chargeId: data['chargeId'],
          transactionId: data['transactionId'],
          newBalance: (data['newBalance'] as num?)?.toDouble(),
        );
      } else {
        final error = jsonDecode(response.body);
        return CulqiRechargeResponse(
          success: false,
          error: error['error'] ?? 'Error procesando recarga',
        );
      }
    } catch (e) {
      return CulqiRechargeResponse(
        success: false,
        error: FirestoreErrorHandler.getSpanishMessage(e),
      );
    }
  }

  /// Crea un reembolso
  Future<CulqiRefundResponse> createRefund({
    required String chargeId,
    required int amount,
    required String reason,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({
        'chargeId': chargeId,
        'amount': amount,
        'reason': reason,
      });

      final response = await http.post(
        Uri.parse(CulqiConfig.refundEndpoint),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return CulqiRefundResponse(
          success: data['success'] ?? false,
          refundId: data['refundId'],
          status: data['status'],
          amount: data['amount'],
        );
      } else {
        final error = jsonDecode(response.body);
        return CulqiRefundResponse(
          success: false,
          error: error['error'] ?? 'Error creando reembolso',
        );
      }
    } catch (e) {
      return CulqiRefundResponse(
        success: false,
        error: FirestoreErrorHandler.getSpanishMessage(e),
      );
    }
  }

  /// Crea un cliente en Culqi
  Future<CulqiCustomerResponse> createCustomer({
    required String firstName,
    required String lastName,
    required String email,
    String? phone,
    String? address,
    String? addressCity,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone ?? '',
        'address': address ?? '',
        'addressCity': addressCity ?? 'Lima',
        'countryCode': 'PE',
      });

      final response = await http.post(
        Uri.parse(CulqiConfig.createCustomerEndpoint),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return CulqiCustomerResponse(
          success: data['success'] ?? false,
          customerId: data['customerId'],
        );
      } else {
        final error = jsonDecode(response.body);
        return CulqiCustomerResponse(
          success: false,
          error: error['error'] ?? 'Error creando cliente',
        );
      }
    } catch (e) {
      return CulqiCustomerResponse(
        success: false,
        error: FirestoreErrorHandler.getSpanishMessage(e),
      );
    }
  }

  /// Guarda una tarjeta para un cliente
  Future<CulqiCardResponse> saveCard({
    required String customerId,
    required String tokenId,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({
        'customerId': customerId,
        'tokenId': tokenId,
      });

      final response = await http.post(
        Uri.parse(CulqiConfig.saveCardEndpoint),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return CulqiCardResponse(
          success: data['success'] ?? false,
          cardId: data['cardId'],
          cardBrand: data['cardBrand'],
          cardLast4: data['cardLast4'],
        );
      } else {
        final error = jsonDecode(response.body);
        return CulqiCardResponse(
          success: false,
          error: error['error'] ?? 'Error guardando tarjeta',
        );
      }
    } catch (e) {
      return CulqiCardResponse(
        success: false,
        error: FirestoreErrorHandler.getSpanishMessage(e),
      );
    }
  }

  /// Obtiene las tarjetas guardadas de un cliente
  Future<CulqiCardsListResponse> getCustomerCards(String customerId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${CulqiConfig.getCardsEndpoint}?customerId=$customerId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> cardsData = data['cards'] ?? [];
        final cards = cardsData.map((c) => CulqiSavedCard.fromJson(c)).toList();
        return CulqiCardsListResponse(
          success: true,
          cards: cards,
        );
      } else {
        final error = jsonDecode(response.body);
        return CulqiCardsListResponse(
          success: false,
          error: error['error'] ?? 'Error obteniendo tarjetas',
        );
      }
    } catch (e) {
      return CulqiCardsListResponse(
        success: false,
        error: FirestoreErrorHandler.getSpanishMessage(e),
      );
    }
  }

  /// Obtiene o crea el ID de cliente Culqi para el usuario actual
  Future<String?> getOrCreateCustomerId() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      // Buscar si ya existe el customerId en Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();

      if (userData != null && userData['culqiCustomerId'] != null) {
        return userData['culqiCustomerId'] as String;
      }

      // Si no existe, crear cliente en Culqi
      final displayName = user.displayName ?? '';
      final nameParts = displayName.split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts.first : 'Usuario';
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : 'RapiTeam';

      final result = await createCustomer(
        firstName: firstName,
        lastName: lastName,
        email: user.email ?? '${user.uid}@rapiteam.app',
        phone: user.phoneNumber,
      );

      if (result.success && result.customerId != null) {
        // Guardar el customerId en Firestore
        await _firestore.collection('users').doc(user.uid).update({
          'culqiCustomerId': result.customerId,
        });
        return result.customerId;
      }

      return null;
    } catch (e) {
      print('Error obteniendo/creando customerId: $e');
      return null;
    }
  }

  /// Registra una transacción de pago en Firestore
  Future<void> logPaymentTransaction({
    required String chargeId,
    required int amount,
    required String status,
    required String type,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('payment_logs').add({
        'userId': user.uid,
        'chargeId': chargeId,
        'amount': amount,
        'amountInSoles': CulqiConfig.centsToSoles(amount),
        'status': status,
        'type': type,
        'description': description,
        'metadata': metadata,
        'provider': 'culqi',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error registrando transacción: $e');
    }
  }

  /// Obtiene el historial de pagos del usuario
  Future<List<Map<String, dynamic>>> getPaymentHistory({int limit = 20}) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _firestore
          .collection('payment_logs')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error obteniendo historial de pagos: $e');
      return [];
    }
  }
}
