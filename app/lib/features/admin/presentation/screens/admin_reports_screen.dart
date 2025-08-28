import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/theme/app_theme.dart';
import '../widgets/chart_period_selector.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'week';
  bool _isLoading = false;

  final List<ReportTab> _tabs = [
    ReportTab('Ingresos', Icons.monetization_on),
    ReportTab('Viajes', Icons.directions_car),
    ReportTab('Usuarios', Icons.people),
    ReportTab('Métricas', Icons.analytics),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes y Analíticas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'export') {
                _exportReports();
              } else if (value == 'settings') {
                _showReportSettings();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('Exportar reportes'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 8),
                    Text('Configuración'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabs
              .map((tab) => Tab(
                    icon: Icon(tab.icon),
                    text: tab.title,
                  ))
              .toList(),
        ),
      ),
      body: Column(
        children: [
          // Selector de período
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ChartPeriodSelector(
              selectedPeriod: _selectedPeriod,
              onPeriodChanged: (period) {
                setState(() {
                  _selectedPeriod = period;
                  _isLoading = true;
                });
                _loadDataForPeriod(period);
              },
            ),
          ),

          // Contenido de las pestañas
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRevenueTab(),
                      _buildTripsTab(),
                      _buildUsersTab(),
                      _buildMetricsTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Tarjetas de resumen de ingresos
          Row(
            children: [
              Expanded(
                child: _buildRevenueCard(
                  'Ingresos Totales',
                  'S/ 45,230',
                  '+12.5%',
                  AppTheme.earningsColor,
                  Icons.trending_up,
                ).animate().fadeIn().slideX(begin: -0.2, end: 0),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRevenueCard(
                  'Ingresos Promedio',
                  'S/ 1,507',
                  '+8.3%',
                  AppTheme.primaryColor,
                  Icons.show_chart,
                ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.2, end: 0),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildRevenueCard(
                  'Comisiones',
                  'S/ 9,046',
                  '+15.2%',
                  AppTheme.accentColor,
                  Icons.account_balance,
                ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.2, end: 0),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRevenueCard(
                  'Meta del Mes',
                  '78%',
                  'S/ 35,000',
                  AppTheme.successColor,
                  Icons.flag,
                ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.2, end: 0),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Gráfico de ingresos por tiempo
          Container(
            height: 300,
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
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ingresos por Día',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: LineChart(_buildRevenueChartData()),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 400.ms),

          const SizedBox(height: 24),

          // Breakdown por categorías
          Container(
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
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ingresos por Categoría',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildRevenueBreakdownItem(
                    'Viajes Estándar',
                    'S/ 28,450',
                    62.9,
                    AppTheme.primaryColor,
                  ),
                  _buildRevenueBreakdownItem(
                    'Viajes Premium',
                    'S/ 12,380',
                    27.4,
                    AppTheme.accentColor,
                  ),
                  _buildRevenueBreakdownItem(
                    'Viajes Compartidos',
                    'S/ 3,210',
                    7.1,
                    AppTheme.successColor,
                  ),
                  _buildRevenueBreakdownItem(
                    'Cancelaciones',
                    'S/ 1,190',
                    2.6,
                    AppTheme.warningColor,
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 500.ms),
        ],
      ),
    );
  }

  Widget _buildTripsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Estadísticas de viajes
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildTripMetricCard(
                'Total Viajes',
                '2,847',
                '+18.5%',
                Icons.directions_car,
                AppTheme.primaryColor,
              ).animate().fadeIn().scale(),
              _buildTripMetricCard(
                'Viajes Completados',
                '2,743',
                '96.3%',
                Icons.check_circle,
                AppTheme.successColor,
              ).animate().fadeIn(delay: 100.ms).scale(),
              _buildTripMetricCard(
                'Viajes Cancelados',
                '104',
                '3.7%',
                Icons.cancel,
                AppTheme.errorColor,
              ).animate().fadeIn(delay: 200.ms).scale(),
              _buildTripMetricCard(
                'Tiempo Promedio',
                '18.5 min',
                '-2.3 min',
                Icons.access_time,
                AppTheme.infoColor,
              ).animate().fadeIn(delay: 300.ms).scale(),
            ],
          ),

          const SizedBox(height: 24),

          // Gráfico de viajes por hora
          Container(
            height: 280,
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
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Viajes por Hora del Día',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: BarChart(_buildTripsBarChartData()),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 400.ms),

          const SizedBox(height: 24),

          // Top rutas
          Container(
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
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rutas Más Populares',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildRouteItem('Aeropuerto → Centro', 'S/ 45', '234 viajes'),
                  _buildRouteItem('Miraflores → San Isidro', 'S/ 18', '189 viajes'),
                  _buildRouteItem('Centro → Callao', 'S/ 25', '156 viajes'),
                  _buildRouteItem('San Borja → La Molina', 'S/ 22', '143 viajes'),
                  _buildRouteItem('Barranco → Surco', 'S/ 28', '127 viajes'),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 500.ms),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Métricas de usuarios
          Row(
            children: [
              Expanded(
                child: _buildUserMetricCard(
                  'Usuarios Activos',
                  '3,492',
                  '+145 esta semana',
                  Icons.people,
                  AppTheme.primaryColor,
                ).animate().fadeIn().slideY(begin: 0.2, end: 0),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildUserMetricCard(
                  'Nuevos Registros',
                  '87',
                  '+23% vs sem. pasada',
                  Icons.person_add,
                  AppTheme.successColor,
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2, end: 0),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildUserMetricCard(
                  'Conductores Online',
                  '156',
                  '89% disponibles',
                  Icons.directions_car,
                  AppTheme.accentColor,
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildUserMetricCard(
                  'Tasa Retención',
                  '78.3%',
                  '+4.2% vs mes pasado',
                  Icons.trending_up,
                  AppTheme.earningsColor,
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Gráfico de crecimiento de usuarios
          Container(
            height: 300,
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
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Crecimiento de Usuarios',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: LineChart(_buildUsersGrowthChartData()),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 400.ms),

          const SizedBox(height: 24),

          // Demographics
          Container(
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
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Demografía de Usuarios',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 200,
                          child: PieChart(_buildDemographicsPieChartData()),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          children: [
                            _buildDemographicItem('18-25 años', '28%', AppTheme.primaryColor),
                            _buildDemographicItem('26-35 años', '35%', AppTheme.accentColor),
                            _buildDemographicItem('36-45 años', '22%', AppTheme.successColor),
                            _buildDemographicItem('46+ años', '15%', AppTheme.warningColor),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 500.ms),
        ],
      ),
    );
  }

  Widget _buildMetricsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // KPIs principales
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'KPIs Principales',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildKPIItem('Rating Promedio', '4.8', '⭐'),
                      ),
                      Expanded(
                        child: _buildKPIItem('Tiempo Respuesta', '3.2 min', '⚡'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildKPIItem('Tasa Conversión', '89.2%', '📈'),
                      ),
                      Expanded(
                        child: _buildKPIItem('Satisfacción', '94.1%', '😊'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ).animate().fadeIn().slideY(begin: -0.1, end: 0),

          const SizedBox(height: 24),

          // Métricas operacionales
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _buildOperationalMetric(
                'Demanda vs Oferta',
                '1.2:1',
                'Equilibrado',
                Icons.balance,
                AppTheme.successColor,
              ).animate().fadeIn(delay: 100.ms).scale(),
              _buildOperationalMetric(
                'Utilización Flota',
                '76%',
                '+5% vs mes pasado',
                Icons.local_taxi,
                AppTheme.primaryColor,
              ).animate().fadeIn(delay: 200.ms).scale(),
              _buildOperationalMetric(
                'Tiempo Inactivo',
                '18.5%',
                '-2.3% mejoría',
                Icons.timer_off,
                AppTheme.warningColor,
              ).animate().fadeIn(delay: 300.ms).scale(),
              _buildOperationalMetric(
                'Picos de Demanda',
                '7-9am, 6-8pm',
                'Patrones normales',
                Icons.show_chart,
                AppTheme.infoColor,
              ).animate().fadeIn(delay: 400.ms).scale(),
            ],
          ),

          const SizedBox(height: 24),

          // Mapa de calor de actividad
          Container(
            height: 250,
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
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Actividad por Horas/Días',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _buildHeatmapPlaceholder(),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 500.ms),
        ],
      ),
    );
  }

  // Helper widgets
  Widget _buildRevenueCard(
    String title,
    String amount,
    String change,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                title,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            change,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueBreakdownItem(
    String category,
    String amount,
    double percentage,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                category,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                amount,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ],
      ),
    );
  }

  Widget _buildTripMetricCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRouteItem(String route, String avgPrice, String trips) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  route,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  trips,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            avgPrice,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.earningsColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserMetricCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemographicItem(String label, String percentage, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(
            percentage,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIItem(String title, String value, String emoji) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildOperationalMetric(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Text(
          'Mapa de calor de actividad\n(Implementar con librerías especializadas)',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // Chart data builders
  LineChartData _buildRevenueChartData() {
    return LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: [
            const FlSpot(0, 3000),
            const FlSpot(1, 3500),
            const FlSpot(2, 3200),
            const FlSpot(3, 4100),
            const FlSpot(4, 3800),
            const FlSpot(5, 4500),
            const FlSpot(6, 4200),
          ],
          isCurved: true,
          color: AppTheme.earningsColor,
          barWidth: 3,
          belowBarData: BarAreaData(
            show: true,
            color: AppTheme.earningsColor.withOpacity(0.2),
          ),
          dotData: const FlDotData(show: false),
        ),
      ],
    );
  }

  BarChartData _buildTripsBarChartData() {
    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      barGroups: List.generate(24, (index) {
        double value = 10 + (index * 5) + (index > 6 && index < 10 ? 50 : 0) + (index > 17 && index < 21 ? 60 : 0);
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: value,
              color: AppTheme.primaryColor,
              width: 12,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        );
      }),
      titlesData: const FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      gridData: const FlGridData(show: false),
    );
  }

  LineChartData _buildUsersGrowthChartData() {
    return LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: [
            const FlSpot(0, 100),
            const FlSpot(1, 120),
            const FlSpot(2, 140),
            const FlSpot(3, 180),
            const FlSpot(4, 220),
            const FlSpot(5, 280),
            const FlSpot(6, 340),
          ],
          isCurved: true,
          color: AppTheme.successColor,
          barWidth: 3,
          belowBarData: BarAreaData(
            show: true,
            color: AppTheme.successColor.withOpacity(0.2),
          ),
          dotData: const FlDotData(show: false),
        ),
      ],
    );
  }

  PieChartData _buildDemographicsPieChartData() {
    return PieChartData(
      sections: [
        PieChartSectionData(
          value: 28,
          color: AppTheme.primaryColor,
          radius: 60,
          showTitle: false,
        ),
        PieChartSectionData(
          value: 35,
          color: AppTheme.accentColor,
          radius: 60,
          showTitle: false,
        ),
        PieChartSectionData(
          value: 22,
          color: AppTheme.successColor,
          radius: 60,
          showTitle: false,
        ),
        PieChartSectionData(
          value: 15,
          color: AppTheme.warningColor,
          radius: 60,
          showTitle: false,
        ),
      ],
      sectionsSpace: 2,
      centerSpaceRadius: 40,
    );
  }

  void _refreshData() {
    setState(() {
      _isLoading = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isLoading = false;
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Datos actualizados'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  void _loadDataForPeriod(String period) {
    Future.delayed(const Duration(milliseconds: 800), () {
      setState(() {
        _isLoading = false;
      });
    });
  }

  void _exportReports() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Exportando reportes...'),
        backgroundColor: AppTheme.infoColor,
      ),
    );
  }

  void _showReportSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configuración de Reportes'),
        content: const Text('Configurar filtros y preferencias de reportes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

class ReportTab {
  final String title;
  final IconData icon;

  ReportTab(this.title, this.icon);
}