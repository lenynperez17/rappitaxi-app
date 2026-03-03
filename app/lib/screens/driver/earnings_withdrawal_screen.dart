import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/design/design_system.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_card.dart';
import '../../core/widgets/rt_button.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../core/widgets/rt_empty_state.dart';
import '../../core/widgets/rt_badge.dart';
import '../../services/payment_service.dart';
import '../../services/firebase_service.dart';
import '../../utils/logger.dart';
import '../../utils/firestore_error_handler.dart';

/// Pantalla de retiro de ganancias para conductores RapiTeam.
/// Funcionalidades: vista de ganancias, retiros bancarios,
/// retiros via Yape/Plin, historial de retiros, estadísticas.
class EarningsWithdrawalScreen extends StatefulWidget {
  final String driverId;

  const EarningsWithdrawalScreen({
    super.key,
    required this.driverId,
  });

  @override
  State<EarningsWithdrawalScreen> createState() => _EarningsWithdrawalScreenState();
}

class _EarningsWithdrawalScreenState extends State<EarningsWithdrawalScreen>
    with TickerProviderStateMixin {
  final PaymentService _paymentService = PaymentService();
  final FirebaseService _firebaseService = FirebaseService();

  late TabController _tabController;
  bool _isLoading = true;

  // Información de ganancias
  double _totalEarnings = 0.0;
  double _availableForWithdrawal = 0.0;
  double _pendingWithdrawals = 0.0;
  double _totalWithdrawn = 0.0;

  // Historial de ganancias y retiros
  List<EarningsPeriod> _earningsHistory = [];
  List<WithdrawalHistory> _withdrawalHistory = [];

  // Formulario de retiro
  final _withdrawalAmountController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _accountHolderNameController = TextEditingController();
  final _documentNumberController = TextEditingController();

  String _selectedWithdrawalMethod = 'bank_transfer';
  String _selectedBank = 'interbank';
  double _withdrawalAmount = 0.0;
  double _withdrawalFee = 0.0;
  double _netAmount = 0.0;

  // Configuración de límites
  static const double _minWithdrawal = 20.0;
  static const double _maxDailyWithdrawal = 1500.0;
  static const double _bankTransferFee = 3.0;
  static const double _digitalWalletFee = 1.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeServices();
    _setupAmountListener();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _withdrawalAmountController.dispose();
    _accountNumberController.dispose();
    _phoneController.dispose();
    _accountHolderNameController.dispose();
    _documentNumberController.dispose();
    super.dispose();
  }

  void _setupAmountListener() {
    _withdrawalAmountController.addListener(() {
      final amount = double.tryParse(_withdrawalAmountController.text) ?? 0.0;
      setState(() {
        _withdrawalAmount = amount;
        _calculateWithdrawalFee();
      });
    });
  }

  void _calculateWithdrawalFee() {
    switch (_selectedWithdrawalMethod) {
      case 'bank_transfer':
        _withdrawalFee = _bankTransferFee;
        break;
      case 'yape':
      case 'plin':
        _withdrawalFee = _digitalWalletFee;
        break;
      default:
        _withdrawalFee = 0.0;
    }
    _netAmount = _withdrawalAmount - _withdrawalFee;
  }

  Future<void> _initializeServices() async {
    setState(() => _isLoading = true);
    try {
      await _paymentService.initialize();
      await _loadDriverEarnings();
      await _loadEarningsHistory();
      await _loadWithdrawalHistory();
    } catch (e) {
      _showErrorSnackBar(FirestoreErrorHandler.getSpanishMessage(e));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDriverEarnings() async {
    try {
      final driverDoc = await _firebaseService.firestore
          .collection('drivers')
          .doc(widget.driverId)
          .get();

      if (driverDoc.exists) {
        final data = driverDoc.data() as Map<String, dynamic>;
        setState(() {
          _totalEarnings = (data['totalEarnings'] ?? 0.0).toDouble();
          _availableForWithdrawal = (data['availableForWithdrawal'] ?? 0.0).toDouble();
          _pendingWithdrawals = (data['pendingWithdrawals'] ?? 0.0).toDouble();
          _totalWithdrawn = (data['totalWithdrawn'] ?? 0.0).toDouble();
        });
      }
    } catch (e) {
      _showErrorSnackBar(FirestoreErrorHandler.getSpanishMessage(e));
    }
  }

  // Cargar historial de ganancias real desde Firebase
  Future<void> _loadEarningsHistory() async {
    try {
      final now = DateTime.now();
      final periods = <String, EarningsPeriod>{};

      for (int i = 0; i < 4; i++) {
        final weekStart = now.subtract(Duration(days: (i + 1) * 7));
        final weekEnd = now.subtract(Duration(days: i * 7));

        final ridesSnapshot = await FirebaseFirestore.instance
            .collection('rides')
            .where('driverId', isEqualTo: widget.driverId)
            .where('status', isEqualTo: 'completed')
            .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
            .where('completedAt', isLessThan: Timestamp.fromDate(weekEnd))
            .get();

        double weekEarnings = 0.0;
        double weekHours = 0.0;

        for (var doc in ridesSnapshot.docs) {
          final data = doc.data();
          final fare = (data['fare'] ?? data['estimatedFare'] ?? 0.0) as num;
          weekEarnings += fare.toDouble();

          if (data['startedAt'] != null && data['completedAt'] != null) {
            final startedAt = (data['startedAt'] as Timestamp).toDate();
            final completedAt = (data['completedAt'] as Timestamp).toDate();
            final duration = completedAt.difference(startedAt);
            weekHours += duration.inMinutes / 60.0;
          }
        }

        final periodName = i == 0
            ? 'Esta semana'
            : i == 1
                ? 'Semana pasada'
                : 'Hace ${i + 1} semanas';

        periods[periodName] = EarningsPeriod(
          period: periodName,
          earnings: weekEarnings,
          trips: ridesSnapshot.docs.length,
          hours: weekHours,
        );
      }

      setState(() {
        _earningsHistory = periods.values.toList();
      });
    } catch (e) {
      AppLogger.error('Error cargando historial de ganancias: $e');
      _showErrorSnackBar(FirestoreErrorHandler.getSpanishMessage(e));
    }
  }

  // Cargar historial de retiros real desde Firebase
  Future<void> _loadWithdrawalHistory() async {
    try {
      final withdrawalsSnapshot = await FirebaseFirestore.instance
          .collection('withdrawals')
          .where('driverId', isEqualTo: widget.driverId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final withdrawals = <WithdrawalHistory>[];
      for (var doc in withdrawalsSnapshot.docs) {
        final data = doc.data();
        withdrawals.add(WithdrawalHistory(
          id: doc.id,
          amount: (data['amount'] ?? 0.0).toDouble(),
          fee: (data['fee'] ?? 0.0).toDouble(),
          netAmount: (data['netAmount'] ?? 0.0).toDouble(),
          method: data['method'] ?? 'bank_transfer',
          destination: data['destination'] ?? '',
          status: data['status'] ?? 'Procesando',
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          processedAt: (data['processedAt'] as Timestamp?)?.toDate(),
        ));
      }

      setState(() {
        _withdrawalHistory = withdrawals;
      });
    } catch (e) {
      AppLogger.error('Error cargando historial de retiros: $e');
      _showErrorSnackBar(FirestoreErrorHandler.getSpanishMessage(e));
    }
  }

  // Procesamiento de retiros
  Future<void> _processWithdrawal() async {
    if (!_validateWithdrawal()) return;

    final confirmed = await _showWithdrawalConfirmation();
    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      switch (_selectedWithdrawalMethod) {
        case 'bank_transfer':
          await _processBankTransfer();
          break;
        case 'yape':
          await _processYapeWithdrawal();
          break;
        case 'plin':
          await _processPlinWithdrawal();
          break;
      }

      _showSuccessDialog();
      await _loadDriverEarnings();
      await _loadWithdrawalHistory();
      _clearForm();
    } catch (e) {
      _showErrorSnackBar(FirestoreErrorHandler.getSpanishMessage(e));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processBankTransfer() async {
    final result = await _paymentService.requestWithdrawal(
      driverId: widget.driverId,
      amount: _withdrawalAmount,
      method: 'bank_transfer',
      bankName: _selectedBank,
      accountNumber: _accountNumberController.text,
      accountHolderName: _accountHolderNameController.text,
      accountHolderDocumentNumber: _documentNumberController.text,
      accountHolderDocumentType: 'DNI',
    );

    if (!result.success) {
      throw Exception(result.error ?? 'Error procesando transferencia bancaria');
    }

    await _firebaseService.analytics.logEvent(
      name: 'driver_withdrawal_bank_transfer',
      parameters: {
        'driver_id': widget.driverId,
        'amount': _withdrawalAmount,
        'bank': _selectedBank,
        'withdrawal_id': result.withdrawalId ?? '',
      },
    );
  }

  Future<void> _processYapeWithdrawal() async {
    final result = await _paymentService.requestWithdrawal(
      driverId: widget.driverId,
      amount: _withdrawalAmount,
      method: 'yape',
      phoneNumber: _phoneController.text,
      accountHolderName: _accountHolderNameController.text,
      accountHolderDocumentNumber: _documentNumberController.text,
      accountHolderDocumentType: 'DNI',
    );

    if (!result.success) {
      throw Exception(result.error ?? 'Error procesando retiro Yape');
    }

    await _firebaseService.analytics.logEvent(
      name: 'driver_withdrawal_yape',
      parameters: {
        'driver_id': widget.driverId,
        'amount': _withdrawalAmount,
        'phone': _phoneController.text,
        'withdrawal_id': result.withdrawalId ?? '',
      },
    );
  }

  Future<void> _processPlinWithdrawal() async {
    final result = await _paymentService.requestWithdrawal(
      driverId: widget.driverId,
      amount: _withdrawalAmount,
      method: 'plin',
      phoneNumber: _phoneController.text,
      accountHolderName: _accountHolderNameController.text,
      accountHolderDocumentNumber: _documentNumberController.text,
      accountHolderDocumentType: 'DNI',
    );

    if (!result.success) {
      throw Exception(result.error ?? 'Error procesando retiro Plin');
    }

    await _firebaseService.analytics.logEvent(
      name: 'driver_withdrawal_plin',
      parameters: {
        'driver_id': widget.driverId,
        'amount': _withdrawalAmount,
        'phone': _phoneController.text,
        'withdrawal_id': result.withdrawalId ?? '',
      },
    );
  }

  // Validaciones
  bool _validateWithdrawal() {
    if (_withdrawalAmount < _minWithdrawal) {
      _showErrorSnackBar('El monto mínimo de retiro es S/. $_minWithdrawal');
      return false;
    }
    if (_withdrawalAmount > _availableForWithdrawal) {
      _showErrorSnackBar('No tienes suficiente saldo disponible');
      return false;
    }
    if (_withdrawalAmount > _maxDailyWithdrawal) {
      _showErrorSnackBar('El monto máximo diario de retiro es S/. $_maxDailyWithdrawal');
      return false;
    }
    if (_accountHolderNameController.text.isEmpty) {
      _showErrorSnackBar('Ingresa el nombre del titular de la cuenta');
      return false;
    }
    if (_documentNumberController.text.isEmpty) {
      _showErrorSnackBar('Ingresa el número de DNI');
      return false;
    }
    if (!RegExp(r'^[0-9]{8}$').hasMatch(_documentNumberController.text)) {
      _showErrorSnackBar('El DNI debe tener 8 dígitos');
      return false;
    }

    switch (_selectedWithdrawalMethod) {
      case 'bank_transfer':
        if (_accountNumberController.text.isEmpty) {
          _showErrorSnackBar('Ingresa el número de cuenta bancaria');
          return false;
        }
        if (_accountNumberController.text.length < 13) {
          _showErrorSnackBar('El número de cuenta debe tener al menos 13 dígitos');
          return false;
        }
        break;
      case 'yape':
      case 'plin':
        if (_phoneController.text.isEmpty ||
            !RegExp(r'^9[0-9]{8}$').hasMatch(_phoneController.text)) {
          _showErrorSnackBar('Ingresa un número de teléfono válido (9XXXXXXXX)');
          return false;
        }
        break;
    }
    return true;
  }

  // Dialogos
  Future<bool> _showWithdrawalConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
        title: Text('Confirmar Retiro', style: RtTypo.headingSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Confirmas el retiro de S/. ${_withdrawalAmount.toStringAsFixed(2)}?'),
            const SizedBox(height: RtSpacing.md),
            Container(
              padding: const EdgeInsets.all(RtSpacing.md),
              decoration: BoxDecoration(
                color: RtColors.infoLight,
                borderRadius: RtRadius.borderSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Monto a retirar:', style: RtTypo.bodyMedium),
                      Text('S/. ${_withdrawalAmount.toStringAsFixed(2)}', style: RtTypo.bodyMedium),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Comisión:', style: RtTypo.bodyMedium),
                      Text('- S/. ${_withdrawalFee.toStringAsFixed(2)}', style: RtTypo.bodyMedium),
                    ],
                  ),
                  Divider(color: RtColors.neutral300),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recibirás:', style: RtTypo.titleMedium),
                      Text(
                        'S/. ${_netAmount.toStringAsFixed(2)}',
                        style: RtTypo.titleMedium.copyWith(color: RtColors.success),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: RtSpacing.md),
            Text('Método: ${_getMethodDisplayName(_selectedWithdrawalMethod)}', style: RtTypo.bodyMedium),
            if (_selectedWithdrawalMethod == 'bank_transfer')
              Text('Destino: ${_getBankDisplayName(_selectedBank)} ${_accountNumberController.text}', style: RtTypo.bodyMedium)
            else
              Text('Destino: ${_phoneController.text}', style: RtTypo.bodyMedium),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: RtColors.brand),
            child: const Text('CONFIRMAR'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: RtColors.success, size: RtIconSize.xl),
            const SizedBox(width: RtSpacing.sm),
            Text('Retiro Procesado!', style: RtTypo.headingSmall),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Tu retiro ha sido procesado exitosamente.', textAlign: TextAlign.center, style: RtTypo.bodyMedium),
            const SizedBox(height: RtSpacing.base),
            Container(
              padding: const EdgeInsets.all(RtSpacing.md),
              decoration: BoxDecoration(
                color: RtColors.successLight,
                borderRadius: RtRadius.borderSm,
              ),
              child: Column(
                children: [
                  Text(
                    'S/. ${_netAmount.toStringAsFixed(2)}',
                    style: RtTypo.displaySmall.copyWith(color: RtColors.success),
                  ),
                  Text(
                    _selectedWithdrawalMethod == 'bank_transfer'
                        ? 'Se procesará en 24-48 horas hábiles'
                        : 'Procesado instantaneamente',
                    style: RtTypo.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: RtColors.brand),
            child: const Text('ENTENDIDO'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    RtSnackbar.show(context, message: message, type: RtSnackbarType.error);
  }

  void _clearForm() {
    _withdrawalAmountController.clear();
    _accountNumberController.clear();
    _phoneController.clear();
    _accountHolderNameController.clear();
    _documentNumberController.clear();
    setState(() {
      _withdrawalAmount = 0.0;
      _withdrawalFee = 0.0;
      _netAmount = 0.0;
    });
  }

  // Métodos auxiliares
  String _getMethodDisplayName(String method) {
    switch (method) {
      case 'bank_transfer':
        return 'Transferencia Bancaria';
      case 'yape':
        return 'Yape';
      case 'plin':
        return 'Plin';
      default:
        return method;
    }
  }

  String _getBankDisplayName(String bank) {
    switch (bank) {
      case 'bcp':
        return 'BCP';
      case 'bbva':
        return 'BBVA';
      case 'interbank':
        return 'Interbank';
      case 'scotiabank':
        return 'Scotiabank';
      default:
        return bank.toUpperCase();
    }
  }

  // UI - BUILD METHODS
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: RtAppBar(
        title: 'Mis Ganancias',
        variant: RtAppBarVariant.gradient,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: RtColors.white,
          labelColor: RtColors.white,
          unselectedLabelColor: RtColors.white.withValues(alpha: 0.7),
          labelStyle: RtTypo.labelLarge,
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Retirar'),
            Tab(text: 'Historial'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildDashboardTab(),
              _buildWithdrawalTab(),
              _buildHistoryTab(),
            ],
          ),
          if (_isLoading)
            Container(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: RtSpacing.paddingBase,
      child: Column(
        children: [
          _buildEarningsSummaryCard(),
          const SizedBox(height: RtSpacing.base),
          _buildEarningsHistoryCard(),
          const SizedBox(height: RtSpacing.base),
          _buildQuickStatsCard(),
        ],
      ),
    );
  }

  Widget _buildEarningsSummaryCard() {
    final secondaryText = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return RtCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet, color: RtColors.brand, size: RtIconSize.lg),
              const SizedBox(width: RtSpacing.sm),
              Text('Resumen de Ganancias', style: RtTypo.headingMedium),
            ],
          ),
          const SizedBox(height: RtSpacing.lg),
          Container(
            padding: RtSpacing.paddingBase,
            decoration: BoxDecoration(
              gradient: RtGradients.brand,
              borderRadius: RtRadius.borderMd,
            ),
            child: Column(
              children: [
                Text('Disponible para retiro', style: RtTypo.bodyLarge.copyWith(color: RtColors.white)),
                const SizedBox(height: RtSpacing.sm),
                Text(
                  'S/. ${_availableForWithdrawal.toStringAsFixed(2)}',
                  style: RtTypo.displayLarge.copyWith(color: RtColors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: RtSpacing.base),
          Row(
            children: [
              Expanded(child: _buildSummaryItem('Total Ganado', 'S/. ${_totalEarnings.toStringAsFixed(2)}', Icons.trending_up, RtColors.info, secondaryText)),
              Expanded(child: _buildSummaryItem('Total Retirado', 'S/. ${_totalWithdrawn.toStringAsFixed(2)}', Icons.download, RtColors.warning, secondaryText)),
            ],
          ),
          const SizedBox(height: RtSpacing.sm),
          Row(
            children: [
              Expanded(child: _buildSummaryItem('Pendientes', 'S/. ${_pendingWithdrawals.toStringAsFixed(2)}', Icons.schedule, RtColors.neutral500, secondaryText)),
              Expanded(
                child: RtButton(
                  label: 'Retirar',
                  icon: Icons.download,
                  onPressed: () => _tabController.animateTo(1),
                  size: RtButtonSize.small,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, IconData icon, Color color, Color secondaryText) {
    return Container(
      padding: const EdgeInsets.all(RtSpacing.md),
      margin: const EdgeInsets.symmetric(horizontal: RtSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: RtRadius.borderSm,
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: RtIconSize.md),
          const SizedBox(height: RtSpacing.xs),
          Text(title, style: RtTypo.labelSmall.copyWith(color: secondaryText), textAlign: TextAlign.center),
          Text(value, style: RtTypo.titleSmall.copyWith(fontWeight: FontWeight.bold, color: color), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildEarningsHistoryCard() {
    return RtCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ganancias por Periodo', style: RtTypo.headingSmall),
          const SizedBox(height: RtSpacing.base),
          Column(
            children: _earningsHistory.map((period) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: RtColors.brandSurface,
                  child: Text(
                    period.trips.toString(),
                    style: RtTypo.titleSmall.copyWith(color: RtColors.brand, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(period.period, style: RtTypo.titleMedium),
                subtitle: Text('${period.trips} viajes - ${period.hours.toStringAsFixed(1)} horas', style: RtTypo.bodySmall),
                trailing: Text(
                  'S/. ${period.earnings.toStringAsFixed(2)}',
                  style: RtTypo.titleMedium.copyWith(fontWeight: FontWeight.bold, color: RtColors.success),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsCard() {
    final secondaryText = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    final avgPerTrip = _earningsHistory.isNotEmpty
        ? _earningsHistory.first.earnings / (_earningsHistory.first.trips > 0 ? _earningsHistory.first.trips : 1)
        : 0.0;
    final avgPerHour = _earningsHistory.isNotEmpty
        ? _earningsHistory.first.earnings / (_earningsHistory.first.hours > 0 ? _earningsHistory.first.hours : 1)
        : 0.0;

    return RtCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Estadísticas Rapidas', style: RtTypo.headingSmall),
          const SizedBox(height: RtSpacing.base),
          Row(
            children: [
              Expanded(child: _buildStatItem('Promedio por viaje', 'S/. ${avgPerTrip.toStringAsFixed(2)}', Icons.directions_car, RtColors.info, secondaryText)),
              Expanded(child: _buildStatItem('Promedio por hora', 'S/. ${avgPerHour.toStringAsFixed(2)}', Icons.schedule, RtColors.warning, secondaryText)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon, Color color, Color secondaryText) {
    return Container(
      padding: RtSpacing.paddingBase,
      margin: const EdgeInsets.symmetric(horizontal: RtSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: RtRadius.borderSm,
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: RtIconSize.xl),
          const SizedBox(height: RtSpacing.sm),
          Text(title, style: RtTypo.bodySmall.copyWith(color: secondaryText), textAlign: TextAlign.center),
          Text(value, style: RtTypo.headingSmall.copyWith(color: color), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildWithdrawalTab() {
    return SingleChildScrollView(
      padding: RtSpacing.paddingBase,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvailableBalanceCard(),
          const SizedBox(height: RtSpacing.base),
          _buildWithdrawalMethodCard(),
          const SizedBox(height: RtSpacing.base),
          _buildWithdrawalAmountCard(),
          const SizedBox(height: RtSpacing.base),
          _buildDestinationCard(),
          const SizedBox(height: RtSpacing.base),
          _buildWithdrawalSummaryCard(),
          const SizedBox(height: RtSpacing.xl),
          _buildProcessWithdrawalButton(),
        ],
      ),
    );
  }

  Widget _buildAvailableBalanceCard() {
    final secondaryText = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return RtCard(
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet, color: RtColors.brand, size: RtIconSize.xxl),
          const SizedBox(width: RtSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Saldo Disponible', style: RtTypo.bodyLarge.copyWith(color: secondaryText)),
                Text(
                  'S/. ${_availableForWithdrawal.toStringAsFixed(2)}',
                  style: RtTypo.displayLarge.copyWith(color: RtColors.brand),
                ),
                Text(
                  'Mínimo: S/. $_minWithdrawal - Máximo diario: S/. $_maxDailyWithdrawal',
                  style: RtTypo.labelSmall.copyWith(color: secondaryText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawalMethodCard() {
    return RtCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Método de Retiro', style: RtTypo.headingSmall),
          const SizedBox(height: RtSpacing.md),
          RadioGroup<String>(
            groupValue: _selectedWithdrawalMethod,
            onChanged: (String? v) {
              if (v != null) {
                setState(() {
                  _selectedWithdrawalMethod = v;
                  _calculateWithdrawalFee();
                });
              }
            },
            child: Column(
              children: [
                _buildMethodTile('bank_transfer', 'Transferencia Bancaria', 'Comisión: S/3.00 - 24-48 horas', Icons.account_balance),
                _buildMethodTile('yape', 'Yape', 'Comisión: S/1.00 - Instantáneo', Icons.phone_android),
                _buildMethodTile('plin', 'Plin', 'Comisión: S/1.00 - Instantáneo', Icons.smartphone),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodTile(String value, String title, String subtitle, IconData icon) {
    final isSelected = _selectedWithdrawalMethod == value;
    return ListTile(
      leading: Radio<String>(
        value: value,
        activeColor: RtColors.brand,
      ),
      title: Row(
        children: [
          Icon(icon, color: isSelected ? RtColors.brand : RtColors.neutral500, size: RtIconSize.sm),
          const SizedBox(width: RtSpacing.sm),
          Text(title, style: RtTypo.titleMedium),
        ],
      ),
      subtitle: Text(subtitle, style: RtTypo.bodySmall),
      onTap: () {
        setState(() {
          _selectedWithdrawalMethod = value;
          _calculateWithdrawalFee();
        });
      },
    );
  }

  Widget _buildWithdrawalAmountCard() {
    return RtCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Monto a Retirar', style: RtTypo.headingSmall),
          const SizedBox(height: RtSpacing.md),
          TextField(
            controller: _withdrawalAmountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
            decoration: InputDecoration(
              labelText: 'Monto (S/.)',
              hintText: '0.00',
              prefixText: 'S/. ',
              border: OutlineInputBorder(borderRadius: RtRadius.borderSm),
              suffixIcon: const Icon(Icons.money),
            ),
          ),
          const SizedBox(height: RtSpacing.sm),
          Row(
            children: [
              _buildAmountChip('S/100', 100.0),
              _buildAmountChip('S/250', 250.0),
              _buildAmountChip('S/500', 500.0),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    _withdrawalAmountController.text = _availableForWithdrawal.toString();
                    setState(() {
                      _withdrawalAmount = _availableForWithdrawal;
                      _calculateWithdrawalFee();
                    });
                  },
                  child: Text('Retirar todo', style: RtTypo.labelMedium.copyWith(color: RtColors.brand)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountChip(String label, double amount) {
    return Expanded(
      child: TextButton(
        onPressed: () {
          _withdrawalAmountController.text = amount.toStringAsFixed(0);
          setState(() {
            _withdrawalAmount = amount;
            _calculateWithdrawalFee();
          });
        },
        child: Text(label, style: RtTypo.labelMedium.copyWith(color: RtColors.brand)),
      ),
    );
  }

  Widget _buildDestinationCard() {
    return RtCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Datos del Titular', style: RtTypo.headingSmall),
          const SizedBox(height: RtSpacing.md),
          TextField(
            controller: _accountHolderNameController,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Nombre Completo del Titular',
              hintText: 'Juan Perez Garcia',
              border: OutlineInputBorder(borderRadius: RtRadius.borderSm),
              suffixIcon: const Icon(Icons.person),
              helperText: 'Nombre como aparece en tu DNI',
            ),
          ),
          const SizedBox(height: RtSpacing.md),
          TextField(
            controller: _documentNumberController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
            decoration: InputDecoration(
              labelText: 'Número de DNI',
              hintText: '12345678',
              border: OutlineInputBorder(borderRadius: RtRadius.borderSm),
              suffixIcon: const Icon(Icons.credit_card),
              helperText: 'DNI de 8 dígitos',
            ),
          ),
          const SizedBox(height: RtSpacing.base),
          const Divider(),
          const SizedBox(height: RtSpacing.base),
          Text('Destino del Retiro', style: RtTypo.headingSmall),
          const SizedBox(height: RtSpacing.md),
          if (_selectedWithdrawalMethod == 'bank_transfer') ...[
            DropdownButtonFormField<String>(
              initialValue: _selectedBank,
              decoration: InputDecoration(
                labelText: 'Banco',
                border: OutlineInputBorder(borderRadius: RtRadius.borderSm),
              ),
              items: const [
                DropdownMenuItem(value: 'interbank', child: Text('Interbank')),
                DropdownMenuItem(value: 'bcp', child: Text('BCP')),
                DropdownMenuItem(value: 'bbva', child: Text('BBVA')),
                DropdownMenuItem(value: 'scotiabank', child: Text('Scotiabank')),
              ],
              onChanged: (value) => setState(() => _selectedBank = value!),
            ),
            const SizedBox(height: RtSpacing.md),
            TextField(
              controller: _accountNumberController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(20)],
              decoration: InputDecoration(
                labelText: 'Número de Cuenta',
                hintText: '1234567890123456',
                border: OutlineInputBorder(borderRadius: RtRadius.borderSm),
                suffixIcon: const Icon(Icons.account_balance),
                helperText: 'Cuenta bancaria destino',
              ),
            ),
          ] else ...[
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
              decoration: InputDecoration(
                labelText: 'Número de Teléfono',
                hintText: '987654321',
                prefixText: '+51 ',
                border: OutlineInputBorder(borderRadius: RtRadius.borderSm),
                suffixIcon: const Icon(Icons.phone),
                helperText: 'Para ${_selectedWithdrawalMethod.toUpperCase()}',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWithdrawalSummaryCard() {
    if (_withdrawalAmount <= 0) return const SizedBox.shrink();
    final secondaryText = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return RtCard(
      variant: RtCardVariant.filled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resumen del Retiro', style: RtTypo.headingSmall),
          const SizedBox(height: RtSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Monto a retirar:', style: RtTypo.bodyMedium),
              Text('S/. ${_withdrawalAmount.toStringAsFixed(2)}', style: RtTypo.bodyMedium),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Comisión (${_getMethodDisplayName(_selectedWithdrawalMethod)}):', style: RtTypo.bodyMedium),
              Text('- S/. ${_withdrawalFee.toStringAsFixed(2)}', style: RtTypo.bodyMedium),
            ],
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recibirás:', style: RtTypo.titleLarge.copyWith(fontWeight: FontWeight.bold)),
              Text(
                'S/. ${_netAmount.toStringAsFixed(2)}',
                style: RtTypo.titleLarge.copyWith(fontWeight: FontWeight.bold, color: RtColors.success),
              ),
            ],
          ),
          const SizedBox(height: RtSpacing.sm),
          Text(
            _selectedWithdrawalMethod == 'bank_transfer'
                ? 'Tiempo de procesamiento: 24-48 horas hábiles'
                : 'Procesamiento: Instantáneo',
            style: RtTypo.labelSmall.copyWith(color: secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessWithdrawalButton() {
    final isEnabled = _withdrawalAmount >= _minWithdrawal &&
        _withdrawalAmount <= _availableForWithdrawal &&
        !_isLoading;

    return RtButton(
      label: 'Procesar Retiro${_netAmount > 0 ? ' (S/. ${_netAmount.toStringAsFixed(2)})' : ''}',
      icon: Icons.download,
      onPressed: isEnabled ? _processWithdrawal : null,
      size: RtButtonSize.large,
    );
  }

  Widget _buildHistoryTab() {
    return SingleChildScrollView(
      padding: RtSpacing.paddingBase,
      child: Column(
        children: [
          if (_withdrawalHistory.isEmpty)
            const RtEmptyState(
              icon: Icons.history,
              title: 'No tienes retiros previos',
              description: 'Tu historial de retiros aparecerá aquí',
            )
          else
            Column(
              children: _withdrawalHistory.map((withdrawal) {
                Color statusColor;
                IconData statusIcon;

                switch (withdrawal.status) {
                  case 'Completado':
                    statusColor = RtColors.success;
                    statusIcon = Icons.check_circle;
                    break;
                  case 'Procesando':
                    statusColor = RtColors.warning;
                    statusIcon = Icons.schedule;
                    break;
                  case 'Rechazado':
                    statusColor = RtColors.error;
                    statusIcon = Icons.cancel;
                    break;
                  default:
                    statusColor = RtColors.neutral500;
                    statusIcon = Icons.help;
                }

                return RtCard(
                  margin: const EdgeInsets.only(bottom: RtSpacing.sm),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: statusColor.withValues(alpha: 0.2),
                      child: Icon(statusIcon, color: statusColor),
                    ),
                    title: Text('S/. ${withdrawal.amount.toStringAsFixed(2)}', style: RtTypo.titleMedium),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${withdrawal.method} - ${withdrawal.destination}', style: RtTypo.bodySmall),
                        Text(
                          'Recibido: S/. ${withdrawal.netAmount.toStringAsFixed(2)} - '
                          '${withdrawal.createdAt.day}/${withdrawal.createdAt.month}/${withdrawal.createdAt.year}',
                          style: RtTypo.labelSmall,
                        ),
                      ],
                    ),
                    trailing: RtBadge(
                      label: withdrawal.status,
                      color: statusColor,
                      variant: RtBadgeVariant.subtle,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

// Clases de datos
class EarningsPeriod {
  final String period;
  final double earnings;
  final int trips;
  final double hours;

  EarningsPeriod({
    required this.period,
    required this.earnings,
    required this.trips,
    required this.hours,
  });
}

class WithdrawalHistory {
  final String id;
  final double amount;
  final double fee;
  final double netAmount;
  final String method;
  final String destination;
  final String status;
  final DateTime createdAt;
  final DateTime? processedAt;

  WithdrawalHistory({
    required this.id,
    required this.amount,
    required this.fee,
    required this.netAmount,
    required this.method,
    required this.destination,
    required this.status,
    required this.createdAt,
    this.processedAt,
  });
}
