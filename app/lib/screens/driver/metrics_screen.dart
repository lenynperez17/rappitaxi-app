// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ Para cargar assets (fuente TTF)
import 'dart:math' as math;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart'; // ✅ NUEVO
import '../../providers/auth_provider.dart'; // ✅ NUEVO
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart'; // ✅ Extensión para colores que se adaptan al tema

import '../../utils/logger.dart';
class MetricsScreen extends StatefulWidget {
  const MetricsScreen({super.key});

  @override
  _MetricsScreenState createState() => _MetricsScreenState();
}

class _MetricsScreenState extends State<MetricsScreen> 
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _chartController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _chartAnimation;
  
  // Selected period
  String _selectedPeriod = 'week';
  int _selectedMetricIndex = 0;
  
  // ✅ Métricas reales desde Firebase (inicialmente 0)
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

  // ✅ Comparaciones reales (inicialmente 0)
  final Map<String, dynamic> _comparisons = {
    'tripsGrowth': 0.0,
    'earningsGrowth': 0.0,
    'ratingChange': 0.0,
    'acceptanceChange': 0.0,
  };

  // ✅ Datos semanales reales desde Firebase (inicialmente vacío)
  final List<Map<String, dynamic>> _weeklyData = [
    {'day': 'Lun', 'trips': 0, 'earnings': 0.0, 'hours': 0.0, 'rating': 0.0},
    {'day': 'Mar', 'trips': 0, 'earnings': 0.0, 'hours': 0.0, 'rating': 0.0},
    {'day': 'Mié', 'trips': 0, 'earnings': 0.0, 'hours': 0.0, 'rating': 0.0},
    {'day': 'Jue', 'trips': 0, 'earnings': 0.0, 'hours': 0.0, 'rating': 0.0},
    {'day': 'Vie', 'trips': 0, 'earnings': 0.0, 'hours': 0.0, 'rating': 0.0},
    {'day': 'Sáb', 'trips': 0, 'earnings': 0.0, 'hours': 0.0, 'rating': 0.0},
    {'day': 'Dom', 'trips': 0, 'earnings': 0.0, 'hours': 0.0, 'rating': 0.0},
  ];

  // ✅ Distribución horaria real desde Firebase (inicialmente vacío)
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

  // ✅ NUEVO: Datos de zonas rentables desde Firebase
  final List<Map<String, dynamic>> _zonesData = [];

  // ✅ Metas reales desde Firebase (inicialmente 0)
  final List<Map<String, dynamic>> _goals = [
    {
      'title': 'Viajes Diarios',
      'current': 0,
      'target': 25,
      'icon': Icons.route,
      'color': ModernTheme.primaryBlue,
    },
    {
      'title': 'Ganancias Semanales',
      'current': 0.0,
      'target': 4000.00,
      'icon': Icons.account_balance_wallet, // ✅ Cambiado de attach_money ($) a wallet
      'color': ModernTheme.rappiOrange,
    },
    {
      'title': 'Calificación',
      'current': 0.0,
      'target': 5.0,
      'icon': Icons.star,
      'color': ModernTheme.accentYellow,
    },
    {
      'title': 'Horas en Línea',
      'current': 0,
      'target': 50,
      'icon': Icons.timer,
      'color': Colors.purple,
    },
  ];
  
  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _chartController = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _chartAnimation = CurvedAnimation(
      parent: _chartController,
      curve: Curves.easeInOut,
    );

    _fadeController.forward();
    _chartController.forward();

    // ✅ CARGAR MÉTRICAS REALES AL INICIAR
    _loadRealMetricsFromFirebase();
  }

  // ✅ NUEVO: Cargar métricas reales desde Firebase
  Future<void> _loadRealMetricsFromFirebase() async {
    try {
      // ✅ OBTENER ID REAL del conductor autenticado desde AuthProvider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        AppLogger.warning('⚠️ No hay usuario autenticado. Mostrando datos en 0.');
        return;
      }

      final driverId = currentUser.id;
      AppLogger.info('✅ Cargando métricas para conductor: ${currentUser.fullName} ($driverId)');
      // Calcular rango de fechas según período seleccionado
      final now = DateTime.now();
      DateTime startDate;

      switch (_selectedPeriod) {
        case 'day':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'week':
          startDate = now.subtract(Duration(days: 7));
          break;
        case 'month':
          startDate = now.subtract(Duration(days: 30));
          break;
        case 'year':
          startDate = now.subtract(Duration(days: 365));
          break;
        default:
          startDate = now.subtract(Duration(days: 7));
      }

      // Consultar viajes completados en Firebase (sin índice requerido)
      // NOTA: Esta query NO requiere índice compuesto porque solo filtra por driverId y status
      // ✅ IMPORTANTE: limit(100) requerido por reglas de Firestore
      final ridesSnapshot = await FirebaseFirestore.instance
          .collection('rides')
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'completed')
          .limit(100)
          .get();

      // Filtrar por fecha en memoria (para evitar crear más índices)
      // Usar completedAt o requestedAt como fallback
      final filteredRides = ridesSnapshot.docs.where((doc) {
        final data = doc.data();
        final completedAt = data['completedAt'] as Timestamp?;
        final requestedAt = data['requestedAt'] as Timestamp?;
        final dateToCheck = completedAt ?? requestedAt;
        if (dateToCheck == null) return false;
        return dateToCheck.toDate().isAfter(startDate);
      }).toList();

      // Calcular métricas generales
      int totalTrips = filteredRides.length;
      double totalEarnings = 0.0;
      double totalRating = 0.0;
      int ratingCount = 0;
      double totalDistance = 0.0;

      // ✅ NUEVO: Estructuras para datos semanales, horarios y zonas
      final Map<int, Map<String, dynamic>> weeklyDataMap = {
        1: {'day': 'Lun', 'trips': 0, 'earnings': 0.0, 'hours': 0.0, 'rating': 0.0, 'ratingCount': 0},
        2: {'day': 'Mar', 'trips': 0, 'earnings': 0.0, 'hours': 0.0, 'rating': 0.0, 'ratingCount': 0},
        3: {'day': 'Mié', 'trips': 0, 'earnings': 0.0, 'hours': 0.0, 'rating': 0.0, 'ratingCount': 0},
        4: {'day': 'Jue', 'trips': 0, 'earnings': 0.0, 'hours': 0.0, 'rating': 0.0, 'ratingCount': 0},
        5: {'day': 'Vie', 'trips': 0, 'earnings': 0.0, 'hours': 0.0, 'rating': 0.0, 'ratingCount': 0},
        6: {'day': 'Sáb', 'trips': 0, 'earnings': 0.0, 'hours': 0.0, 'rating': 0.0, 'ratingCount': 0},
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

        // ✅ Agrupar por día de la semana
        if (completedAt != null) {
          final weekday = completedAt.weekday; // 1=Lun, 7=Dom
          if (weeklyDataMap.containsKey(weekday)) {
            weeklyDataMap[weekday]!['trips'] = (weeklyDataMap[weekday]!['trips'] as int) + 1;
            weeklyDataMap[weekday]!['earnings'] = (weeklyDataMap[weekday]!['earnings'] as num).toDouble() + fare;
            if (rating != null) {
              weeklyDataMap[weekday]!['rating'] = (weeklyDataMap[weekday]!['rating'] as num).toDouble() + rating;
              weeklyDataMap[weekday]!['ratingCount'] = (weeklyDataMap[weekday]!['ratingCount'] as int) + 1;
            }
          }

          // ✅ Agrupar por hora
          final hour = completedAt.hour;
          if (hourlyDataMap.containsKey(hour)) {
            hourlyDataMap[hour]!['trips'] = (hourlyDataMap[hour]!['trips'] as int) + 1;
            hourlyDataMap[hour]!['earnings'] = (hourlyDataMap[hour]!['earnings'] as num).toDouble() + fare;
          }
        }

        // ✅ Agrupar por zona (usando pickup o dropoff location name)
        final pickupZone = data['pickupLocationName'] as String? ?? 'Desconocido';
        final dropoffZone = data['dropoffLocationName'] as String? ?? 'Desconocido';

        // Contar zona de pickup
        if (!zonesMap.containsKey(pickupZone)) {
          zonesMap[pickupZone] = {'zone': pickupZone, 'trips': 0, 'earnings': 0.0};
        }
        zonesMap[pickupZone]!['trips'] = (zonesMap[pickupZone]!['trips'] as int) + 1;
        zonesMap[pickupZone]!['earnings'] = (zonesMap[pickupZone]!['earnings'] as num).toDouble() + fare / 2;

        // Contar zona de dropoff
        if (!zonesMap.containsKey(dropoffZone)) {
          zonesMap[dropoffZone] = {'zone': dropoffZone, 'trips': 0, 'earnings': 0.0};
        }
        zonesMap[dropoffZone]!['trips'] = (zonesMap[dropoffZone]!['trips'] as int) + 1;
        zonesMap[dropoffZone]!['earnings'] = (zonesMap[dropoffZone]!['earnings'] as num).toDouble() + fare / 2;
      }

      // ✅ Convertir datos semanales a lista
      final weeklyList = weeklyDataMap.values.map((day) {
        final ratingCount = day['ratingCount'] as int;
        final avgRating = ratingCount > 0 ? (day['rating'] as num).toDouble() / ratingCount : 0.0;
        return {
          'day': day['day'],
          'trips': day['trips'],
          'earnings': day['earnings'],
          'hours': day['hours'],
          'rating': avgRating,
        };
      }).toList();

      // ✅ Convertir datos horarios a lista
      final hourlyList = hourlyDataMap.values.toList();

      // ✅ Identificar horas pico (top 3 horas con más viajes)
      final sortedHours = hourlyList.toList()
        ..sort((a, b) => (b['trips'] as int).compareTo(a['trips'] as int));
      final peakHoursList = <String>[];
      for (int i = 0; i < math.min(3, sortedHours.length); i++) {
        if ((sortedHours[i]['trips'] as int) > 0) {
          peakHoursList.add(sortedHours[i]['hour'] as String);
        }
      }

      // ✅ Top 3 zonas más rentables (con datos completos)
      final sortedZones = zonesMap.values.toList()
        ..sort((a, b) => (b['earnings'] as num).toDouble().compareTo((a['earnings'] as num).toDouble()));
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

        // ✅ Actualizar datos semanales
        _weeklyData.clear();
        _weeklyData.addAll(weeklyList);

        // ✅ Actualizar distribución horaria
        _hourlyDistribution.clear();
        _hourlyDistribution.addAll(hourlyList);

        // ✅ Actualizar datos de zonas
        _zonesData.clear();
        _zonesData.addAll(topZonesData);
      });

      AppLogger.info('✅ Métricas completas cargadas:');
      AppLogger.debug('   - $totalTrips viajes, S/. ${totalEarnings.toStringAsFixed(2)}');
      AppLogger.debug('   - Horas pico: ${peakHoursList.join(", ")}');
      AppLogger.debug('   - Top zonas: ${topZones.join(", ")}');
    } catch (e) {
      AppLogger.error('❌ Error cargando métricas: $e');
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
      backgroundColor: context.surfaceColor,
      appBar: AppBar(
        backgroundColor: ModernTheme.rappiOrange,
        elevation: 0,
        // UI: Resumen general en la top bar naranja con KPIs inline
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Mis Metricas',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'Viajes: ${_currentMetrics['totalTrips']} · S/. ${_currentMetrics['totalEarnings']} · ${_currentMetrics['avgRating']}★',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.download, color: Theme.of(context).colorScheme.onPrimary),
            onPressed: _exportReport,
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.onPrimary),
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
                  // Period selector
                  _buildPeriodSelector(),

                  // UI: 4 mini-gráficos circulares en grid 2x2
                  _buildMiniChartsGrid(),

                  // Summary cards
                  _buildSummaryCards(),

                  // Performance chart
                  _buildPerformanceChart(),

                  // Goals progress
                  _buildGoalsSection(),

                  // Hourly distribution
                  _buildHourlyDistribution(),

                  // Best zones
                  _buildBestZones(),

                  // Comparison with others
                  _buildComparison(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // UI: Grid 2x2 de 4 mini-indicadores circulares
  Widget _buildMiniChartsGrid() {
    final metrics = [
      {'label': 'Viajes', 'value': _currentMetrics['totalTrips'], 'max': 50, 'color': ModernTheme.primaryBlue, 'icon': Icons.route},
      {'label': 'Calificacion', 'value': _currentMetrics['avgRating'], 'max': 5.0, 'color': ModernTheme.accentYellow, 'icon': Icons.star},
      {'label': 'Aceptacion', 'value': _currentMetrics['acceptanceRate'], 'max': 100, 'color': Colors.purple, 'icon': Icons.check_circle},
      {'label': 'Horas online', 'value': _currentMetrics['onlineHours'], 'max': 12, 'color': ModernTheme.rappiOrange, 'icon': Icons.timer},
    ];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.1,
        children: metrics.map((m) {
          final value = (m['value'] as num).toDouble();
          final max = (m['max'] as num).toDouble();
          final progress = (value / max).clamp(0.0, 1.0);
          final color = m['color'] as Color;
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: ModernTheme.getCardShadow(context),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 6,
                        backgroundColor: color.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                    Icon(m['icon'] as IconData, color: color, size: 22),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '$value',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.primaryText),
                ),
                Text(
                  m['label'] as String,
                  style: TextStyle(fontSize: 11, color: context.secondaryText),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildPeriodSelector() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          Expanded(
            child: _buildPeriodButton('Día', 'day'),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _buildPeriodButton('Semana', 'week'),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _buildPeriodButton('Mes', 'month'),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _buildPeriodButton('Año', 'year'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPeriodButton(String label, String value) {
    final isSelected = _selectedPeriod == value;

    return InkWell(
      onTap: () => setState(() => _selectedPeriod = value),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? ModernTheme.rappiOrange : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? ModernTheme.rappiOrange : Theme.of(context).dividerColor,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Theme.of(context).colorScheme.onPrimary : context.secondaryText,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
        padding: EdgeInsets.all(16),
        children: [
          _buildMetricCard(
            'Viajes',
            '${_currentMetrics['totalTrips']}',
            Icons.route,
            ModernTheme.primaryBlue,
            '+${_comparisons['tripsGrowth']}%',
            true,
          ),
          _buildMetricCard(
            'Ganancias',
            'S/. ${_currentMetrics['totalEarnings']}',
            Icons.account_balance_wallet, // ✅ Cambiado de attach_money ($) a wallet
            ModernTheme.rappiOrange,
            '+${_comparisons['earningsGrowth']}%',
            true,
          ),
          _buildMetricCard(
            'Calificación',
            '${_currentMetrics['avgRating']}',
            Icons.star,
            ModernTheme.accentYellow,
            '+${_comparisons['ratingChange']}',
            true,
          ),
          _buildMetricCard(
            'Aceptación',
            '${_currentMetrics['acceptanceRate']}%',
            Icons.check_circle,
            Colors.purple,
            '+${_comparisons['acceptanceChange']}%',
            true,
          ),
          _buildMetricCard(
            'Horas',
            '${_currentMetrics['onlineHours']}h',
            Icons.timer,
            Colors.orange,
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
      margin: EdgeInsets.only(right: 12),
      padding: EdgeInsets.all(10), // ✅ Reducido de 12 a 10 para evitar overflow
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.getCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // ✅ Usar tamaño mínimo para evitar overflow
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 22), // ✅ Reducido de 24 a 22
              if (showChange && change.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 5, vertical: 1), // ✅ Reducido padding
                  decoration: BoxDecoration(
                    color: ModernTheme.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    change,
                    style: TextStyle(
                      color: ModernTheme.success,
                      fontSize: 9, // ✅ Reducido de 10 a 9
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 4), // ✅ Reducido de 6 a 4 para evitar overflow
          Text(
            value,
            style: TextStyle(
              fontSize: 17, // ✅ Reducido de 18 a 17
              fontWeight: FontWeight.bold,
              color: context.primaryText,
            ),
            maxLines: 1, // ✅ Forzar una línea
            overflow: TextOverflow.ellipsis, // ✅ Añadir ellipsis si es muy largo
          ),
          SizedBox(height: 1), // ✅ Reducido de 2 a 1 para evitar overflow
          Text(
            title,
            style: TextStyle(
              fontSize: 10, // ✅ Reducido de 11 a 10 para evitar overflow
              color: context.secondaryText,
            ),
            maxLines: 1, // ✅ Forzar una línea
            overflow: TextOverflow.ellipsis, // ✅ Añadir ellipsis
          ),
        ],
      ),
    );
  }
  
  Widget _buildPerformanceChart() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
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
                'Rendimiento Semanal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  _buildChartToggle(Icons.show_chart, 0),
                  SizedBox(width: 8),
                  _buildChartToggle(Icons.bar_chart, 1),
                ],
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
          
          SizedBox(height: 16),
          
          // Chart legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _weeklyData.map((data) {
              return Column(
                children: [
                  Text(
                    data['day'],
                    style: TextStyle(
                      fontSize: 11,
                      color: context.secondaryText,
                    ),
                  ),
                  Text(
                    '${data['trips']}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
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
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? ModernTheme.rappiOrange.withValues(alpha: 0.1) : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isSelected ? ModernTheme.rappiOrange : context.secondaryText,
          size: 20,
        ),
      ),
    );
  }
  
  Widget _buildGoalsSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.getCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Objetivos y Metas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          
          ..._goals.map((goal) => _buildGoalItem(goal)),
        ],
      ),
    );
  }
  
  Widget _buildGoalItem(Map<String, dynamic> goal) {
    final progress = (goal['current'] / goal['target']).clamp(0.0, 1.0);
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(goal['icon'], color: goal['color'], size: 20),
                  SizedBox(width: 8),
                  Text(
                    goal['title'],
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              Text(
                '${goal['current']} / ${goal['target']}',
                style: TextStyle(
                  fontSize: 12,
                  color: context.secondaryText,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          
          LinearProgressIndicator(
            value: progress,
            backgroundColor: goal['color'].withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(goal['color']),
            minHeight: 6,
          ),
          
          SizedBox(height: 4),
          Text(
            '${(progress * 100).round()}% completado',
            style: TextStyle(
              fontSize: 11,
              color: context.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHourlyDistribution() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.getCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Distribución por Horas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Identifica tus horas más productivas',
            style: TextStyle(
              fontSize: 12,
              color: context.secondaryText,
            ),
          ),
          SizedBox(height: 16),
          
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
          
          SizedBox(height: 16),
          
          // Peak hours info
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.trending_up, color: ModernTheme.rappiOrange),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Horas Pico',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: ModernTheme.rappiOrange,
                        ),
                      ),
                      Text(
                        (_currentMetrics['peakHours'] as List).join(', '),
                        style: TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis, // ✅ CORREGIDO: Evitar overflow si hay muchas horas
                        maxLines: 2, // ✅ NUEVO: Máximo 2 líneas
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
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.getCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Zonas Más Rentables',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          
          // ✅ MODIFICADO: Usar datos COMPLETOS de Firebase desde _zonesData
          ..._zonesData.asMap().entries.map((entry) {
            final index = entry.key;
            final zoneData = entry.value;
            final zone = zoneData['zone'] as String;
            final earnings = (zoneData['earnings'] as num).toDouble();
            final trips = (zoneData['trips'] as int);

            return Container(
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: ModernTheme.rappiOrange.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: ModernTheme.rappiOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    flex: 2, // ✅ NUEVO: Dar más espacio a la columna de zona
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          zone,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15, // ✅ Reducido de 16 a 15
                          ),
                          overflow: TextOverflow.ellipsis, // ✅ NUEVO: Evitar overflow en nombres largos
                          maxLines: 1,
                        ),
                        Text(
                          '$trips viajes',
                          style: TextStyle(
                            fontSize: 11, // ✅ Reducido de 12 a 11
                            color: context.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8), // ✅ NUEVO: Separación antes de earnings
                  Flexible( // ✅ CORREGIDO: Usar Flexible para evitar overflow
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'S/. ${earnings.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14, // ✅ Reducido de default a 14
                            color: ModernTheme.rappiOrange,
                          ),
                          overflow: TextOverflow.ellipsis, // ✅ NUEVO
                          maxLines: 1,
                        ),
                        Text(
                          trips > 0 ? 'S/. ${(earnings / trips).toStringAsFixed(2)}/viaje' : 'Sin viajes',
                          style: TextStyle(
                            fontSize: 10, // ✅ Reducido de 11 a 10
                            color: context.secondaryText,
                          ),
                          overflow: TextOverflow.ellipsis, // ✅ NUEVO
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
    // ✅ MODIFICADO: Mostrar placeholder profesional mientras no haya comparación real
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [ModernTheme.rappiOrange.withValues(alpha: 0.8), ModernTheme.rappiOrange.withValues(alpha: 0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.getCardShadow(context),
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
          SizedBox(height: 16),
          Text(
            'Comparación con Otros Conductores',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),
          Text(
            'Requiere datos de al menos 10 conductores activos en el sistema',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.trending_up, color: Theme.of(context).colorScheme.onPrimary, size: 18),
                SizedBox(width: 8),
                Text(
                  'Sigue trabajando para mejorar tu ranking',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildComparisonItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.onPrimary, size: 28),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.70),
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  void _exportReport() async {
    try {
      // ✅ FIX: Implementar exportación real de datos
      // Mostrar diálogo para elegir formato
      final format = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Exportar Reporte'),
          content: Text('¿En qué formato deseas exportar el reporte?'),
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

      // Generar contenido del reporte
      final reportData = _generateReportData();

      if (format == 'csv') {
        await _exportToCSV(reportData);
      } else if (format == 'pdf') {
        await _exportToPDF(reportData);
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

  String _generateReportData() {
    // ✅ Generar datos del reporte en formato texto
    final buffer = StringBuffer();
    buffer.writeln('REPORTE DE MÉTRICAS - RAPPI TEAM');
    buffer.writeln('Fecha: ${DateTime.now().toString().split('.')[0]}');
    buffer.writeln('Período: $_selectedPeriod');
    buffer.writeln('');
    buffer.writeln('RESUMEN:');
    buffer.writeln('- Total Viajes: ${_currentMetrics['totalTrips']}');
    buffer.writeln('- Ganancias: S/. ${_currentMetrics['totalEarnings']}');
    buffer.writeln('- Calificación Promedio: ${_currentMetrics['avgRating']}');
    buffer.writeln('- Tasa de Aceptación: ${_currentMetrics['acceptanceRate']}%');
    buffer.writeln('- Horas en Línea: ${_currentMetrics['onlineHours']}h');
    buffer.writeln('');
    buffer.writeln('RENDIMIENTO SEMANAL:');
    for (var day in _weeklyData) {
      buffer.writeln('${day['day']}: ${day['trips']} viajes, S/. ${day['earnings']}');
    }
    return buffer.toString();
  }

  Future<void> _exportToCSV(String data) async {
    try {
      // ✅ IMPLEMENTACIÓN REAL: Generar archivo CSV
      final List<List<dynamic>> csvData = [
        ['REPORTE DE MÉTRICAS - RAPPI TEAM'],
        ['Fecha', DateTime.now().toString().split('.')[0]],
        ['Período', _selectedPeriod],
        [],
        ['RESUMEN'],
        ['Métrica', 'Valor'],
        ['Total Viajes', _currentMetrics['totalTrips']],
        ['Ganancias', 'S/. ${_currentMetrics['totalEarnings']}'],
        ['Calificación Promedio', _currentMetrics['avgRating']],
        ['Tasa de Aceptación', '${_currentMetrics['acceptanceRate']}%'],
        ['Horas en Línea', '${_currentMetrics['onlineHours']}h'],
        [],
        ['RENDIMIENTO SEMANAL'],
        ['Día', 'Viajes', 'Ganancias'],
        ..._weeklyData.map((day) => [
          day['day'],
          day['trips'],
          'S/. ${day['earnings']}'
        ]),
      ];

      // Convertir a CSV
      String csvString = const ListToCsvConverter().convert(csvData);

      // Obtener directorio temporal
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/metricas_rappi_$timestamp.csv';

      // Escribir archivo
      final file = File(filePath);
      await file.writeAsString(csvString);

      // Compartir archivo usando share_plus
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Reporte de Métricas - Rappi Team',
        text: 'Reporte de métricas generado el ${DateTime.now().toString().split('.')[0]}',
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

      // ✅ IMPLEMENTACIÓN REAL: Generar archivo PDF
      final pdf = pw.Document();

      // Agregar página al PDF
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
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
                        'REPORTE DE MÉTRICAS', // ✅ Ahora con acento (Unicode)
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
                  'Fecha: ${DateTime.now().toString().split('.')[0]}',
                  style: pw.TextStyle(font: ttfRegular, fontSize: 12),
                ),
                pw.Text(
                  'Período: $_selectedPeriod',
                  style: pw.TextStyle(font: ttfRegular, fontSize: 12),
                ),
                pw.SizedBox(height: 20),

                // Resumen de métricas
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
                    _buildPdfTableRow('Total Viajes', '${_currentMetrics['totalTrips']}', true, ttfRegular, ttfBold),
                    _buildPdfTableRow('Ganancias', 'S/. ${_currentMetrics['totalEarnings']}', false, ttfRegular, ttfBold),
                    _buildPdfTableRow('Calificación Promedio', '${_currentMetrics['avgRating']}', true, ttfRegular, ttfBold),
                    _buildPdfTableRow('Tasa de Aceptación', '${_currentMetrics['acceptanceRate']}%', false, ttfRegular, ttfBold),
                    _buildPdfTableRow('Horas en Línea', '${_currentMetrics['onlineHours']}h', true, ttfRegular, ttfBold),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Rendimiento semanal
                pw.Text(
                  'RENDIMIENTO SEMANAL',
                  style: pw.TextStyle(
                    font: ttfBold, // ✅ Usar fuente bold
                    fontSize: 16,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColor.fromHex('#28A745')),
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

      // Guardar PDF en archivo temporal
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/metricas_rappi_$timestamp.pdf';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      // Compartir archivo usando share_plus
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Reporte de Métricas - Rappi Team',
        text: 'Reporte de métricas generado el ${DateTime.now().toString().split('.')[0]}',
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

  // ✅ NUEVO: Funciones helper para generar tabla PDF
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
        style: pw.TextStyle(
          font: font, // ✅ Usar fuente custom
          color: PdfColors.white,
        ),
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

    // ✅ RECARGAR métricas desde Firebase
    _loadRealMetricsFromFirebase();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Datos actualizados'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
}

// Line chart painter
class LineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double progress;
  
  const LineChartPainter({super.repaint, required this.data, required this.progress});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ModernTheme.rappiOrange
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = ModernTheme.rappiOrange.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final dotPaint = Paint()
      ..color = ModernTheme.rappiOrange
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    // ✅ Protección contra división por cero
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
      
      // Draw dots
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

// Bar chart painter
class BarChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double progress;
  
  const BarChartPainter({super.repaint, required this.data, required this.progress});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ModernTheme.rappiOrange
      ..style = PaintingStyle.fill;

    // ✅ Protección contra división por cero
    double maxValue = math.max(1.0, data.map((d) => (d['earnings'] as num).toDouble()).reduce(math.max));
    final barWidth = size.width / (data.length * 2);
    
    for (int i = 0; i < data.length; i++) {
      final x = (size.width / data.length) * i + barWidth / 2;
      final barHeight = (size.height * (data[i]['earnings'] / maxValue) * progress);
      final y = size.height - barHeight;
      
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        Radius.circular(4),
      );
      
      canvas.drawRRect(rect, paint);
    }
  }
  
  @override
  bool shouldRepaint(BarChartPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// Hourly distribution chart painter
class HourlyChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final List<String> peakHours;
  
  const HourlyChartPainter({super.repaint, required this.data, required this.peakHours});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    // ✅ Protección contra división por cero
    double maxTrips = math.max(1.0, data.map((d) => d['trips'] as int).reduce(math.max).toDouble());
    final barWidth = size.width / data.length;
    
    for (int i = 0; i < data.length; i++) {
      final hour = data[i]['hour'] as String;
      final trips = data[i]['trips'] as int;
      final barHeight = (size.height * (trips / maxTrips));
      
      // Check if it's a peak hour
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
          ? ModernTheme.rappiOrange 
          : ModernTheme.rappiOrange.withValues(alpha: 0.3);
      
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