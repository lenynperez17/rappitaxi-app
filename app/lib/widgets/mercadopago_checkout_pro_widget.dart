import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/theme/modern_theme.dart';

/// MercadoPago Checkout Pro - loads the hosted checkout page in a WebView.
///
/// Unlike Checkout Bricks (local HTML), this opens MercadoPago's own page
/// which has proper device fingerprinting and anti-fraud capabilities.
/// Intercepts back_url redirects (rapiteam://) to detect payment result.
class MercadoPagoCheckoutProWidget extends StatefulWidget {
  final String initPoint;
  final String transactionId;
  final double amount;
  final Function(String status, String transactionId) onPaymentComplete;
  final VoidCallback? onCancel;

  const MercadoPagoCheckoutProWidget({
    super.key,
    required this.initPoint,
    required this.transactionId,
    required this.amount,
    required this.onPaymentComplete,
    this.onCancel,
  });

  @override
  State<MercadoPagoCheckoutProWidget> createState() =>
      _MercadoPagoCheckoutProWidgetState();
}

class _MercadoPagoCheckoutProWidgetState
    extends State<MercadoPagoCheckoutProWidget> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _paymentHandled = false;

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
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;

            // Intercept deep link redirects from MercadoPago
            if (url.startsWith('rapiteam://')) {
              _handleDeepLink(url);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('❌ MercadoPago Checkout error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initPoint));
  }

  void _handleDeepLink(String url) {
    if (_paymentHandled) return;
    _paymentHandled = true;

    final uri = Uri.parse(url);
    final path = uri.host; // e.g. "payment"
    final segments = uri.pathSegments; // e.g. ["success"]

    String status = 'unknown';
    if (url.contains('success')) {
      status = 'approved';
    } else if (url.contains('failure')) {
      status = 'rejected';
    } else if (url.contains('pending')) {
      status = 'pending';
    }

    debugPrint(
        '💳 MercadoPago Checkout Pro result: $status (path: $path, segments: $segments)');

    widget.onPaymentComplete(status, widget.transactionId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pago Seguro',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: ModernTheme.rappiOrange,
        elevation: 0,
        iconTheme:
            IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
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
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(ModernTheme.rappiOrange),
              ),
            ),
        ],
      ),
    );
  }
}
