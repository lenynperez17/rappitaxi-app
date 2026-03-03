import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/design/design_system.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_card.dart';
import '../../core/widgets/rt_badge.dart';
import '../../core/widgets/rt_button.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../core/widgets/rt_empty_state.dart';
import '../../core/utils/currency_formatter.dart';
import '../../utils/logger.dart';
import '../../utils/firestore_error_handler.dart';

class TransactionsHistoryScreen extends StatefulWidget {
  const TransactionsHistoryScreen({super.key});

  @override
  State<TransactionsHistoryScreen> createState() => _TransactionsHistoryScreenState();
}

class _TransactionsHistoryScreenState extends State<TransactionsHistoryScreen>
    with TickerProviderStateMixin {
  // Controladores de animacion
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  // Estado de filtros
  String _selectedFilter = 'all';
  DateTimeRange? _selectedDateRange;
  String _searchQuery = '';

  // Transacciones reales desde Firebase
  final List<Transaction> _transactions = [];

  // Resumen real calculado desde transacciones
  final Map<String, dynamic> _summary = {
    'totalEarnings': 0.0,
    'totalTrips': 0,
    'totalWithdrawals': 0.0,
    'pendingBalance': 0.0,
    'thisWeek': 0.0,
    'lastWeek': 0.0,
  };

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _slideAnimation = CurvedAnimation(parent: _slideController, curve: Curves.easeOut);

    _fadeController.forward();
    _slideController.forward();
    _loadTransactionsFromFirebase();
  }

  // Cargar transacciones reales desde Firebase
  Future<void> _loadTransactionsFromFirebase() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        AppLogger.warning('No hay usuario autenticado en transactions_history');
        setState(() => _isLoading = false);
        return;
      }

      final driverId = currentUser.uid;
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final lastWeekStart = startOfWeek.subtract(const Duration(days: 7));

      // Cargar viajes completados
      final ridesSnapshot = await FirebaseFirestore.instance
          .collection('rides')
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .limit(100)
          .get();

      // Cargar retiros
      final withdrawalsSnapshot = await FirebaseFirestore.instance
          .collection('withdrawals')
          .where('driverId', isEqualTo: driverId)
          .where('status', whereIn: ['completed', 'pending'])
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final List<Transaction> loadedTransactions = [];
      double totalEarnings = 0.0;
      int totalTrips = 0;
      double totalWithdrawals = 0.0;
      double thisWeek = 0.0;
      double lastWeek = 0.0;

      // Procesar viajes
      for (var doc in ridesSnapshot.docs) {
        final data = doc.data();
        final completedAt = (data['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final fare = (data['fare'] ?? data['estimatedFare'] ?? 0.0) as num;
        final commission = fare * 0.20;
        final netEarnings = fare - commission;

        totalEarnings += netEarnings.toDouble();
        totalTrips++;

        if (completedAt.isAfter(startOfWeek)) {
          thisWeek += netEarnings.toDouble();
        } else if (completedAt.isAfter(lastWeekStart) && completedAt.isBefore(startOfWeek)) {
          lastWeek += netEarnings.toDouble();
        }

        loadedTransactions.add(Transaction(
          id: doc.id,
          type: TransactionType.trip,
          date: completedAt,
          amount: netEarnings.toDouble(),
          status: TransactionStatus.completed,
          passenger: data['passengerName'],
          pickup: data['pickupAddress'],
          destination: data['destinationAddress'],
          distance: (data['distance'] as num?)?.toDouble(),
          duration: (data['duration'] as num?)?.toInt(),
          paymentMethod: data['paymentMethod'],
          commission: commission.toDouble(),
          netEarnings: netEarnings.toDouble(),
          tip: (data['tip'] as num?)?.toDouble(),
        ));
      }

      // Procesar retiros
      for (var doc in withdrawalsSnapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final amount = (data['amount'] ?? 0.0) as num;

        totalWithdrawals += amount.toDouble();

        loadedTransactions.add(Transaction(
          id: doc.id,
          type: TransactionType.withdrawal,
          date: createdAt,
          amount: -amount.toDouble(),
          status: data['status'] == 'completed'
              ? TransactionStatus.completed
              : TransactionStatus.pending,
          withdrawalMethod: data['method'],
          bankAccount: data['bankAccount'],
        ));
      }

      // Ordenar transacciones por fecha
      loadedTransactions.sort((a, b) => b.date.compareTo(a.date));

      final pendingBalance = totalEarnings - totalWithdrawals;

      setState(() {
        _transactions.clear();
        _transactions.addAll(loadedTransactions);
        _summary['totalEarnings'] = totalEarnings;
        _summary['totalTrips'] = totalTrips;
        _summary['totalWithdrawals'] = totalWithdrawals;
        _summary['pendingBalance'] = pendingBalance;
        _summary['thisWeek'] = thisWeek;
        _summary['lastWeek'] = lastWeek;
        _isLoading = false;
      });

      AppLogger.info('Cargadas ${loadedTransactions.length} transacciones desde Firebase');
    } catch (e) {
      AppLogger.error('Error cargando transacciones: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        RtSnackbar.show(
          context,
          message: FirestoreErrorHandler.getSpanishMessage(e),
          type: RtSnackbarType.error,
        );
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  List<Transaction> get _filteredTransactions {
    var filtered = _transactions.where((transaction) {
      if (_selectedFilter != 'all') {
        if (_selectedFilter == 'trips' && transaction.type != TransactionType.trip) return false;
        if (_selectedFilter == 'withdrawals' && transaction.type != TransactionType.withdrawal) return false;
        if (_selectedFilter == 'bonuses' && transaction.type != TransactionType.bonus) return false;
        if (_selectedFilter == 'refunds' && transaction.type != TransactionType.refund) return false;
      }

      if (_selectedDateRange != null) {
        if (transaction.date.isBefore(_selectedDateRange!.start) ||
            transaction.date.isAfter(_selectedDateRange!.end)) {
          return false;
        }
      }

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return transaction.id.toLowerCase().contains(query) ||
            (transaction.passenger?.toLowerCase().contains(query) ?? false) ||
            (transaction.pickup?.toLowerCase().contains(query) ?? false) ||
            (transaction.destination?.toLowerCase().contains(query) ?? false);
      }

      return true;
    }).toList();

    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: RtAppBar(
        title: 'Historial de Transacciones',
        variant: RtAppBarVariant.gradient,
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: RtColors.white),
            onPressed: _exportTransactions,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: RtColors.white),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: RtColors.brand))
        : Column(
            children: [
              _buildSummarySection(),
              _buildSearchBar(),
              _buildFilterChips(),
              Expanded(
                child: AnimatedBuilder(
                  animation: _fadeAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnimation.value,
                      child: _buildTransactionsList(),
                    );
                  },
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildSummarySection() {
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: RtSpacing.paddingBase,
        children: [
          _buildSummaryCard(
            'Balance Pendiente',
            (_summary['pendingBalance'] as double).toCurrency(),
            Icons.account_balance_wallet,
            RtColors.brand,
            true,
          ),
          _buildSummaryCard(
            'Total Ganado',
            (_summary['totalEarnings'] as double).toCurrency(),
            Icons.account_balance_wallet,
            RtColors.info,
            false,
          ),
          _buildSummaryCard(
            'Viajes',
            '${_summary['totalTrips']}',
            Icons.directions_car,
            RtColors.success,
            false,
          ),
          _buildSummaryCard(
            'Retiros',
            (_summary['totalWithdrawals'] as double).toCurrency(),
            Icons.money_off,
            RtColors.warning,
            false,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, bool highlight) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(50 * (1 - _slideAnimation.value), 0),
          child: Container(
            width: 140,
            margin: const EdgeInsets.only(right: RtSpacing.md),
            padding: const EdgeInsets.all(RtSpacing.md),
            decoration: BoxDecoration(
              color: highlight ? color : Theme.of(context).colorScheme.surface,
              borderRadius: RtRadius.borderLg,
              boxShadow: RtShadow.soft(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: highlight ? RtColors.white : color,
                  size: RtIconSize.sm,
                ),
                const SizedBox(height: RtSpacing.sm),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        value,
                        style: RtTypo.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: highlight
                              ? RtColors.white
                              : Theme.of(context).colorScheme.onSurface,
                          height: 1.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        style: RtTypo.labelSmall.copyWith(
                          color: highlight
                              ? RtColors.white.withValues(alpha: 0.70)
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          height: 1.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    final secondaryText = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: RtSpacing.base),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: RtSpacing.base),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: RtRadius.borderMd,
          boxShadow: RtShadow.soft(),
        ),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Buscar por ID, pasajero o dirección...',
            border: InputBorder.none,
            icon: Icon(Icons.search, color: secondaryText),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
          ),
          onChanged: (value) {
            setState(() => _searchQuery = value);
          },
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: RtSpacing.base, vertical: RtSpacing.sm),
        children: [
          _buildFilterChip('Todos', 'all', Icons.list),
          _buildFilterChip('Viajes', 'trips', Icons.directions_car),
          _buildFilterChip('Retiros', 'withdrawals', Icons.money_off),
          _buildFilterChip('Bonos', 'bonuses', Icons.card_giftcard),
          _buildFilterChip('Reembolsos', 'refunds', Icons.replay),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _selectedFilter == value;
    final secondaryText = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.only(right: RtSpacing.sm),
      child: FilterChip(
        selected: isSelected,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: RtIconSize.xs,
              color: isSelected ? RtColors.white : secondaryText,
            ),
            const SizedBox(width: RtSpacing.xs),
            Text(label),
          ],
        ),
        onSelected: (selected) {
          setState(() => _selectedFilter = value);
        },
        selectedColor: RtColors.brand,
        checkmarkColor: RtColors.white,
        labelStyle: RtTypo.labelSmall.copyWith(
          color: isSelected ? RtColors.white : secondaryText,
        ),
      ),
    );
  }

  Widget _buildTransactionsList() {
    if (_filteredTransactions.isEmpty) {
      return const RtEmptyState(
        icon: Icons.receipt_long,
        title: 'No hay transacciones',
        description: 'Tus transacciones aparecerán aquí',
      );
    }

    // Agrupar transacciones por fecha
    Map<String, List<Transaction>> groupedTransactions = {};
    for (var transaction in _filteredTransactions) {
      final dateKey = _getDateKey(transaction.date);
      if (!groupedTransactions.containsKey(dateKey)) {
        groupedTransactions[dateKey] = [];
      }
      groupedTransactions[dateKey]!.add(transaction);
    }

    return ListView.builder(
      padding: RtSpacing.paddingBase,
      itemCount: groupedTransactions.length,
      itemBuilder: (context, index) {
        final dateKey = groupedTransactions.keys.elementAt(index);
        final transactions = groupedTransactions[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: RtSpacing.sm),
              child: Text(
                dateKey,
                style: RtTypo.titleMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            ...transactions.map((transaction) => _buildTransactionCard(transaction)),
          ],
        );
      },
    );
  }

  Widget _buildTransactionCard(Transaction transaction) {
    final secondaryText = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return RtCard(
      margin: const EdgeInsets.only(bottom: RtSpacing.md),
      onTap: () => _showTransactionDetails(transaction),
      child: Row(
        children: [
          // Icono de transacción
          Container(
            padding: const EdgeInsets.all(RtSpacing.md),
            decoration: BoxDecoration(
              color: _getTransactionColor(transaction.type).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getTransactionIcon(transaction.type),
              color: _getTransactionColor(transaction.type),
              size: RtIconSize.md,
            ),
          ),
          const SizedBox(width: RtSpacing.md),

          // Detalles de la transacción
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getTransactionTitle(transaction),
                  style: RtTypo.titleLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: RtSpacing.xs),
                Text(
                  _getTransactionSubtitle(transaction),
                  style: RtTypo.bodySmall.copyWith(color: secondaryText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (transaction.status == TransactionStatus.cancelled)
                  Padding(
                    padding: const EdgeInsets.only(top: RtSpacing.xs),
                    child: RtBadge(
                      label: 'Cancelado',
                      color: RtColors.error,
                      variant: RtBadgeVariant.subtle,
                    ),
                  ),
              ],
            ),
          ),

          // Monto
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${transaction.amount >= 0 ? '+' : ''}${transaction.amount.abs().toCurrency()}',
                style: RtTypo.headingSmall.copyWith(
                  color: transaction.amount >= 0 ? RtColors.success : RtColors.error,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (transaction.netEarnings != null)
                Text(
                  'Neto: ${transaction.netEarnings!.toCurrency()}',
                  style: RtTypo.labelSmall.copyWith(color: secondaryText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              Text(
                _formatTime(transaction.date),
                style: RtTypo.labelSmall.copyWith(color: secondaryText),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Hoy';
    } else if (dateOnly == yesterday) {
      return 'Ayer';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  IconData _getTransactionIcon(TransactionType type) {
    switch (type) {
      case TransactionType.trip:
        return Icons.directions_car;
      case TransactionType.withdrawal:
        return Icons.money_off;
      case TransactionType.bonus:
        return Icons.card_giftcard;
      case TransactionType.refund:
        return Icons.replay;
      case TransactionType.commission:
        return Icons.percent;
    }
  }

  Color _getTransactionColor(TransactionType type) {
    switch (type) {
      case TransactionType.trip:
        return RtColors.info;
      case TransactionType.withdrawal:
        return RtColors.warning;
      case TransactionType.bonus:
        return RtColors.brand;
      case TransactionType.refund:
        return RtColors.error;
      case TransactionType.commission:
        return RtColors.accentPurple;
    }
  }

  String _getTransactionTitle(Transaction transaction) {
    switch (transaction.type) {
      case TransactionType.trip:
        return transaction.passenger ?? 'Viaje';
      case TransactionType.withdrawal:
        return 'Retiro';
      case TransactionType.bonus:
        return transaction.bonusType ?? 'Bono';
      case TransactionType.refund:
        return 'Reembolso';
      case TransactionType.commission:
        return 'Comisión';
    }
  }

  String _getTransactionSubtitle(Transaction transaction) {
    switch (transaction.type) {
      case TransactionType.trip:
        if (transaction.status == TransactionStatus.cancelled) {
          return transaction.cancellationReason ?? 'Viaje cancelado';
        }
        return '${transaction.pickup} -> ${transaction.destination}';
      case TransactionType.withdrawal:
        return transaction.withdrawalMethod ?? 'Retiro de fondos';
      case TransactionType.bonus:
        return transaction.description ?? '';
      case TransactionType.refund:
        return transaction.refundReason ?? '';
      case TransactionType.commission:
        return 'Comisión de plataforma';
    }
  }

  void _showTransactionDetails(Transaction transaction) {
    final secondaryText = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: RtRadius.sheetTop,
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: RtSpacing.md),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: RtColors.neutral300,
                borderRadius: RtRadius.borderFull,
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(RtSpacing.lg),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(RtSpacing.md),
                    decoration: BoxDecoration(
                      color: _getTransactionColor(transaction.type).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getTransactionIcon(transaction.type),
                      color: _getTransactionColor(transaction.type),
                      size: RtIconSize.lg,
                    ),
                  ),
                  const SizedBox(width: RtSpacing.base),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_getTransactionTitle(transaction), style: RtTypo.headingMedium),
                        Text(
                          'ID: ${transaction.id}',
                          style: RtTypo.bodySmall.copyWith(color: secondaryText),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${transaction.amount >= 0 ? '+' : ''}${transaction.amount.abs().toCurrency()}',
                    style: RtTypo.displaySmall.copyWith(
                      color: transaction.amount >= 0 ? RtColors.success : RtColors.error,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(),

            // Detalles
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(RtSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (transaction.type == TransactionType.trip) ...[
                      _buildDetailSection('Información del Viaje', [
                        _buildDetailRow('Pasajero', transaction.passenger ?? '', secondaryText),
                        _buildDetailRow('Recogida', transaction.pickup ?? '', secondaryText),
                        _buildDetailRow('Destino', transaction.destination ?? '', secondaryText),
                        _buildDetailRow('Distancia', '${transaction.distance ?? 0} km', secondaryText),
                        _buildDetailRow('Duracion', '${transaction.duration ?? 0} min', secondaryText),
                      ]),
                      const SizedBox(height: RtSpacing.lg),
                      _buildDetailSection('Detalles Financieros', [
                        _buildDetailRow('Tarifa', transaction.amount.toCurrency(), secondaryText),
                        if (transaction.tip != null)
                          _buildDetailRow('Propina', transaction.tip!.toCurrency(), secondaryText),
                        _buildDetailRow('Comisión (-20%)', (transaction.commission ?? 0).toCurrency(), secondaryText),
                        const Divider(),
                        _buildDetailRow('Ganancia Neta', (transaction.netEarnings ?? 0).toCurrency(), secondaryText, bold: true),
                      ]),
                      const SizedBox(height: RtSpacing.lg),
                      _buildDetailSection('Pago', [
                        _buildDetailRow('Método', transaction.paymentMethod ?? '', secondaryText),
                        _buildDetailRow('Estado', transaction.status == TransactionStatus.completed ? 'Completado' : 'Cancelado', secondaryText),
                      ]),
                    ],

                    if (transaction.type == TransactionType.withdrawal) ...[
                      _buildDetailSection('Detalles del Retiro', [
                        _buildDetailRow('Monto', transaction.amount.abs().toCurrency(), secondaryText),
                        _buildDetailRow('Método', transaction.withdrawalMethod ?? '', secondaryText),
                        _buildDetailRow('Cuenta', transaction.bankAccount ?? '', secondaryText),
                        _buildDetailRow('Estado', 'Completado', secondaryText),
                      ]),
                    ],

                    if (transaction.type == TransactionType.bonus) ...[
                      _buildDetailSection('Detalles del Bono', [
                        _buildDetailRow('Tipo', transaction.bonusType ?? '', secondaryText),
                        _buildDetailRow('Descripción', transaction.description ?? '', secondaryText),
                        _buildDetailRow('Monto', transaction.amount.toCurrency(), secondaryText),
                      ]),
                    ],

                    const SizedBox(height: RtSpacing.lg),
                    _buildDetailSection('Información General', [
                      _buildDetailRow('Fecha', '${transaction.date.day}/${transaction.date.month}/${transaction.date.year}', secondaryText),
                      _buildDetailRow('Hora', _formatTime(transaction.date), secondaryText),
                      _buildDetailRow('ID Transacción', transaction.id, secondaryText),
                    ]),
                  ],
                ),
              ),
            ),

            // Acciones
            Padding(
              padding: const EdgeInsets.all(RtSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: RtButton(
                      label: 'Compartir',
                      icon: Icons.share,
                      onPressed: () {
                        Navigator.pop(context);
                        _shareTransaction(transaction);
                      },
                    ),
                  ),
                  const SizedBox(width: RtSpacing.md),
                  Expanded(
                    child: RtButton(
                      label: 'Reportar',
                      icon: Icons.report,
                      variant: RtButtonVariant.danger,
                      onPressed: () {
                        Navigator.pop(context);
                        _reportIssue(transaction);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: RtTypo.titleLarge.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: RtSpacing.md),
        Container(
          padding: const EdgeInsets.all(RtSpacing.md),
          decoration: BoxDecoration(
            color: RtColors.neutral100,
            borderRadius: RtRadius.borderMd,
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, Color secondaryColor, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RtSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: RtTypo.bodyMedium.copyWith(
                color: secondaryColor,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: RtSpacing.sm),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: RtTypo.bodyMedium.copyWith(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: bold ? RtColors.brand : Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrar Transacciones'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.date_range),
              title: Text(_selectedDateRange != null
                  ? '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}'
                  : 'Seleccionar rango de fechas'),
              onTap: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now(),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(primary: RtColors.brand),
                      ),
                      child: child!,
                    );
                  },
                );
                if (range != null) {
                  setState(() => _selectedDateRange = range);
                }
              },
            ),
            if (_selectedDateRange != null)
              TextButton(
                onPressed: () {
                  setState(() => _selectedDateRange = null);
                },
                child: const Text('Limpiar fechas'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: RtColors.brand),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  void _exportTransactions() async {
    try {
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

      if (format == 'csv') {
        await _exportToCSV();
      } else if (format == 'pdf') {
        await _exportToPDF();
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

  Future<void> _exportToCSV() async {
    try {
      final List<List<dynamic>> csvData = [
        ['HISTORIAL DE TRANSACCIONES - RAPITEAM'],
        ['Fecha de generacion', DateTime.now().toString().split('.')[0]],
        [],
        ['RESUMEN'],
        ['Metrica', 'Valor'],
        ['Total Transacciones', _filteredTransactions.length],
        ['Balance Pendiente', (_summary['pendingBalance'] as double).toCurrency()],
        ['Total Ganado', (_summary['totalEarnings'] as double).toCurrency()],
        ['Total Viajes', _summary['totalTrips']],
        ['Total Retiros', (_summary['totalWithdrawals'] as double).toCurrency()],
        [],
        ['DETALLE DE TRANSACCIONES'],
        ['ID', 'Fecha', 'Hora', 'Tipo', 'Pasajero', 'Pickup', 'Destino', 'Monto', 'Método Pago', 'Estado'],
      ];

      if (_filteredTransactions.isEmpty) {
        csvData.add(['No hay transacciones registradas']);
      } else {
        for (var transaction in _filteredTransactions) {
          final sign = transaction.amount >= 0 ? '+' : '-';
          final amountValue = transaction.amount.abs().toCurrency();
          csvData.add([
            transaction.id,
            _getDateKey(transaction.date),
            _formatTime(transaction.date),
            _getTransactionTitle(transaction),
            transaction.passenger ?? 'N/A',
            transaction.pickup ?? 'N/A',
            transaction.destination ?? 'N/A',
            '$sign$amountValue',
            transaction.paymentMethod ?? 'N/A',
            transaction.status == TransactionStatus.completed ? 'Completado' : 'Cancelado',
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
      RtSnackbar.show(context, message: 'Archivo CSV generado exitosamente', type: RtSnackbarType.success);
    } catch (e) {
      if (!mounted) return;
      RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
    }
  }

  Future<void> _exportToPDF() async {
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
                    pw.Text('HISTORIAL DE TRANSACCIONES', style: pw.TextStyle(font: ttfBold, color: PdfColors.white, fontSize: 24)),
                    pw.SizedBox(height: 8),
                    pw.Text('RAPITEAM', style: pw.TextStyle(font: ttfRegular, color: PdfColors.white, fontSize: 16)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Fecha de generacion: ${DateTime.now().toString().split('.')[0]}', style: pw.TextStyle(font: ttfRegular, fontSize: 12)),
              pw.SizedBox(height: 20),
              pw.Text('RESUMEN', style: pw.TextStyle(font: ttfBold, fontSize: 16)),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  _buildPdfRow('Total Transacciones', '${_filteredTransactions.length}', true, ttfRegular, ttfBold),
                  _buildPdfRow('Balance Pendiente', (_summary['pendingBalance'] as double).toCurrency(), false, ttfRegular, ttfBold),
                  _buildPdfRow('Total Ganado', (_summary['totalEarnings'] as double).toCurrency(), true, ttfRegular, ttfBold),
                  _buildPdfRow('Total Viajes', '${_summary['totalTrips']}', false, ttfRegular, ttfBold),
                  _buildPdfRow('Total Retiros', (_summary['totalWithdrawals'] as double).toCurrency(), true, ttfRegular, ttfBold),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text('DETALLE DE TRANSACCIONES', style: pw.TextStyle(font: ttfBold, fontSize: 16)),
              pw.SizedBox(height: 10),
              if (_filteredTransactions.isEmpty)
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
                        _buildPdfHeaderCell('Descripción', ttfBold),
                        _buildPdfHeaderCell('Fecha', ttfBold),
                        _buildPdfHeaderCell('Monto', ttfBold),
                      ],
                    ),
                    ..._filteredTransactions.take(50).map((transaction) {
                      final sign = transaction.amount >= 0 ? '+' : '-';
                      final amountValue = transaction.amount.abs().toCurrency();
                      return pw.TableRow(
                        children: [
                          _buildPdfCell(_getTransactionTitle(transaction), ttfRegular),
                          _buildPdfCell(_getDateKey(transaction.date), ttfRegular),
                          _buildPdfCell('$sign$amountValue', ttfRegular),
                        ],
                      );
                    }),
                  ],
                ),
              if (_filteredTransactions.length > 50)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 10),
                  child: pw.Text(
                    'Mostrando las primeras 50 transacciones de ${_filteredTransactions.length} totales',
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
      RtSnackbar.show(context, message: 'Archivo PDF generado exitosamente', type: RtSnackbarType.success);
    } catch (e) {
      if (!mounted) return;
      RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
    }
  }

  // Helpers para generar tabla PDF
  pw.TableRow _buildPdfRow(String label, String value, bool isEven, pw.Font fontRegular, pw.Font fontBold) {
    return pw.TableRow(
      decoration: isEven ? pw.BoxDecoration(color: PdfColors.grey100) : null,
      children: [
        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(label, style: pw.TextStyle(font: fontRegular))),
        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(value, style: pw.TextStyle(font: fontBold))),
      ],
    );
  }

  pw.Widget _buildPdfHeaderCell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text, style: pw.TextStyle(font: font, color: PdfColors.white, fontSize: 10)),
    );
  }

  pw.Widget _buildPdfCell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 9)),
    );
  }

  void _shareTransaction(Transaction transaction) {
    RtSnackbar.show(context, message: 'Compartiendo transacción ${transaction.id}', type: RtSnackbarType.info);
  }

  void _reportIssue(Transaction transaction) {
    RtSnackbar.show(context, message: 'Reportando problema con ${transaction.id}', type: RtSnackbarType.warning);
  }
}

// Modelo de transacción
class Transaction {
  final String id;
  final TransactionType type;
  final DateTime date;
  final double amount;
  final TransactionStatus status;

  // Detalles del viaje
  final String? passenger;
  final String? pickup;
  final String? destination;
  final double? distance;
  final int? duration;
  final String? paymentMethod;
  final double? commission;
  final double? netEarnings;
  final double? tip;

  // Detalles del retiro
  final String? withdrawalMethod;
  final String? bankAccount;

  // Detalles del bono
  final String? bonusType;
  final String? description;

  // Detalles de reembolso
  final String? refundReason;
  final String? originalTransaction;

  // Detalles de cancelación
  final String? cancellationReason;
  final double? cancellationFee;

  Transaction({
    required this.id,
    required this.type,
    required this.date,
    required this.amount,
    required this.status,
    this.passenger,
    this.pickup,
    this.destination,
    this.distance,
    this.duration,
    this.paymentMethod,
    this.commission,
    this.netEarnings,
    this.tip,
    this.withdrawalMethod,
    this.bankAccount,
    this.bonusType,
    this.description,
    this.refundReason,
    this.originalTransaction,
    this.cancellationReason,
    this.cancellationFee,
  });
}

enum TransactionType { trip, withdrawal, bonus, refund, commission }
enum TransactionStatus { completed, pending, cancelled }
