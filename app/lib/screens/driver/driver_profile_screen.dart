// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/rapi_api_client.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/utils/responsive_bottom_sheet.dart';
import '../../core/extensions/theme_extensions.dart'; // ✅ Extensión para colores que se adaptan al tema
import '../../core/utils/currency_formatter.dart';
import 'documents_screen.dart';
import 'earnings_withdrawal_screen.dart';

import '../../utils/logger.dart';
import '../../utils/error_messages.dart';
class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  _DriverProfileScreenState createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  // Profile data
  DriverProfile? _profile;
  bool _isLoading = true;

  // ImagePicker para foto de perfil (upload va por RapiApiClient)
  final ImagePicker _picker = ImagePicker();
  final RapiApiClient _api = RapiApiClient.instance;

  // ID del usuario autenticado (obtenido del backend Node)
  String? _authUserId;

  // ✅ FLAGS DE EDICIÓN INLINE PARA CADA SECCIÓN
  bool _isEditingPersonal = false;  // Información Personal
  bool _isEditingVehicle = false;   // Información del Vehículo
  bool _isEditingPreferences = false; // Preferencias
  bool _isEditingSchedule = false;  // Horario de Trabajo

  // ✅ NUEVO: Documentos del conductor
  Map<String, String>? _documents;

  // ✅ FORM KEYS PARA CADA SECCIÓN
  final _personalFormKey = GlobalKey<FormState>();
  final _vehicleFormKey = GlobalKey<FormState>();
  final _preferencesFormKey = GlobalKey<FormState>();
  final _scheduleFormKey = GlobalKey<FormState>();

  // ✅ CONTROLADORES - INFORMACIÓN PERSONAL
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _emergencyContactController = TextEditingController();
  final TextEditingController _emergencyPhoneController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  // ✅ CONTROLADORES - INFORMACIÓN DEL VEHÍCULO
  final TextEditingController _makeController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();

  // ✅ VARIABLES DE ESTADO - PREFERENCIAS (sin controllers, usan estado directo)
  bool _acceptPets = false;
  bool _acceptSmoking = false;
  String _musicPreference = 'Ninguna';
  List<String> _languages = ['Español'];
  double _maxTripDistance = 50.0;
  List<String> _preferredZones = [];

  // ✅ VARIABLES DE ESTADO - HORARIO DE TRABAJO
  Map<String, Map<String, dynamic>> _weekSchedule = {
    'Lunes': {'start': TimeOfDay(hour: 8, minute: 0), 'end': TimeOfDay(hour: 18, minute: 0), 'active': true},
    'Martes': {'start': TimeOfDay(hour: 8, minute: 0), 'end': TimeOfDay(hour: 18, minute: 0), 'active': true},
    'Miércoles': {'start': TimeOfDay(hour: 8, minute: 0), 'end': TimeOfDay(hour: 18, minute: 0), 'active': true},
    'Jueves': {'start': TimeOfDay(hour: 8, minute: 0), 'end': TimeOfDay(hour: 18, minute: 0), 'active': true},
    'Viernes': {'start': TimeOfDay(hour: 8, minute: 0), 'end': TimeOfDay(hour: 18, minute: 0), 'active': true},
    'Sábado': {'start': TimeOfDay(hour: 8, minute: 0), 'end': TimeOfDay(hour: 18, minute: 0), 'active': false},
    'Domingo': {'start': TimeOfDay(hour: 8, minute: 0), 'end': TimeOfDay(hour: 18, minute: 0), 'active': false},
  };

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    );
    
    _loadProfile();
  }
  
  @override
  void dispose() {
    // Animación
    _fadeController.dispose();
    _slideController.dispose();

    // Información Personal
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    _bioController.dispose();

    // Información del Vehículo
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _plateController.dispose();
    _capacityController.dispose();

    super.dispose();
  }
  
  // Cargar perfil real desde el backend Node (RapiApiClient)
  Future<void> _loadProfile() async {
    try {
      // Obtener usuario actual del backend Node
      final meResp = await _api.me();
      final userData = meResp?['user'] as Map<String, dynamic>?;
      if (userData == null) {
        AppLogger.warning('No hay usuario autenticado');
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final userId = (userData['id'] ?? '') as String;
      _authUserId = userId;

      // Perfil driver (vehicle + documents) desde /api/drivers/me/profile
      Map<String, dynamic> driverProfileData = const {};
      try {
        driverProfileData = await _api.myDriverProfile();
      } catch (e) {
        AppLogger.warning(userFriendlyError(e, fallback: 'No se pudo cargar driver profile'));
      }

      // Estadísticas desde /api/rides (viajes completados como conductor)
      double totalDistance = 0.0;
      double totalEarnings = 0.0;
      double totalHours = 0.0;
      int totalTripsCount = 0;

      try {
        final ridesResp = await _api.listRides(
          role: 'driver',
          status: 'completed',
          pageSize: 100,
        );
        final rides = ridesResp['rides'] ?? ridesResp['items'] ?? ridesResp['data'];
        if (rides is List) {
          totalTripsCount = rides.length;
          for (final r in rides.whereType<Map>()) {
            final data = Map<String, dynamic>.from(r);
            final distance = data['distance'] ?? data['distanceMeters'];
            if (distance is num) totalDistance += distance.toDouble();
            final fare = data['fare'] ?? data['finalFare'];
            if (fare is num) totalEarnings += fare.toDouble();
            final startedRaw = data['startedAt'] ?? data['started_at'];
            final completedRaw = data['completedAt'] ?? data['completed_at'];
            if (startedRaw is String && completedRaw is String) {
              final startedAt = DateTime.tryParse(startedRaw);
              final completedAt = DateTime.tryParse(completedRaw);
              if (startedAt != null && completedAt != null) {
                totalHours += completedAt.difference(startedAt).inMinutes / 60.0;
              }
            }
          }
        }
      } catch (e) {
        AppLogger.warning(userFriendlyError(e, fallback: 'No se pudieron cargar estadísticas de rides'));
        totalTripsCount = (userData['totalTrips'] as num?)?.toInt() ?? 0;
        totalEarnings = (userData['totalEarnings'] as num?)?.toDouble() ?? 0.0;
      }

      // Extraer datos ricos del perfil (vienen en driverProfile o en user)
      final richProfile = (userData['driverProfile'] as Map<String, dynamic>?) ??
          driverProfileData;
      final emergencyContactData = richProfile['emergencyContact'] as Map<String, dynamic>?;
      final preferencesData = richProfile['preferences'] as Map<String, dynamic>?;
      final vehicleInfoData = (richProfile['vehicle'] ?? richProfile['vehicleInfo']) as Map<String, dynamic>?;
      final workScheduleData = richProfile['workSchedule'] as Map<String, dynamic>?;

      // Documentos del conductor (vienen como lista en /api/drivers/me/documents)
      try {
        final docsResp = await _api.myDocuments();
        final docs = docsResp['documents'];
        if (docs is List) {
          final map = <String, String>{};
          for (final d in docs.whereType<Map>()) {
            final type = (d['docType'] ?? d['type'])?.toString();
            final url = (d['fileUrl'] ?? d['url'])?.toString();
            if (type != null && url != null) {
              map[type] = url;
            }
          }
          _documents = map;
        }
      } catch (e) {
        AppLogger.warning(userFriendlyError(e, fallback: 'No se pudieron cargar documentos'));
      }

      // Ronda 235: catálogo de logros con progreso real. Bloqueados hasta
      // alcanzar la meta. Antes lista vacía → sección "Logros" siempre en
      // blanco aunque el driver hubiera completado hitos.
      final List<Achievement> achievementsList = _buildAchievementsCatalog(
        totalTrips: totalTripsCount,
        rating: (userData['rating'] as num?)?.toDouble() ?? 5.0,
        totalEarnings: totalEarnings,
        memberSince: DateTime.tryParse((userData['createdAt'] ?? '').toString()) ?? DateTime.now(),
      );

      if (mounted) {
        setState(() {
          _profile = DriverProfile(
            id: userId,
          name: (userData['fullName'] ?? '') as String,
          email: (userData['email'] ?? '') as String,
          phone: (userData['phone'] ?? '') as String,
          profileImageUrl: (userData['profilePhotoUrl'] ?? '') as String,
          rating: (userData['rating'] as num?)?.toDouble() ?? 5.0,
          totalTrips: totalTripsCount,
          totalDistance: totalDistance,
          totalHours: totalHours,
          totalEarnings: totalEarnings,
          memberSince: DateTime.tryParse((userData['createdAt'] ?? '').toString()) ?? DateTime.now(),
          bio: userData['bio'] ?? '',
          emergencyContact: EmergencyContact(
            name: emergencyContactData?['name'] ?? '',
            phone: emergencyContactData?['phone'] ?? '',
            relationship: emergencyContactData?['relationship'] ?? '',
          ),
          // Ronda 235: defaults sensatos cuando el backend aún no envía
          // preferencias. Antes todo era false/vacío → sección "Preferencias"
          // se veía como si el driver no hubiera configurado nada.
          preferences: DriverPreferences(
            acceptPets: preferencesData?['acceptPets'] ?? true,
            acceptSmoking: preferencesData?['acceptSmoking'] ?? false,
            musicPreference: preferencesData?['musicPreference'] ?? 'A gusto del pasajero',
            languages: (preferencesData?['languages'] as List<dynamic>?)?.cast<String>() ?? const ['Español'],
            maxTripDistance: ((preferencesData?['maxTripDistance'] ?? 50.0) as num).toDouble().clamp(5.0, 100.0),
            preferredZones: (preferencesData?['preferredZones'] as List<dynamic>?)?.cast<String>() ?? const ['Lima Metropolitana'],
          ),
          achievements: achievementsList,
          vehicleInfo: VehicleInfo(
            make: (vehicleInfoData?['make'] ?? vehicleInfoData?['brand'] ?? '') as String,
            model: (vehicleInfoData?['model'] ?? '') as String,
            year: (vehicleInfoData?['year'] as num?)?.toInt() ?? 0,
            color: (vehicleInfoData?['color'] ?? '') as String,
            plate: (vehicleInfoData?['plate'] ?? '') as String,
            capacity: (vehicleInfoData?['capacity'] as num?)?.toInt() ?? (vehicleInfoData?['seats'] as num?)?.toInt() ?? 4,
          ),
          // Ronda 235: horario por defecto 08:00-20:00 lun-sab, 09:00-18:00
          // domingo. Antes 00:00-00:00 se leía como "no trabaja ningún día"
          // y no había manera de saber que era default vacío.
          workSchedule: WorkSchedule(
            mondayStart: workScheduleData?['mondayStart'] ?? '08:00',
            mondayEnd: workScheduleData?['mondayEnd'] ?? '20:00',
            tuesdayStart: workScheduleData?['tuesdayStart'] ?? '08:00',
            tuesdayEnd: workScheduleData?['tuesdayEnd'] ?? '20:00',
            wednesdayStart: workScheduleData?['wednesdayStart'] ?? '08:00',
            wednesdayEnd: workScheduleData?['wednesdayEnd'] ?? '20:00',
            thursdayStart: workScheduleData?['thursdayStart'] ?? '08:00',
            thursdayEnd: workScheduleData?['thursdayEnd'] ?? '20:00',
            fridayStart: workScheduleData?['fridayStart'] ?? '08:00',
            fridayEnd: workScheduleData?['fridayEnd'] ?? '20:00',
            saturdayStart: workScheduleData?['saturdayStart'] ?? '08:00',
            saturdayEnd: workScheduleData?['saturdayEnd'] ?? '20:00',
            sundayStart: workScheduleData?['sundayStart'] ?? '09:00',
            sundayEnd: workScheduleData?['sundayEnd'] ?? '18:00',
          ),
        );
        _isLoading = false;

        // ✅ Inicializar controladores - Información Personal
        _nameController.text = _profile!.name;
        _phoneController.text = _profile!.phone;
        _emailController.text = _profile!.email;
        _emergencyContactController.text = _profile!.emergencyContact.name;
        _emergencyPhoneController.text = _profile!.emergencyContact.phone;
        _bioController.text = _profile!.bio;

        // ✅ Inicializar controladores - Información del Vehículo
        _makeController.text = _profile!.vehicleInfo.make;
        _modelController.text = _profile!.vehicleInfo.model;
        _yearController.text = '${_profile!.vehicleInfo.year}';
        _colorController.text = _profile!.vehicleInfo.color;
        _plateController.text = _profile!.vehicleInfo.plate;
        _capacityController.text = '${_profile!.vehicleInfo.capacity}';

        // ✅ Inicializar variables de estado - Preferencias
        _acceptPets = _profile!.preferences.acceptPets;
        _acceptSmoking = _profile!.preferences.acceptSmoking;
        _musicPreference = _profile!.preferences.musicPreference.isEmpty
            ? 'Ninguna'
            : _profile!.preferences.musicPreference;
        _languages = List<String>.from(_profile!.preferences.languages);
        _maxTripDistance = (_profile!.preferences.maxTripDistance).clamp(5.0, 100.0);
        _preferredZones = List<String>.from(_profile!.preferences.preferredZones);

        // ✅ Inicializar variables de estado - Horario de Trabajo
        final schedule = _profile!.workSchedule;
        _weekSchedule = {
          'Lunes': {
            'start': TimeOfDay(
              hour: int.parse(schedule.mondayStart.split(':')[0]),
              minute: int.parse(schedule.mondayStart.split(':')[1])
            ),
            'end': TimeOfDay(
              hour: int.parse(schedule.mondayEnd.split(':')[0]),
              minute: int.parse(schedule.mondayEnd.split(':')[1])
            ),
            'active': schedule.mondayStart != '00:00' || schedule.mondayEnd != '00:00',
          },
          'Martes': {
            'start': TimeOfDay(
              hour: int.parse(schedule.tuesdayStart.split(':')[0]),
              minute: int.parse(schedule.tuesdayStart.split(':')[1])
            ),
            'end': TimeOfDay(
              hour: int.parse(schedule.tuesdayEnd.split(':')[0]),
              minute: int.parse(schedule.tuesdayEnd.split(':')[1])
            ),
            'active': schedule.tuesdayStart != '00:00' || schedule.tuesdayEnd != '00:00',
          },
          'Miércoles': {
            'start': TimeOfDay(
              hour: int.parse(schedule.wednesdayStart.split(':')[0]),
              minute: int.parse(schedule.wednesdayStart.split(':')[1])
            ),
            'end': TimeOfDay(
              hour: int.parse(schedule.wednesdayEnd.split(':')[0]),
              minute: int.parse(schedule.wednesdayEnd.split(':')[1])
            ),
            'active': schedule.wednesdayStart != '00:00' || schedule.wednesdayEnd != '00:00',
          },
          'Jueves': {
            'start': TimeOfDay(
              hour: int.parse(schedule.thursdayStart.split(':')[0]),
              minute: int.parse(schedule.thursdayStart.split(':')[1])
            ),
            'end': TimeOfDay(
              hour: int.parse(schedule.thursdayEnd.split(':')[0]),
              minute: int.parse(schedule.thursdayEnd.split(':')[1])
            ),
            'active': schedule.thursdayStart != '00:00' || schedule.thursdayEnd != '00:00',
          },
          'Viernes': {
            'start': TimeOfDay(
              hour: int.parse(schedule.fridayStart.split(':')[0]),
              minute: int.parse(schedule.fridayStart.split(':')[1])
            ),
            'end': TimeOfDay(
              hour: int.parse(schedule.fridayEnd.split(':')[0]),
              minute: int.parse(schedule.fridayEnd.split(':')[1])
            ),
            'active': schedule.fridayStart != '00:00' || schedule.fridayEnd != '00:00',
          },
          'Sábado': {
            'start': TimeOfDay(
              hour: int.parse(schedule.saturdayStart.split(':')[0]),
              minute: int.parse(schedule.saturdayStart.split(':')[1])
            ),
            'end': TimeOfDay(
              hour: int.parse(schedule.saturdayEnd.split(':')[0]),
              minute: int.parse(schedule.saturdayEnd.split(':')[1])
            ),
            'active': schedule.saturdayStart != '00:00' || schedule.saturdayEnd != '00:00',
          },
          'Domingo': {
            'start': TimeOfDay(
              hour: int.parse(schedule.sundayStart.split(':')[0]),
              minute: int.parse(schedule.sundayStart.split(':')[1])
            ),
            'end': TimeOfDay(
              hour: int.parse(schedule.sundayEnd.split(':')[0]),
              minute: int.parse(schedule.sundayEnd.split(':')[1])
            ),
            'active': schedule.sundayStart != '00:00' || schedule.sundayEnd != '00:00',
          },
        };
        });
      }

      if (mounted) {
        _fadeController.forward();
        _slideController.forward();
      }
    } catch (e) {
      AppLogger.error('❌ Error al cargar perfil: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceColor,
      // UI: Sin AppBar - la portada reemplaza el header
      body: _isLoading ? _buildLoadingState() : _buildProfile(),
    );
  }
  
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(ModernTheme.rappiOrange),
          ),
          SizedBox(height: 16),
          Text(
            'Cargando perfil...',
            style: TextStyle(
              color: context.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProfile() {
    // ✅ CRÍTICO: Validar que _profile no sea null antes de renderizar
    if (_profile == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: ModernTheme.error),
            SizedBox(height: 16),
            Text(
              'No se pudo cargar el perfil',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.primaryText,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Por favor, intenta nuevamente',
              style: TextStyle(
                color: context.secondaryText,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.rappiOrange,
              ),
              child: Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              children: [
                // Profile header
                _buildProfileHeader(),

                // Stats overview
                _buildStatsOverview(),
                
                // Personal information
                _buildPersonalInfoSection(),
                
                // Vehicle information
                _buildVehicleInfoSection(),

                // ✅ NUEVO: Documentos del conductor
                if (_documents != null && _documents!.isNotEmpty)
                  _buildDocumentsSection(),

                // Métodos de retiro están en wallet_screen.dart

                // Achievements
                _buildAchievementsSection(),
                
                // Preferences
                _buildPreferencesSection(),
                
                // Work schedule
                _buildWorkScheduleSection(),
                
                SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildProfileHeader() {
    // UI: Estilo LinkedIn - portada naranja (height 200) + avatar overlapping + rating prominente
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - _slideAnimation.value)),
          child: SizedBox(
            child: Column(
              children: [
                // Portada (cover) con gradiente naranja
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    // Imagen de portada height 200
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [ModernTheme.rappiOrange, ModernTheme.rappiOrange.withValues(alpha: 0.75)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Patron decorativo
                          Positioned(
                            right: -20,
                            top: -20,
                            child: Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                          ),
                          Positioned(
                            left: -30,
                            bottom: -30,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                          ),
                          // Botón volver
                          SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Avatar circular overlapping (Positioned)
                    Positioned(
                      bottom: -48,
                      child: Stack(
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              gradient: _profile!.profileImageUrl.isEmpty
                                  ? LinearGradient(
                                      colors: [ModernTheme.rappiOrange.withValues(alpha: 0.5), ModernTheme.rappiOrange],
                                    )
                                  : null,
                              image: _profile!.profileImageUrl.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(_profile!.profileImageUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: _profile!.profileImageUrl.isEmpty
                                ? const Icon(Icons.person, size: 48, color: Colors.white)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _changeProfileImage,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: ModernTheme.rappiOrange, width: 2),
                                ),
                                child: const Icon(Icons.camera_alt, color: ModernTheme.rappiOrange, size: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Espacio para el avatar overlapping
                const SizedBox(height: 60),

                // Nombre y rating prominente
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Text(
                        _profile!.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: context.primaryText,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Rating prominente
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: ModernTheme.rappiOrange.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ...List.generate(5, (index) => Icon(
                              Icons.star,
                              size: 18,
                              color: index < _profile!.rating.floor()
                                  ? Colors.amber
                                  : Colors.amber.withValues(alpha: 0.3),
                            )),
                            const SizedBox(width: 8),
                            Text(
                              '${_profile!.rating}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: ModernTheme.rappiOrange,
                              ),
                            ),
                            Text(
                              ' (${_profile!.totalTrips} viajes)',
                              style: TextStyle(fontSize: 13, color: context.secondaryText),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Miembro desde ${_formatMemberSince(_profile!.memberSince)}',
                        style: TextStyle(color: context.secondaryText, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsOverview() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Viajes',
              '${_profile!.totalTrips}',
              Icons.directions_car,
              ModernTheme.primaryBlue,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Kilómetros',
              '${(_profile!.totalDistance / 1000).toStringAsFixed(1)}K',
              Icons.straighten,
              ModernTheme.success,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Ganancias',
              _profile!.totalEarnings.toCurrencyCompact(),
              Icons.account_balance_wallet, // ✅ Cambiado de attach_money ($) a wallet
              ModernTheme.warning,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.getCardShadow(context),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(height: 8),
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
              color: context.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPersonalInfoSection() {
    return _buildSection(
      'Información Personal',
      Icons.person,
      ModernTheme.primaryBlue,
      [
        if (_isEditingPersonal) ...[
          Form(
            key: _personalFormKey,
            child: Column(
              children: [
                _buildTextFormField(
                  controller: _nameController,
                  label: 'Nombre completo',
                  icon: Icons.person,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa tu nombre completo';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                _buildTextFormField(
                  controller: _phoneController,
                  label: 'Teléfono',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa tu teléfono';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                _buildTextFormField(
                  controller: _emailController,
                  label: 'Correo electrónico',
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa tu email';
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                      return 'Ingresa un email válido';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                _buildTextFormField(
                  controller: _bioController,
                  label: 'Descripción personal',
                  icon: Icons.description,
                  maxLines: 3,
                  validator: (value) {
                    if (value != null && value.length > 200) {
                      return 'Máximo 200 caracteres';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ] else ...[
          _buildInfoRow('Nombre', _profile!.name, Icons.person),
          _buildInfoRow('Teléfono', _profile!.phone, Icons.phone),
          _buildInfoRow('Email', _profile!.email, Icons.email),
          if (_profile!.bio.isNotEmpty)
            _buildInfoRow('Bio', _profile!.bio, Icons.description),
        ],
        
        SizedBox(height: 20),

        // Emergency contact
        Text(
          'Contacto de Emergencia',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: ModernTheme.error,
          ),
        ),
        SizedBox(height: 12),

        if (_isEditingPersonal) ...[
          _buildTextFormField(
            controller: _emergencyContactController,
            label: 'Nombre del contacto',
            icon: Icons.emergency,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa el nombre del contacto';
              }
              return null;
            },
          ),
          SizedBox(height: 16),
          _buildTextFormField(
            controller: _emergencyPhoneController,
            label: 'Teléfono de emergencia',
            icon: Icons.phone_in_talk,
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa el teléfono de emergencia';
              }
              return null;
            },
          ),
        ] else ...[
          _buildInfoRow('Nombre', _profile!.emergencyContact.name, Icons.emergency),
          _buildInfoRow('Teléfono', _profile!.emergencyContact.phone, Icons.phone_in_talk),
          _buildInfoRow('Relación', _profile!.emergencyContact.relationship, Icons.family_restroom),
        ],

        // ✅ NUEVO: Botones de acción cuando está en modo edición
        if (_isEditingPersonal) ...[
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isEditingPersonal = false;
                      // Restaurar valores originales
                      _nameController.text = _profile!.name;
                      _phoneController.text = _profile!.phone;
                      _emailController.text = _profile!.email;
                      _bioController.text = _profile!.bio;
                      _emergencyContactController.text = _profile!.emergencyContact.name;
                      _emergencyPhoneController.text = _profile!.emergencyContact.phone;
                    });
                  },
                  icon: Icon(Icons.cancel, color: ModernTheme.error),
                  label: Text('Cancelar', style: TextStyle(color: ModernTheme.error)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: ModernTheme.error),
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saveProfile,
                  icon: Icon(Icons.save, color: Theme.of(context).colorScheme.onPrimary),
                  label: Text('Guardar', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ModernTheme.success,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
      onEdit: _isEditingPersonal ? null : () => _toggleEditPersonal(),
    );
  }

  // ✅ NUEVO: Toggle de edición para Información Personal
  void _toggleEditPersonal() {
    setState(() {
      _isEditingPersonal = !_isEditingPersonal;
    });
  }

  // ✅ CONVERTIDO A INLINE: Sección de Información del Vehículo
  Widget _buildVehicleInfoSection() {
    return _buildSection(
      'Información del Vehículo',
      Icons.directions_car,
      ModernTheme.rappiOrange,
      [
        if (_isEditingVehicle) ...[
          Form(
            key: _vehicleFormKey,
            child: Column(
              children: [
                _buildTextFormField(
                  controller: _makeController,
                  label: 'Marca',
                  icon: Icons.business,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa la marca del vehículo';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                _buildTextFormField(
                  controller: _modelController,
                  label: 'Modelo',
                  icon: Icons.drive_eta,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa el modelo del vehículo';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                _buildTextFormField(
                  controller: _yearController,
                  label: 'Año',
                  icon: Icons.calendar_today,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa el año del vehículo';
                    }
                    final year = int.tryParse(value);
                    if (year == null || year < 1900 || year > DateTime.now().year + 1) {
                      return 'Ingresa un año válido';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                _buildTextFormField(
                  controller: _colorController,
                  label: 'Color',
                  icon: Icons.palette,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa el color del vehículo';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                _buildTextFormField(
                  controller: _plateController,
                  label: 'Placa',
                  icon: Icons.confirmation_number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa la placa del vehículo';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                _buildTextFormField(
                  controller: _capacityController,
                  label: 'Capacidad de pasajeros',
                  icon: Icons.people,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa la capacidad';
                    }
                    final capacity = int.tryParse(value);
                    if (capacity == null || capacity < 1 || capacity > 50) {
                      return 'Ingresa una capacidad válida (1-50)';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ] else ...[
          _buildInfoRow('Marca', _profile!.vehicleInfo.make, Icons.directions_car),
          _buildInfoRow('Modelo', _profile!.vehicleInfo.model, Icons.drive_eta),
          _buildInfoRow('Año', '${_profile!.vehicleInfo.year}', Icons.calendar_today),
          _buildInfoRow('Color', _profile!.vehicleInfo.color, Icons.palette),
          _buildInfoRow('Placa', _profile!.vehicleInfo.plate, Icons.confirmation_number),
          _buildInfoRow('Capacidad', '${_profile!.vehicleInfo.capacity} pasajeros', Icons.people),
        ],

        // Botones de acción
        if (_isEditingVehicle) ...[
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isEditingVehicle = false;
                      // Restaurar valores originales
                      _makeController.text = _profile!.vehicleInfo.make;
                      _modelController.text = _profile!.vehicleInfo.model;
                      _yearController.text = '${_profile!.vehicleInfo.year}';
                      _colorController.text = _profile!.vehicleInfo.color;
                      _plateController.text = _profile!.vehicleInfo.plate;
                      _capacityController.text = '${_profile!.vehicleInfo.capacity}';
                    });
                  },
                  icon: Icon(Icons.cancel, color: ModernTheme.error),
                  label: Text('Cancelar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ModernTheme.error,
                    side: BorderSide(color: ModernTheme.error),
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saveVehicleInfo,
                  icon: Icon(Icons.save, color: Theme.of(context).colorScheme.onPrimary),
                  label: Text('Guardar', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ModernTheme.success,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
      onEdit: _isEditingVehicle ? null : () => _toggleEditVehicle(),
    );
  }

  // ✅ NUEVO: Toggle de edición para Información del Vehículo
  void _toggleEditVehicle() {
    setState(() {
      _isEditingVehicle = !_isEditingVehicle;
    });
  }

  void _toggleEditPreferences() {
    setState(() {
      _isEditingPreferences = !_isEditingPreferences;
    });
  }

  void _toggleEditSchedule() {
    setState(() {
      _isEditingSchedule = !_isEditingSchedule;
    });
  }

  // ✅ ELIMINADO: _showEditVehicleDialog() - Ahora usa edición inline

  // ✅ NUEVO: Sección de documentos del conductor
  Widget _buildDocumentsSection() {
    // Ronda 235: los IDs deben coincidir con los doc_type reales del backend
    // (dni_front, dni_back, license_front, license_back, soat,
    // tarjeta_propiedad, ownership, selfie, vehicle_photo). Antes usaba
    // legacy Firebase (dniPhoto/licensePhoto/etc) → los labels no salían y
    // solo se veía el key técnico con guiones bajos.
    final documentLabels = {
      'dni_front':          'DNI (frente)',
      'dni_back':           'DNI (reverso)',
      'license_front':      'Licencia de conducir (frente)',
      'license_back':       'Licencia de conducir (reverso)',
      'soat':               'SOAT vigente',
      'tarjeta_propiedad':  'Tarjeta de propiedad (frente)',
      'ownership':          'Tarjeta de propiedad (reverso)',
      'selfie':             'Selfie del conductor',
      'vehicle_photo':      'Foto del vehículo',
    };

    final documentIcons = {
      'dni_front':          Icons.badge,
      'dni_back':           Icons.badge_outlined,
      'license_front':      Icons.credit_card,
      'license_back':       Icons.credit_card_outlined,
      'soat':               Icons.verified_user_outlined,
      'tarjeta_propiedad':  Icons.article_outlined,
      'ownership':          Icons.article,
      'selfie':             Icons.person_outlined,
      'vehicle_photo':      Icons.directions_car,
    };

    return _buildSection(
      'Documentos Subidos',
      Icons.folder_outlined,
      ModernTheme.warning,
      [
        ..._documents!.entries.map((entry) {
          final label = documentLabels[entry.key] ?? entry.key;
          final icon = documentIcons[entry.key] ?? Icons.insert_drive_file;
          final hasDocument = entry.value.isNotEmpty;

          // Ronda 237: cada fila navega a la pantalla completa "Mis Documentos"
          // para que el driver pueda subir/reemplazar. Antes solo el lápiz
          // superior era tappeable — se veía como un listado de solo lectura.
          return InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DocumentsScreen()),
            ),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Icon(icon, size: 18, color: context.secondaryText),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.secondaryText,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Icon(
                            hasDocument ? Icons.check_circle : Icons.cancel,
                            size: 14,
                            color: hasDocument ? ModernTheme.success : ModernTheme.error,
                          ),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              hasDocument ? 'Subido' : 'No subido',
                              style: TextStyle(
                                fontSize: 14,
                                color: hasDocument ? ModernTheme.success : ModernTheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (hasDocument)
                  SizedBox(
                    width: 48,
                    child: IconButton(
                      icon: Icon(Icons.visibility, color: ModernTheme.primaryBlue, size: 20),
                      onPressed: () => _viewDocument(entry.key, entry.value),
                      tooltip: 'Ver documento',
                      padding: EdgeInsets.zero,
                    ),
                  ),
                Icon(Icons.chevron_right, size: 18, color: context.secondaryText),
              ],
            ),
            ),
          );
        }),
      ],
      onEdit: () {
        // Navegar a la pantalla de documentos
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DocumentsScreen(),
          ),
        );
      },
    );
  }

  // ✅ NUEVO: Sección de configuración de métodos de retiro
  Widget _buildWithdrawalMethodsSection() {
    return _buildSection(
      'Métodos de Retiro',
      Icons.account_balance_wallet,
      ModernTheme.primaryBlue,
      [
        Text(
          'Configura tus métodos de retiro para recibir tus ganancias',
          style: TextStyle(
            fontSize: 14,
            color: context.secondaryText,
          ),
        ),
        SizedBox(height: 16),

        // Cuenta bancaria
        _buildPaymentMethodCard(
          'Cuenta Bancaria',
          'Retiros en 1-2 días hábiles',
          Icons.account_balance,
          ModernTheme.success,
          () => _configurePaymentMethod('bank'),
        ),

        SizedBox(height: 12),

        // Tarjeta de débito
        _buildPaymentMethodCard(
          'Tarjeta de Débito',
          'Retiros instantáneos',
          Icons.credit_card,
          ModernTheme.warning,
          () => _configurePaymentMethod('card'),
        ),

        SizedBox(height: 12),

        // Efectivo en oficina
        _buildPaymentMethodCard(
          'Efectivo en Oficina',
          'Retiro inmediato en nuestras oficinas',
          Icons.store,
          ModernTheme.info,
          () => _configurePaymentMethod('cash'),
        ),
      ],
      onEdit: () {
        // Navegar a la pantalla de configuración de retiros
        final userId = _authUserId;
        if (userId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EarningsWithdrawalScreen(driverId: userId),
            ),
          );
        }
      },
    );
  }

  Widget _buildPaymentMethodCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.primaryText,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.secondaryText,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }

  /// Ronda 235: en vez de mostrar la URL del documento, abre un modal con
  /// la imagen real (fetch autenticado + bytes) + botón "Reemplazar" que
  /// llama al image_picker y re-sube al backend con el mismo doc_type.
  void _viewDocument(String documentType, String url) {
    final labels = {
      'dni_front': 'DNI (frente)', 'dni_back': 'DNI (reverso)',
      'license_front': 'Licencia (frente)', 'license_back': 'Licencia (reverso)',
      'soat': 'SOAT vigente', 'tarjeta_propiedad': 'Tarjeta de propiedad (frente)',
      'ownership': 'Tarjeta de propiedad (reverso)',
      'selfie': 'Selfie del conductor', 'vehicle_photo': 'Foto del vehículo',
    };
    // Ronda 235: mapping cliente→backend scope para el upload de reemplazo.
    const clientToScope = {
      'dni_front': 'identity_front', 'dni_back': 'identity_back',
      'license_front': 'driver_license', 'license_back': 'driver_license',
      'soat': 'soat', 'tarjeta_propiedad': 'vehicle_registration',
      'ownership': 'vehicle_registration',
      'selfie': 'profile_photo', 'vehicle_photo': 'vehicle_photo',
    };
    final label = labels[documentType] ?? documentType;

    showDialog(
      context: context,
      builder: (dialogCtx) => _DocumentPreviewDialog(
        docType: documentType,
        label: label,
        url: url,
        scope: clientToScope[documentType] ?? 'misc',
        onReplaced: () async {
          Navigator.pop(dialogCtx);
          await _loadProfile();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Documento reemplazado. Pendiente de revisión.'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }

  // ✅ REAL: Configurar método de retiro con formularios completos
  void _configurePaymentMethod(String method) async {
    if (method == 'bank') {
      _showBankAccountForm();
    } else if (method == 'card') {
      _showDebitCardForm();
    } else if (method == 'cash') {
      _showCashPickupInfo();
    }
  }

  // ✅ REAL: Formulario de cuenta bancaria
  void _showBankAccountForm() {
    final formKey = GlobalKey<FormState>(debugLabel: 'bankAccountForm');
    final accountTypeController = TextEditingController(text: 'savings');
    final accountNumberController = TextEditingController();
    final cciController = TextEditingController();
    final holderNameController = TextEditingController(text: _profile?.name ?? '');
    final holderDniController = TextEditingController();

    // Bancos de Perú
    final banks = [
      'BCP - Banco de Crédito del Perú',
      'BBVA',
      'Interbank',
      'Scotiabank',
      'Banco de la Nación',
      'Banco Pichincha',
      'BanBif',
      'Banco Falabella',
      'Banco Ripley',
      'Otro',
    ];
    String selectedBank = banks[0];

    // Ronda 214: garantizar dispose de los 5 controllers cuando el diálogo
    // cierre por CUALQUIER vía (pop programático, back button, tap fuera).
    // Antes se disponían solo en los botones Guardar/Cancelar → cierres por
    // back button dejaban los controllers colgados escuchando notificaciones
    // del framework hasta el final del proceso.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.account_balance, color: ModernTheme.success),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Cuenta Bancaria',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configura tu cuenta bancaria para recibir retiros en 1-2 días hábiles',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.secondaryText,
                    ),
                  ),
                  SizedBox(height: 16),

                  // Banco
                  DropdownButtonFormField<String>(
                    value: selectedBank,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Banco',
                      prefixIcon: Icon(Icons.account_balance),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: banks.map((bank) {
                      return DropdownMenuItem(
                        value: bank,
                        child: Text(
                          bank,
                          style: TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedBank = value!);
                    },
                  ),
                  SizedBox(height: 16),

                  // Tipo de cuenta
                  DropdownButtonFormField<String>(
                    value: accountTypeController.text.isEmpty ||
                           (accountTypeController.text != 'savings' && accountTypeController.text != 'checking')
                        ? 'savings'
                        : accountTypeController.text,
                    decoration: InputDecoration(
                      labelText: 'Tipo de Cuenta',
                      prefixIcon: Icon(Icons.account_box),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      DropdownMenuItem(value: 'savings', child: Text('Ahorros')),
                      DropdownMenuItem(value: 'checking', child: Text('Corriente')),
                    ],
                    onChanged: (value) {
                      setState(() => accountTypeController.text = value!);
                    },
                  ),
                  SizedBox(height: 16),

                  // Número de cuenta
                  TextFormField(
                    controller: accountNumberController,
                    keyboardType: TextInputType.number,
                    maxLength: 20,
                    decoration: InputDecoration(
                      labelText: 'Número de Cuenta',
                      prefixIcon: Icon(Icons.numbers),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      counterText: '',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa el número de cuenta';
                      }
                      if (value.length < 10) {
                        return 'Mínimo 10 dígitos';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  // CCI
                  TextFormField(
                    controller: cciController,
                    keyboardType: TextInputType.number,
                    maxLength: 20,
                    decoration: InputDecoration(
                      labelText: 'CCI (Código de Cuenta Interbancaria)',
                      prefixIcon: Icon(Icons.qr_code),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      counterText: '',
                      hintText: '20 dígitos',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa el CCI';
                      }
                      if (value.length != 20) {
                        return 'El CCI debe tener 20 dígitos';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  // Titular
                  TextFormField(
                    controller: holderNameController,
                    decoration: InputDecoration(
                      labelText: 'Titular de la Cuenta',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa el nombre del titular';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  // DNI del titular
                  TextFormField(
                    controller: holderDniController,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    decoration: InputDecoration(
                      labelText: 'DNI del Titular',
                      prefixIcon: Icon(Icons.badge),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      counterText: '',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa el DNI';
                      }
                      if (value.length != 8) {
                        return 'El DNI debe tener 8 dígitos';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  // Guardar via backend Node.
                  // El endpoint /api/payment-methods solo persiste (methodType, label, isDefault);
                  // los datos ricos (banco, cuenta, CCI, DNI) quedan pendientes de un endpoint dedicado.
                  try {
                    if (_authUserId == null) return;
                    final label =
                        '$selectedBank · ****${accountNumberController.text.trim().length >= 4 ? accountNumberController.text.trim().substring(accountNumberController.text.trim().length - 4) : accountNumberController.text.trim()}';
                    await _api.addPaymentMethod(
                      methodType: 'bank',
                      label: label,
                      isDefault: true,
                    );

                    // ignore: use_build_context_synchronously
                    Navigator.pop(context);

                    if (mounted) {
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ Cuenta bancaria guardada. Pendiente de verificación.'),
                          backgroundColor: ModernTheme.success,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  } catch (e) {
                    AppLogger.error('❌ Error al guardar cuenta bancaria: $e');
                    if (mounted) {
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al guardar. Intenta nuevamente.'),
                          backgroundColor: ModernTheme.error,
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.success,
              ),
              child: Text('Guardar'),
            ),
          ],
        ),
      ),
    ).then((_) {
      // Ronda 214: dispose garantizado independientemente de cómo cerró.
      accountTypeController.dispose();
      accountNumberController.dispose();
      cciController.dispose();
      holderNameController.dispose();
      holderDniController.dispose();
    });
  }

  // ✅ REAL: Formulario de tarjeta de débito
  void _showDebitCardForm() {
    final formKey = GlobalKey<FormState>(debugLabel: 'debitCardForm');
    final cardNumberController = TextEditingController();
    final cardHolderController = TextEditingController(text: _profile?.name ?? '');

    final banks = [
      'BCP - Banco de Crédito del Perú',
      'BBVA',
      'Interbank',
      'Scotiabank',
      'Banco de la Nación',
      'Otro',
    ];
    String selectedBank = banks[0];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.credit_card, color: ModernTheme.warning),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Tarjeta de Débito',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configura tu tarjeta de débito para retiros instantáneos',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.secondaryText,
                    ),
                  ),
                  SizedBox(height: 16),

                  // Banco emisor
                  DropdownButtonFormField<String>(
                    value: selectedBank,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Banco Emisor',
                      prefixIcon: Icon(Icons.account_balance),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: banks.map((bank) {
                      return DropdownMenuItem(
                        value: bank,
                        child: Text(
                          bank,
                          style: TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedBank = value!);
                    },
                  ),
                  SizedBox(height: 16),

                  // Últimos 4 dígitos
                  TextFormField(
                    controller: cardNumberController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: InputDecoration(
                      labelText: 'Últimos 4 Dígitos de la Tarjeta',
                      prefixIcon: Icon(Icons.credit_card),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      counterText: '',
                      hintText: '1234',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa los últimos 4 dígitos';
                      }
                      if (value.length != 4) {
                        return 'Deben ser 4 dígitos';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  // Titular
                  TextFormField(
                    controller: cardHolderController,
                    decoration: InputDecoration(
                      labelText: 'Titular de la Tarjeta',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa el nombre del titular';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ModernTheme.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: ModernTheme.info, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Por seguridad, solo guardamos los últimos 4 dígitos',
                            style: TextStyle(
                              fontSize: 11,
                              color: ModernTheme.info,
                            ),
                            overflow: TextOverflow.visible,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  // Guardar via backend Node (solo metadata: methodType + label).
                  try {
                    if (_authUserId == null) return;
                    final label = '$selectedBank · ****${cardNumberController.text.trim()}';
                    await _api.addPaymentMethod(
                      methodType: 'card',
                      label: label,
                      isDefault: false,
                    );

                    // ignore: use_build_context_synchronously
                    Navigator.pop(context);

                    if (mounted) {
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ Tarjeta de débito guardada. Pendiente de verificación.'),
                          backgroundColor: ModernTheme.success,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  } catch (e) {
                    AppLogger.error('❌ Error al guardar tarjeta: $e');
                    if (mounted) {
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al guardar. Intenta nuevamente.'),
                          backgroundColor: ModernTheme.error,
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.warning,
              ),
              child: Text('Guardar'),
            ),
          ],
        ),
      ),
    ).then((_) {
      // Ronda 214: dispose de los 2 controllers del debit card form al cerrar.
      cardNumberController.dispose();
      cardHolderController.dispose();
    });
  }

  // ✅ REAL: Información de retiro en efectivo
  void _showCashPickupInfo() async {
    if (_authUserId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.store, color: ModernTheme.info),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Efectivo en Oficina',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Retira tus ganancias en efectivo en nuestras oficinas',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            _buildInfoItem(Icons.location_on, 'Av. Principal 123, Lima'),
            _buildInfoItem(Icons.access_time, 'Lunes a Viernes: 9:00 AM - 6:00 PM'),
            _buildInfoItem(Icons.access_time, 'Sábados: 9:00 AM - 1:00 PM'),
            _buildInfoItem(Icons.badge, 'Presenta tu DNI al retirar'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ModernTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: ModernTheme.success, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Retiro inmediato, sin comisiones',
                      style: TextStyle(
                        fontSize: 12,
                        color: ModernTheme.success,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Guardar via backend Node (methodType 'cash').
              try {
                await _api.addPaymentMethod(
                  methodType: 'cash',
                  label: 'Efectivo en oficina',
                  isDefault: false,
                );

                // ignore: use_build_context_synchronously
                Navigator.pop(context);

                if (mounted) {
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Método de efectivo activado'),
                      backgroundColor: ModernTheme.success,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                AppLogger.error('❌ Error al activar efectivo: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.info,
            ),
            child: Text('Activar Método'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.secondaryText),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12),
              overflow: TextOverflow.visible,
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsSection() {
    return _buildSection(
      'Logros y Reconocimientos',
      Icons.emoji_events,
      Colors.amber,
      [
        // Ronda 236: aspect ratio 0.85 (más alto que ancho) porque el card
        // ahora incluye barra de progreso + counter "X / Y" en logros
        // bloqueados. Con 1.2 el contador se superponía sobre el card
        // vecino de abajo (visible en el screenshot del user).
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: _profile!.achievements.length,
          itemBuilder: (context, index) {
            final achievement = _profile!.achievements[index];
            return _buildAchievementCard(achievement);
          },
        ),
      ],
    );
  }
  
  Widget _buildAchievementCard(Achievement achievement) {
    // Ronda 235: card diferenciada — desbloqueado (dorado) vs bloqueado (gris
    // con candado). Muestra barra de progreso cuando el logro tiene meta.
    final unlocked = achievement.isUnlocked;
    final color = unlocked ? Colors.amber : Colors.grey;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: unlocked ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: unlocked ? 0.4 : 0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              unlocked ? Icons.emoji_events : Icons.lock_outline,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            achievement.name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: unlocked ? null : context.secondaryText,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            achievement.description,
            style: TextStyle(
              fontSize: 10,
              color: context.secondaryText,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (!unlocked && achievement.progressTarget > 0) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: achievement.progress,
                minHeight: 4,
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${achievement.progressCurrent} / ${achievement.progressTarget}',
              style: TextStyle(fontSize: 9, color: context.secondaryText),
            ),
          ],
        ],
      ),
    );
  }

  /// Ronda 235: catálogo con 8 logros y su estado real basado en las stats
  /// del conductor. Antes lista vacía → sección "Logros" siempre en blanco.
  List<Achievement> _buildAchievementsCatalog({
    required int totalTrips,
    required double rating,
    required double totalEarnings,
    required DateTime memberSince,
  }) {
    final daysMember = DateTime.now().difference(memberSince).inDays;
    Achievement unlockOr(String id, String name, String desc, {required bool met, required int current, required int target}) {
      return Achievement(
        id: id, name: name, description: desc, iconUrl: '',
        unlockedDate: met ? DateTime.now() : null,
        progressCurrent: current > target ? target : current,
        progressTarget: target,
      );
    }
    return [
      unlockOr('first_trip', 'Primer viaje', 'Completa tu primer viaje',
          met: totalTrips >= 1, current: totalTrips, target: 1),
      unlockOr('trips_10', '10 viajes', 'Completa 10 viajes',
          met: totalTrips >= 10, current: totalTrips, target: 10),
      unlockOr('trips_50', '50 viajes', 'Alcanza 50 viajes',
          met: totalTrips >= 50, current: totalTrips, target: 50),
      unlockOr('trips_100', '100 viajes', 'Alcanza 100 viajes',
          met: totalTrips >= 100, current: totalTrips, target: 100),
      unlockOr('trips_500', 'Conductor experto', '500 viajes completados',
          met: totalTrips >= 500, current: totalTrips, target: 500),
      unlockOr('rating_gold', 'Estrella dorada', 'Mantén rating ≥ 4.8',
          met: rating >= 4.8, current: (rating * 10).round(), target: 48),
      unlockOr('earnings_1k', 'Mil soles', 'Gana S/ 1000 en total',
          met: totalEarnings >= 1000, current: totalEarnings.round(), target: 1000),
      unlockOr('veteran', 'Veterano', 'Cumple 90 días en la app',
          met: daysMember >= 90, current: daysMember, target: 90),
    ];
  }
  
  Widget _buildPreferencesSection() {
    return _buildSection(
      'Preferencias de Trabajo',
      Icons.settings,
      Colors.purple,
      [
        if (_isEditingPreferences) ...[
          // ✅ MODO EDICIÓN - Formulario inline
          Form(
            key: _preferencesFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Acepta mascotas
                SwitchListTile(
                  title: Text('Acepta mascotas'),
                  subtitle: Text('Permitir pasajeros con mascotas'),
                  value: _acceptPets,
                  activeColor: Colors.purple,
                  onChanged: (value) {
                    setState(() {
                      _acceptPets = value;
                    });
                  },
                ),
                SizedBox(height: 8),

                // Acepta fumadores
                SwitchListTile(
                  title: Text('Permite fumar'),
                  subtitle: Text('Permitir pasajeros que fuman'),
                  value: _acceptSmoking,
                  activeColor: Colors.purple,
                  onChanged: (value) {
                    setState(() {
                      _acceptSmoking = value;
                    });
                  },
                ),
                SizedBox(height: 16),

                // Música preferida
                DropdownButtonFormField<String>(
                  value: _musicPreference,
                  decoration: InputDecoration(
                    labelText: 'Música preferida',
                    prefixIcon: Icon(Icons.music_note, color: Colors.purple),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: [
                    'Ninguna',
                    'Pop',
                    'Rock',
                    'Clásica',
                    'Reggaetón',
                    'Salsa',
                    'Electrónica',
                    'Jazz',
                  ].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _musicPreference = newValue ?? 'Ninguna';
                    });
                  },
                ),
                SizedBox(height: 16),

                // Idiomas
                Text(
                  'Idiomas que hablas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.primaryText,
                  ),
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'Español',
                    'Inglés',
                    'Francés',
                    'Alemán',
                    'Italiano',
                    'Portugués',
                  ].map((String language) {
                    final isSelected = _languages.contains(language);
                    return FilterChip(
                      label: Text(language),
                      selected: isSelected,
                      onSelected: (bool selected) {
                        setState(() {
                          if (selected) {
                            _languages.add(language);
                          } else {
                            if (_languages.length > 1) {
                              _languages.remove(language);
                            } else {
                              // Al menos un idioma debe estar seleccionado
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Debes seleccionar al menos un idioma'),
                                  backgroundColor: ModernTheme.warning,
                                ),
                              );
                            }
                          }
                        });
                      },
                      selectedColor: Colors.purple.withValues(alpha: 0.2),
                      checkmarkColor: Colors.purple,
                    );
                  }).toList(),
                ),
                SizedBox(height: 16),

                // Distancia máxima de viaje
                Text(
                  'Distancia máxima de viaje: ${_maxTripDistance.toStringAsFixed(0)} km',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.primaryText,
                  ),
                ),
                SizedBox(height: 8),
                Slider(
                  value: _maxTripDistance,
                  min: 5,
                  max: 100,
                  divisions: 19,
                  label: '${_maxTripDistance.toStringAsFixed(0)} km',
                  activeColor: Colors.purple,
                  onChanged: (double value) {
                    setState(() {
                      _maxTripDistance = value;
                    });
                  },
                ),
                SizedBox(height: 16),

                // Zonas preferidas
                Text(
                  'Zonas preferidas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.primaryText,
                  ),
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'Centro',
                    'Norte',
                    'Sur',
                    'Este',
                    'Oeste',
                    'Aeropuerto',
                    'Zona Industrial',
                    'Zona Comercial',
                  ].map((String zone) {
                    final isSelected = _preferredZones.contains(zone);
                    return FilterChip(
                      label: Text(zone),
                      selected: isSelected,
                      onSelected: (bool selected) {
                        setState(() {
                          if (selected) {
                            _preferredZones.add(zone);
                          } else {
                            _preferredZones.remove(zone);
                          }
                        });
                      },
                      selectedColor: Colors.purple.withValues(alpha: 0.2),
                      checkmarkColor: Colors.purple,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ] else ...[
          // ✅ MODO VISTA - Información de solo lectura
          _buildPreferenceRow('Acepta mascotas', _profile!.preferences.acceptPets),
          _buildPreferenceRow('Permite fumar', _profile!.preferences.acceptSmoking),
          _buildInfoRow('Música preferida', _profile!.preferences.musicPreference, Icons.music_note),
          _buildInfoRow('Idiomas', _profile!.preferences.languages.join(', '), Icons.language),
          _buildInfoRow('Distancia máxima', '${_profile!.preferences.maxTripDistance} km', Icons.straighten),

          SizedBox(height: 12),
          Text(
            'Zonas preferidas:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: context.primaryText,
            ),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _profile!.preferences.preferredZones.map((zone) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  zone,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.purple,
                  ),
                ),
              );
            }).toList(),
          ),
        ],

        // ✅ BOTONES DE ACCIÓN (solo en modo edición)
        if (_isEditingPreferences) ...[
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      // Restaurar valores originales
                      _acceptPets = _profile!.preferences.acceptPets;
                      _acceptSmoking = _profile!.preferences.acceptSmoking;
                      _musicPreference = _profile!.preferences.musicPreference.isEmpty
                          ? 'Ninguna'
                          : _profile!.preferences.musicPreference;
                      _languages = List<String>.from(_profile!.preferences.languages);
                      _maxTripDistance = (_profile!.preferences.maxTripDistance).clamp(5.0, 100.0);
                      _preferredZones = List<String>.from(_profile!.preferences.preferredZones);
                      _isEditingPreferences = false;
                    });
                  },
                  icon: Icon(Icons.cancel, color: ModernTheme.error),
                  label: Text(
                    'Cancelar',
                    style: TextStyle(color: ModernTheme.error),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: ModernTheme.error),
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _savePreferences,
                  icon: Icon(Icons.save, color: Theme.of(context).colorScheme.onPrimary),
                  label: Text('Guardar', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
      onEdit: _isEditingPreferences ? null : () => _toggleEditPreferences(),
    );
  }
  
  Widget _buildWorkScheduleSection() {
    return _buildSection(
      'Horario de Trabajo',
      Icons.schedule,
      Colors.orange,
      [
        if (_isEditingSchedule) ...[
          // ✅ MODO EDICIÓN - Formulario inline con time pickers
          Form(
            key: _scheduleFormKey,
            child: Column(
              children: _weekSchedule.entries.map((entry) {
                final day = entry.key;
                final dayData = entry.value;

                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Fila: Día + Switch activo/inactivo
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              day,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Switch(
                              value: dayData['active'],
                              activeColor: Colors.orange,
                              onChanged: (value) {
                                setState(() {
                                  dayData['active'] = value;
                                });
                              },
                            ),
                          ],
                        ),

                        if (dayData['active']) ...[
                          SizedBox(height: 8),
                          Row(
                            children: [
                              // Hora de inicio
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: dayData['start'],
                                      builder: (context, child) {
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme: ColorScheme.light(
                                              primary: Colors.orange,
                                            ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        dayData['start'] = picked;
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Theme.of(context).dividerColor,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 16,
                                          color: Colors.orange,
                                        ),
                                        SizedBox(width: 8),
                                        Text('${dayData['start'].format(context)}'),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(Icons.arrow_forward, size: 16),
                              ),

                              // Hora de fin
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: dayData['end'],
                                      builder: (context, child) {
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme: ColorScheme.light(
                                              primary: Colors.orange,
                                            ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        dayData['end'] = picked;
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Theme.of(context).dividerColor,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 16,
                                          color: Colors.orange,
                                        ),
                                        SizedBox(width: 8),
                                        Text('${dayData['end'].format(context)}'),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ] else ...[
          // ✅ MODO VISTA - Información de solo lectura
          _buildScheduleRow('Lunes', _profile!.workSchedule.mondayStart, _profile!.workSchedule.mondayEnd),
          _buildScheduleRow('Martes', _profile!.workSchedule.tuesdayStart, _profile!.workSchedule.tuesdayEnd),
          _buildScheduleRow('Miércoles', _profile!.workSchedule.wednesdayStart, _profile!.workSchedule.wednesdayEnd),
          _buildScheduleRow('Jueves', _profile!.workSchedule.thursdayStart, _profile!.workSchedule.thursdayEnd),
          _buildScheduleRow('Viernes', _profile!.workSchedule.fridayStart, _profile!.workSchedule.fridayEnd),
          _buildScheduleRow('Sábado', _profile!.workSchedule.saturdayStart, _profile!.workSchedule.saturdayEnd),
          _buildScheduleRow('Domingo', _profile!.workSchedule.sundayStart, _profile!.workSchedule.sundayEnd),
        ],

        // ✅ BOTONES DE ACCIÓN (solo en modo edición)
        if (_isEditingSchedule) ...[
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      // Restaurar valores originales desde _profile
                      final schedule = _profile!.workSchedule;
                      _weekSchedule = {
                        'Lunes': {
                          'start': TimeOfDay(
                            hour: int.parse(schedule.mondayStart.split(':')[0]),
                            minute: int.parse(schedule.mondayStart.split(':')[1])
                          ),
                          'end': TimeOfDay(
                            hour: int.parse(schedule.mondayEnd.split(':')[0]),
                            minute: int.parse(schedule.mondayEnd.split(':')[1])
                          ),
                          'active': schedule.mondayStart != '00:00' || schedule.mondayEnd != '00:00',
                        },
                        'Martes': {
                          'start': TimeOfDay(
                            hour: int.parse(schedule.tuesdayStart.split(':')[0]),
                            minute: int.parse(schedule.tuesdayStart.split(':')[1])
                          ),
                          'end': TimeOfDay(
                            hour: int.parse(schedule.tuesdayEnd.split(':')[0]),
                            minute: int.parse(schedule.tuesdayEnd.split(':')[1])
                          ),
                          'active': schedule.tuesdayStart != '00:00' || schedule.tuesdayEnd != '00:00',
                        },
                        'Miércoles': {
                          'start': TimeOfDay(
                            hour: int.parse(schedule.wednesdayStart.split(':')[0]),
                            minute: int.parse(schedule.wednesdayStart.split(':')[1])
                          ),
                          'end': TimeOfDay(
                            hour: int.parse(schedule.wednesdayEnd.split(':')[0]),
                            minute: int.parse(schedule.wednesdayEnd.split(':')[1])
                          ),
                          'active': schedule.wednesdayStart != '00:00' || schedule.wednesdayEnd != '00:00',
                        },
                        'Jueves': {
                          'start': TimeOfDay(
                            hour: int.parse(schedule.thursdayStart.split(':')[0]),
                            minute: int.parse(schedule.thursdayStart.split(':')[1])
                          ),
                          'end': TimeOfDay(
                            hour: int.parse(schedule.thursdayEnd.split(':')[0]),
                            minute: int.parse(schedule.thursdayEnd.split(':')[1])
                          ),
                          'active': schedule.thursdayStart != '00:00' || schedule.thursdayEnd != '00:00',
                        },
                        'Viernes': {
                          'start': TimeOfDay(
                            hour: int.parse(schedule.fridayStart.split(':')[0]),
                            minute: int.parse(schedule.fridayStart.split(':')[1])
                          ),
                          'end': TimeOfDay(
                            hour: int.parse(schedule.fridayEnd.split(':')[0]),
                            minute: int.parse(schedule.fridayEnd.split(':')[1])
                          ),
                          'active': schedule.fridayStart != '00:00' || schedule.fridayEnd != '00:00',
                        },
                        'Sábado': {
                          'start': TimeOfDay(
                            hour: int.parse(schedule.saturdayStart.split(':')[0]),
                            minute: int.parse(schedule.saturdayStart.split(':')[1])
                          ),
                          'end': TimeOfDay(
                            hour: int.parse(schedule.saturdayEnd.split(':')[0]),
                            minute: int.parse(schedule.saturdayEnd.split(':')[1])
                          ),
                          'active': schedule.saturdayStart != '00:00' || schedule.saturdayEnd != '00:00',
                        },
                        'Domingo': {
                          'start': TimeOfDay(
                            hour: int.parse(schedule.sundayStart.split(':')[0]),
                            minute: int.parse(schedule.sundayStart.split(':')[1])
                          ),
                          'end': TimeOfDay(
                            hour: int.parse(schedule.sundayEnd.split(':')[0]),
                            minute: int.parse(schedule.sundayEnd.split(':')[1])
                          ),
                          'active': schedule.sundayStart != '00:00' || schedule.sundayEnd != '00:00',
                        },
                      };
                      _isEditingSchedule = false;
                    });
                  },
                  icon: Icon(Icons.cancel, color: ModernTheme.error),
                  label: Text(
                    'Cancelar',
                    style: TextStyle(color: ModernTheme.error),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: ModernTheme.error),
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saveWorkSchedule,
                  icon: Icon(Icons.save, color: Theme.of(context).colorScheme.onPrimary),
                  label: Text('Guardar', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
      onEdit: _isEditingSchedule ? null : () => _toggleEditSchedule(),
    );
  }
  
  Widget _buildScheduleRow(String day, String startTime, String endTime) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              day,
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 8),
          Flexible(
            flex: 3,
            child: Text(
              '$startTime - $endTime',
              style: TextStyle(
                color: context.secondaryText,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPreferenceRow(String label, bool value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 8),
          Icon(
            value ? Icons.check_circle : Icons.cancel,
            color: value ? ModernTheme.success : ModernTheme.error,
            size: 20,
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: context.secondaryText),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.secondaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // Ronda 235: mostrar la info del conductor en MAYÚSCULAS
                // (consistente con documentos oficiales tipo DNI).
                Text(
                  value.toUpperCase(),
                  style: TextStyle(
                    fontSize: 14,
                    color: context.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSection(
    String title,
    IconData icon,
    Color color,
    List<Widget> children, {
    VoidCallback? onEdit, // ✅ Parámetro opcional para acción de edición
  }) {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.getCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                // ✅ Mostrar botón de edición si se proporciona la función
                if (onEdit != null)
                  IconButton(
                    icon: Icon(Icons.edit, color: color, size: 20),
                    onPressed: onEdit,
                    tooltip: 'Editar',
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ModernTheme.rappiOrange, width: 2),
        ),
      ),
    );
  }
  
  String _formatMemberSince(DateTime date) {
    final months = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
                   'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return '${months[date.month - 1]} ${date.year}';
  }
  
  // ✅ OBSOLETO - Eliminado después de migrar todas las secciones
  // void _toggleEdit() {
  //   setState(() {
  //     _isEditing = !_isEditing;
  //   });
  // }

  // Guardar información personal via backend Node (RapiApiClient.updateMe)
  Future<void> _saveProfile() async {
    if (_personalFormKey.currentState!.validate()) {
      final messenger = ScaffoldMessenger.of(context);

      try {
        if (_authUserId == null) {
          throw Exception('Usuario no autenticado');
        }

        // El backend Node solo soporta campos básicos vía updateMe.
        // Bio, emergencyContact y otros extendidos por ahora no persisten en el server.
        await _api.updateMe(
          fullName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
        );

        // Contacto de emergencia: intentar guardarlo via /api/emergency-contacts
        try {
          if (_emergencyContactController.text.trim().isNotEmpty &&
              _emergencyPhoneController.text.trim().isNotEmpty) {
            await _api.addEmergencyContact(
              name: _emergencyContactController.text.trim(),
              phone: _emergencyPhoneController.text.trim(),
              relationship: _profile!.emergencyContact.relationship,
              isPrimary: true,
            );
          }
        } catch (e) {
          AppLogger.warning(userFriendlyError(e, fallback: 'No se pudo guardar contacto de emergencia'));
        }

        // Actualizar estado local
        if (!mounted) return;
        setState(() {
          _profile = DriverProfile(
            id: _profile!.id,
            name: _nameController.text,
            email: _emailController.text,
            phone: _phoneController.text,
            profileImageUrl: _profile!.profileImageUrl,
            rating: _profile!.rating,
            totalTrips: _profile!.totalTrips,
            totalDistance: _profile!.totalDistance,
            totalHours: _profile!.totalHours,
            totalEarnings: _profile!.totalEarnings,
            memberSince: _profile!.memberSince,
            bio: _bioController.text,
            emergencyContact: EmergencyContact(
              name: _emergencyContactController.text,
              phone: _emergencyPhoneController.text,
              relationship: _profile!.emergencyContact.relationship,
            ),
            preferences: _profile!.preferences,
            achievements: _profile!.achievements,
            vehicleInfo: _profile!.vehicleInfo,
            workSchedule: _profile!.workSchedule,
          );
          _isEditingPersonal = false;
        });

        messenger.showSnackBar(
          SnackBar(
            content: Text('Información personal actualizada exitosamente'),
            backgroundColor: ModernTheme.success,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(userFriendlyError(e, fallback: 'Error al actualizar')),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }

  // Guardar información del vehículo via backend Node (upsertVehicle)
  Future<void> _saveVehicleInfo() async {
    if (_vehicleFormKey.currentState!.validate()) {
      final messenger = ScaffoldMessenger.of(context);

      try {
        if (_authUserId == null) {
          throw Exception('Usuario no autenticado');
        }

        // Obtener valores de los controladores (TODO EN MAYÚSCULAS)
        final make = _makeController.text.trim().toUpperCase();
        final model = _modelController.text.trim().toUpperCase();
        final year = int.tryParse(_yearController.text.trim()) ?? DateTime.now().year;
        final color = _colorController.text.trim().toUpperCase();
        final plate = _plateController.text.trim().toUpperCase();
        final capacity = int.tryParse(_capacityController.text.trim()) ?? 4;

        // Persistir vehículo en backend Node
        await _api.upsertVehicle(
          vehicleType: 'sedan',
          plate: plate,
          make: make,
          model: model,
          color: color,
          year: year,
        );

        // Actualizar estado local
        if (!mounted) return;
        setState(() {
          _profile = DriverProfile(
            id: _profile!.id,
            name: _profile!.name,
            email: _profile!.email,
            phone: _profile!.phone,
            profileImageUrl: _profile!.profileImageUrl,
            rating: _profile!.rating,
            totalTrips: _profile!.totalTrips,
            totalDistance: _profile!.totalDistance,
            totalHours: _profile!.totalHours,
            totalEarnings: _profile!.totalEarnings,
            memberSince: _profile!.memberSince,
            bio: _profile!.bio,
            emergencyContact: _profile!.emergencyContact,
            preferences: _profile!.preferences,
            achievements: _profile!.achievements,
            vehicleInfo: VehicleInfo(
              make: make,
              model: model,
              year: year,
              color: color,
              plate: plate,
              capacity: capacity,
            ),
            workSchedule: _profile!.workSchedule,
          );
          _isEditingVehicle = false;
        });

        messenger.showSnackBar(
          SnackBar(
            content: Text('Información del vehículo actualizada exitosamente'),
            backgroundColor: ModernTheme.success,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(userFriendlyError(e, fallback: 'Error al actualizar')),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _savePreferences() async {
    if (_preferencesFormKey.currentState!.validate()) {
      try {
        if (_authUserId == null) {
          throw Exception('Usuario no autenticado');
        }

        // El backend Node aún no expone endpoint dedicado para preferences del driver.
        // Persistimos solo en memoria durante la sesión.
        AppLogger.info('Preferencias del conductor actualizadas en memoria');

        // Actualizar estado local
        setState(() {
          _profile = DriverProfile(
            id: _profile!.id,
            name: _profile!.name,
            email: _profile!.email,
            phone: _profile!.phone,
            profileImageUrl: _profile!.profileImageUrl,
            rating: _profile!.rating,
            totalTrips: _profile!.totalTrips,
            totalDistance: _profile!.totalDistance,
            totalHours: _profile!.totalHours,
            totalEarnings: _profile!.totalEarnings,
            memberSince: _profile!.memberSince,
            bio: _profile!.bio,
            emergencyContact: _profile!.emergencyContact,
            preferences: DriverPreferences(
              acceptPets: _acceptPets,
              acceptSmoking: _acceptSmoking,
              musicPreference: _musicPreference,
              languages: _languages,
              maxTripDistance: _maxTripDistance,
              preferredZones: _preferredZones,
            ),
            achievements: _profile!.achievements,
            vehicleInfo: _profile!.vehicleInfo,
            workSchedule: _profile!.workSchedule,
          );
          _isEditingPreferences = false;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Preferencias actualizadas exitosamente'),
            backgroundColor: ModernTheme.success,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFriendlyError(e, fallback: 'Error al actualizar preferencias')),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _saveWorkSchedule() async {
    try {
      if (_authUserId == null) {
        throw Exception('Usuario no autenticado');
      }

      // Validar que hora fin > hora inicio para días activos
      String? validationError;
      for (var entry in _weekSchedule.entries) {
        final day = entry.key;
        final dayData = entry.value;
        if (dayData['active']) {
          final start = dayData['start'] as TimeOfDay;
          final end = dayData['end'] as TimeOfDay;
          final startMinutes = start.hour * 60 + start.minute;
          final endMinutes = end.hour * 60 + end.minute;

          if (endMinutes <= startMinutes) {
            validationError = 'La hora de fin debe ser mayor que la hora de inicio en $day';
            break;
          }
        }
      }

      if (validationError != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(validationError),
            backgroundColor: ModernTheme.error,
          ),
        );
        return;
      }

      // Formatear horarios para persistencia
      String formatTime(TimeOfDay time) {
        return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      }

      // El backend Node aún no expone endpoint dedicado para workSchedule del driver.
      // Persistimos solo en memoria durante la sesión.
      AppLogger.info('Horario del conductor actualizado en memoria');

      // Actualizar estado local
      setState(() {
        _profile = DriverProfile(
          id: _profile!.id,
          name: _profile!.name,
          email: _profile!.email,
          phone: _profile!.phone,
          profileImageUrl: _profile!.profileImageUrl,
          rating: _profile!.rating,
          totalTrips: _profile!.totalTrips,
          totalDistance: _profile!.totalDistance,
          totalHours: _profile!.totalHours,
          totalEarnings: _profile!.totalEarnings,
          memberSince: _profile!.memberSince,
          bio: _profile!.bio,
          emergencyContact: _profile!.emergencyContact,
          preferences: _profile!.preferences,
          achievements: _profile!.achievements,
          vehicleInfo: _profile!.vehicleInfo,
          workSchedule: WorkSchedule(
            mondayStart: _weekSchedule['Lunes']!['active'] ? formatTime(_weekSchedule['Lunes']!['start']) : '00:00',
            mondayEnd: _weekSchedule['Lunes']!['active'] ? formatTime(_weekSchedule['Lunes']!['end']) : '00:00',
            tuesdayStart: _weekSchedule['Martes']!['active'] ? formatTime(_weekSchedule['Martes']!['start']) : '00:00',
            tuesdayEnd: _weekSchedule['Martes']!['active'] ? formatTime(_weekSchedule['Martes']!['end']) : '00:00',
            wednesdayStart: _weekSchedule['Miércoles']!['active'] ? formatTime(_weekSchedule['Miércoles']!['start']) : '00:00',
            wednesdayEnd: _weekSchedule['Miércoles']!['active'] ? formatTime(_weekSchedule['Miércoles']!['end']) : '00:00',
            thursdayStart: _weekSchedule['Jueves']!['active'] ? formatTime(_weekSchedule['Jueves']!['start']) : '00:00',
            thursdayEnd: _weekSchedule['Jueves']!['active'] ? formatTime(_weekSchedule['Jueves']!['end']) : '00:00',
            fridayStart: _weekSchedule['Viernes']!['active'] ? formatTime(_weekSchedule['Viernes']!['start']) : '00:00',
            fridayEnd: _weekSchedule['Viernes']!['active'] ? formatTime(_weekSchedule['Viernes']!['end']) : '00:00',
            saturdayStart: _weekSchedule['Sábado']!['active'] ? formatTime(_weekSchedule['Sábado']!['start']) : '00:00',
            saturdayEnd: _weekSchedule['Sábado']!['active'] ? formatTime(_weekSchedule['Sábado']!['end']) : '00:00',
            sundayStart: _weekSchedule['Domingo']!['active'] ? formatTime(_weekSchedule['Domingo']!['start']) : '00:00',
            sundayEnd: _weekSchedule['Domingo']!['active'] ? formatTime(_weekSchedule['Domingo']!['end']) : '00:00',
          ),
        );
        _isEditingSchedule = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onPrimary),
              SizedBox(width: 12),
              Text('Horario actualizado correctamente'),
            ],
          ),
          backgroundColor: ModernTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFriendlyError(e, fallback: 'Error al guardar horario')),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  void _changeProfileImage() {
    showResponsiveBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cambiar foto de perfil',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromCamera();
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ModernTheme.primaryBlue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          color: ModernTheme.primaryBlue,
                          size: 32,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('Cámara'),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.photo_library,
                          color: ModernTheme.rappiOrange,
                          size: 32,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('Galería'),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  Future<void> _pickImageFromCamera() async {
    try {
      // Seleccionar imagen desde la cámara usando image_picker
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) {
        // Usuario canceló
        return;
      }

      // Mostrar indicador de carga
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary)),
                SizedBox(width: 16),
                Text('Subiendo foto de perfil...'),
              ],
            ),
            duration: Duration(minutes: 2),
            backgroundColor: ModernTheme.info,
          ),
        );
      }

      // Subir imagen al backend Node
      if (_authUserId == null) {
        throw Exception('Usuario no autenticado');
      }

      final file = File(image.path);
      final uploaded = await _api.uploadFile(file: file, scope: 'profile');
      final downloadUrl = (uploaded['url'] ?? '') as String;
      if (downloadUrl.isEmpty) {
        throw Exception('El servidor no devolvió URL de la foto');
      }

      // Actualizar perfil del usuario con la nueva URL
      await _api.updateMe(profilePhotoUrl: downloadUrl);

      // Actualizar el estado local
      if (mounted) {
        setState(() {
          _profile = DriverProfile(
            id: _profile!.id,
            name: _profile!.name,
            email: _profile!.email,
            phone: _profile!.phone,
            profileImageUrl: downloadUrl,
            rating: _profile!.rating,
            totalTrips: _profile!.totalTrips,
            totalDistance: _profile!.totalDistance,
            totalHours: _profile!.totalHours,
            totalEarnings: _profile!.totalEarnings,
            memberSince: _profile!.memberSince,
            bio: _profile!.bio,
            emergencyContact: _profile!.emergencyContact,
            preferences: _profile!.preferences,
            achievements: _profile!.achievements,
            vehicleInfo: _profile!.vehicleInfo,
            workSchedule: _profile!.workSchedule,
          );
        });

        // Ocultar indicador de carga y mostrar mensaje de éxito
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto de perfil actualizada exitosamente'),
            backgroundColor: ModernTheme.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      AppLogger.error(userFriendlyError(e, fallback: 'Error al seleccionar foto desde cámara'));
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al actualizar foto: ${e.toString()}'),
            backgroundColor: ModernTheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
  
  Future<void> _pickImageFromGallery() async {
    try {
      // Seleccionar imagen desde la galería usando image_picker
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) {
        // Usuario canceló
        return;
      }

      // Mostrar indicador de carga
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary)),
                SizedBox(width: 16),
                Text('Subiendo foto de perfil...'),
              ],
            ),
            duration: Duration(minutes: 2),
            backgroundColor: ModernTheme.info,
          ),
        );
      }

      // Subir imagen al backend Node
      if (_authUserId == null) {
        throw Exception('Usuario no autenticado');
      }

      final file = File(image.path);
      final uploaded = await _api.uploadFile(file: file, scope: 'profile');
      final downloadUrl = (uploaded['url'] ?? '') as String;
      if (downloadUrl.isEmpty) {
        throw Exception('El servidor no devolvió URL de la foto');
      }

      // Actualizar perfil del usuario con la nueva URL
      await _api.updateMe(profilePhotoUrl: downloadUrl);

      // Actualizar el estado local
      if (mounted) {
        setState(() {
          _profile = DriverProfile(
            id: _profile!.id,
            name: _profile!.name,
            email: _profile!.email,
            phone: _profile!.phone,
            profileImageUrl: downloadUrl,
            rating: _profile!.rating,
            totalTrips: _profile!.totalTrips,
            totalDistance: _profile!.totalDistance,
            totalHours: _profile!.totalHours,
            totalEarnings: _profile!.totalEarnings,
            memberSince: _profile!.memberSince,
            bio: _profile!.bio,
            emergencyContact: _profile!.emergencyContact,
            preferences: _profile!.preferences,
            achievements: _profile!.achievements,
            vehicleInfo: _profile!.vehicleInfo,
            workSchedule: _profile!.workSchedule,
          );
        });

        // Ocultar indicador de carga y mostrar mensaje de éxito
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Foto de perfil actualizada exitosamente'),
            backgroundColor: ModernTheme.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      AppLogger.error(userFriendlyError(e, fallback: 'Error al seleccionar foto desde galería'));
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al actualizar foto: ${e.toString()}'),
            backgroundColor: ModernTheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ✅ ELIMINADO: _editPreferences() - Ahora usa edición inline
  // ✅ ELIMINADO: _editWorkSchedule() - Ahora usa edición inline
}

// Models
class DriverProfile {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String profileImageUrl;
  final double rating;
  final int totalTrips;
  final double totalDistance;
  final double totalHours;
  final double totalEarnings;
  final DateTime memberSince;
  final String bio;
  final EmergencyContact emergencyContact;
  final DriverPreferences preferences;
  final List<Achievement> achievements;
  final VehicleInfo vehicleInfo;
  final WorkSchedule workSchedule;
  
  DriverProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.profileImageUrl,
    required this.rating,
    required this.totalTrips,
    required this.totalDistance,
    required this.totalHours,
    required this.totalEarnings,
    required this.memberSince,
    required this.bio,
    required this.emergencyContact,
    required this.preferences,
    required this.achievements,
    required this.vehicleInfo,
    required this.workSchedule,
  });
}

class EmergencyContact {
  final String name;
  final String phone;
  final String relationship;
  
  EmergencyContact({
    required this.name,
    required this.phone,
    required this.relationship,
  });
}

class DriverPreferences {
  final bool acceptPets;
  final bool acceptSmoking;
  final String musicPreference;
  final List<String> languages;
  final double maxTripDistance;
  final List<String> preferredZones;
  
  DriverPreferences({
    required this.acceptPets,
    required this.acceptSmoking,
    required this.musicPreference,
    required this.languages,
    required this.maxTripDistance,
    required this.preferredZones,
  });
}

class Achievement {
  final String id;
  final String name;
  final String description;
  final String iconUrl;
  // Ronda 235: si unlockedDate == null, el logro está BLOQUEADO. Sin este
  // flag no había forma de mostrar todos los logros (incluidos los que
  // faltan) — la lista quedaba vacía si el driver no había ganado ninguno.
  final DateTime? unlockedDate;
  final int progressCurrent;
  final int progressTarget;

  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.iconUrl,
    this.unlockedDate,
    this.progressCurrent = 0,
    this.progressTarget = 0,
  });

  bool get isUnlocked => unlockedDate != null;
  double get progress => progressTarget == 0
      ? (isUnlocked ? 1.0 : 0.0)
      : (progressCurrent / progressTarget).clamp(0.0, 1.0);
}

class VehicleInfo {
  final String make;
  final String model;
  final int year;
  final String color;
  final String plate;
  final int capacity;
  
  VehicleInfo({
    required this.make,
    required this.model,
    required this.year,
    required this.color,
    required this.plate,
    required this.capacity,
  });
}

class WorkSchedule {
  final String mondayStart;
  final String mondayEnd;
  final String tuesdayStart;
  final String tuesdayEnd;
  final String wednesdayStart;
  final String wednesdayEnd;
  final String thursdayStart;
  final String thursdayEnd;
  final String fridayStart;
  final String fridayEnd;
  final String saturdayStart;
  final String saturdayEnd;
  final String sundayStart;
  final String sundayEnd;
  
  WorkSchedule({
    required this.mondayStart,
    required this.mondayEnd,
    required this.tuesdayStart,
    required this.tuesdayEnd,
    required this.wednesdayStart,
    required this.wednesdayEnd,
    required this.thursdayStart,
    required this.thursdayEnd,
    required this.fridayStart,
    required this.fridayEnd,
    required this.saturdayStart,
    required this.saturdayEnd,
    required this.sundayStart,
    required this.sundayEnd,
  });
}
/// Ronda 235: dialog que carga la imagen real del documento (fetch autenticado)
/// y permite reemplazarla eligiendo un nuevo archivo del image_picker.
class _DocumentPreviewDialog extends StatefulWidget {
  final String docType;
  final String label;
  final String url;
  final String scope;
  final Future<void> Function() onReplaced;
  const _DocumentPreviewDialog({
    required this.docType,
    required this.label,
    required this.url,
    required this.scope,
    required this.onReplaced,
  });
  @override
  State<_DocumentPreviewDialog> createState() => _DocumentPreviewDialogState();
}

class _DocumentPreviewDialogState extends State<_DocumentPreviewDialog> {
  Uint8List? _bytes;
  String? _error;
  bool _replacing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await RapiApiClient.instance.fetchMediaBytes(widget.url);
      if (!mounted) return;
      setState(() => _bytes = Uint8List.fromList(res.bytes));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = userFriendlyError(e, fallback: 'Error cargando'));
    }
  }

  Future<void> _replace() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Elegir de galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (picked == null || !mounted) return;
    setState(() => _replacing = true);
    try {
      final upload = await RapiApiClient.instance.uploadFile(
        file: File(picked.path),
        scope: widget.scope,
      );
      final newUrl = (upload['url'] ?? upload['downloadUrl'])?.toString();
      if (newUrl == null || newUrl.isEmpty) {
        throw StateError('El backend no devolvió URL');
      }
      await RapiApiClient.instance.uploadDocument(docType: widget.docType, fileUrl: newUrl);
      if (!mounted) return;
      await widget.onReplaced();
    } catch (e) {
      if (!mounted) return;
      setState(() => _replacing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFriendlyError(e, fallback: 'Error reemplazando')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.label,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _replacing ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.black12,
                child: _bytes != null
                    ? InteractiveViewer(child: Image.memory(_bytes!, fit: BoxFit.contain))
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(_error!, textAlign: TextAlign.center),
                            ),
                          )
                        : const Center(child: CircularProgressIndicator()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _replacing ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Cerrar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _replacing ? null : _replace,
                      icon: _replacing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.upload),
                      label: Text(_replacing ? 'Subiendo…' : 'Reemplazar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ModernTheme.primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
