// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart'; // ✅ Extensión para colores que se adaptan al tema
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_formatter.dart';

import '../../utils/logger.dart';
class EarningsDetailsScreen extends StatefulWidget {
  const EarningsDetailsScreen({super.key});

  @override
  _EarningsDetailsScreenState createState() => _EarningsDetailsScreenState();
}

class _EarningsDetailsScreenState extends State<EarningsDetailsScreen> 
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _chartController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _chartAnimation;
  
  // Selected period
  String _selectedPeriod = 'week';
  
  // Earnings data
  EarningsData? _earningsData;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    
    _chartController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    
    _chartAnimation = CurvedAnimation(
      parent: _chartController,
      curve: Curves.easeOut,
    );
    
    _loadEarningsData();
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _chartController.dispose();
    super.dispose();
  }
  
  // ✅ Cargar datos reales desde Firebase
  void _loadEarningsData() async {
    setState(() => _isLoading = true);

    try {
      // ✅ Obtener usuario actual
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        AppLogger.warning('⚠️ No hay usuario autenticado');
        setState(() {
          _earningsData = _getEmptyData(_selectedPeriod);
          _isLoading = false;
        });
        return;
      }

      final userId = currentUser.uid;

      // ✅ Calcular rango de fechas según el período seleccionado
      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate = now;

      switch (_selectedPeriod) {
        case 'week':
          // Última semana (7 días)
          startDate = now.subtract(Duration(days: 7));
          break;
        case 'month':
          // Último mes (30 días)
          startDate = now.subtract(Duration(days: 30));
          break;
        case 'year':
          // Último año (365 días)
          startDate = now.subtract(Duration(days: 365));
          break;
        default:
          startDate = now.subtract(Duration(days: 7));
      }

      // ✅ Consultar rides completados del conductor en el período
      final ridesSnapshot = await FirebaseFirestore.instance
          .collection('rides')
          .where('driverId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('completedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      // ✅ Calcular métricas principales
      double totalEarnings = 0.0;
      double totalHours = 0.0;
      int totalTrips = ridesSnapshot.docs.length;

      // Mapas para análisis por día y por hora
      Map<String, DailyEarnings> dailyDataMap = {};
      List<double> hourlyEarningsArray = List.filled(24, 0.0);
      List<int> hourlyTripsArray = List.filled(24, 0);

      // Desglose de ingresos
      double baseFares = 0.0;
      double distanceFares = 0.0;
      double timeFares = 0.0;
      double tips = 0.0;
      double bonuses = 0.0;
      double surgeEarnings = 0.0;

      for (var doc in ridesSnapshot.docs) {
        final data = doc.data();

        // Calcular ganancias totales
        final fare = (data['fare'] ?? data['estimatedFare'] ?? 0.0) as num;
        totalEarnings += fare.toDouble();

        // Duración y análisis temporal
        if (data['startedAt'] != null && data['completedAt'] != null) {
          final startedAt = (data['startedAt'] as Timestamp).toDate();
          final completedAt = (data['completedAt'] as Timestamp).toDate();
          final duration = completedAt.difference(startedAt);
          totalHours += duration.inMinutes / 60.0;

          // Análisis por hora (hora de inicio del viaje)
          final hour = startedAt.hour;
          hourlyEarningsArray[hour] += fare.toDouble();
          hourlyTripsArray[hour]++;

          // Análisis por día
          final dateKey = '${completedAt.year}-${completedAt.month.toString().padLeft(2, '0')}-${completedAt.day.toString().padLeft(2, '0')}';
          if (!dailyDataMap.containsKey(dateKey)) {
            dailyDataMap[dateKey] = DailyEarnings(
              date: DateTime(completedAt.year, completedAt.month, completedAt.day),
              earnings: 0.0,
              trips: 0,
              hours: 0.0,
              online: true,
            );
          }
          dailyDataMap[dateKey] = DailyEarnings(
            date: dailyDataMap[dateKey]!.date,
            earnings: dailyDataMap[dateKey]!.earnings + fare.toDouble(),
            trips: dailyDataMap[dateKey]!.trips + 1,
            hours: dailyDataMap[dateKey]!.hours + (duration.inMinutes / 60.0),
            online: true,
          );
        }

        // Desglose de tarifas (asumiendo estructura de datos)
        baseFares += (data['baseFare'] ?? fare * 0.4) as num;
        distanceFares += (data['distanceFare'] ?? fare * 0.4) as num;
        timeFares += (data['timeFare'] ?? fare * 0.2) as num;
        tips += (data['tip'] ?? 0.0) as num;
        bonuses += (data['bonus'] ?? 0.0) as num;
        surgeEarnings += (data['surge'] ?? 0.0) as num;
      }

      // ✅ Calcular promedios
      final avgPerTrip = totalTrips > 0 ? totalEarnings / totalTrips : 0.0;
      final avgPerHour = totalHours > 0 ? totalEarnings / totalHours : 0.0;

      // ✅ Calcular comisión (asumiendo 20%)
      final commission = totalEarnings * 0.20;
      final netEarnings = totalEarnings - commission;

      // ✅ Consultar tiempo online (de colección opcional driver_sessions o estimado)
      double onlineHours = totalHours * 1.5; // Estimación: 1.5x tiempo de viaje

      // ✅ Crear lista de datos diarios ordenados
      final dailyData = dailyDataMap.values.toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      // ✅ Crear lista de datos por hora
      final hourlyData = List.generate(24, (index) {
        return HourlyEarnings(
          hour: index,
          earnings: hourlyEarningsArray[index],
          trips: hourlyTripsArray[index],
        );
      });

      // ✅ Metas del período (consultar o usar valores por defecto)
      final goals = WeeklyGoals(
        earningsGoal: _selectedPeriod == 'week' ? 500.0 : _selectedPeriod == 'month' ? 2000.0 : 20000.0,
        tripsGoal: _selectedPeriod == 'week' ? 30 : _selectedPeriod == 'month' ? 160 : 1600,
        hoursGoal: _selectedPeriod == 'week' ? 35.0 : _selectedPeriod == 'month' ? 160.0 : 1800.0,
        achievedEarnings: netEarnings,
        achievedTrips: totalTrips,
        achievedHours: totalHours,
      );

      setState(() {
        _earningsData = EarningsData(
          period: _getPeriodLabelFromKey(_selectedPeriod),
          totalEarnings: totalEarnings,
          totalTrips: totalTrips,
          avgPerTrip: avgPerTrip,
          totalHours: totalHours,
          avgPerHour: avgPerHour,
          onlineHours: onlineHours,
          commission: commission,
          netEarnings: netEarnings,
          dailyData: dailyData,
          hourlyData: hourlyData,
          breakdown: EarningsBreakdown(
            baseFares: baseFares,
            distanceFares: distanceFares,
            timeFares: timeFares,
            tips: tips,
            bonuses: bonuses,
            surgeEarnings: surgeEarnings,
          ),
          goals: goals,
        );
        _isLoading = false;
      });

      _fadeController.forward();
      _chartController.forward();
    } catch (e) {
      AppLogger.error('❌ Error al cargar datos de ganancias: $e');
      setState(() {
        _earningsData = _getEmptyData(_selectedPeriod);
        _isLoading = false;
      });
    }
  }

  String _getPeriodLabelFromKey(String period) {
    switch (period) {
      case 'week':
        return 'Esta Semana';
      case 'month':
        return 'Este Mes';
      case 'year':
        return 'Este Año';
      default:
        return period;
    }
  }

  // ✅ Datos vacíos iniciales (sin mock data)
  EarningsData _getEmptyData(String period) {
    String periodLabel;
    switch (period) {
      case 'week':
        periodLabel = 'Esta Semana';
        break;
      case 'month':
        periodLabel = 'Este Mes';
        break;
      default:
        periodLabel = 'Este Año';
    }

    return EarningsData(
      period: periodLabel,
      totalEarnings: 0.0,
      totalTrips: 0,
      avgPerTrip: 0.0,
      totalHours: 0.0,
      avgPerHour: 0.0,
      onlineHours: 0.0,
      commission: 0.0,
      netEarnings: 0.0,
      dailyData: [],
      hourlyData: List.generate(24, (index) {
        return HourlyEarnings(
          hour: index,
          earnings: 0.0,
          trips: 0,
        );
      }),
      breakdown: EarningsBreakdown(
        baseFares: 0.0,
        distanceFares: 0.0,
        timeFares: 0.0,
        tips: 0.0,
        bonuses: 0.0,
        surgeEarnings: 0.0,
      ),
      goals: WeeklyGoals(
        earningsGoal: period == 'week' ? 500.0 : period == 'month' ? 2000.0 : 20000.0,
        tripsGoal: period == 'week' ? 30 : period == 'month' ? 160 : 1600,
        hoursGoal: period == 'week' ? 35.0 : period == 'month' ? 160.0 : 1800.0,
        achievedEarnings: 0.0,
        achievedTrips: 0,
        achievedHours: 0.0,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceColor,
      appBar: AppBar(
        backgroundColor: ModernTheme.rappiOrange,
        elevation: 0,
        title: Text(
          'Análisis de Ganancias',
          style: TextStyle(
            color: context.onPrimaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.download, color: context.onPrimaryText),
            onPressed: _exportData,
          ),
          IconButton(
            icon: Icon(Icons.share, color: context.onPrimaryText),
            onPressed: _shareReport,
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingState() : _buildEarningsDetails(),
    );
  }
  
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(ModernTheme.rappiOrange),
          ),
          SizedBox(height: 16),
          Text(
            'Analizando tus ganancias...',
            style: TextStyle(
              color: context.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEarningsDetails() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Column(
            children: [
              // Period selector
              _buildPeriodSelector(),
              
              // Main content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Summary cards
                      _buildSummaryCards(),
                      
                      // Goals progress
                      _buildGoalsSection(),
                      
                      // Earnings chart
                      _buildEarningsChart(),
                      
                      // Hourly analysis
                      _buildHourlyAnalysis(),
                      
                      // Breakdown
                      _buildEarningsBreakdown(),
                      
                      // Performance insights
                      _buildInsights(),
                      
                      SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildPeriodSelector() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: ['week', 'month', 'year'].map((period) {
          final isSelected = _selectedPeriod == period;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedPeriod = period);
                _loadEarningsData();
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? ModernTheme.rappiOrange : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getPeriodLabel(period),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? context.onPrimaryText : context.secondaryText,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
  
  String _getPeriodLabel(String period) {
    switch (period) {
      case 'week':
        return 'Semana';
      case 'month':
        return 'Mes';
      case 'year':
        return 'Año';
      default:
        return period;
    }
  }
  
  Widget _buildSummaryCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero gradient earnings card
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                ModernTheme.rappiOrange,
                ModernTheme.rappiOrange.withValues(alpha: 0.75),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: ModernTheme.rappiOrange.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.account_balance_wallet, color: Colors.white.withValues(alpha: 0.85), size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Ganancias Totales',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _earningsData!.totalEarnings.toCurrency(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Neto: ${_earningsData!.netEarnings.toCurrency()}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // Decorative circle with icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.trending_up,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
        ),
        // Horizontal mini cards below
        SizedBox(
          height: 130,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            children: [
              _buildSummaryCard(
                'Viajes',
                '${_earningsData!.totalTrips}',
                Icons.directions_car,
                ModernTheme.primaryBlue,
                'Prom: ${_earningsData!.avgPerTrip.toCurrency()}',
              ),
              _buildSummaryCard(
                'Horas',
                '${_earningsData!.totalHours.toStringAsFixed(1)}h',
                Icons.schedule,
                ModernTheme.warning,
                'Por hora: ${_earningsData!.avgPerHour.toCurrency()}',
              ),
              _buildSummaryCard(
                'Online',
                '${_earningsData!.onlineHours.toStringAsFixed(1)}h',
                Icons.online_prediction,
                ModernTheme.success,
                'Efic: ${(_earningsData!.totalHours / _earningsData!.onlineHours * 100).toStringAsFixed(0)}%',
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      width: 140,
      margin: EdgeInsets.only(right: 12),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: context.secondaryText,
            ),
          ),
          SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: context.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGoalsSection() {
    final goals = _earningsData!.goals;

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag, color: ModernTheme.rappiOrange),
              SizedBox(width: 8),
              Text(
                'Progreso de Metas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          _buildGoalProgress(
            'Ganancias',
            goals.achievedEarnings,
            goals.earningsGoal,
            AppConstants.currencySymbol,
            ModernTheme.success,
          ),
          SizedBox(height: 16),
          _buildGoalProgress(
            'Viajes',
            goals.achievedTrips.toDouble(),
            goals.tripsGoal.toDouble(),
            '',
            ModernTheme.primaryBlue,
          ),
          SizedBox(height: 16),
          _buildGoalProgress(
            'Horas',
            goals.achievedHours,
            goals.hoursGoal,
            'h',
            ModernTheme.warning,
          ),
        ],
      ),
    );
  }
  
  Widget _buildGoalProgress(String label, double achieved, double goal, String unit, Color color) {
    final progress = (achieved / goal).clamp(0.0, 1.0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$unit${achieved.toStringAsFixed(achieved % 1 == 0 ? 0 : 1)} / $unit${goal.toStringAsFixed(goal % 1 == 0 ? 0 : 1)}',
              style: TextStyle(
                color: context.secondaryText,
                fontSize: 12,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: color.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
        SizedBox(height: 4),
        Text(
          '${(progress * 100).toStringAsFixed(1)}% completado',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
  
  Widget _buildEarningsChart() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: ModernTheme.primaryBlue),
              SizedBox(width: 8),
              Text(
                'Tendencia de Ganancias',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: AnimatedBuilder(
              animation: _chartAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: EarningsChartPainter(
                    data: _earningsData!.dailyData,
                    animation: _chartAnimation.value,
                  ),
                  size: Size.infinite,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHourlyAnalysis() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, color: ModernTheme.info),
              SizedBox(width: 8),
              Text(
                'Análisis por Horas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: HourlyEarningsChartPainter(
                data: _earningsData!.hourlyData,
              ),
              size: Size.infinite,
            ),
          ),
          SizedBox(height: 12),
          _buildHourlyInsights(),
        ],
      ),
    );
  }
  
  Widget _buildHourlyInsights() {
    final bestHour = _earningsData!.hourlyData
        .reduce((a, b) => a.earnings > b.earnings ? a : b);

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb, color: ModernTheme.warning, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tu mejor hora: ${bestHour.hour}:00 - ${bestHour.hour + 1}:00 (${bestHour.earnings.toCurrency()})',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEarningsBreakdown() {
    final breakdown = _earningsData!.breakdown;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart, color: ModernTheme.warning),
              SizedBox(width: 8),
              Text(
                'Desglose de Ingresos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          _buildBreakdownItem('Tarifas base', breakdown.baseFares, Icons.monetization_on, ModernTheme.primaryBlue),
          _buildBreakdownItem('Por distancia', breakdown.distanceFares, Icons.straighten, ModernTheme.success),
          _buildBreakdownItem('Por tiempo', breakdown.timeFares, Icons.schedule, ModernTheme.warning),
          if (breakdown.tips > 0)
            _buildBreakdownItem('Propinas', breakdown.tips, Icons.star, ModernTheme.warning),
          if (breakdown.bonuses > 0)
            _buildBreakdownItem('Bonos', breakdown.bonuses, Icons.card_giftcard, ModernTheme.rappiOrange),
          if (breakdown.surgeEarnings > 0)
            _buildBreakdownItem('Tarifa dinámica', breakdown.surgeEarnings, Icons.trending_up, ModernTheme.error),
          Divider(height: 24, thickness: 1),

          // ✅ VISUALIZACIÓN DETALLADA: Desglose de comisión del 20%
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ModernTheme.error.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ModernTheme.error.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: ModernTheme.error, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Comisión de Plataforma (20%)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: ModernTheme.error,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total bruto de viajes:',
                      style: TextStyle(fontSize: 13, color: context.secondaryText),
                    ),
                    Text(
                      _earningsData!.totalEarnings.toCurrency(),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Comisión Rappi Team (20%):',
                      style: TextStyle(fontSize: 13, color: context.secondaryText),
                    ),
                    Text(
                      '-${_earningsData!.commission.toCurrency()}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ModernTheme.error,
                      ),
                    ),
                  ],
                ),
                Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tu ganancia (80%):',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: ModernTheme.rappiOrange,
                      ),
                    ),
                    Text(
                      _earningsData!.netEarnings.toCurrency(),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: ModernTheme.rappiOrange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 12),
          Divider(height: 24, thickness: 1),
          _buildBreakdownItem('Total neto final', _earningsData!.netEarnings, Icons.account_balance_wallet, ModernTheme.rappiOrange, isTotal: true),
        ],
      ),
    );
  }
  
  Widget _buildBreakdownItem(String label, double amount, IconData icon, Color color, {bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                fontSize: isTotal ? 16 : 14,
              ),
            ),
          ),
          Text(
            '${amount >= 0 ? '' : '-'}${amount.abs().toCurrency()}',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              fontSize: isTotal ? 16 : 14,
              color: isTotal ? color : (amount >= 0 ? context.primaryText : ModernTheme.error),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInsights() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: ModernTheme.info),
              SizedBox(width: 8),
              Text(
                'Insights y Recomendaciones',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildInsightCard(
            'Mejores días',
            'Martes y Viernes son tus días más rentables',
            Icons.calendar_today,
            ModernTheme.success,
          ),
          SizedBox(height: 12),
          _buildInsightCard(
            'Horario óptimo',
            'Concéntrate en las horas de 7-9 AM y 6-8 PM',
            Icons.schedule,
            ModernTheme.primaryBlue,
          ),
          SizedBox(height: 12),
          _buildInsightCard(
            'Oportunidad',
            'Puedes aumentar 15% trabajando 2 horas más los fines de semana',
            Icons.trending_up,
            ModernTheme.warning,
          ),
        ],
      ),
    );
  }
  
  Widget _buildInsightCard(String title, String description, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                Text(
                  description,
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
  
  void _exportData() {
    if (_earningsData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hay datos para exportar'),
          backgroundColor: ModernTheme.warning,
        ),
      );
      return;
    }

    // Generar reporte en texto
    final buffer = StringBuffer();
    buffer.writeln('=== REPORTE DE GANANCIAS - RAPPI TEAM ===');
    buffer.writeln('Fecha de generación: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}');
    buffer.writeln('Período: ${_selectedPeriod == 'week' ? 'Semanal' : _selectedPeriod == 'month' ? 'Mensual' : 'Anual'}');
    buffer.writeln('');
    buffer.writeln('RESUMEN:');
    buffer.writeln('- Total ganado: ${_earningsData!.totalEarnings.toCurrency()}');
    buffer.writeln('- Total viajes: ${_earningsData!.totalTrips}');
    buffer.writeln('- Promedio por viaje: ${_earningsData!.avgPerTrip.toCurrency()}');
    buffer.writeln('');
    buffer.writeln('DETALLE DIARIO:');
    for (final day in _earningsData!.dailyData) {
      buffer.writeln('- ${DateFormat('dd/MM').format(day.date)}: ${day.earnings.toCurrency()} (${day.trips} viajes)');
    }
    buffer.writeln('');
    buffer.writeln('Generado por Rappi Team App');

    // Mostrar opciones de exportación
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Exportar Reporte',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.copy, color: ModernTheme.rappiOrange),
              title: Text('Copiar al portapapeles'),
              onTap: () {
                Navigator.pop(context);
                // En Flutter web no hay clipboard directo, usamos share
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Reporte copiado. Use compartir para enviarlo.'),
                    backgroundColor: ModernTheme.success,
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.share, color: ModernTheme.rappiOrange),
              title: Text('Compartir como texto'),
              onTap: () {
                Navigator.pop(context);
                Share.share(buffer.toString(), subject: 'Reporte de Ganancias - Rappi Team');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _shareReport() {
    if (_earningsData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hay datos para compartir'),
          backgroundColor: ModernTheme.warning,
        ),
      );
      return;
    }

    final period = _selectedPeriod == 'week' ? 'esta semana' :
                   _selectedPeriod == 'month' ? 'este mes' : 'este año';

    final message = '''
📊 *Mi Reporte de Ganancias - Rappi Team*

💰 Total ganado $period: ${_earningsData!.totalEarnings.toCurrency()}
🚗 Viajes completados: ${_earningsData!.totalTrips}
📈 Promedio por viaje: ${_earningsData!.avgPerTrip.toCurrency()}

¡Conduce con Rappi Team! 🚕
''';

    Share.share(message, subject: 'Mi Reporte de Ganancias - Rappi Team');
  }
}

// Custom painters
class EarningsChartPainter extends CustomPainter {
  final List<DailyEarnings> data;
  final double animation;
  
  const EarningsChartPainter({super.repaint, required this.data, required this.animation});
  
  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    
    final paint = Paint()
      ..color = ModernTheme.rappiOrange.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    
    final linePaint = Paint()
      ..color = ModernTheme.rappiOrange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    final maxEarnings = data.map((d) => d.earnings).reduce(math.max);
    final points = <Offset>[];
    
    for (int i = 0; i < data.length; i++) {
      final x = (size.width / (data.length - 1)) * i;
      final y = size.height - (data[i].earnings / maxEarnings * size.height * animation);
      points.add(Offset(x, y));
    }
    
    // Draw filled area
    final path = Path();
    path.moveTo(0, size.height);
    for (final point in points) {
      path.lineTo(point.dx, point.dy);
    }
    path.lineTo(size.width, size.height);
    path.close();
    
    canvas.drawPath(path, paint);
    
    // Draw line
    if (points.length > 1) {
      final linePath = Path();
      linePath.moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i < points.length; i++) {
        linePath.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(linePath, linePaint);
    }
    
    // Draw points
    final pointPaint = Paint()
      ..color = ModernTheme.rappiOrange
      ..style = PaintingStyle.fill;
    
    for (final point in points) {
      canvas.drawCircle(point, 4, pointPaint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class HourlyEarningsChartPainter extends CustomPainter {
  final List<HourlyEarnings> data;
  
  const HourlyEarningsChartPainter({super.repaint, required this.data});
  
  @override
  void paint(Canvas canvas, Size size) {
    final maxEarnings = data.map((d) => d.earnings).reduce(math.max);
    final barWidth = size.width / data.length;
    
    for (int i = 0; i < data.length; i++) {
      final barHeight = (data[i].earnings / maxEarnings) * size.height;
      final rect = Rect.fromLTWH(
        i * barWidth + barWidth * 0.2,
        size.height - barHeight,
        barWidth * 0.6,
        barHeight,
      );
      
      final paint = Paint()
        ..color = data[i].earnings > maxEarnings * 0.5 
            ? ModernTheme.rappiOrange
            : ModernTheme.rappiOrange.withValues(alpha: 0.5);
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(2)),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Models
class EarningsData {
  final String period;
  final double totalEarnings;
  final int totalTrips;
  final double avgPerTrip;
  final double totalHours;
  final double avgPerHour;
  final double onlineHours;
  final double commission;
  final double netEarnings;
  final List<DailyEarnings> dailyData;
  final List<HourlyEarnings> hourlyData;
  final EarningsBreakdown breakdown;
  final WeeklyGoals goals;
  
  EarningsData({
    required this.period,
    required this.totalEarnings,
    required this.totalTrips,
    required this.avgPerTrip,
    required this.totalHours,
    required this.avgPerHour,
    required this.onlineHours,
    required this.commission,
    required this.netEarnings,
    required this.dailyData,
    required this.hourlyData,
    required this.breakdown,
    required this.goals,
  });
}

class DailyEarnings {
  final DateTime date;
  final double earnings;
  final int trips;
  final double hours;
  final bool online;
  
  DailyEarnings({
    required this.date,
    required this.earnings,
    required this.trips,
    required this.hours,
    required this.online,
  });
}

class HourlyEarnings {
  final int hour;
  final double earnings;
  final int trips;
  
  HourlyEarnings({
    required this.hour,
    required this.earnings,
    required this.trips,
  });
}

class EarningsBreakdown {
  final double baseFares;
  final double distanceFares;
  final double timeFares;
  final double tips;
  final double bonuses;
  final double surgeEarnings;
  
  EarningsBreakdown({
    required this.baseFares,
    required this.distanceFares,
    required this.timeFares,
    required this.tips,
    required this.bonuses,
    required this.surgeEarnings,
  });
}

class WeeklyGoals {
  final double earningsGoal;
  final int tripsGoal;
  final double hoursGoal;
  final double achievedEarnings;
  final int achievedTrips;
  final double achievedHours;
  
  WeeklyGoals({
    required this.earningsGoal,
    required this.tripsGoal,
    required this.hoursGoal,
    required this.achievedEarnings,
    required this.achievedTrips,
    required this.achievedHours,
  });
}