import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/design/design_system.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_card.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_formatter.dart';
import '../../utils/logger.dart';

class EarningsDetailsScreen extends StatefulWidget {
  const EarningsDetailsScreen({super.key});

  @override
  State<EarningsDetailsScreen> createState() => _EarningsDetailsScreenState();
}

class _EarningsDetailsScreenState extends State<EarningsDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _chartController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _chartAnimation;

  // Periodo seleccionado
  String _selectedPeriod = 'week';

  // Datos de ganancias
  EarningsData? _earningsData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _chartController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _chartAnimation = CurvedAnimation(parent: _chartController, curve: Curves.easeOut);

    _loadEarningsData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _chartController.dispose();
    super.dispose();
  }

  // Cargar datos reales desde Firebase
  void _loadEarningsData() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        AppLogger.warning('No hay usuario autenticado');
        setState(() {
          _earningsData = _getEmptyData(_selectedPeriod);
          _isLoading = false;
        });
        return;
      }

      final userId = currentUser.uid;

      // Calcular rango de fechas según el período seleccionado
      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate = now;

      switch (_selectedPeriod) {
        case 'week':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case 'month':
          startDate = now.subtract(const Duration(days: 30));
          break;
        case 'year':
          startDate = now.subtract(const Duration(days: 365));
          break;
        default:
          startDate = now.subtract(const Duration(days: 7));
      }

      // Consultar rides completados del conductor en el período
      final ridesSnapshot = await FirebaseFirestore.instance
          .collection('rides')
          .where('driverId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('completedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      // Calcular metricas principales
      double totalEarnings = 0.0;
      double totalHours = 0.0;
      int totalTrips = ridesSnapshot.docs.length;

      Map<String, DailyEarnings> dailyDataMap = {};
      List<double> hourlyEarningsArray = List.filled(24, 0.0);
      List<int> hourlyTripsArray = List.filled(24, 0);

      double baseFares = 0.0;
      double distanceFares = 0.0;
      double timeFares = 0.0;
      double tips = 0.0;
      double bonuses = 0.0;
      double surgeEarnings = 0.0;

      for (var doc in ridesSnapshot.docs) {
        final data = doc.data();

        final fare = (data['fare'] ?? data['estimatedFare'] ?? 0.0) as num;
        totalEarnings += fare.toDouble();

        if (data['startedAt'] != null && data['completedAt'] != null) {
          final startedAt = (data['startedAt'] as Timestamp).toDate();
          final completedAt = (data['completedAt'] as Timestamp).toDate();
          final duration = completedAt.difference(startedAt);
          totalHours += duration.inMinutes / 60.0;

          final hour = startedAt.hour;
          hourlyEarningsArray[hour] += fare.toDouble();
          hourlyTripsArray[hour]++;

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

        baseFares += (data['baseFare'] ?? fare * 0.4) as num;
        distanceFares += (data['distanceFare'] ?? fare * 0.4) as num;
        timeFares += (data['timeFare'] ?? fare * 0.2) as num;
        tips += (data['tip'] ?? 0.0) as num;
        bonuses += (data['bonus'] ?? 0.0) as num;
        surgeEarnings += (data['surge'] ?? 0.0) as num;
      }

      final avgPerTrip = totalTrips > 0 ? totalEarnings / totalTrips : 0.0;
      final avgPerHour = totalHours > 0 ? totalEarnings / totalHours : 0.0;
      final commission = totalEarnings * 0.20;
      final netEarnings = totalEarnings - commission;
      double onlineHours = totalHours * 1.5;

      final dailyData = dailyDataMap.values.toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      final hourlyData = List.generate(24, (index) {
        return HourlyEarnings(
          hour: index,
          earnings: hourlyEarningsArray[index],
          trips: hourlyTripsArray[index],
        );
      });

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
      AppLogger.error('Error al cargar datos de ganancias: $e');
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
        return 'Este Ano';
      default:
        return period;
    }
  }

  // Datos vacios iniciales
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
        periodLabel = 'Este Ano';
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
        return HourlyEarnings(hour: index, earnings: 0.0, trips: 0);
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: RtAppBar(
        title: 'Análisis de Ganancias',
        variant: RtAppBarVariant.gradient,
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: RtColors.white),
            onPressed: _exportData,
          ),
          IconButton(
            icon: const Icon(Icons.share, color: RtColors.white),
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
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(RtColors.brand),
          ),
          const SizedBox(height: RtSpacing.base),
          Text(
            'Analizando tus ganancias...',
            style: RtTypo.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
              _buildPeriodSelector(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildSummaryCards(),
                      _buildGoalsSection(),
                      _buildEarningsChart(),
                      _buildHourlyAnalysis(),
                      _buildEarningsBreakdown(),
                      _buildInsights(),
                      const SizedBox(height: RtSpacing.xl),
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
    final secondaryText = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return Container(
      margin: RtSpacing.paddingBase,
      padding: const EdgeInsets.all(RtSpacing.xs),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: RtRadius.borderMd,
        boxShadow: RtShadow.soft(),
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
                padding: const EdgeInsets.symmetric(vertical: RtSpacing.md),
                decoration: BoxDecoration(
                  color: isSelected ? RtColors.brand : Colors.transparent,
                  borderRadius: RtRadius.borderSm,
                ),
                child: Text(
                  _getPeriodLabel(period),
                  textAlign: TextAlign.center,
                  style: RtTypo.labelLarge.copyWith(
                    color: isSelected ? RtColors.white : secondaryText,
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
        return 'Ano';
      default:
        return period;
    }
  }

  Widget _buildSummaryCards() {
    final secondaryText = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return SizedBox(
      height: 200,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: RtSpacing.base),
        children: [
          _buildSummaryCard(
            'Ganancias Totales',
            _earningsData!.totalEarnings.toCurrency(),
            Icons.account_balance_wallet,
            RtColors.success,
            'Neto: ${_earningsData!.netEarnings.toCurrency()}',
            secondaryText,
          ),
          _buildSummaryCard(
            'Total de Viajes',
            '${_earningsData!.totalTrips}',
            Icons.directions_car,
            RtColors.info,
            'Promedio: ${_earningsData!.avgPerTrip.toCurrency()}',
            secondaryText,
          ),
          _buildSummaryCard(
            'Horas Trabajadas',
            '${_earningsData!.totalHours.toStringAsFixed(1)}h',
            Icons.schedule,
            RtColors.warning,
            'Por hora: ${_earningsData!.avgPerHour.toCurrency()}',
            secondaryText,
          ),
          _buildSummaryCard(
            'Tiempo Online',
            '${_earningsData!.onlineHours.toStringAsFixed(1)}h',
            Icons.online_prediction,
            RtColors.brand,
            'Eficiencia: ${(_earningsData!.totalHours / _earningsData!.onlineHours * 100).toStringAsFixed(1)}%',
            secondaryText,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, String subtitle, Color secondaryText) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: RtSpacing.md),
      padding: RtSpacing.paddingBase,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: RtRadius.borderLg,
        boxShadow: RtShadow.soft(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(RtSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: RtIconSize.md),
          ),
          const Spacer(),
          Text(
            value,
            style: RtTypo.displaySmall.copyWith(color: color),
          ),
          const SizedBox(height: RtSpacing.xs),
          Text(title, style: RtTypo.bodySmall.copyWith(color: secondaryText)),
          const SizedBox(height: RtSpacing.sm),
          Text(subtitle, style: RtTypo.labelSmall.copyWith(color: secondaryText)),
        ],
      ),
    );
  }

  Widget _buildGoalsSection() {
    final goals = _earningsData!.goals;
    final secondaryText = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return RtCard(
      margin: RtSpacing.paddingBase,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag, color: RtColors.brand),
              const SizedBox(width: RtSpacing.sm),
              Text('Progreso de Metas', style: RtTypo.headingSmall),
            ],
          ),
          const SizedBox(height: RtSpacing.lg),
          _buildGoalProgress('Ganancias', goals.achievedEarnings, goals.earningsGoal, AppConstants.currencySymbol, RtColors.success, secondaryText),
          const SizedBox(height: RtSpacing.base),
          _buildGoalProgress('Viajes', goals.achievedTrips.toDouble(), goals.tripsGoal.toDouble(), '', RtColors.info, secondaryText),
          const SizedBox(height: RtSpacing.base),
          _buildGoalProgress('Horas', goals.achievedHours, goals.hoursGoal, 'h', RtColors.warning, secondaryText),
        ],
      ),
    );
  }

  Widget _buildGoalProgress(String label, double achieved, double goal, String unit, Color color, Color secondaryText) {
    final progress = (achieved / goal).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: RtTypo.titleMedium),
            Text(
              '$unit${achieved.toStringAsFixed(achieved % 1 == 0 ? 0 : 1)} / $unit${goal.toStringAsFixed(goal % 1 == 0 ? 0 : 1)}',
              style: RtTypo.bodySmall.copyWith(color: secondaryText),
            ),
          ],
        ),
        const SizedBox(height: RtSpacing.sm),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: color.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
        const SizedBox(height: RtSpacing.xs),
        Text(
          '${(progress * 100).toStringAsFixed(1)}% completado',
          style: RtTypo.labelSmall.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildEarningsChart() {
    return RtCard(
      margin: const EdgeInsets.symmetric(horizontal: RtSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, color: RtColors.info),
              const SizedBox(width: RtSpacing.sm),
              Text('Tendencia de Ganancias', style: RtTypo.headingSmall),
            ],
          ),
          const SizedBox(height: RtSpacing.lg),
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
    return RtCard(
      margin: RtSpacing.paddingBase,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time, color: RtColors.info),
              const SizedBox(width: RtSpacing.sm),
              Text('Análisis por Horas', style: RtTypo.headingSmall),
            ],
          ),
          const SizedBox(height: RtSpacing.lg),
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: HourlyEarningsChartPainter(data: _earningsData!.hourlyData),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: RtSpacing.md),
          _buildHourlyInsights(),
        ],
      ),
    );
  }

  Widget _buildHourlyInsights() {
    final bestHour = _earningsData!.hourlyData
        .reduce((a, b) => a.earnings > b.earnings ? a : b);

    return Container(
      padding: const EdgeInsets.all(RtSpacing.md),
      decoration: BoxDecoration(
        color: RtColors.neutral100,
        borderRadius: RtRadius.borderMd,
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb, color: RtColors.warning, size: RtIconSize.sm),
          const SizedBox(width: RtSpacing.sm),
          Expanded(
            child: Text(
              'Tu mejor hora: ${bestHour.hour}:00 - ${bestHour.hour + 1}:00 (${bestHour.earnings.toCurrency()})',
              style: RtTypo.bodySmall.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsBreakdown() {
    final breakdown = _earningsData!.breakdown;
    final secondaryText = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return RtCard(
      margin: const EdgeInsets.symmetric(horizontal: RtSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart, color: RtColors.warning),
              const SizedBox(width: RtSpacing.sm),
              Text('Desglose de Ingresos', style: RtTypo.headingSmall),
            ],
          ),
          const SizedBox(height: RtSpacing.lg),
          _buildBreakdownItem('Tarifas base', breakdown.baseFares, Icons.monetization_on, RtColors.info, secondaryText),
          _buildBreakdownItem('Por distancia', breakdown.distanceFares, Icons.straighten, RtColors.success, secondaryText),
          _buildBreakdownItem('Por tiempo', breakdown.timeFares, Icons.schedule, RtColors.warning, secondaryText),
          if (breakdown.tips > 0)
            _buildBreakdownItem('Propinas', breakdown.tips, Icons.star, RtColors.warning, secondaryText),
          if (breakdown.bonuses > 0)
            _buildBreakdownItem('Bonos', breakdown.bonuses, Icons.card_giftcard, RtColors.brand, secondaryText),
          if (breakdown.surgeEarnings > 0)
            _buildBreakdownItem('Tarifa dinamica', breakdown.surgeEarnings, Icons.trending_up, RtColors.error, secondaryText),
          const Divider(height: 24, thickness: 1),

          // Desglose de comisión del 20%
          Container(
            padding: const EdgeInsets.all(RtSpacing.md),
            decoration: BoxDecoration(
              color: RtColors.error.withValues(alpha: 0.05),
              borderRadius: RtRadius.borderMd,
              border: Border.all(color: RtColors.error.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, color: RtColors.error, size: RtIconSize.sm),
                    const SizedBox(width: RtSpacing.sm),
                    Text(
                      'Comisión de Plataforma (20%)',
                      style: RtTypo.titleMedium.copyWith(color: RtColors.error, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: RtSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total bruto de viajes:', style: RtTypo.bodySmall.copyWith(color: secondaryText)),
                    Text(_earningsData!.totalEarnings.toCurrency(), style: RtTypo.bodySmall.copyWith(fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: RtSpacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Comisión RapiTeam (20%):', style: RtTypo.bodySmall.copyWith(color: secondaryText)),
                    Text(
                      '-${_earningsData!.commission.toCurrency()}',
                      style: RtTypo.bodySmall.copyWith(fontWeight: FontWeight.w600, color: RtColors.error),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tu ganancia (80%):',
                      style: RtTypo.titleMedium.copyWith(fontWeight: FontWeight.bold, color: RtColors.brand),
                    ),
                    Text(
                      _earningsData!.netEarnings.toCurrency(),
                      style: RtTypo.titleMedium.copyWith(fontWeight: FontWeight.bold, color: RtColors.brand),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: RtSpacing.md),
          const Divider(height: 24, thickness: 1),
          _buildBreakdownItem('Total neto final', _earningsData!.netEarnings, Icons.account_balance_wallet, RtColors.brand, secondaryText, isTotal: true),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(String label, double amount, IconData icon, Color color, Color secondaryText, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RtSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: color, size: RtIconSize.sm),
          const SizedBox(width: RtSpacing.md),
          Expanded(
            child: Text(
              label,
              style: isTotal
                  ? RtTypo.titleLarge.copyWith(fontWeight: FontWeight.bold)
                  : RtTypo.bodyMedium,
            ),
          ),
          Text(
            '${amount >= 0 ? '' : '-'}${amount.abs().toCurrency()}',
            style: isTotal
                ? RtTypo.titleLarge.copyWith(fontWeight: FontWeight.bold, color: color)
                : RtTypo.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                    color: amount >= 0
                        ? Theme.of(context).colorScheme.onSurface
                        : RtColors.error,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsights() {
    return RtCard(
      margin: RtSpacing.paddingBase,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, color: RtColors.info),
              const SizedBox(width: RtSpacing.sm),
              Text('Insights y Recomendaciones', style: RtTypo.headingSmall),
            ],
          ),
          const SizedBox(height: RtSpacing.base),
          _buildInsightCard('Mejores días', 'Martes y Viernes son tus días más rentables', Icons.calendar_today, RtColors.success),
          const SizedBox(height: RtSpacing.md),
          _buildInsightCard('Horario optimo', 'Concentrate en las horas de 7-9 AM y 6-8 PM', Icons.schedule, RtColors.info),
          const SizedBox(height: RtSpacing.md),
          _buildInsightCard('Oportunidad', 'Puedes aumentar 15% trabajando 2 horas más los fines de semana', Icons.trending_up, RtColors.warning),
        ],
      ),
    );
  }

  Widget _buildInsightCard(String title, String description, IconData icon, Color color) {
    final secondaryText = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return Container(
      padding: const EdgeInsets.all(RtSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: RtRadius.borderMd,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(RtSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: RtIconSize.xs),
          ),
          const SizedBox(width: RtSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: RtTypo.titleMedium.copyWith(color: color, fontWeight: FontWeight.bold)),
                Text(description, style: RtTypo.bodySmall.copyWith(color: secondaryText)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _exportData() {
    RtSnackbar.show(context, message: 'Exportando datos de ganancias...', type: RtSnackbarType.info);
  }

  void _shareReport() {
    RtSnackbar.show(context, message: 'Compartiendo reporte de ganancias...', type: RtSnackbarType.info);
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
      ..color = RtColors.brand.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = RtColors.brand
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final maxEarnings = data.map((d) => d.earnings).reduce(math.max);
    final points = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final x = (size.width / (data.length - 1)) * i;
      final y = size.height - (data[i].earnings / maxEarnings * size.height * animation);
      points.add(Offset(x, y));
    }

    // Dibujar area rellena
    final path = Path();
    path.moveTo(0, size.height);
    for (final point in points) {
      path.lineTo(point.dx, point.dy);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);

    // Dibujar linea
    if (points.length > 1) {
      final linePath = Path();
      linePath.moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i < points.length; i++) {
        linePath.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(linePath, linePaint);
    }

    // Dibujar puntos
    final pointPaint = Paint()
      ..color = RtColors.brand
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
            ? RtColors.brand
            : RtColors.brand.withValues(alpha: 0.5);

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Modelos
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
