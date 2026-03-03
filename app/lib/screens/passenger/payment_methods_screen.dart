import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/design/rt_colors.dart';
import '../../core/design/rt_gradients.dart';
import '../../core/design/rt_tokens.dart';
import '../../core/design/rt_typography.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_badge.dart';
import '../../core/widgets/rt_card.dart';
import '../../core/widgets/rt_empty_state.dart';
import '../../core/widgets/rt_section_header.dart';
import '../../core/widgets/rt_button.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../core/widgets/rt_tab_bar.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../services/firebase_service.dart';
import '../../services/payment_service.dart';
import '../../utils/firestore_error_handler.dart';
import '../../utils/logger.dart';

enum CardType { visa, mastercard, amex, discover, other }
enum PaymentMethodType { card, cash, wallet, paypal }

class PaymentMethod {
  final String id;
  final PaymentMethodType type;
  final String name;
  final String? cardNumber;
  final String? cardHolder;
  final String? expiryDate;
  final CardType? cardType;
  final bool isDefault;
  final String? walletBalance;
  final IconData icon;
  final Color color;

  PaymentMethod({
    required this.id,
    required this.type,
    required this.name,
    this.cardNumber,
    this.cardHolder,
    this.expiryDate,
    this.cardType,
    required this.isDefault,
    this.walletBalance,
    required this.icon,
    required this.color,
  });
}

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  final PaymentService _paymentService = PaymentService();
  final FirebaseService _firebaseService = FirebaseService();

  String _defaultMethodId = 'cash';
  bool _isLoading = true;
  String? _userId;

  final List<PaymentMethod> _paymentMethods = [
    PaymentMethod(id: 'cash', type: PaymentMethodType.cash, name: 'Efectivo', isDefault: true, icon: Icons.money, color: RtColors.success),
    PaymentMethod(id: 'wallet', type: PaymentMethodType.wallet, name: 'Billetera RapiTeam', walletBalance: '0.00', isDefault: false, icon: Icons.account_balance_wallet, color: RtColors.brand),
  ];

  List<PaymentHistoryItem> _transactionHistory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeServices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // -- Carga de datos -------------------------------------------------------

  Future<void> _initializeServices() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }
      _userId = user.uid;
      await _loadPaymentMethodsFromFirebase();
      await _loadWalletBalance();
      setState(() => _isLoading = false);
    } catch (e) {
      AppLogger.error('Error cargando métodos de pago: $e');
      setState(() => _isLoading = false);
      if (mounted && !e.toString().contains('Bad state: No element')) {
        RtSnackbar.show(context, message: 'No se pudieron cargar los métodos de pago', type: RtSnackbarType.warning);
      }
    }
  }

  Future<void> _loadPaymentMethodsFromFirebase() async {
    if (_userId == null) return;
    try {
      final snap = await _firebaseService.firestore
          .collection('users').doc(_userId)
          .collection('payment_methods')
          .orderBy('createdAt', descending: true).limit(50).get();

      for (var doc in snap.docs) {
        final data = doc.data();
        final cType = _parseCardType(data['cardType']);
        final method = PaymentMethod(
          id: doc.id,
          type: PaymentMethodType.card,
          name: data['name'] ?? 'Tarjeta',
          cardNumber: data['lastFourDigits'] != null ? '---- ${data['lastFourDigits']}' : null,
          cardHolder: data['cardHolder'],
          expiryDate: data['expiryDate'],
          cardType: cType,
          isDefault: data['isDefault'] ?? false,
          icon: Icons.credit_card,
          color: _cardColor(cType),
        );
        setState(() {
          _paymentMethods.add(method);
          if (method.isDefault) _defaultMethodId = method.id;
        });
      }
    } catch (e) {
      AppLogger.error('Error cargando payment methods: $e');
    }
  }

  Future<void> _loadWalletBalance() async {
    if (_userId == null) return;
    try {
      final doc = await _firebaseService.firestore.collection('users').doc(_userId).get();
      if (doc.exists) {
        final balance = (doc.data()?['walletBalance'] ?? 0.0).toDouble();
        setState(() {
          final idx = _paymentMethods.indexWhere((m) => m.type == PaymentMethodType.wallet);
          if (idx != -1) {
            final old = _paymentMethods[idx];
            _paymentMethods[idx] = PaymentMethod(
              id: old.id, type: old.type, name: old.name,
              walletBalance: balance.toStringAsFixed(2),
              isDefault: old.isDefault, icon: old.icon, color: old.color,
            );
          }
        });
      }
    } catch (e) {
      AppLogger.error('Error cargando wallet: $e');
    }
  }

  Future<void> _loadTransactionHistory() async {
    if (_userId == null) return;
    try {
      final history = await _paymentService.getUserPaymentHistory(_userId!, 'passenger');
      setState(() => _transactionHistory = history);
    } catch (e) {
      AppLogger.error('Error cargando historial: $e');
    }
  }

  CardType _parseCardType(String? type) {
    switch (type?.toLowerCase()) {
      case 'visa': return CardType.visa;
      case 'mastercard': return CardType.mastercard;
      case 'amex': return CardType.amex;
      case 'discover': return CardType.discover;
      default: return CardType.other;
    }
  }

  Color _cardColor(CardType type) {
    switch (type) {
      case CardType.visa: return RtColors.info;
      case CardType.mastercard: return RtColors.warning;
      case CardType.amex: return RtColors.success;
      case CardType.discover: return RtColors.accentBlue;
      case CardType.other: return RtColors.neutral500;
    }
  }

  // =========================================================================
  // BUILD
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: RtAppBar(
        title: l10n.paymentMethodsTitle,
        variant: RtAppBarVariant.solid,
        actions: [
          IconButton(icon: const Icon(Icons.help_outline_rounded), onPressed: _showHelp),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: RtTabBar(tabs: [l10n.paymentMethodsTab, l10n.historyTab], controller: _tabController),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: RtColors.brand))
          : TabBarView(
              controller: _tabController,
              children: [_buildMethodsTab(), _buildHistoryTab()],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPaymentMethod,
        backgroundColor: RtColors.brand,
        icon: const Icon(Icons.add, color: RtColors.white),
        label: Text(l10n.addMethod, style: RtTypo.labelLarge.copyWith(color: RtColors.white)),
      ),
    );
  }

  // -- Tab: Métodos de pago -------------------------------------------------

  Widget _buildMethodsTab() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: RtSpacing.screenAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wallet balance
          _buildWalletCard(),
          const SizedBox(height: RtSpacing.xl),

          RtSectionHeader(title: l10n.savedMethods),
          const SizedBox(height: RtSpacing.md),

          ..._paymentMethods.map((method) {
            if (method.type == PaymentMethodType.card) return _buildCreditCard(method);
            return _buildPaymentMethodTile(method);
          }),

          const SizedBox(height: RtSpacing.xl),
          _buildSecurityInfo(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildWalletCard() {
    final l10n = AppLocalizations.of(context)!;
    final wallet = _paymentMethods.firstWhere(
      (m) => m.type == PaymentMethodType.wallet,
      orElse: () => _paymentMethods.first,
    );
    final balance = double.tryParse(wallet.walletBalance ?? '0.0') ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(RtSpacing.lg),
      decoration: BoxDecoration(
        gradient: RtGradients.success,
        borderRadius: RtRadius.borderLg,
        boxShadow: RtShadow.medium(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.rapiteamWallet, style: RtTypo.bodySmall.copyWith(color: RtColors.white.withValues(alpha: 0.8))),
                  const SizedBox(height: RtSpacing.sm),
                  Text(balance.toCurrency(), style: RtTypo.displayLarge.copyWith(color: RtColors.white)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: RtColors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: RtColors.white, size: 32),
              ),
            ],
          ),
          const SizedBox(height: RtSpacing.lg),
          Row(
            children: [
              Expanded(
                child: RtButton(
                  label: l10n.recharge,
                  icon: Icons.add,
                  variant: RtButtonVariant.secondary,
                  onPressed: _rechargeWallet,
                ),
              ),
              const SizedBox(width: RtSpacing.md),
              Expanded(
                child: RtButton(
                  label: l10n.historyButton,
                  icon: Icons.history,
                  variant: RtButtonVariant.outlined,
                  onPressed: () => _tabController.animateTo(1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCreditCard(PaymentMethod method) {
    final isDefault = method.id == _defaultMethodId;
    final l10n = AppLocalizations.of(context)!;
    final gradient = _cardGradient(method.cardType ?? CardType.other);

    return GestureDetector(
      onTap: () => _setDefaultMethod(method),
      child: Container(
        margin: const EdgeInsets.only(bottom: RtSpacing.base),
        height: 200,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: RtRadius.borderLg,
          boxShadow: RtShadow.medium(),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: CardPatternPainter(RtColors.white))),
            Padding(
              padding: const EdgeInsets.all(RtSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_cardLogoText(method.cardType!), style: RtTypo.headingMedium.copyWith(color: RtColors.white, fontStyle: FontStyle.italic)),
                      if (isDefault) RtBadge(label: l10n.defaultBadge, color: RtColors.white.withValues(alpha: 0.3)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(method.cardNumber ?? '', style: RtTypo.headingSmall.copyWith(color: RtColors.white, letterSpacing: 2, fontFamily: 'monospace')),
                      const SizedBox(height: RtSpacing.base),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(l10n.cardHolder, style: RtTypo.labelSmall.copyWith(color: RtColors.white.withValues(alpha: 0.7))),
                            Text(method.cardHolder ?? '', style: RtTypo.bodyMedium.copyWith(color: RtColors.white)),
                          ]),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(l10n.expiresLabel, style: RtTypo.labelSmall.copyWith(color: RtColors.white.withValues(alpha: 0.7))),
                            Text(method.expiryDate ?? '', style: RtTypo.bodyMedium.copyWith(color: RtColors.white)),
                          ]),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: Icon(Icons.close, color: RtColors.white.withValues(alpha: 0.6), size: 20),
                onPressed: () => _deletePaymentMethod(method),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodTile(PaymentMethod method) {
    final isDefault = method.id == _defaultMethodId;
    final l10n = AppLocalizations.of(context)!;

    return RtCard(
      margin: const EdgeInsets.only(bottom: RtSpacing.md),
      variant: isDefault ? RtCardVariant.outlined : RtCardVariant.elevated,
      onTap: isDefault ? null : () => _setDefaultMethod(method),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: method.color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(method.icon, color: method.color, size: 24),
          ),
          const SizedBox(width: RtSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(method.name, style: RtTypo.titleMedium),
                Text(
                  method.walletBalance != null ? l10n.balanceLabel(method.walletBalance!) : _methodDescription(method.type),
                  style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500),
                ),
              ],
            ),
          ),
          if (isDefault) RtBadge(label: l10n.defaultLabel, color: RtColors.brand, variant: RtBadgeVariant.subtle),
        ],
      ),
    );
  }

  // -- Tab: Historial -------------------------------------------------------

  Widget _buildHistoryTab() {
    if (_transactionHistory.isEmpty) {
      return RtEmptyState(
        icon: Icons.receipt_long_rounded,
        title: 'No hay transacciones aun',
        description: 'Tus pagos aparecerán aquí',
      );
    }

    return ListView.builder(
      padding: RtSpacing.screenAll,
      itemCount: _transactionHistory.length + 1,
      itemBuilder: (ctx, index) {
        if (index == 0) return _buildHistorySummary();
        final tx = _transactionHistory[index - 1];
        return _buildTransactionTile(tx);
      },
    );
  }

  Widget _buildHistorySummary() {
    final l10n = AppLocalizations.of(context)!;
    final totalSpent = _transactionHistory.fold<double>(0, (t, tx) => t + tx.amount);
    final successful = _transactionHistory.where((t) => t.status == 'approved').length;

    return Container(
      margin: const EdgeInsets.only(bottom: RtSpacing.lg),
      padding: const EdgeInsets.all(RtSpacing.lg),
      decoration: BoxDecoration(gradient: RtGradients.info, borderRadius: RtRadius.borderLg),
      child: Column(
        children: [
          Text(l10n.monthlySummary, style: RtTypo.headingSmall.copyWith(color: RtColors.white)),
          const SizedBox(height: RtSpacing.base),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryItem(l10n.totalSpent, totalSpent.toCurrency(), Icons.account_balance_wallet_rounded),
              _summaryItem(l10n.transactionsLabel, '${_transactionHistory.length}', Icons.receipt_rounded),
              _summaryItem(l10n.successfulLabel, '$successful/${_transactionHistory.length}', Icons.check_circle_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: RtColors.white.withValues(alpha: 0.7), size: 24),
        const SizedBox(height: RtSpacing.sm),
        Text(value, style: RtTypo.headingSmall.copyWith(color: RtColors.white)),
        Text(label, style: RtTypo.labelSmall.copyWith(color: RtColors.white.withValues(alpha: 0.7))),
      ],
    );
  }

  Widget _buildTransactionTile(PaymentHistoryItem tx) {
    final isSuccess = tx.status == 'approved';
    final l10n = AppLocalizations.of(context)!;

    return RtCard(
      margin: const EdgeInsets.only(bottom: RtSpacing.md),
      onTap: () => _showTransactionDetails(tx),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isSuccess ? RtColors.success : RtColors.error).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                color: isSuccess ? RtColors.success : RtColors.error),
          ),
          const SizedBox(width: RtSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.tripLabel(tx.rideId), style: RtTypo.titleMedium),
                Text(tx.paymentMethod, style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500)),
                Text(_formatDate(tx.createdAt), style: RtTypo.labelSmall.copyWith(color: RtColors.neutral400)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(tx.amount.toCurrency(), style: RtTypo.titleLarge),
              RtBadge(
                label: isSuccess ? l10n.successfulStatus : l10n.failedStatus,
                color: isSuccess ? RtColors.success : RtColors.error,
                variant: RtBadgeVariant.subtle,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityInfo() {
    final l10n = AppLocalizations.of(context)!;
    return RtCard(
      variant: RtCardVariant.outlined,
      child: Row(
        children: [
          const Icon(Icons.security_rounded, color: RtColors.info),
          const SizedBox(width: RtSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.paymentsProtected, style: RtTypo.titleMedium.copyWith(color: RtColors.info)),
                Text(l10n.encryptionMessage, style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -- Acciones -------------------------------------------------------------

  void _setDefaultMethod(PaymentMethod method) {
    setState(() => _defaultMethodId = method.id);
    final l10n = AppLocalizations.of(context)!;
    RtSnackbar.show(context, message: l10n.defaultMethodMessage(method.name), type: RtSnackbarType.success);
  }

  void _deletePaymentMethod(PaymentMethod method) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderXl),
        title: Text(l10n.deletePaymentMethod),
        content: Text(l10n.confirmDeleteMethod(method.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancelButton)),
          ElevatedButton(
            onPressed: () async {
              final msg = l10n.methodDeleted;
              Navigator.pop(ctx);
              if (method.type == PaymentMethodType.card && _userId != null) {
                try {
                  await _firebaseService.firestore
                      .collection('users').doc(_userId).collection('payment_methods').doc(method.id).delete();
                } catch (e) {
                  AppLogger.error('Error eliminando payment method: $e');
                }
              }
              setState(() {
                _paymentMethods.removeWhere((m) => m.id == method.id);
                if (_defaultMethodId == method.id && _paymentMethods.isNotEmpty) {
                  _defaultMethodId = _paymentMethods.first.id;
                }
              });
              if (!mounted) return;
              RtSnackbar.show(context, message: msg, type: RtSnackbarType.success);
            },
            style: ElevatedButton.styleFrom(backgroundColor: RtColors.error),
            child: Text(l10n.deleteButton),
          ),
        ],
      ),
    );
  }

  void _addPaymentMethod() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (ctx, scroll) => Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: RtRadius.sheetTop,
          ),
          child: AddPaymentMethodSheet(
            scrollController: scroll,
            onMethodAdded: (m) => setState(() => _paymentMethods.add(m)),
          ),
        ),
      ),
    );
  }

  void _rechargeWallet() {
    final amountCtrl = TextEditingController();
    double selectedAmount = 0;
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: RtRadius.sheetTop),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            top: RtSpacing.xl, left: RtSpacing.xl, right: RtSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.rechargeWallet, style: RtTypo.headingMedium),
              const SizedBox(height: RtSpacing.xl),
              Wrap(
                spacing: RtSpacing.md,
                runSpacing: RtSpacing.md,
                children: [10, 20, 50, 100, 200].map((a) => ChoiceChip(
                  label: Text(a.toCurrency(decimals: 0)),
                  selected: selectedAmount == a.toDouble(),
                  selectedColor: RtColors.brand.withValues(alpha: 0.2),
                  onSelected: (s) => setModal(() {
                    selectedAmount = s ? a.toDouble() : 0;
                    amountCtrl.clear();
                  }),
                )).toList(),
              ),
              const SizedBox(height: RtSpacing.base),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.customAmount,
                  prefixText: 'S/. ',
                  border: OutlineInputBorder(borderRadius: RtRadius.borderMd),
                ),
                onChanged: (v) => setModal(() => selectedAmount = double.tryParse(v) ?? 0),
              ),
              const SizedBox(height: RtSpacing.xl),
              RtButton(
                label: selectedAmount > 0 ? 'Recargar ${selectedAmount.toCurrency()}' : l10n.recharge,
                isFullWidth: true,
                onPressed: selectedAmount > 0
                    ? () { Navigator.pop(ctx); _processRecharge(selectedAmount); }
                    : null,
              ),
              const SizedBox(height: RtSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processRecharge(double amount) async {
    if (_userId == null) return;
    try {
      showDialog(context: context, barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator(color: RtColors.brand)));

      final userDoc = await _firebaseService.firestore.collection('users').doc(_userId).get();
      final email = userDoc.data()?['email'] ?? '';
      final name = userDoc.data()?['name'] ?? 'Usuario';
      final result = await _paymentService.createMercadoPagoPreference(
        rideId: 'wallet_recharge_${DateTime.now().millisecondsSinceEpoch}',
        amount: amount, payerEmail: email, payerName: name,
        description: 'Recarga de billetera RapiTeam',
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (result.success && result.initPoint != null) {
        await _openMercadoPagoWebView(result.initPoint!, amount);
      } else {
        RtSnackbar.show(context, message: 'Error: ${result.error}', type: RtSnackbarType.error);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
    }
  }

  Future<void> _openMercadoPagoWebView(String url, double amount) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: const RtAppBar(title: 'MercadoPago', variant: RtAppBarVariant.gradient),
          body: WebViewWidget(
            controller: WebViewController()
              ..setJavaScriptMode(JavaScriptMode.unrestricted)
              ..setNavigationDelegate(NavigationDelegate(
                onPageFinished: (u) async {
                  final nav = Navigator.of(ctx);
                  if (u.contains('success') || u.contains('approved')) {
                    await _updateWalletBalance(amount);
                    if (!mounted) return;
                    nav.pop();
                    RtSnackbar.show(context, message: 'Recarga exitosa de ${amount.toCurrency()}', type: RtSnackbarType.success);
                    await _loadWalletBalance();
                    await _loadTransactionHistory();
                  } else if (u.contains('failure') || u.contains('pending')) {
                    if (!mounted) return;
                    nav.pop();
                    RtSnackbar.show(context, message: 'El pago no pudo completarse', type: RtSnackbarType.error);
                  }
                },
              ))
              ..loadRequest(Uri.parse(url)),
          ),
        ),
      ),
    );
  }

  Future<void> _updateWalletBalance(double amount) async {
    if (_userId == null) return;
    try {
      await _firebaseService.firestore.collection('users').doc(_userId).update({
        'walletBalance': FieldValue.increment(amount),
      });
    } catch (e) {
      AppLogger.error('Error actualizando wallet: $e');
    }
  }

  void _showTransactionDetails(PaymentHistoryItem tx) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: RtRadius.sheetTop),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(RtSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: RtColors.neutral300, borderRadius: RtRadius.borderFull))),
            const SizedBox(height: RtSpacing.lg),
            Text(l10n.transactionDetails, style: RtTypo.headingMedium),
            const SizedBox(height: RtSpacing.lg),
            _detailRow(l10n.transactionId, tx.id),
            _detailRow(l10n.tripDetailLabel, tx.rideId),
            _detailRow(l10n.dateDetailLabel, _formatDate(tx.createdAt)),
            _detailRow(l10n.methodDetailLabel, tx.paymentMethod),
            _detailRow(l10n.amountDetailLabel, tx.amount.toCurrency()),
            _detailRow('Comisión plataforma', tx.platformCommission.toCurrency()),
            _detailRow(l10n.statusDetailLabel, tx.status == 'approved' ? l10n.successfulStatus : l10n.failedStatus),
            const SizedBox(height: RtSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: RtButton(
                    label: l10n.downloadButton,
                    icon: Icons.download_rounded,
                    variant: RtButtonVariant.outlined,
                    onPressed: () { Navigator.pop(ctx); _generateTransactionPDF(tx); },
                  ),
                ),
                const SizedBox(width: RtSpacing.md),
                Expanded(
                  child: RtButton(
                    label: l10n.helpButton,
                    icon: Icons.help_rounded,
                    onPressed: () { Navigator.pop(ctx); Navigator.pushNamed(context, '/shared/support'); },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateTransactionPDF(PaymentHistoryItem tx) async {
    try {
      final pdf = pw.Document();
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(child: pw.Text('RECIBO DE TRANSACCION', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 10),
            pw.Center(child: pw.Text('RapiTeam', style: pw.TextStyle(fontSize: 18))),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 20),
            _pdfRow('ID:', tx.id),
            _pdfRow('Viaje:', tx.rideId),
            _pdfRow('Fecha:', DateFormat('dd/MM/yyyy HH:mm').format(tx.createdAt)),
            _pdfRow('Método:', tx.paymentMethod),
            pw.Divider(),
            _pdfRow('Total:', tx.amount.toCurrency(), bold: true),
            _pdfRow('Comisión:', tx.platformCommission.toCurrency()),
            _pdfRow('Estado:', tx.status == 'approved' ? 'Aprobado' : 'Pendiente'),
            pw.Divider(),
            pw.SizedBox(height: 20),
            pw.Center(child: pw.Text('Generado el ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey))),
          ],
        ),
      ));
      await Printing.layoutPdf(onLayout: (f) async => pdf.save());
      if (!mounted) return;
      RtSnackbar.show(context, message: 'Recibo generado', type: RtSnackbarType.success);
    } catch (e) {
      if (!mounted) return;
      RtSnackbar.show(context, message: 'Error generando recibo', type: RtSnackbarType.error);
    }
  }

  pw.Widget _pdfRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 12)),
          pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  void _showHelp() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderXl),
        title: Row(children: [
          const Icon(Icons.help_outline_rounded, color: RtColors.brand),
          const SizedBox(width: RtSpacing.sm),
          Text(l10n.helpTitle),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [l10n.helpItem1, l10n.helpItem2, l10n.helpItem3, l10n.helpItem4]
              .map((t) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(t, style: RtTypo.bodyMedium)))
              .toList(),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.understood))],
      ),
    );
  }

  // -- Helpers --------------------------------------------------------------

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RtSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: RtTypo.bodyMedium.copyWith(color: RtColors.neutral500)),
          Text(value, style: RtTypo.titleMedium),
        ],
      ),
    );
  }

  List<Color> _cardGradient(CardType type) {
    switch (type) {
      case CardType.visa: return [RtColors.info, RtColors.infoDark];
      case CardType.mastercard: return [RtColors.warning, RtColors.warningDark];
      case CardType.amex: return [RtColors.success, RtColors.successDark];
      case CardType.discover: return [RtColors.accentBlue, RtColors.accentBlue.withValues(alpha: 0.7)];
      case CardType.other: return [RtColors.neutral600, RtColors.neutral800];
    }
  }

  String _cardLogoText(CardType type) {
    switch (type) {
      case CardType.visa: return 'VISA';
      case CardType.mastercard: return 'MasterCard';
      case CardType.amex: return 'AMEX';
      case CardType.discover: return 'Discover';
      case CardType.other: return 'CARD';
    }
  }

  String _methodDescription(PaymentMethodType type) {
    final l10n = AppLocalizations.of(context)!;
    switch (type) {
      case PaymentMethodType.cash: return l10n.cashDescription;
      case PaymentMethodType.wallet: return l10n.walletDescription;
      case PaymentMethodType.paypal: return l10n.paypalDescription;
      case PaymentMethodType.card: return l10n.paymentMethodDefault;
    }
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    final l10n = AppLocalizations.of(context)!;
    if (diff.inHours < 24) return '${l10n.todayDate}, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 1) return '${l10n.yesterdayDate}, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    return '${date.day}/${date.month}/${date.year}';
  }
}

// -- AddPaymentMethodSheet --------------------------------------------------

class AddPaymentMethodSheet extends StatefulWidget {
  final ScrollController scrollController;
  final Function(PaymentMethod) onMethodAdded;

  const AddPaymentMethodSheet({super.key, required this.scrollController, required this.onMethodAdded});

  @override
  State<AddPaymentMethodSheet> createState() => _AddPaymentMethodSheetState();
}

class _AddPaymentMethodSheetState extends State<AddPaymentMethodSheet> {
  final _formKey = GlobalKey<FormState>();
  final _numberCtrl = TextEditingController();
  final _holderCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;

  @override
  void dispose() {
    _numberCtrl.dispose();
    _holderCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(RtSpacing.xl),
      child: Form(
        key: _formKey,
        child: ListView(
          controller: widget.scrollController,
          children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: RtSpacing.lg),
                decoration: BoxDecoration(color: RtColors.neutral300, borderRadius: RtRadius.borderFull))),
            Text(l10n.addCard, style: RtTypo.displaySmall),
            const SizedBox(height: RtSpacing.xl),
            TextFormField(
              controller: _numberCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.cardNumberLabel, prefixIcon: const Icon(Icons.credit_card),
                  border: OutlineInputBorder(borderRadius: RtRadius.borderMd)),
              validator: (v) => (v == null || v.isEmpty) ? l10n.cardNumberRequired : null,
            ),
            const SizedBox(height: RtSpacing.base),
            TextFormField(
              controller: _holderCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: l10n.cardHolderLabel, prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(borderRadius: RtRadius.borderMd)),
              validator: (v) => (v == null || v.isEmpty) ? l10n.cardHolderRequired : null,
            ),
            const SizedBox(height: RtSpacing.base),
            Row(
              children: [
                Expanded(child: TextFormField(
                  controller: _expiryCtrl,
                  keyboardType: TextInputType.datetime,
                  decoration: InputDecoration(labelText: l10n.expiryLabel, prefixIcon: const Icon(Icons.calendar_today),
                      border: OutlineInputBorder(borderRadius: RtRadius.borderMd)),
                  validator: (v) => (v == null || v.isEmpty) ? l10n.requiredField : null,
                )),
                const SizedBox(width: RtSpacing.base),
                Expanded(child: TextFormField(
                  controller: _cvvCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  decoration: InputDecoration(labelText: l10n.cvvLabel, prefixIcon: const Icon(Icons.lock),
                      border: OutlineInputBorder(borderRadius: RtRadius.borderMd)),
                  validator: (v) => (v == null || v.isEmpty) ? l10n.requiredField : null,
                )),
              ],
            ),
            const SizedBox(height: RtSpacing.xl),
            RtButton(
              label: l10n.addCard,
              isFullWidth: true,
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _addCard,
            ),
            const SizedBox(height: RtSpacing.base),
            Center(child: Text(l10n.dataSecureMessage, style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500))),
          ],
        ),
      ),
    );
  }

  Future<void> _addCard() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final cardType = _detectCardType(_numberCtrl.text);
      final last4 = _numberCtrl.text.replaceAll(' ', '');
      final lastFour = last4.substring(last4.length - 4);

      final docRef = await _firebaseService.firestore
          .collection('users').doc(user.uid).collection('payment_methods').add({
        'name': '${cardType.name.toUpperCase()} ---- $lastFour',
        'lastFourDigits': lastFour,
        'cardHolder': _holderCtrl.text.toUpperCase(),
        'expiryDate': _expiryCtrl.text,
        'cardType': cardType.name,
        'isDefault': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final method = PaymentMethod(
        id: docRef.id,
        type: PaymentMethodType.card,
        name: '${cardType.name.toUpperCase()} ---- $lastFour',
        cardNumber: '---- ---- ---- $lastFour',
        cardHolder: _holderCtrl.text.toUpperCase(),
        expiryDate: _expiryCtrl.text,
        cardType: cardType,
        isDefault: false,
        icon: Icons.credit_card,
        color: _colorForType(cardType),
      );
      widget.onMethodAdded(method);

      if (!mounted) return;
      Navigator.pop(context);
      RtSnackbar.show(context, message: AppLocalizations.of(context)!.cardAddedSuccess, type: RtSnackbarType.success);
    } catch (e) {
      if (!mounted) return;
      RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  CardType _detectCardType(String num) {
    final c = num.replaceAll(' ', '');
    if (c.startsWith('4')) return CardType.visa;
    if (c.startsWith(RegExp(r'^5[1-5]'))) return CardType.mastercard;
    if (c.startsWith(RegExp(r'^3[47]'))) return CardType.amex;
    if (c.startsWith('6011')) return CardType.discover;
    return CardType.other;
  }

  Color _colorForType(CardType t) {
    switch (t) {
      case CardType.visa: return RtColors.info;
      case CardType.mastercard: return RtColors.warning;
      case CardType.amex: return RtColors.success;
      case CardType.discover: return RtColors.accentBlue;
      case CardType.other: return RtColors.neutral500;
    }
  }
}

// -- CustomPainter para patron de tarjeta -----------------------------------

class CardPatternPainter extends CustomPainter {
  final Color color;
  CardPatternPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i < 5; i++) {
      final y = size.height * (i + 1) / 6;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (int i = 0; i < 8; i++) {
      final x = size.width * (i + 1) / 9;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
