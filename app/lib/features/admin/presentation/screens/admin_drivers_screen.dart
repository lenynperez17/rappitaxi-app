import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_theme.dart';
import '../widgets/driver_management_card.dart';
import '../widgets/driver_filter_chips.dart';

class AdminDriversScreen extends StatefulWidget {
  const AdminDriversScreen({super.key});

  @override
  State<AdminDriversScreen> createState() => _AdminDriversScreenState();
}

class _AdminDriversScreenState extends State<AdminDriversScreen> {
  String _selectedFilter = 'all';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredDrivers = _getFilteredDrivers();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Conductores'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Actualizar lista de conductores
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _showAddDriverDialog();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda y filtros
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Barra de búsqueda
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar conductores...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Chips de filtro
                DriverFilterChips(
                  selectedFilter: _selectedFilter,
                  onFilterChanged: (filter) {
                    setState(() {
                      _selectedFilter = filter;
                    });
                  },
                ),
              ],
            ),
          ),
          
          // Lista de conductores
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                // Actualizar datos
              },
              child: filteredDrivers.isEmpty
                  ? _buildEmptyState()
                  : _buildDriversList(filteredDrivers),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No se encontraron conductores',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Intenta ajustar los filtros de búsqueda',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriversList(List<AdminDriverInfo> drivers) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: drivers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final driver = drivers[index];
        return DriverManagementCard(
          driver: driver,
          onStatusChanged: (newStatus) {
            _updateDriverStatus(driver.id, newStatus);
          },
          onViewDetails: () {
            _showDriverDetails(driver);
          },
          onSendMessage: () {
            _sendMessageToDriver(driver);
          },
        ).animate(delay: Duration(milliseconds: index * 100))
            .fadeIn()
            .slideY(begin: 0.2, end: 0);
      },
    );
  }

  List<AdminDriverInfo> _getFilteredDrivers() {
    List<AdminDriverInfo> drivers = _getMockDrivers();
    
    // Filtrar por búsqueda
    if (_searchController.text.isNotEmpty) {
      drivers = drivers.where((driver) {
        return driver.name.toLowerCase().contains(_searchController.text.toLowerCase()) ||
               driver.licensePlate.toLowerCase().contains(_searchController.text.toLowerCase());
      }).toList();
    }
    
    // Filtrar por estado
    if (_selectedFilter != 'all') {
      drivers = drivers.where((driver) => driver.status == _selectedFilter).toList();
    }
    
    return drivers;
  }

  List<AdminDriverInfo> _getMockDrivers() {
    return [
      AdminDriverInfo(
        id: '1',
        name: 'Carlos Mendoza',
        phone: '+51 987 654 321',
        email: 'carlos@example.com',
        rating: 4.8,
        totalTrips: 156,
        status: 'online',
        licensePlate: 'ABC-123',
        vehicleModel: 'Toyota Yaris',
        vehicleColor: 'Blanco',
        joinedDate: DateTime.now().subtract(const Duration(days: 45)),
        photoUrl: null,
      ),
      AdminDriverInfo(
        id: '2',
        name: 'María López',
        phone: '+51 987 654 322',
        email: 'maria@example.com',
        rating: 4.9,
        totalTrips: 203,
        status: 'offline',
        licensePlate: 'DEF-456',
        vehicleModel: 'Nissan Versa',
        vehicleColor: 'Gris',
        joinedDate: DateTime.now().subtract(const Duration(days: 67)),
        photoUrl: null,
      ),
      AdminDriverInfo(
        id: '3',
        name: 'Pedro Ramírez',
        phone: '+51 987 654 323',
        email: 'pedro@example.com',
        rating: 4.6,
        totalTrips: 89,
        status: 'in_ride',
        licensePlate: 'GHI-789',
        vehicleModel: 'Hyundai Grand i10',
        vehicleColor: 'Azul',
        joinedDate: DateTime.now().subtract(const Duration(days: 23)),
        photoUrl: null,
      ),
      AdminDriverInfo(
        id: '4',
        name: 'Ana García',
        phone: '+51 987 654 324',
        email: 'ana@example.com',
        rating: 4.7,
        totalTrips: 134,
        status: 'suspended',
        licensePlate: 'JKL-012',
        vehicleModel: 'Chevrolet Spark',
        vehicleColor: 'Rojo',
        joinedDate: DateTime.now().subtract(const Duration(days: 78)),
        photoUrl: null,
      ),
    ];
  }

  void _updateDriverStatus(String driverId, String newStatus) {
    // TODO: Implementar actualización de estado del conductor
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Estado del conductor actualizado a: $newStatus'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  void _showDriverDetails(AdminDriverInfo driver) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: _buildDriverDetailsSheet(driver, scrollController),
          );
        },
      ),
    );
  }

  Widget _buildDriverDetailsSheet(AdminDriverInfo driver, ScrollController scrollController) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Información del conductor
          Text(
            'Detalles del conductor',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          
          const SizedBox(height: 20),
          
          _buildDetailRow('Nombre', driver.name),
          _buildDetailRow('Teléfono', driver.phone),
          _buildDetailRow('Email', driver.email),
          _buildDetailRow('Calificación', '${driver.rating} ⭐'),
          _buildDetailRow('Total de viajes', driver.totalTrips.toString()),
          _buildDetailRow('Estado', _getStatusText(driver.status)),
          
          const SizedBox(height: 20),
          
          Text(
            'Información del vehículo',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          
          const SizedBox(height: 12),
          
          _buildDetailRow('Placa', driver.licensePlate),
          _buildDetailRow('Modelo', driver.vehicleModel),
          _buildDetailRow('Color', driver.vehicleColor),
          
          const SizedBox(height: 30),
          
          // Botones de acción
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _sendMessageToDriver(driver);
                  },
                  icon: const Icon(Icons.message),
                  label: const Text('Mensaje'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showStatusChangeDialog(driver);
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Cambiar estado'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessageToDriver(AdminDriverInfo driver) {
    // TODO: Implementar funcionalidad de envío de mensajes
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Enviando mensaje a ${driver.name}...'),
        backgroundColor: AppTheme.infoColor,
      ),
    );
  }

  void _showStatusChangeDialog(AdminDriverInfo driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar estado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Activo'),
              onTap: () {
                Navigator.pop(context);
                _updateDriverStatus(driver.id, 'active');
              },
            ),
            ListTile(
              title: const Text('Suspendido'),
              onTap: () {
                Navigator.pop(context);
                _updateDriverStatus(driver.id, 'suspended');
              },
            ),
            ListTile(
              title: const Text('Bloqueado'),
              onTap: () {
                Navigator.pop(context);
                _updateDriverStatus(driver.id, 'blocked');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  void _showAddDriverDialog() {
    // TODO: Implementar formulario para agregar conductor
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Función de agregar conductor próximamente...'),
        backgroundColor: AppTheme.infoColor,
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'online':
        return 'En línea';
      case 'offline':
        return 'Desconectado';
      case 'in_ride':
        return 'En viaje';
      case 'suspended':
        return 'Suspendido';
      case 'blocked':
        return 'Bloqueado';
      default:
        return status;
    }
  }
}

class AdminDriverInfo {
  final String id;
  final String name;
  final String phone;
  final String email;
  final double rating;
  final int totalTrips;
  final String status;
  final String licensePlate;
  final String vehicleModel;
  final String vehicleColor;
  final DateTime joinedDate;
  final String? photoUrl;

  AdminDriverInfo({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.rating,
    required this.totalTrips,
    required this.status,
    required this.licensePlate,
    required this.vehicleModel,
    required this.vehicleColor,
    required this.joinedDate,
    this.photoUrl,
  });
}