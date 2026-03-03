import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/design/design_system.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_loading_state.dart';
import '../../core/widgets/rt_button.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../utils/firestore_error_handler.dart';
import '../../utils/logger.dart';
import 'widgets/driver_profile_header.dart';
import 'widgets/driver_personal_info_section.dart';
import 'widgets/driver_vehicle_section.dart';
import 'widgets/driver_schedule_section.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  // Datos del perfil
  DriverProfile? _profile;
  bool _isLoading = true;

  // ImagePicker y Firebase
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Flags de edicion inline
  bool _isEditingPersonal = false;
  bool _isEditingVehicle = false;
  bool _isEditingPreferences = false;
  bool _isEditingSchedule = false;

  // Documentos del conductor
  Map<String, String>? _documents;

  // Form keys
  final _personalFormKey = GlobalKey<FormState>();
  final _vehicleFormKey = GlobalKey<FormState>();
  final _preferencesFormKey = GlobalKey<FormState>();
  final _scheduleFormKey = GlobalKey<FormState>();

  // Controladores - Información Personal
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _bioController = TextEditingController();

  // Controladores - Información del Vehículo
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _plateController = TextEditingController();
  final _capacityController = TextEditingController();

  // Estado - Preferencias
  bool _acceptPets = false;
  bool _acceptSmoking = false;
  String _musicPreference = 'Ninguna';
  List<String> _languages = ['Español'];
  double _maxTripDistance = 50.0;
  List<String> _preferredZones = [];

  // Estado - Horario de Trabajo
  Map<String, Map<String, dynamic>> _weekSchedule = {
    'Lunes': {'start': const TimeOfDay(hour: 8, minute: 0), 'end': const TimeOfDay(hour: 18, minute: 0), 'active': true},
    'Martes': {'start': const TimeOfDay(hour: 8, minute: 0), 'end': const TimeOfDay(hour: 18, minute: 0), 'active': true},
    'Miércoles': {'start': const TimeOfDay(hour: 8, minute: 0), 'end': const TimeOfDay(hour: 18, minute: 0), 'active': true},
    'Jueves': {'start': const TimeOfDay(hour: 8, minute: 0), 'end': const TimeOfDay(hour: 18, minute: 0), 'active': true},
    'Viernes': {'start': const TimeOfDay(hour: 8, minute: 0), 'end': const TimeOfDay(hour: 18, minute: 0), 'active': true},
    'Sábado': {'start': const TimeOfDay(hour: 8, minute: 0), 'end': const TimeOfDay(hour: 18, minute: 0), 'active': false},
    'Domingo': {'start': const TimeOfDay(hour: 8, minute: 0), 'end': const TimeOfDay(hour: 18, minute: 0), 'active': false},
  };

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: RtDuration.emphasis,
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
    _fadeController.dispose();
    _slideController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    _bioController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _plateController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  // --- Carga de perfil desde Firebase ---

  void _loadProfile() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        AppLogger.warning('No hay usuario autenticado');
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final userId = currentUser.uid;
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        AppLogger.warning('Documento de usuario no existe: $userId');
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final userData = userDoc.data()!;

      // Calcular estadísticas desde rides
      double totalDistance = 0.0;
      double totalEarnings = 0.0;
      double totalHours = 0.0;
      int totalTripsCount = 0;

      try {
        final ridesSnapshot = await _firestore
            .collection('rides')
            .where('driverId', isEqualTo: userId)
            .where('status', isEqualTo: 'completed')
            .limit(100)
            .get();

        totalTripsCount = ridesSnapshot.docs.length;

        for (var doc in ridesSnapshot.docs) {
          final data = doc.data();
          if (data['distance'] != null) {
            totalDistance += (data['distance'] as num).toDouble();
          }
          if (data['fare'] != null) {
            totalEarnings += (data['fare'] as num).toDouble();
          }
          if (data['startedAt'] != null && data['completedAt'] != null) {
            final startedAt = (data['startedAt'] as Timestamp).toDate();
            final completedAt = (data['completedAt'] as Timestamp).toDate();
            totalHours += completedAt.difference(startedAt).inMinutes / 60.0;
          }
        }
      } catch (e) {
        AppLogger.warning('No se pudieron cargar estadísticas de rides: $e');
        totalTripsCount = (userData['totalTrips'] as num?)?.toInt() ?? 0;
        totalEarnings = (userData['totalEarnings'] as num?)?.toDouble() ?? 0.0;
      }

      // Extraer datos del perfil
      final emergencyContactData = userData['emergencyContact'] as Map<String, dynamic>?;
      final preferencesData = userData['preferences'] as Map<String, dynamic>?;
      final vehicleInfoData = userData['vehicleInfo'] as Map<String, dynamic>?;
      final workScheduleData = userData['workSchedule'] as Map<String, dynamic>?;
      final documentsData = userData['documents'] as Map<String, dynamic>?;

      _documents = documentsData?.map((key, value) => MapEntry(key, value.toString()));

      // Cargar logros
      List<Achievement> achievementsList = [];
      try {
        final achievementsSnapshot = await _firestore
            .collection('achievements')
            .where('userId', isEqualTo: userId)
            .get();

        for (var doc in achievementsSnapshot.docs) {
          final data = doc.data();
          achievementsList.add(Achievement(
            id: doc.id,
            name: data['name'] ?? '',
            description: data['description'] ?? '',
            iconUrl: data['iconUrl'] ?? '',
            unlockedDate: (data['unlockedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
          ));
        }
      } catch (e) {
        AppLogger.warning('No se pudieron cargar logros: $e');
      }

      if (!mounted) return;
      setState(() {
        _profile = DriverProfile(
          id: userId,
          name: userData['fullName'] ?? currentUser.displayName ?? '',
          email: userData['email'] ?? currentUser.email ?? '',
          phone: userData['phone'] ?? '',
          profileImageUrl: userData['profilePhotoUrl'] ?? currentUser.photoURL ?? '',
          rating: (userData['rating'] ?? 5.0).toDouble(),
          totalTrips: totalTripsCount,
          totalDistance: totalDistance,
          totalHours: totalHours,
          totalEarnings: totalEarnings,
          memberSince: (userData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          bio: userData['bio'] ?? '',
          emergencyContact: EmergencyContact(
            name: emergencyContactData?['name'] ?? '',
            phone: emergencyContactData?['phone'] ?? '',
            relationship: emergencyContactData?['relationship'] ?? '',
          ),
          preferences: DriverPreferences(
            acceptPets: preferencesData?['acceptPets'] ?? false,
            acceptSmoking: preferencesData?['acceptSmoking'] ?? false,
            musicPreference: preferencesData?['musicPreference'] ?? '',
            languages: (preferencesData?['languages'] as List<dynamic>?)?.cast<String>() ?? [],
            maxTripDistance: ((preferencesData?['maxTripDistance'] ?? 50.0) as num).toDouble().clamp(5.0, 100.0),
            preferredZones: (preferencesData?['preferredZones'] as List<dynamic>?)?.cast<String>() ?? [],
          ),
          achievements: achievementsList,
          vehicleInfo: VehicleInfo(
            make: vehicleInfoData?['make'] ?? '',
            model: vehicleInfoData?['model'] ?? '',
            year: vehicleInfoData?['year'] ?? 0,
            color: vehicleInfoData?['color'] ?? '',
            plate: vehicleInfoData?['plate'] ?? '',
            capacity: vehicleInfoData?['capacity'] ?? 4,
          ),
          workSchedule: WorkSchedule(
            mondayStart: workScheduleData?['mondayStart'] ?? '00:00',
            mondayEnd: workScheduleData?['mondayEnd'] ?? '00:00',
            tuesdayStart: workScheduleData?['tuesdayStart'] ?? '00:00',
            tuesdayEnd: workScheduleData?['tuesdayEnd'] ?? '00:00',
            wednesdayStart: workScheduleData?['wednesdayStart'] ?? '00:00',
            wednesdayEnd: workScheduleData?['wednesdayEnd'] ?? '00:00',
            thursdayStart: workScheduleData?['thursdayStart'] ?? '00:00',
            thursdayEnd: workScheduleData?['thursdayEnd'] ?? '00:00',
            fridayStart: workScheduleData?['fridayStart'] ?? '00:00',
            fridayEnd: workScheduleData?['fridayEnd'] ?? '00:00',
            saturdayStart: workScheduleData?['saturdayStart'] ?? '00:00',
            saturdayEnd: workScheduleData?['saturdayEnd'] ?? '00:00',
            sundayStart: workScheduleData?['sundayStart'] ?? '00:00',
            sundayEnd: workScheduleData?['sundayEnd'] ?? '00:00',
          ),
        );
        _isLoading = false;
        _initializeControllers();
      });

      if (mounted) {
        _fadeController.forward();
        _slideController.forward();
      }
    } catch (e) {
      AppLogger.error('Error al cargar perfil: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Inicializa los controladores con datos del perfil cargado
  void _initializeControllers() {
    final profile = _profile!;

    // Información Personal
    _nameController.text = profile.name;
    _phoneController.text = profile.phone;
    _emailController.text = profile.email;
    _emergencyContactController.text = profile.emergencyContact.name;
    _emergencyPhoneController.text = profile.emergencyContact.phone;
    _bioController.text = profile.bio;

    // Información del Vehículo
    _makeController.text = profile.vehicleInfo.make;
    _modelController.text = profile.vehicleInfo.model;
    _yearController.text = '${profile.vehicleInfo.year}';
    _colorController.text = profile.vehicleInfo.color;
    _plateController.text = profile.vehicleInfo.plate;
    _capacityController.text = '${profile.vehicleInfo.capacity}';

    // Preferencias
    _acceptPets = profile.preferences.acceptPets;
    _acceptSmoking = profile.preferences.acceptSmoking;
    _musicPreference = profile.preferences.musicPreference.isEmpty
        ? 'Ninguna'
        : profile.preferences.musicPreference;
    _languages = List<String>.from(profile.preferences.languages);
    _maxTripDistance = profile.preferences.maxTripDistance.clamp(5.0, 100.0);
    _preferredZones = List<String>.from(profile.preferences.preferredZones);

    // Horario de Trabajo
    _weekSchedule = _buildWeekScheduleFromProfile(profile.workSchedule);
  }

  /// Construye el mapa de horario semanal a partir del modelo
  Map<String, Map<String, dynamic>> _buildWeekScheduleFromProfile(WorkSchedule schedule) {
    TimeOfDay parseTime(String time) {
      final parts = time.split(':');
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    bool isActive(String start, String end) {
      return start != '00:00' || end != '00:00';
    }

    return {
      'Lunes': {'start': parseTime(schedule.mondayStart), 'end': parseTime(schedule.mondayEnd), 'active': isActive(schedule.mondayStart, schedule.mondayEnd)},
      'Martes': {'start': parseTime(schedule.tuesdayStart), 'end': parseTime(schedule.tuesdayEnd), 'active': isActive(schedule.tuesdayStart, schedule.tuesdayEnd)},
      'Miércoles': {'start': parseTime(schedule.wednesdayStart), 'end': parseTime(schedule.wednesdayEnd), 'active': isActive(schedule.wednesdayStart, schedule.wednesdayEnd)},
      'Jueves': {'start': parseTime(schedule.thursdayStart), 'end': parseTime(schedule.thursdayEnd), 'active': isActive(schedule.thursdayStart, schedule.thursdayEnd)},
      'Viernes': {'start': parseTime(schedule.fridayStart), 'end': parseTime(schedule.fridayEnd), 'active': isActive(schedule.fridayStart, schedule.fridayEnd)},
      'Sábado': {'start': parseTime(schedule.saturdayStart), 'end': parseTime(schedule.saturdayEnd), 'active': isActive(schedule.saturdayStart, schedule.saturdayEnd)},
      'Domingo': {'start': parseTime(schedule.sundayStart), 'end': parseTime(schedule.sundayEnd), 'active': isActive(schedule.sundayStart, schedule.sundayEnd)},
    };
  }

  // --- UI Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: RtAppBar(
        title: 'Mi Perfil',
        variant: RtAppBarVariant.gradient,
      ),
      body: _isLoading ? _buildLoadingState() : _buildProfile(),
    );
  }

  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.all(RtSpacing.xl),
      child: RtLoadingState.profile(),
    );
  }

  Widget _buildProfile() {
    if (_profile == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: RtColors.error),
            const SizedBox(height: RtSpacing.base),
            Text(
              'No se pudo cargar el perfil',
              style: RtTypo.headingSmall.copyWith(color: RtColors.neutral900),
            ),
            const SizedBox(height: RtSpacing.sm),
            Text(
              'Por favor, intenta nuevamente',
              style: RtTypo.bodyMedium.copyWith(color: RtColors.neutral500),
            ),
            const SizedBox(height: RtSpacing.xl),
            RtButton(
              label: 'Reintentar',
              onPressed: _loadProfile,
              variant: RtButtonVariant.primary,
              icon: Icons.refresh,
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
            child: Column(
              children: [
                DriverProfileHeader(
                  profile: _profile!,
                  slideAnimation: _slideAnimation,
                  onChangeImage: _changeProfileImage,
                ),
                DriverPersonalInfoSection(
                  profile: _profile!,
                  isEditing: _isEditingPersonal,
                  formKey: _personalFormKey,
                  nameController: _nameController,
                  phoneController: _phoneController,
                  emailController: _emailController,
                  bioController: _bioController,
                  emergencyContactController: _emergencyContactController,
                  emergencyPhoneController: _emergencyPhoneController,
                  onToggleEdit: () => setState(() => _isEditingPersonal = true),
                  onSave: _saveProfile,
                  onCancel: _cancelEditPersonal,
                ),
                DriverVehicleSection(
                  profile: _profile!,
                  isEditing: _isEditingVehicle,
                  formKey: _vehicleFormKey,
                  makeController: _makeController,
                  modelController: _modelController,
                  yearController: _yearController,
                  colorController: _colorController,
                  plateController: _plateController,
                  capacityController: _capacityController,
                  onToggleEdit: () => setState(() => _isEditingVehicle = true),
                  onSave: _saveVehicleInfo,
                  onCancel: _cancelEditVehicle,
                ),
                if (_documents != null && _documents!.isNotEmpty)
                  DriverDocumentsSection(documents: _documents!),
                DriverAchievementsSection(profile: _profile!),
                DriverPreferencesSection(
                  profile: _profile!,
                  isEditing: _isEditingPreferences,
                  formKey: _preferencesFormKey,
                  acceptPets: _acceptPets,
                  acceptSmoking: _acceptSmoking,
                  musicPreference: _musicPreference,
                  languages: _languages,
                  maxTripDistance: _maxTripDistance,
                  preferredZones: _preferredZones,
                  onToggleEdit: () => setState(() => _isEditingPreferences = true),
                  onSave: _savePreferences,
                  onCancel: _cancelEditPreferences,
                  onAcceptPetsChanged: (v) => setState(() => _acceptPets = v),
                  onAcceptSmokingChanged: (v) => setState(() => _acceptSmoking = v),
                  onMusicPreferenceChanged: (v) => setState(() => _musicPreference = v),
                  onLanguagesChanged: (v) => setState(() => _languages = v),
                  onMaxTripDistanceChanged: (v) => setState(() => _maxTripDistance = v),
                  onPreferredZonesChanged: (v) => setState(() => _preferredZones = v),
                ),
                DriverWorkScheduleSection(
                  profile: _profile!,
                  isEditing: _isEditingSchedule,
                  formKey: _scheduleFormKey,
                  weekSchedule: _weekSchedule,
                  onToggleEdit: () => setState(() => _isEditingSchedule = true),
                  onSave: _saveWorkSchedule,
                  onCancel: _cancelEditSchedule,
                  onScheduleChanged: (day, field, value) {
                    setState(() {
                      _weekSchedule[day]![field] = value;
                    });
                  },
                ),
                const SizedBox(height: RtSpacing.xl),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Cancelar edicion (restaurar valores originales) ---

  void _cancelEditPersonal() {
    setState(() {
      _isEditingPersonal = false;
      _nameController.text = _profile!.name;
      _phoneController.text = _profile!.phone;
      _emailController.text = _profile!.email;
      _bioController.text = _profile!.bio;
      _emergencyContactController.text = _profile!.emergencyContact.name;
      _emergencyPhoneController.text = _profile!.emergencyContact.phone;
    });
  }

  void _cancelEditVehicle() {
    setState(() {
      _isEditingVehicle = false;
      _makeController.text = _profile!.vehicleInfo.make;
      _modelController.text = _profile!.vehicleInfo.model;
      _yearController.text = '${_profile!.vehicleInfo.year}';
      _colorController.text = _profile!.vehicleInfo.color;
      _plateController.text = _profile!.vehicleInfo.plate;
      _capacityController.text = '${_profile!.vehicleInfo.capacity}';
    });
  }

  void _cancelEditPreferences() {
    setState(() {
      _isEditingPreferences = false;
      _acceptPets = _profile!.preferences.acceptPets;
      _acceptSmoking = _profile!.preferences.acceptSmoking;
      _musicPreference = _profile!.preferences.musicPreference.isEmpty
          ? 'Ninguna'
          : _profile!.preferences.musicPreference;
      _languages = List<String>.from(_profile!.preferences.languages);
      _maxTripDistance = _profile!.preferences.maxTripDistance.clamp(5.0, 100.0);
      _preferredZones = List<String>.from(_profile!.preferences.preferredZones);
    });
  }

  void _cancelEditSchedule() {
    setState(() {
      _isEditingSchedule = false;
      _weekSchedule = _buildWeekScheduleFromProfile(_profile!.workSchedule);
    });
  }

  // --- Guardar en Firebase ---

  Future<void> _saveProfile() async {
    if (!_personalFormKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('Usuario no autenticado');

      await _firestore.collection('users').doc(userId).update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'bio': _bioController.text.trim(),
        'emergencyContact': {
          'name': _emergencyContactController.text.trim(),
          'phone': _emergencyPhoneController.text.trim(),
          'relationship': _profile!.emergencyContact.relationship,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() {
        _profile = _profile!.copyWith(
          name: _nameController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          bio: _bioController.text,
          emergencyContact: EmergencyContact(
            name: _emergencyContactController.text,
            phone: _emergencyPhoneController.text,
            relationship: _profile!.emergencyContact.relationship,
          ),
        );
        _isEditingPersonal = false;
      });

      RtSnackbar.show(context, message: 'Información personal actualizada', type: RtSnackbarType.success);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(FirestoreErrorHandler.getSpanishMessage(e)),
        backgroundColor: RtColors.error,
      ));
    }
  }

  Future<void> _saveVehicleInfo() async {
    if (!_vehicleFormKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('Usuario no autenticado');

      final make = _makeController.text.trim().toUpperCase();
      final model = _modelController.text.trim().toUpperCase();
      final year = int.tryParse(_yearController.text.trim()) ?? DateTime.now().year;
      final color = _colorController.text.trim().toUpperCase();
      final plate = _plateController.text.trim().toUpperCase();
      final capacity = int.tryParse(_capacityController.text.trim()) ?? 4;

      await _firestore.collection('users').doc(userId).update({
        'vehicleInfo': {
          'make': make, 'model': model, 'year': year,
          'color': color, 'plate': plate, 'capacity': capacity,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() {
        _profile = _profile!.copyWith(
          vehicleInfo: VehicleInfo(
            make: make, model: model, year: year,
            color: color, plate: plate, capacity: capacity,
          ),
        );
        _isEditingVehicle = false;
      });

      RtSnackbar.show(context, message: 'Información del vehículo actualizada', type: RtSnackbarType.success);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(FirestoreErrorHandler.getSpanishMessage(e)),
        backgroundColor: RtColors.error,
      ));
    }
  }

  Future<void> _savePreferences() async {
    if (!_preferencesFormKey.currentState!.validate()) return;

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('Usuario no autenticado');

      await _firestore.collection('users').doc(userId).update({
        'preferences': {
          'acceptPets': _acceptPets,
          'acceptSmoking': _acceptSmoking,
          'musicPreference': _musicPreference,
          'languages': _languages,
          'maxTripDistance': _maxTripDistance,
          'preferredZones': _preferredZones,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() {
        _profile = _profile!.copyWith(
          preferences: DriverPreferences(
            acceptPets: _acceptPets,
            acceptSmoking: _acceptSmoking,
            musicPreference: _musicPreference,
            languages: _languages,
            maxTripDistance: _maxTripDistance,
            preferredZones: _preferredZones,
          ),
        );
        _isEditingPreferences = false;
      });

      RtSnackbar.show(context, message: 'Preferencias actualizadas', type: RtSnackbarType.success);
    } catch (e) {
      if (!mounted) return;
      RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
    }
  }

  Future<void> _saveWorkSchedule() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('Usuario no autenticado');

      // Validar que hora fin > hora inicio para días activos
      for (var entry in _weekSchedule.entries) {
        final day = entry.key;
        final dayData = entry.value;
        if (dayData['active'] as bool) {
          final start = dayData['start'] as TimeOfDay;
          final end = dayData['end'] as TimeOfDay;
          final startMinutes = start.hour * 60 + start.minute;
          final endMinutes = end.hour * 60 + end.minute;
          if (endMinutes <= startMinutes) {
            if (!mounted) return;
            RtSnackbar.show(
              context,
              message: 'La hora de fin debe ser mayor que la hora de inicio en $day',
              type: RtSnackbarType.error,
            );
            return;
          }
        }
      }

      String formatTime(TimeOfDay time) {
        return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      }

      String getStart(String day) => _weekSchedule[day]!['active'] as bool
          ? formatTime(_weekSchedule[day]!['start'] as TimeOfDay) : '00:00';
      String getEnd(String day) => _weekSchedule[day]!['active'] as bool
          ? formatTime(_weekSchedule[day]!['end'] as TimeOfDay) : '00:00';

      final scheduleData = {
        'mondayStart': getStart('Lunes'), 'mondayEnd': getEnd('Lunes'),
        'tuesdayStart': getStart('Martes'), 'tuesdayEnd': getEnd('Martes'),
        'wednesdayStart': getStart('Miércoles'), 'wednesdayEnd': getEnd('Miércoles'),
        'thursdayStart': getStart('Jueves'), 'thursdayEnd': getEnd('Jueves'),
        'fridayStart': getStart('Viernes'), 'fridayEnd': getEnd('Viernes'),
        'saturdayStart': getStart('Sábado'), 'saturdayEnd': getEnd('Sábado'),
        'sundayStart': getStart('Domingo'), 'sundayEnd': getEnd('Domingo'),
      };

      await _firestore.collection('users').doc(userId).update({
        'workSchedule': scheduleData,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() {
        _profile = _profile!.copyWith(
          workSchedule: WorkSchedule(
            mondayStart: scheduleData['mondayStart']!,
            mondayEnd: scheduleData['mondayEnd']!,
            tuesdayStart: scheduleData['tuesdayStart']!,
            tuesdayEnd: scheduleData['tuesdayEnd']!,
            wednesdayStart: scheduleData['wednesdayStart']!,
            wednesdayEnd: scheduleData['wednesdayEnd']!,
            thursdayStart: scheduleData['thursdayStart']!,
            thursdayEnd: scheduleData['thursdayEnd']!,
            fridayStart: scheduleData['fridayStart']!,
            fridayEnd: scheduleData['fridayEnd']!,
            saturdayStart: scheduleData['saturdayStart']!,
            saturdayEnd: scheduleData['saturdayEnd']!,
            sundayStart: scheduleData['sundayStart']!,
            sundayEnd: scheduleData['sundayEnd']!,
          ),
        );
        _isEditingSchedule = false;
      });

      RtSnackbar.show(context, message: 'Horario actualizado correctamente', type: RtSnackbarType.success);
    } catch (e) {
      if (!mounted) return;
      RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
    }
  }

  // --- Cambiar foto de perfil ---

  void _changeProfileImage() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: RtRadius.sheetTop),
      builder: (context) => Container(
        padding: const EdgeInsets.all(RtSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cambiar foto de perfil',
              style: RtTypo.headingSmall,
            ),
            const SizedBox(height: RtSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImageSourceOption(
                  context,
                  icon: Icons.camera_alt,
                  label: 'Cámara',
                  color: RtColors.info,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                _buildImageSourceOption(
                  context,
                  icon: Icons.photo_library,
                  label: 'Galería',
                  color: RtColors.brand,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
            const SizedBox(height: RtSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: RtSpacing.paddingBase,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: RtSpacing.sm),
          Text(label, style: RtTypo.bodyMedium),
        ],
      ),
    );
  }

  /// Selecciona y sube una imagen desde cámara o galería
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image == null) return;

      if (mounted) {
        RtSnackbar.show(context, message: 'Subiendo foto de perfil...', type: RtSnackbarType.info);
      }

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('Usuario no autenticado');

      final file = File(image.path);
      final storageRef = _storage
          .ref()
          .child('users')
          .child(userId)
          .child('profile')
          .child('profile_photo_${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      await _firestore.collection('users').doc(userId).update({
        'profilePhotoUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() {
        _profile = _profile!.copyWith(profileImageUrl: downloadUrl);
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      RtSnackbar.show(context, message: 'Foto de perfil actualizada', type: RtSnackbarType.success);
    } catch (e) {
      AppLogger.error('Error al seleccionar foto: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      RtSnackbar.show(
        context,
        message: FirestoreErrorHandler.getSpanishMessage(e),
        type: RtSnackbarType.error,
      );
    }
  }

}

// --- Modelos ---

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

  /// Crea una copia del perfil con los campos proporcionados
  DriverProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? profileImageUrl,
    double? rating,
    int? totalTrips,
    double? totalDistance,
    double? totalHours,
    double? totalEarnings,
    DateTime? memberSince,
    String? bio,
    EmergencyContact? emergencyContact,
    DriverPreferences? preferences,
    List<Achievement>? achievements,
    VehicleInfo? vehicleInfo,
    WorkSchedule? workSchedule,
  }) {
    return DriverProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      rating: rating ?? this.rating,
      totalTrips: totalTrips ?? this.totalTrips,
      totalDistance: totalDistance ?? this.totalDistance,
      totalHours: totalHours ?? this.totalHours,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      memberSince: memberSince ?? this.memberSince,
      bio: bio ?? this.bio,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      preferences: preferences ?? this.preferences,
      achievements: achievements ?? this.achievements,
      vehicleInfo: vehicleInfo ?? this.vehicleInfo,
      workSchedule: workSchedule ?? this.workSchedule,
    );
  }
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
  final DateTime unlockedDate;

  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.unlockedDate,
  });
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
