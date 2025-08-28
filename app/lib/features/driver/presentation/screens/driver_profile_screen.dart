import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../shared/providers/riverpod_compat.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/oasis_button.dart';
import '../../../../shared/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/driver_status_provider.dart';
import '../widgets/driver_stats_widget.dart';
import '../widgets/vehicle_info_widget.dart';

class DriverProfileScreen extends ConsumerStatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  ConsumerState<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends ConsumerState<DriverProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _licensePlateController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  
  bool _isEditing = false;
  String? _selectedPhotoPath;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _licensePlateController.dispose();
    _vehicleModelController.dispose();
    _vehicleColorController.dispose();
    super.dispose();
  }

  void _initializeControllers(UserModel user) {
    _nameController.text = user.name;
    _phoneController.text = user.phone;
    _emailController.text = user.email;
    
    if (user.driverData != null) {
      _licensePlateController.text = user.driverData!.vehicleInfo.plate;
      _vehicleModelController.text = '${user.driverData!.vehicleInfo.brand} ${user.driverData!.vehicleInfo.model}';
      _vehicleColorController.text = user.driverData!.vehicleInfo.color;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final driverRating = ref.watch(driverRatingProvider);
    final totalTrips = ref.watch(totalTripsProvider);
    final todayEarnings = ref.watch(todayEarningsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text('Guardar'),
            ),
        ],
      ),
      body: currentUser == null 
        ? const Center(
            child: Text('Usuario no encontrado'),
          )
        : Builder(
            builder: (context) {
              final user = currentUser;

          // Inicializar controladores si no se ha hecho
          if (_nameController.text.isEmpty) {
            _initializeControllers(user);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Foto de perfil
                  _buildProfilePhoto(user),
                  
                  const SizedBox(height: 24),
                  
                  // Estadísticas del conductor
                  _buildDriverStats(driverRating, totalTrips, todayEarnings),
                  
                  const SizedBox(height: 24),
                  
                  // Información personal
                  _buildPersonalInfo(),
                  
                  const SizedBox(height: 24),
                  
                  // Información del vehículo
                  _buildVehicleInfo(user),
                  
                  const SizedBox(height: 24),
                  
                  // Documentos
                  _buildDocuments(),
                  
                  const SizedBox(height: 24),
                  
                  // Configuración
                  _buildSettings(),
                  
                  const SizedBox(height: 24),
                  
                  // Botón de cerrar sesión
                  _buildLogoutButton(),
                ],
              ),
            ),
          );
        }),
    );
  }

  Widget _buildProfilePhoto(UserModel user) {
    return GestureDetector(
      onTap: _isEditing ? _selectPhoto : null,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 60,
            // backgroundColor: Colors.grey[200],
            backgroundImage: user.photoUrl != null
                ? NetworkImage(user.photoUrl!)
                : null,
            child: user.photoUrl == null
                ? Icon(
                    Icons.person,
                    size: 60,
                    color: Colors.grey[400],
                  )
                : null,
          ),
          if (_isEditing)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn().scale();
  }

  Widget _buildDriverStats(
    AsyncValue<double> rating,
    AsyncValue<int> trips,
    AsyncValue<double> earnings,
  ) {
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
            'Estadísticas del conductor',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Calificación',
                rating.when(
                  data: (value) => value.toStringAsFixed(1),
                  loading: () => '...',
                  error: (_, __) => '0.0',
                ),
                Icons.star,
                Colors.amber[700]!,
              ),
              _buildStatItem(
                'Viajes',
                trips.when(
                  data: (value) => value.toString(),
                  loading: () => '...',
                  error: (_, __) => '0',
                ),
                Icons.directions_car,
                AppTheme.primaryColor,
              ),
              _buildStatItem(
                'Hoy',
                earnings.when(
                  data: (value) => 'S/ ${value.toStringAsFixed(0)}',
                  loading: () => '...',
                  error: (_, __) => 'S/ 0',
                ),
                Icons.monetization_on,
                AppTheme.earningsColor,
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.2, end: 0);
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Widget _buildPersonalInfo() {
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
            'Información personal',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          
          // Nombre
          TextFormField(
            controller: _nameController,
            enabled: _isEditing,
            decoration: const InputDecoration(
              labelText: 'Nombre completo',
              prefixIcon: Icon(Icons.person),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingresa tu nombre';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          // Teléfono
          TextFormField(
            controller: _phoneController,
            enabled: _isEditing,
            decoration: const InputDecoration(
              labelText: 'Teléfono',
              prefixIcon: Icon(Icons.phone),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingresa tu teléfono';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          // Email
          TextFormField(
            controller: _emailController,
            enabled: false, // Email no se puede editar
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              prefixIcon: Icon(Icons.email),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildVehicleInfo(UserModel user) {
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
            'Información del vehículo',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          
          // Placa
          TextFormField(
            controller: _licensePlateController,
            enabled: _isEditing,
            decoration: const InputDecoration(
              labelText: 'Placa del vehículo',
              prefixIcon: Icon(Icons.drive_eta),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingresa la placa';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          // Modelo
          TextFormField(
            controller: _vehicleModelController,
            enabled: _isEditing,
            decoration: const InputDecoration(
              labelText: 'Modelo del vehículo',
              prefixIcon: Icon(Icons.directions_car),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingresa el modelo';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          // Color
          TextFormField(
            controller: _vehicleColorController,
            enabled: _isEditing,
            decoration: const InputDecoration(
              labelText: 'Color del vehículo',
              prefixIcon: Icon(Icons.palette),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingresa el color';
              }
              return null;
            },
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildDocuments() {
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
            'Documentos',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          
          _buildDocumentItem(
            'Licencia de conducir',
            'Verificada',
            Icons.badge,
            AppTheme.successColor,
            true,
          ),
          
          const SizedBox(height: 12),
          
          _buildDocumentItem(
            'SOAT',
            'Vigente hasta Dic 2024',
            Icons.shield,
            AppTheme.successColor,
            true,
          ),
          
          const SizedBox(height: 12),
          
          _buildDocumentItem(
            'Revisión técnica',
            'Pendiente',
            Icons.build,
            AppTheme.warningColor,
            false,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildDocumentItem(
    String title,
    String status,
    IconData icon,
    Color color,
    bool isValid,
  ) {
    return Row(
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
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              Text(
                status,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color,
                    ),
              ),
            ],
          ),
        ),
        Icon(
          isValid ? Icons.check_circle : Icons.warning,
          color: color,
          size: 20,
        ),
      ],
    );
  }

  Widget _buildSettings() {
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
            'Configuración',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          
          _buildSettingItem(
            'Notificaciones',
            'Recibir alertas de nuevos viajes',
            Icons.notifications,
            () {},
          ),
          
          const Divider(),
          
          _buildSettingItem(
            'Privacidad',
            'Configurar datos personales',
            Icons.privacy_tip,
            () {},
          ),
          
          const Divider(),
          
          _buildSettingItem(
            'Soporte',
            'Ayuda y contacto',
            Icons.help,
            () {},
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildSettingItem(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: AppTheme.primaryColor,
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton() {
    return OasisButton(
      isOutlined: true,
      text: 'Cerrar sesión',
      onPressed: () => _showLogoutDialog(),
      // textColor: AppTheme.errorColor,
      // borderColor: AppTheme.errorColor,
      // icon removed,
    ).animate().fadeIn(delay: 500.ms);
  }

  Future<void> _selectPhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        _selectedPhotoPath = image.path;
      });
    }
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      // TODO: Guardar perfil en Firebase
      setState(() {
        _isEditing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil actualizado correctamente'),
          // backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(authRepositoryProvider).signOut();
            },
            child: Text(
              'Cerrar sesión',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );
  }
}