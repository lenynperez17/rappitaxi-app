import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/design/design_system.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_button.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../utils/firestore_error_handler.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
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

      if (!mounted) return;
      RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
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
      backgroundColor: RtColors.neutral50,
      appBar: RtAppBar(
        title: 'Gestión de Usuarios',
        variant: RtAppBarVariant.gradient,
        showBackButton: true,
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: RtColors.white),
            onPressed: _showAddUserDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda y filtros
          Container(
            padding: EdgeInsets.all(16),
            color: RtColors.white,
            child: Column(
              children: [
                // Campo de búsqueda
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar usuario...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: RtColors.neutral50,
                  ),
                  onChanged: _filterUsers,
                ),
                SizedBox(height: 16),
                // Chips de filtros
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Todos'),
                      SizedBox(width: 8),
                      _buildFilterChip('Activos'),
                      SizedBox(width: 8),
                      _buildFilterChip('Suspendidos'),
                      SizedBox(width: 8),
                      _buildFilterChip('Inactivos'),
                      SizedBox(width: 8),
                      _buildFilterChip('Pasajeros'),
                      SizedBox(width: 8),
                      _buildFilterChip('Conductores'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Estadísticas
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatCard('Total', _users.length.toString(), Icons.people, RtColors.info),
                _buildStatCard('Activos', _users.where((u) => u.status == 'Activo').length.toString(), Icons.check_circle, RtColors.success),
                _buildStatCard('Suspendidos', _users.where((u) => u.status == 'Suspendido').length.toString(), Icons.warning, RtColors.warning),
                _buildStatCard('Inactivos', _users.where((u) => u.status == 'Inactivo').length.toString(), Icons.cancel, RtColors.neutral500),
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
                          valueColor: AlwaysStoppedAnimation<Color>(RtColors.brand),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Cargando usuarios desde Firebase...',
                          style: TextStyle(color: RtColors.neutral500),
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
                              color: RtColors.neutral500.withValues(alpha: 0.5),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No se encontraron usuarios',
                              style: TextStyle(
                                color: RtColors.neutral500,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 8),
                            RtButton(
                              label: 'Recargar',
                              onPressed: _loadUsersFromFirebase,
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadUsersFromFirebase,
                        color: RtColors.brand,
                        backgroundColor: Theme.of(context).colorScheme.surface,
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
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? label : 'Todos';
        });
        _filterUsers(_searchController.text);
      },
      selectedColor: RtColors.brand.withValues(alpha: 0.2),
      checkmarkColor: RtColors.brand,
      labelStyle: TextStyle(
        color: isSelected ? RtColors.brand : RtColors.neutral500,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
              color: RtColors.neutral500,
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
                        color: RtColors.neutral500,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.phone, size: 14, color: RtColors.neutral500),
                        SizedBox(width: 4),
                        Text(
                          user.phone,
                          style: TextStyle(
                            color: RtColors.neutral500,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(width: 16),
                        Icon(Icons.star, size: 14, color: RtColors.accentAmber),
                        SizedBox(width: 4),
                        Text(
                          user.rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 16),
                        Icon(Icons.route, size: 14, color: RtColors.neutral500),
                        SizedBox(width: 4),
                        Text(
                          '${user.trips} viajes',
                          style: TextStyle(
                            color: RtColors.neutral500,
                            fontSize: 12,
                          ),
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
                    icon: Icon(Icons.more_vert, color: RtColors.neutral500),
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
                              Icon(Icons.block, size: 20, color: RtColors.warning),
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
                              Icon(Icons.check_circle, size: 20, color: RtColors.success),
                              SizedBox(width: 8),
                              Text('Activar'),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: RtColors.error),
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
        return RtColors.info;
      case 'Pasajero':
        return RtColors.warning;
      default:
        return RtColors.neutral500;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Activo':
        return RtColors.success;
      case 'Suspendido':
        return RtColors.warning;
      case 'Inactivo':
        return RtColors.neutral500;
      default:
        return RtColors.neutral500;
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
              backgroundColor: RtColors.brand,
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
          Icon(icon, size: 20, color: RtColors.neutral500),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: RtColors.neutral500,
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
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext2, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.person_add, color: RtColors.brand),
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
                  initialValue: selectedRole,
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
              onPressed: () => Navigator.pop(dialogContext2),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final email = emailController.text.trim();
                final phone = phoneController.text.trim();
                final password = passwordController.text.trim();

                if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
                  RtSnackbar.show(dialogContext2, message: 'Por favor completa todos los campos', type: RtSnackbarType.error);
                  return;
                }

                if (password.length < 6) {
                  RtSnackbar.show(dialogContext2, message: 'La contraseña debe tener al menos 6 caracteres', type: RtSnackbarType.error);
                  return;
                }

                Navigator.pop(dialogContext2);

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
                  RtSnackbar.show(context, message: 'Usuario agregado exitosamente', type: RtSnackbarType.success);

                  _loadUsersFromFirebase();
                } catch (e) {
                  if (!mounted) return;
                  RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: RtColors.brand),
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
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.edit, color: RtColors.brand),
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
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final email = emailController.text.trim();
              final phone = phoneController.text.trim();

              if (name.isEmpty || email.isEmpty || phone.isEmpty) {
                RtSnackbar.show(dialogContext, message: 'Por favor completa todos los campos', type: RtSnackbarType.error);
                return;
              }

              Navigator.pop(dialogContext);

              try {
                await _firestore.collection('users').doc(user.id).update({
                  'name': name,
                  'fullName': name,
                  'email': email,
                  'phone': phone,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                if (!mounted) return;
                RtSnackbar.show(context, message: 'Usuario actualizado exitosamente', type: RtSnackbarType.success);

                _loadUsersFromFirebase();
              } catch (e) {
                if (!mounted) return;
                RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: RtColors.brand),
            child: Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _confirmSuspendUser(User user) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Suspender Usuario'),
        content: Text('¿Está seguro de suspender a ${user.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

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

                RtSnackbar.show(context, message: 'Usuario suspendido correctamente', type: RtSnackbarType.warning);

                // Recargar usuarios
                _loadUsersFromFirebase();
              } catch (e) {
                if (!mounted) return;
                RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: RtColors.warning,
            ),
            child: Text('Suspender'),
          ),
        ],
      ),
    );
  }

  void _confirmActivateUser(User user) async {
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

      RtSnackbar.show(context, message: 'Usuario activado correctamente', type: RtSnackbarType.success);

      // Recargar usuarios
      _loadUsersFromFirebase();
    } catch (e) {
      if (!mounted) return;
      RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
    }
  }

  void _confirmDeleteUser(User user) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Eliminar Usuario'),
        content: Text('¿Está seguro de eliminar a ${user.name}? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

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

                RtSnackbar.show(context, message: 'Usuario eliminado correctamente', type: RtSnackbarType.success);

                // Recargar usuarios
                _loadUsersFromFirebase();
              } catch (e) {
                if (!mounted) return;
                RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: RtColors.error,
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