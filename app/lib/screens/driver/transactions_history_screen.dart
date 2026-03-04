// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
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
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart'; // ✅ Extensión para colores que se adaptan al tema
import '../../core/utils/currency_formatter.dart';
import '../../utils/logger.dart';

class TransactionsHistoryScreen extends StatefulWidget {
  const TransactionsHistoryScreen({super.key});

  @override
  _TransactionsHistoryScreenState createState() => _TransactionsHistoryScreenState();
}

class _TransactionsHistoryScreenState extends State<TransactionsHistoryScreen> 
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  
  // Filter state
  String _selectedFilter = 'all';
  DateTimeRange? _selectedDateRange;
  String _searchQuery = '';

  // ✅ Transacciones reales desde Firebase (inicialmente vacío)
  final List<Transaction> _transactions = [];

  // ✅ Resumen real calculado desde transacciones (inicialmente 0)
  final Map<String, dynamic> _summary = {
    'totalEarnings': 0.0,
    'totalTrips': 0,
    'totalWithdrawals': 0.0,
    'pendingBalance': 0.0,
    'thisWeek': 0.0,
    'lastWeek': 0.0,
  };

  // ✅ Loading state
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    );
    
    _fadeController.forward();
    _slideController.forward();

    // ✅ Cargar transacciones desde Firebase
    _loadTransactionsFromFirebase();
  }

  // ✅ NUEVO: Cargar transacciones reales desde Firebase
  Future<void> _loadTransactionsFromFirebase() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        AppLogger.warning('⚠️ No hay usuario autenticado en transactions_history');
        setState(() => _isLoading = false);
        return;
      }

      final driverId = currentUser.uid;
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final lastWeekStart = startOfWeek.subtract(Duration(days: 7));

      // ✅ Cargar viajes completados
      final ridesSnapshot = await FirebaseFirestore.instance
          .collection('rides')
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .limit(100)
          .get();

      // ✅ Cargar retiros
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

      // ✅ Procesar viajes
      for (var doc in ridesSnapshot.docs) {
        final data = doc.data();
        final completedAt = (data['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final fare = (data['fare'] ?? data['estimatedFare'] ?? 0.0) as num;
        final commission = fare * 0.20; // 20% comisión
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

      // ✅ Procesar retiros
      for (var doc in withdrawalsSnapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final amount = (data['amount'] ?? 0.0) as num;

        totalWithdrawals += amount.toDouble();

        loadedTransactions.add(Transaction(
          id: doc.id,
          type: TransactionType.withdrawal,
          date: createdAt,
          amount: -amount.toDouble(), // Negativo porque es un retiro
          status: data['status'] == 'completed'
              ? TransactionStatus.completed
              : TransactionStatus.pending,
          withdrawalMethod: data['method'],
          bankAccount: data['bankAccount'],
        ));
      }

      // ✅ Ordenar transacciones por fecha (más reciente primero)
      loadedTransactions.sort((a, b) => b.date.compareTo(a.date));

      // ✅ Calcular balance pendiente
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

      AppLogger.info('✅ Cargadas ${loadedTransactions.length} transacciones desde Firebase');
    } catch (e) {
      AppLogger.error('❌ Error cargando transacciones: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cargando transacciones: $e'),
            backgroundColor: ModernTheme.error,
          ),
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
      // Filter by type
      if (_selectedFilter != 'all') {
        if (_selectedFilter == 'trips' && transaction.type != TransactionType.trip) return false;
        if (_selectedFilter == 'withdrawals' && transaction.type != TransactionType.withdrawal) return false;
        if (_selectedFilter == 'bonuses' && transaction.type != TransactionType.bonus) return false;
        if (_selectedFilter == 'refunds' && transaction.type != TransactionType.refund) return false;
      }
      
      // Filter by date range
      if (_selectedDateRange != null) {
        if (transaction.date.isBefore(_selectedDateRange!.start) ||
            transaction.date.isAfter(_selectedDateRange!.end)) {
          return false;
        }
      }
      
      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return transaction.id.toLowerCase().contains(query) ||
               (transaction.passenger?.toLowerCase().contains(query) ?? false) ||
               (transaction.pickup?.toLowerCase().contains(query) ?? false) ||
               (transaction.destination?.toLowerCase().contains(query) ?? false);
      }
      
      return true;
    }).toList();
    
    // Sort by date (newest first)
    filtered.sort((a, b) => b.date.compareTo(a.date));
    
    return filtered;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceColor,
      appBar: AppBar(
        backgroundColor: ModernTheme.rappiOrange,
        elevation: 0,
        title: Text(
          'Historial de Transacciones',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.download, color: Theme.of(context).colorScheme.onPrimary),
            onPressed: _exportTransactions,
          ),
          IconButton(
            icon: Icon(Icons.filter_list, color: Theme.of(context).colorScheme.onPrimary),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary cards
          _buildSummarySection(),

          // Advanced filter bar: dropdown + calendar picker + search
          _buildAdvancedFilterBar(),

          // Transactions list
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
        padding: EdgeInsets.all(16),
        children: [
          _buildSummaryCard(
            'Balance Pendiente',
            ((_summary['pendingBalance'] as num).toDouble()).toCurrency(),
            Icons.account_balance_wallet,
            ModernTheme.rappiOrange,
            true,
          ),
          _buildSummaryCard(
            'Total Ganado',
            ((_summary['totalEarnings'] as num).toDouble()).toCurrency(),
            Icons.account_balance_wallet, // ✅ Cambiado de attach_money ($) a wallet
            ModernTheme.primaryBlue,
            false,
          ),
          _buildSummaryCard(
            'Viajes',
            '${_summary['totalTrips']}',
            Icons.directions_car,
            Theme.of(context).colorScheme.tertiary,
            false,
          ),
          _buildSummaryCard(
            'Retiros',
            ((_summary['totalWithdrawals'] as num).toDouble()).toCurrency(),
            Icons.money_off,
            Theme.of(context).colorScheme.secondary,
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
            margin: EdgeInsets.only(right: 12),
            padding: EdgeInsets.all(12), // ✅ CORRECCIÓN: Reducir padding de 16 a 12
            decoration: BoxDecoration(
              color: highlight ? color : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: ModernTheme.getCardShadow(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: highlight ? Theme.of(context).colorScheme.onPrimary : color,
                  size: 22, // ✅ CORRECCIÓN: Reducir de 24 a 22
                ),
                SizedBox(height: 6), // ✅ CORRECCIÓN: Reducir de 8 a 6
                Flexible( // ✅ CRÍTICO: Envolver en Flexible para permitir ajuste
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 16, // ✅ CORRECCIÓN: Reducir de 18 a 16
                          fontWeight: FontWeight.bold,
                          color: highlight ? Theme.of(context).colorScheme.onPrimary : context.primaryText,
                          height: 1.2, // ✅ CRÍTICO: Reducir line-height
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1, // ✅ CRÍTICO: Limitar a 1 línea
                      ),
                      SizedBox(height: 2),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 9, // ✅ CORRECCIÓN: Reducir de 10 a 9
                          color: highlight ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.70) : context.secondaryText,
                          height: 1.2, // ✅ CRÍTICO: Reducir line-height
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1, // ✅ CRÍTICO: Limitar a 1 línea
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
  
  Widget _buildAdvancedFilterBar() {
    return Material(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: search + calendar button
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ModernTheme.rappiOrange.withValues(alpha: 0.25)),
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar transaccion...',
                        hintStyle: TextStyle(color: context.secondaryText, fontSize: 13),
                        prefixIcon: Icon(Icons.search, color: ModernTheme.rappiOrange, size: 18),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onChanged: (value) => setState(() => _searchQuery = value),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Calendar picker button
                GestureDetector(
                  onTap: () async {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now(),
                      initialDateRange: _selectedDateRange,
                      builder: (ctx, child) => Theme(
                        data: Theme.of(ctx).copyWith(
                          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                            primary: ModernTheme.rappiOrange,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (range != null) setState(() => _selectedDateRange = range);
                  },
                  child: Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: _selectedDateRange != null
                          ? ModernTheme.rappiOrange
                          : ModernTheme.rappiOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.calendar_month,
                      color: _selectedDateRange != null ? Colors.white : ModernTheme.rappiOrange,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            if (_selectedDateRange != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.date_range, size: 14, color: ModernTheme.rappiOrange),
                  const SizedBox(width: 4),
                  Text(
                    '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month} – '
                    '${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}',
                    style: TextStyle(fontSize: 12, color: ModernTheme.rappiOrange),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _selectedDateRange = null),
                    child: Icon(Icons.close, size: 14, color: ModernTheme.rappiOrange),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            // Row 2: type dropdown chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Todos', 'all', Icons.list),
                  const SizedBox(width: 6),
                  _buildFilterChip('Viajes', 'trips', Icons.directions_car),
                  const SizedBox(width: 6),
                  _buildFilterChip('Retiros', 'withdrawals', Icons.money_off),
                  const SizedBox(width: 6),
                  _buildFilterChip('Bonos', 'bonuses', Icons.card_giftcard),
                  const SizedBox(width: 6),
                  _buildFilterChip('Reembolsos', 'refunds', Icons.replay),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Buscar por ID, pasajero o dirección...',
            border: InputBorder.none,
            icon: Icon(Icons.search, color: context.secondaryText),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, size: 20),
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
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Theme.of(context).colorScheme.onPrimary : context.secondaryText,
            ),
            SizedBox(width: 4),
            Text(label),
          ],
        ),
        onSelected: (selected) {
          setState(() => _selectedFilter = value);
        },
        selectedColor: ModernTheme.rappiOrange,
        checkmarkColor: Theme.of(context).colorScheme.onPrimary,
        labelStyle: TextStyle(
          color: isSelected ? Theme.of(context).colorScheme.onPrimary : context.secondaryText,
        ),
      ),
    );
  }
  
  Widget _buildTransactionsList() {
    if (_filteredTransactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 64,
              color: context.secondaryText.withValues(alpha: 0.5),
            ),
            SizedBox(height: 16),
            Text(
              'No hay transacciones',
              style: TextStyle(
                color: context.secondaryText,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
    
    // Group transactions by date
    Map<String, List<Transaction>> groupedTransactions = {};
    for (var transaction in _filteredTransactions) {
      final dateKey = _getDateKey(transaction.date);
      if (!groupedTransactions.containsKey(dateKey)) {
        groupedTransactions[dateKey] = [];
      }
      groupedTransactions[dateKey]!.add(transaction);
    }
    
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: groupedTransactions.length,
      itemBuilder: (context, index) {
        final dateKey = groupedTransactions.keys.elementAt(index);
        final transactions = groupedTransactions[dateKey]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                dateKey,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: context.secondaryText,
                ),
              ),
            ),
            // Transactions for this date
            ...transactions.map((transaction) => _buildTransactionCard(transaction)),
          ],
        );
      },
    );
  }
  
  Widget _buildTransactionCard(Transaction transaction) {
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
              // Transaction icon
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getTransactionColor(transaction.type).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getTransactionIcon(transaction.type),
                  color: _getTransactionColor(transaction.type),
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              
              // Transaction details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getTransactionTitle(transaction),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      _getTransactionSubtitle(transaction),
                      style: TextStyle(
                        color: context.secondaryText,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (transaction.status == TransactionStatus.cancelled)
                      Container(
                        margin: EdgeInsets.only(top: 4),
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: ModernTheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Cancelado',
                          style: TextStyle(
                            color: ModernTheme.error,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${transaction.amount >= 0 ? '+' : ''}${transaction.amount.abs().toCurrency()}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: transaction.amount >= 0 ? ModernTheme.success : ModernTheme.error,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (transaction.netEarnings != null)
                    Text(
                      'Neto: ${transaction.netEarnings!.toCurrency()}',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.secondaryText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    _formatTime(transaction.date),
                    style: TextStyle(
                      fontSize: 11,
                      color: context.secondaryText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return 'Hoy';
    if (dateOnly == yesterday) return 'Ayer';

    // Group by week
    final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
    final lastWeekEnd = thisWeekStart.subtract(const Duration(days: 1));

    if (dateOnly.isAfter(thisWeekStart.subtract(const Duration(days: 1))) &&
        dateOnly.isBefore(today)) {
      return 'Esta semana';
    } else if (dateOnly.isAfter(lastWeekStart.subtract(const Duration(days: 1))) &&
        dateOnly.isBefore(lastWeekEnd.add(const Duration(days: 1)))) {
      return 'Semana pasada';
    } else {
      // Older: group by "Semana del dd/MM"
      final weekStart = dateOnly.subtract(Duration(days: dateOnly.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));
      return 'Sem. ${weekStart.day}/${weekStart.month} – ${weekEnd.day}/${weekEnd.month}';
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
        return ModernTheme.primaryBlue;
      case TransactionType.withdrawal:
        return Theme.of(context).colorScheme.secondary;
      case TransactionType.bonus:
        return ModernTheme.rappiOrange;
      case TransactionType.refund:
        return ModernTheme.error;
      case TransactionType.commission:
        return Theme.of(context).colorScheme.tertiary;
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
        return '${transaction.pickup} → ${transaction.destination}';
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.0),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Container(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getTransactionColor(transaction.type).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getTransactionIcon(transaction.type),
                      color: _getTransactionColor(transaction.type),
                      size: 28,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getTransactionTitle(transaction),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'ID: ${transaction.id}',
                          style: TextStyle(
                            color: context.secondaryText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${transaction.amount >= 0 ? '+' : ''}${transaction.amount.abs().toCurrency()}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: transaction.amount >= 0 ? ModernTheme.success : ModernTheme.error,
                    ),
                  ),
                ],
              ),
            ),
            
            Divider(),
            
            // Details
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (transaction.type == TransactionType.trip) ...[
                      _buildDetailSection('Información del Viaje', [
                        _buildDetailRow('Pasajero', transaction.passenger ?? ''),
                        _buildDetailRow('Recogida', transaction.pickup ?? ''),
                        _buildDetailRow('Destino', transaction.destination ?? ''),
                        _buildDetailRow('Distancia', '${transaction.distance ?? 0} km'),
                        _buildDetailRow('Duración', '${transaction.duration ?? 0} min'),
                      ]),
                      SizedBox(height: 20),
                      _buildDetailSection('Detalles Financieros', [
                        _buildDetailRow('Tarifa', transaction.amount.toCurrency()),
                        if (transaction.tip != null)
                          _buildDetailRow('Propina', transaction.tip!.toCurrency()),
                        _buildDetailRow('Comisión (-20%)', (transaction.commission ?? 0).toCurrency()),
                        Divider(),
                        _buildDetailRow('Ganancia Neta', (transaction.netEarnings ?? 0).toCurrency(), bold: true),
                      ]),
                      SizedBox(height: 20),
                      _buildDetailSection('Pago', [
                        _buildDetailRow('Método', transaction.paymentMethod ?? ''),
                        _buildDetailRow('Estado', transaction.status == TransactionStatus.completed ? 'Completado' : 'Cancelado'),
                      ]),
                    ],
                    
                    if (transaction.type == TransactionType.withdrawal) ...[
                      _buildDetailSection('Detalles del Retiro', [
                        _buildDetailRow('Monto', transaction.amount.abs().toCurrency()),
                        _buildDetailRow('Método', transaction.withdrawalMethod ?? ''),
                        _buildDetailRow('Cuenta', transaction.bankAccount ?? ''),
                        _buildDetailRow('Estado', 'Completado'),
                      ]),
                    ],
                    
                    if (transaction.type == TransactionType.bonus) ...[
                      _buildDetailSection('Detalles del Bono', [
                        _buildDetailRow('Tipo', transaction.bonusType ?? ''),
                        _buildDetailRow('Descripción', transaction.description ?? ''),
                        _buildDetailRow('Monto', transaction.amount.toCurrency()),
                      ]),
                    ],
                    
                    SizedBox(height: 20),
                    _buildDetailSection('Información General', [
                      _buildDetailRow('Fecha', '${transaction.date.day}/${transaction.date.month}/${transaction.date.year}'),
                      _buildDetailRow('Hora', _formatTime(transaction.date)),
                      _buildDetailRow('ID Transacción', transaction.id),
                    ]),
                  ],
                ),
              ),
            ),
            
            // Actions
            Container(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _shareTransaction(transaction);
                      },
                      icon: Icon(Icons.share),
                      label: Text('Compartir'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ModernTheme.primaryBlue,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _reportIssue(transaction);
                      },
                      icon: Icon(Icons.report),
                      label: Text('Reportar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ModernTheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: context.primaryText,
          ),
        ),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
  
  Widget _buildDetailRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: context.secondaryText,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          SizedBox(width: 8), // ✅ Espaciado entre label y value
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: bold ? ModernTheme.rappiOrange : context.primaryText,
              ),
              textAlign: TextAlign.right, // ✅ Alinear a la derecha
              overflow: TextOverflow.ellipsis, // ✅ Cortar texto largo con ...
              maxLines: 1, // ✅ Forzar una sola línea
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
        title: Text('Filtrar Transacciones'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Date range picker button
            ListTile(
              leading: Icon(Icons.date_range),
              title: Text(_selectedDateRange != null 
                  ? '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}'
                  : 'Seleccionar rango de fechas'),
              onTap: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime.now().subtract(Duration(days: 365)),
                  lastDate: DateTime.now(),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(
                          primary: ModernTheme.rappiOrange,
                        ),
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
                child: Text('Limpiar fechas'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.rappiOrange,
            ),
            child: Text('Aplicar'),
          ),
        ],
      ),
    );
  }
  
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

      // Exportar según formato
      if (format == 'csv') {
        await _exportToCSV();
      } else if (format == 'pdf') {
        await _exportToPDF();
      }

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

  Future<void> _exportToCSV() async {
    try {
      // Generar archivo CSV de transacciones
      final List<List<dynamic>> csvData = [
        ['HISTORIAL DE TRANSACCIONES - RAPPI TEAM'],
        ['Fecha de generación', DateTime.now().toString().split('.')[0]],
        [],
        ['RESUMEN'],
        ['Métrica', 'Valor'],
        ['Total Transacciones', _filteredTransactions.length],
        ['Balance Pendiente', ((_summary['pendingBalance'] as num).toDouble()).toCurrency()],
        ['Total Ganado', ((_summary['totalEarnings'] as num).toDouble()).toCurrency()],
        ['Total Viajes', _summary['totalTrips']],
        ['Total Retiros', ((_summary['totalWithdrawals'] as num).toDouble()).toCurrency()],
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
          final passengerName = transaction.passenger ?? 'N/A';
          final pickupLocation = transaction.pickup ?? 'N/A';
          final destinationLocation = transaction.destination ?? 'N/A';
          final paymentMethodType = transaction.paymentMethod ?? 'N/A';
          final statusText = transaction.status == TransactionStatus.completed ? 'Completado' : 'Cancelado';

          csvData.add([
            transaction.id,
            _getDateKey(transaction.date),
            _formatTime(transaction.date),
            _getTransactionTitle(transaction),
            passengerName,
            pickupLocation,
            destinationLocation,
            '$sign$amountValue',
            paymentMethodType,
            statusText,
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

  Future<void> _exportToPDF() async {
    try {
      // Cargar fuentes custom con soporte Unicode completo
      final fontRegular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final fontBold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      final ttfRegular = pw.Font.ttf(fontRegular);
      final ttfBold = pw.Font.ttf(fontBold);

      // Generar archivo PDF de transacciones
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
                        font: ttfBold,
                        color: PdfColors.white,
                        fontSize: 24,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'RAPPI TEAM',
                      style: pw.TextStyle(
                        font: ttfRegular,
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
                  font: ttfBold,
                  fontSize: 16,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  _buildPdfRow('Total Transacciones', '${_filteredTransactions.length}', true, ttfRegular, ttfBold),
                  _buildPdfRow('Balance Pendiente', ((_summary['pendingBalance'] as num).toDouble()).toCurrency(), false, ttfRegular, ttfBold),
                  _buildPdfRow('Total Ganado', ((_summary['totalEarnings'] as num).toDouble()).toCurrency(), true, ttfRegular, ttfBold),
                  _buildPdfRow('Total Viajes', '${_summary['totalTrips']}', false, ttfRegular, ttfBold),
                  _buildPdfRow('Total Retiros', ((_summary['totalWithdrawals'] as num).toDouble()).toCurrency(), true, ttfRegular, ttfBold),
                ],
              ),
              pw.SizedBox(height: 20),

              // Transacciones
              pw.Text(
                'DETALLE DE TRANSACCIONES',
                style: pw.TextStyle(
                  font: ttfBold,
                  fontSize: 16,
                ),
              ),
              pw.SizedBox(height: 10),

              if (_filteredTransactions.isEmpty)
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
                          _buildPdfCell(
                            '$sign$amountValue',
                            ttfRegular,
                          ),
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

  // Funciones helper para generar tabla PDF
  pw.TableRow _buildPdfRow(String label, String value, bool isEven, pw.Font fontRegular, pw.Font fontBold) {
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

  pw.Widget _buildPdfHeaderCell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          color: PdfColors.white,
          fontSize: 10,
        ),
      ),
    );
  }

  pw.Widget _buildPdfCell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 9),
      ),
    );
  }
  
  void _shareTransaction(Transaction transaction) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Compartiendo transacción ${transaction.id}'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _reportIssue(Transaction transaction) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reportando problema con ${transaction.id}'),
        backgroundColor: ModernTheme.warning,
      ),
    );
  }
}

// Transaction model
class Transaction {
  final String id;
  final TransactionType type;
  final DateTime date;
  final double amount;
  final TransactionStatus status;
  
  // Trip details
  final String? passenger;
  final String? pickup;
  final String? destination;
  final double? distance;
  final int? duration;
  final String? paymentMethod;
  final double? commission;
  final double? netEarnings;
  final double? tip;
  
  // Withdrawal details
  final String? withdrawalMethod;
  final String? bankAccount;
  
  // Bonus details
  final String? bonusType;
  final String? description;
  
  // Refund details
  final String? refundReason;
  final String? originalTransaction;
  
  // Cancellation details
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