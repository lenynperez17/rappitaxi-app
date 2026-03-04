import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import '../services/payment_service.dart';

/// Widget para procesar pagos con MercadoPago Checkout Bricks dentro de la app
///
/// Este widget carga un formulario de pago seguro de MercadoPago directamente
/// en la aplicación usando WebView, sin necesidad de abrir navegador externo.
///
/// Características:
/// - Formulario de tarjeta dentro de la app
/// - Tokenización segura PCI DSS compliant
/// - Experiencia UX fluida
/// - Callback cuando el pago se completa
class MercadoPagoCheckoutWidget extends StatefulWidget {
  final String publicKey;
  final String rideId; // ID de la transacción (ride o recarga)
  final double amount;
  final String description;
  final String payerEmail;
  final String payerName;
  final Function(String paymentId, String status) onPaymentComplete;
  final VoidCallback? onCancel;

  const MercadoPagoCheckoutWidget({
    super.key,
    required this.publicKey,
    required this.rideId,
    required this.amount,
    required this.description,
    required this.payerEmail,
    required this.payerName,
    required this.onPaymentComplete,
    this.onCancel,
  });

  @override
  State<MercadoPagoCheckoutWidget> createState() => _MercadoPagoCheckoutWidgetState();
}

class _MercadoPagoCheckoutWidgetState extends State<MercadoPagoCheckoutWidget> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            debugPrint('🌐 MercadoPago Bricks: Cargando página...');
          },
          onPageFinished: (String url) {
            // Inyectar configuración del pago después de cargar el HTML
            _injectPaymentConfig();
            setState(() {
              _isLoading = false;
            });
            debugPrint('✅ MercadoPago Bricks: Página cargada e inicializada');
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('❌ Error cargando MercadoPago: ${error.description}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'PaymentResult',
        onMessageReceived: (JavaScriptMessage message) {
          _handlePaymentResult(message.message);
        },
      )
      ..loadFlutterAsset('assets/mercadopago_checkout.html');
  }

  /// Inyecta la configuración del pago en el HTML ya cargado
  void _injectPaymentConfig() {
    // Escapar comillas en strings para JavaScript
    final escapedDescription = widget.description.replaceAll("'", "\\'");
    final escapedEmail = widget.payerEmail.replaceAll("'", "\\'");
    final escapedName = widget.payerName.replaceAll("'", "\\'");
    final escapedPublicKey = widget.publicKey.replaceAll("'", "\\'");

    final config = '''
    {
      publicKey: '$escapedPublicKey',
      amount: ${widget.amount},
      description: '$escapedDescription',
      payerEmail: '$escapedEmail',
      payerName: '$escapedName'
    }
    ''';

    // Llamar a la función JavaScript del HTML para inicializar el pago
    _controller.runJavaScript('initializePayment($config)');
    debugPrint('💳 Configuración del pago inyectada: amount=${widget.amount}, email=${widget.payerEmail}');
  }

  /// Maneja el resultado del pago
  void _handlePaymentResult(String message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'];

      if (type == 'token') {
        // Token recibido, procesamos el pago
        _processPaymentWithToken(data['data']);
      } else if (type == 'cancel') {
        // Usuario canceló
        if (widget.onCancel != null) {
          widget.onCancel!();
        } else {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('❌ Error parseando resultado: $e');
    }
  }

  /// Procesa el pago con el token recibido del Checkout Bricks
  Future<void> _processPaymentWithToken(Map<String, dynamic> tokenData) async {
    try {
      debugPrint('💳 Procesando pago con token: ${tokenData['token']}');

      // Extract payer data from Checkout Bricks form (includes identification/DNI)
      final payerData = tokenData['payer'] as Map<String, dynamic>?;
      final payerEmail = payerData?['email'] as String? ?? widget.payerEmail;
      final identification = payerData?['identification'] as Map<String, dynamic>?;

      // Llamar al backend para procesar el pago con el token
      final paymentService = PaymentService();
      final result = await paymentService.processMercadoPagoCheckoutBricks(
        rideId: widget.rideId,
        token: tokenData['token'],
        paymentMethodId: tokenData['payment_method_id'],
        issuerId: tokenData['issuer_id'],
        installments: tokenData['installments'],
        transactionAmount: widget.amount,
        payerEmail: payerEmail,
        description: widget.description,
        payerFirstName: widget.payerName.split(' ').first,
        payerLastName: widget.payerName.split(' ').length > 1
            ? widget.payerName.split(' ').sublist(1).join(' ')
            : '',
        identificationType: identification?['type'] as String?,
        identificationNumber: identification?['number'] as String?,
      );

      if (!mounted) return;

      if (result.success && result.paymentId != null) {
        // Pago exitoso
        debugPrint('✅ Pago procesado exitosamente: ${result.paymentId}');
        widget.onPaymentComplete(result.paymentId!, result.status ?? 'approved');
      } else {
        // Error en el pago
        throw Exception(result.error ?? 'Error desconocido al procesar el pago');
      }

    } catch (e) {
      debugPrint('❌ Error procesando pago: $e');

      if (!mounted) return;

      // Mostrar error en la UI del WebView
      _controller.runJavaScript('showError("Error al procesar el pago: $e")');

      // Esperar un momento antes de volver
      await Future.delayed(const Duration(seconds: 3));

      if (!mounted) return;

      // Informar al padre sobre el error
      widget.onPaymentComplete('', 'error');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Establecer el color de fondo del WebView según el tema
    _controller.setBackgroundColor(Theme.of(context).colorScheme.surface);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          'Pago Seguro',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimaryContainer),
                    strokeWidth: 3.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
