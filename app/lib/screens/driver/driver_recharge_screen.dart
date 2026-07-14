import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/l10n/driver_strings.dart';
import '../../providers/wallet_provider.dart';
import '../../services/payment_service.dart';
import '../../services/rapi_api_client.dart';
import '../../utils/error_messages.dart';

class DriverRechargeScreen extends StatefulWidget {
  const DriverRechargeScreen({super.key});

  @override
  State<DriverRechargeScreen> createState() => _DriverRechargeScreenState();
}

class _DriverRechargeScreenState extends State<DriverRechargeScreen> {
  int _selectedAmount = 15;
  final TextEditingController _amountController = TextEditingController(text: '15');
  bool _isEditing = false;
  bool _isProcessing = false;

  // TODO(node-migration): estos ratios deberían venir del endpoint
  // /api/config/rates. Por ahora son constantes coherentes con Perú (10%).
  double _avgFarePerTrip = 2.0; // Average commission per trip

  final PaymentService _paymentService = PaymentService();

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  Future<void> _loadRates() async {
    // TODO(node-migration): reemplazar con endpoint /api/config/rates cuando
    // exista. Por ahora usamos los defaults (10% de comisión, ~S/2 por viaje).
  }

  int _estimateTrips(int amount) {
    return (amount / _avgFarePerTrip).round().clamp(1, 9999);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = DriverStrings(Localizations.localeOf(context).languageCode);
    final quickAmounts = [15, 30, 45];

    return Scaffold(
      backgroundColor: AppColors.getSurface(context),
      body: SafeArea(
        child: Column(
          children: [
            // Close button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close, size: 28, color: AppColors.getTextPrimary(context)),
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Payment method display (MercadoPago only)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppColors.getBorder(context))),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF009EE3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text('MP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('MercadoPago', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
                                Text(ds.paymentMethod, style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Amount input section
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.getBackground(context),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ds.enterAmount, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (_isEditing)
                                Expanded(
                                  child: Row(
                                    children: [
                                      Text('S/ ', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: AppColors.getTextPrimary(context))),
                                      Expanded(
                                        child: TextField(
                                          controller: _amountController,
                                          keyboardType: TextInputType.number,
                                          autofocus: true,
                                          style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: AppColors.getTextPrimary(context)),
                                          decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                          onSubmitted: (value) {
                                            final parsed = int.tryParse(value) ?? 15;
                                            setState(() {
                                              _selectedAmount = parsed.clamp(1, 999);
                                              _isEditing = false;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Expanded(
                                  child: Text(
                                    'S/ $_selectedAmount',
                                    style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: AppColors.getTextPrimary(context)),
                                  ),
                                ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isEditing = !_isEditing;
                                    if (_isEditing) {
                                      _amountController.text = '$_selectedAmount';
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.getSurface(context),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.getBorder(context).withValues(alpha: 0.3)),
                                  ),
                                  child: Icon(Icons.edit, size: 20, color: AppColors.getTextSecondary(context)),
                                ),
                              ),
                            ],
                          ),
                          Divider(color: AppColors.getBorder(context)),
                          const SizedBox(height: 12),

                          // Quick amount buttons
                          Row(
                            children: quickAmounts.map((amount) {
                              final isSelected = _selectedAmount == amount;
                              final trips = _estimateTrips(amount);
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedAmount = amount;
                                        _amountController.text = '$amount';
                                        _isEditing = false;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.rappiRed.withValues(alpha: 0.1)
                                            : AppColors.getSurface(context),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected ? AppColors.rappiRed : AppColors.getBorder(context),
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            '$amount',
                                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context)),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            ds.approxTrips(trips),
                                            style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(context)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            ds.tripCountApproximate,
                            style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(context)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom button - goes to MercadoPago
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : () => _processRecharge(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.rappiRed,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.rappiRed.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isProcessing
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(ds.rechargeSafely, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processRecharge() async {
    final ds = DriverStrings(Localizations.localeOf(context).languageCode);
    if (_selectedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ds.enterValidAmount), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      await _paymentService.initialize(isProduction: true);

      // Obtener datos del usuario desde el backend Node.
      final resp = await RapiApiClient.instance.me();
      final user = resp?['user'] as Map<String, dynamic>?;
      if (user == null) throw Exception('Usuario no autenticado');
      final userName = (user['fullName'] ?? user['name'] ?? 'Usuario') as String;
      final userEmail = (user['email'] ?? 'usuario@rapiteam.app') as String;

      final rechargeId = 'RECARGA_${DateTime.now().millisecondsSinceEpoch}';
      final amount = _selectedAmount.toDouble();
      final description = 'Recarga de saldo Rappi Team - $userName';

      final preferenceResult = await _paymentService.createMercadoPagoPreference(
        rideId: rechargeId,
        amount: amount,
        payerEmail: userEmail,
        payerName: userName,
        description: description,
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (!preferenceResult.success || preferenceResult.initPoint == null) {
        throw Exception(preferenceResult.error ?? 'No se pudo crear la preferencia de pago');
      }

      // Open MercadoPago Checkout Pro (full checkout with all payment methods)
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => _MercadoPagoCheckoutProScreen(
            initPoint: preferenceResult.initPoint!,
            amount: amount,
          ),
        ),
      );

      if (!mounted) return;

      if (result == 'approved') {
        // Credit the service credits in Firestore
        final walletProvider = Provider.of<WalletProvider>(context, listen: false);
        await walletProvider.rechargeServiceCredits(
          amount: amount,
          paymentMethod: 'mercadopago',
          paymentId: rechargeId,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ds.rechargeSuccess(amount.toInt())),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 5),
          ),
        );
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pop(context);
      } else if (result == 'pending') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ds.paymentPendingMsg), backgroundColor: Colors.orange),
        );
      } else if (result == 'failure') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ds.paymentNotApproved), backgroundColor: Colors.red),
        );
      }
      // result == null means user pressed back / cancelled — no snackbar needed
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFriendlyError(e, fallback: 'Error')), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

/// Full-screen WebView that loads MercadoPago Checkout Pro (initPoint URL).
/// Shows all payment methods: cards, Yape, bank transfers, PagoEfectivo, etc.
class _MercadoPagoCheckoutProScreen extends StatefulWidget {
  final String initPoint;
  final double amount;

  const _MercadoPagoCheckoutProScreen({
    required this.initPoint,
    required this.amount,
  });

  @override
  State<_MercadoPagoCheckoutProScreen> createState() => _MercadoPagoCheckoutProScreenState();
}

class _MercadoPagoCheckoutProScreenState extends State<_MercadoPagoCheckoutProScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) {
            final url = request.url.toLowerCase();
            // MercadoPago redirects to back_urls after payment
            if (url.contains('payment_approved') || url.contains('status=approved')) {
              Navigator.pop(context, 'approved');
              return NavigationDecision.prevent;
            }
            if (url.contains('payment_pending') || url.contains('status=pending')) {
              Navigator.pop(context, 'pending');
              return NavigationDecision.prevent;
            }
            if (url.contains('payment_failure') || url.contains('status=rejected') || url.contains('status=cancelled')) {
              Navigator.pop(context, 'failure');
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initPoint));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(DriverStrings(Localizations.localeOf(context).languageCode).payAmount(widget.amount.toInt()), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.rappiRed,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: AppColors.rappiRed)),
        ],
      ),
    );
  }
}
