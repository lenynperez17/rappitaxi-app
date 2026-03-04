// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/modern_theme.dart';
import '../../widgets/common/rappi_app_bar.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  _UsersManagementScreenState createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedFilter = 'Todos';
  List<User> _users = [];
  List<User> _filteredUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // ✅ CORREGIDO: Usar addPostFrameCallback para cargar después del primer frame
    // Esto garantiza que el widget tree esté completamente construido
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsersFromFirebase();
    });
  }

  @override
  void dispose() {
    // ✅ Liberar el TextEditingController para prevenir memory leak
    _searchController.dispose();
    super.dispose();
  }

  // Cargar usuarios reales desde Firebase
  Future<void> _loadUsersFromFirebase() async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (!mounted) return;
      setState(() => _isLoading = true);

      debugPrint('👥 Cargando usuarios desde Firebase...');

      // Obtener usuarios desde Firebase
      final QuerySnapshot snapshot = await _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get()
          .catchError((e) {
        debugPrint('❌ Error en query de usuarios: $e');
        throw e;
      });

      debugPrint('✅ Usuarios obtenidos: ${snapshot.docs.length}');

      final List<User> loadedUsers = [];

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) {
            debugPrint('⚠️ Usuario ${doc.id} sin datos');
            continue;
          }

          // Usar campos correctos de Firestore
          final userType = data['userType'] ?? data['role'] ?? 'passenger';
          final fullName = data['fullName'] ?? data['name'] ?? 'Sin nombre';
          final isDriver = userType == 'driver' ||
                           (data['availableRoles'] as List?)?.contains('driver') == true;

          // Calcular número de viajes del usuario
          int tripCount = data['totalTrips'] ?? 0;
          double avgRating = (data['rating'] ?? 0.0).toDouble();

          // Si no tiene totalTrips en el modelo, intentar contarlos (opcional)
          if (tripCount == 0) {
            try {
              final tripsSnapshot = await _firestore
                  .collection('rides')
                  .where(isDriver ? 'driverId' : 'passengerId', isEqualTo: doc.id)
                  .where('status', isEqualTo: 'completed')
                  .limit(1)
                  .get()
                  .timeout(Duration(seconds: 2));
              tripCount = tripsSnapshot.size;
            } catch (e) {
              debugPrint('⚠️ No se pudo contar trips para ${doc.id}: $e');
            }
          }

          // Determinar tipo de usuario para mostrar
          String displayType = 'Pasajero';
          if (userType == 'admin') {
            displayType = 'Admin';
          } else if (isDriver) {
            displayType = 'Conductor';
          }

          // Determinar estado
          String status = 'Inactivo';
          if (data['isActive'] == true) {
            status = 'Activo';
          } else if (data['isSuspended'] == true || data['disabled'] == true) {
            status = 'Suspendido';
          }

          loadedUsers.add(User(
            id: doc.id,
            name: fullName,
            email: data['email'] ?? '',
            phone: data['phone'] ?? data['phoneNumber'] ?? '',
            type: displayType,
            status: status,
            registrationDate: (data['createdAt'] as Timestamp?)?.toDate() ??
                             DateTime.now(),
            lastLogin: (data['lastLogin'] as Timestamp?)?.toDate() ??
                      DateTime.now(),
            trips: tripCount,
            rating: avgRating,
          ));

          debugPrint('✅ Usuario procesado: $fullName ($displayType)');
        } catch (e) {
          debugPrint('⚠️ Error procesando usuario ${doc.id}: $e');
          continue;
        }
      }

      debugPrint('✅ Total usuarios procesados: ${loadedUsers.length}');

      if (!mounted) return;
      setState(() {
        _users = loadedUsers;
        _filteredUsers = loadedUsers;
        _isLoading = false;
      });

    } catch (e, stackTrace) {
      debugPrint('❌ Error crítico cargando usuarios: $e');
      debugPrint('📍 Stack: $stackTrace');

      if (!mounted) return;
      setState(() => _isLoading = false);

      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al cargar usuarios: ${e.toString()}'),
          backgroundColor: ModernTheme.error,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  void _filterUsers(String query) {
    // ✅ CORREGIDO: Verificar mounted antes de setState
    if (!mounted) return;
    setState(() {
      _filteredUsers = _users.where((user) {
        final matchesSearch = user.name.toLowerCase().contains(query.toLowerCase()) ||
            user.email.toLowerCase().contains(query.toLowerCase()) ||
            user.phone.contains(query);

        final matchesFilter = _selectedFilter == 'Todos' ||
            (_selectedFilter == 'Activos' && user.status == 'Activo') ||
            (_selectedFilter == 'Suspendidos' && user.status == 'Suspendido') ||
            (_selectedFilter == 'Inactivos' && user.status == 'Inactivo') ||
            (_selectedFilter == 'Pasajeros' && user.type == 'Pasajero') ||
            (_selectedFilter == 'Conductores' && user.type == 'Conductor');

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: RappiAppBar(
        title: 'Gestión de Usuarios',
        showBackButton: true,
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: ModernTheme.textLight),
            onPressed: _showAddUserDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Sticky search bar + filters with shadow
          Material(
            elevation: 3,
            shadowColor: Colors.black.withValues(alpha: 0.1),
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Campo de búsqueda moderno
                  Container(
                    decoration: BoxDecoration(
                      color: ModernTheme.backgroundLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: ModernTheme.rappiOrange.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre, email o telefono...',
                        hintStyle: TextStyle(color: ModernTheme.textSecondary, fontSize: 14),
                        prefixIcon: Icon(Icons.search, color: ModernTheme.rappiOrange, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, size: 18, color: ModernTheme.textSecondary),
                                onPressed: () {
                                  _searchController.clear();
                                  _filterUsers('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onChanged: _filterUsers,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Chips de filtros horizontales
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('Todos'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Activos'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Suspendidos'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Inactivos'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Pasajeros'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Conductores'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Estadísticas
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatCard('Total', _users.length.toString(), Icons.people, ModernTheme.primaryBlue),
                _buildStatCard('Activos', _users.where((u) => u.status == 'Activo').length.toString(), Icons.check_circle, ModernTheme.success),
                _buildStatCard('Suspendidos', _users.where((u) => u.status == 'Suspendido').length.toString(), Icons.warning, ModernTheme.warning),
                _buildStatCard('Inactivos', _users.where((u) => u.status == 'Inactivo').length.toString(), Icons.cancel, ModernTheme.textSecondary),
              ],
            ),
          ),
          
          // Lista de usuarios con indicador de carga
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(ModernTheme.rappiOrange),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Cargando usuarios desde Firebase...',
                          style: TextStyle(color: ModernTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_off,
                              size: 64,
                              color: ModernTheme.textSecondary.withValues(alpha: 0.5),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No se encontraron usuarios',
                              style: TextStyle(
                                color: ModernTheme.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _loadUsersFromFirebase,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ModernTheme.rappiOrange,
                              ),
                              child: Text('Recargar'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadUsersFromFirebase,
                        color: ModernTheme.rappiOrange,
                        child: ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = _filteredUsers[index];
                            return _buildUserCard(user);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = isSelected ? 'Todos' : label;
        });
        _filterUsers(_searchController.text);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? ModernTheme.rappiOrange : ModernTheme.backgroundLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? ModernTheme.rappiOrange : ModernTheme.textSecondary.withValues(alpha: 0.3),
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : ModernTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: ModernTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(User user) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showUserDetails(user),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 30,
                backgroundColor: _getUserTypeColor(user.type).withValues(alpha: 0.2),
                child: Icon(
                  user.type == 'Conductor' ? Icons.directions_car : Icons.person,
                  color: _getUserTypeColor(user.type),
                ),
              ),
              SizedBox(width: 16),
              
              // Información del usuario
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getUserTypeColor(user.type).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            user.type,
                            style: TextStyle(
                              fontSize: 12,
                              color: _getUserTypeColor(user.type),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      user.email,
                      style: TextStyle(
                        color: ModernTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    // ✅ FIX: Usar Wrap para evitar overflow con datos largos
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.phone, size: 14, color: ModernTheme.textSecondary),
                            SizedBox(width: 4),
                            Text(
                              user.phone,
                              style: TextStyle(
                                color: ModernTheme.textSecondary,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 14, color: ModernTheme.accentYellow),
                            SizedBox(width: 4),
                            Text(
                              user.rating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.route, size: 14, color: ModernTheme.textSecondary),
                            SizedBox(width: 4),
                            Text(
                              '${user.trips}',
                              style: TextStyle(
                                color: ModernTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Estado y acciones
              Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(user.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      user.status,
                      style: TextStyle(
                        color: _getStatusColor(user.status),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: ModernTheme.textSecondary),
                    onSelected: (value) => _handleUserAction(user, value),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility, size: 20),
                            SizedBox(width: 8),
                            Text('Ver detalles'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Editar'),
                          ],
                        ),
                      ),
                      if (user.status == 'Activo')
                        PopupMenuItem(
                          value: 'suspend',
                          child: Row(
                            children: [
                              Icon(Icons.block, size: 20, color: ModernTheme.warning),
                              SizedBox(width: 8),
                              Text('Suspender'),
                            ],
                          ),
                        ),
                      if (user.status == 'Suspendido')
                        PopupMenuItem(
                          value: 'activate',
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, size: 20, color: ModernTheme.success),
                              SizedBox(width: 8),
                              Text('Activar'),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: ModernTheme.error),
                            SizedBox(width: 8),
                            Text('Eliminar'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getUserTypeColor(String type) {
    switch (type) {
      case 'Conductor':
        return ModernTheme.primaryBlue;
      case 'Pasajero':
        return ModernTheme.primaryOrange;
      default:
        return ModernTheme.textSecondary;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Activo':
        return ModernTheme.success;
      case 'Suspendido':
        return ModernTheme.warning;
      case 'Inactivo':
        return ModernTheme.textSecondary;
      default:
        return ModernTheme.textSecondary;
    }
  }

  void _handleUserAction(User user, String action) {
    switch (action) {
      case 'view':
        _showUserDetails(user);
        break;
      case 'edit':
        _showEditUserDialog(user);
        break;
      case 'suspend':
        _confirmSuspendUser(user);
        break;
      case 'activate':
        _confirmActivateUser(user);
        break;
      case 'delete':
        _confirmDeleteUser(user);
        break;
    }
  }

  void _showUserDetails(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: _getUserTypeColor(user.type).withValues(alpha: 0.2),
              child: Icon(
                user.type == 'Conductor' ? Icons.directions_car : Icons.person,
                color: _getUserTypeColor(user.type),
              ),
            ),
            SizedBox(width: 12),
            Text(user.name),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Email', user.email, Icons.email),
              _buildDetailRow('Teléfono', user.phone, Icons.phone),
              _buildDetailRow('Tipo', user.type, Icons.person),
              _buildDetailRow('Estado', user.status, Icons.info),
              _buildDetailRow('Registro', _formatDate(user.registrationDate), Icons.calendar_today),
              _buildDetailRow('Último acceso', _formatDate(user.lastLogin), Icons.access_time),
              _buildDetailRow('Viajes', user.trips.toString(), Icons.route),
              _buildDetailRow('Calificación', '${user.rating} ⭐', Icons.star),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showEditUserDialog(user);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.rappiOrange,
            ),
            child: Text('Editar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: ModernTheme.textSecondary),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: ModernTheme.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ IMPLEMENTADO: Agregar nuevo usuario
  void _showAddUserDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    String selectedRole = 'Pasajero';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.person_add, color: ModernTheme.rappiOrange),
              SizedBox(width: 12),
              Text('Agregar Usuario'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nombre completo',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: 'Teléfono',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: InputDecoration(
                    labelText: 'Tipo de usuario',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.work),
                  ),
                  items: ['Pasajero', 'Conductor'].map((String role) {
                    return DropdownMenuItem<String>(
                      value: role,
                      child: Text(role),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setDialogState(() {
                      selectedRole = newValue!;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final email = emailController.text.trim();
                final phone = phoneController.text.trim();
                final password = passwordController.text.trim();
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);

                if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Por favor completa todos los campos'),
                      backgroundColor: ModernTheme.error,
                    ),
                  );
                  return;
                }

                if (password.length < 6) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('La contraseña debe tener al menos 6 caracteres'),
                      backgroundColor: ModernTheme.error,
                    ),
                  );
                  return;
                }

                navigator.pop();

                try {
                  final newUserRef = _firestore.collection('users').doc();
                  await newUserRef.set({
                    'id': newUserRef.id,
                    'name': name,
                    'fullName': name,
                    'email': email,
                    'phone': phone,
                    'role': selectedRole == 'Conductor' ? 'driver' : 'passenger',
                    'userType': selectedRole == 'Conductor' ? 'driver' : 'passenger',
                    'isActive': true,
                    'isSuspended': false,
                    'isVerified': false,
                    'emailVerified': false,
                    'phoneVerified': false,
                    'createdAt': FieldValue.serverTimestamp(),
                    'lastLogin': FieldValue.serverTimestamp(),
                    'rating': 5.0,
                    'totalTrips': 0,
                  });

                  if (!mounted) return;

                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Usuario agregado exitosamente'),
                      backgroundColor: ModernTheme.success,
                    ),
                  );

                  _loadUsersFromFirebase();
                } catch (e) {
                  if (!mounted) return;

                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error al agregar usuario: $e'),
                      backgroundColor: ModernTheme.error,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: ModernTheme.rappiOrange),
              child: Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ IMPLEMENTADO: Editar usuario existente
  void _showEditUserDialog(User user) {
    final TextEditingController nameController = TextEditingController(text: user.name);
    final TextEditingController emailController = TextEditingController(text: user.email);
    final TextEditingController phoneController = TextEditingController(text: user.phone);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.edit, color: ModernTheme.rappiOrange),
            SizedBox(width: 12),
            Text('Editar Usuario'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nombre completo',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: 'Teléfono',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final email = emailController.text.trim();
              final phone = phoneController.text.trim();
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);

              if (name.isEmpty || email.isEmpty || phone.isEmpty) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Por favor completa todos los campos'),
                    backgroundColor: ModernTheme.error,
                  ),
                );
                return;
              }

              navigator.pop();

              try {
                await _firestore.collection('users').doc(user.id).update({
                  'name': name,
                  'fullName': name,
                  'email': email,
                  'phone': phone,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                if (!mounted) return;

                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Usuario actualizado exitosamente'),
                    backgroundColor: ModernTheme.success,
                  ),
                );

                _loadUsersFromFirebase();
              } catch (e) {
                if (!mounted) return;

                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Error al actualizar usuario: $e'),
                    backgroundColor: ModernTheme.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: ModernTheme.rappiOrange),
            child: Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _confirmSuspendUser(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Suspender Usuario'),
        content: Text('¿Está seguro de suspender a ${user.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              navigator.pop();

              // Actualizar en Firebase
              try {
                await _firestore.collection('users').doc(user.id).update({
                  'isActive': false,
                  'isSuspended': true,
                  'suspendedAt': FieldValue.serverTimestamp(),
                });

                if (!mounted) return;

                setState(() {
                  user.status = 'Suspendido';
                });

                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Usuario suspendido correctamente'),
                    backgroundColor: ModernTheme.warning,
                  ),
                );

                // Recargar usuarios
                _loadUsersFromFirebase();
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Error al suspender usuario: $e'),
                    backgroundColor: ModernTheme.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.warning,
            ),
            child: Text('Suspender'),
          ),
        ],
      ),
    );
  }

  void _confirmActivateUser(User user) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Actualizar en Firebase
      await _firestore.collection('users').doc(user.id).update({
        'isActive': true,
        'isSuspended': false,
        'activatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        user.status = 'Activo';
      });

      messenger.showSnackBar(
        SnackBar(
          content: Text('Usuario activado correctamente'),
          backgroundColor: ModernTheme.success,
        ),
      );

      // Recargar usuarios
      _loadUsersFromFirebase();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al activar usuario: $e'),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  void _confirmDeleteUser(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar Usuario'),
        content: Text('¿Está seguro de eliminar a ${user.name}? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              navigator.pop();

              try {
                // Eliminar de Firebase
                await _firestore.collection('users').doc(user.id).delete();

                if (!mounted) return;

                // También eliminar sus viajes asociados (opcional, depende de la lógica de negocio)
                // final ridesSnapshot = await _firestore
                //     .collection('rides')
                //     .where(user.role == 'driver' ? 'driverId' : 'passengerId', isEqualTo: user.id)
                //     .get();
                //
                // for (var doc in ridesSnapshot.docs) {
                //   await doc.reference.delete();
                // }

                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Usuario eliminado correctamente'),
                    backgroundColor: ModernTheme.error,
                  ),
                );

                // Recargar usuarios
                _loadUsersFromFirebase();
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Error al eliminar usuario: $e'),
                    backgroundColor: ModernTheme.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.error,
            ),
            child: Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours} horas';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String type;
  String status;
  final DateTime registrationDate;
  final DateTime lastLogin;
  final int trips;
  final double rating;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.type,
    required this.status,
    required this.registrationDate,
    required this.lastLogin,
    required this.trips,
    required this.rating,
  });
}