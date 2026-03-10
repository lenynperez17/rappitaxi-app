// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para cargar assets (fuente TTF)
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart'; // ✅ Extensión para colores que se adaptan al tema
import '../../widgets/animated/modern_animated_widgets.dart';
import '../../core/utils/currency_formatter.dart';
import '../../services/payment_service.dart';
import '../../widgets/mercadopago_checkout_pro_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with TickerProviderStateMixin {
  late AnimationController _balanceController;
  late AnimationController _cardsController;
  late AnimationController _transactionsController;
  late TabController _tabController;
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PaymentService _paymentService = PaymentService();
  final bool _isLoading = false;

  // Balance desde Firebase (colección wallets)
  double _currentBalance = 0.0;
  bool _isBalanceLoaded = false;
  final double _weeklyEarnings = 0.0;
  final double _monthlyEarnings = 0.0;

  // ✅ NUEVO: Ganancias semanales para el gráfico (7 días: L, M, M, J, V, S, D)
  final List<double> _weeklyEarningsChart = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  
  // Método de retiro seleccionado
  String _selectedWithdrawalMethod = 'bank';
  final TextEditingController _withdrawalAmountController = TextEditingController();

  // Controlador para recarga de saldo
  final TextEditingController _rechargeAmountController = TextEditingController();
  
  // Subscription para escuchar cambios de wallet
  StreamSubscription<DocumentSnapshot>? _walletSubscription;

  // Transacciones reales desde Firebase (inicialmente vacío)
  final List<Transaction> _transactions = [];
  
  // Estadísticas
  Map<String, dynamic> get _statistics {
    final today = DateTime.now();
    final todayEarnings = _transactions
        .where((t) =>
            t.type == TransactionType.tripEarning &&
            t.date.day == today.day &&
            t.date.month == today.month &&
            t.date.year == today.year)
        .fold<double>(0, (total, t) => total + t.amount);

    final totalTrips = _transactions
        .where((t) => t.type == TransactionType.tripEarning)
        .length;

    final totalCommission = _transactions
        .where((t) => t.type == TransactionType.tripEarning)
        .fold<double>(0, (total, t) => total + (t.commission ?? 0));
    
    return {
      'todayEarnings': todayEarnings,
      'totalTrips': totalTrips,
      'totalCommission': totalCommission,
      'avgPerTrip': totalTrips > 0 ? todayEarnings / totalTrips : 0.0,
    };
  }
  
  @override
  void initState() {
    super.initState();
    
    _balanceController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    )..forward();
    
    _cardsController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    
    _transactionsController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    )..forward();
    
    _tabController = TabController(length: 4, vsync: this);

    // Configurar listener de wallet (una sola vez en initState)
    _setupWalletListener();

    // Inicializar servicio de pagos
    _initializePaymentService();
  }

  /// Configurar listener de wallet desde Firestore (llamado una sola vez desde initState)
  void _setupWalletListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _walletSubscription = _firestore.collection('wallets').doc(user.uid).snapshots().listen((snapshot) {
      if (!mounted) return;
      if (snapshot.exists) {
        final walletData = snapshot.data();
        if (walletData != null) {
          final newBalance = (walletData['serviceCredits'] as num?)?.toDouble() ?? 0.0;

          // Solo actualizar si el balance cambió
          if (_currentBalance != newBalance) {
            setState(() {
              _currentBalance = newBalance;
              _isBalanceLoaded = true;
            });
          } else if (!_isBalanceLoaded) {
            setState(() => _isBalanceLoaded = true);
          }
        }
      } else {
        // Wallet no existe aún, mostrar 0
        if (!_isBalanceLoaded) {
          setState(() => _isBalanceLoaded = true);
        }
      }
    });
  }

  Future<void> _initializePaymentService() async {
    try {
      await _paymentService.initialize(isProduction: true); // Usar producción
    } catch (e) {
      debugPrint('Error inicializando PaymentService: $e');
    }
  }
  
  @override
  void dispose() {
    _walletSubscription?.cancel();
    _balanceController.dispose();
    _cardsController.dispose();
    _transactionsController.dispose();
    _tabController.dispose();
    _withdrawalAmountController.dispose();
    _rechargeAmountController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: context.surfaceColor,
        appBar: AppBar(
          backgroundColor: ModernTheme.rappiOrange,
          title: Text('Mi Billetera', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
        ),
        body: Center(
          child: Text('Usuario no autenticado'),
        ),
      );
    }

    return Scaffold(
          backgroundColor: context.surfaceColor,
          appBar: AppBar(
            backgroundColor: ModernTheme.rappiOrange,
            title: Text(
              'Mi Billetera',
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
          ),
          body: Column(
        children: [
          // UI: Balance como CircleAvatar naranja grande flotante arriba
          Container(
            color: ModernTheme.rappiOrange,
            padding: const EdgeInsets.only(top: 20, bottom: 32),
            child: Center(
              child: AnimatedBuilder(
                animation: _balanceController,
                builder: (context, child) {
                  final displayBalance = _currentBalance * _balanceController.value;
                  return Transform.scale(
                    scale: 0.8 + (0.2 * _balanceController.value),
                    child: Opacity(
                      opacity: _balanceController.value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.2),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: ModernTheme.rappiOrange.withValues(alpha: 0.5),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
                                const SizedBox(height: 4),
                                Text(
                                  CurrencyFormatter.formatCurrency(displayBalance),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                Text(
                                  'Disponible',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // UI: Tabs Todo | Ingresos | Gastos con indicador naranja
          Container(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: ModernTheme.rappiOrange,
              unselectedLabelColor: context.secondaryText,
              indicatorColor: ModernTheme.rappiOrange,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'Todo'),
                Tab(text: 'Ingresos'),
                Tab(text: 'Gastos'),
                Tab(text: 'Retirar'),
              ],
            ),
          ),

          // Contenido de tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSummaryTab(),
                _buildTransactionsTab(),
                _buildRechargeTab(),
                _buildWithdrawTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ModernTheme.rappiOrange,
            ModernTheme.rappiOrange.withBlue(50),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ModernTheme.rappiOrange.withValues(alpha: 0.4),
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
                    'Balance Disponible',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.70),
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 8),
                  AnimatedBuilder(
                    animation: _balanceController,
                    builder: (context, child) {
                      final displayBalance = _currentBalance * _balanceController.value;
                      return Text(
                        CurrencyFormatter.formatCurrency(displayBalance),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
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
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 30,
                ),
              ),
            ],
          ),
          
          SizedBox(height: 20),
          
          // Estadísticas rápidas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickStat(
                'Esta Semana',
                CurrencyFormatter.formatCurrency(_weeklyEarnings),
                Icons.calendar_today,
              ),
              Container(
                height: 40,
                width: 1,
                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.24),
              ),
              _buildQuickStat(
                'Este Mes',
                CurrencyFormatter.formatCurrency(_monthlyEarnings),
                Icons.calendar_month,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.70), size: 20),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.70),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  Widget _buildSummaryTab() {
    final stats = _statistics;
    
    return AnimatedBuilder(
      animation: _cardsController,
      builder: (context, child) {
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estadísticas del Día',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.primaryText,
                ),
              ),
              SizedBox(height: 16),
              
              // Grid de estadísticas
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.5,
                children: [
                  _buildStatCard(
                    'Ganancias Hoy',
                    CurrencyFormatter.formatCurrency((stats['todayEarnings'] as num).toDouble()),
                    Icons.today,
                    ModernTheme.success,
                    0,
                  ),
                  _buildStatCard(
                    'Viajes Completados',
                    '${stats['totalTrips']}',
                    Icons.directions_car,
                    ModernTheme.primaryBlue,
                    1,
                  ),
                  _buildStatCard(
                    'Comisión Total',
                    CurrencyFormatter.formatCurrency((stats['totalCommission'] as num).toDouble()),
                    Icons.receipt,
                    ModernTheme.warning,
                    2,
                  ),
                  _buildStatCard(
                    'Promedio/Viaje',
                    CurrencyFormatter.formatCurrency((stats['avgPerTrip'] as num).toDouble()),
                    Icons.analytics,
                    ModernTheme.info,
                    3,
                  ),
                ],
              ),
              
              SizedBox(height: 24),
              
              // Gráfico de ganancias
              Text(
                'Ganancias de la Semana',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.primaryText,
                ),
              ),
              SizedBox(height: 16),
              
              Container(
                height: 200,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: ModernTheme.getCardShadow(context),
                ),
                child: CustomPaint(
                  painter: EarningsChartPainter(
                    animation: _cardsController,
                    weeklyEarnings: _weeklyEarningsChart, // ✅ FIX: Pasar datos reales
                    textColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    primaryTextColor: Theme.of(context).colorScheme.onSurface,
                  ),
                  child: Container(),
                ),
              ),
              
              SizedBox(height: 24),
              
              // Metas y objetivos
              Text(
                'Metas del Mes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.primaryText,
                ),
              ),
              SizedBox(height: 16),
              
              _buildGoalCard(
                'Meta de Ganancias',
                _monthlyEarnings,
                3000.00,
                ModernTheme.rappiOrange,
              ),
              SizedBox(height: 12),
              _buildGoalCard(
                'Viajes Completados',
                stats['totalTrips'],
                150,
                ModernTheme.primaryBlue,
              ),
              SizedBox(height: 12),
              _buildGoalCard(
                'Calificación Promedio',
                0.0, // ✅ Calificación real desde Firebase (inicialmente 0)
                5.0,
                ModernTheme.warning,
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildTransactionsTab() {
    // ✅ Mostrar mensaje si no hay transacciones
    if (_transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 80,
              color: context.secondaryText.withValues(alpha: 0.3),
            ),
            SizedBox(height: 16),
            Text(
              'No hay transacciones aún',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.secondaryText,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tus viajes y retiros aparecerán aquí',
              style: TextStyle(
                fontSize: 14,
                color: context.secondaryText.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _transactionsController,
      builder: (context, child) {
        return Column(
          children: [
            // ✅ NUEVO: Botón de exportar transacciones
            Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: ElevatedButton.icon(
                onPressed: _exportTransactions,
                icon: Icon(Icons.download),
                label: Text('Exportar Transacciones'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ModernTheme.rappiOrange,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  minimumSize: Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: _transactions.length,
                itemBuilder: (context, index) {
                  final transaction = _transactions[index];
                  final delay = index * 0.1;
                  final animation = Tween<double>(
                    begin: 0,
                    end: 1,
                  ).animate(
                    CurvedAnimation(
                      parent: _transactionsController,
                      curve: Interval(
                        delay,
                        delay + 0.5,
                        curve: Curves.easeOutBack,
                      ),
                    ),
                  );

                  return AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(50 * (1 - animation.value), 0),
                        child: Opacity(
                          opacity: animation.value,
                          child: _buildTransactionCard(transaction),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildRechargeTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Información sobre recarga
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ModernTheme.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ModernTheme.info.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: ModernTheme.info,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Recarga tu billetera para aceptar viajes y recibir pagos',
                    style: TextStyle(
                      color: context.secondaryText,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Balance actual
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ModernTheme.rappiOrange.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  color: ModernTheme.rappiOrange,
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Balance actual',
                      style: TextStyle(
                        color: context.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatCurrency(_currentBalance),
                      style: TextStyle(
                        color: ModernTheme.rappiOrange,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Monto a recargar
          Text(
            'Monto a Recargar',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.primaryText,
            ),
          ),
          SizedBox(height: 12),

          TextField(
            controller: _rechargeAmountController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.add_circle, color: ModernTheme.rappiOrange),
              hintText: '0.00',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: ModernTheme.rappiOrange, width: 2),
              ),
            ),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: 12),

          // Botones rápidos de monto
          Wrap(
            spacing: 8,
            children: [20, 50, 100, 200].map((amount) {
              return ActionChip(
                label: Text(CurrencyFormatter.formatCurrency(amount.toDouble(), decimals: 0)),
                onPressed: () {
                  setState(() {
                    _rechargeAmountController.text = amount.toString();
                  });
                },
                backgroundColor: context.surfaceColor,
              );
            }).toList(),
          ),

          SizedBox(height: 24),

          // Vista previa del monto total después de recarga
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ModernTheme.rappiOrange.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Balance actual:',
                      style: TextStyle(color: context.secondaryText),
                    ),
                    Text(
                      CurrencyFormatter.formatCurrency(_currentBalance),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: context.primaryText,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Monto a recargar:',
                      style: TextStyle(color: context.secondaryText),
                    ),
                    Text(
                      CurrencyFormatter.formatCurrency(
                        double.tryParse(_rechargeAmountController.text) ?? 0.0,
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ModernTheme.rappiOrange,
                      ),
                    ),
                  ],
                ),
                Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Nuevo balance:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    _isBalanceLoaded
                        ? Text(
                            CurrencyFormatter.formatCurrency(
                              _currentBalance + (double.tryParse(_rechargeAmountController.text) ?? 0.0),
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: ModernTheme.rappiOrange,
                            ),
                          )
                        : SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Botón de recarga con MercadoPago
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _processRecharge,
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.rappiOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payment, color: Theme.of(context).colorScheme.onPrimary),
                  SizedBox(width: 8),
                  Text(
                    'Recargar con MercadoPago',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // Información importante
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ModernTheme.rappiOrange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ModernTheme.rappiOrange.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_outline, size: 20, color: ModernTheme.rappiOrange),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '• La recarga es inmediata\n'
                    '• Se acepta tarjetas de crédito/débito\n'
                    '• Transacción segura con MercadoPago\n'
                    '• Monto mínimo: S/ 10.00',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.primaryText,
                      height: 1.5,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance disponible
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ModernTheme.rappiOrange.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  color: ModernTheme.rappiOrange,
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Disponible para retirar',
                      style: TextStyle(
                        color: context.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatCurrency(_currentBalance),
                      style: TextStyle(
                        color: ModernTheme.rappiOrange,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          SizedBox(height: 24),
          
          // Monto a retirar
          Text(
            'Monto a Retirar',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.primaryText,
            ),
          ),
          SizedBox(height: 12),
          
          TextField(
            controller: _withdrawalAmountController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.account_balance_wallet, color: ModernTheme.rappiOrange), // ✅ Cambiado de attach_money ($) a wallet
              hintText: '0.00',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: ModernTheme.rappiOrange, width: 2),
              ),
            ),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          SizedBox(height: 12),
          
          // Botones rápidos de monto
          Wrap(
            spacing: 8,
            children: [50, 100, 200, 500].map((amount) {
              return ActionChip(
                label: Text(CurrencyFormatter.formatCurrency(amount.toDouble(), decimals: 0)),
                onPressed: () {
                  setState(() {
                    _withdrawalAmountController.text = amount.toString();
                  });
                },
                backgroundColor: context.surfaceColor,
              );
            }).toList(),
          ),
          
          SizedBox(height: 24),
          
          // Método de retiro
          Text(
            'Método de Retiro',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.primaryText,
            ),
          ),
          SizedBox(height: 12),
          
          // Solo cuenta bancaria - Única opción real implementada
          _buildWithdrawalMethod(
            'bank',
            'Transferencia Bancaria',
            'Procesa en 1-2 días hábiles',
            Icons.account_balance,
          ),
          
          SizedBox(height: 24),
          
          // Información importante
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ModernTheme.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ModernTheme.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: ModernTheme.warning,
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Información Importante',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: ModernTheme.warning,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• Solo transferencia bancaria disponible\n'
                        '• Los retiros se procesan en 1-2 días hábiles\n'
                        '• Monto mínimo de retiro: ${CurrencyFormatter.formatCurrency(20.0)}\n'
                        '• Sin comisiones por retiro\n'
                        '• Procesado vía MercadoPago Money Out',
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
          ),
          
          SizedBox(height: 24),
          
          // Botón de retirar
          AnimatedPulseButton(
            text: 'Solicitar Retiro',
            icon: Icons.send,
            onPressed: _processWithdrawal,
            color: ModernTheme.rappiOrange,
          ),
          
          SizedBox(height: 24),
          
          // Historial de retiros
          Text(
            'Retiros Recientes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.primaryText,
            ),
          ),
          SizedBox(height: 12),
          
          ..._transactions
              .where((t) => t.type == TransactionType.withdrawal)
              .take(3)
              .map((t) => _buildWithdrawalHistoryItem(t)),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    int index,
  ) {
    final delay = index * 0.1;
    final animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _cardsController,
        curve: Interval(
          delay,
          delay + 0.5,
          curve: Curves.easeOutBack,
        ),
      ),
    );
    
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.scale(
          scale: animation.value,
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: ModernTheme.getCardShadow(context),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.primaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.secondaryText,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildGoalCard(
    String title,
    num current,
    num goal,
    Color color,
  ) {
    final progress = (current / goal).clamp(0.0, 1.0).toDouble();
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.getCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: context.primaryText,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              AnimatedContainer(
                duration: Duration(milliseconds: 800),
                height: 8,
                width: MediaQuery.of(context).size.width * progress * 0.8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                current is double
                  ? CurrencyFormatter.formatCurrency(current)
                  : current.toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: context.secondaryText,
                ),
              ),
              Text(
                goal is double
                  ? CurrencyFormatter.formatCurrency(goal)
                  : goal.toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: context.secondaryText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildTransactionCard(Transaction transaction) {
    final isEarning = transaction.amount > 0;
    final icon = _getTransactionIcon(transaction.type);
    final color = _getTransactionColor(transaction.type);
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.getCardShadow(context),
      ),
      child: InkWell(
        onTap: () => _showTransactionDetails(transaction),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (transaction.passenger != null)
                      Text(
                        transaction.passenger!,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.secondaryText,
                        ),
                      ),
                    Text(
                      _formatDate(transaction.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isEarning ? '+' : '-'}${CurrencyFormatter.formatCurrency(transaction.amount.abs())}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isEarning ? ModernTheme.success : ModernTheme.error,
                    ),
                  ),
                  if (transaction.commission != null)
                    Text(
                      'Comisión: ${CurrencyFormatter.formatCurrency(transaction.commission!)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: context.secondaryText,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildWithdrawalMethod(
    String value,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final isSelected = _selectedWithdrawalMethod == value;
    
    return InkWell(
      onTap: () => setState(() => _selectedWithdrawalMethod = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
            ? ModernTheme.rappiOrange.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
              ? ModernTheme.rappiOrange
              : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected 
                ? ModernTheme.rappiOrange 
                : context.secondaryText,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected 
                        ? ModernTheme.rappiOrange 
                        : context.primaryText,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: _selectedWithdrawalMethod,
              onChanged: (val) => setState(() => _selectedWithdrawalMethod = val!),
              activeColor: ModernTheme.rappiOrange,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildWithdrawalHistoryItem(Transaction transaction) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.history,
            color: context.secondaryText,
            size: 20,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: TextStyle(fontSize: 14),
                ),
                Text(
                  _formatDate(transaction.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Text(
            CurrencyFormatter.formatCurrency(transaction.amount.abs()),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: context.primaryText,
            ),
          ),
        ],
      ),
    );
  }
  
  IconData _getTransactionIcon(TransactionType type) {
    switch (type) {
      case TransactionType.tripEarning:
        return Icons.directions_car;
      case TransactionType.withdrawal:
        return Icons.account_balance;
      case TransactionType.bonus:
        return Icons.card_giftcard;
      case TransactionType.penalty:
        return Icons.warning;
    }
  }
  
  Color _getTransactionColor(TransactionType type) {
    switch (type) {
      case TransactionType.tripEarning:
        return ModernTheme.success;
      case TransactionType.withdrawal:
        return ModernTheme.primaryBlue;
      case TransactionType.bonus:
        return Theme.of(context).colorScheme.secondary;
      case TransactionType.penalty:
        return ModernTheme.error;
    }
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return 'Hace ${difference.inMinutes} min';
      }
      return 'Hace ${difference.inHours} horas';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    }
    
    return '${date.day}/${date.month}/${date.year}';
  }
  
  void _showTransactionDetails(Transaction transaction) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.0),
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Detalles de la Transacción',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            _buildDetailRow('ID', transaction.id),
            _buildDetailRow('Tipo', transaction.type.toString().split('.').last),
            _buildDetailRow('Descripción', transaction.description),
            if (transaction.passenger != null)
              _buildDetailRow('Pasajero', transaction.passenger!),
            _buildDetailRow('Fecha', _formatDate(transaction.date)),
            _buildDetailRow('Hora',
              '${transaction.date.hour.toString().padLeft(2, '0')}:${transaction.date.minute.toString().padLeft(2, '0')}'),
            _buildDetailRow('Monto', CurrencyFormatter.formatCurrency(transaction.amount.abs())),
            if (transaction.commission != null)
              _buildDetailRow('Comisión', CurrencyFormatter.formatCurrency(transaction.commission!)),
            _buildDetailRow('Estado', transaction.status),
            SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close),
              label: Text('Cerrar'),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: context.secondaryText),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
  
  Future<void> _processWithdrawal() async {
    final amount = double.tryParse(_withdrawalAmountController.text) ?? 0;

    if (amount < 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('El monto mínimo de retiro es ${CurrencyFormatter.formatCurrency(50.0)}'),
          backgroundColor: ModernTheme.error,
        ),
      );
      return;
    }

    if (amount > _currentBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saldo insuficiente'),
          backgroundColor: ModernTheme.error,
        ),
      );
      return;
    }

    // Obtener datos bancarios del conductor
    final bankData = await _showBankAccountDialog();
    if (bankData == null) return; // Usuario canceló
    if (!mounted) return;

    // Mostrar diálogo de confirmación
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.account_balance, color: ModernTheme.rappiOrange, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Confirmar Retiro',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Estás a punto de retirar:'),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Monto:'),
                      Text(
                        CurrencyFormatter.formatCurrency(amount),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ModernTheme.rappiOrange,
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Banco:'),
                      Text(bankData['bankName'] ?? '', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Cuenta:'),
                      Text('***${() { final acc = bankData['bankAccount'] ?? ''; return acc.length >= 4 ? acc.substring(acc.length - 4) : acc; }()}'),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: ModernTheme.info),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'El retiro se procesará en 1-2 días hábiles',
                    style: TextStyle(fontSize: 12, color: context.secondaryText),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: TextStyle(
                decoration: TextDecoration.none,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.rappiOrange,
            ),
            child: Text(
              'Confirmar',
              style: TextStyle(
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    // Mostrar diálogo de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: ModernTheme.rappiOrange),
              SizedBox(height: 16),
              Text('Procesando retiro...'),
            ],
          ),
        ),
      ),
    );

    try {
      // Obtener usuario actual
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      // Solicitar retiro con MercadoPago Money Out API
      final withdrawalResult = await _paymentService.requestWithdrawal(
        driverId: user.uid,
        amount: amount,
        method: 'bank_transfer', // Método de retiro: transferencia bancaria
        bankName: bankData['bankName'] ?? '',
        accountNumber: bankData['bankAccount'] ?? '',
        accountHolderName: bankData['accountHolderName'] ?? '',
        accountHolderDocumentType: bankData['documentType'] ?? 'DNI',
        accountHolderDocumentNumber: bankData['documentNumber'] ?? '',
      );

      if (!mounted) return;
      Navigator.pop(context); // Cerrar diálogo de carga

      if (!withdrawalResult.success) {
        throw Exception(withdrawalResult.error ?? 'Error desconocido al procesar retiro');
      }

      if (!mounted) return;
      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onPrimary),
                  SizedBox(width: 12),
                  Expanded(child: Text('Retiro solicitado exitosamente')),
                ],
              ),
              SizedBox(height: 4),
              Text(
                'ID: ${withdrawalResult.withdrawalId}',
                style: TextStyle(fontSize: 11),
              ),
              Text(
                'Se procesará en 1-2 días hábiles',
                style: TextStyle(fontSize: 11),
              ),
            ],
          ),
          backgroundColor: ModernTheme.success,
          duration: Duration(seconds: 5),
        ),
      );

      // Limpiar campo de monto
      _withdrawalAmountController.clear();
      setState(() {});

      // Nota: El saldo se actualizará automáticamente cuando la transferencia
      // sea confirmada por MercadoPago a través del webhook

    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Cerrar diálogo de carga si todavía está abierto

      if (!mounted) return;

      // Limpiar mensaje de error para mostrar algo amigable al usuario
      String errorMessage = 'No se pudo procesar el retiro. Intenta nuevamente.';
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('network') || errorStr.contains('conexión')) {
        errorMessage = 'Error de conexión. Verifica tu internet e intenta nuevamente.';
      } else if (errorStr.contains('saldo') || errorStr.contains('fondos')) {
        errorMessage = 'Saldo insuficiente para realizar el retiro.';
      } else if (errorStr.contains('cuenta') || errorStr.contains('bank')) {
        errorMessage = 'Datos de cuenta bancaria inválidos. Verifica la información.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ $errorMessage'),
          backgroundColor: ModernTheme.error,
          duration: Duration(seconds: 5),
        ),
      );

      debugPrint('Error en _processWithdrawal: $e');
    }
  }

  /// Mostrar diálogo para ingresar datos bancarios
  Future<Map<String, String>?> _showBankAccountDialog() async {
    final bankNameController = TextEditingController();
    final bankAccountController = TextEditingController();
    final accountHolderController = TextEditingController();
    final documentNumberController = TextEditingController();
    String documentType = 'DNI';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Datos de Cuenta Bancaria'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: accountHolderController,
                  decoration: InputDecoration(
                    labelText: 'Titular de la Cuenta',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: documentType,
                        decoration: InputDecoration(
                          labelText: 'Tipo Doc.',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          isDense: true,
                        ),
                        style: TextStyle(fontSize: 13, color: context.primaryText),
                        items: [
                          DropdownMenuItem(value: 'DNI', child: Text('DNI', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: 'CE', child: Text('C.E.', style: TextStyle(fontSize: 13))),
                        ],
                        onChanged: (value) {
                          setState(() {
                            documentType = value!;
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: documentNumberController,
                        decoration: InputDecoration(
                          labelText: 'Número',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                TextField(
                  controller: bankNameController,
                  decoration: InputDecoration(
                    labelText: 'Banco',
                    border: OutlineInputBorder(),
                    hintText: 'Ej: BCP, Interbank, BBVA',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                SizedBox(height: 12),
                TextField(
                  controller: bankAccountController,
                  decoration: InputDecoration(
                    labelText: 'Número de Cuenta',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ModernTheme.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: ModernTheme.info),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Verifica que los datos sean correctos',
                          style: TextStyle(fontSize: 12, color: context.secondaryText),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                // Validar campos
                if (accountHolderController.text.isEmpty ||
                    documentNumberController.text.isEmpty ||
                    bankNameController.text.isEmpty ||
                    bankAccountController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Por favor completa todos los campos'),
                      backgroundColor: ModernTheme.error,
                    ),
                  );
                  return;
                }

                Navigator.pop(context, {
                  'accountHolderName': accountHolderController.text,
                  'documentType': documentType,
                  'documentNumber': documentNumberController.text,
                  'bankName': bankNameController.text,
                  'bankAccount': bankAccountController.text,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.rappiOrange,
              ),
              child: Text('Continuar'),
            ),
          ],
        ),
      ),
    );

    // Limpiar controllers
    bankNameController.dispose();
    bankAccountController.dispose();
    accountHolderController.dispose();
    documentNumberController.dispose();

    return result;
  }
  
  // ✅ NUEVO: Exportar transacciones
  void _exportTransactions() async {
    try {
      // Mostrar diálogo para elegir formato
      final format = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Exportar Transacciones'),
          content: Text('¿En qué formato deseas exportar las transacciones?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'csv'),
              child: Text('CSV'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'pdf'),
              child: Text('PDF'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar'),
            ),
          ],
        ),
      );

      if (format == null) return;

      // Generar datos de transacciones
      final transactionsData = _generateTransactionsData();

      // Exportar según formato
      if (format == 'csv') {
        await _exportToCSV(transactionsData);
      } else if (format == 'pdf') {
        await _exportToPDF(transactionsData);
      }

      // ✅ El archivo ya fue compartido en _exportToCSV o _exportToPDF
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al exportar: $e'),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  String _generateTransactionsData() {
    final buffer = StringBuffer();
    buffer.writeln('HISTORIAL DE TRANSACCIONES - RAPPI TEAM');
    buffer.writeln('Fecha de generación: ${DateTime.now().toString().split('.')[0]}');
    buffer.writeln('');
    buffer.writeln('RESUMEN:');
    buffer.writeln('- Total Transacciones: ${_transactions.length}');
    buffer.writeln('- Balance Actual: ${CurrencyFormatter.formatCurrency(_currentBalance)}');
    buffer.writeln('- Ganancias Semana: ${CurrencyFormatter.formatCurrency(_weeklyEarnings)}');
    buffer.writeln('- Ganancias Mes: ${CurrencyFormatter.formatCurrency(_monthlyEarnings)}');
    buffer.writeln('');
    buffer.writeln('DETALLE DE TRANSACCIONES:');
    buffer.writeln('');

    if (_transactions.isEmpty) {
      buffer.writeln('No hay transacciones registradas.');
    } else {
      for (var transaction in _transactions) {
        final typeStr = transaction.type.toString().split('.').last;
        final sign = transaction.amount > 0 ? '+' : '-';
        buffer.writeln('ID: ${transaction.id}');
        buffer.writeln('Fecha: ${_formatDate(transaction.date)} ${transaction.date.hour.toString().padLeft(2, '0')}:${transaction.date.minute.toString().padLeft(2, '0')}');
        buffer.writeln('Tipo: $typeStr');
        buffer.writeln('Descripción: ${transaction.description}');
        if (transaction.passenger != null) {
          buffer.writeln('Pasajero: ${transaction.passenger}');
        }
        buffer.writeln('Monto: $sign${CurrencyFormatter.formatCurrency(transaction.amount.abs())}');
        if (transaction.commission != null) {
          buffer.writeln('Comisión: ${CurrencyFormatter.formatCurrency(transaction.commission!)}');
        }
        buffer.writeln('Estado: ${transaction.status}');
        buffer.writeln('---');
      }
    }

    return buffer.toString();
  }

  Future<void> _exportToCSV(String data) async {
    try {
      // ✅ IMPLEMENTACIÓN REAL: Generar archivo CSV de transacciones
      final List<List<dynamic>> csvData = [
        ['HISTORIAL DE TRANSACCIONES - RAPPI TEAM'],
        ['Fecha de generación', DateTime.now().toString().split('.')[0]],
        [],
        ['RESUMEN'],
        ['Métrica', 'Valor'],
        ['Total Transacciones', _transactions.length],
        ['Balance Actual', CurrencyFormatter.formatCurrency(_currentBalance)],
        ['Ganancias Semana', CurrencyFormatter.formatCurrency(_weeklyEarnings)],
        ['Ganancias Mes', CurrencyFormatter.formatCurrency(_monthlyEarnings)],
        [],
        ['DETALLE DE TRANSACCIONES'],
        ['ID', 'Fecha', 'Hora', 'Tipo', 'Descripción', 'Pasajero', 'Monto', 'Comisión', 'Estado'],
      ];

      if (_transactions.isEmpty) {
        csvData.add(['No hay transacciones registradas']);
      } else {
        for (var transaction in _transactions) {
          final typeStr = transaction.type.toString().split('.').last;
          final sign = transaction.amount > 0 ? '+' : '-';
          csvData.add([
            transaction.id,
            _formatDate(transaction.date),
            '${transaction.date.hour.toString().padLeft(2, '0')}:${transaction.date.minute.toString().padLeft(2, '0')}',
            typeStr,
            transaction.description,
            transaction.passenger ?? 'N/A',
            '$sign${CurrencyFormatter.formatCurrency(transaction.amount.abs())}',
            transaction.commission != null ? CurrencyFormatter.formatCurrency(transaction.commission!) : 'N/A',
            transaction.status,
          ]);
        }
      }

      // Convertir a CSV
      String csvString = const ListToCsvConverter().convert(csvData);

      // Obtener directorio temporal
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/transacciones_rappi_$timestamp.csv';

      // Escribir archivo
      final file = File(filePath);
      await file.writeAsString(csvString);

      // Compartir archivo usando share_plus
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Historial de Transacciones - Rappi Team',
        text: 'Historial de transacciones generado el ${DateTime.now().toString().split('.')[0]}',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onPrimary),
              SizedBox(width: 12),
              Expanded(child: Text('Archivo CSV generado exitosamente')),
            ],
          ),
          backgroundColor: ModernTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al exportar CSV: $e'),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  Future<void> _exportToPDF(String data) async {
    try {
      // ✅ CARGAR FUENTES CUSTOM con soporte Unicode completo
      final fontRegular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final fontBold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      final ttfRegular = pw.Font.ttf(fontRegular);
      final ttfBold = pw.Font.ttf(fontBold);

      // ✅ IMPLEMENTACIÓN REAL: Generar archivo PDF de transacciones
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              // Título
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#28A745'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'HISTORIAL DE TRANSACCIONES',
                      style: pw.TextStyle(
                        font: ttfBold, // ✅ Usar fuente custom
                        color: PdfColors.white,
                        fontSize: 24,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'RAPPI TEAM',
                      style: pw.TextStyle(
                        font: ttfRegular, // ✅ Usar fuente custom
                        color: PdfColors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Información general
              pw.Text(
                'Fecha de generación: ${DateTime.now().toString().split('.')[0]}',
                style: pw.TextStyle(font: ttfRegular, fontSize: 12),
              ),
              pw.SizedBox(height: 20),

              // Resumen
              pw.Text(
                'RESUMEN',
                style: pw.TextStyle(
                  font: ttfBold, // ✅ Usar fuente bold
                  fontSize: 16,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  _buildPdfTransactionRow('Total Transacciones', '${_transactions.length}', true, ttfRegular, ttfBold),
                  _buildPdfTransactionRow('Balance Actual', CurrencyFormatter.formatCurrency(_currentBalance), false, ttfRegular, ttfBold),
                  _buildPdfTransactionRow('Ganancias Semana', CurrencyFormatter.formatCurrency(_weeklyEarnings), true, ttfRegular, ttfBold),
                  _buildPdfTransactionRow('Ganancias Mes', CurrencyFormatter.formatCurrency(_monthlyEarnings), false, ttfRegular, ttfBold),
                ],
              ),
              pw.SizedBox(height: 20),

              // Transacciones
              pw.Text(
                'DETALLE DE TRANSACCIONES',
                style: pw.TextStyle(
                  font: ttfBold, // ✅ Usar fuente bold
                  fontSize: 16,
                ),
              ),
              pw.SizedBox(height: 10),

              if (_transactions.isEmpty)
                pw.Text('No hay transacciones registradas', style: pw.TextStyle(font: ttfRegular, fontSize: 12))
              else
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2), // Descripción
                    1: const pw.FlexColumnWidth(1.5), // Fecha
                    2: const pw.FlexColumnWidth(1), // Monto
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColor.fromHex('#28A745')),
                      children: [
                        _buildPdfTransactionHeaderCell('Descripción', ttfBold),
                        _buildPdfTransactionHeaderCell('Fecha', ttfBold),
                        _buildPdfTransactionHeaderCell('Monto', ttfBold),
                      ],
                    ),
                    ..._transactions.take(50).map((transaction) {
                      final sign = transaction.amount > 0 ? '+' : '-';
                      return pw.TableRow(
                        children: [
                          _buildPdfTransactionCell(transaction.description, ttfRegular),
                          _buildPdfTransactionCell(_formatDate(transaction.date), ttfRegular),
                          _buildPdfTransactionCell(
                            '$sign${CurrencyFormatter.formatCurrency(transaction.amount.abs())}',
                            ttfRegular,
                          ),
                        ],
                      );
                    }),
                  ],
                ),

              if (_transactions.length > 50)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 10),
                  child: pw.Text(
                    'Mostrando las primeras 50 transacciones de ${_transactions.length} totales',
                    style: pw.TextStyle(font: ttfRegular, fontSize: 10, fontStyle: pw.FontStyle.italic),
                  ),
                ),
            ];
          },
        ),
      );

      // Guardar PDF en archivo temporal
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/transacciones_rappi_$timestamp.pdf';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      // Compartir archivo usando share_plus
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Historial de Transacciones - Rappi Team',
        text: 'Historial de transacciones generado el ${DateTime.now().toString().split('.')[0]}',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onPrimary),
              SizedBox(width: 12),
              Expanded(child: Text('Archivo PDF generado exitosamente')),
            ],
          ),
          backgroundColor: ModernTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al exportar PDF: $e'),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  // ✅ NUEVO: Funciones helper para generar tabla PDF de transacciones
  pw.TableRow _buildPdfTransactionRow(String label, String value, bool isEven, pw.Font fontRegular, pw.Font fontBold) {
    return pw.TableRow(
      decoration: isEven
        ? pw.BoxDecoration(color: PdfColors.grey100)
        : null,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(label, style: pw.TextStyle(font: fontRegular)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(value, style: pw.TextStyle(font: fontBold)),
        ),
      ],
    );
  }

  pw.Widget _buildPdfTransactionHeaderCell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font, // ✅ Usar fuente custom
          color: PdfColors.white,
          fontSize: 10,
        ),
      ),
    );
  }

  pw.Widget _buildPdfTransactionCell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 9)), // ✅ Usar fuente custom
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text('Ayuda - Billetera'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cómo funciona tu billetera:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '• Las ganancias se acumulan después de cada viaje\n'
                '• Puedes retirar cuando tengas mínimo ${CurrencyFormatter.formatCurrency(10.0)}\n'
                '• Los retiros se procesan en 1-2 días hábiles\n'
                '• No hay comisiones por retiro\n'
                '• Revisa tus estadísticas para mejorar tus ganancias',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Entendido'),
          ),
        ],
      ),
    );
  }

  // Procesar recarga de saldo con MercadoPago
  Future<void> _processRecharge() async {
    final amount = double.tryParse(_rechargeAmountController.text);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor ingresa un monto válido'),
          backgroundColor: ModernTheme.error,
        ),
      );
      return;
    }

    if (amount < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('El monto mínimo de recarga es S/ 10.00'),
          backgroundColor: ModernTheme.error,
        ),
      );
      return;
    }

    // Mostrar diálogo de confirmación
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.payment, color: ModernTheme.rappiOrange, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Confirmar Recarga',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estás a punto de recargar:',
              style: TextStyle(
                decoration: TextDecoration.none,
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Monto:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  Text(
                    CurrencyFormatter.formatCurrency(amount),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: ModernTheme.rappiOrange,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Nuevo balance será:',
              style: TextStyle(
                fontSize: 12,
                color: context.secondaryText,
                decoration: TextDecoration.none,
              ),
            ),
            Text(
              CurrencyFormatter.formatCurrency(_currentBalance + amount),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ModernTheme.rappiOrange,
                decoration: TextDecoration.none,
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.security, size: 18, color: ModernTheme.rappiOrange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pago seguro procesado por MercadoPago',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.primaryText,
                        decoration: TextDecoration.none,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: TextStyle(
                decoration: TextDecoration.none,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.rappiOrange,
            ),
            child: Text(
              'Confirmar',
              style: TextStyle(
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    // Mostrar diálogo de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 40),
          padding: EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: ModernTheme.getCardShadow(context),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Spinner con gradiente verde de RappiTeam
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: ModernTheme.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: ModernTheme.rappiOrange.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary),
                    strokeWidth: 3.5,
                  ),
                ),
              ),
              SizedBox(height: 24),
              // Texto con estilo moderno
              Text(
                'Procesando recarga',
                style: TextStyle(
                  color: context.primaryText,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  decoration: TextDecoration.none,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Por favor espera un momento',
                style: TextStyle(
                  color: context.secondaryText,
                  fontSize: 14,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // Obtener datos del usuario actual
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      // Obtener información adicional del usuario desde Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();
      final userName = userData?['name'] ?? user.displayName ?? 'Usuario';
      final userEmail = user.email ?? 'usuario@rapiteam.app';

      // Generar ID único para la recarga
      final rechargeId = 'RECARGA_${DateTime.now().millisecondsSinceEpoch}';

      // Crear preferencia de pago con MercadoPago
      final preferenceResult = await _paymentService.createMercadoPagoPreference(
        rideId: rechargeId,
        amount: amount,
        payerEmail: userEmail,
        payerName: userName,
        description: 'Recarga de saldo RappiTeam - $userName',
      );

      if (!mounted) return;
      Navigator.pop(context); // Cerrar diálogo de carga

      if (!preferenceResult.success || preferenceResult.initPoint == null) {
        throw Exception(preferenceResult.error ?? 'No se pudo crear la preferencia de pago');
      }

      // Open MercadoPago Checkout Pro (hosted page with Yape, Plin, cards, etc.)
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MercadoPagoCheckoutProWidget(
            initPoint: preferenceResult.initPoint!,
            transactionId: rechargeId,
            amount: amount,
            onPaymentComplete: (status, transactionId) async {
              // Close checkout widget
              Navigator.pop(context);

              if (!mounted) return;

              if (status == 'approved') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Recarga exitosa! Tu saldo se actualizará en unos momentos.'),
                    backgroundColor: ModernTheme.success,
                    duration: Duration(seconds: 5),
                  ),
                );
                await Future.delayed(Duration(seconds: 2));
              } else if (status == 'pending') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Pago en proceso. Tu saldo se actualizará cuando sea confirmado.'),
                    backgroundColor: ModernTheme.warning,
                    duration: Duration(seconds: 5),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Pago rechazado. Verifica tu método de pago e intenta nuevamente.'),
                    backgroundColor: ModernTheme.error,
                    duration: Duration(seconds: 7),
                  ),
                );
              }
            },
            onCancel: () {
              Navigator.pop(context);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Recarga cancelada'),
                  backgroundColor: ModernTheme.info,
                  duration: Duration(seconds: 3),
                ),
              );
            },
          ),
        ),
      );

      // Limpiar campo de monto
      _rechargeAmountController.clear();
      setState(() {});

      // The MercadoPago webhook handles wallet balance updates
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Cerrar diálogo de carga si todavía está abierto

      if (!mounted) return;

      String errorMessage = 'No se pudo iniciar la recarga. Intenta nuevamente.';
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('network') || errorStr.contains('conexión')) {
        errorMessage = 'Error de conexión. Verifica tu internet e intenta nuevamente.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: ModernTheme.error,
          duration: Duration(seconds: 5),
        ),
      );

      debugPrint('Error en _processRecharge: $e');
    }
  }
}

// Modelo de transacción
enum TransactionType { tripEarning, withdrawal, bonus, penalty }

class Transaction {
  final String id;
  final TransactionType type;
  final double amount;
  final DateTime date;
  final String description;
  final String? passenger;
  final String status;
  final double? commission;
  
  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.description,
    this.passenger,
    required this.status,
    this.commission,
  });
}

// Painter para el gráfico de ganancias
class EarningsChartPainter extends CustomPainter {
  final Animation<double> animation;
  final List<double> weeklyEarnings; // ✅ NUEVO: datos reales desde Firebase
  final Color textColor;
  final Color primaryTextColor;

  const EarningsChartPainter({
    super.repaint,
    required this.animation,
    required this.weeklyEarnings, // ✅ NUEVO: parámetro requerido
    required this.textColor,
    required this.primaryTextColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ModernTheme.rappiOrange
      ..style = PaintingStyle.fill;

    // ✅ FIX: Usar datos reales pasados como parámetro
    final data = weeklyEarnings.isNotEmpty ? weeklyEarnings : [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    final days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    final barWidth = size.width / (data.length * 2);

    for (int i = 0; i < data.length; i++) {
      final barHeight = size.height * 0.8 * data[i] * animation.value;
      final x = i * (barWidth * 2) + barWidth / 2;
      final y = size.height * 0.8 - barHeight;

      // Barra
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        Radius.circular(4),
      );

      // Gradiente
      paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          ModernTheme.rappiOrange,
          ModernTheme.rappiOrange.withValues(alpha: 0.6),
        ],
      ).createShader(rect.outerRect);

      canvas.drawRRect(rect, paint);

      // Etiqueta del día
      final textPainter = TextPainter(
        text: TextSpan(
          text: days[i],
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x + barWidth / 2 - textPainter.width / 2, size.height * 0.85),
      );

      // Valor
      final valuePainter = TextPainter(
        text: TextSpan(
          text: CurrencyFormatter.formatCurrency((data[i] * 100).toDouble(), decimals: 0),
          style: TextStyle(
            color: primaryTextColor,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      valuePainter.layout();
      valuePainter.paint(
        canvas,
        Offset(x + barWidth / 2 - valuePainter.width / 2, y - 15),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}