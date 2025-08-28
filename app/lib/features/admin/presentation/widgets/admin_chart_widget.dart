import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/theme/app_theme.dart';

class AdminChartWidget extends StatelessWidget {
  const AdminChartWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1000,
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
                  const style = TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  );
                  Widget text;
                  switch (value.toInt()) {
                    case 0:
                      text = const Text('Lun', style: style);
                      break;
                    case 1:
                      text = const Text('Mar', style: style);
                      break;
                    case 2:
                      text = const Text('Mié', style: style);
                      break;
                    case 3:
                      text = const Text('Jue', style: style);
                      break;
                    case 4:
                      text = const Text('Vie', style: style);
                      break;
                    case 5:
                      text = const Text('Sáb', style: style);
                      break;
                    case 6:
                      text = const Text('Dom', style: style);
                      break;
                    default:
                      text = const Text('', style: style);
                      break;
                  }
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: text,
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1000,
                reservedSize: 50,
                getTitlesWidget: (double value, TitleMeta meta) {
                  return Text(
                    'S/${(value / 1000).toInt()}K',
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
          maxX: 6,
          minY: 0,
          maxY: 5000,
          lineBarsData: [
            LineChartBarData(
              spots: _getChartData(),
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
      ),
    );
  }

  List<FlSpot> _getChartData() {
    // Datos simulados para la semana
    return [
      const FlSpot(0, 2800), // Lunes
      const FlSpot(1, 3200), // Martes
      const FlSpot(2, 2900), // Miércoles
      const FlSpot(3, 3800), // Jueves
      const FlSpot(4, 4200), // Viernes
      const FlSpot(5, 4800), // Sábado
      const FlSpot(6, 3600), // Domingo
    ];
  }
}