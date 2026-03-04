import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/modern_theme.dart';
import '../../widgets/common/rappi_app_bar.dart';
import '../../services/firebase_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  late FirebaseService _firebaseService;
  bool _isLoading = true;

  Map<String, dynamic> _stats = {
    'totalUsers': 0,
    'totalDrivers': 0,
    'tripsToday': 0,
    'todayEarnings': 0.0,
    'activeUsers': 0,
    'onlineDrivers': 0,
    'availableDrivers': 0,
    'driversInTrip': 0,
  };

  @override
  void initState() {
    super.initState();
    _firebaseService = FirebaseService();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final monthStart = DateTime(now.year, now.month, 1);

      debugPrint('📊 Cargando datos del dashboard admin...');
      debugPrint('📅 Fecha actual: $now');
      debugPrint('🌅 Inicio del día: $todayStart');
      debugPrint('📆 Inicio del mes: $monthStart');

      // ✅ OPTIMIZADO: Consultas Firebase en PARALELO con límites para mejor performance
      QuerySnapshot<Map<String, dynamic>>? usersSnapshot;
      QuerySnapshot<Map<String, dynamic>>? driversSnapshot;
      QuerySnapshot<Map<String, dynamic>>? tripsSnapshot;
      QuerySnapshot<Map<String, dynamic>>? newUsersMonthSnapshot;
      QuerySnapshot<Map<String, dynamic>>? suspendedUsersSnapshot;
      QuerySnapshot<Map<String, dynamic>>? withdrawalsSnapshot;
      QuerySnapshot<Map<String, dynamic>>? disputesSnapshot;

      // Helper para ejecutar query con manejo de errores
      Future<QuerySnapshot<Map<String, dynamic>>?> safeQuery(
        Future<QuerySnapshot<Map<String, dynamic>>> query,
        String name,
      ) async {
        try {
          return await query;
        } catch (e) {
          debugPrint('❌ Error cargando $name: $e');
          return null;
        }
      }

      // Ejecutar TODAS las consultas en paralelo con Future.wait
      final results = await Future.wait([
        // 0: Usuarios totales (con límite para evitar cargar miles de documentos)
        safeQuery(
          _firebaseService.firestore.collection('users').limit(1000).get(),
          'usuarios',
        ),
        // 1: Conductores (driver o dual)
        safeQuery(
          _firebaseService.firestore.collection('users')
              .where('userType', whereIn: ['driver', 'dual'])
              .limit(500)
              .get(),
          'conductores',
        ),
        // 2: Viajes de hoy
        safeQuery(
          _firebaseService.firestore.collection('rides')
              .where('requestedAt', isGreaterThanOrEqualTo: todayStart)
              .limit(500)
              .get(),
          'viajes',
        ),
        // 3: Usuarios nuevos del mes
        safeQuery(
          _firebaseService.firestore.collection('users')
              .where('createdAt', isGreaterThanOrEqualTo: monthStart)
              .limit(500)
              .get(),
          'usuarios nuevos',
        ),
        // 4: Usuarios suspendidos
        safeQuery(
          _firebaseService.firestore.collection('users')
              .where('isActive', isEqualTo: false)
              .limit(200)
              .get(),
          'usuarios suspendidos',
        ),
        // 5: Retiros de hoy
        safeQuery(
          _firebaseService.firestore.collection('withdrawals')
              .where('requestedAt', isGreaterThanOrEqualTo: todayStart)
              .limit(100)
              .get(),
          'retiros',
        ),
        // 6: Disputas abiertas
        safeQuery(
          _firebaseService.firestore.collection('disputes')
              .where('status', isEqualTo: 'open')
              .limit(100)
              .get(),
          'disputas',
        ),
      ]);

      // Asignar resultados (pueden ser null si fallaron)
      usersSnapshot = results[0];
      driversSnapshot = results[1];
      tripsSnapshot = results[2];
      newUsersMonthSnapshot = results[3];
      suspendedUsersSnapshot = results[4];
      withdrawalsSnapshot = results[5];
      disputesSnapshot = results[6];

      debugPrint('✅ Resultados obtenidos:');
      debugPrint('   👥 Usuarios: ${usersSnapshot?.docs.length ?? 0}');
      debugPrint('   🚗 Conductores: ${driversSnapshot?.docs.length ?? 0}');
      debugPrint('   🚕 Viajes hoy: ${tripsSnapshot?.docs.length ?? 0}');

      double todayEarnings = 0.0;
      double totalPlatformCommission = 0.0;
      int activeUsers = 0;
      int onlineDrivers = 0;
      int availableDrivers = 0;
      int driversInTrip = 0;
      int completedTripsToday = 0;
      int pendingPayments = 0;
      double totalRating = 0.0;
      int ratedTrips = 0;

      // Calcular usuarios activos
      if (usersSnapshot != null) {
        for (var user in usersSnapshot.docs) {
          try {
            final userData = user.data() as Map<String, dynamic>?;
            if (userData != null && userData['isActive'] == true) activeUsers++;
          } catch (e) {
            debugPrint('⚠️ Error procesando usuario ${user.id}: $e');
          }
        }
      }

      // Calcular estados de conductores
      if (driversSnapshot != null) {
        for (var driver in driversSnapshot.docs) {
          try {
            final driverData = driver.data() as Map<String, dynamic>?;
            if (driverData != null) {
              if (driverData['isOnline'] == true) onlineDrivers++;
              if (driverData['isAvailable'] == true) availableDrivers++;
              if (driverData['status'] == 'in_trip') driversInTrip++;
            }
          } catch (e) {
            debugPrint('⚠️ Error procesando conductor ${driver.id}: $e');
          }
        }
      }

      // Calcular ingresos, comisiones y ratings del día
      if (tripsSnapshot != null) {
        for (var trip in tripsSnapshot.docs) {
          try {
            final tripData = trip.data() as Map<String, dynamic>?;
            if (tripData == null) continue;

            final status = tripData['status'];

            if (status == 'completed') {
              completedTripsToday++;
              final fare = (tripData['finalFare'] ?? 0.0).toDouble();
              final commission =
                  (tripData['platformCommission'] ?? 0.0).toDouble();
              todayEarnings += fare;
              totalPlatformCommission += commission;

              // Calcular rating promedio
              if (tripData['rating'] != null) {
                totalRating += (tripData['rating'] as num).toDouble();
                ratedTrips++;
              }
            } else if (status == 'pending_payment') {
              pendingPayments++;
            }
          } catch (e) {
            debugPrint('⚠️ Error procesando viaje ${trip.id}: $e');
          }
        }
      }

      final averageRating = ratedTrips > 0 ? totalRating / ratedTrips : 0.0;
      final conversionRate = (tripsSnapshot != null && tripsSnapshot.docs.isNotEmpty)
          ? (completedTripsToday / tripsSnapshot.docs.length * 100)
          : 0.0;

      debugPrint('💰 Ingresos hoy: S/. ${todayEarnings.toStringAsFixed(2)}');
      debugPrint('⭐ Rating promedio: ${averageRating.toStringAsFixed(1)}');
      debugPrint('📈 Tasa de conversión: ${conversionRate.toStringAsFixed(1)}%');

      // ✅ CORREGIDO: Verificar mounted antes de setState para evitar error de dispose
      if (!mounted) return;

      setState(() {
        _stats = {
          'totalUsers': usersSnapshot?.docs.length ?? 0,
          'totalDrivers': driversSnapshot?.docs.length ?? 0,
          'tripsToday': tripsSnapshot?.docs.length ?? 0,
          'todayEarnings': todayEarnings,
          'activeUsers': activeUsers,
          'onlineDrivers': onlineDrivers,
          'availableDrivers': availableDrivers,
          'driversInTrip': driversInTrip,
          'newUsersMonth': newUsersMonthSnapshot?.docs.length ?? 0,
          'suspendedUsers': suspendedUsersSnapshot?.docs.length ?? 0,
          'averageRating': averageRating,
          'conversionRate': conversionRate,
          'completedTripsToday': completedTripsToday,
          'pendingPayments': pendingPayments,
          'withdrawalsToday': withdrawalsSnapshot?.docs.length ?? 0,
          'openDisputes': disputesSnapshot?.docs.length ?? 0,
          'platformCommission': totalPlatformCommission,
        };
      });

      debugPrint('✅ Dashboard cargado exitosamente');

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error crítico loading dashboard: $e');
      debugPrint('📍 Stack trace: $stackTrace');

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar el dashboard: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  final List<AdminMenuItem> _menuItems = [
    AdminMenuItem(
      icon: Icons.dashboard,
      title: 'Dashboard',
      subtitle: 'Vista general',
    ),
    AdminMenuItem(
      icon: Icons.people,
      title: 'Usuarios',
      subtitle: 'Gestión de usuarios',
    ),
    AdminMenuItem(
      icon: Icons.directions_car,
      title: 'Conductores',
      subtitle: 'Gestión de conductores',
    ),
    AdminMenuItem(
      icon: Icons.analytics,
      title: 'Analíticas',
      subtitle: 'Estadísticas y reportes',
    ),
    AdminMenuItem(
      icon: Icons.account_balance_wallet,
      title: 'Finanzas',
      subtitle: 'Gestión financiera',
    ),
    AdminMenuItem(
      icon: Icons.credit_card,
      title: 'Créditos',
      subtitle: 'Sistema de créditos',
    ),
    AdminMenuItem(
      icon: Icons.settings,
      title: 'Configuración',
      subtitle: 'Ajustes del sistema',
    ),
  ];

  // Confirmación de logout
  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.error,
            ),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: RappiAppBar(
        title: 'Panel Administrativo',
        showBackButton: false,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications, color: Theme.of(context).colorScheme.onPrimary),
            onPressed: () {
              Navigator.pushNamed(context, '/shared/notifications');
            },
            tooltip: 'Notificaciones',
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Theme.of(context).colorScheme.onPrimary),
            onPressed: _showLogoutConfirmation,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            // Layout para desktop/tablet
            return Row(
              children: [
                SizedBox(
                  width: 280,
                  child: _buildSidebar(),
                ),
                Expanded(
                  child: _buildMainContent(),
                ),
              ],
            );
          } else {
            // Layout para móvil
            return Column(
              children: [
                SizedBox(
                  height: 60,
                  child: _buildMobileNav(),
                ),
                Expanded(
                  child: _buildMainContent(),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          const RappiTeamDrawerHeader(
            userType: 'admin',
            userName: 'Administrador',
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _menuItems.length,
              itemBuilder: (context, index) {
                final item = _menuItems[index];
                final isSelected = index == _selectedIndex;
                
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? ModernTheme.rappiOrange.withValues(alpha: 0.1)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(
                      item.icon,
                      color: isSelected
                          ? ModernTheme.rappiOrange
                          : ModernTheme.textSecondary,
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(
                        color: isSelected
                            ? ModernTheme.rappiOrange
                            : ModernTheme.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      item.subtitle,
                      style: const TextStyle(
                        color: ModernTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedIndex = index;
                      });
                      // Navegar a las pantallas correspondientes
                      switch (index) {
                        case 1:
                          Navigator.pushNamed(context, '/admin/users-management');
                          break;
                        case 2:
                          Navigator.pushNamed(context, '/admin/drivers-management');
                          break;
                        case 3:
                          Navigator.pushNamed(context, '/admin/analytics');
                          break;
                        case 4:
                          Navigator.pushNamed(context, '/admin/financial');
                          break;
                        case 5:
                          // Créditos - se muestra inline en el dashboard
                          break;
                        case 6:
                          Navigator.pushNamed(context, '/admin/settings');
                          break;
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileNav() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calcular ancho de cada tab para que quepan todos
          final tabWidth = constraints.maxWidth / _menuItems.length;
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _menuItems.length,
            itemBuilder: (context, index) {
              final item = _menuItems[index];
              final isSelected = index == _selectedIndex;

              return SizedBox(
                width: tabWidth,
                child: InkWell(
              onTap: () {
                setState(() {
                  _selectedIndex = index;
                });
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item.icon,
                    color: isSelected
                        ? ModernTheme.rappiOrange
                        : ModernTheme.textSecondary,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    style: TextStyle(
                      color: isSelected
                          ? ModernTheme.rappiOrange
                          : ModernTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
            },
          );
        },
      ),
    );
  }

  Widget _buildMainContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _menuItems[_selectedIndex].title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: ModernTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _menuItems[_selectedIndex].subtitle,
            style: const TextStyle(
              color: ModernTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _buildContentForIndex(_selectedIndex),
          ),
        ],
      ),
    );
  }

  Widget _buildContentForIndex(int index) {
    switch (index) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return _buildUsersContent();
      case 2:
        return _buildDriversContent();
      case 3:
        return _buildAnalyticsContent();
      case 4:
        return _buildFinancesContent();
      case 5:
        return _buildCreditsContent();
      case 6:
        return _buildSettingsContent();
      default:
        return _buildDashboardContent();
    }
  }

  Widget _buildDashboardContent() {
    // Mostrar indicador de carga mientras se obtienen los datos
    if (_isLoading) {
      return GridView.count(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.4 : 1.1,
        children: List.generate(4, (index) => _buildLoadingCard()),
      );
    }

    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.4 : 1.1,
      children: [
        _buildStatsCard('Usuarios Totales', _stats['totalUsers'].toString(), Icons.people, Colors.blue),
        _buildStatsCard('Conductores', _stats['totalDrivers'].toString(), Icons.directions_car, Colors.green),
        _buildStatsCard('Viajes Hoy', _stats['tripsToday'].toString(), Icons.route, Colors.orange),
        _buildStatsCard('Ingresos', 'S/. ${_stats['todayEarnings'].toStringAsFixed(0)}', Icons.account_balance_wallet, Colors.purple),
      ],
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.getCardShadow(context),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 40,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Container(
            width: 60,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(String title, String value, IconData icon, Color color) {
    // Parse numeric value for progress bar (if applicable)
    final numericVal = double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    final progressVal = (numericVal / 1000).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: ModernTheme.getCardShadow(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icon circle - large
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              // Value
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: ModernTheme.textPrimary,
                  ),
                  maxLines: 1,
                ),
              ),
              // Title
              Text(
                title,
                style: const TextStyle(
                  color: ModernTheme.textSecondary,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Mini progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progressVal,
                  backgroundColor: color.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 4,
                ),
              ),
              // Empty space kept for original FittedBox compatibility
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '',
                  style: const TextStyle(
                    color: ModernTheme.textSecondary,
                    fontSize: 9,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUsersContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Estadísticas de usuarios
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.4 : 1.1,
            children: [
              _buildStatsCard('Total Usuarios', _stats['totalUsers'].toString(), Icons.people, Colors.blue),
              _buildStatsCard('Activos', _stats['activeUsers'].toString(), Icons.check_circle, Colors.green),
              _buildStatsCard('Nuevos (Mes)', _stats['newUsersMonth'].toString(), Icons.person_add, Colors.orange),
              _buildStatsCard('Suspendidos', _stats['suspendedUsers'].toString(), Icons.block, Colors.red),
            ],
          ),
          const SizedBox(height: 24),
          // Botón para ir a gestión completa
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/admin/users-management'),
            icon: const Icon(Icons.manage_accounts),
            label: const Text('Gestión Completa de Usuarios'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.rappiOrange,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriversContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Estadísticas de conductores
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.4 : 1.1,
            children: [
              _buildStatsCard('Total Conductores', _stats['totalDrivers'].toString(), Icons.directions_car, Colors.green),
              _buildStatsCard('En Línea', _stats['onlineDrivers'].toString(), Icons.wifi, Colors.blue),
              _buildStatsCard('Disponibles', _stats['availableDrivers'].toString(), Icons.check, Colors.orange),
              _buildStatsCard('En Viaje', _stats['driversInTrip'].toString(), Icons.route, Colors.purple),
            ],
          ),
          const SizedBox(height: 24),
          // Botón para ir a gestión completa
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/admin/drivers-management'),
            icon: const Icon(Icons.drive_eta),
            label: const Text('Gestión Completa de Conductores'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.rappiOrange,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // KPIs principales
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.4 : 1.1,
            children: [
              _buildStatsCard('Viajes Hoy', _stats['tripsToday'].toString(), Icons.route, Colors.blue),
              _buildStatsCard('Ingresos Hoy', 'S/. ${_stats['todayEarnings'].toStringAsFixed(0)}', Icons.account_balance_wallet, Colors.green),
              _buildStatsCard('Rating Promedio', '${_stats['averageRating'].toStringAsFixed(1)}⭐', Icons.star, Colors.amber),
              _buildStatsCard('Tasa Conversión', '${_stats['conversionRate'].toStringAsFixed(0)}%', Icons.trending_up, Colors.purple),
            ],
          ),
          const SizedBox(height: 24),
          // Botón para ir a analíticas completas
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/admin/analytics'),
            icon: const Icon(Icons.analytics),
            label: const Text('Ver Analíticas Completas'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.rappiOrange,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancesContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Resumen financiero
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [ModernTheme.rappiOrange, ModernTheme.rappiOrange.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: ModernTheme.getCardShadow(context),
            ),
            child: Column(
              children: [
                Text(
                  'Balance del Día',
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'S/. ${_stats['todayEarnings'].toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('Ingresos', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7))),
                        Text('S/. ${_stats['todayEarnings'].toStringAsFixed(0)}', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Container(width: 1, height: 30, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.3)),
                    Column(
                      children: [
                        Text('Comisiones', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7))),
                        Text('S/. ${_stats['platformCommission'].toStringAsFixed(0)}', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Estadísticas financieras
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.6,
            children: [
              _buildStatsCard('Pagos Pendientes', _stats['pendingPayments'].toString(), Icons.pending, Colors.orange),
              _buildStatsCard('Pagos Completados', _stats['completedTripsToday'].toString(), Icons.check_circle, Colors.green),
              _buildStatsCard('Retiros Hoy', _stats['withdrawalsToday'].toString(), Icons.account_balance, Colors.blue),
              _buildStatsCard('Disputas', _stats['openDisputes'].toString(), Icons.warning, Colors.red),
            ],
          ),
          const SizedBox(height: 24),
          // Botón para ir a finanzas completas
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/admin/financial'),
            icon: const Icon(Icons.account_balance_wallet),
            label: const Text('Gestión Financiera Completa'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.rappiOrange,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NUEVO: Panel de gestión de créditos para conductores
  Widget _buildCreditsContent() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firebaseService.firestore.collection('settings').doc('admin').snapshots(),
      builder: (context, settingsSnapshot) {
        // Valores por defecto
        double serviceFee = 1.0;
        double minServiceCredits = 10.0; // ✅ Unificado con mínimo de MercadoPago
        double bonusCreditsOnFirstRecharge = 5.0;
        List<dynamic> creditPackages = [];

        if (settingsSnapshot.hasData && settingsSnapshot.data!.exists) {
          final data = settingsSnapshot.data!.data() as Map<String, dynamic>?;
          if (data != null) {
            serviceFee = (data['serviceFee'] ?? 1.0).toDouble();
            minServiceCredits = (data['minServiceCredits'] ?? 10.0).toDouble(); // ✅ Unificado con mínimo de MercadoPago
            bonusCreditsOnFirstRecharge = (data['bonusCreditsOnFirstRecharge'] ?? 5.0).toDouble();
            creditPackages = data['creditPackages'] ?? [];
          }
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Estadísticas de créditos en tiempo real
              FutureBuilder<QuerySnapshot>(
                future: _firebaseService.firestore
                    .collection('wallets')
                    .get(),
                builder: (context, walletsSnapshot) {
                  double totalCreditsInSystem = 0;
                  double totalCreditsConsumed = 0;
                  int driversWithLowBalance = 0;
                  int driversWithCredits = 0;

                  if (walletsSnapshot.hasData) {
                    for (var doc in walletsSnapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final credits = (data['serviceCredits'] ?? 0.0).toDouble();
                      final consumed = (data['totalCreditsUsed'] ?? 0.0).toDouble();
                      totalCreditsInSystem += credits;
                      totalCreditsConsumed += consumed;
                      if (credits > 0) driversWithCredits++;
                      if (credits < minServiceCredits && credits > 0) driversWithLowBalance++;
                    }
                  }

                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.4 : 1.1,
                    children: [
                      _buildStatsCard(
                        'Créditos en Sistema',
                        'S/. ${totalCreditsInSystem.toStringAsFixed(0)}',
                        Icons.account_balance_wallet,
                        Colors.green,
                      ),
                      _buildStatsCard(
                        'Créditos Consumidos',
                        'S/. ${totalCreditsConsumed.toStringAsFixed(0)}',
                        Icons.trending_down,
                        Colors.orange,
                      ),
                      _buildStatsCard(
                        'Conductores con Saldo',
                        driversWithCredits.toString(),
                        Icons.person,
                        Colors.blue,
                      ),
                      _buildStatsCard(
                        'Saldo Bajo',
                        driversWithLowBalance.toString(),
                        Icons.warning,
                        Colors.red,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Configuración de créditos
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: ModernTheme.getCardShadow(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.settings, color: ModernTheme.rappiOrange),
                        const SizedBox(width: 8),
                        const Text(
                          'Configuración de Créditos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Costo por servicio
                    _buildConfigItem(
                      'Costo por Servicio',
                      'S/. ${serviceFee.toStringAsFixed(2)}',
                      'Créditos que se descuentan al aceptar un viaje',
                      Icons.monetization_on,
                      () => _showEditServiceFeeDialog(serviceFee),
                    ),
                    const Divider(height: 24),

                    // Mínimo de créditos
                    _buildConfigItem(
                      'Mínimo de Créditos',
                      'S/. ${minServiceCredits.toStringAsFixed(2)}',
                      'Saldo mínimo para poder aceptar servicios',
                      Icons.warning_amber,
                      () => _showEditMinCreditsDialog(minServiceCredits),
                    ),
                    const Divider(height: 24),

                    // Bono primera recarga
                    _buildConfigItem(
                      'Bono Primera Recarga',
                      'S/. ${bonusCreditsOnFirstRecharge.toStringAsFixed(2)}',
                      'Créditos adicionales en la primera recarga',
                      Icons.card_giftcard,
                      () => _showEditBonusDialog(bonusCreditsOnFirstRecharge),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Paquetes de créditos
              Container(
                padding: const EdgeInsets.all(20),
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
                        Row(
                          children: [
                            Icon(Icons.inventory_2, color: ModernTheme.primaryBlue),
                            const SizedBox(width: 8),
                            const Text(
                              'Paquetes de Créditos',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: ModernTheme.rappiOrange),
                          onPressed: _showAddPackageDialog,
                          tooltip: 'Agregar paquete',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (creditPackages.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text(
                                'No hay paquetes configurados',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: _showAddPackageDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('Crear Paquete'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ModernTheme.rappiOrange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: creditPackages.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final package = creditPackages[index] as Map<String, dynamic>;
                          final amount = (package['amount'] ?? 0).toDouble();
                          final bonus = (package['bonus'] ?? 0).toDouble();
                          final price = (package['price'] ?? amount).toDouble();
                          final isPopular = package['popular'] ?? false;

                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isPopular
                                    ? ModernTheme.rappiOrange.withValues(alpha: 0.1)
                                    : Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.credit_card,
                                color: isPopular ? ModernTheme.rappiOrange : Colors.blue,
                              ),
                            ),
                            title: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'S/. ${amount.toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                if (bonus > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: ModernTheme.rappiOrange,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '+${bonus.toStringAsFixed(0)} bonus',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                if (isPopular)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: ModernTheme.primaryOrange,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'Popular',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text('Precio: S/. ${price.toStringAsFixed(2)}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deletePackage(index),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Acción rápida: Agregar créditos a conductor
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [ModernTheme.rappiOrange, ModernTheme.rappiOrange.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(Icons.person_add, color: Colors.white, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      'Agregar Créditos Manualmente',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Agrega créditos a un conductor específico',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _showAddCreditsToDriverDialog,
                          icon: const Icon(Icons.person_add),
                          label: const Text('Individual'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: ModernTheme.rappiOrange,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _showBulkCreditsDialog,
                          icon: const Icon(Icons.group_add),
                          label: const Text('Masivo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Widget helper para items de configuración
  Widget _buildConfigItem(String title, String value, String description, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: ModernTheme.rappiOrange),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(description, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: ModernTheme.rappiOrange,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.edit, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  // Diálogo para editar costo por servicio
  void _showEditServiceFeeDialog(double currentValue) {
    final controller = TextEditingController(text: currentValue.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Costo por Servicio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Créditos que se descontarán al conductor cada vez que acepte un viaje.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Costo (S/.)',
                prefixText: 'S/. ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final value = double.tryParse(controller.text) ?? currentValue;
              await _firebaseService.firestore
                  .collection('settings')
                  .doc('admin')
                  .set({'serviceFee': value}, SetOptions(merge: true));
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: ModernTheme.rappiOrange),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // Diálogo para editar mínimo de créditos
  void _showEditMinCreditsDialog(double currentValue) {
    final controller = TextEditingController(text: currentValue.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mínimo de Créditos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Saldo mínimo que debe tener un conductor para poder aceptar servicios.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Mínimo (S/.)',
                prefixText: 'S/. ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final value = double.tryParse(controller.text) ?? currentValue;
              await _firebaseService.firestore
                  .collection('settings')
                  .doc('admin')
                  .set({'minServiceCredits': value}, SetOptions(merge: true));
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: ModernTheme.rappiOrange),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // Diálogo para editar bono de primera recarga
  void _showEditBonusDialog(double currentValue) {
    final controller = TextEditingController(text: currentValue.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bono Primera Recarga'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Créditos adicionales que recibirá el conductor en su primera recarga.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Bono (S/.)',
                prefixText: 'S/. ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final value = double.tryParse(controller.text) ?? currentValue;
              await _firebaseService.firestore
                  .collection('settings')
                  .doc('admin')
                  .set({'bonusCreditsOnFirstRecharge': value}, SetOptions(merge: true));
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: ModernTheme.rappiOrange),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // Diálogo para agregar paquete de créditos
  void _showAddPackageDialog() {
    final amountController = TextEditingController();
    final bonusController = TextEditingController(text: '0');
    final priceController = TextEditingController();
    bool isPopular = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nuevo Paquete de Créditos'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad de Créditos',
                    prefixText: 'S/. ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    if (priceController.text.isEmpty) {
                      priceController.text = value;
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: bonusController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Bonus Adicional',
                    prefixText: 'S/. ',
                    border: OutlineInputBorder(),
                    helperText: 'Créditos extra gratis',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Precio de Venta',
                    prefixText: 'S/. ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Marcar como Popular'),
                  subtitle: const Text('Se mostrará destacado'),
                  value: isPopular,
                  onChanged: (value) => setDialogState(() => isPopular = value),
                  activeTrackColor: ModernTheme.rappiOrange.withValues(alpha: 0.5),
                  thumbColor: WidgetStateProperty.resolveWith((states) =>
                      states.contains(WidgetState.selected) ? ModernTheme.rappiOrange : null),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0;
                final bonus = double.tryParse(bonusController.text) ?? 0;
                final price = double.tryParse(priceController.text) ?? amount;

                if (amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('La cantidad debe ser mayor a 0')),
                  );
                  return;
                }

                // Obtener paquetes actuales
                final doc = await _firebaseService.firestore
                    .collection('settings')
                    .doc('admin')
                    .get();

                List<dynamic> currentPackages = [];
                if (doc.exists) {
                  currentPackages = (doc.data()?['creditPackages'] ?? []) as List<dynamic>;
                }

                // Agregar nuevo paquete
                currentPackages.add({
                  'amount': amount,
                  'bonus': bonus,
                  'price': price,
                  'popular': isPopular,
                });

                // Ordenar por cantidad
                currentPackages.sort((a, b) => (a['amount'] as num).compareTo(b['amount'] as num));

                await _firebaseService.firestore
                    .collection('settings')
                    .doc('admin')
                    .set({'creditPackages': currentPackages}, SetOptions(merge: true));

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Paquete de créditos creado exitosamente'),
                      backgroundColor: ModernTheme.rappiOrange,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: ModernTheme.rappiOrange),
              child: const Text('Crear Paquete'),
            ),
          ],
        ),
      ),
    );
  }

  // Eliminar paquete
  Future<void> _deletePackage(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Paquete'),
        content: const Text('¿Estás seguro de eliminar este paquete de créditos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final doc = await _firebaseService.firestore
          .collection('settings')
          .doc('admin')
          .get();

      if (doc.exists) {
        List<dynamic> packages = (doc.data()?['creditPackages'] ?? []) as List<dynamic>;
        if (index < packages.length) {
          packages.removeAt(index);
          await _firebaseService.firestore
              .collection('settings')
              .doc('admin')
              .set({'creditPackages': packages}, SetOptions(merge: true));
        }
      }
    }
  }

  // Diálogo para agregar créditos a un conductor específico
  void _showAddCreditsToDriverDialog() {
    final emailController = TextEditingController();
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    String? selectedDriverId;
    String? selectedDriverName;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Agregar Créditos a Conductor'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Buscar conductor por email
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email del Conductor',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () async {
                        final email = emailController.text.trim();
                        if (email.isEmpty) return;

                        final query = await _firebaseService.firestore
                            .collection('users')
                            .where('email', isEqualTo: email)
                            .where('userType', whereIn: ['driver', 'dual'])
                            .limit(1)
                            .get();

                        if (query.docs.isNotEmpty) {
                          final user = query.docs.first;
                          final driverName = user.data()['displayName'] ?? user.data()['name'] ?? 'Conductor';
                          setDialogState(() {
                            selectedDriverId = user.id;
                            selectedDriverName = driverName;
                          });
                          // Feedback visual de éxito
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✅ Conductor encontrado: $driverName'),
                                backgroundColor: ModernTheme.rappiOrange,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Conductor no encontrado')),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ),
                if (selectedDriverId != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: ModernTheme.rappiOrange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(selectedDriverName!, style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('ID: $selectedDriverId', style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Cantidad de Créditos',
                    prefixText: 'S/. ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Razón (opcional)',
                    border: OutlineInputBorder(),
                    hintText: 'Ej: Compensación, promoción, etc.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: selectedDriverId == null
                  ? null
                  : () async {
                      final amount = double.tryParse(amountController.text) ?? 0;
                      if (amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('La cantidad debe ser mayor a 0')),
                        );
                        return;
                      }

                      try {
                        // Actualizar wallet del conductor
                        final walletRef = _firebaseService.firestore
                            .collection('wallets')
                            .doc(selectedDriverId);

                        final walletDoc = await walletRef.get();
                        double currentCredits = 0;
                        if (walletDoc.exists) {
                          currentCredits = (walletDoc.data()?['serviceCredits'] ?? 0.0).toDouble();
                        }

                        await walletRef.set({
                          'serviceCredits': currentCredits + amount,
                          'totalCreditsRecharged': FieldValue.increment(amount),
                          'lastCreditUpdate': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true));

                        // Registrar transacción
                        await _firebaseService.firestore
                            .collection('wallets')
                            .doc(selectedDriverId)
                            .collection('credit_transactions')
                            .add({
                          'type': 'admin_credit',
                          'amount': amount,
                          'previousBalance': currentCredits,
                          'newBalance': currentCredits + amount,
                          'reason': reasonController.text.trim().isEmpty
                              ? 'Créditos agregados por administrador'
                              : reasonController.text.trim(),
                          'adminId': 'admin',
                          'timestamp': FieldValue.serverTimestamp(),
                        });

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Se agregaron S/. ${amount.toStringAsFixed(2)} créditos a $selectedDriverName'),
                              backgroundColor: ModernTheme.rappiOrange,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: ModernTheme.rappiOrange),
              child: const Text('Agregar Créditos'),
            ),
          ],
        ),
      ),
    );
  }

  // Diálogo para agregar créditos a múltiples conductores
  void _showBulkCreditsDialog() {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    final searchController = TextEditingController();
    List<Map<String, dynamic>> allDrivers = [];
    List<Map<String, dynamic>> filteredDrivers = [];
    Set<String> selectedDriverIds = {};
    bool isLoading = true;
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Cargar conductores al inicio
          if (isLoading && allDrivers.isEmpty) {
            _firebaseService.firestore
                .collection('users')
                .where('userType', whereIn: ['driver', 'dual'])
                .get()
                .then((snapshot) {
              setDialogState(() {
                allDrivers = snapshot.docs.map((doc) => {
                  'id': doc.id,
                  'name': doc.data()['displayName'] ?? doc.data()['name'] ?? 'Sin nombre',
                  'email': doc.data()['email'] ?? '',
                }).toList();
                filteredDrivers = List.from(allDrivers);
                isLoading = false;
              });
            });
          }

          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.group_add, color: ModernTheme.rappiOrange),
                const SizedBox(width: 8),
                const Text('Créditos Masivos'),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.85,
              height: MediaQuery.of(context).size.height * 0.65,
              child: Column(
                children: [
                  // Campos de cantidad y razón
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Cantidad',
                            prefixText: 'S/. ',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: reasonController,
                          decoration: const InputDecoration(
                            labelText: 'Razón',
                            border: OutlineInputBorder(),
                            hintText: 'Ej: Promoción Año Nuevo',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Búsqueda y selección masiva
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          decoration: const InputDecoration(
                            labelText: 'Buscar conductor',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (value) {
                            setDialogState(() {
                              filteredDrivers = allDrivers.where((d) =>
                                d['name'].toString().toLowerCase().contains(value.toLowerCase()) ||
                                d['email'].toString().toLowerCase().contains(value.toLowerCase())
                              ).toList();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            if (selectedDriverIds.length == filteredDrivers.length) {
                              selectedDriverIds.clear();
                            } else {
                              selectedDriverIds = filteredDrivers.map((d) => d['id'] as String).toSet();
                            }
                          });
                        },
                        icon: Icon(selectedDriverIds.length == filteredDrivers.length && filteredDrivers.isNotEmpty
                            ? Icons.deselect : Icons.select_all),
                        label: Text(selectedDriverIds.length == filteredDrivers.length && filteredDrivers.isNotEmpty
                            ? 'Ninguno' : 'Todos'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Contador de seleccionados
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people, color: ModernTheme.rappiOrange, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${selectedDriverIds.length} de ${filteredDrivers.length} conductores seleccionados',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Lista de conductores
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : filteredDrivers.isEmpty
                            ? const Center(child: Text('No hay conductores'))
                            : ListView.builder(
                                itemCount: filteredDrivers.length,
                                itemBuilder: (context, index) {
                                  final driver = filteredDrivers[index];
                                  final isSelected = selectedDriverIds.contains(driver['id']);
                                  return CheckboxListTile(
                                    value: isSelected,
                                    onChanged: (value) {
                                      setDialogState(() {
                                        if (value == true) {
                                          selectedDriverIds.add(driver['id']);
                                        } else {
                                          selectedDriverIds.remove(driver['id']);
                                        }
                                      });
                                    },
                                    title: Text(driver['name']),
                                    subtitle: Text(driver['email'], style: const TextStyle(fontSize: 12)),
                                    secondary: CircleAvatar(
                                      backgroundColor: ModernTheme.rappiOrange.withValues(alpha: 0.2),
                                      child: Text(
                                        driver['name'].toString().isNotEmpty
                                            ? driver['name'].toString()[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(color: ModernTheme.rappiOrange),
                                      ),
                                    ),
                                    dense: true,
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                onPressed: isProcessing || selectedDriverIds.isEmpty
                    ? null
                    : () async {
                        final amount = double.tryParse(amountController.text) ?? 0;
                        if (amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('La cantidad debe ser mayor a 0')),
                          );
                          return;
                        }

                        // Confirmar
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Confirmar'),
                            content: Text(
                              '¿Agregar S/. ${amount.toStringAsFixed(2)} a ${selectedDriverIds.length} conductores?\n\n'
                              'Total a distribuir: S/. ${(amount * selectedDriverIds.length).toStringAsFixed(2)}'
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('No'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(backgroundColor: ModernTheme.rappiOrange),
                                child: const Text('Sí, confirmar'),
                              ),
                            ],
                          ),
                        );

                        if (confirm != true) return;

                        setDialogState(() => isProcessing = true);

                        int success = 0;
                        int failed = 0;
                        final reason = reasonController.text.trim().isEmpty
                            ? 'Créditos masivos por administrador'
                            : reasonController.text.trim();

                        for (final driverId in selectedDriverIds) {
                          try {
                            final walletRef = _firebaseService.firestore
                                .collection('wallets').doc(driverId);

                            await walletRef.set({
                              'serviceCredits': FieldValue.increment(amount),
                              'totalCreditsRecharged': FieldValue.increment(amount),
                              'lastCreditUpdate': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));

                            // Registrar transacción individual
                            await _firebaseService.firestore
                                .collection('wallets')
                                .doc(driverId)
                                .collection('credit_transactions')
                                .add({
                              'type': 'admin_bulk_credit',
                              'amount': amount,
                              'reason': reason,
                              'adminId': 'admin',
                              'totalRecipients': selectedDriverIds.length,
                              'timestamp': FieldValue.serverTimestamp(),
                            });
                            success++;
                          } catch (e) {
                            failed++;
                          }
                        }

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Créditos agregados a $success conductores${failed > 0 ? ' ($failed fallidos)' : ''}',
                              ),
                              backgroundColor: failed == 0 ? ModernTheme.rappiOrange : Colors.orange,
                            ),
                          );
                          // Refrescar el dashboard para mostrar los nuevos totales
                          _loadDashboardData();
                        }
                      },
                icon: isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send),
                label: Text(isProcessing ? 'Procesando...' : 'Agregar Créditos'),
                style: ElevatedButton.styleFrom(backgroundColor: ModernTheme.rappiOrange),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSettingsContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Lista de configuraciones
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: ModernTheme.getCardShadow(context),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet, color: ModernTheme.rappiOrange),
                  title: const Text('Tarifas y Precios'),
                  subtitle: const Text('Configurar tarifas base y comisiones'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.pushNamed(context, '/admin/settings'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.map, color: ModernTheme.primaryBlue),
                  title: const Text('Zonas y Cobertura'),
                  subtitle: const Text('Gestionar áreas de servicio'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.pushNamed(context, '/admin/settings'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.local_offer, color: ModernTheme.primaryOrange),
                  title: const Text('Promociones'),
                  subtitle: const Text('Códigos y descuentos activos'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.pushNamed(context, '/admin/settings'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications, color: ModernTheme.warning),
                  title: const Text('Notificaciones'),
                  subtitle: const Text('Configurar alertas y mensajes'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.pushNamed(context, '/shared/notifications'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.security, color: ModernTheme.error),
                  title: const Text('Seguridad'),
                  subtitle: const Text('Políticas y permisos'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.pushNamed(context, '/admin/settings'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Botón para ir a configuración completa
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/admin/settings'),
            icon: const Icon(Icons.settings),
            label: const Text('Configuración Completa del Sistema'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.rappiOrange,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminMenuItem {
  final IconData icon;
  final String title;
  final String subtitle;

  AdminMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}