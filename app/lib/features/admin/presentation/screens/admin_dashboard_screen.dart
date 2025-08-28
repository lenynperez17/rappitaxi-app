import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/theme/app_theme.dart';
import '../widgets/admin_stats_card.dart';
import '../widgets/admin_chart_widget.dart';
import '../widgets/recent_activity_widget.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Actualizar datos
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Actualizar datos del dashboard
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Saludo y fecha
              _buildHeader(context),
              
              const SizedBox(height: 24),
              
              // Tarjetas de estadísticas principales
              _buildStatsGrid(),
              
              const SizedBox(height: 24),
              
              // Gráfico de ingresos
              _buildRevenueChart(context),
              
              const SizedBox(height: 24),
              
              // Métricas de viajes
              _buildTripsMetrics(context),
              
              const SizedBox(height: 24),
              
              // Actividad reciente
              _buildRecentActivity(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final now = DateTime.now();
    final greeting = _getGreeting(now.hour);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ).animate().fadeIn().slideX(begin: -0.2, end: 0),
        
        const SizedBox(height: 4),
        
        Text(
          'Aquí tienes un resumen de la actividad de hoy',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
        ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.2, end: 0),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.2,
      children: [
        AdminStatsCard(
          title: 'Viajes Hoy',
          value: '127',
          subtitle: '+15% vs ayer',
          icon: Icons.directions_car,
          color: AppTheme.primaryColor,
          trend: TrendType.up,
        ).animate().fadeIn(delay: 200.ms).scale(),
        
        AdminStatsCard(
          title: 'Ingresos Hoy',
          value: 'S/ 3,450',
          subtitle: '+8% vs ayer',
          icon: Icons.monetization_on,
          color: AppTheme.earningsColor,
          trend: TrendType.up,
        ).animate().fadeIn(delay: 250.ms).scale(),
        
        AdminStatsCard(
          title: 'Conductores',
          value: '45',
          subtitle: '12 activos',
          icon: Icons.group,
          color: AppTheme.infoColor,
          trend: TrendType.stable,
        ).animate().fadeIn(delay: 300.ms).scale(),
        
        AdminStatsCard(
          title: 'Usuarios',
          value: '1,234',
          subtitle: '+5 nuevos',
          icon: Icons.people,
          color: AppTheme.secondaryColor,
          trend: TrendType.up,
        ).animate().fadeIn(delay: 350.ms).scale(),
      ],
    );
  }

  Widget _buildRevenueChart(BuildContext context) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ingresos de la semana',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.earningsColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '+12.5%',
                  style: TextStyle(
                    color: AppTheme.earningsColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const AdminChartWidget(),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildTripsMetrics(BuildContext context) {
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
          Text(
            'Métricas de viajes',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  'Tiempo promedio',
                  '18 min',
                  Icons.timer,
                  AppTheme.infoColor,
                ),
              ),
              Expanded(
                child: _buildMetricItem(
                  'Distancia promedio',
                  '8.5 km',
                  Icons.route,
                  AppTheme.warningColor,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  'Calificación promedio',
                  '4.8',
                  Icons.star,
                  Colors.amber,
                ),
              ),
              Expanded(
                child: _buildMetricItem(
                  'Tasa de cancelación',
                  '2.1%',
                  Icons.cancel,
                  AppTheme.errorColor,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildMetricItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRecentActivity(BuildContext context) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Actividad reciente',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('Ver todo'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const RecentActivityWidget(),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0);
  }

  String _getGreeting(int hour) {
    if (hour < 12) {
      return '¡Buenos días!';
    } else if (hour < 18) {
      return '¡Buenas tardes!';
    } else {
      return '¡Buenas noches!';
    }
  }
}