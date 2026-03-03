import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../config/izypay_config.dart';
import '../core/design/design_system.dart';

/// Widget que muestra el formulario de pago embebido de Izipay (Web-Core SDK)
///
/// Soporta múltiples métodos de pago: tarjetas, Yape, QR, Plin
///
/// Flujo:
/// 1. Carga la Cloud Function izipayPaymentPage en un WebView (URL HTTPS real)
/// 2. La Cloud Function genera el session token y sirve el HTML con el SDK Web-Core
/// 3. El usuario elige método de pago (tarjeta, Yape, QR, Plin)
/// 4. Recibe resultado del pago via JavaScriptChannel
/// 5. Ejecuta callback con el resultado
class IzypayCheckoutWidget extends StatefulWidget {
  final double amount;
  final String description;
  final String payerEmail;
  final String payerFirstName;
  final String payerLastName;
  final String payerPhone;
  final Function(String orderId, double amount, String status) onPaymentComplete;
  final VoidCallback? onCancel;

  const IzypayCheckoutWidget({
    super.key,
    required this.amount,
    required this.description,
    required this.payerEmail,
    required this.onPaymentComplete,
    this.payerFirstName = 'Cliente',
    this.payerLastName = 'RapiTeam',
    this.payerPhone = '999999999',
    this.onCancel,
  });

  @override
  State<IzypayCheckoutWidget> createState() => _IzypayCheckoutWidgetState();
}

class _IzypayCheckoutWidgetState extends State<IzypayCheckoutWidget> {
  late WebViewController _webViewController;
  bool _isLoading = true;
  String? _error;
  String? _orderId;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  /// Construye la URL de la Cloud Function que sirve la página de pago
  Uri _buildPaymentUrl() {
    return Uri.parse(
      '${IzypayConfig.functionsBaseUrl}/izipayPaymentPage',
    ).replace(queryParameters: {
      'amount': widget.amount.toStringAsFixed(2),
      'email': widget.payerEmail,
      'firstName': widget.payerFirstName,
      'lastName': widget.payerLastName,
      'phone': widget.payerPhone,
    });
  }

  /// Inicializa el WebView cargando la URL HTTPS de la Cloud Function
  void _initWebView() {
    final paymentUrl = _buildPaymentUrl();

    debugPrint('Izipay: Cargando formulario desde ${paymentUrl.toString()}');

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'PaymentChannel',
        onMessageReceived: _handlePaymentMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
          onWebResourceError: (error) {
            debugPrint('Izipay WebView error: ${error.description}');
            if (error.isForMainFrame == true && mounted) {
              setState(() {
                _isLoading = false;
                _error = 'Error cargando formulario de pago. Verifica tu conexión.';
              });
            }
          },
        ),
      )
      ..loadRequest(paymentUrl);
  }

  /// Procesa los mensajes del JavaScript del formulario Web-Core
  void _handlePaymentMessage(JavaScriptMessage message) {
    debugPrint('Izipay: Mensaje del WebView: ${message.message}');

    try {
      final data = jsonDecode(message.message) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'PAYMENT_SUCCESS') {
        // Web-Core responde con code='00' y response.payMethod
        final code = data['code'] as String? ?? '';
        final orderId = data['orderId'] as String? ?? _orderId ?? '';
        final payMethod = data['payMethod'] as String? ?? 'CARD';

        debugPrint('Izipay: Pago exitoso - code=$code, orderId=$orderId, payMethod=$payMethod');

        if (code == '00') {
          widget.onPaymentComplete(orderId, widget.amount, 'approved');
        } else {
          setState(() {
            _error = data['messageUser'] as String? ??
                data['message'] as String? ??
                'El pago no fue aprobado';
          });
        }
      } else if (type == 'PAYMENT_ERROR') {
        final errorMessage = data['messageUser'] as String? ??
            data['message'] as String? ??
            data['errorMessage'] as String? ??
            'Error desconocido';
        final errorCode = data['code'] as String? ?? data['errorCode'] as String? ?? '';
        debugPrint('Izipay: Error - $errorCode: $errorMessage');
        setState(() => _error = errorMessage);
      } else if (type == 'FORM_READY') {
        _orderId = data['orderId'] as String?;
        debugPrint('Izipay: Formulario Web-Core listo, orderId=$_orderId');
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Izipay: Error parseando mensaje - $e');
    }
  }

  /// Recarga el formulario de pago
  void _retry() {
    setState(() {
      _isLoading = true;
      _error = null;
      _orderId = null;
    });
    _webViewController.loadRequest(_buildPaymentUrl());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (widget.onCancel != null) {
              widget.onCancel!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Error
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: RtColors.error),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: RtColors.brand,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  if (widget.onCancel != null) {
                    widget.onCancel!();
                  } else {
                    Navigator.pop(context);
                  }
                },
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      );
    }

    // WebView con formulario embebido + overlay de carga
    return Stack(
      children: [
        WebViewWidget(controller: _webViewController),
        if (_isLoading)
          Container(
            color: Colors.white,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: RtColors.brandSurface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.credit_card, size: 48, color: RtColors.brand),
                  ),
                  const SizedBox(height: 24),
                  Text('Cargando métodos de pago', style: RtTypo.headingMedium),
                  const SizedBox(height: 8),
                  Text(
                    'S/. ${widget.amount.toStringAsFixed(2)}',
                    style: RtTypo.displaySmall.copyWith(
                      color: RtColors.brand,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(RtColors.brand),
                      strokeWidth: 3.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tarjetas, Yape, QR, Plin...',
                    style: RtTypo.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
