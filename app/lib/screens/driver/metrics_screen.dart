import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../core/design/design_system.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_card.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../utils/logger.dart';
import '../../utils/firestore_error_handler.dart';

class MetricsScreen extends StatefulWidget {
  const MetricsScreen({super.key});

  @override
  State<MetricsScreen> createState() => _MetricsScreenState();
}

class _MetricsScreenState extends State<MetricsScreen>
    with TickerProviderStateMixin {
  // Controladores de animacion
  late AnimationController _fadeController;
  late AnimationController _chartController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _chartAnimation;

  // Periodo seleccionado
  String _selectedPeriod = 'week';
  int _selectedMetricIndex = 0;

  // Metricas reales desde Firebase (inicialmente 0)
  final Map<String, dynamic> _currentMetrics = {
    'totalTrips': 0,
    'totalEarnings': 0.0,
    'avgRating': 0.0,
    'acceptanceRate': 0.0,
    'cancellationRate': 0.0,
    'onlineHours': 0.0,
    'totalDistance': 0.0,
    'peakHours': <String>[],
    'bestZones': <String>[],
  };

  // Comparaciones reales (inicialmente 0)
  final Map<String, dynamic> _comparisons = {
    'tripsGrowth': 0.0,
    'earningsGrowth': 0.0,
    'ratingChange': 0.0,
    'acceptanceChange': 0.0,
  };

  // Datos semanales reales desde Firebase (inicialmente vacio)
  final List<Map<String, dynamic>> _weeklyData = [
    {'day': 'Lun', 'trips': 0, 'earnings': 0.0, 'hours': 0.0, 'rating': 0.0},
    {'day': 'Mar', 'trips': 0, 'earnings': 0.0, 'hours': 0.0, 'rating': 0.0},
    {'day': 'Mie', 'trips': 0, 'earnings': 0.0, 'hours': 0.0, 'rating': 0.0},
    {'day': 'Jue', 'trips': 0, 'earnings': 0.0, 'hours': 0.0, 'rating': 0.0},
    {'day': 'Vie', 'trips': 0, 'earnings': 0.0, 'hours': 0.0, 'rating': 0.0},
    {'day': 'Sab', 'trips': 0, 'earnings': 0.0, 'hours': 0.0, 'rating': 0.0},
    {'day': 'Dom', 'trips': 0, 'earnings': 0.0, 'hours': 0.0, 'rating': 0.0},
  ];

  // Distribución horaria real desde Firebase (inicialmente vacio)
  final List<Map<String, dynamic>> _hourlyDistribution = [
    {'hour': '00:00', 'trips': 0, 'avg': 0.0},
    {'hour': '01:00', 'trips': 0, 'avg': 0.0},
    {'hour': '02:00', 'trips': 0, 'avg': 0.0},
    {'hour': '03:00', 'trips': 0, 'avg': 0.0},
    {'hour': '04:00', 'trips': 0, 'avg': 0.0},
    {'hour': '05:00', 'trips': 0, 'avg': 0.0},
    {'hour': '06:00', 'trips': 0, 'avg': 0.0},
    {'hour': '07:00', 'trips': 0, 'avg': 0.0},
    {'hour': '08:00', 'trips': 0, 'avg': 0.0},
    {'hour': '09:00', 'trips': 0, 'avg': 0.0},
    {'hour': '10:00', 'trips': 0, 'avg': 0.0},
    {'hour': '11:00', 'trips': 0, 'avg': 0.0},
    {'hour': '12:00', 'trips': 0, 'avg': 0.0},
    {'hour': '13:00', 'trips': 0, 'avg': 0.0},
    {'hour': '14:00', 'trips': 0, 'avg': 0.0},
    {'hour': '15:00', 'trips': 0, 'avg': 0.0},
    {'hour': '16:00', 'trips': 0, 'avg': 0.0},
    {'hour': '17:00', 'trips': 0, 'avg': 0.0},
    {'hour': '18:00', 'trips': 0, 'avg': 0.0},
    {'hour': '19:00', 'trips': 0, 'avg': 0.0},
    {'hour': '20:00', 'trips': 0, 'avg': 0.0},
    {'hour': '21:00', 'trips': 0, 'avg': 0.0},
    {'hour': '22:00', 'trips': 0, 'avg': 0.0},
    {'hour': '23:00', 'trips': 0, 'avg': 0.0},
  ];

  // Datos de zonas rentables desde Firebase
  final List<Map<String, dynamic>> _zonesData = [];

  // Metas reales desde Firebase (inicialmente 0)
  final List<Map<String, dynamic>> _goals = [
    {
      'title': 'Viajes Diarios',
      'current': 0,
      'target': 25,
      'icon': Icons.route,
      'color': RtColors.info,
    },
    {
      'title': 'Ganancias Semanales',
      'current': 0.0,
      'target': 4000.00,
      'icon': Icons.account_balance_wallet,
      'color': RtColors.brand,
    },
    {
      'title': 'Calificación',
      'current': 0.0,
      'target': 5.0,
      'icon': Icons.star,
      'color': RtColors.warning,
    },
    {
      'title': 'Horas en Linea',
      'current': 0,
      'target': 50,
      'icon': Icons.timer,
      'color': RtColors.accentPurple,
    },
  ];

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _chartController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: RtCurve.enter,
    );

    _chartAnimation = CurvedAnimation(
      parent: _chartController,
      curve: RtCurve.emphasis,
    );

    _fadeController.forward();
    _chartController.forward();

    // Cargar metricas reales al iniciar
    _loadRealMetricsFromFirebase();
  }

  // Cargar metricas reales desde Firebase
  Future<void> _loadRealMetricsFromFirebase() async {
    try {
      // Obtener ID real del conductor autenticado desde AuthProvider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        AppLogger.warning('No hay usuario autenticado. Mostrando datos en 0.');
        return;
      }

      final driverId = currentUser.id;
      AppLogger.info('Cargando metricas para conductor: ${currentUser.fullName} ($driverId)');

      // Calcular rango de fechas según período seleccionado
      final now = DateTime.now();
      DateTime startDate;

      switch (_selectedPeriod) {
        case 'day':
          startDate = DateTime(now.year, now.month, now.day);
          break;
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

      // Consultar viajes completados en Firebase
      final ridesSnapshot = await FirebaseFirestore.instance
          .collection('rides')
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'completed')
          .limit(100)
          .get();

      // Filtrar por fecha en memoria (para evitar crear más indices)
      final filteredRides = ridesSnapshot.docs.where((doc) {
        final data = doc.data();
        final completedAt = data['completedAt'] as Timestamp?;
        if (completedAt == null) return false;
        return completedAt.toDate().isAfter(startDate);
      }).toList();

      // Calcular metricas generales
      int totalTrips = filteredRides.length;
      double totalEarnings = 0.0;
      double totalRating = 0.0;
      int ratingCount = 0;
      double totalDistance = 0.0;

      // Estructuras para datos semanales, horarios y zonas
      final Map<int, Map<String, dynamic>> weeklyDataMap = {
        1: {'day': 'Lun', 'trips': 0, 'earnings': 0.0, 'hours': 0.0, 'rating': 0.0, 'ratingCount': 0},
        2: {'day': 'Mar', 'trips': 0, 'earnings': 0.0, 'hours': 0.0, 'rating': 0.0, 'ratingCount': 0},
        3: {'day': 'Mie', 'trips': 0, 'earnings': 0.0, 'hours': 0.0, 'rating': 0.0, 'ratingCount': 0},
        4: {'day': 'Jue', 'trips': 0, 'earnings': 0.0, 'hours': 0.0, 'rating': 0.0, 'ratingCount': 0},
        5: {'day': 'Vie', 'trips': 0, 'earnings': 0.0, 'hours': 0.0, 'rating': 0.0, 'ratingCount': 0},
        6: {'day': 'Sab', 'trips': 0, 'earnings': 0.0, 'hours': 0.0, 'rating': 0.0, 'ratingCount': 0},
        7: {'day': 'Dom', 'trips': 0, 'earnings': 0.0, 'hours': 0.0, 'rating': 0.0, 'ratingCount': 0},
      };

      final Map<int, Map<String, dynamic>> hourlyDataMap = {};
      for (int h = 0; h < 24; h++) {
        hourlyDataMap[h] = {
          'hour': '${h.toString().padLeft(2, '0')}:00',
          'trips': 0,
          'earnings': 0.0,
        };
      }

      final Map<String, Map<String, dynamic>> zonesMap = {};

      // Procesar cada viaje
      for (var doc in filteredRides) {
        final data = doc.data();
        final fare = (data['fare'] as num?)?.toDouble() ?? 0.0;
        final distance = (data['distance'] as num?)?.toDouble() ?? 0.0;
        final rating = (data['rating'] as num?)?.toDouble();
        final completedAt = (data['completedAt'] as Timestamp?)?.toDate();

        totalEarnings += fare;
        totalDistance += distance;

        if (rating != null) {
          totalRating += rating;
          ratingCount++;
        }

        // Agrupar pordía de la semana
        if (completedAt != null) {
          final weekday = completedAt.weekday;
          if (weeklyDataMap.containsKey(weekday)) {
            weeklyDataMap[weekday]!['trips'] = (weeklyDataMap[weekday]!['trips'] as int) + 1;
            weeklyDataMap[weekday]!['earnings'] = (weeklyDataMap[weekday]!['earnings'] as double) + fare;
            if (rating != null) {
              weeklyDataMap[weekday]!['rating'] = (weeklyDataMap[weekday]!['rating'] as double) + rating;
              weeklyDataMap[weekday]!['ratingCount'] = (weeklyDataMap[weekday]!['ratingCount'] as int) + 1;
            }
          }

          // Agrupar por hora
          final hour = completedAt.hour;
          if (hourlyDataMap.containsKey(hour)) {
            hourlyDataMap[hour]!['trips'] = (hourlyDataMap[hour]!['trips'] as int) + 1;
            hourlyDataMap[hour]!['earnings'] = (hourlyDataMap[hour]!['earnings'] as double) + fare;
          }
        }

        // Agrupar por zona
        final pickupZone = data['pickupLocationName'] as String? ?? 'Desconocido';
        final dropoffZone = data['dropoffLocationName'] as String? ?? 'Desconocido';

        if (!zonesMap.containsKey(pickupZone)) {
          zonesMap[pickupZone] = {'zone': pickupZone, 'trips': 0, 'earnings': 0.0};
        }
        zonesMap[pickupZone]!['trips'] = (zonesMap[pickupZone]!['trips'] as int) + 1;
        zonesMap[pickupZone]!['earnings'] = (zonesMap[pickupZone]!['earnings'] as double) + fare / 2;

        if (!zonesMap.containsKey(dropoffZone)) {
          zonesMap[dropoffZone] = {'zone': dropoffZone, 'trips': 0, 'earnings': 0.0};
        }
        zonesMap[dropoffZone]!['trips'] = (zonesMap[dropoffZone]!['trips'] as int) + 1;
        zonesMap[dropoffZone]!['earnings'] = (zonesMap[dropoffZone]!['earnings'] as double) + fare / 2;
      }

      // Convertir datos semanales a lista
      final weeklyList = weeklyDataMap.values.map((day) {
        final ratingCount = day['ratingCount'] as int;
        final avgRating = ratingCount > 0 ? (day['rating'] as double) / ratingCount : 0.0;
        return {
          'day': day['day'],
          'trips': day['trips'],
          'earnings': day['earnings'],
          'hours': day['hours'],
          'rating': avgRating,
        };
      }).toList();

      // Convertir datos horarios a lista
      final hourlyList = hourlyDataMap.values.toList();

      // Identificar horas pico (top 3 horas con más viajes)
      final sortedHours = hourlyList.toList()
        ..sort((a, b) => (b['trips'] as int).compareTo(a['trips'] as int));
      final peakHoursList = <String>[];
      for (int i = 0; i < math.min(3, sortedHours.length); i++) {
        if ((sortedHours[i]['trips'] as int) > 0) {
          peakHoursList.add(sortedHours[i]['hour'] as String);
        }
      }

      // Top 3 zonas más rentables
      final sortedZones = zonesMap.values.toList()
        ..sort((a, b) => (b['earnings'] as double).compareTo(a['earnings'] as double));
      final topZonesData = sortedZones.take(3).toList();
      final topZones = topZonesData.map((z) => z['zone'] as String).toList();

      double avgRating = ratingCount > 0 ? totalRating / ratingCount : 0.0;

      if (!mounted) return;
      setState(() {
        _currentMetrics['totalTrips'] = totalTrips;
        _currentMetrics['totalEarnings'] = totalEarnings;
        _currentMetrics['avgRating'] = avgRating;
        _currentMetrics['totalDistance'] = totalDistance;
        _currentMetrics['peakHours'] = peakHoursList;
        _currentMetrics['bestZones'] = topZones;

        _weeklyData.clear();
        _weeklyData.addAll(weeklyList);

        _hourlyDistribution.clear();
        _hourlyDistribution.addAll(hourlyList);

        _zonesData.clear();
        _zonesData.addAll(topZonesData);
      });

      AppLogger.info('Metricas completas cargadas:');
      AppLogger.debug('   - $totalTrips viajes, S/. ${totalEarnings.toStringAsFixed(2)}');
      AppLogger.debug('   - Horas pico: ${peakHoursList.join(", ")}');
      AppLogger.debug('   - Top zonas: ${topZones.join(", ")}');
    } catch (e) {
      AppLogger.error('Error cargando metricas: $e');
      // Mantener valores en 0 si hay error
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _chartController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: RtAppBar(
        title: 'Mis Metricas',
        variant: RtAppBarVariant.gradient,
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: RtColors.white),
            onPressed: _exportReport,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: RtColors.white),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Selector de período
                  _buildPeriodSelector(),

                  // Cards de resumen
                  _buildSummaryCards(),

                  // Grafico de rendimiento
                  _buildPerformanceChart(),

                  // Progreso de metas
                  _buildGoalsSection(),

                  // Distribución horaria
                  _buildHourlyDistribution(),

                  // Mejores zonas
                  _buildBestZones(),

                  // Comparación con otros
                  _buildComparison(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(RtSpacing.base),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          Expanded(child: _buildPeriodButton('Día', 'day')),
          const SizedBox(width: RtSpacing.sm),
          Expanded(child: _buildPeriodButton('Semana', 'week')),
          const SizedBox(width: RtSpacing.sm),
          Expanded(child: _buildPeriodButton('Mes', 'month')),
          const SizedBox(width: RtSpacing.sm),
          Expanded(child: _buildPeriodButton('Año', 'year')),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String label, String value) {
    final isSelected = _selectedPeriod == value;

    return InkWell(
      onTap: () {
        setState(() => _selectedPeriod = value);
        _loadRealMetricsFromFirebase();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: RtSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? RtColors.brand : Theme.of(context).colorScheme.surface,
          borderRadius: RtRadius.borderMd,
          border: Border.all(
            color: isSelected ? RtColors.brand : RtColors.neutral200,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: RtTypo.labelLarge.copyWith(
            color: isSelected ? RtColors.white : RtColors.neutral500,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(RtSpacing.base),
        children: [
          _buildMetricCard(
            'Viajes',
            '${_currentMetrics['totalTrips']}',
            Icons.route,
            RtColors.info,
            '+${_comparisons['tripsGrowth']}%',
            true,
          ),
          _buildMetricCard(
            'Ganancias',
            'S/. ${_currentMetrics['totalEarnings']}',
            Icons.account_balance_wallet,
            RtColors.brand,
            '+${_comparisons['earningsGrowth']}%',
            true,
          ),
          _buildMetricCard(
            'Calificación',
            '${_currentMetrics['avgRating']}',
            Icons.star,
            RtColors.warning,
            '+${_comparisons['ratingChange']}',
            true,
          ),
          _buildMetricCard(
            'Aceptación',
            '${_currentMetrics['acceptanceRate']}%',
            Icons.check_circle,
            RtColors.accentPurple,
            '+${_comparisons['acceptanceChange']}%',
            true,
          ),
          _buildMetricCard(
            'Horas',
            '${_currentMetrics['onlineHours']}h',
            Icons.timer,
            RtColors.accentAmber,
            '',
            false,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String change,
    bool showChange,
  ) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: RtSpacing.md),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: RtRadius.borderMd,
        boxShadow: RtShadow.soft(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 22),
              if (showChange && change.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: RtColors.success.withValues(alpha: 0.1),
                    borderRadius: RtRadius.borderSm,
                  ),
                  child: Text(
                    change,
                    style: RtTypo.labelSmall.copyWith(
                      color: RtColors.success,
                      fontWeight: FontWeight.w700,
                      fontSize: 9,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: RtTypo.headingSmall.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 17,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            title,
            style: RtTypo.labelSmall.copyWith(
              color: RtColors.neutral500,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceChart() {
    return RtCard(
      margin: const EdgeInsets.all(RtSpacing.base),
      padding: const EdgeInsets.all(RtSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedPeriod == 'day' ? 'Rendimiento Diario' :
                _selectedPeriod == 'week' ? 'Rendimiento Semanal' :
                _selectedPeriod == 'month' ? 'Rendimiento Mensual' :
                'Rendimiento Anual',
                style: RtTypo.headingSmall,
              ),
              Row(
                children: [
                  _buildChartToggle(Icons.show_chart, 0),
                  const SizedBox(width: RtSpacing.sm),
                  _buildChartToggle(Icons.bar_chart, 1),
                ],
              ),
            ],
          ),
          const SizedBox(height: RtSpacing.lg),

          SizedBox(
            height: 200,
            child: AnimatedBuilder(
              animation: _chartAnimation,
              builder: (context, child) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: _selectedMetricIndex == 0
                      ? LineChartPainter(
                          data: _weeklyData,
                          progress: _chartAnimation.value,
                        )
                      : BarChartPainter(
                          data: _weeklyData,
                          progress: _chartAnimation.value,
                        ),
                );
              },
            ),
          ),

          const SizedBox(height: RtSpacing.base),

          // Leyenda del grafico
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _weeklyData.map((data) {
              return Column(
                children: [
                  Text(
                    data['day'],
                    style: RtTypo.labelSmall.copyWith(color: RtColors.neutral500),
                  ),
                  Text(
                    '${data['trips']}',
                    style: RtTypo.labelMedium.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChartToggle(IconData icon, int index) {
    final isSelected = _selectedMetricIndex == index;

    return InkWell(
      onTap: () {
        setState(() => _selectedMetricIndex = index);
        _chartController.reset();
        _chartController.forward();
      },
      child: Container(
        padding: const EdgeInsets.all(RtSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected
              ? RtColors.brand.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.surface,
          borderRadius: RtRadius.borderSm,
        ),
        child: Icon(
          icon,
          color: isSelected ? RtColors.brand : RtColors.neutral500,
          size: RtIconSize.sm,
        ),
      ),
    );
  }

  Widget _buildGoalsSection() {
    return RtCard(
      margin: const EdgeInsets.symmetric(horizontal: RtSpacing.base),
      padding: const EdgeInsets.all(RtSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Objetivos y Metas',
            style: RtTypo.headingSmall,
          ),
          const SizedBox(height: RtSpacing.base),

          ..._goals.map((goal) => _buildGoalItem(goal)),
        ],
      ),
    );
  }

  Widget _buildGoalItem(Map<String, dynamic> goal) {
    final progress = (goal['current'] / goal['target']).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: RtSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(goal['icon'], color: goal['color'], size: RtIconSize.sm),
                  const SizedBox(width: RtSpacing.sm),
                  Text(
                    goal['title'],
                    style: RtTypo.titleMedium.copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              Text(
                '${goal['current']} / ${goal['target']}',
                style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500),
              ),
            ],
          ),
          const SizedBox(height: RtSpacing.sm),

          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: (goal['color'] as Color).withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(goal['color']),
              minHeight: 6,
            ),
          ),

          const SizedBox(height: RtSpacing.xs),
          Text(
            '${(progress * 100).round()}% completado',
            style: RtTypo.labelSmall.copyWith(color: RtColors.neutral500),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyDistribution() {
    return RtCard(
      margin: const EdgeInsets.all(RtSpacing.base),
      padding: const EdgeInsets.all(RtSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Distribución por Horas',
            style: RtTypo.headingSmall,
          ),
          const SizedBox(height: RtSpacing.sm),
          Text(
            'Identifica tus horas más productivas',
            style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500),
          ),
          const SizedBox(height: RtSpacing.base),

          SizedBox(
            height: 150,
            child: CustomPaint(
              size: Size.infinite,
              painter: HourlyChartPainter(
                data: _hourlyDistribution,
                peakHours: _currentMetrics['peakHours'],
              ),
            ),
          ),

          const SizedBox(height: RtSpacing.base),

          // Información de horas pico
          Container(
            padding: const EdgeInsets.all(RtSpacing.md),
            decoration: BoxDecoration(
              color: RtColors.brand.withValues(alpha: 0.1),
              borderRadius: RtRadius.borderMd,
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_up, color: RtColors.brand),
                const SizedBox(width: RtSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Horas Pico',
                        style: RtTypo.titleMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: RtColors.brand,
                        ),
                      ),
                      Text(
                        (_currentMetrics['peakHours'] as List).join(', '),
                        style: RtTypo.bodySmall,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBestZones() {
    return RtCard(
      margin: const EdgeInsets.symmetric(horizontal: RtSpacing.base),
      padding: const EdgeInsets.all(RtSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Zonas Mas Rentables',
            style: RtTypo.headingSmall,
          ),
          const SizedBox(height: RtSpacing.base),

          ..._zonesData.asMap().entries.map((entry) {
            final index = entry.key;
            final zoneData = entry.value;
            final zone = zoneData['zone'] as String;
            final earnings = (zoneData['earnings'] as double);
            final trips = (zoneData['trips'] as int);

            return Container(
              margin: const EdgeInsets.only(bottom: RtSpacing.md),
              padding: const EdgeInsets.all(RtSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: RtRadius.borderMd,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: RtColors.brand.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: RtTypo.titleMedium.copyWith(
                          color: RtColors.brand,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: RtSpacing.md),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          zone,
                          style: RtTypo.titleMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Text(
                          '$trips viajes',
                          style: RtTypo.labelSmall.copyWith(
                            color: RtColors.neutral500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: RtSpacing.sm),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'S/. ${earnings.toStringAsFixed(2)}',
                          style: RtTypo.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: RtColors.brand,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Text(
                          trips > 0 ? 'S/. ${(earnings / trips).toStringAsFixed(2)}/viaje' : 'Sin viajes',
                          style: RtTypo.labelSmall.copyWith(
                            color: RtColors.neutral500,
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildComparison() {
    // Mostrar placeholder profesional mientras no haya comparación real
    return Container(
      margin: const EdgeInsets.all(RtSpacing.base),
      padding: const EdgeInsets.all(RtSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            RtColors.brand.withValues(alpha: 0.8),
            RtColors.brand.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: RtRadius.borderMd,
        boxShadow: RtShadow.soft(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.leaderboard,
            size: 48,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          const SizedBox(height: RtSpacing.base),
          Text(
            'Comparación con Otros Conductores',
            style: RtTypo.headingSmall.copyWith(color: RtColors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: RtSpacing.md),
          Text(
            'Requiere datos de al menos 10 conductores activos en el sistema',
            style: RtTypo.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: RtSpacing.base),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: RtSpacing.base, vertical: RtSpacing.sm),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.2),
              borderRadius: RtRadius.borderMd,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.trending_up, color: RtColors.white, size: RtIconSize.sm),
                const SizedBox(width: RtSpacing.sm),
                Flexible(
                  child: Text(
                    'Sigue trabajando para mejorar tu ranking',
                    style: RtTypo.labelMedium.copyWith(
                      color: RtColors.white,
                      fontWeight: FontWeight.w700,
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

  void _exportReport() async {
    try {
      final format = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Exportar Reporte'),
          content: const Text('En qué formato deseas exportar el reporte?'),
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

      final reportData = _generateReportData();

      if (format == 'csv') {
        await _exportToCSV(reportData);
      } else if (format == 'pdf') {
        await _exportToPDF(reportData);
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

  String _generateReportData() {
    final buffer = StringBuffer();
    buffer.writeln('REPORTE DE METRICAS - RAPITEAM');
    buffer.writeln('Fecha: ${DateTime.now().toString().split('.')[0]}');
    buffer.writeln('Periodo: $_selectedPeriod');
    buffer.writeln('');
    buffer.writeln('RESUMEN:');
    buffer.writeln('- Total Viajes: ${_currentMetrics['totalTrips']}');
    buffer.writeln('- Ganancias: S/. ${_currentMetrics['totalEarnings']}');
    buffer.writeln('- Calificación Promedio: ${_currentMetrics['avgRating']}');
    buffer.writeln('- Tasa de Aceptación: ${_currentMetrics['acceptanceRate']}%');
    buffer.writeln('- Horas en Linea: ${_currentMetrics['onlineHours']}h');
    buffer.writeln('');
    buffer.writeln('RENDIMIENTO SEMANAL:');
    for (var day in _weeklyData) {
      buffer.writeln('${day['day']}: ${day['trips']} viajes, S/. ${day['earnings']}');
    }
    return buffer.toString();
  }

  Future<void> _exportToCSV(String data) async {
    try {
      final List<List<dynamic>> csvData = [
        ['REPORTE DE METRICAS - RAPITEAM'],
        ['Fecha', DateTime.now().toString().split('.')[0]],
        ['Periodo', _selectedPeriod],
        [],
        ['RESUMEN'],
        ['Metrica', 'Valor'],
        ['Total Viajes', _currentMetrics['totalTrips']],
        ['Ganancias', 'S/. ${_currentMetrics['totalEarnings']}'],
        ['Calificación Promedio', _currentMetrics['avgRating']],
        ['Tasa de Aceptación', '${_currentMetrics['acceptanceRate']}%'],
        ['Horas en Linea', '${_currentMetrics['onlineHours']}h'],
        [],
        ['RENDIMIENTO SEMANAL'],
        ['Día', 'Viajes', 'Ganancias'],
        ..._weeklyData.map((day) => [
          day['day'],
          day['trips'],
          'S/. ${day['earnings']}'
        ]),
      ];

      String csvString = const ListToCsvConverter().convert(csvData);
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/metricas_rapiteam_$timestamp.csv';
      final file = File(filePath);
      await file.writeAsString(csvString);

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Reporte de Metricas - RapiTeam',
        text: 'Reporte de metricas generado el ${DateTime.now().toString().split('.')[0]}',
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
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
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
                        'REPORTE DE METRICAS',
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
                  'Fecha: ${DateTime.now().toString().split('.')[0]}',
                  style: pw.TextStyle(font: ttfRegular, fontSize: 12),
                ),
                pw.Text(
                  'Periodo: $_selectedPeriod',
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
                    _buildPdfTableRow('Total Viajes', '${_currentMetrics['totalTrips']}', true, ttfRegular, ttfBold),
                    _buildPdfTableRow('Ganancias', 'S/. ${_currentMetrics['totalEarnings']}', false, ttfRegular, ttfBold),
                    _buildPdfTableRow('Calificación Promedio', '${_currentMetrics['avgRating']}', true, ttfRegular, ttfBold),
                    _buildPdfTableRow('Tasa de Aceptación', '${_currentMetrics['acceptanceRate']}%', false, ttfRegular, ttfBold),
                    _buildPdfTableRow('Horas en Linea', '${_currentMetrics['onlineHours']}h', true, ttfRegular, ttfBold),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'RENDIMIENTO SEMANAL',
                  style: pw.TextStyle(font: ttfBold, fontSize: 16),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColor.fromHex('#E31E24')),
                      children: [
                        _buildPdfHeaderCell('Día', ttfBold),
                        _buildPdfHeaderCell('Viajes', ttfBold),
                        _buildPdfHeaderCell('Ganancias', ttfBold),
                      ],
                    ),
                    ..._weeklyData.map((day) => pw.TableRow(
                      children: [
                        _buildPdfCell('${day['day']}', ttfRegular),
                        _buildPdfCell('${day['trips']}', ttfRegular),
                        _buildPdfCell('S/. ${day['earnings']}', ttfRegular),
                      ],
                    )),
                  ],
                ),
              ],
            );
          },
        ),
      );

      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/metricas_rapiteam_$timestamp.pdf';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Reporte de Metricas - RapiTeam',
        text: 'Reporte de metricas generado el ${DateTime.now().toString().split('.')[0]}',
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

  pw.TableRow _buildPdfTableRow(String label, String value, bool isEven, pw.Font fontRegular, pw.Font fontBold) {
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
        style: pw.TextStyle(font: font, color: PdfColors.white),
      ),
    );
  }

  pw.Widget _buildPdfCell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text, style: pw.TextStyle(font: font)),
    );
  }

  void _refreshData() {
    setState(() {
      _chartController.reset();
      _chartController.forward();
    });

    // Recargar metricas desde Firebase
    _loadRealMetricsFromFirebase();

    RtSnackbar.show(
      context,
      message: 'Datos actualizados',
      type: RtSnackbarType.info,
    );
  }
}

// Painter de grafico de linea
class LineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double progress;

  const LineChartPainter({super.repaint, required this.data, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = RtColors.brand
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = RtColors.brand.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final dotPaint = Paint()
      ..color = RtColors.brand
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    // Proteccion contra division por cero
    double maxValue = math.max(1.0, data.map((d) => d['trips'] as int).reduce(math.max).toDouble());

    for (int i = 0; i < data.length; i++) {
      final x = (size.width / (data.length - 1)) * i;
      final y = size.height - (size.height * (data[i]['trips'] / maxValue) * progress);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      // Dibujar puntos
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(LineChartPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// Painter de grafico de barras
class BarChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double progress;

  const BarChartPainter({super.repaint, required this.data, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = RtColors.brand
      ..style = PaintingStyle.fill;

    // Proteccion contra division por cero
    double maxValue = math.max(1.0, data.map((d) => d['earnings'] as double).reduce(math.max));
    final barWidth = size.width / (data.length * 2);

    for (int i = 0; i < data.length; i++) {
      final x = (size.width / data.length) * i + barWidth / 2;
      final barHeight = (size.height * (data[i]['earnings'] / maxValue) * progress);
      final y = size.height - barHeight;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(4),
      );

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(BarChartPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// Painter de distribución horaria
class HourlyChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final List<String> peakHours;

  const HourlyChartPainter({super.repaint, required this.data, required this.peakHours});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    // Proteccion contra division por cero
    double maxTrips = math.max(1.0, data.map((d) => d['trips'] as int).reduce(math.max).toDouble());
    final barWidth = size.width / data.length;

    for (int i = 0; i < data.length; i++) {
      final hour = data[i]['hour'] as String;
      final trips = data[i]['trips'] as int;
      final barHeight = (size.height * (trips / maxTrips));

      // Verificar si es hora pico
      bool isPeakHour = false;
      for (String peak in peakHours) {
        final range = peak.split('-');
        final startHour = int.parse(range[0].split(':')[0]);
        final endHour = int.parse(range[1].split(':')[0]);
        final currentHour = int.parse(hour.split(':')[0]);

        if (currentHour >= startHour && currentHour <= endHour) {
          isPeakHour = true;
          break;
        }
      }

      paint.color = isPeakHour
          ? RtColors.brand
          : RtColors.brand.withValues(alpha: 0.3);

      final rect = Rect.fromLTWH(
        i * barWidth,
        size.height - barHeight,
        barWidth - 1,
        barHeight,
      );

      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(HourlyChartPainter oldDelegate) => false;
}
