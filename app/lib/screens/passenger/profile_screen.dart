// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:convert'; // ✅ Para exportar datos en JSON
import 'package:image_picker/image_picker.dart'; // ✅ Para seleccionar fotos
import 'package:path_provider/path_provider.dart'; // ✅ Para obtener directorios del sistema
import 'package:permission_handler/permission_handler.dart'; // ✅ Para abrir configuración de permisos
import 'package:firebase_storage/firebase_storage.dart'; // ✅ Para subir fotos a Firebase Storage
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Para actualizar Firestore
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart'; // ✅ Extensión para colores que se adaptan al tema
import '../../widgets/animated/modern_animated_widgets.dart';
import '../../providers/auth_provider.dart';
import '../../utils/logger.dart';
import '../../providers/locale_provider.dart'; // ✅ NUEVO: Para cambio de idioma
import '../../generated/l10n/app_localizations.dart'; // ✅ NUEVO: Textos localizados
import '../auth/email_verification_screen.dart'; // Verificación de email nativa de Firebase
// import '../../providers/ride_provider.dart'; // Se usará para estadísticas reales

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerController;
  late AnimationController _statsController;
  late AnimationController _settingsController;
  late TabController _tabController;
  
  // Controllers para edición
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthDateController = TextEditingController();
  
  bool _isEditing = false;
  File? _imageFile;
  
  // Preferencias
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _promotionsEnabled = false;
  bool _newsEnabled = false;
  String _defaultPayment = 'cash';
  // ✅ ELIMINADO: _language ya no se usa, ahora se maneja con LocaleProvider

  // Estadísticas del usuario (se cargan de Firebase)
  Map<String, dynamic> _userStats = {
    'totalTrips': 0,
    'totalSpent': 0.0,
    'totalDistance': 0.0,
    'savedPlaces': 0,
    'referrals': 0,
    'memberSince': DateTime.now(),
    'rating': 0.0,
    'level': 'Bronze',
    'points': 0,
  };
  
  bool _isLoadingProfile = true;
  
  @override
  void initState() {
    super.initState();
    
    _headerController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    
    _statsController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    )..forward();
    
    _settingsController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    )..forward();
    
    _tabController = TabController(length: 3, vsync: this);
    
    // Cargar datos del usuario
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserProfile();
    });
  }

  // Cargar perfil del usuario desde Firebase
  Future<void> _loadUserProfile() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      // final rideProvider = Provider.of<RideProvider>(context, listen: false); // Se usará para estadísticas reales
      final user = authProvider.currentUser;
      
      if (user != null) {
        // Cargar datos básicos del usuario
        _nameController.text = user.fullName;
        _emailController.text = user.email;
        _phoneController.text = user.phone;
        // ✅ NUEVO: Cargar birthDate si existe
        _birthDateController.text = user.birthDate ?? '';

        // Cargar estadísticas del usuario (simuladas por ahora)
        final userStats = {
          'totalTrips': user.totalTrips,
          'totalSpent': user.balance,
          'totalDistance': 0.0,
          'savedPlaces': 0,
          'referrals': 0,
          'memberSince': user.createdAt,
          'rating': user.rating,
          'level': _getUserLevel(user.totalTrips),
          'points': user.totalTrips * 10,
        };

        setState(() {
          _userStats = userStats;
          _isLoadingProfile = false;
        });
      } else {
        // Usuario no disponible aún, desactivar loading para no quedar en spinner infinito
        setState(() {
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando perfil: $e');
      setState(() {
        _isLoadingProfile = false;
      });
    }
  }
  
  // Obtener nivel del usuario basado en viajes
  String _getUserLevel(int totalTrips) {
    if (totalTrips >= 100) return 'Platinum';
    if (totalTrips >= 50) return 'Gold';
    if (totalTrips >= 20) return 'Silver';
    return 'Bronze';
  }
  
  @override
  void dispose() {
    _headerController.dispose();
    _statsController.dispose();
    _settingsController.dispose();
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }
  
  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        // Guardar cambios
        _saveProfile();
      }
    });
  }
  
  /// ✅ IMPLEMENTADO: Guardar perfil REAL en Firestore
  Future<void> _saveProfile() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        _showError('No hay usuario autenticado');
        return;
      }

      // Mostrar loading
      _showLoadingSnackBar('Guardando cambios...');

      // Preparar datos a actualizar
      final updates = <String, dynamic>{
        'fullName': _nameController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // ✅ NUEVO: Agregar birthDate si tiene valor
      if (_birthDateController.text.isNotEmpty) {
        updates['birthDate'] = _birthDateController.text.trim();
      }

      // Actualizar en Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.id) // ✅ CORREGIDO: usar .id en lugar de .uid
          .update(updates);

      // ✅ NOTA: No necesitamos recargar manualmente - Consumer<AuthProvider> se actualizará automáticamente

      if (!mounted) return;

      // Ocultar loading y mostrar éxito
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showSuccessSnackBar(AppLocalizations.of(context)!.profileUpdated);

      // Salir del modo edición
      setState(() => _isEditing = false);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showError('Error al guardar perfil: $e');
    }
  }

  /// Mostrar SnackBar de loading
  void _showLoadingSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary),
              ),
            ),
            SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: ModernTheme.rappiOrange,
        behavior: SnackBarBehavior.floating,
        duration: Duration(hours: 1), // Durará hasta que se oculte manualmente
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// Mostrar SnackBar de éxito
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onPrimary),
            SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: ModernTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// Mostrar SnackBar de error
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onPrimary),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: ModernTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// Navegar a verificación de email usando Firebase nativo (envía link por email)
  Future<void> _navigateToEmailVerification(AuthProvider authProvider) async {
    final user = authProvider.currentUser;
    if (user == null) {
      _showError('No hay usuario autenticado');
      return;
    }

    if (user.email.isEmpty) {
      _showError('No tienes email registrado');
      return;
    }

    // Navegar a la pantalla nativa de verificación de email de Firebase
    // Esta pantalla envía un LINK al email del usuario (gratis, sin SMTP)
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => EmailVerificationScreen(
          email: user.email,
        ),
      ),
    );

    // Si el usuario verificó su email, recargar datos
    if (result == true && mounted) {
      await authProvider.refreshUserData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Email verificado exitosamente'),
          backgroundColor: ModernTheme.success,
        ),
      );
    }
  }

  /// ✅ NUEVO: Navegar a verificación de teléfono
  void _navigateToPhoneVerification() {
    // Navegar a la pantalla de verificación de teléfono existente
    Navigator.of(context).pushNamed('/phone-verification');
  }

  /// ✅ IMPLEMENTADO: Seleccionar foto de perfil desde cámara o galería
  Future<void> _pickImage() async {
    try {
      // Mostrar diálogo para elegir fuente
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  AppLocalizations.of(context)!.changeProfilePhoto,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: ModernTheme.rappiOrange),
                  title: Text(AppLocalizations.of(context)!.takePhoto),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: ModernTheme.rappiOrange),
                  title: Text(AppLocalizations.of(context)!.chooseFromGallery),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                if (_imageFile != null)
                  ListTile(
                    leading: const Icon(Icons.delete, color: ModernTheme.error),
                    title: Text(AppLocalizations.of(context)!.deletePhoto),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _imageFile = null;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context)!.profilePhotoDeleted),
                          backgroundColor: ModernTheme.info,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      );

      if (source == null) return;

      // Solo pedir permiso de CÁMARA si se usa la cámara
      // Para GALERÍA: Android 13+ usa Photo Picker que NO requiere permisos
      // Photo Picker es una actividad del sistema que maneja los permisos internamente
      if (source == ImageSource.camera) {
        final permissionStatus = await Permission.camera.request();
        if (!permissionStatus.isGranted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.permissionsNeeded),
              backgroundColor: ModernTheme.error,
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: AppLocalizations.of(context)!.openSettings,
                textColor: Theme.of(context).colorScheme.onPrimary,
                onPressed: () => openAppSettings(),
              ),
            ),
          );
          return;
        }
      }
      // NOTA: Para galería NO pedimos permisos - image_picker usa Photo Picker en Android 13+

      // Seleccionar imagen
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 90,
      );

      if (image == null) return;

      // Actualizar estado con la nueva foto
      if (!mounted) return;
      setState(() {
        _imageFile = File(image.path);
      });

      // ✅ IMPLEMENTADO: Subir foto a Firebase Storage y actualizar Firestore
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final userId = authProvider.currentUser?.id;

        if (userId != null && _imageFile != null) {
          // Mostrar indicador de carga
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Subiendo foto...'),
                ],
              ),
              backgroundColor: ModernTheme.info,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 30),
            ),
          );

          AppLogger.debug('🚕 RappiTeam [DEBUG] Subiendo foto de perfil a Firebase Storage...');
          // Crear referencia única con timestamp
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final storage = FirebaseStorage.instance;
          final profilePhotoRef = storage.ref('profile_photos/$userId/profile_$timestamp.jpg');

          // Subir con metadata
          final metadata = SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {
              'uploadedBy': userId,
              'type': 'profile_photo',
            },
          );

          final uploadTask = await profilePhotoRef.putFile(_imageFile!, metadata);
          final profileImageUrl = await uploadTask.ref.getDownloadURL();

          AppLogger.debug('🚕 RappiTeam [INFO] ✅ Foto de perfil subida exitosamente: $profileImageUrl');
          // Actualizar Firestore con la URL de la foto
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({
            'profilePhotoUrl': profileImageUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          AppLogger.debug('🚕 RappiTeam [INFO] ✅ Firestore actualizado con nueva foto de perfil');
          // Actualizar AuthProvider para reflejar el cambio en la UI
          await authProvider.updateProfile({'profilePhotoUrl': profileImageUrl});

          // Mostrar confirmación de éxito
          if (!mounted) return;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onPrimary, size: 20),
                  const SizedBox(width: 12),
                  Text(AppLocalizations.of(context)!.profilePhotoUpdated),
                ],
              ),
              backgroundColor: ModernTheme.rappiOrange,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          AppLogger.warning('🚕 RappiTeam [WARNING] No se pudo subir foto: userId o _imageFile es null');
        }
      } catch (uploadError) {
        AppLogger.error('🚕 RappiTeam [ERROR] Error subiendo foto de perfil: $uploadError');
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir foto: ${uploadError.toString()}'),
            backgroundColor: ModernTheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error seleccionando imagen: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.of(context)!.errorSelectingImage}: $e'),
          backgroundColor: ModernTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceColor,
      body: _isLoadingProfile 
        ? Center(
            child: CircularProgressIndicator(
              color: ModernTheme.rappiOrange,
            ),
          )
        : CustomScrollView(
        slivers: [
          // AppBar animado con foto de perfil
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: ModernTheme.rappiOrange,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _isEditing ? Icons.check : Icons.edit,
                  color: Theme.of(context).colorScheme.surface,
                ),
                onPressed: _toggleEdit,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: AnimatedBuilder(
                animation: _headerController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: ModernTheme.primaryGradient,
                    ),
                    child: Stack(
                      children: [
                        // Patrón de fondo
                        Positioned.fill(
                          child: CustomPaint(
                            painter: ProfileBackgroundPainter(
                              animation: _headerController,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                        // Contenido del perfil
                        Center(
                          child: Transform.scale(
                            scale: 0.8 + (0.2 * _headerController.value),
                            child: Opacity(
                              opacity: _headerController.value,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(height: 60),
                                  // Foto de perfil
                                  Stack(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Theme.of(context).colorScheme.surface,
                                            width: 3,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.26),
                                              blurRadius: 20,
                                              offset: Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: Consumer<AuthProvider>(
                                          builder: (context, authProvider, _) {
                                            final profilePhotoUrl = authProvider.currentUser?.profilePhotoUrl;

                                            // ✅ Prioridad: 1) Archivo local recién seleccionado, 2) URL de Firestore, 3) Icono por defecto
                                            ImageProvider? backgroundImage;
                                            Widget? child;

                                            if (_imageFile != null) {
                                              // Usuario acaba de seleccionar una foto nueva
                                              backgroundImage = FileImage(_imageFile!);
                                              child = null;
                                            } else if (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty) {
                                              // Cargar foto desde Firestore
                                              backgroundImage = NetworkImage(profilePhotoUrl);
                                              child = null;
                                            } else {
                                              // No hay foto, mostrar icono por defecto
                                              backgroundImage = null;
                                              child = Icon(
                                                Icons.person,
                                                size: 60,
                                                color: ModernTheme.rappiOrange,
                                              );
                                            }

                                            return CircleAvatar(
                                              radius: 60,
                                              backgroundColor: Theme.of(context).colorScheme.surface,
                                              backgroundImage: backgroundImage,
                                              child: child,
                                            );
                                          },
                                        ),
                                      ),
                                      if (_isEditing)
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.surface,
                                              shape: BoxShape.circle,
                                              boxShadow: ModernTheme.getCardShadow(context),
                                            ),
                                            child: IconButton(
                                              icon: Icon(
                                                Icons.camera_alt,
                                                color: ModernTheme.rappiOrange,
                                              ),
                                              onPressed: _pickImage,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: 16),
                                  // Nombre y nivel
                                  Text(
                                    _nameController.text,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.surface,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ModernTheme.warning,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.star,
                                          size: 16,
                                          color: Theme.of(context).colorScheme.surface,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          '${_userStats['level']} • ${_userStats['points']} pts',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.surface,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          
          // Tabs
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: ModernTheme.rappiOrange,
                unselectedLabelColor: context.secondaryText,
                indicatorColor: ModernTheme.rappiOrange,
                tabs: [
                  Tab(text: AppLocalizations.of(context)!.information, icon: Icon(Icons.person)),
                  Tab(text: AppLocalizations.of(context)!.statistics, icon: Icon(Icons.bar_chart)),
                  Tab(text: AppLocalizations.of(context)!.preferences, icon: Icon(Icons.settings)),
                ],
              ),
            ),
          ),
          
          // Stats del usuario en fila horizontal debajo del avatar/header
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Theme.of(context).colorScheme.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Stat: Viajes
                  Column(
                    children: [
                      Icon(Icons.route, size: 22, color: ModernTheme.rappiOrange),
                      SizedBox(height: 4),
                      Text(
                        '${_userStats['totalTrips'] ?? 0}',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.primaryText),
                      ),
                      Text(
                        AppLocalizations.of(context)!.trips,
                        style: TextStyle(fontSize: 12, color: context.secondaryText),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 40, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.15)),
                  // Stat: Rating
                  Column(
                    children: [
                      Icon(Icons.star, size: 22, color: Colors.amber),
                      SizedBox(height: 4),
                      Text(
                        ((_userStats['rating'] ?? 5.0) as num).toStringAsFixed(1),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.primaryText),
                      ),
                      Text(
                        AppLocalizations.of(context)!.rating,
                        style: TextStyle(fontSize: 12, color: context.secondaryText),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 40, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.15)),
                  // Stat: Miembro desde
                  Column(
                    children: [
                      Icon(Icons.calendar_today, size: 22, color: ModernTheme.rappiOrange),
                      SizedBox(height: 4),
                      Text(
                        () {
                          final ms = _userStats['memberSince'];
                          if (ms is DateTime) return '${ms.year}';
                          return '-';
                        }(),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.primaryText),
                      ),
                      Text(
                        'Miembro',
                        style: TextStyle(fontSize: 12, color: context.secondaryText),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Contenido de tabs
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPersonalInfoTab(),
                _buildStatisticsTab(),
                _buildPreferencesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPersonalInfoTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.personalInformation,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.primaryText,
            ),
          ),
          SizedBox(height: 20),

          // Campos de información
          _buildTextField(
            controller: _nameController,
            label: AppLocalizations.of(context)!.fullName,
            icon: Icons.person,
            enabled: _isEditing,
          ),
          SizedBox(height: 16),

          _buildTextField(
            controller: _emailController,
            label: AppLocalizations.of(context)!.email,
            icon: Icons.email,
            enabled: _isEditing,
            keyboardType: TextInputType.emailAddress,
          ),
          SizedBox(height: 16),

          // ✅ MODIFICADO: Campo de teléfono con botón para cambiar número
          GestureDetector(
            onTap: !_isEditing ? () async {
              // Solo permitir cambio cuando NO está en modo edición
              final result = await Navigator.pushNamed(
                context,
                '/change-phone-number',
                arguments: _phoneController.text.trim(),
              );

              // Si se cambió exitosamente, recargar datos
              if (result == true && mounted) {
                await _loadUserProfile();

                // ✅ CORREGIDO: Verificar mounted nuevamente después del async
                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onPrimary),
                        SizedBox(width: 12),
                        Text('Número actualizado correctamente'),
                      ],
                    ),
                    backgroundColor: ModernTheme.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            } : null,
            child: AbsorbPointer(
              absorbing: !_isEditing, // Bloquear edición directa cuando no está en modo edición
              child: _buildTextField(
                controller: _phoneController,
                label: AppLocalizations.of(context)!.phone,
                icon: Icons.phone,
                enabled: _isEditing,
                keyboardType: TextInputType.phone,
                // ✅ Mostrar ícono de edición solo cuando NO está en modo edición
                suffixIcon: !_isEditing ? Icon(Icons.edit, color: ModernTheme.rappiOrange, size: 20) : null,
              ),
            ),
          ),
          // ✅ Helper text
          if (!_isEditing)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 4),
              child: Text(
                'Toca para cambiar tu número de teléfono',
                style: TextStyle(
                  fontSize: 12,
                  color: context.secondaryText,
                ),
              ),
            ),
          SizedBox(height: 16),

          _buildTextField(
            controller: _birthDateController,
            label: AppLocalizations.of(context)!.birthDate,
            icon: Icons.calendar_today,
            enabled: _isEditing,
            onTap: _isEditing ? () => _selectDate() : null,
          ),

          SizedBox(height: 30),

          // Verificación de cuenta
          Text(
            AppLocalizations.of(context)!.verification,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.primaryText,
            ),
          ),
          SizedBox(height: 16),

          // ✅ CORREGIDO: Leer estado REAL de verificación desde AuthProvider
          Consumer<AuthProvider>(
            builder: (context, authProvider, _) => _buildVerificationItem(
              AppLocalizations.of(context)!.emailVerified,
              authProvider.emailVerified, // ✅ Estado real desde Firestore
              Icons.email,
              onTap: authProvider.emailVerified ? null : () => _navigateToEmailVerification(authProvider),
            ),
          ),
          Consumer<AuthProvider>(
            builder: (context, authProvider, _) => _buildVerificationItem(
              AppLocalizations.of(context)!.phoneVerified,
              authProvider.phoneVerified, // ✅ Estado real desde Firestore
              Icons.phone,
              onTap: authProvider.phoneVerified ? null : () => _navigateToPhoneVerification(),
            ),
          ),
          Consumer<AuthProvider>(
            builder: (context, authProvider, _) => _buildVerificationItem(
              AppLocalizations.of(context)!.identityDocument,
              authProvider.documentVerified, // ✅ Estado real desde Firestore (validado por admin)
              Icons.badge,
              // DNI no tiene onTap - lo valida el administrador
            ),
          ),
          
          SizedBox(height: 30),
          
          // Botones de acción
          if (!_isEditing) ...[
            // ✅ OPTIMIZADO: Botón para convertirse en conductor (solo si no es dual-account)
            // Se extrae el Consumer para evitar rebuilds innecesarios del widget complejo
            Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                final user = authProvider.currentUser;
                final isDualAccount = user?.isDualAccount ?? false;

                // ✅ Si es dual-account, no mostrar nada
                if (isDualAccount) return const SizedBox.shrink();

                // ✅ Usar child preconstruido para evitar reconstruir el widget pesado
                return child!;
              },
              // ✅ Widget preconstruido que no se reconstruye en cada cambio de AuthProvider
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          ModernTheme.rappiOrange,
                          ModernTheme.rappiOrange.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: ModernTheme.rappiOrange.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Builder(
                      builder: (context) => Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.drive_eta,
                              color: Theme.of(context).colorScheme.surface,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.becomeDriver,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.surface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  AppLocalizations.of(context)!.earnMoneyDriving,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/shared/upgrade-to-driver');
                            },
                            icon: Icon(
                              Icons.arrow_forward_ios,
                              color: Theme.of(context).colorScheme.surface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            AnimatedPulseButton(
              text: AppLocalizations.of(context)!.changePassword,
              icon: Icons.lock,
              onPressed: () {
                _showChangePasswordDialog();
              },
              color: ModernTheme.primaryBlue,
            ),
            SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                _showDeleteAccountDialog();
              },
              icon: Icon(Icons.delete_forever, color: ModernTheme.error),
              label: Text(
                AppLocalizations.of(context)!.deleteAccount,
                style: TextStyle(color: ModernTheme.error),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 48),
                side: BorderSide(color: ModernTheme.error),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildStatisticsTab() {
    return AnimatedBuilder(
      animation: _statsController,
      builder: (context, child) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.yourStatistics,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.primaryText,
                ),
              ),
              SizedBox(height: 20),

              // Grid de estadísticas
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.4, // ✅ Aumentado de 1.3 a 1.4 para más espacio vertical
                children: [
                  _buildStatCard(
                    AppLocalizations.of(context)!.totalTrips,
                    '${_userStats['totalTrips']}',
                    Icons.route,
                    ModernTheme.primaryBlue,
                    0,
                  ),
                  _buildStatCard(
                    AppLocalizations.of(context)!.totalSpent,
                    'S/. ${_userStats['totalSpent'].toStringAsFixed(2)}',
                    Icons.account_balance_wallet, // ✅ Cambiado de attach_money ($) a wallet
                    ModernTheme.success,
                    1,
                  ),
                  _buildStatCard(
                    AppLocalizations.of(context)!.distance,
                    '${_userStats['totalDistance'].toStringAsFixed(1)} km',
                    Icons.map,
                    ModernTheme.warning,
                    2,
                  ),
                  _buildStatCard(
                    AppLocalizations.of(context)!.rating,
                    '${_userStats['rating']}',
                    Icons.star,
                    ModernTheme.warning,
                    3,
                  ),
                ],
              ),

              SizedBox(height: 30),

              // Logros
              Text(
                AppLocalizations.of(context)!.achievementsUnlocked,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.primaryText,
                ),
              ),
              SizedBox(height: 16),

              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildAchievementBadge(
                      AppLocalizations.of(context)!.frequentTraveler,
                      Icons.flight_takeoff,
                      true,
                    ),
                    _buildAchievementBadge(
                      AppLocalizations.of(context)!.punctual,
                      Icons.access_time,
                      true,
                    ),
                    _buildAchievementBadge(
                      AppLocalizations.of(context)!.explorer,
                      Icons.explore,
                      true,
                    ),
                    _buildAchievementBadge(
                      AppLocalizations.of(context)!.vip,
                      Icons.workspace_premium,
                      false,
                    ),
                    _buildAchievementBadge(
                      AppLocalizations.of(context)!.ambassador,
                      Icons.people,
                      false,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 30),

              // Gráfico de actividad
              Text(
                AppLocalizations.of(context)!.monthlyActivity,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.primaryText,
                ),
              ),
              SizedBox(height: 16),
              
              Container(
                height: 200,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: ModernTheme.getCardShadow(context),
                ),
                child: CustomPaint(
                  painter: ActivityChartPainter(
                    animation: _statsController,
                    textColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  child: Container(),
                ),
              ),
              
              SizedBox(height: 30),
              
              // Información adicional
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: ModernTheme.rappiOrange.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.cake,
                          color: ModernTheme.rappiOrange,
                        ),
                        SizedBox(width: 12),
                        Text(
                          AppLocalizations.of(context)!.memberSince,
                          style: TextStyle(
                            color: context.secondaryText,
                          ),
                        ),
                        Spacer(),
                        Text(
                          '${_userStats['memberSince'].day}/${_userStats['memberSince'].month}/${_userStats['memberSince'].year}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: ModernTheme.rappiOrange,
                          ),
                        ),
                      ],
                    ),
                    Divider(height: 24),
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          color: ModernTheme.rappiOrange,
                        ),
                        SizedBox(width: 12),
                        Text(
                          AppLocalizations.of(context)!.referredFriends,
                          style: TextStyle(
                            color: context.secondaryText,
                          ),
                        ),
                        Spacer(),
                        Text(
                          '${_userStats['referrals']}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: ModernTheme.rappiOrange,
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
  
  Widget _buildPreferencesTab() {
    return AnimatedBuilder(
      animation: _settingsController,
      builder: (context, child) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notificaciones
              Text(
                AppLocalizations.of(context)!.notifications,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.primaryText,
                ),
              ),
              SizedBox(height: 16),

              _buildSwitchTile(
                AppLocalizations.of(context)!.pushNotifications,
                AppLocalizations.of(context)!.receiveTripAlerts,
                _notificationsEnabled,
                (value) => setState(() => _notificationsEnabled = value),
                Icons.notifications,
                0,
              ),
              _buildSwitchTile(
                AppLocalizations.of(context)!.sound,
                AppLocalizations.of(context)!.activateSounds,
                _soundEnabled,
                (value) => setState(() => _soundEnabled = value),
                Icons.volume_up,
                1,
              ),
              _buildSwitchTile(
                AppLocalizations.of(context)!.vibration,
                AppLocalizations.of(context)!.vibrateOnNotifications,
                _vibrationEnabled,
                (value) => setState(() => _vibrationEnabled = value),
                Icons.vibration,
                2,
              ),
              _buildSwitchTile(
                AppLocalizations.of(context)!.promotions,
                AppLocalizations.of(context)!.receiveOffers,
                _promotionsEnabled,
                (value) => setState(() => _promotionsEnabled = value),
                Icons.local_offer,
                3,
              ),
              _buildSwitchTile(
                AppLocalizations.of(context)!.newsTitle,
                AppLocalizations.of(context)!.learnNewFeatures,
                _newsEnabled,
                (value) => setState(() => _newsEnabled = value),
                Icons.new_releases,
                4,
              ),

              SizedBox(height: 30),

              // Preferencias de viaje
              Text(
                AppLocalizations.of(context)!.travelPreferences,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.primaryText,
                ),
              ),
              SizedBox(height: 16),
              
              // Método de pago predeterminado
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: ModernTheme.getCardShadow(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.payment,
                          color: ModernTheme.rappiOrange,
                        ),
                        SizedBox(width: 12),
                        Text(
                          AppLocalizations.of(context)!.defaultPaymentMethod,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        _buildPaymentOption(AppLocalizations.of(context)!.cash, 'cash', Icons.money),
                        SizedBox(width: 8),
                        _buildPaymentOption(AppLocalizations.of(context)!.card, 'card', Icons.credit_card),
                        SizedBox(width: 8),
                        _buildPaymentOption(AppLocalizations.of(context)!.wallet, 'wallet', Icons.account_balance_wallet),
                      ],
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 16),
              
              // Idioma - ✅ CONECTADO CON LocaleProvider
              Consumer<LocaleProvider>(
                builder: (context, localeProvider, _) => Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: ModernTheme.getCardShadow(context),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.language,
                        color: ModernTheme.rappiOrange,
                      ),
                      SizedBox(width: 12),
                      Text(
                        AppLocalizations.of(context)!.language,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: localeProvider.currentLanguageCode, // ✅ Usar provider
                          underline: SizedBox(),
                          isDense: true,
                          items: [
                            DropdownMenuItem(
                              value: 'es',
                              child: Text(AppLocalizations.of(context)!.spanish),
                            ),
                            DropdownMenuItem(
                              value: 'en',
                              child: Text(AppLocalizations.of(context)!.english),
                            ),
                          ],
                          onChanged: (value) async {
                            if (value != null) {
                              // ✅ Capturar messenger y tema antes del await para evitar warning
                              final messenger = ScaffoldMessenger.of(context);
                              final iconColor = Theme.of(context).colorScheme.onPrimary;
                              final message = value == 'es' ? 'Idioma cambiado a Español' : 'Language changed to English';

                              // ✅ Cambiar idioma usando el provider
                              await localeProvider.setLocale(Locale(value));

                              // ✅ Mostrar confirmación
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(Icons.check_circle, color: iconColor, size: 20),
                                        SizedBox(width: 12),
                                        Text(message),
                                      ],
                                    ),
                                    backgroundColor: ModernTheme.rappiOrange,
                                    behavior: SnackBarBehavior.floating,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 30),

              // Privacidad
              Text(
                AppLocalizations.of(context)!.privacyAndSecurity,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.primaryText,
                ),
              ),
              SizedBox(height: 16),

              _buildPrivacyOption(
                AppLocalizations.of(context)!.termsAndConditions,
                Icons.description,
                _showTermsDialog, // ✅ IMPLEMENTADO: Mostrar diálogo con términos
              ),
              _buildPrivacyOption(
                AppLocalizations.of(context)!.privacyPolicy,
                Icons.privacy_tip,
                _showPrivacyPolicyDialog, // ✅ IMPLEMENTADO: Mostrar diálogo con política
              ),
              _buildPrivacyOption(
                AppLocalizations.of(context)!.managePermissions,
                Icons.security,
                _openAppSettings, // ✅ IMPLEMENTADO: Abrir configuración de Android
              ),
              _buildPrivacyOption(
                AppLocalizations.of(context)!.exportMyData,
                Icons.download,
                _exportUserData, // ✅ IMPLEMENTADO: Exportar datos a JSON
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    TextInputType? keyboardType,
    VoidCallback? onTap,
    Widget? suffixIcon, // ✅ NUEVO: Ícono al final del campo
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: ModernTheme.rappiOrange),
        suffixIcon: suffixIcon, // ✅ NUEVO: Agregar suffixIcon
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ModernTheme.rappiOrange, width: 2),
        ),
        filled: true,
        fillColor: enabled ? Theme.of(context).colorScheme.surface : context.surfaceColor,
      ),
    );
  }
  
  Widget _buildVerificationItem(String title, bool verified, IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: verified ? null : onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: verified
            ? ModernTheme.success.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: verified
              ? ModernTheme.success.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: verified ? ModernTheme.success : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: verified ? context.primaryText : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (!verified && onTap != null)
                    Text(
                      'Toca para verificar',
                      style: TextStyle(
                        fontSize: 12,
                        color: ModernTheme.rappiOrange,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              verified ? Icons.check_circle : Icons.arrow_forward_ios,
              color: verified ? ModernTheme.success : ModernTheme.rappiOrange,
              size: verified ? 24 : 18,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    int index,
  ) {
    final delay = index * 0.1;
    final animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _statsController,
        curve: Interval(
          delay,
          delay + 0.5,
          curve: Curves.easeOut, // ✅ Cambiado de easeOutBack a easeOut para evitar overflow
        ),
      ),
    );
    
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.scale(
          scale: animation.value,
          child: Container(
            padding: EdgeInsets.all(12), // ✅ Reducido de 16 a 12 para más espacio interno
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: ModernTheme.getCardShadow(context),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(8), // ✅ Reducido de 10 a 8
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20), // ✅ Reducido de 22 a 20
                ),
                SizedBox(height: 4), // ✅ Reducido de 8 a 4
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16, // ✅ Reducido de 18 a 16
                    fontWeight: FontWeight.bold,
                    color: context.primaryText,
                  ),
                ),
                SizedBox(height: 2), // ✅ Mantener en 2
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10, // ✅ Reducido de 11 a 10
                    color: context.secondaryText,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildAchievementBadge(String title, IconData icon, bool unlocked) {
    return Container(
      width: 80,
      margin: EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: unlocked
                ? ModernTheme.rappiOrange
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              shape: BoxShape.circle,
              boxShadow: unlocked ? ModernTheme.getCardShadow(context) : null,
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.surface,
              size: 30,
            ),
          ),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: unlocked 
                ? context.primaryText 
                : context.secondaryText,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
    IconData icon,
    int index,
  ) {
    final delay = index * 0.1;
    final animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _settingsController,
        curve: Interval(
          delay,
          delay + 0.5,
          curve: Curves.easeOut,
        ),
      ),
    );
    
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(50 * (1 - animation.value), 0),
          child: Opacity(
            opacity: animation.value,
            child: Container(
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: ModernTheme.getCardShadow(context),
              ),
              child: ListTile(
                leading: Icon(icon, color: ModernTheme.rappiOrange),
                title: Text(title),
                subtitle: Text(
                  subtitle,
                  style: TextStyle(fontSize: 12),
                ),
                trailing: Switch(
                  value: value,
                  onChanged: onChanged,
                  thumbColor: WidgetStateProperty.all(ModernTheme.rappiOrange),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildPaymentOption(String label, String value, IconData icon) {
    final isSelected = _defaultPayment == value;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _defaultPayment = value);
          // ✅ FEEDBACK VISUAL: SnackBar para confirmar selección
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onPrimary, size: 20),
                  const SizedBox(width: 12),
                  Text('${AppLocalizations.of(context)!.paymentMethodPrefix} $label'),
                ],
              ),
              backgroundColor: ModernTheme.rappiOrange,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            // ✅ MEJORADO: Alpha aumentado de 0.1 a 0.25 para mejor visibilidad
            color: isSelected
              ? ModernTheme.rappiOrange.withValues(alpha: 0.25)
              : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                ? ModernTheme.rappiOrange
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
            // ✅ NUEVO: Sombra cuando está seleccionado
            boxShadow: isSelected ? [
              BoxShadow(
                color: ModernTheme.rappiOrange.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ] : null,
          ),
          child: Stack(
            children: [
              // Contenido principal
              Column(
                children: [
                  Icon(
                    icon,
                    color: isSelected
                      ? ModernTheme.rappiOrange
                      : context.secondaryText,
                    size: 20,
                  ),
                  SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                        ? ModernTheme.rappiOrange
                        : context.secondaryText,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              // ✅ NUEVO: Check icon en la esquina cuando está seleccionado
              if (isSelected)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: ModernTheme.rappiOrange,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.surface,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildPrivacyOption(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: ModernTheme.getCardShadow(context),
        ),
        child: Row(
          children: [
            Icon(icon, color: ModernTheme.rappiOrange),
            SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: context.secondaryText,
            ),
          ],
        ),
      ),
    );
  }
  
  void _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990, 3, 15),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: ModernTheme.rappiOrange,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _birthDateController.text = 
          '${picked.day}/${picked.month}/${picked.year}';
      });
    }
  }
  
  void _showChangePasswordDialog() {
    // ✅ AGREGAR CONTROLLERS para capturar los valores
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(AppLocalizations.of(context)!.changePasswordTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController, // ✅ AGREGAR CONTROLLER
                obscureText: true,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.currentPassword,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: newPasswordController, // ✅ AGREGAR CONTROLLER
                obscureText: true,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.newPassword,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.lock),
                  helperText: 'Mín. 8 caracteres, mayúsculas, minúsculas, números y símbolos',
                  helperMaxLines: 2,
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController, // ✅ AGREGAR CONTROLLER
                obscureText: true,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.confirmNewPassword,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.check_circle_outline),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // ✅ Dispose controllers
              currentPasswordController.dispose();
              newPasswordController.dispose();
              confirmPasswordController.dispose();
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              // ✅ VALIDAR QUE LAS CONTRASEÑAS COINCIDAN
              if (newPasswordController.text != confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Las contraseñas no coinciden'),
                    backgroundColor: ModernTheme.error,
                  ),
                );
                return;
              }

              // ✅ VALIDAR FORTALEZA DE CONTRASEÑA
              final password = newPasswordController.text;
              if (password.length < 8 ||
                  !password.contains(RegExp(r'[A-Z]')) ||
                  !password.contains(RegExp(r'[a-z]')) ||
                  !password.contains(RegExp(r'[0-9]')) ||
                  !password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('La contraseña debe tener al menos 8 caracteres con mayúsculas, minúsculas, números y caracteres especiales'),
                    backgroundColor: ModernTheme.error,
                    duration: Duration(seconds: 5),
                  ),
                );
                return;
              }

              // ✅ LLAMAR A authProvider.changePassword()
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final passwordUpdatedMsg = AppLocalizations.of(context)!.passwordUpdated;

              final success = await authProvider.changePassword(
                currentPasswordController.text,
                newPasswordController.text,
              );

              // ✅ Dispose controllers
              currentPasswordController.dispose();
              newPasswordController.dispose();
              confirmPasswordController.dispose();

              navigator.pop();

              // ✅ MOSTRAR RESULTADO REAL (no falso)
              if (success) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(passwordUpdatedMsg),
                    backgroundColor: ModernTheme.success,
                  ),
                );
              } else {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(authProvider.errorMessage ?? 'Error al cambiar contraseña'),
                    backgroundColor: ModernTheme.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.rappiOrange,
            ),
            child: Text(AppLocalizations.of(context)!.change),
          ),
        ],
      ),
    );
  }

  /// ✅ IMPLEMENTADO: Diálogo de confirmación para eliminar cuenta
  /// Requiere re-autenticación por seguridad (requisito de Firebase)
  void _showDeleteAccountDialog() {
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    showDialog(
      context: context,
      barrierDismissible: false, // No cerrar al tocar afuera
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: ModernTheme.error, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.deleteAccountTitle,
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.deleteAccountConfirmation,
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ModernTheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ModernTheme.error.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '⚠️ Esta acción es PERMANENTE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: ModernTheme.error,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Se eliminarán:\n'
                        '• Tu perfil y datos personales\n'
                        '• Historial de viajes\n'
                        '• Lugares favoritos\n'
                        '• Métodos de pago guardados\n'
                        '• Fotos y documentos',
                        style: TextStyle(fontSize: 12, color: context.secondaryText),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Confirma tu contraseña para continuar:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Ingresa tu contraseña',
                    prefixIcon: Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword ? Icons.visibility_off : Icons.visibility,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                passwordController.dispose();
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                final password = passwordController.text.trim();

                if (password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Por favor ingresa tu contraseña'),
                      backgroundColor: ModernTheme.error,
                    ),
                  );
                  return;
                }

                Navigator.pop(context);
                passwordController.dispose();

                // Ejecutar eliminación
                await _deleteAccount(password);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.error,
              ),
              child: Text(AppLocalizations.of(context)!.delete),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ IMPLEMENTADO: Eliminar cuenta completa con Firebase
  /// Sigue las mejores prácticas de seguridad y limpieza de datos
  Future<void> _deleteAccount(String password) async {
    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Eliminando cuenta...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userModel = authProvider.currentUser;

      if (userModel == null) {
        throw Exception('No hay usuario autenticado');
      }

      // 1️⃣ Re-autenticar usuario (REQUISITO DE FIREBASE para operaciones sensibles)
      final email = userModel.email;
      if (email.isEmpty) {
        throw Exception('Usuario sin email, no se puede re-autenticar');
      }

      await authProvider.reauthenticateWithPassword(email, password);

      // 2️⃣ Eliminar foto de perfil de Storage (si existe)
      if (userModel.profilePhotoUrl.isNotEmpty && userModel.profilePhotoUrl.contains('firebase')) {
        try {
          final photoRef = FirebaseStorage.instance.refFromURL(userModel.profilePhotoUrl);
          await photoRef.delete();
        } catch (e) {
          // Si falla, continuar igual (la foto puede no existir)
          debugPrint('Error eliminando foto de perfil: $e');
        }
      }

      // 3️⃣ Eliminar documentos del usuario de Firestore
      final userId = userModel.id;
      final firestore = FirebaseFirestore.instance;

      // Eliminar datos del usuario
      final batch = firestore.batch();

      // Usuario principal
      batch.delete(firestore.collection('users').doc(userId));

      // Favoritos (subcolección)
      final favoritesSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .get();
      for (var doc in favoritesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Métodos de pago (subcolección)
      final paymentMethodsSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('payment_methods')
          .get();
      for (var doc in paymentMethodsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Notificaciones del usuario
      final notificationsSnapshot = await firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();
      for (var doc in notificationsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // ⚠️ NOTA: NO eliminamos viajes (rides) porque pueden estar compartidos con conductores
      // Solo marcamos como "usuario eliminado" para mantener historial del conductor
      final ridesSnapshot = await firestore
          .collection('rides')
          .where('passengerId', isEqualTo: userId)
          .get();
      for (var doc in ridesSnapshot.docs) {
        batch.update(doc.reference, {
          'passengerDeleted': true,
          'passengerName': '[Usuario eliminado]',
        });
      }

      // Ejecutar todas las eliminaciones
      await batch.commit();

      // 4️⃣ Eliminar cuenta de Firebase Auth (ÚLTIMA ACCIÓN)
      await authProvider.deleteAccount();

      // 5️⃣ Cerrar diálogo de loading
      if (mounted) {
        Navigator.pop(context);

        // 6️⃣ Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onPrimary),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Cuenta eliminada correctamente'),
                ),
              ],
            ),
            backgroundColor: ModernTheme.success,
            duration: Duration(seconds: 3),
          ),
        );

        // 7️⃣ Redirigir al login después de 1 segundo
        await Future.delayed(Duration(seconds: 1));
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
          );
        }
      }
    } catch (e) {
      // Cerrar diálogo de loading
      if (mounted) {
        Navigator.pop(context);

        // Mostrar error
        String errorMessage = 'Error al eliminar la cuenta';

        if (e.toString().contains('wrong-password')) {
          errorMessage = 'Contraseña incorrecta';
        } else if (e.toString().contains('requires-recent-login')) {
          errorMessage = 'Por seguridad, inicia sesión nuevamente';
        } else if (e.toString().contains('network')) {
          errorMessage = 'Error de conexión. Verifica tu internet';
        }

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.error_outline, color: ModernTheme.error),
                SizedBox(width: 12),
                Text('Error'),
              ],
            ),
            content: Text(errorMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Entendido'),
              ),
            ],
          ),
        );
      }

      debugPrint('❌ Error eliminando cuenta: $e');
    }
  }

  // ✅ NUEVO: Mostrar términos y condiciones
  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.description, color: ModernTheme.rappiOrange, size: 20), // ✅ Reducido tamaño
            SizedBox(width: 8), // ✅ Reducido espacio
            Expanded( // ✅ AGREGADO: Expanded para evitar overflow
              child: Text(
                'Términos y Condiciones',
                style: TextStyle(fontSize: 16), // ✅ Reducido tamaño de fuente
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Última actualización: Enero 2025',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.secondaryText,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  '1. Aceptación de Términos',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Al usar la aplicación Rappi Team, aceptas estos términos y condiciones en su totalidad. Si no estás de acuerdo, por favor no uses nuestros servicios.',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 16),
                Text(
                  '2. Servicios Ofrecidos',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Rappi Team proporciona una plataforma para conectar pasajeros con conductores profesionales. Nos reservamos el derecho de modificar o discontinuar servicios sin previo aviso.',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 16),
                Text(
                  '3. Responsabilidades del Usuario',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  '• Proporcionar información precisa y actualizada\n'
                  '• Mantener la confidencialidad de tu cuenta\n'
                  '• Cumplir con todas las leyes aplicables\n'
                  '• Tratar con respeto a conductores y otros usuarios\n'
                  '• No usar el servicio con fines ilícitos',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 16),
                Text(
                  '4. Pagos y Tarifas',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Las tarifas se calculan en base a distancia, tiempo y demanda. Los precios mostrados son aproximados y pueden variar. Aceptas pagar todas las tarifas aplicables.',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 16),
                Text(
                  '5. Cancelaciones',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Puedes cancelar un viaje antes de que el conductor llegue. Cancelaciones tardías pueden incurrir en cargos. Los conductores también pueden cancelar bajo ciertas circunstancias.',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 16),
                Text(
                  '6. Limitación de Responsabilidad',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Rappi Team actúa como intermediario. No somos responsables por la conducta de conductores o pasajeros, accidentes, daños o pérdidas durante el servicio.',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 16),
                Text(
                  '7. Modificaciones',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Nos reservamos el derecho de modificar estos términos en cualquier momento. El uso continuado de la app constituye aceptación de los términos modificados.',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.rappiOrange,
            ),
            child: Text(AppLocalizations.of(context)!.understood),
          ),
        ],
      ),
    );
  }

  // ✅ NUEVO: Mostrar política de privacidad
  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.privacy_tip, color: ModernTheme.rappiOrange, size: 20), // ✅ Reducido tamaño
            SizedBox(width: 8), // ✅ Reducido espacio
            Expanded( // ✅ AGREGADO: Expanded para evitar overflow
              child: Text(
                'Política de Privacidad',
                style: TextStyle(fontSize: 16), // ✅ Reducido tamaño de fuente
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Última actualización: Enero 2025',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.secondaryText,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  '1. Información que Recopilamos',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  '• Información de cuenta: nombre, email, teléfono\n'
                  '• Ubicación en tiempo real durante viajes\n'
                  '• Historial de viajes y rutas\n'
                  '• Información de pago\n'
                  '• Datos del dispositivo y uso de la app',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 16),
                Text(
                  '2. Cómo Usamos Tu Información',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  '• Proveer y mejorar nuestros servicios\n'
                  '• Conectar pasajeros con conductores\n'
                  '• Procesar pagos de forma segura\n'
                  '• Enviar notificaciones sobre viajes\n'
                  '• Prevenir fraude y abusos\n'
                  '• Cumplir con obligaciones legales',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 16),
                Text(
                  '3. Compartir Información',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Compartimos tu información solo cuando es necesario:\n'
                  '• Con conductores asignados a tus viajes\n'
                  '• Con proveedores de servicios de pago\n'
                  '• Con autoridades si es requerido por ley\n'
                  '• Con tu consentimiento explícito',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 16),
                Text(
                  '4. Seguridad de Datos',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Implementamos medidas de seguridad técnicas y organizativas para proteger tu información contra acceso no autorizado, pérdida o alteración.',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 16),
                Text(
                  '5. Tus Derechos',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  '• Acceder a tu información personal\n'
                  '• Corregir datos inexactos\n'
                  '• Solicitar eliminación de tu cuenta\n'
                  '• Exportar tus datos\n'
                  '• Revocar consentimientos\n'
                  '• Presentar quejas ante autoridades',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 16),
                Text(
                  '6. Retención de Datos',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Conservamos tu información mientras tu cuenta esté activa y durante el tiempo necesario para cumplir con obligaciones legales (típicamente 5 años).',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 16),
                Text(
                  '7. Contacto',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Para consultas sobre privacidad:\n'
                  'Email: privacy@rapiteam.app\n'
                  'Teléfono: +51 (01) 555-0123',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.rappiOrange,
            ),
            child: Text(AppLocalizations.of(context)!.understood),
          ),
        ],
      ),
    );
  }

  // ✅ NUEVO: Abrir configuración de Android/iOS para gestionar permisos
  Future<void> _openAppSettings() async {
    try {
      // Usar el método correcto de permission_handler para abrir settings
      final opened = await openAppSettings();

      if (!opened && mounted) {
        // Si no se pudo abrir, mostrar instrucciones manuales
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Por favor, abre Configuración > Apps > Rappi Team > Permisos manualmente',
            ),
            backgroundColor: ModernTheme.warning,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error abriendo configuración: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir la configuración'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }

  // ✅ NUEVO: Exportar datos del usuario a JSON
  Future<void> _exportUserData() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final localeProvider = Provider.of<LocaleProvider>(context, listen: false); // ✅ Obtener LocaleProvider
      final user = authProvider.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.userInfoError),
            backgroundColor: ModernTheme.error,
          ),
        );
        return;
      }

      // Crear JSON con todos los datos del usuario
      final userData = {
        'exportDate': DateTime.now().toIso8601String(),
        'personalInfo': {
          'userId': user.id, // ✅ CORREGIDO: usar 'id' en lugar de 'userId'
          'fullName': user.fullName,
          'email': user.email,
          'phone': user.phone,
          'createdAt': user.createdAt.toIso8601String(),
        },
        'statistics': {
          'totalTrips': user.totalTrips,
          'balance': user.balance,
          'rating': user.rating,
          'level': _getUserLevel(user.totalTrips),
          'points': user.totalTrips * 10,
        },
        'preferences': {
          'notificationsEnabled': _notificationsEnabled,
          'soundEnabled': _soundEnabled,
          'vibrationEnabled': _vibrationEnabled,
          'promotionsEnabled': _promotionsEnabled,
          'newsEnabled': _newsEnabled,
          'defaultPayment': _defaultPayment,
          'language': localeProvider.currentLanguageCode, // ✅ Usar LocaleProvider
        },
      };

      // Convertir a JSON string con formato bonito
      final jsonString = JsonEncoder.withIndent('  ').convert(userData);

      // Obtener directorio de documentos
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/rappi_team_data_$timestamp.json');

      // Guardar archivo
      await file.writeAsString(jsonString);

      // Mostrar diálogo de éxito con ubicación del archivo
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: ModernTheme.success),
                SizedBox(width: 12),
                Text('Datos Exportados'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tus datos han sido exportados exitosamente.'),
                SizedBox(height: 12),
                Text(
                  'Ubicación:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    file.path,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ModernTheme.rappiOrange,
                ),
                child: Text(AppLocalizations.of(context)!.understood),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error exportando datos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar datos: ${e.toString()}'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }
}

// Delegate para el tab bar fijo
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  
  _SliverAppBarDelegate(this._tabBar);
  
  @override
  double get minExtent => _tabBar.preferredSize.height;
  
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: _tabBar,
    );
  }
  
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}

// Painter para el fondo del perfil
class ProfileBackgroundPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  const ProfileBackgroundPainter({super.repaint, required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    // Círculos animados
    for (int i = 0; i < 3; i++) {
      final radius = (50 + i * 30) * animation.value;
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        radius,
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Painter para el gráfico de actividad
class ActivityChartPainter extends CustomPainter {
  final Animation<double> animation;
  final Color textColor;

  const ActivityChartPainter({super.repaint, required this.animation, required this.textColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ModernTheme.rappiOrange
      ..style = PaintingStyle.fill;

    final data = [0.3, 0.5, 0.8, 0.6, 0.9, 0.7, 0.4];
    final barWidth = size.width / (data.length * 2);

    for (int i = 0; i < data.length; i++) {
      final barHeight = size.height * data[i] * animation.value;
      final x = i * (barWidth * 2) + barWidth / 2;
      final y = size.height - barHeight;

      // Barra
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        Radius.circular(4),
      );
      canvas.drawRRect(rect, paint);

      // Etiqueta
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'D${i + 1}',
          style: TextStyle(
            color: textColor,
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x + barWidth / 2 - textPainter.width / 2, size.height + 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}