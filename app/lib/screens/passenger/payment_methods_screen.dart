// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart'; // ✅ Extensión para colores que se adaptan al tema
import '../../generated/l10n/app_localizations.dart';
import '../../core/utils/currency_formatter.dart';
import '../../services/payment_service.dart';
import '../../services/firebase_service.dart';
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
  _PaymentMethodsScreenState createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen>
    with TickerProviderStateMixin {
  late AnimationController _listAnimationController;
  late AnimationController _cardFlipController;
  late AnimationController _fabAnimationController;

  // ✅ Servicios
  final PaymentService _paymentService = PaymentService();
  final FirebaseService _firebaseService = FirebaseService();

  String _defaultMethodId = 'cash'; // ✅ Efectivo como método por defecto
  bool _isLoading = true;
  String? _userId;

  // ✅ ACTUALIZADO: Métodos de pago se cargan desde Firebase
  final List<PaymentMethod> _paymentMethods = [
    PaymentMethod(
      id: 'cash',
      type: PaymentMethodType.cash,
      name: 'Efectivo',
      isDefault: true,
      icon: Icons.money,
      color: ModernTheme.success,
    ),
    PaymentMethod(
      id: 'wallet',
      type: PaymentMethodType.wallet,
      name: 'Billetera Rappi Team',
      walletBalance: '0.00',
      isDefault: false,
      icon: Icons.account_balance_wallet,
      color: ModernTheme.rappiOrange,
    ),
  ];

  // ✅ ACTUALIZADO: Historial se carga desde Firebase
  List<PaymentHistoryItem> _transactionHistory = [];
  
  @override
  void initState() {
    super.initState();

    _listAnimationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _cardFlipController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _fabAnimationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    )..forward();

    // ✅ Inicializar servicios y cargar datos
    _initializeServices();
  }

  /// Inicializar PaymentService y cargar datos desde Firebase
  Future<void> _initializeServices() async {
    try {
      // Obtener usuario actual
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        AppLogger.error('Usuario no autenticado');
        setState(() => _isLoading = false);
        return;
      }

      _userId = user.uid;

      // ✅ SIMPLIFICADO: NO inicializar PaymentService (causa errores de conexión)
      // Solo cargar datos desde Firestore directamente, como lo hacen otros módulos

      // Cargar payment methods desde Firebase
      await _loadPaymentMethodsFromFirebase();

      // Cargar wallet balance
      await _loadWalletBalance();

      // NO cargar historial de transacciones (requiere PaymentService)
      // await _loadTransactionHistory();

      setState(() {
        _isLoading = false;
      });

      AppLogger.info('Métodos de pago cargados exitosamente');

    } catch (e) {
      AppLogger.error('Error cargando métodos de pago: $e');
      setState(() {
        _isLoading = false;
      });

      // Solo mostrar error si es un problema real, no si está vacío
      if (mounted && !e.toString().contains('Bad state: No element')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudieron cargar los métodos de pago'),
            backgroundColor: ModernTheme.warning,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Cargar métodos de pago guardados desde Firestore
  Future<void> _loadPaymentMethodsFromFirebase() async {
    if (_userId == null) return;

    try {
      final snapshot = await _firebaseService.firestore
          .collection('users')
          .doc(_userId)
          .collection('payment_methods')
          .orderBy('createdAt', descending: true)
          .limit(50) // ✅ Agregar limit para cumplir con reglas de Firestore
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();

        // Convertir de Firestore a PaymentMethod
        final method = PaymentMethod(
          id: doc.id,
          type: PaymentMethodType.card,
          name: data['name'] ?? 'Tarjeta',
          cardNumber: data['lastFourDigits'] != null
              ? '•••• ${data['lastFourDigits']}'
              : null,
          cardHolder: data['cardHolder'],
          expiryDate: data['expiryDate'],
          cardType: _parseCardType(data['cardType']),
          isDefault: data['isDefault'] ?? false,
          icon: Icons.credit_card,
          color: _getCardColorFromType(_parseCardType(data['cardType'])),
        );

        setState(() {
          _paymentMethods.add(method);
          if (method.isDefault) {
            _defaultMethodId = method.id;
          }
        });
      }
    } catch (e) {
      AppLogger.error('Error cargando payment methods: $e');
    }
  }

  /// Cargar balance de billetera desde Firestore
  Future<void> _loadWalletBalance() async {
    if (_userId == null) return;

    try {
      final userDoc = await _firebaseService.firestore
          .collection('users')
          .doc(_userId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        final walletBalance = (data?['walletBalance'] ?? 0.0).toDouble();

        // Actualizar balance en el método wallet
        setState(() {
          final walletIndex = _paymentMethods.indexWhere(
            (m) => m.type == PaymentMethodType.wallet
          );
          if (walletIndex != -1) {
            _paymentMethods[walletIndex] = PaymentMethod(
              id: _paymentMethods[walletIndex].id,
              type: _paymentMethods[walletIndex].type,
              name: _paymentMethods[walletIndex].name,
              walletBalance: walletBalance.toStringAsFixed(2),
              isDefault: _paymentMethods[walletIndex].isDefault,
              icon: _paymentMethods[walletIndex].icon,
              color: _paymentMethods[walletIndex].color,
            );
          }
        });
      }
    } catch (e) {
      AppLogger.error('Error cargando wallet balance: $e');
    }
  }

  /// Cargar historial de transacciones desde PaymentService
  Future<void> _loadTransactionHistory() async {
    if (_userId == null) return;

    try {
      final history = await _paymentService.getUserPaymentHistory(_userId!, 'passenger');

      setState(() {
        _transactionHistory = history;
      });

      // ✅ NUEVO: Log informativo si está vacío (no es error)
      if (history.isEmpty) {
        AppLogger.info('No hay historial de transacciones aún');
      }
    } catch (e) {
      AppLogger.error('Error cargando historial: $e');
      // ✅ No mostrar SnackBar aquí, solo loguear el error
      // El historial vacío es manejado por el UI con _buildEmptyState
    }
  }

  CardType _parseCardType(String? type) {
    switch (type?.toLowerCase()) {
      case 'visa':
        return CardType.visa;
      case 'mastercard':
        return CardType.mastercard;
      case 'amex':
        return CardType.amex;
      case 'discover':
        return CardType.discover;
      default:
        return CardType.other;
    }
  }

  Color _getCardColorFromType(CardType type) {
    switch (type) {
      case CardType.visa:
        return ModernTheme.info;
      case CardType.mastercard:
        return ModernTheme.warning;
      case CardType.amex:
        return ModernTheme.success;
      case CardType.discover:
        return ModernTheme.primaryBlue;
      default:
        return Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
    }
  }
  
  @override
  void dispose() {
    _listAnimationController.dispose();
    _cardFlipController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: context.surfaceColor,
        appBar: AppBar(
          backgroundColor: ModernTheme.rappiOrange,
          title: Text(
            AppLocalizations.of(context)!.paymentMethodsTitle,
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.help_outline, color: Theme.of(context).colorScheme.onPrimary),
              onPressed: _showHelp,
            ),
          ],
          bottom: TabBar(
            indicatorColor: Theme.of(context).colorScheme.onPrimary,
            labelColor: Theme.of(context).colorScheme.onPrimary,
            unselectedLabelColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
            tabs: [
              Tab(text: AppLocalizations.of(context)!.paymentMethodsTab),
              Tab(text: AppLocalizations.of(context)!.historyTab),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPaymentMethodsTab(),
            _buildHistoryTab(),
          ],
        ),
        floatingActionButton: AnimatedBuilder(
          animation: _fabAnimationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _fabAnimationController.value,
              child: FloatingActionButton.extended(
                onPressed: _addPaymentMethod,
                backgroundColor: ModernTheme.rappiOrange,
                icon: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
                label: Text(
                  AppLocalizations.of(context)!.addMethod,
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildPaymentMethodsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance card for wallet
          _buildWalletBalance(),
          
          SizedBox(height: 24),
          
          // Payment methods section
          Text(
            AppLocalizations.of(context)!.savedMethods,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.primaryText,
            ),
          ),
          SizedBox(height: 16),
          
          // Grid 2 columnas para métodos de pago
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: _paymentMethods.map((method) {
              return _buildPaymentMethodGridCard(method);
            }).toList(),
          ),
          
          SizedBox(height: 24),
          
          // Security info
          _buildSecurityInfo(),
          
          SizedBox(height: 80),
        ],
      ),
    );
  }
  
  Widget _buildHistoryTab() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: ModernTheme.rappiOrange));
    }

    if (_transactionHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: context.secondaryText),
            SizedBox(height: 16),
            Text(
              'No hay transacciones aún',
              style: TextStyle(
                color: context.secondaryText,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _transactionHistory.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildHistorySummary();
        }

        final transaction = _transactionHistory[index - 1];
        return _buildTransactionCard(transaction);
      },
    );
  }
  
  Widget _buildWalletBalance() {
    final wallet = _paymentMethods.firstWhere(
      (m) => m.type == PaymentMethodType.wallet,
      orElse: () => _paymentMethods.first,
    );
    
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: ModernTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ModernTheme.rappiOrange.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
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
                  Text(
                    AppLocalizations.of(context)!.rappiWallet,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    double.tryParse(wallet.walletBalance ?? "0.0")?.toCurrency() ?? (0.0).toCurrency(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.surface,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  color: Theme.of(context).colorScheme.surface,
                  size: 32,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _rechargeWallet,
                  icon: Icon(Icons.add),
                  label: Text(AppLocalizations.of(context)!.recharge),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    foregroundColor: ModernTheme.rappiOrange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _viewWalletHistory,
                  icon: Icon(Icons.history),
                  label: Text(AppLocalizations.of(context)!.historyButton),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    side: BorderSide(color: Theme.of(context).colorScheme.onPrimary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
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
    
    return GestureDetector(
      onTap: () => _showCardDetails(method),
      onLongPress: () => _setDefaultMethod(method),
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        height: 200,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _getCardGradient(method.cardType!),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: method.color.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Card pattern
            Positioned.fill(
              child: CustomPaint(
                painter: CardPatternPainter(Theme.of(context).colorScheme.surface),
              ),
            ),
            
            // Card content
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _getCardLogo(method.cardType!),
                      if (isDefault)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.defaultBadge,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.surface,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        method.cardNumber ?? '',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.surface,
                          fontSize: 22,
                          letterSpacing: 2,
                          fontFamily: 'monospace',
                        ),
                      ),
                      SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(context)!.cardHolder,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                method.cardHolder ?? '',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.surface,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(context)!.expiresLabel,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                method.expiryDate ?? '',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.surface,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Delete button
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.54), size: 20),
                onPressed: () => _deletePaymentMethod(method),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Card cuadrada para el grid de 2 columnas - ícono grande centrado
  Widget _buildPaymentMethodGridCard(PaymentMethod method) {
    final isSelected = method.id == _defaultMethodId;

    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          _setDefaultMethod(method);
        }
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: ModernTheme.getCardShadow(context),
          border: Border.all(
            color: isSelected ? ModernTheme.rappiOrange : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
            width: isSelected ? 3 : 1,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: method.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(method.icon, color: method.color, size: 32),
              ),
              SizedBox(height: 12),
              Text(
                method.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: context.primaryText,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (isSelected) ...[
                SizedBox(height: 6),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.defaultLabel,
                    style: TextStyle(
                      color: ModernTheme.rappiOrange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard(PaymentMethod method) {
    final isDefault = method.id == _defaultMethodId;
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.getCardShadow(context),
        border: Border.all(
          color: isDefault ? ModernTheme.rappiOrange : Theme.of(context).colorScheme.surfaceContainerHighest,
          width: 2,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: method.color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            method.icon,
            color: method.color,
            size: 24,
          ),
        ),
        title: Text(
          method.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: context.primaryText,
          ),
        ),
        subtitle: Text(
          method.walletBalance != null
              ? AppLocalizations.of(context)!.balanceLabel(method.walletBalance!)
              : _getMethodDescription(method.type),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDefault)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  AppLocalizations.of(context)!.defaultLabel,
                  style: TextStyle(
                    color: ModernTheme.rappiOrange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert),
              onSelected: (value) => _handleMethodAction(method, value),
              itemBuilder: (context) => [
                if (!isDefault)
                  PopupMenuItem(
                    value: 'default',
                    child: Row(
                      children: [
                        Icon(Icons.star, size: 20),
                        SizedBox(width: 12),
                        Text(AppLocalizations.of(context)!.makeDefault),
                      ],
                    ),
                  ),
                if (method.type != PaymentMethodType.cash)
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: ModernTheme.error),
                        SizedBox(width: 12),
                        Text(AppLocalizations.of(context)!.deleteButton, style: TextStyle(color: ModernTheme.error)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        onTap: () {
          if (!isDefault) {
            _setDefaultMethod(method);
          }
        },
      ),
    );
  }
  
  Widget _buildHistorySummary() {
    final totalSpent = _transactionHistory.fold<double>(
      0, (total, t) => total + t.amount);
    final successfulTransactions = _transactionHistory
      .where((t) => t.status == 'approved').length;
    
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [ModernTheme.primaryBlue, ModernTheme.primaryBlue.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            AppLocalizations.of(context)!.monthlySummary,
            style: TextStyle(
              color: Theme.of(context).colorScheme.surface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                AppLocalizations.of(context)!.totalSpent,
                totalSpent.toCurrency(),
                Icons.account_balance_wallet // ✅ Cambiado de attach_money ($) a wallet,
              ),
              _buildSummaryItem(
                AppLocalizations.of(context)!.transactionsLabel,
                _transactionHistory.length.toString(),
                Icons.receipt,
              ),
              _buildSummaryItem(
                AppLocalizations.of(context)!.successfulLabel,
                '$successfulTransactions/${_transactionHistory.length}',
                Icons.check_circle,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7), size: 24),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.surface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  Widget _buildTransactionCard(PaymentHistoryItem transaction) {
    final isSuccess = transaction.status == 'approved';
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.getCardShadow(context),
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (isSuccess ? ModernTheme.success : ModernTheme.error)
              .withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isSuccess ? Icons.check_circle : Icons.error,
            color: isSuccess ? ModernTheme.success : ModernTheme.error,
          ),
        ),
        title: Text(
          AppLocalizations.of(context)!.tripLabel(transaction.rideId),
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(transaction.paymentMethod),
            Text(
              _formatDate(transaction.createdAt),
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              transaction.amount.toCurrency(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.primaryText,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (isSuccess ? ModernTheme.success : ModernTheme.error)
                  .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isSuccess ? AppLocalizations.of(context)!.successfulStatus : AppLocalizations.of(context)!.failedStatus,
                style: TextStyle(
                  color: isSuccess ? ModernTheme.success : ModernTheme.error,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        onTap: () => _showTransactionDetails(transaction),
      ),
    );
  }
  
  Widget _buildSecurityInfo() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ModernTheme.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ModernTheme.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.security, color: ModernTheme.info),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.paymentsProtected,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ModernTheme.info,
                  ),
                ),
                Text(
                  AppLocalizations.of(context)!.encryptionMessage,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  List<Color> _getCardGradient(CardType type) {
    switch (type) {
      case CardType.visa:
        return [ModernTheme.info, ModernTheme.info.withValues(alpha: 0.7)];
      case CardType.mastercard:
        return [ModernTheme.warning, ModernTheme.warning.withValues(alpha: 0.7)];
      case CardType.amex:
        return [ModernTheme.success, ModernTheme.success.withValues(alpha: 0.7)];
      case CardType.discover:
        return [ModernTheme.primaryBlue, ModernTheme.primaryBlue.withValues(alpha: 0.7)];
      default:
        return [Theme.of(context).colorScheme.onSurface.withOpacity(0.6), Theme.of(context).colorScheme.onSurface.withOpacity(0.4)];
    }
  }
  
  Widget _getCardLogo(CardType type) {
    String logoText;
    switch (type) {
      case CardType.visa:
        logoText = 'VISA';
        break;
      case CardType.mastercard:
        logoText = 'MasterCard';
        break;
      case CardType.amex:
        logoText = 'AMEX';
        break;
      case CardType.discover:
        logoText = 'Discover';
        break;
      default:
        logoText = 'CARD';
    }
    
    return Text(
      logoText,
      style: TextStyle(
        color: Theme.of(context).colorScheme.surface,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.italic,
      ),
    );
  }
  
  String _getMethodDescription(PaymentMethodType type) {
    switch (type) {
      case PaymentMethodType.cash:
        return AppLocalizations.of(context)!.cashDescription;
      case PaymentMethodType.wallet:
        return AppLocalizations.of(context)!.walletDescription;
      case PaymentMethodType.paypal:
        return AppLocalizations.of(context)!.paypalDescription;
      default:
        return AppLocalizations.of(context)!.paymentMethodDefault;
    }
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inHours < 24) {
      return '${AppLocalizations.of(context)!.todayDate}, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return '${AppLocalizations.of(context)!.yesterdayDate}, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
  
  void _setDefaultMethod(PaymentMethod method) {
    setState(() {
      _defaultMethodId = method.id;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.defaultMethodMessage(method.name)),
        backgroundColor: ModernTheme.success,
      ),
    );
  }
  
  /// ✅ IMPLEMENTADO: Eliminar método de pago de Firestore
  void _deletePaymentMethod(PaymentMethod method) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(AppLocalizations.of(context)!.deletePaymentMethod),
        content: Text(AppLocalizations.of(context)!.confirmDeleteMethod(method.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancelButton),
          ),
          ElevatedButton(
            onPressed: () async {
              final successMessage = AppLocalizations.of(context)!.methodDeleted;
              Navigator.pop(context);

              // Eliminar de Firestore si no es cash o wallet
              if (method.type == PaymentMethodType.card && _userId != null) {
                try {
                  await _firebaseService.firestore
                      .collection('users')
                      .doc(_userId)
                      .collection('payment_methods')
                      .doc(method.id)
                      .delete();
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
              _showSuccess(successMessage);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.error,
            ),
            child: Text(AppLocalizations.of(context)!.deleteButton),
          ),
        ],
      ),
    );
  }
  
  void _handleMethodAction(PaymentMethod method, String action) {
    switch (action) {
      case 'default':
        _setDefaultMethod(method);
        break;
      case 'delete':
        _deletePaymentMethod(method);
        break;
    }
  }
  
  void _addPaymentMethod() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: AddPaymentMethodSheet(
              scrollController: scrollController,
              onMethodAdded: (method) {
                setState(() {
                  _paymentMethods.add(method);
                });
              },
            ),
          );
        },
      ),
    );
  }
  
  void _showCardDetails(PaymentMethod method) {
    _cardFlipController.forward().then((_) {
      Future.delayed(Duration(seconds: 2), () {
        _cardFlipController.reverse();
      });
    });
  }
  
  /// ✅ IMPLEMENTADO: Recargar billetera con MercadoPago
  void _rechargeWallet() {
    final TextEditingController customAmountController = TextEditingController();
    double selectedAmount = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)!.rechargeWallet,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 24),

              // Amount chips
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [10, 20, 50, 100, 200].map((amount) {
                  return ChoiceChip(
                    label: Text(amount.toCurrency(decimals: 0)),
                    selected: selectedAmount == amount.toDouble(),
                    selectedColor: ModernTheme.rappiOrange.withValues(alpha: 0.3),
                    onSelected: (selected) {
                      setModalState(() {
                        selectedAmount = selected ? amount.toDouble() : 0;
                        customAmountController.clear();
                      });
                    },
                  );
                }).toList(),
              ),

              SizedBox(height: 16),

              TextField(
                controller: customAmountController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.customAmount,
                  prefixText: 'S/. ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setModalState(() {
                    selectedAmount = double.tryParse(value) ?? 0;
                  });
                },
              ),

              SizedBox(height: 24),

              ElevatedButton(
                onPressed: selectedAmount > 0
                    ? () async {
                        Navigator.pop(context);
                        await _processRecharge(selectedAmount);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ModernTheme.rappiOrange,
                  minimumSize: Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  selectedAmount > 0
                      ? 'Recargar ${selectedAmount.toCurrency()}'
                      : AppLocalizations.of(context)!.recharge,
                ),
              ),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Procesar recarga con MercadoPago
  Future<void> _processRecharge(double amount) async {
    if (_userId == null) return;

    try {
      // Mostrar loader
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(color: ModernTheme.rappiOrange),
        ),
      );

      // Obtener datos del usuario
      final userDoc = await _firebaseService.firestore
          .collection('users')
          .doc(_userId)
          .get();

      final userData = userDoc.data();
      final email = userData?['email'] ?? '';
      final name = userData?['name'] ?? 'Usuario';

      // Crear preferencia de pago
      final result = await _paymentService.createMercadoPagoPreference(
        rideId: 'wallet_recharge_${DateTime.now().millisecondsSinceEpoch}',
        amount: amount,
        payerEmail: email,
        payerName: name,
        description: 'Recarga de billetera Rappi Team',
      );

      if (!mounted) return;
      Navigator.pop(context); // Cerrar loader

      if (result.success && result.initPoint != null) {
        // Abrir MercadoPago en WebView
        await _openMercadoPagoWebView(result.initPoint!, amount);
      } else {
        _showError('Error creando preferencia de pago: ${result.error}');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Cerrar loader
      AppLogger.error('Error procesando recarga: $e');
      _showError('Error procesando recarga: $e');
    }
  }

  /// Abrir MercadoPago en WebView
  Future<void> _openMercadoPagoWebView(String url, double amount) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('MercadoPago'),
            backgroundColor: ModernTheme.rappiOrange,
          ),
          body: WebViewWidget(
            controller: WebViewController()
              ..setJavaScriptMode(JavaScriptMode.unrestricted)
              ..setNavigationDelegate(
                NavigationDelegate(
                  onPageFinished: (url) async {
                    final navigator = Navigator.of(context);

                    // Detectar si el pago fue exitoso
                    if (url.contains('success') || url.contains('approved')) {
                      // Actualizar wallet balance en Firestore
                      await _updateWalletBalance(amount);

                      if (!mounted) return;
                      navigator.pop();

                      final successMessage = 'Recarga exitosa de ${amount.toCurrency()}';
                      _showSuccess(successMessage);

                      // Recargar datos
                      await _loadWalletBalance();
                      await _loadTransactionHistory();
                    } else if (url.contains('failure') || url.contains('pending')) {
                      if (!mounted) return;
                      navigator.pop();
                      _showError('El pago no pudo completarse');
                    }
                  },
                ),
              )
              ..loadRequest(Uri.parse(url)),
          ),
        ),
      ),
    );
  }

  /// Actualizar balance de wallet en Firestore
  Future<void> _updateWalletBalance(double amount) async {
    if (_userId == null) return;

    try {
      await _firebaseService.firestore.collection('users').doc(_userId).update({
        'walletBalance': FieldValue.increment(amount),
      });
    } catch (e) {
      AppLogger.error('Error actualizando wallet balance: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: ModernTheme.success,
        ),
      );
    }
  }
  
  /// ✅ IMPLEMENTADO: Ver historial de wallet
  void _viewWalletHistory() {
    // Cambiar a la pestaña de historial
    DefaultTabController.of(context).animateTo(1);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mostrando historial de transacciones'),
        backgroundColor: ModernTheme.info,
        duration: Duration(seconds: 2),
      ),
    );
  }
  
  /// ✅ IMPLEMENTADO: Mostrar detalles de transacción con descarga de PDF
  void _showTransactionDetails(PaymentHistoryItem transaction) async {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Text(
              AppLocalizations.of(context)!.transactionDetails,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 20),

            _buildDetailRow(AppLocalizations.of(context)!.transactionId, transaction.id),
            _buildDetailRow(AppLocalizations.of(context)!.tripDetailLabel, transaction.rideId),
            _buildDetailRow(AppLocalizations.of(context)!.dateDetailLabel, _formatDate(transaction.createdAt)),
            _buildDetailRow(AppLocalizations.of(context)!.methodDetailLabel, transaction.paymentMethod),
            _buildDetailRow(AppLocalizations.of(context)!.amountDetailLabel, transaction.amount.toCurrency()),
            _buildDetailRow('Comisión plataforma', transaction.platformCommission.toCurrency()),
            _buildDetailRow(
              AppLocalizations.of(context)!.statusDetailLabel,
              transaction.status == 'approved' ? AppLocalizations.of(context)!.successfulStatus : AppLocalizations.of(context)!.failedStatus,
            ),

            SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _generateTransactionPDF(transaction);
                    },
                    icon: Icon(Icons.download),
                    label: Text(AppLocalizations.of(context)!.downloadButton),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/support');
                    },
                    icon: Icon(Icons.help),
                    label: Text(AppLocalizations.of(context)!.helpButton),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ModernTheme.rappiOrange,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Generar PDF de recibo de transacción
  Future<void> _generateTransactionPDF(PaymentHistoryItem transaction) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Text(
                    'RECIBO DE TRANSACCIÓN',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Text(
                    'Rappi Team',
                    style: pw.TextStyle(fontSize: 18),
                  ),
                ),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 20),

                // Transaction details
                _buildPdfRow('ID de Transacción:', transaction.id),
                _buildPdfRow('ID de Viaje:', transaction.rideId),
                _buildPdfRow('Fecha:', DateFormat('dd/MM/yyyy HH:mm').format(transaction.createdAt)),
                _buildPdfRow('Método de Pago:', transaction.paymentMethod),
                pw.SizedBox(height: 10),

                // Amounts
                pw.Divider(),
                _buildPdfRow('Monto Total:', transaction.amount.toCurrency(), bold: true),
                _buildPdfRow('Comisión Plataforma:', transaction.platformCommission.toCurrency()),
                _buildPdfRow('Estado:', transaction.status == 'approved' ? 'Aprobado' : 'Pendiente'),
                pw.Divider(),

                pw.SizedBox(height: 20),

                // Footer
                pw.Center(
                  child: pw.Text(
                    'Generado el ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Guardar y compartir PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );

      _showSuccess('Recibo generado exitosamente');
    } catch (e) {
      AppLogger.error('Error generando PDF: $e');
      _showError('Error generando recibo');
    }
  }

  /// Helper para crear fila en PDF
  pw.Widget _buildPdfRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 12)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.secondaryText,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.help_outline, color: ModernTheme.rappiOrange),
            SizedBox(width: 8),
            Text(AppLocalizations.of(context)!.helpTitle),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHelpItem(AppLocalizations.of(context)!.helpItem1),
            _buildHelpItem(AppLocalizations.of(context)!.helpItem2),
            _buildHelpItem(AppLocalizations.of(context)!.helpItem3),
            _buildHelpItem(AppLocalizations.of(context)!.helpItem4),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.understood),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHelpItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 14),
      ),
    );
  }
}

// Add payment method sheet
class AddPaymentMethodSheet extends StatefulWidget {
  final ScrollController scrollController;
  final Function(PaymentMethod) onMethodAdded;
  
  const AddPaymentMethodSheet({
    super.key,
    required this.scrollController,
    required this.onMethodAdded,
  });
  
  @override
  _AddPaymentMethodSheetState createState() => _AddPaymentMethodSheetState();
}

class _AddPaymentMethodSheetState extends State<AddPaymentMethodSheet> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();

  final FirebaseService _firebaseService = FirebaseService();

  CardType _selectedCardType = CardType.visa;
  bool _isLoading = false;
  
  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: ListView(
          controller: widget.scrollController,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            Text(
              AppLocalizations.of(context)!.addCard,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            SizedBox(height: 24),
            
            TextFormField(
              controller: _cardNumberController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.cardNumberLabel,
                prefixIcon: Icon(Icons.credit_card),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return AppLocalizations.of(context)!.cardNumberRequired;
                }
                return null;
              },
            ),
            
            SizedBox(height: 16),
            
            TextFormField(
              controller: _cardHolderController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.cardHolderLabel,
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return AppLocalizations.of(context)!.cardHolderRequired;
                }
                return null;
              },
            ),
            
            SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _expiryController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.expiryLabel,
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.datetime,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!.requiredField;
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _cvvController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.cvvLabel,
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!.requiredField;
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 24),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _addCard,
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.rappiOrange,
                minimumSize: Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.surface,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(AppLocalizations.of(context)!.addCard),
            ),

            SizedBox(height: 16),

            Center(
              child: Text(
                AppLocalizations.of(context)!.dataSecureMessage,
                style: TextStyle(
                  color: context.secondaryText,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// ✅ IMPLEMENTADO: Agregar tarjeta y guardar en Firestore
  Future<void> _addCard() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Obtener usuario actual
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw Exception('Usuario no autenticado');
        }

        // Detectar tipo de tarjeta automáticamente
        _selectedCardType = _detectCardType(_cardNumberController.text);

        // Obtener últimos 4 dígitos
        final lastFourDigits = _cardNumberController.text.replaceAll(' ', '').substring(
          _cardNumberController.text.replaceAll(' ', '').length - 4
        );

        // Guardar en Firestore (NO guardamos el número completo por seguridad)
        final docRef = await _firebaseService.firestore
            .collection('users')
            .doc(user.uid)
            .collection('payment_methods')
            .add({
          'name': '${_selectedCardType.name.toUpperCase()} •••• $lastFourDigits',
          'lastFourDigits': lastFourDigits,
          'cardHolder': _cardHolderController.text.toUpperCase(),
          'expiryDate': _expiryController.text,
          'cardType': _selectedCardType.name,
          'isDefault': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Crear objeto PaymentMethod para UI
        final newMethod = PaymentMethod(
          id: docRef.id,
          type: PaymentMethodType.card,
          name: '${_selectedCardType.name.toUpperCase()} •••• $lastFourDigits',
          cardNumber: '•••• •••• •••• $lastFourDigits',
          cardHolder: _cardHolderController.text.toUpperCase(),
          expiryDate: _expiryController.text,
          cardType: _selectedCardType,
          isDefault: false,
          icon: Icons.credit_card,
          color: _getCardColor(_selectedCardType),
        );

        widget.onMethodAdded(newMethod);

        if (!mounted) return;
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.cardAddedSuccess),
            backgroundColor: ModernTheme.success,
          ),
        );
      } catch (e) {
        AppLogger.error('Error agregando tarjeta: $e');

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error agregando tarjeta: $e'),
            backgroundColor: ModernTheme.error,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Detectar tipo de tarjeta por número
  CardType _detectCardType(String cardNumber) {
    final cleaned = cardNumber.replaceAll(' ', '');

    if (cleaned.startsWith('4')) {
      return CardType.visa;
    } else if (cleaned.startsWith(RegExp(r'^5[1-5]'))) {
      return CardType.mastercard;
    } else if (cleaned.startsWith(RegExp(r'^3[47]'))) {
      return CardType.amex;
    } else if (cleaned.startsWith('6011')) {
      return CardType.discover;
    }

    return CardType.other;
  }

  /// Obtener color por tipo de tarjeta
  Color _getCardColor(CardType type) {
    switch (type) {
      case CardType.visa:
        return ModernTheme.info;
      case CardType.mastercard:
        return ModernTheme.warning;
      case CardType.amex:
        return ModernTheme.success;
      case CardType.discover:
        return ModernTheme.primaryBlue;
      default:
        return Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
    }
  }
}

// Custom painter for card pattern
class CardPatternPainter extends CustomPainter {
  final Color color;

  CardPatternPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    // Draw pattern
    for (int i = 0; i < 5; i++) {
      final y = size.height * (i + 1) / 6;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
    
    for (int i = 0; i < 8; i++) {
      final x = size.width * (i + 1) / 9;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}