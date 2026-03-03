import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/design/design_system.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_button.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../core/utils/currency_formatter.dart';
import '../../utils/firestore_error_handler.dart';

enum TransactionType { trip, withdrawal, commission, refund }
enum PaymentStatus { completed, pending, failed, processing }

class Transaction {
  final String id;
  final TransactionType type;
  final double amount;
  final DateTime date;
  final PaymentStatus status;
  final String description;
  final String? driverId;
  final String? driverName;
  final String? passengerId;
  final String? passengerName;
  final double? commission;
  final String? invoiceNumber;

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.status,
    required this.description,
    this.driverId,
    this.driverName,
    this.passengerId,
    this.passengerName,
    this.commission,
    this.invoiceNumber,
  });
}

class FinancialScreen extends StatefulWidget {
  const FinancialScreen({super.key});

  @override
  State<FinancialScreen> createState() => _FinancialScreenState();
}

class _FinancialScreenState extends State<FinancialScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _chartAnimationController;
  late AnimationController _statsAnimationController;
  
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedPeriod = 'today';
  String _searchQuery = '';
  double _currentCommissionRate = 20.0; // 20% commission
  // ✅ NUEVO: Comisiones por tipo de viaje
  Map<String, double> _commissionRates = {
    'standard': 18.0,
    'premium': 22.0,
    'corporate': 15.0,
  };
  bool _isLoading = true;

  // ✅ Datos financieros reales desde Firebase (se cargan en _loadFinancialData)
  Map<String, double> _financialStats = {
    'totalRevenue': 0.0,
    'totalCommissions': 0.0,
    'pendingPayouts': 0.0,
    'completedPayouts': 0.0,
    'avgTripValue': 0.0,
    'dailyAverage': 0.0,
  };

  // ✅ Transacciones reales desde Firebase (se cargan en _loadFinancialData)
  List<Transaction> _transactions = [];

  // ✅ Pagos pendientes reales desde Firebase (se cargan en _loadFinancialData)
  List<Map<String, dynamic>> _pendingPayouts = [];

  // ✅ NUEVO: Métricas de crecimiento calculadas
  Map<String, dynamic> _growthMetrics = {
    'revenueGrowth': '+0%',
    'commissionRate': '0%',
    'completedPayoutsCount': 0,
    'avgValueGrowth': '+0%',
    'dailyAverageGrowth': '+0%',
  };

  List<Transaction> get _filteredTransactions {
    var filtered = _transactions.where((transaction) {
      if (_searchQuery.isEmpty) return true;
      
      return transaction.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             transaction.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             (transaction.driverName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
             (transaction.passengerName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
             (transaction.invoiceNumber?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();
    
    // Apply tab filter
    switch (_tabController.index) {
      case 1: // Income
        filtered = filtered.where((t) => 
          t.type == TransactionType.trip || t.type == TransactionType.commission).toList();
        break;
      case 2: // Payouts
        filtered = filtered.where((t) => t.type == TransactionType.withdrawal).toList();
        break;
      case 3: // Refunds
        filtered = filtered.where((t) => t.type == TransactionType.refund).toList();
        break;
    }
    
    // Apply period filter
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'today':
        filtered = filtered.where((t) => 
          t.date.year == now.year && 
          t.date.month == now.month && 
          t.date.day == now.day).toList();
        break;
      case 'week':
        final weekAgo = now.subtract(Duration(days: 7));
        filtered = filtered.where((t) => t.date.isAfter(weekAgo)).toList();
        break;
      case 'month':
        filtered = filtered.where((t) => 
          t.date.year == now.year && t.date.month == now.month).toList();
        break;
    }
    
    // Sort by date descending
    filtered.sort((a, b) => b.date.compareTo(a.date));
    
    return filtered;
  }
  
  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 4, vsync: this);
    _chartAnimationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    )..forward();
    _statsAnimationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _statsAnimationController.forward(from: 0);
      }
    });

    // ✅ Cargar datos financieros reales desde Firebase
    _loadFinancialData();
    // ✅ Cargar configuración de comisiones desde Firebase
    _loadCommissionSettings();
  }

  // ✅ NUEVO: Cargar todos los datos financieros desde Firebase
  Future<void> _loadFinancialData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      debugPrint('💰 Cargando datos financieros...');

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      debugPrint('📅 Período de hoy: desde $todayStart');

      // Consultas paralelas para mejor performance
      final results = await Future.wait([
        // ✅ CORREGIDO: Cargar viajes completados (cambiar 'trips' a 'rides')
        _firestore
            .collection('rides')
            .where('status', isEqualTo: 'completed')
            .where('completedAt', isGreaterThanOrEqualTo: todayStart)
            .get()
            .catchError((e) {
          debugPrint('❌ Error obteniendo rides completados: $e');
          throw e;
        }),

        // Cargar retiros pendientes
        _firestore
            .collection('withdrawal_requests')
            .where('status', isEqualTo: 'pending')
            .get()
            .catchError((e) {
          debugPrint('❌ Error obteniendo retiros pendientes: $e');
          throw e;
        }),

        // Cargar retiros completados del mes
        _firestore
            .collection('withdrawal_requests')
            .where('status', isEqualTo: 'completed')
            .where('processedAt', isGreaterThanOrEqualTo: DateTime(now.year, now.month, 1))
            .get()
            .catchError((e) {
          debugPrint('❌ Error obteniendo retiros completados: $e');
          throw e;
        }),
      ]);

      final tripsSnapshot = results[0];
      final pendingWithdrawalsSnapshot = results[1];
      final completedWithdrawalsSnapshot = results[2];

      debugPrint('✅ Datos obtenidos:');
      debugPrint('   🚕 Trips completados: ${tripsSnapshot.docs.length}');
      debugPrint('   ⏳ Retiros pendientes: ${pendingWithdrawalsSnapshot.docs.length}');
      debugPrint('   ✅ Retiros completados: ${completedWithdrawalsSnapshot.docs.length}');

      // Calcular estadísticas financieras
      double totalRevenue = 0.0;
      double totalCommissions = 0.0;
      double pendingPayouts = 0.0;
      double completedPayouts = 0.0;
      int tripCount = 0;

      final List<Transaction> loadedTransactions = [];
      final List<Map<String, dynamic>> loadedPendingPayouts = [];

      // Procesar viajes completados
      for (var tripDoc in tripsSnapshot.docs) {
        final tripData = tripDoc.data();
        final fare = (tripData['finalFare'] ?? tripData['estimatedFare'] ?? 0.0).toDouble();
        final commission = fare * (_currentCommissionRate / 100);

        totalRevenue += fare;
        totalCommissions += commission;
        tripCount++;

        // Agregar transacción de viaje
        loadedTransactions.add(Transaction(
          id: tripDoc.id,
          type: TransactionType.trip,
          amount: fare,
          date: (tripData['completedAt'] as Timestamp).toDate(),
          status: PaymentStatus.completed,
          description: 'Viaje ${tripData['pickupAddress'] ?? ''} → ${tripData['destinationAddress'] ?? ''}',
          driverId: tripData['driverId'],
          driverName: tripData['vehicleInfo']?['driverName'] ?? 'Conductor',
          passengerId: tripData['userId'],
          passengerName: tripData['vehicleInfo']?['passengerName'],
          commission: commission,
        ));

        // Agregar transacción de comisión
        loadedTransactions.add(Transaction(
          id: '${tripDoc.id}_commission',
          type: TransactionType.commission,
          amount: commission,
          date: (tripData['completedAt'] as Timestamp).toDate(),
          status: PaymentStatus.completed,
          description: 'Comisión de viaje',
          driverId: tripData['driverId'],
          driverName: tripData['vehicleInfo']?['driverName'] ?? 'Conductor',
          commission: commission,
        ));
      }

      // Procesar retiros pendientes
      for (var withdrawalDoc in pendingWithdrawalsSnapshot.docs) {
        final withdrawalData = withdrawalDoc.data();
        final amount = (withdrawalData['amount'] ?? 0.0).toDouble();

        pendingPayouts += amount;

        // Agregar a lista de pagos pendientes
        loadedPendingPayouts.add({
          'id': withdrawalDoc.id,
          'driverId': withdrawalData['driverId'],
          'driverName': withdrawalData['driverName'] ?? 'Conductor',
          'amount': amount,
          'trips': withdrawalData['tripsCount'] ?? 0,
          'bank': withdrawalData['bankName'] ?? 'Banco',
          'accountNumber': withdrawalData['accountNumber'] ?? '****',
          'requestDate': (withdrawalData['createdAt'] as Timestamp).toDate(),
        });

        // Agregar transacción pendiente
        loadedTransactions.add(Transaction(
          id: withdrawalDoc.id,
          type: TransactionType.withdrawal,
          amount: amount,
          date: (withdrawalData['createdAt'] as Timestamp).toDate(),
          status: PaymentStatus.pending,
          description: 'Solicitud de retiro',
          driverId: withdrawalData['driverId'],
          driverName: withdrawalData['driverName'] ?? 'Conductor',
        ));
      }

      // Procesar retiros completados
      for (var withdrawalDoc in completedWithdrawalsSnapshot.docs) {
        final withdrawalData = withdrawalDoc.data();
        final amount = (withdrawalData['amount'] ?? 0.0).toDouble();

        completedPayouts += amount;

        // Agregar transacción completada
        loadedTransactions.add(Transaction(
          id: withdrawalDoc.id,
          type: TransactionType.withdrawal,
          amount: amount,
          date: (withdrawalData['processedAt'] as Timestamp).toDate(),
          status: PaymentStatus.completed,
          description: 'Retiro procesado',
          driverId: withdrawalData['driverId'],
          driverName: withdrawalData['driverName'] ?? 'Conductor',
        ));
      }

      // Calcular promedios
      final avgTripValue = tripCount > 0 ? totalRevenue / tripCount : 0.0;
      final dailyAverage = totalRevenue; // Para hoy

      // ✅ NUEVO: Calcular métricas de crecimiento comparando con período anterior
      double revenueGrowthPercent = 0.0;
      double avgValueGrowthPercent = 0.0;
      double dailyAverageGrowthPercent = 0.0;

      try {
        // ✅ CORREGIDO: Obtener datos del mismo período pero de ayer (para comparar)
        final yesterdayStart = todayStart.subtract(Duration(days: 1));
        final yesterdayEnd = todayStart;

        final yesterdayTripsSnapshot = await _firestore
            .collection('rides')
            .where('status', isEqualTo: 'completed')
            .where('completedAt', isGreaterThanOrEqualTo: yesterdayStart)
            .where('completedAt', isLessThan: yesterdayEnd)
            .get();

        double yesterdayRevenue = 0.0;
        int yesterdayTripCount = 0;

        for (var tripDoc in yesterdayTripsSnapshot.docs) {
          final tripData = tripDoc.data();
          final fare = (tripData['finalFare'] ?? tripData['estimatedFare'] ?? 0.0).toDouble();
          yesterdayRevenue += fare;
          yesterdayTripCount++;
        }

        final yesterdayAvgValue = yesterdayTripCount > 0 ? yesterdayRevenue / yesterdayTripCount : 0.0;

        // Calcular porcentajes de crecimiento
        if (yesterdayRevenue > 0) {
          revenueGrowthPercent = ((totalRevenue - yesterdayRevenue) / yesterdayRevenue) * 100;
        }
        if (yesterdayAvgValue > 0) {
          avgValueGrowthPercent = ((avgTripValue - yesterdayAvgValue) / yesterdayAvgValue) * 100;
        }
        if (yesterdayRevenue > 0) {
          dailyAverageGrowthPercent = ((dailyAverage - yesterdayRevenue) / yesterdayRevenue) * 100;
        }
      } catch (e) {
        debugPrint('Error calculando crecimiento: $e');
      }

      // Calcular tasa de comisión promedio
      final commissionRatePercent = totalRevenue > 0 ? (totalCommissions / totalRevenue) * 100 : 0.0;

      // Actualizar estado
      if (!mounted) return;

      setState(() {
        _financialStats = {
          'totalRevenue': totalRevenue,
          'totalCommissions': totalCommissions,
          'pendingPayouts': pendingPayouts,
          'completedPayouts': completedPayouts,
          'avgTripValue': avgTripValue,
          'dailyAverage': dailyAverage,
        };
        _growthMetrics = {
          'revenueGrowth': '${revenueGrowthPercent >= 0 ? '+' : ''}${revenueGrowthPercent.toStringAsFixed(1)}%',
          'commissionRate': '${commissionRatePercent.toStringAsFixed(1)}%',
          'completedPayoutsCount': completedWithdrawalsSnapshot.docs.length,
          'avgValueGrowth': '${avgValueGrowthPercent >= 0 ? '+' : ''}${avgValueGrowthPercent.toStringAsFixed(1)}%',
          'dailyAverageGrowth': '${dailyAverageGrowthPercent >= 0 ? '+' : ''}${dailyAverageGrowthPercent.toStringAsFixed(1)}%',
        };
        _transactions = loadedTransactions;
        _pendingPayouts = loadedPendingPayouts;
        _isLoading = false;
      });

      debugPrint('✅ Finanzas cargadas exitosamente:');
      debugPrint('   💰 Ingresos totales: ${totalRevenue.toStringAsFixed(2)}');
      debugPrint('   🎯 Comisiones: ${totalCommissions.toStringAsFixed(2)}');
      debugPrint('   ⏳ Pagos pendientes: ${pendingPayouts.toStringAsFixed(2)}');
      debugPrint('   ✅ Pagos completados: ${completedPayouts.toStringAsFixed(2)}');
      debugPrint('   📊 ${loadedTransactions.length} transacciones procesadas');

    } catch (e, stackTrace) {
      debugPrint('❌ Error crítico cargando finanzas: $e');
      debugPrint('📍 Stack: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
        RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
      }
    }
  }
  
  // ✅ NUEVO: Cargar configuración de comisiones desde Firebase
  Future<void> _loadCommissionSettings() async {
    try {
      final doc = await _firestore.collection('config').doc('commissions').get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _currentCommissionRate = (data['defaultRate'] ?? 20.0).toDouble();
          _commissionRates = {
            'standard': (data['standard'] ?? 18.0).toDouble(),
            'premium': (data['premium'] ?? 22.0).toDouble(),
            'corporate': (data['corporate'] ?? 15.0).toDouble(),
          };
        });
      }
    } catch (e) {
      debugPrint('Error cargando configuración de comisiones: $e');
    }
  }

  // ✅ NUEVO: Guardar configuración de comisiones en Firebase
  Future<void> _saveCommissionSettings() async {
    try {
      await _firestore.collection('config').doc('commissions').set({
        'defaultRate': _currentCommissionRate,
        'standard': _commissionRates['standard'],
        'premium': _commissionRates['premium'],
        'corporate': _commissionRates['corporate'],
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      RtSnackbar.show(context, message: 'Configuración de comisiones guardada exitosamente', type: RtSnackbarType.success);
    } catch (e) {
      if (!mounted) return;

      RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chartAnimationController.dispose();
    _statsAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RtColors.neutral50,
      appBar: RtAppBar(
        title: 'Control Financiero',
        variant: RtAppBarVariant.gradient,
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: Theme.of(context).colorScheme.onPrimary),
            onPressed: _showCommissionSettings,
          ),
          IconButton(
            icon: Icon(Icons.download, color: Theme.of(context).colorScheme.onPrimary),
            onPressed: _exportFinancialReport,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: RtColors.brand,
          labelColor: RtColors.brand,
          unselectedLabelColor: RtColors.neutral500,
          tabs: [
            Tab(text: 'General'),
            Tab(text: 'Ingresos'),
            Tab(text: 'Pagos'),
            Tab(text: 'Reembolsos'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: RtColors.brand))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildGeneralTab(),
                _buildIncomeTab(),
                _buildPayoutsTab(),
                _buildRefundsTab(),
              ],
            ),
    );
  }
  
  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period selector
          _buildPeriodSelector(),
          
          SizedBox(height: 20),
          
          // Financial stats cards
          AnimatedBuilder(
            animation: _statsAnimationController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, 50 * (1 - _statsAnimationController.value)),
                child: Opacity(
                  opacity: _statsAnimationController.value,
                  child: _buildFinancialStats(),
                ),
              );
            },
          ),
          
          SizedBox(height: 24),
          
          // Revenue chart
          _buildRevenueChart(),
          
          SizedBox(height: 24),
          
          // Commission breakdown
          _buildCommissionBreakdown(),
          
          SizedBox(height: 24),
          
          // Recent transactions
          _buildRecentTransactions(),
        ],
      ),
    );
  }
  
  Widget _buildIncomeTab() {
    return Column(
      children: [
        // Search bar
        Container(
          margin: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Buscar transacción...',
              hintStyle: TextStyle(color: RtColors.neutral500),
              prefixIcon: Icon(Icons.search, color: RtColors.brand),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),
        ),
        
        // Income summary
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [RtColors.success, RtColors.success.withValues(alpha: 0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildIncomeStat('Total Ingresos', _financialStats['totalRevenue']!.toCurrency()),
              Container(width: 1, height: 40, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
              _buildIncomeStat('Comisiones', _financialStats['totalCommissions']!.toCurrency()),
              Container(width: 1, height: 40, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
              _buildIncomeStat('Promedio', _financialStats['avgTripValue']!.toCurrency()),
            ],
          ),
        ),
        
        SizedBox(height: 16),
        
        // Transactions list
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filteredTransactions.where((t) => 
              t.type == TransactionType.trip || t.type == TransactionType.commission).length,
            itemBuilder: (context, index) {
              final incomeTransactions = _filteredTransactions.where((t) => 
                t.type == TransactionType.trip || t.type == TransactionType.commission).toList();
              final transaction = incomeTransactions[index];
              return _buildTransactionCard(transaction);
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildPayoutsTab() {
    return Column(
      children: [
        // Pending payouts header
        Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: RtColors.warning.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: RtColors.warning.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: RtColors.warning),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pagos Pendientes',
                      style: TextStyle(
                        color: RtColors.neutral900,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${_financialStats['pendingPayouts']!.toCurrency()} en ${_pendingPayouts.length} solicitudes',
                      style: TextStyle(color: RtColors.neutral500, fontSize: 14),
                    ),
                  ],
                ),
              ),
              RtButton(
                label: 'Procesar Todos',
                isFullWidth: false,
                onPressed: _processAllPayouts,
              ),
            ],
          ),
        ),
        
        // Pending payouts list
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: _pendingPayouts.length,
            itemBuilder: (context, index) {
              final payout = _pendingPayouts[index];
              return _buildPayoutCard(payout);
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildRefundsTab() {
    // ✅ CALCULAR TOTAL REAL DE REEMBOLSOS desde Firebase
    final refundTransactions = _filteredTransactions.where((t) => t.type == TransactionType.refund).toList();
    final totalRefunds = refundTransactions.fold<double>(0.0, (total, t) => total + t.amount);
    final refundsCount = refundTransactions.length;

    return Column(
      children: [
        // Refunds summary
        Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: RtColors.error.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: RtColors.error.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(Icons.replay, color: RtColors.error, size: 32),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Reembolsos',
                      style: TextStyle(color: RtColors.neutral500, fontSize: 14),
                    ),
                    Text(
                      totalRefunds.toCurrency(),
                      style: TextStyle(
                        color: RtColors.neutral900,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      refundsCount == 0
                        ? 'No hay reembolsos registrados'
                        : '$refundsCount reembolso${refundsCount > 1 ? 's' : ''} registrado${refundsCount > 1 ? 's' : ''}',
                      style: TextStyle(color: RtColors.neutral500.withValues(alpha: 0.7), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Refunds list
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filteredTransactions.where((t) => 
              t.type == TransactionType.refund).length,
            itemBuilder: (context, index) {
              final refundTransactions = _filteredTransactions.where((t) => 
                t.type == TransactionType.refund).toList();
              final transaction = refundTransactions[index];
              return _buildTransactionCard(transaction);
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildPeriodSelector() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildPeriodChip('Hoy', 'today'),
          _buildPeriodChip('Esta Semana', 'week'),
          _buildPeriodChip('Este Mes', 'month'),
          _buildPeriodChip('Este Año', 'year'),
          _buildPeriodChip('Personalizado', 'custom'),
        ],
      ),
    );
  }
  
  Widget _buildPeriodChip(String label, String value) {
    final isSelected = _selectedPeriod == value;
    
    return Container(
      margin: EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: RtColors.brand,
        backgroundColor: Theme.of(context).colorScheme.surface,
        labelStyle: TextStyle(
          color: isSelected ? Theme.of(context).colorScheme.onPrimary : RtColors.neutral500,
        ),
        onSelected: (selected) {
          if (selected) {
            setState(() => _selectedPeriod = value);
            if (value == 'custom') {
              _showDateRangePicker();
            }
          }
        },
      ),
    );
  }
  
  Widget _buildFinancialStats() {
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Ingresos Totales',
          _financialStats['totalRevenue']!.toCurrency(),
          Icons.trending_up,
          RtColors.success,
          _growthMetrics['revenueGrowth'],
        ),
        _buildStatCard(
          'Comisiones',
          _financialStats['totalCommissions']!.toCurrency(),
          Icons.percent,
          RtColors.info,
          _growthMetrics['commissionRate'],
        ),
        _buildStatCard(
          'Pagos Pendientes',
          _financialStats['pendingPayouts']!.toCurrency(),
          Icons.schedule,
          RtColors.warning,
          '${_pendingPayouts.length}',
        ),
        _buildStatCard(
          'Pagos Completados',
          _financialStats['completedPayouts']!.toCurrency(),
          Icons.check_circle,
          RtColors.brand,
          '${_growthMetrics['completedPayoutsCount']}',
        ),
        _buildStatCard(
          'Valor Promedio',
          _financialStats['avgTripValue']!.toCurrency(),
          Icons.analytics,
          RtColors.info,
          _growthMetrics['avgValueGrowth'],
        ),
        _buildStatCard(
          'Promedio Diario',
          _financialStats['dailyAverage']!.toCurrency(),
          Icons.calendar_today,
          RtColors.accentAmber,
          _growthMetrics['dailyAverageGrowth'],
        ),
      ],
    );
  }
  
  Widget _buildStatCard(String title, String value, IconData icon, Color color, String extra) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  extra,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: RtColors.neutral900,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  title,
                  style: TextStyle(
                    color: RtColors.neutral500.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRevenueChart() {
    return Container(
      height: 250,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tendencia de Ingresos',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20),
          Expanded(
            child: AnimatedBuilder(
              animation: _chartAnimationController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: RevenueChartPainter(
                    progress: _chartAnimationController.value,
                    data: [
                      1200, 1500, 1300, 1800, 2100, 1900, 2300,
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['L', 'M', 'M', 'J', 'V', 'S', 'D']
                .map((day) => Text(
                      day,
                      style: TextStyle(color: RtColors.neutral500.withValues(alpha: 0.7), fontSize: 12),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCommissionBreakdown() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Desglose de Comisiones',
                style: TextStyle(
                  color: RtColors.neutral900,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_currentCommissionRate.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: RtColors.brand,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // ✅ DESGLOSE REAL: Mostrar información desde Firebase
          if (_transactions.where((t) => t.type == TransactionType.commission).isNotEmpty)
            ...(_transactions.where((t) => t.type == TransactionType.commission).take(5).map((transaction) =>
              _buildCommissionRow(
                transaction.description,
                _currentCommissionRate,
                transaction.amount,
              )
            ).toList())
          else
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No hay comisiones registradas hoy',
                style: TextStyle(
                  color: RtColors.neutral500,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

          Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2), height: 32),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Comisiones',
                style: TextStyle(
                  color: RtColors.neutral900,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _financialStats['totalCommissions']!.toCurrency(),
                style: TextStyle(
                  color: RtColors.brand,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildCommissionRow(String type, double rate, double amount) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: TextStyle(color: RtColors.neutral900, fontSize: 14),
                ),
                Text(
                  '${rate.toStringAsFixed(0)}% de comisión',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            amount.toCurrency(),
            style: TextStyle(
              color: RtColors.neutral500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRecentTransactions() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transacciones Recientes',
                style: TextStyle(
                  color: RtColors.neutral900,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              RtButton(
                label: 'Ver todas',
                variant: RtButtonVariant.ghost,
                isFullWidth: false,
                onPressed: () {
                  setState(() => _tabController.index = 1);
                },
              ),
            ],
          ),
          SizedBox(height: 16),
          
          ..._transactions.take(5).map((transaction) => 
            _buildTransactionRow(transaction)),
        ],
      ),
    );
  }
  
  Widget _buildTransactionRow(Transaction transaction) {
    final icon = _getTransactionIcon(transaction.type);
    final color = _getTransactionColor(transaction.type);
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: TextStyle(
                    color: RtColors.neutral900,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  transaction.driverName ?? transaction.passengerName ?? 'Sistema',
                  style: TextStyle(
                    color: RtColors.neutral500.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${transaction.type == TransactionType.withdrawal || transaction.type == TransactionType.refund ? '-' : '+'} ${transaction.amount.toCurrency()}',
                style: TextStyle(
                  color: transaction.type == TransactionType.withdrawal ||
                         transaction.type == TransactionType.refund
                    ? RtColors.error
                    : RtColors.success,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _formatTime(transaction.date),
                style: TextStyle(
                  color: RtColors.neutral500.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildTransactionCard(Transaction transaction) {
    final icon = _getTransactionIcon(transaction.type);
    final color = _getTransactionColor(transaction.type);
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(transaction.status).withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        onTap: () => _showTransactionDetails(transaction),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.description,
                          style: TextStyle(
                            color: RtColors.neutral900,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          transaction.id,
                          style: TextStyle(
                            color: RtColors.neutral500.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        transaction.amount.toCurrency(),
                        style: TextStyle(
                          color: RtColors.neutral900,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusColor(transaction.status).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getStatusText(transaction.status),
                          style: TextStyle(
                            color: _getStatusColor(transaction.status),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              if (transaction.driverName != null || transaction.passengerName != null) ...[
                SizedBox(height: 12),
                Row(
                  children: [
                    if (transaction.driverName != null) ...[
                      Icon(Icons.directions_car, size: 14, color: RtColors.neutral500),
                      SizedBox(width: 4),
                      Text(
                        transaction.driverName!,
                        style: TextStyle(color: RtColors.neutral500, fontSize: 13),
                      ),
                      SizedBox(width: 16),
                    ],
                    if (transaction.passengerName != null) ...[
                      Icon(Icons.person, size: 14, color: RtColors.neutral500),
                      SizedBox(width: 4),
                      Text(
                        transaction.passengerName!,
                        style: TextStyle(color: RtColors.neutral500, fontSize: 13),
                      ),
                    ],
                    Spacer(),
                    Text(
                      _formatDateTime(transaction.date),
                      style: TextStyle(color: RtColors.neutral500.withValues(alpha: 0.7), fontSize: 12),
                    ),
                  ],
                ),
              ],
              
              if (transaction.commission != null) ...[
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: RtColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.percent, size: 14, color: RtColors.info),
                      SizedBox(width: 4),
                      Text(
                        'Comisión: ${transaction.commission!.toCurrency()}',
                        style: TextStyle(
                          color: RtColors.info,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildPayoutCard(Map<String, dynamic> payout) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RtColors.warning.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: RtColors.brand.withValues(alpha: 0.2),
                  child: Icon(Icons.person, color: RtColors.brand),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payout['driverName'],
                        style: TextStyle(
                          color: RtColors.neutral900,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${payout['trips']} viajes completados',
                        style: TextStyle(
                          color: RtColors.neutral500.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  payout['amount'].toCurrency(),
                  style: TextStyle(
                    color: RtColors.warning,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 12),
            
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.account_balance, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
                  SizedBox(width: 8),
                  Text(
                    '${payout['bank']} - ${payout['accountNumber']}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.70), fontSize: 13),
                  ),
                  Spacer(),
                  Text(
                    'Solicitado ${_formatDate(payout['requestDate'])}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 12),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: RtButton(
                    label: 'Rechazar',
                    icon: Icons.close,
                    variant: RtButtonVariant.danger,
                    onPressed: () => _rejectPayout(payout),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: RtButton(
                    label: 'Aprobar',
                    icon: Icons.check,
                    onPressed: () => _approvePayout(payout),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildIncomeStat(String label, String value) {
    return Column(
      children: [
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
  
  IconData _getTransactionIcon(TransactionType type) {
    switch (type) {
      case TransactionType.trip:
        return Icons.directions_car;
      case TransactionType.withdrawal:
        return Icons.account_balance_wallet;
      case TransactionType.commission:
        return Icons.percent;
      case TransactionType.refund:
        return Icons.replay;
    }
  }
  
  Color _getTransactionColor(TransactionType type) {
    switch (type) {
      case TransactionType.trip:
        return RtColors.success;
      case TransactionType.withdrawal:
        return RtColors.warning;
      case TransactionType.commission:
        return RtColors.info;
      case TransactionType.refund:
        return RtColors.error;
    }
  }
  
  Color _getStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.completed:
        return RtColors.success;
      case PaymentStatus.pending:
        return RtColors.warning;
      case PaymentStatus.failed:
        return RtColors.error;
      case PaymentStatus.processing:
        return RtColors.info;
    }
  }
  
  String _getStatusText(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.completed:
        return 'COMPLETADO';
      case PaymentStatus.pending:
        return 'PENDIENTE';
      case PaymentStatus.failed:
        return 'FALLIDO';
      case PaymentStatus.processing:
        return 'PROCESANDO';
    }
  }
  
  String _formatTime(DateTime date) {
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}';
  }
  
  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
  
  void _showTransactionDetails(Transaction transaction) {
    showModalBottomSheet(
      context: context,
      backgroundColor: RtColors.neutral800,
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
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            Text(
              'Detalles de Transacción',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            SizedBox(height: 20),
            
            _buildDetailRow('ID Transacción', transaction.id),
            _buildDetailRow('Tipo', _getTransactionTypeName(transaction.type)),
            _buildDetailRow('Monto', transaction.amount.toCurrency()),
            _buildDetailRow('Estado', _getStatusText(transaction.status)),
            _buildDetailRow('Fecha', _formatDateTime(transaction.date)),
            
            if (transaction.driverName != null)
              _buildDetailRow('Conductor', transaction.driverName!),
            if (transaction.passengerName != null)
              _buildDetailRow('Pasajero', transaction.passengerName!),
            if (transaction.commission != null)
              _buildDetailRow('Comisión', transaction.commission!.toCurrency()),
            if (transaction.invoiceNumber != null)
              _buildDetailRow('Nº Factura', transaction.invoiceNumber!),
            
            SizedBox(height: 20),
            
            Row(
              children: [
                Expanded(
                  child: RtButton(
                    label: 'Exportar',
                    icon: Icons.download,
                    variant: RtButtonVariant.outlined,
                    onPressed: () {
                      Navigator.pop(context);
                      _exportTransaction(transaction);
                    },
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: RtButton(
                    label: 'Factura',
                    icon: Icons.receipt,
                    onPressed: () {
                      Navigator.pop(context);
                      _generateInvoice(transaction);
                    },
                  ),
                ),
              ],
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
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(color: RtColors.neutral900, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
  
  String _getTransactionTypeName(TransactionType type) {
    switch (type) {
      case TransactionType.trip:
        return 'Viaje';
      case TransactionType.withdrawal:
        return 'Retiro';
      case TransactionType.commission:
        return 'Comisión';
      case TransactionType.refund:
        return 'Reembolso';
    }
  }
  
  void _showCommissionSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RtColors.neutral800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Configuración de Comisiones',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tasa de comisión actual',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.70)),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _currentCommissionRate,
                    min: 10,
                    max: 30,
                    divisions: 20,
                    activeColor: RtColors.brand,
                    onChanged: (value) {
                      setState(() => _currentCommissionRate = value);
                      Navigator.pop(context);
                      _showCommissionSettings();
                    },
                  ),
                ),
                Text(
                  '${_currentCommissionRate.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: RtColors.brand,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Text(
              'Comisiones por tipo de viaje',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.70), fontSize: 14),
            ),
            SizedBox(height: 12),
            _buildCommissionSetting('Viajes Estándar', 'standard'),
            _buildCommissionSetting('Viajes Premium', 'premium'),
            _buildCommissionSetting('Viajes Corporativos', 'corporate'),
          ],
        ),
        actions: [
          RtButton(
            label: 'Cancelar',
            variant: RtButtonVariant.ghost,
            isFullWidth: false,
            onPressed: () => Navigator.pop(context),
          ),
          RtButton(
            label: 'Guardar',
            isFullWidth: false,
            onPressed: () async {
              Navigator.pop(context);
              await _saveCommissionSettings();
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildCommissionSetting(String label, String typeKey) {
    final rate = _commissionRates[typeKey] ?? 0.0;
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: RtColors.neutral900, fontSize: 14)),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.remove, size: 18, color: RtColors.neutral500),
                onPressed: () {
                  if (rate > 0) {
                    setState(() => _commissionRates[typeKey] = rate - 0.5);
                  }
                },
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  '${rate.toStringAsFixed(1)}%',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: RtColors.brand,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.add, size: 18, color: RtColors.neutral500),
                onPressed: () {
                  if (rate < 50) {
                    setState(() => _commissionRates[typeKey] = rate + 0.5);
                  }
                },
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  void _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: RtColors.brand,
              surface: RtColors.neutral800,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      // Handle date range selection
    }
  }
  
  // ✅ IMPLEMENTADO: Procesar todos los pagos pendientes con Firebase
  Future<void> _processAllPayouts() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RtColors.neutral800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Procesar Todos los Pagos',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
          '¿Estás seguro de procesar ${_pendingPayouts.length} pagos por un total de ${_financialStats['pendingPayouts']!.toCurrency()}?',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.70)),
        ),
        actions: [
          RtButton(
            label: 'Cancelar',
            variant: RtButtonVariant.ghost,
            isFullWidth: false,
            onPressed: () => Navigator.pop(context),
          ),
          RtButton(
            label: 'Procesar',
            isFullWidth: false,
            onPressed: () async {
              Navigator.of(context).pop();

              RtSnackbar.show(this.context, message: 'Procesando ${_pendingPayouts.length} pagos...', type: RtSnackbarType.warning);

              try {
                final batch = _firestore.batch();

                for (final payout in _pendingPayouts) {
                  final docRef = _firestore
                      .collection('withdrawal_requests')
                      .doc(payout['id']);

                  batch.update(docRef, {
                    'status': 'completed',
                    'processedAt': FieldValue.serverTimestamp(),
                    'processedBy': 'admin',
                  });
                }

                await batch.commit();
                await _loadFinancialData();

                if (!mounted) return;

                RtSnackbar.show(this.context, message: '${_pendingPayouts.length} pagos procesados exitosamente', type: RtSnackbarType.success);
              } catch (e) {
                if (!mounted) return;

                RtSnackbar.show(this.context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
              }
            },
          ),
        ],
      ),
    );
  }
  
  // ✅ IMPLEMENTADO: Aprobar pago con actualización a Firebase
  Future<void> _approvePayout(Map<String, dynamic> payout) async {
    try {
      // Actualizar estado del retiro en Firebase
      await _firestore
          .collection('withdrawal_requests')
          .doc(payout['id'])
          .update({
        'status': 'completed',
        'processedAt': FieldValue.serverTimestamp(),
        'processedBy': FirebaseAuth.instance.currentUser?.uid ?? 'admin', // ✅ ID del admin actual
      });

      // Recargar datos
      await _loadFinancialData();

      if (mounted) {
        RtSnackbar.show(context, message: 'Pago aprobado: ${payout['amount'].toCurrency()} a ${payout['driverName']}', type: RtSnackbarType.success);
      }
    } catch (e) {
      if (mounted) {
        RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
      }
    }
  }

  // Rechazar pago con actualización a Firebase
  Future<void> _rejectPayout(Map<String, dynamic> payout) async {
    try {
      // Actualizar estado del retiro en Firebase
      await _firestore
          .collection('withdrawal_requests')
          .doc(payout['id'])
          .update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': FirebaseAuth.instance.currentUser?.uid ?? 'admin', // ✅ ID del admin actual
      });

      // Recargar datos
      await _loadFinancialData();

      if (mounted) {
        RtSnackbar.show(context, message: 'Pago rechazado', type: RtSnackbarType.error);
      }
    } catch (e) {
      if (mounted) {
        RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
      }
    }
  }
  
  // ✅ IMPLEMENTADO: Exportar reporte financiero completo en PDF y CSV
  Future<void> _exportFinancialReport() async {
    try {
      // Mostrar diálogo de progreso
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: RtColors.neutral800,
          content: Row(
            children: [
              CircularProgressIndicator(color: RtColors.brand),
              SizedBox(width: 20),
              Text('Generando reporte...', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            ],
          ),
        ),
      );

      // Generar PDF
      final pdf = pw.Document();
      final now = DateTime.now();

      pdf.addPage(
        pw.MultiPage(
          build: (context) => [
            // Encabezado
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('REPORTE FINANCIERO - RAPITEAM',
                      style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  pw.Text('Fecha: ${now.day}/${now.month}/${now.year}  ${now.hour}:${now.minute}',
                      style: pw.TextStyle(fontSize: 12)),
                  pw.Text('Período: $_selectedPeriod',
                      style: pw.TextStyle(fontSize: 12)),
                  pw.Divider(thickness: 2),
                ],
              ),
            ),

            // Estadísticas principales
            pw.SizedBox(height: 20),
            pw.Text('RESUMEN FINANCIERO', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                _buildPdfTableRow('Ingresos Totales', _financialStats['totalRevenue']!.toCurrency()),
                _buildPdfTableRow('Comisiones', _financialStats['totalCommissions']!.toCurrency()),
                _buildPdfTableRow('Pagos Pendientes', _financialStats['pendingPayouts']!.toCurrency()),
                _buildPdfTableRow('Pagos Completados', _financialStats['completedPayouts']!.toCurrency()),
                _buildPdfTableRow('Valor Promedio Viaje', _financialStats['avgTripValue']!.toCurrency()),
                _buildPdfTableRow('Promedio Diario', _financialStats['dailyAverage']!.toCurrency()),
              ],
            ),

            // Transacciones
            pw.SizedBox(height: 30),
            pw.Text('TRANSACCIONES RECIENTES', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: pw.FixedColumnWidth(80),
                1: pw.FixedColumnWidth(100),
                2: pw.FlexColumnWidth(),
                3: pw.FixedColumnWidth(80),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Padding(
                      padding: pw.EdgeInsets.all(5),
                      child: pw.Text('Tipo', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(5),
                      child: pw.Text('Fecha', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(5),
                      child: pw.Text('Descripción', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(5),
                      child: pw.Text('Monto', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                ..._transactions.take(50).map((t) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                          child: pw.Text(t.type.name.toUpperCase(), style: pw.TextStyle(fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                          child: pw.Text('${t.date.day}/${t.date.month}/${t.date.year}', style: pw.TextStyle(fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                          child: pw.Text(t.description, style: pw.TextStyle(fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                          child: pw.Text(t.amount.toCurrency(), style: pw.TextStyle(fontSize: 10)),
                        ),
                      ],
                    )),
              ],
            ),
          ],
        ),
      );

      // Guardar PDF
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/reporte_financiero_${now.millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      // Generar CSV
      final List<List<dynamic>> csvData = [
        ['Tipo', 'Fecha', 'Descripción', 'Monto', 'Estado'],
        ..._transactions.map((t) => [
              t.type.name,
              '${t.date.day}/${t.date.month}/${t.date.year}',
              t.description,
              t.amount,
              t.status.name,
            ]),
      ];

      final csvString = const ListToCsvConverter().convert(csvData);
      final csvFile = File('${output.path}/reporte_financiero_${now.millisecondsSinceEpoch}.csv');
      await csvFile.writeAsBytes(csvString.codeUnits);

      if (!mounted) return;

      Navigator.pop(context); // Cerrar diálogo de progreso

      // Compartir archivos
      await Share.shareXFiles(
        [XFile(file.path), XFile(csvFile.path)],
        text: 'Reporte Financiero - RapiTeam',
      );

      if (!mounted) return;

      RtSnackbar.show(context, message: 'Reporte exportado exitosamente', type: RtSnackbarType.success);
    } catch (e) {
      if (!mounted) return;

      Navigator.pop(context);

      if (!mounted) return;

      RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
    }
  }

  // Helper para construir filas de tabla en PDF
  pw.TableRow _buildPdfTableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: pw.EdgeInsets.all(8),
          child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ),
        pw.Padding(
          padding: pw.EdgeInsets.all(8),
          child: pw.Text(value),
        ),
      ],
    );
  }
  
  // ✅ IMPLEMENTADO: Exportar transacción individual en CSV
  Future<void> _exportTransaction(Transaction transaction) async {
    try {
      final List<List<dynamic>> csvData = [
        ['Campo', 'Valor'],
        ['ID', transaction.id],
        ['Tipo', transaction.type.name],
        ['Monto', transaction.amount],
        ['Fecha', '${transaction.date.day}/${transaction.date.month}/${transaction.date.year} ${transaction.date.hour}:${transaction.date.minute}'],
        ['Estado', transaction.status.name],
        ['Descripción', transaction.description],
        if (transaction.driverName != null) ['Conductor', transaction.driverName],
        if (transaction.passengerName != null) ['Pasajero', transaction.passengerName],
        if (transaction.commission != null) ['Comisión', transaction.commission],
        if (transaction.invoiceNumber != null) ['Nº Factura', transaction.invoiceNumber],
      ];

      final csvString = const ListToCsvConverter().convert(csvData);
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/transacción_${transaction.id}.csv');
      await file.writeAsBytes(csvString.codeUnits);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Transacción ${transaction.id}',
      );

      if (!mounted) return;

      RtSnackbar.show(context, message: 'Transacción exportada exitosamente', type: RtSnackbarType.success);
    } catch (e) {
      if (!mounted) return;

      RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
    }
  }

  // ✅ IMPLEMENTADO: Generar factura en PDF para una transacción
  Future<void> _generateInvoice(Transaction transaction) async {
    try {
      final pdf = pw.Document();
      final now = DateTime.now();

      pdf.addPage(
        pw.Page(
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Encabezado de factura
              pw.Container(
                padding: pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 2),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('FACTURA',
                        style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 10),
                    pw.Text('RAPITEAM S.A.C.',
                        style: pw.TextStyle(fontSize: 18)),
                    pw.Text('RUC: 20XXXXXXXXX',
                        style: pw.TextStyle(fontSize: 12)),
                    pw.Text('Dirección: Lima, Perú',
                        style: pw.TextStyle(fontSize: 12)),
                  ],
                ),
              ),

              pw.SizedBox(height: 30),

              // Información de la factura
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('FACTURA Nº: ${transaction.invoiceNumber ?? transaction.id}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Fecha: ${now.day}/${now.month}/${now.year}'),
                      pw.Text('Hora: ${now.hour}:${now.minute}'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      if (transaction.driverName != null)
                        pw.Text('Conductor: ${transaction.driverName}'),
                      if (transaction.passengerName != null)
                        pw.Text('Pasajero: ${transaction.passengerName}'),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 30),

              // Detalles de la transacción
              pw.Text('DETALLE DE SERVICIO',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text('Descripción', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text('Monto', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(transaction.description),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(transaction.amount.toCurrency()),
                      ),
                    ],
                  ),
                  if (transaction.commission != null)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text('Comisión de plataforma'),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(transaction.commission!.toCurrency()),
                        ),
                      ],
                    ),
                ],
              ),

              pw.SizedBox(height: 20),

              // Total
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 200,
                  padding: pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey300,
                    border: pw.Border.all(width: 2),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('TOTAL:', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                      pw.Text(transaction.amount.toCurrency(),
                          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
              ),

              pw.Spacer(),

              // Pie de página
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 10),
              pw.Text('Gracias por usar RapiTeam',
                  style: pw.TextStyle(fontSize: 12), textAlign: pw.TextAlign.center),
              pw.Text('www.rapiteam.app | soporte@rapiteam.app',
                  style: pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center),
            ],
          ),
        ),
      );

      // Guardar y compartir
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/factura_${transaction.id}.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Factura ${transaction.invoiceNumber ?? transaction.id}',
      );

      if (!mounted) return;

      RtSnackbar.show(context, message: 'Factura generada exitosamente', type: RtSnackbarType.success);
    } catch (e) {
      if (!mounted) return;

      RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
    }
  }
}

// Custom painter for revenue chart
class RevenueChartPainter extends CustomPainter {
  final double progress;
  final List<double> data;
  
  const RevenueChartPainter({super.repaint, required this.progress, required this.data});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        colors: [
          RtColors.brand.withValues(alpha: 0.3),
          RtColors.brand.withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    final path = Path();
    final fillPath = Path();
    
    final maxValue = data.reduce(math.max);
    final stepX = size.width / (data.length - 1);
    
    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - (data[i] / maxValue) * size.height * 0.8 * progress;
      
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    
    // Complete fill path
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();
    
    // Draw fill
    canvas.drawPath(fillPath, fillPaint);
    
    // Draw line
    paint.color = RtColors.brand;
    canvas.drawPath(path, paint);
    
    // Draw points
    final pointPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = RtColors.brand;
    
    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - (data[i] / maxValue) * size.height * 0.8 * progress;
      
      canvas.drawCircle(Offset(x, y), 4, pointPaint);
      canvas.drawCircle(
        Offset(x, y),
        4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = RtColors.neutral50,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}