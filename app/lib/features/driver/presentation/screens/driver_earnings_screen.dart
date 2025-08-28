import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/oasis_button.dart';
import '../../../../shared/models/ride_model.dart';
import '../providers/driver_status_provider.dart';
import '../widgets/earnings_card.dart';
import '../widgets/earnings_chart.dart';
import '../widgets/recent_trips_list.dart';

class DriverEarningsScreen extends ConsumerStatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  ConsumerState<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends ConsumerState<DriverEarningsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Inicializar con el mes actual
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppTheme.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayEarnings = ref.watch(todayEarningsProvider);
    final weeklyEarnings = ref.watch(weeklyEarningsProvider);
    final monthlyEarnings = ref.watch(monthlyEarningsProvider);
    final totalTrips = ref.watch(totalTripsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ganancias'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Seleccionar período',
          ),
        ],
      ),
      body: Column(
        children: [
          // Pestañas de período
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Hoy'),
                Tab(text: 'Semana'),
                Tab(text: 'Mes'),
                Tab(text: 'Personalizado'),
              ],
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppTheme.primaryColor,
            ),
          ),
          
          // Contenido principal
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Hoy
                _buildEarningsView(
                  todayEarnings,
                  totalTrips,
                  'Hoy',
                  DateTime.now(),
                  DateTime.now(),
                ),
                
                // Semana
                _buildEarningsView(
                  weeklyEarnings,
                  totalTrips,
                  'Esta semana',
                  _getWeekStart(DateTime.now()),
                  DateTime.now(),
                ),
                
                // Mes
                _buildEarningsView(
                  monthlyEarnings,
                  totalTrips,
                  'Este mes',
                  DateTime(DateTime.now().year, DateTime.now().month, 1),
                  DateTime.now(),
                ),
                
                // Personalizado
                if (_selectedDateRange != null)
                  _buildCustomPeriodView()
                else
                  const Center(
                    child: Text('Selecciona un período personalizado'),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showWithdrawDialog();
        },
        backgroundColor: AppTheme.earningsColor,
        icon: const Icon(Icons.account_balance_wallet),
        label: const Text('Retirar'),
      ),
    );
  }

  Widget _buildEarningsView(
    AsyncValue<double> earningsAsync,
    AsyncValue<int> tripsAsync,
    String period,
    DateTime startDate,
    DateTime endDate,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(todayEarningsProvider);
        ref.invalidate(weeklyEarningsProvider);
        ref.invalidate(monthlyEarningsProvider);
        ref.invalidate(totalTripsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumen de ganancias
            Row(
              children: [
                Expanded(
                  child: earningsAsync.when(
                    data: (earnings) => EarningsCard(
                      title: period,
                      amount: earnings,
                      icon: Icons.monetization_on,
                      color: AppTheme.earningsColor,
                    ),
                    loading: () => const EarningsCard(
                      title: 'Cargando...',
                      amount: 0.0,
                      icon: Icons.monetization_on,
                      color: AppTheme.earningsColor,
                    ),
                    error: (_, __) => const EarningsCard(
                      title: 'Error',
                      amount: 0.0,
                      icon: Icons.error,
                      color: AppTheme.errorColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: tripsAsync.when(
                    data: (trips) => EarningsCard(
                      title: 'Viajes',
                      amount: trips.toDouble(),
                      icon: Icons.directions_car,
                      color: AppTheme.primaryColor,
                      isCount: true,
                    ),
                    loading: () => const EarningsCard(
                      title: 'Cargando...',
                      amount: 0.0,
                      icon: Icons.directions_car,
                      color: AppTheme.primaryColor,
                      isCount: true,
                    ),
                    error: (_, __) => const EarningsCard(
                      title: 'Error',
                      amount: 0.0,
                      icon: Icons.error,
                      color: AppTheme.errorColor,
                      isCount: true,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Gráfico de ganancias
            earningsAsync.when(
              data: (earnings) => EarningsChart(
                earnings: earnings,
                period: period,
                startDate: startDate,
                endDate: endDate,
              ).animate().fadeIn().slideY(begin: 0.2, end: 0),
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
            
            const SizedBox(height: 24),
            
            // Lista de viajes recientes
            Text(
              'Viajes recientes',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            
            RecentTripsList(
              startDate: startDate,
              endDate: endDate,
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomPeriodView() {
    if (_selectedDateRange == null) {
      return const Center(
        child: Text('Selecciona un período'),
      );
    }

    final dateFormat = DateFormat('dd/MM/yyyy');
    final period = '${dateFormat.format(_selectedDateRange!.start)} - ${dateFormat.format(_selectedDateRange!.end)}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Período seleccionado
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.date_range,
                  color: AppTheme.primaryColor,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  'Período seleccionado',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.primaryColor,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  period,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Estadísticas del período personalizado
          FutureBuilder<List<RideModel>>(
            future: ref.read(driverRepositoryProvider).getEarningsHistory(
              _selectedDateRange!.start,
              _selectedDateRange!.end,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
                );
              }
              
              final rides = snapshot.data ?? [];
              final totalEarnings = rides.fold<double>(
                0.0,
                (sum, ride) => sum + (ride.fare ?? 0.0),
              );
              
              return Column(
                children: [
                  // Resumen
                  Row(
                    children: [
                      Expanded(
                        child: EarningsCard(
                          title: 'Total ganado',
                          amount: totalEarnings,
                          icon: Icons.monetization_on,
                          color: AppTheme.earningsColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: EarningsCard(
                          title: 'Viajes',
                          amount: rides.length.toDouble(),
                          icon: Icons.directions_car,
                          color: AppTheme.primaryColor,
                          isCount: true,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Promedio por viaje
                  if (rides.isNotEmpty)
                    EarningsCard(
                      title: 'Promedio por viaje',
                      amount: totalEarnings / rides.length,
                      icon: Icons.trending_up,
                      color: AppTheme.infoColor,
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Lista de viajes
                  Text(
                    'Historial de viajes',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  
                  RecentTripsList(
                    startDate: _selectedDateRange!.start,
                    endDate: _selectedDateRange!.end,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  void _showWithdrawDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirar ganancias'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_balance_wallet,
              size: 64,
              color: AppTheme.earningsColor,
            ),
            const SizedBox(height: 16),
            const Text(
              'Esta función estará disponible próximamente. Podrás retirar tus ganancias directamente a tu cuenta bancaria.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

// Provider para ganancias semanales
final weeklyEarningsProvider = FutureProvider<double>((ref) async {
  final repository = ref.watch(driverRepositoryProvider);
  return repository.getWeeklyEarnings();
});

// Provider para ganancias mensuales
final monthlyEarningsProvider = FutureProvider<double>((ref) async {
  final repository = ref.watch(driverRepositoryProvider);
  return repository.getMonthlyEarnings();
});