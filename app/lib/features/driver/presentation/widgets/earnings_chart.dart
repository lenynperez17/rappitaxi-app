import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';

class EarningsChart extends StatelessWidget {
  final double earnings;
  final String period;
  final DateTime startDate;
  final DateTime endDate;

  const EarningsChart({
    super.key,
    required this.earnings,
    required this.period,
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tendencia de ganancias',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _buildChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    // Datos simulados para el gráfico
    // En una implementación real, estos datos vendrían del repositorio
    final spots = _generateChartData();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: earnings / 4,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey[300]!,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (double value, TitleMeta meta) {
                return Text(
                  _getBottomTitle(value.toInt()),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: earnings / 4,
              reservedSize: 50,
              getTitlesWidget: (double value, TitleMeta meta) {
                return Text(
                  'S/${value.toInt()}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: false,
        ),
        minX: 0,
        maxX: spots.length.toDouble() - 1,
        minY: 0,
        maxY: earnings * 1.2,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: LinearGradient(
              colors: [
                AppTheme.earningsColor.withOpacity(0.8),
                AppTheme.earningsColor,
              ],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: AppTheme.earningsColor,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppTheme.earningsColor.withOpacity(0.3),
                  AppTheme.earningsColor.withOpacity(0.1),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _generateChartData() {
    // Generar datos simulados basados en el período
    final daysDifference = endDate.difference(startDate).inDays + 1;
    final spots = <FlSpot>[];

    for (int i = 0; i < daysDifference && i < 7; i++) {
      // Simular ganancias variables
      final earningsValue = earnings * (0.3 + (i / daysDifference) * 0.7) +
          (earnings * 0.2 * (i % 3 == 0 ? 1 : 0.5));
      spots.add(FlSpot(i.toDouble(), earningsValue));
    }

    return spots;
  }

  String _getBottomTitle(int value) {
    final date = startDate.add(Duration(days: value));
    
    if (period.contains('Hoy')) {
      // Para hoy, mostrar horas
      return DateFormat('HH:mm').format(DateTime.now().subtract(Duration(hours: 6 - value)));
    } else if (period.contains('Semana') || period.contains('semana')) {
      // Para semana, mostrar días de la semana
      final weekDays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
      return weekDays[date.weekday - 1];
    } else {
      // Para mes, mostrar días del mes
      return date.day.toString();
    }
  }
}