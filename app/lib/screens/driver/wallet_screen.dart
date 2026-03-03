import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';

import '../../core/design/design_system.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_loading_state.dart';
import '../../core/widgets/rt_card.dart';
import '../../core/widgets/rt_button.dart';
import '../../core/widgets/rt_section_header.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../core/widgets/rt_empty_state.dart';
import '../../core/utils/currency_formatter.dart';
import '../../services/payment_service.dart';
import '../../utils/firestore_error_handler.dart';
import '../../widgets/izypay_checkout_widget.dart';
import '../../core/widgets/rt_animated_widgets.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with TickerProviderStateMixin {
  late AnimationController _balanceController;
  late AnimationController _cardsController;
  late AnimationController _transactionsController;
  late TabController _tabController;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PaymentService _paymentService = PaymentService();

  // Balance desde Firebase (coleccion wallets)
  double _currentBalance = 0.0;
  bool _isBalanceLoaded = false;
  final double _weeklyEarnings = 0.0;
  final double _monthlyEarnings = 0.0;

  // Ganancias semanales para el grafico (7 dias: L, M, M, J, V, S, D)
  final List<double> _weeklyEarningsChart = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

  // Método de retiro seleccionado
  String _selectedWithdrawalMethod = 'bank';
  final TextEditingController _withdrawalAmountController = TextEditingController();

  // Controlador para recarga de saldo
  final TextEditingController _rechargeAmountController = TextEditingController();

  // Transacciones reales desde Firebase (inicialmente vacio)
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
      'avgPerTrip': totalTrips > 0 ? _weeklyEarnings / totalTrips : 0.0,
    };
  }

  @override
  void initState() {
    super.initState();

    _balanceController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..forward();

    _cardsController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _transactionsController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..forward();

    _tabController = TabController(length: 4, vsync: this);

    // Inicializar servicio de pagos
    _initializePaymentService();
  }

  Future<void> _initializePaymentService() async {
    try {
      await _paymentService.initialize(isProduction: true);
    } catch (e) {
      debugPrint('Error inicializando PaymentService: $e');
    }
  }

  @override
  void dispose() {
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
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: RtAppBar(
          title: 'Mi Billetera',
          variant: RtAppBarVariant.gradient,
        ),
        body: const Center(
          child: Text('Usuario no autenticado'),
        ),
      );
    }

    // Escuchar cambios de créditos desde la coleccion wallets
    _firestore.collection('wallets').doc(user.uid).snapshots().listen((snapshot) {
      if (mounted) {
        if (snapshot.exists) {
          final walletData = snapshot.data();
          if (walletData != null) {
            final newBalance = (walletData['serviceCredits'] as num?)?.toDouble() ?? 0.0;

            // Solo actualizar si el balance cambio
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
          // Wallet no existe aun, mostrar 0
          if (!_isBalanceLoaded) {
            setState(() => _isBalanceLoaded = true);
          }
        }
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: RtAppBar(
        title: 'Mi Billetera',
        variant: RtAppBarVariant.gradient,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: RtColors.white),
            onPressed: _showHelp,
          ),
        ],
      ),
      body: Column(
        children: [
          // Balance card animado
          AnimatedBuilder(
            animation: _balanceController,
            builder: (context, child) {
              return Transform.scale(
                scale: 0.8 + (0.2 * _balanceController.value),
                child: Opacity(
                  opacity: _balanceController.value,
                  child: _buildBalanceCard(),
                ),
              );
            },
          ),

          // Tabs con RtTabBar no aplica directamente porque necesita TabController
          // Se usa TabBar con estilos del design system
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: RtColors.neutral200,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: RtColors.brand,
              unselectedLabelColor: RtColors.neutral500,
              indicatorColor: RtColors.brand,
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: RtTypo.labelLarge.copyWith(fontWeight: FontWeight.w700),
              unselectedLabelStyle: RtTypo.labelLarge,
              splashFactory: NoSplash.splashFactory,
              overlayColor: WidgetStateProperty.all(RtColors.transparent),
              dividerColor: RtColors.transparent,
              tabs: const [
                Tab(text: 'Resumen'),
                Tab(text: 'Transacciones'),
                Tab(text: 'Recargar'),
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
      margin: const EdgeInsets.all(RtSpacing.base),
      padding: const EdgeInsets.all(RtSpacing.lg),
      decoration: BoxDecoration(
        gradient: RtGradients.brand,
        borderRadius: RtRadius.borderLg,
        boxShadow: RtShadow.brand(),
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
                    style: RtTypo.bodyMedium.copyWith(
                      color: RtColors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: RtSpacing.sm),
                  AnimatedBuilder(
                    animation: _balanceController,
                    builder: (context, child) {
                      final displayBalance = _currentBalance * _balanceController.value;
                      return Text(
                        CurrencyFormatter.formatCurrency(displayBalance),
                        style: RtTypo.displayLarge.copyWith(
                          color: RtColors.white,
                        ),
                      );
                    },
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(RtSpacing.md),
                decoration: BoxDecoration(
                  color: RtColors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: RtColors.white,
                  size: 30,
                ),
              ),
            ],
          ),

          const SizedBox(height: RtSpacing.lg),

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
                color: RtColors.white.withValues(alpha: 0.24),
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
        Icon(icon, color: RtColors.white.withValues(alpha: 0.7), size: 20),
        const SizedBox(height: RtSpacing.xs),
        Text(
          value,
          style: RtTypo.headingSmall.copyWith(color: RtColors.white),
        ),
        Text(
          label,
          style: RtTypo.bodySmall.copyWith(
            color: RtColors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryTab() {
    // Mostrar shimmer stats mientras no se cargue el balance
    if (!_isBalanceLoaded) {
      return const Padding(
        padding: EdgeInsets.all(RtSpacing.base),
        child: RtLoadingState.stats(),
      );
    }

    final stats = _statistics;

    return AnimatedBuilder(
      animation: _cardsController,
      builder: (context, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(RtSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RtSectionHeader(
                title: 'Estadísticas del Día',
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: RtSpacing.base),

              // Grid de estadísticas
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: RtSpacing.base,
                crossAxisSpacing: RtSpacing.base,
                childAspectRatio: 1.5,
                children: [
                  _buildStatCard(
                    'Ganancias Hoy',
                    CurrencyFormatter.formatCurrency(stats['todayEarnings'] as double),
                    Icons.today,
                    RtColors.success,
                    0,
                  ),
                  _buildStatCard(
                    'Viajes Completados',
                    '${stats['totalTrips']}',
                    Icons.directions_car,
                    RtColors.info,
                    1,
                  ),
                  _buildStatCard(
                    'Comisión Total',
                    CurrencyFormatter.formatCurrency(stats['totalCommission'] as double),
                    Icons.receipt,
                    RtColors.warning,
                    2,
                  ),
                  _buildStatCard(
                    'Promedio/Viaje',
                    CurrencyFormatter.formatCurrency(stats['avgPerTrip'] as double),
                    Icons.analytics,
                    RtColors.info,
                    3,
                  ),
                ],
              ),

              const SizedBox(height: RtSpacing.xl),

              // Grafico de ganancias
              RtSectionHeader(
                title: 'Ganancias de la Semana',
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: RtSpacing.base),

              Container(
                height: 200,
                padding: const EdgeInsets.all(RtSpacing.base),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: RtRadius.borderMd,
                  boxShadow: RtShadow.soft(),
                ),
                child: CustomPaint(
                  painter: EarningsChartPainter(
                    animation: _cardsController,
                    weeklyEarnings: _weeklyEarningsChart,
                    textColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    primaryTextColor: Theme.of(context).colorScheme.onSurface,
                  ),
                  child: Container(),
                ),
              ),

              const SizedBox(height: RtSpacing.xl),

              // Metas y objetivos
              RtSectionHeader(
                title: 'Metas del Mes',
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: RtSpacing.base),

              _buildGoalCard(
                'Meta de Ganancias',
                _monthlyEarnings,
                3000.00,
                RtColors.brand,
              ),
              const SizedBox(height: RtSpacing.md),
              _buildGoalCard(
                'Viajes Completados',
                stats['totalTrips'],
                150,
                RtColors.info,
              ),
              const SizedBox(height: RtSpacing.md),
              _buildGoalCard(
                'Calificación Promedio',
                0.0,
                5.0,
                RtColors.warning,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransactionsTab() {
    // Mostrar mensaje si no hay transacciones
    if (_transactions.isEmpty) {
      return Center(
        child: RtEmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'No hay transacciones aun',
          description: 'Tus viajes y retiros aparecerán aquí',
        ),
      );
    }

    return AnimatedBuilder(
      animation: _transactionsController,
      builder: (context, child) {
        return Column(
          children: [
            // Boton de exportar transacciones
            Padding(
              padding: const EdgeInsets.fromLTRB(
                RtSpacing.base, RtSpacing.base, RtSpacing.base, RtSpacing.sm,
              ),
              child: RtButton(
                label: 'Exportar Transacciones',
                icon: Icons.download,
                onPressed: _exportTransactions,
              ),
            ),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(RtSpacing.base),
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
      padding: const EdgeInsets.all(RtSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Información sobre recarga
          Container(
            padding: const EdgeInsets.all(RtSpacing.base),
            decoration: BoxDecoration(
              color: RtColors.infoLight,
              borderRadius: RtRadius.borderMd,
              border: Border.all(
                color: RtColors.info.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: RtColors.info),
                const SizedBox(width: RtSpacing.md),
                Expanded(
                  child: Text(
                    'Recarga tu billetera para aceptar viajes y recibir pagos',
                    style: RtTypo.bodySmall.copyWith(color: RtColors.neutral600),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: RtSpacing.xl),

          // Balance actual
          Container(
            padding: const EdgeInsets.all(RtSpacing.base),
            decoration: BoxDecoration(
              color: RtColors.brandSurface,
              borderRadius: RtRadius.borderMd,
              border: Border.all(
                color: RtColors.brand.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: RtColors.brand),
                const SizedBox(width: RtSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Balance actual',
                      style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500),
                    ),
                    Text(
                      CurrencyFormatter.formatCurrency(_currentBalance),
                      style: RtTypo.displaySmall.copyWith(color: RtColors.brand),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: RtSpacing.xl),

          // Monto a recargar
          Text(
            'Monto a Recargar',
            style: RtTypo.titleLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: RtSpacing.md),

          TextField(
            controller: _rechargeAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.add_circle, color: RtColors.brand),
              hintText: '0.00',
              border: OutlineInputBorder(
                borderRadius: RtRadius.borderMd,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: RtRadius.borderMd,
                borderSide: const BorderSide(color: RtColors.brand, width: 2),
              ),
            ),
            style: RtTypo.headingMedium,
          ),

          const SizedBox(height: RtSpacing.md),

          // Botones rápidos de monto
          Wrap(
            spacing: RtSpacing.sm,
            children: [20, 50, 100, 200].map((amount) {
              return ActionChip(
                label: Text(CurrencyFormatter.formatCurrency(amount.toDouble(), decimals: 0)),
                onPressed: () {
                  setState(() {
                    _rechargeAmountController.text = amount.toString();
                  });
                },
                backgroundColor: Theme.of(context).colorScheme.surface,
              );
            }).toList(),
          ),

          const SizedBox(height: RtSpacing.xl),

          // Vista previa del monto total después de recarga
          RtCard(
            variant: RtCardVariant.outlined,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Balance actual:',
                      style: RtTypo.bodyMedium.copyWith(color: RtColors.neutral500),
                    ),
                    Text(
                      CurrencyFormatter.formatCurrency(_currentBalance),
                      style: RtTypo.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: RtSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Monto a recargar:',
                      style: RtTypo.bodyMedium.copyWith(color: RtColors.neutral500),
                    ),
                    Text(
                      CurrencyFormatter.formatCurrency(
                        double.tryParse(_rechargeAmountController.text) ?? 0.0,
                      ),
                      style: RtTypo.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: RtColors.brand,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Nuevo balance:',
                      style: RtTypo.titleLarge.copyWith(fontWeight: FontWeight.w600),
                    ),
                    _isBalanceLoaded
                        ? Text(
                            CurrencyFormatter.formatCurrency(
                              _currentBalance + (double.tryParse(_rechargeAmountController.text) ?? 0.0),
                            ),
                            style: RtTypo.headingMedium.copyWith(color: RtColors.brand),
                          )
                        : const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: RtSpacing.xl),

          // Boton de recarga con Izypay
          RtButton(
            label: 'Recargar Saldo',
            icon: Icons.payment,
            onPressed: _processRecharge,
            size: RtButtonSize.large,
          ),

          const SizedBox(height: RtSpacing.base),

          // Información importante
          Container(
            padding: const EdgeInsets.all(RtSpacing.base),
            decoration: BoxDecoration(
              color: RtColors.brand.withValues(alpha: 0.08),
              borderRadius: RtRadius.borderMd,
              border: Border.all(
                color: RtColors.brand.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline, size: 20, color: RtColors.brand),
                const SizedBox(width: RtSpacing.md),
                Expanded(
                  child: Text(
                    '- La recarga es inmediata\n'
                    '- Se acepta tarjetas de crédito/débito\n'
                    '- Transacción segura con Izypay\n'
                    '- Monto mínimo: S/ 10.00',
                    style: RtTypo.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
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
      padding: const EdgeInsets.all(RtSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance disponible
          Container(
            padding: const EdgeInsets.all(RtSpacing.base),
            decoration: BoxDecoration(
              color: RtColors.brandSurface,
              borderRadius: RtRadius.borderMd,
              border: Border.all(
                color: RtColors.brand.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: RtColors.brand),
                const SizedBox(width: RtSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Disponible para retirar',
                      style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500),
                    ),
                    Text(
                      CurrencyFormatter.formatCurrency(_currentBalance),
                      style: RtTypo.displaySmall.copyWith(color: RtColors.brand),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: RtSpacing.xl),

          // Monto a retirar
          Text(
            'Monto a Retirar',
            style: RtTypo.titleLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: RtSpacing.md),

          TextField(
            controller: _withdrawalAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.account_balance_wallet, color: RtColors.brand),
              hintText: '0.00',
              border: OutlineInputBorder(
                borderRadius: RtRadius.borderMd,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: RtRadius.borderMd,
                borderSide: const BorderSide(color: RtColors.brand, width: 2),
              ),
            ),
            style: RtTypo.headingMedium,
          ),

          const SizedBox(height: RtSpacing.md),

          // Botones rápidos de monto
          Wrap(
            spacing: RtSpacing.sm,
            children: [50, 100, 200, 500].map((amount) {
              return ActionChip(
                label: Text(CurrencyFormatter.formatCurrency(amount.toDouble(), decimals: 0)),
                onPressed: () {
                  setState(() {
                    _withdrawalAmountController.text = amount.toString();
                  });
                },
                backgroundColor: Theme.of(context).colorScheme.surface,
              );
            }).toList(),
          ),

          const SizedBox(height: RtSpacing.xl),

          // Método de retiro
          Text(
            'Método de Retiro',
            style: RtTypo.titleLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: RtSpacing.md),

          // Solo cuenta bancaria - Unica opcion real implementada
          _buildWithdrawalMethod(
            'bank',
            'Transferencia Bancaria',
            'Procesa en 1-2 días hábiles',
            Icons.account_balance,
          ),

          const SizedBox(height: RtSpacing.xl),

          // Información importante
          Container(
            padding: const EdgeInsets.all(RtSpacing.md),
            decoration: BoxDecoration(
              color: RtColors.warningLight,
              borderRadius: RtRadius.borderMd,
              border: Border.all(
                color: RtColors.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: RtColors.warning, size: 20),
                const SizedBox(width: RtSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Información Importante',
                        style: RtTypo.titleMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: RtColors.warningDark,
                        ),
                      ),
                      const SizedBox(height: RtSpacing.xs),
                      Text(
                        '- Solo transferencia bancaria disponible\n'
                        '- Los retiros se procesan en 1-2 días hábiles\n'
                        '- Monto mínimo de retiro: ${CurrencyFormatter.formatCurrency(20.0)}\n'
                        '- Sin comisiones por retiro\n'
                        '- Procesado via MercadoPago Money Out',
                        style: RtTypo.bodySmall.copyWith(color: RtColors.neutral600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: RtSpacing.xl),

          // Boton de retirar
          AnimatedPulseButton(
            text: 'Solicitar Retiro',
            icon: Icons.send,
            onPressed: _processWithdrawal,
            color: RtColors.brand,
          ),

          const SizedBox(height: RtSpacing.xl),

          // Historial de retiros
          RtSectionHeader(
            title: 'Retiros Recientes',
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: RtSpacing.md),

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
            padding: const EdgeInsets.all(RtSpacing.md),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: RtRadius.borderMd,
              boxShadow: RtShadow.soft(),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: RtTypo.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: RtTypo.labelSmall.copyWith(color: RtColors.neutral500),
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

    return RtCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: RtTypo.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: RtTypo.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: RtSpacing.sm),
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
                duration: const Duration(milliseconds: 800),
                height: 8,
                width: MediaQuery.of(context).size.width * progress * 0.8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          const SizedBox(height: RtSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                current is double
                  ? CurrencyFormatter.formatCurrency(current)
                  : current.toString(),
                style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500),
              ),
              Text(
                goal is double
                  ? CurrencyFormatter.formatCurrency(goal)
                  : goal.toString(),
                style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500),
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

    return RtCard(
      margin: const EdgeInsets.only(bottom: RtSpacing.md),
      onTap: () => _showTransactionDetails(transaction),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: RtIconSize.md),
          ),
          const SizedBox(width: RtSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: RtTypo.titleMedium.copyWith(fontWeight: FontWeight.w600),
                ),
                if (transaction.passenger != null)
                  Text(
                    transaction.passenger!,
                    style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500),
                  ),
                Text(
                  _formatDate(transaction.date),
                  style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isEarning ? '+' : '-'}${CurrencyFormatter.formatCurrency(transaction.amount.abs())}',
                style: RtTypo.titleLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isEarning ? RtColors.success : RtColors.error,
                ),
              ),
              if (transaction.commission != null)
                Text(
                  'Comisión: ${CurrencyFormatter.formatCurrency(transaction.commission!)}',
                  style: RtTypo.labelSmall.copyWith(color: RtColors.neutral500),
                ),
            ],
          ),
        ],
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
      borderRadius: RtRadius.borderMd,
      child: Container(
        padding: const EdgeInsets.all(RtSpacing.base),
        decoration: BoxDecoration(
          color: isSelected
            ? RtColors.brand.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.surface,
          borderRadius: RtRadius.borderMd,
          border: Border.all(
            color: isSelected ? RtColors.brand : RtColors.neutral200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? RtColors.brand : RtColors.neutral500,
            ),
            const SizedBox(width: RtSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: RtTypo.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                        ? RtColors.brand
                        : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500),
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? RtColors.brand : RtColors.neutral400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: RtColors.brand,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWithdrawalHistoryItem(Transaction transaction) {
    return Container(
      margin: const EdgeInsets.only(bottom: RtSpacing.sm),
      padding: const EdgeInsets.all(RtSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: RtRadius.borderMd,
      ),
      child: Row(
        children: [
          Icon(
            Icons.history,
            color: RtColors.neutral500,
            size: RtIconSize.sm,
          ),
          const SizedBox(width: RtSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: RtTypo.bodyMedium,
                ),
                Text(
                  _formatDate(transaction.date),
                  style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500),
                ),
              ],
            ),
          ),
          Text(
            CurrencyFormatter.formatCurrency(transaction.amount.abs()),
            style: RtTypo.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
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
        return RtColors.success;
      case TransactionType.withdrawal:
        return RtColors.info;
      case TransactionType.bonus:
        return Theme.of(context).colorScheme.secondary;
      case TransactionType.penalty:
        return RtColors.error;
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
      return 'Hace ${difference.inDays}días';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  void _showTransactionDetails(Transaction transaction) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: RtRadius.sheetTop,
        ),
        padding: const EdgeInsets.all(RtSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: RtColors.neutral300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: RtSpacing.lg),
            Text(
              'Detalles de la Transacción',
              style: RtTypo.headingMedium,
            ),
            const SizedBox(height: RtSpacing.lg),
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
            const SizedBox(height: RtSpacing.lg),
            RtButton(
              label: 'Cerrar',
              variant: RtButtonVariant.outlined,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: RtTypo.bodyMedium.copyWith(color: RtColors.neutral500),
          ),
          Text(
            value,
            style: RtTypo.bodyMedium.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Future<void> _processWithdrawal() async {
    final amount = double.tryParse(_withdrawalAmountController.text) ?? 0;

    if (amount < 50) {
      RtSnackbar.show(
        context,
        message: 'El monto mínimo de retiro es ${CurrencyFormatter.formatCurrency(50.0)}',
        type: RtSnackbarType.error,
      );
      return;
    }

    if (amount > _currentBalance) {
      RtSnackbar.show(
        context,
        message: 'Saldo insuficiente',
        type: RtSnackbarType.error,
      );
      return;
    }

    // Obtener datos bancarios del conductor
    final bankData = await _showBankAccountDialog();
    if (bankData == null) return;
    if (!mounted) return;

    // Mostrar dialogo de confirmación
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.account_balance, color: RtColors.brand, size: 22),
            const SizedBox(width: RtSpacing.sm),
            const Expanded(
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
            const Text('Estas a punto de retirar:'),
            const SizedBox(height: RtSpacing.md),
            Container(
              padding: const EdgeInsets.all(RtSpacing.md),
              decoration: BoxDecoration(
                color: RtColors.brand.withValues(alpha: 0.1),
                borderRadius: RtRadius.borderSm,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Monto:'),
                      Text(
                        CurrencyFormatter.formatCurrency(amount),
                        style: RtTypo.headingMedium.copyWith(color: RtColors.brand),
                      ),
                    ],
                  ),
                  const Divider(height: RtSpacing.base),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Banco:'),
                      Text(bankData['bankName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: RtSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Cuenta:'),
                      Text('***${(bankData['bankAccount'] ?? '').substring((bankData['bankAccount'] ?? '').length - 4)}'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: RtSpacing.md),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: RtColors.info),
                const SizedBox(width: RtSpacing.xs),
                Expanded(
                  child: Text(
                    'El retiro se procesará en 1-2 días hábiles',
                    style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(decoration: TextDecoration.none),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: RtColors.brand),
            child: const Text(
              'Confirmar',
              style: TextStyle(decoration: TextDecoration.none),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    // Mostrar dialogo de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(RtSpacing.xl),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: RtRadius.borderMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: RtColors.brand),
              const SizedBox(height: RtSpacing.base),
              const Text('Procesando retiro...'),
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
        method: 'bank_transfer',
        bankName: bankData['bankName'] ?? '',
        accountNumber: bankData['bankAccount'] ?? '',
        accountHolderName: bankData['accountHolderName'] ?? '',
        accountHolderDocumentType: bankData['documentType'] ?? 'DNI',
        accountHolderDocumentNumber: bankData['documentNumber'] ?? '',
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (!withdrawalResult.success) {
        throw Exception(withdrawalResult.error ?? 'Error desconocido al procesar retiro');
      }

      if (!mounted) return;
      RtSnackbar.show(
        context,
        message: 'Retiro solicitado exitosamente. Se procesará en 1-2 días hábiles.',
        type: RtSnackbarType.success,
      );

      // Limpiar campo de monto
      _withdrawalAmountController.clear();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

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

      RtSnackbar.show(
        context,
        message: errorMessage,
        type: RtSnackbarType.error,
      );

      debugPrint('Error en _processWithdrawal: $e');
    }
  }

  /// Mostrar dialogo para ingresar datos bancarios
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
          title: const Text('Datos de Cuenta Bancaria'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: accountHolderController,
                  decoration: const InputDecoration(
                    labelText: 'Titular de la Cuenta',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: RtSpacing.md),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: documentType,
                        decoration: InputDecoration(
                          labelText: 'Tipo Doc.',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          isDense: true,
                        ),
                        style: RtTypo.bodySmall.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        items: [
                          DropdownMenuItem(value: 'DNI', child: Text('DNI', style: RtTypo.bodySmall)),
                          DropdownMenuItem(value: 'CE', child: Text('C.E.', style: RtTypo.bodySmall)),
                        ],
                        onChanged: (value) {
                          setState(() {
                            documentType = value!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: RtSpacing.sm),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: documentNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Número',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: RtSpacing.md),
                TextField(
                  controller: bankNameController,
                  decoration: const InputDecoration(
                    labelText: 'Banco',
                    border: OutlineInputBorder(),
                    hintText: 'Ej: BCP, Interbank, BBVA',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: RtSpacing.md),
                TextField(
                  controller: bankAccountController,
                  decoration: const InputDecoration(
                    labelText: 'Número de Cuenta',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: RtSpacing.md),
                Container(
                  padding: const EdgeInsets.all(RtSpacing.sm),
                  decoration: BoxDecoration(
                    color: RtColors.infoLight,
                    borderRadius: RtRadius.borderSm,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: RtColors.info),
                      const SizedBox(width: RtSpacing.sm),
                      Expanded(
                        child: Text(
                          'Verifica que los datos sean correctos',
                          style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500),
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
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                // Validar campos
                if (accountHolderController.text.isEmpty ||
                    documentNumberController.text.isEmpty ||
                    bankNameController.text.isEmpty ||
                    bankAccountController.text.isEmpty) {
                  RtSnackbar.show(
                    context,
                    message: 'Por favor completa todos los campos',
                    type: RtSnackbarType.error,
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
              style: ElevatedButton.styleFrom(backgroundColor: RtColors.brand),
              child: const Text('Continuar'),
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

  // Exportar transacciones
  void _exportTransactions() async {
    try {
      // Mostrar dialogo para elegir formato
      final format = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Exportar Transacciones'),
          content: const Text('En qué formato deseas exportar las transacciones?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'csv'),
              child: const Text('CSV'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'pdf'),
              child: const Text('PDF'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
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
    } catch (e) {
      if (!mounted) return;
      RtSnackbar.show(
        context,
        message: FirestoreErrorHandler.getSpanishMessage(e),
        type: RtSnackbarType.error,
      );
    }
  }

  String _generateTransactionsData() {
    final buffer = StringBuffer();
    buffer.writeln('HISTORIAL DE TRANSACCIONES - RAPITEAM');
    buffer.writeln('Fecha de generacion: ${DateTime.now().toString().split('.')[0]}');
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
      final List<List<dynamic>> csvData = [
        ['HISTORIAL DE TRANSACCIONES - RAPITEAM'],
        ['Fecha de generacion', DateTime.now().toString().split('.')[0]],
        [],
        ['RESUMEN'],
        ['Metrica', 'Valor'],
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

      String csvString = const ListToCsvConverter().convert(csvData);
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/transacciones_rapiteam_$timestamp.csv';
      final file = File(filePath);
      await file.writeAsString(csvString);

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Historial de Transacciones - RapiTeam',
        text: 'Historial de transacciones generado el ${DateTime.now().toString().split('.')[0]}',
      );

      if (!mounted) return;
      RtSnackbar.show(
        context,
        message: 'Archivo CSV generado exitosamente',
        type: RtSnackbarType.success,
      );
    } catch (e) {
      if (!mounted) return;
      RtSnackbar.show(
        context,
        message: FirestoreErrorHandler.getSpanishMessage(e),
        type: RtSnackbarType.error,
      );
    }
  }

  Future<void> _exportToPDF(String data) async {
    try {
      final fontRegular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final fontBold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      final ttfRegular = pw.Font.ttf(fontRegular);
      final ttfBold = pw.Font.ttf(fontBold);

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#E31E24'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'HISTORIAL DE TRANSACCIONES',
                      style: pw.TextStyle(font: ttfBold, color: PdfColors.white, fontSize: 24),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'RAPITEAM',
                      style: pw.TextStyle(font: ttfRegular, color: PdfColors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Fecha de generacion: ${DateTime.now().toString().split('.')[0]}',
                style: pw.TextStyle(font: ttfRegular, fontSize: 12),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'RESUMEN',
                style: pw.TextStyle(font: ttfBold, fontSize: 16),
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
              pw.Text(
                'DETALLE DE TRANSACCIONES',
                style: pw.TextStyle(font: ttfBold, fontSize: 16),
              ),
              pw.SizedBox(height: 10),
              if (_transactions.isEmpty)
                pw.Text('No hay transacciones registradas', style: pw.TextStyle(font: ttfRegular, fontSize: 12))
              else
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(1.5),
                    2: const pw.FlexColumnWidth(1),
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColor.fromHex('#E31E24')),
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

      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/transacciones_rapiteam_$timestamp.pdf';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Historial de Transacciones - RapiTeam',
        text: 'Historial de transacciones generado el ${DateTime.now().toString().split('.')[0]}',
      );

      if (!mounted) return;
      RtSnackbar.show(
        context,
        message: 'Archivo PDF generado exitosamente',
        type: RtSnackbarType.success,
      );
    } catch (e) {
      if (!mounted) return;
      RtSnackbar.show(
        context,
        message: FirestoreErrorHandler.getSpanishMessage(e),
        type: RtSnackbarType.error,
      );
    }
  }

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
        style: pw.TextStyle(font: font, color: PdfColors.white, fontSize: 10),
      ),
    );
  }

  pw.Widget _buildPdfTransactionCell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 9)),
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: RtRadius.borderLg,
        ),
        title: const Text('Ayuda - Billetera'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cómo funciona tu billetera:',
                style: RtTypo.titleMedium.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: RtSpacing.sm),
              Text(
                '- Las ganancias se acumulan después de cada viaje\n'
                '- Puedes retirar cuando tengas mínimo ${CurrencyFormatter.formatCurrency(10.0)}\n'
                '- Los retiros se procesan en 1-2 días hábiles\n'
                '- No hay comisiones por retiro\n'
                '- Revisa tus estadísticas para mejorar tus ganancias',
                style: RtTypo.bodyMedium,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  // Procesar recarga de saldo con MercadoPago
  Future<void> _processRecharge() async {
    final amount = double.tryParse(_rechargeAmountController.text);

    if (amount == null || amount <= 0) {
      RtSnackbar.show(
        context,
        message: 'Por favor ingresa un monto válido',
        type: RtSnackbarType.error,
      );
      return;
    }

    if (amount < 10) {
      RtSnackbar.show(
        context,
        message: 'El monto mínimo de recarga es S/ 10.00',
        type: RtSnackbarType.error,
      );
      return;
    }

    // Mostrar dialogo de confirmación
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.payment, color: RtColors.brand, size: 22),
            const SizedBox(width: RtSpacing.sm),
            const Expanded(
              child: Text(
                'Confirmar Recarga',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(decoration: TextDecoration.none),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estas a punto de recargar:',
              style: TextStyle(decoration: TextDecoration.none),
            ),
            const SizedBox(height: RtSpacing.md),
            Container(
              padding: const EdgeInsets.all(RtSpacing.md),
              decoration: BoxDecoration(
                color: RtColors.brand.withValues(alpha: 0.1),
                borderRadius: RtRadius.borderSm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Monto:',
                    style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.none),
                  ),
                  Text(
                    CurrencyFormatter.formatCurrency(amount),
                    style: RtTypo.headingMedium.copyWith(
                      color: RtColors.brand,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: RtSpacing.md),
            Text(
              'Nuevo balance sera:',
              style: RtTypo.bodySmall.copyWith(
                color: RtColors.neutral500,
                decoration: TextDecoration.none,
              ),
            ),
            Text(
              CurrencyFormatter.formatCurrency(_currentBalance + amount),
              style: RtTypo.headingSmall.copyWith(
                color: RtColors.brand,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: RtSpacing.md),
            Container(
              padding: const EdgeInsets.all(RtSpacing.md),
              decoration: BoxDecoration(
                color: RtColors.brand.withValues(alpha: 0.1),
                borderRadius: RtRadius.borderSm,
              ),
              child: Row(
                children: [
                  const Icon(Icons.security, size: 18, color: RtColors.brand),
                  const SizedBox(width: RtSpacing.sm),
                  Expanded(
                    child: Text(
                      'Pago seguro procesado por Izypay',
                      style: RtTypo.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
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
            child: const Text(
              'Cancelar',
              style: TextStyle(decoration: TextDecoration.none),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: RtColors.brand),
            child: const Text(
              'Confirmar',
              style: TextStyle(decoration: TextDecoration.none),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    // Mostrar dialogo de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(RtSpacing.xxl),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: RtRadius.borderLg,
            boxShadow: RtShadow.medium(),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(RtSpacing.lg),
                decoration: BoxDecoration(
                  gradient: RtGradients.brand,
                  shape: BoxShape.circle,
                  boxShadow: RtShadow.brand(),
                ),
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(RtColors.white),
                    strokeWidth: 3.5,
                  ),
                ),
              ),
              const SizedBox(height: RtSpacing.xl),
              Text(
                'Procesando recarga',
                style: RtTypo.headingSmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: RtSpacing.sm),
              Text(
                'Por favor espera un momento',
                style: RtTypo.bodyMedium.copyWith(
                  color: RtColors.neutral500,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      final userEmail = user.email ?? 'usuario@rapiteam.app';

      // Obtener datos adicionales del usuario para Izipay
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final firstName = userData['firstName'] as String? ?? userData['name'] as String? ?? 'Cliente';
      final lastName = userData['lastName'] as String? ?? 'RapiTeam';
      final phone = userData['phone'] as String? ?? '999999999';

      if (!mounted) return;
      Navigator.pop(context);

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IzypayCheckoutWidget(
            amount: amount,
            description: 'Recarga de saldo RapiTeam',
            payerEmail: userEmail,
            payerFirstName: firstName,
            payerLastName: lastName,
            payerPhone: phone,
            onPaymentComplete: (orderId, paidAmount, status) async {
              final nav = Navigator.of(context);
              final walletProv = Provider.of<WalletProvider>(context, listen: false);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              nav.pop();

              if (status == 'approved') {
                await walletProv.rechargeServiceCredits(
                  amount: amount,
                  paymentMethod: 'izypay_native',
                  paymentId: orderId,
                );

                scaffoldMessenger.showSnackBar(SnackBar(
                  content: Text('Recarga exitosa! Se acreditaron S/. ${amount.toStringAsFixed(2)}'),
                  backgroundColor: RtColors.success,
                ));
              } else if (status == 'error') {
                scaffoldMessenger.showSnackBar(const SnackBar(
                  content: Text('Error al verificar el pago. Contacta soporte si tu tarjeta fue cobrada.'),
                  backgroundColor: RtColors.error,
                ));
              } else {
                scaffoldMessenger.showSnackBar(const SnackBar(
                  content: Text('Pago rechazado. Verifica tu tarjeta e intenta nuevamente.'),
                  backgroundColor: RtColors.error,
                ));
              }
            },
            onCancel: () {
              Navigator.pop(context);

              if (!mounted) return;
              RtSnackbar.show(
                context,
                message: 'Recarga cancelada',
                type: RtSnackbarType.info,
              );
            },
          ),
        ),
      );

      _rechargeAmountController.clear();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      if (!mounted) return;

      String errorMessage = 'No se pudo iniciar la recarga. Intenta nuevamente.';
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('network') || errorStr.contains('conexión')) {
        errorMessage = 'Error de conexión. Verifica tu internet e intenta nuevamente.';
      }

      RtSnackbar.show(
        context,
        message: errorMessage,
        type: RtSnackbarType.error,
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

// Painter para el grafico de ganancias
class EarningsChartPainter extends CustomPainter {
  final Animation<double> animation;
  final List<double> weeklyEarnings;
  final Color textColor;
  final Color primaryTextColor;

  const EarningsChartPainter({
    super.repaint,
    required this.animation,
    required this.weeklyEarnings,
    required this.textColor,
    required this.primaryTextColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = RtColors.brand
      ..style = PaintingStyle.fill;

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
        const Radius.circular(4),
      );

      // Gradiente
      paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          RtColors.brand,
          RtColors.brand.withValues(alpha: 0.6),
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
