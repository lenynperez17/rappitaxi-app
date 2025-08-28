import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

enum TrendType { up, down, stable }

class AdminStatsCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final TrendType trend;

  const AdminStatsCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          // Header con icono
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              _buildTrendIcon(),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Valor principal
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
          ),
          
          const SizedBox(height: 4),
          
          // Título
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
          ),
          
          const SizedBox(height: 8),
          
          // Subtítulo con tendencia
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _getTrendColor(),
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendIcon() {
    IconData iconData;
    Color iconColor;

    switch (trend) {
      case TrendType.up:
        iconData = Icons.trending_up;
        iconColor = AppTheme.successColor;
        break;
      case TrendType.down:
        iconData = Icons.trending_down;
        iconColor = AppTheme.errorColor;
        break;
      case TrendType.stable:
        iconData = Icons.trending_flat;
        iconColor = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 16,
      ),
    );
  }

  Color _getTrendColor() {
    switch (trend) {
      case TrendType.up:
        return AppTheme.successColor;
      case TrendType.down:
        return AppTheme.errorColor;
      case TrendType.stable:
        return Colors.grey;
    }
  }
}