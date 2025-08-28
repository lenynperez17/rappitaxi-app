import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_theme.dart';

class AdminPassengersScreen extends StatefulWidget {
  const AdminPassengersScreen({super.key});

  @override
  State<AdminPassengersScreen> createState() => _AdminPassengersScreenState();
}

class _AdminPassengersScreenState extends State<AdminPassengersScreen> {
  String _selectedFilter = 'all';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredPassengers = _getFilteredPassengers();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Pasajeros'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Actualizar lista de pasajeros
            },
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () {
              _showPassengerAnalytics();
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
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Estadísticas rápidas
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickStat(
                        'Total Pasajeros',
                        '1,234',
                        Icons.people,
                        AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickStat(
                        'Activos Hoy',
                        '892',
                        Icons.trending_up,
                        AppTheme.successColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickStat(
                        'Nuevos (7d)',
                        '45',
                        Icons.person_add,
                        AppTheme.accentColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Barra de búsqueda
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar pasajeros por nombre, email o teléfono...',
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
                    fillColor: Colors.grey.shade100,
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),

                const SizedBox(height: 16),

                // Chips de filtro
                _buildFilterChips(),
              ],
            ),
          ),

          // Lista de pasajeros
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                // Actualizar datos
              },
              child: filteredPassengers.isEmpty
                  ? _buildEmptyState()
                  : _buildPassengersList(filteredPassengers),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      FilterOption('all', 'Todos', Icons.group),
      FilterOption('active', 'Activos', Icons.verified_user),
      FilterOption('inactive', 'Inactivos', Icons.person_off),
      FilterOption('premium', 'Premium', Icons.star),
      FilterOption('recent', 'Recientes', Icons.new_releases),
      FilterOption('frequent', 'Frecuentes', Icons.repeat),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter.value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    filter.icon,
                    size: 16,
                    color: isSelected ? Colors.white : AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(filter.label),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedFilter = filter.value;
                  });
                }
              },
              selectedColor: AppTheme.primaryColor,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: Colors.grey.shade100,
            ),
          );
        }).toList(),
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
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No se encontraron pasajeros',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Intenta ajustar los filtros de búsqueda',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassengersList(List<AdminPassengerInfo> passengers) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: passengers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final passenger = passengers[index];
        return _buildPassengerCard(passenger)
            .animate(delay: Duration(milliseconds: index * 50))
            .fadeIn()
            .slideX(begin: 0.2, end: 0);
      },
    );
  }

  Widget _buildPassengerCard(AdminPassengerInfo passenger) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header con info básica
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  backgroundImage: passenger.photoUrl != null
                      ? NetworkImage(passenger.photoUrl!)
                      : null,
                  child: passenger.photoUrl == null
                      ? Text(
                          passenger.name.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              passenger.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (passenger.isPremium)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Premium',
                                    style: TextStyle(
                                      color: Colors.amber.shade700,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        passenger.email,
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        passenger.phone,
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: passenger.isActive
                        ? AppTheme.successColor
                        : Colors.grey.shade400,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Estadísticas del pasajero
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildPassengerStat(
                    'Viajes',
                    passenger.totalRides.toString(),
                    Icons.directions_car,
                  ),
                  _buildPassengerStat(
                    'Rating',
                    passenger.rating.toString(),
                    Icons.star,
                  ),
                  _buildPassengerStat(
                    'Gastado',
                    'S/ ${passenger.totalSpent.toStringAsFixed(0)}',
                    Icons.monetization_on,
                  ),
                  _buildPassengerStat(
                    'Último viaje',
                    _formatLastRide(passenger.lastRideDate),
                    Icons.access_time,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showPassengerDetails(passenger),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('Ver detalles'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: BorderSide(color: AppTheme.primaryColor),
                      foregroundColor: AppTheme.primaryColor,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                OutlinedButton(
                  onPressed: () => _sendMessageToPassenger(passenger),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(40, 40),
                    side: BorderSide(color: AppTheme.infoColor),
                    foregroundColor: AppTheme.infoColor,
                  ),
                  child: const Icon(Icons.message, size: 16),
                ),

                const SizedBox(width: 8),

                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'view_rides') {
                      _showPassengerRides(passenger);
                    } else if (value == 'view_payments') {
                      _showPassengerPayments(passenger);
                    } else if (value == 'change_status') {
                      _showStatusChangeDialog(passenger);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view_rides',
                      child: Row(
                        children: [
                          Icon(Icons.history, size: 18),
                          SizedBox(width: 8),
                          Text('Ver viajes'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'view_payments',
                      child: Row(
                        children: [
                          Icon(Icons.payment, size: 18),
                          SizedBox(width: 8),
                          Text('Ver pagos'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'change_status',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Cambiar estado'),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.more_vert,
                      size: 16,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassengerStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppTheme.primaryColor,
          size: 16,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textSecondaryColor,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  List<AdminPassengerInfo> _getFilteredPassengers() {
    List<AdminPassengerInfo> passengers = _getMockPassengers();

    // Filtrar por búsqueda
    if (_searchController.text.isNotEmpty) {
      passengers = passengers.where((passenger) {
        final searchTerm = _searchController.text.toLowerCase();
        return passenger.name.toLowerCase().contains(searchTerm) ||
            passenger.email.toLowerCase().contains(searchTerm) ||
            passenger.phone.toLowerCase().contains(searchTerm);
      }).toList();
    }

    // Filtrar por estado
    switch (_selectedFilter) {
      case 'active':
        passengers = passengers.where((p) => p.isActive).toList();
        break;
      case 'inactive':
        passengers = passengers.where((p) => !p.isActive).toList();
        break;
      case 'premium':
        passengers = passengers.where((p) => p.isPremium).toList();
        break;
      case 'recent':
        passengers = passengers.where((p) {
          final daysSinceJoined = DateTime.now().difference(p.joinedDate).inDays;
          return daysSinceJoined <= 7;
        }).toList();
        break;
      case 'frequent':
        passengers = passengers.where((p) => p.totalRides >= 50).toList();
        break;
    }

    return passengers;
  }

  List<AdminPassengerInfo> _getMockPassengers() {
    return [
      AdminPassengerInfo(
        id: '1',
        name: 'María González',
        email: 'maria.gonzalez@email.com',
        phone: '+51 987 654 321',
        totalRides: 87,
        rating: 4.9,
        totalSpent: 2145.50,
        isActive: true,
        isPremium: true,
        joinedDate: DateTime.now().subtract(const Duration(days: 125)),
        lastRideDate: DateTime.now().subtract(const Duration(days: 2)),
        photoUrl: null,
      ),
      AdminPassengerInfo(
        id: '2',
        name: 'Carlos Pérez',
        email: 'carlos.perez@email.com',
        phone: '+51 987 654 322',
        totalRides: 23,
        rating: 4.6,
        totalSpent: 456.75,
        isActive: false,
        isPremium: false,
        joinedDate: DateTime.now().subtract(const Duration(days: 45)),
        lastRideDate: DateTime.now().subtract(const Duration(days: 15)),
        photoUrl: null,
      ),
      AdminPassengerInfo(
        id: '3',
        name: 'Ana Rodriguez',
        email: 'ana.rodriguez@email.com',
        phone: '+51 987 654 323',
        totalRides: 156,
        rating: 4.8,
        totalSpent: 3821.25,
        isActive: true,
        isPremium: true,
        joinedDate: DateTime.now().subtract(const Duration(days: 234)),
        lastRideDate: DateTime.now().subtract(const Duration(hours: 3)),
        photoUrl: null,
      ),
      AdminPassengerInfo(
        id: '4',
        name: 'Luis Torres',
        email: 'luis.torres@email.com',
        phone: '+51 987 654 324',
        totalRides: 12,
        rating: 4.5,
        totalSpent: 238.90,
        isActive: true,
        isPremium: false,
        joinedDate: DateTime.now().subtract(const Duration(days: 8)),
        lastRideDate: DateTime.now().subtract(const Duration(days: 1)),
        photoUrl: null,
      ),
    ];
  }

  String _formatLastRide(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m';
      }
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${(difference.inDays / 7).floor()}sem';
    }
  }

  void _showPassengerDetails(AdminPassengerInfo passenger) {
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
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Detalles del pasajero',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildDetailRow('Nombre', passenger.name),
                  _buildDetailRow('Email', passenger.email),
                  _buildDetailRow('Teléfono', passenger.phone),
                  _buildDetailRow('Total viajes', passenger.totalRides.toString()),
                  _buildDetailRow('Rating promedio', '${passenger.rating} ⭐'),
                  _buildDetailRow('Total gastado', 'S/ ${passenger.totalSpent.toStringAsFixed(2)}'),
                  _buildDetailRow('Estado', passenger.isActive ? 'Activo' : 'Inactivo'),
                  _buildDetailRow('Tipo cuenta', passenger.isPremium ? 'Premium' : 'Estándar'),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _sendMessageToPassenger(passenger);
                          },
                          icon: const Icon(Icons.message),
                          label: const Text('Enviar mensaje'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showPassengerRides(passenger);
                          },
                          icon: const Icon(Icons.history),
                          label: const Text('Ver viajes'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
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

  void _sendMessageToPassenger(AdminPassengerInfo passenger) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Enviando mensaje a ${passenger.name}...'),
        backgroundColor: AppTheme.infoColor,
      ),
    );
  }

  void _showPassengerRides(AdminPassengerInfo passenger) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Viajes de ${passenger.name}'),
        content: const SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Center(
            child: Text('Lista de viajes del pasajero...'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showPassengerPayments(AdminPassengerInfo passenger) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pagos de ${passenger.name}'),
        content: const SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Center(
            child: Text('Historial de pagos del pasajero...'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showStatusChangeDialog(AdminPassengerInfo passenger) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cambiar estado de ${passenger.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle, color: AppTheme.successColor),
              title: const Text('Activar cuenta'),
              onTap: () {
                Navigator.pop(context);
                _updatePassengerStatus(passenger.id, 'active');
              },
            ),
            ListTile(
              leading: const Icon(Icons.pause_circle, color: AppTheme.warningColor),
              title: const Text('Suspender cuenta'),
              onTap: () {
                Navigator.pop(context);
                _updatePassengerStatus(passenger.id, 'suspended');
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: AppTheme.errorColor),
              title: const Text('Bloquear cuenta'),
              onTap: () {
                Navigator.pop(context);
                _updatePassengerStatus(passenger.id, 'blocked');
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

  void _updatePassengerStatus(String passengerId, String newStatus) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Estado del pasajero actualizado a: $newStatus'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  void _showPassengerAnalytics() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Analíticas de Pasajeros'),
        content: const SizedBox(
          width: double.maxFinite,
          height: 200,
          child: Center(
            child: Text('Gráficos y estadísticas de pasajeros...'),
          ),
        ),
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

class AdminPassengerInfo {
  final String id;
  final String name;
  final String email;
  final String phone;
  final int totalRides;
  final double rating;
  final double totalSpent;
  final bool isActive;
  final bool isPremium;
  final DateTime joinedDate;
  final DateTime lastRideDate;
  final String? photoUrl;

  AdminPassengerInfo({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.totalRides,
    required this.rating,
    required this.totalSpent,
    required this.isActive,
    required this.isPremium,
    required this.joinedDate,
    required this.lastRideDate,
    this.photoUrl,
  });
}

class FilterOption {
  final String value;
  final String label;
  final IconData icon;

  FilterOption(this.value, this.label, this.icon);
}