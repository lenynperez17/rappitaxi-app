import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../domain/entities/price_negotiation.dart';
import '../../../../core/constants/app_colors.dart';

class PriceComparisonChart extends StatelessWidget {
  final List<DriverOffer> offers;
  final double suggestedPrice;

  const PriceComparisonChart({
    super.key,
    required this.offers,
    required this.suggestedPrice,
  });

  @override
  Widget build(BuildContext context) {
    if (offers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              'Sin ofertas para mostrar',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Comparación de Ofertas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.rappiOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Base: \$${suggestedPrice.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.rappiOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            SizedBox(
              height: 120,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _getMaxPrice() * 1.1,
                  minY: _getMinPrice() * 0.9,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => Colors.blueGrey,
                      tooltipRoundedRadius: 8,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final offer = offers[group.x.toInt()];
                        final difference = offer.offeredPrice - suggestedPrice;
                        final percentage = (difference / suggestedPrice * 100);
                        
                        return BarTooltipItem(
                          '${offer.driverName}\n',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(
                              text: '\$${offer.offeredPrice.toStringAsFixed(0)}\n',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text: percentage >= 0 
                                  ? '+${percentage.toStringAsFixed(1)}%'
                                  : '${percentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: percentage >= 0 ? Colors.red[300] : Colors.green[300],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
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
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= offers.length) {
                            return const Text('');
                          }
                          
                          final offer = offers[index];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  offer.driverName.length > 6
                                      ? '${offer.driverName.substring(0, 6)}...'
                                      : offer.driverName,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 10,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star,
                                      size: 8,
                                      color: Colors.amber[600],
                                    ),
                                    Text(
                                      offer.driverRating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 8,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                        reservedSize: 32,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: _getPriceInterval(),
                        getTitlesWidget: (double value, TitleMeta meta) {
                          return Text(
                            '\$${value.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  barGroups: _buildBarGroups(),
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: _getPriceInterval(),
                    getDrawingHorizontalLine: (value) {
                      if (value == suggestedPrice) {
                        return FlLine(
                          color: AppColors.rappiOrange,
                          strokeWidth: 2,
                          dashArray: [5, 5],
                        );
                      }
                      return FlLine(
                        color: Colors.grey[300]!,
                        strokeWidth: 0.5,
                      );
                    },
                    drawVerticalLine: false,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Leyenda
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildLegendItem(
                  color: AppColors.success,
                  label: 'Mejor oferta',
                ),
                _buildLegendItem(
                  color: AppColors.rappiOrange,
                  label: 'Precio sugerido',
                  isDashed: true,
                ),
                _buildLegendItem(
                  color: AppColors.error,
                  label: 'Más caro',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups() {
    final sortedOffers = List<DriverOffer>.from(offers)
      ..sort((a, b) => a.offeredPrice.compareTo(b.offeredPrice));

    return sortedOffers.asMap().entries.map((entry) {
      final index = entry.key;
      final offer = entry.value;
      
      Color barColor;
      if (index == 0) {
        // Mejor oferta (más barata)
        barColor = AppColors.success;
      } else if (offer.offeredPrice > suggestedPrice) {
        // Más caro que el precio sugerido
        barColor = AppColors.error;
      } else {
        // Precio aceptable
        barColor = AppColors.rappiOrange.withOpacity(0.7);
      }

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: offer.offeredPrice,
            color: barColor,
            width: 20,
            borderRadius: BorderRadius.circular(4),
            borderSide: index == 0
                ? const BorderSide(color: AppColors.success, width: 2)
                : BorderSide.none,
          ),
        ],
        showingTooltipIndicators: [0],
      );
    }).toList();
  }

  double _getMaxPrice() {
    final prices = [...offers.map((o) => o.offeredPrice), suggestedPrice];
    return prices.reduce((a, b) => a > b ? a : b);
  }

  double _getMinPrice() {
    final prices = [...offers.map((o) => o.offeredPrice), suggestedPrice];
    return prices.reduce((a, b) => a < b ? a : b);
  }

  double _getPriceInterval() {
    final range = _getMaxPrice() - _getMinPrice();
    return (range / 4).ceilToDouble();
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    bool isDashed = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isDashed ? Colors.transparent : color,
            border: isDashed ? Border.all(color: color, width: 2) : null,
            borderRadius: BorderRadius.circular(2),
          ),
          child: isDashed
              ? CustomPaint(
                  painter: DashedLinePainter(color: color),
                )
              : null,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

class DashedLinePainter extends CustomPainter {
  final Color color;

  DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;

    const dashWidth = 2.0;
    const dashSpace = 2.0;

    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}