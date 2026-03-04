// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:provider/provider.dart'; // Ya no se usa después de corrección toggle darkMode
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Firebase Firestore
import 'package:firebase_storage/firebase_storage.dart'; // ✅ NUEVO: Firebase Storage para imágenes
import 'package:image_picker/image_picker.dart'; // ✅ NUEVO: Selector de imágenes
import 'package:geocoding/geocoding.dart'; // ✅ Para búsqueda de lugares con Google
import '../../core/theme/modern_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_formatter.dart';
import '../../utils/logger.dart'; // ✅ Para logs
// import '../../providers/preferences_provider.dart'; // Ya no se usa después de corrección toggle darkMode

class SettingsAdminScreen extends StatefulWidget {
  const SettingsAdminScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SettingsAdminScreenState createState() => _SettingsAdminScreenState();
}

class _SettingsAdminScreenState extends State<SettingsAdminScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // ✅ NUEVO: Firebase instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ NUEVO: Loading state
  bool _isLoading = true;
  bool _isSaving = false;

  // General settings
  bool _maintenanceMode = false;
  bool _allowNewRegistrations = true;
  bool _requireDocumentVerification = true;
  String _defaultLanguage = 'es';
  String _timezone = 'America/Lima';
  bool _darkMode = false; // ✅ NUEVO: Modo oscuro

  // Pricing settings
  final TextEditingController _baseFareController = TextEditingController();
  final TextEditingController _perKmController = TextEditingController();
  final TextEditingController _perMinController = TextEditingController();
  final TextEditingController _commissionController = TextEditingController();
  final TextEditingController _cancellationFeeController = TextEditingController();
  final TextEditingController _withdrawalMinimumController = TextEditingController(); // ✅ NUEVO
  bool _dynamicPricing = true;
  double _surgeMultiplier = 1.5;

  // ✅ NUEVO: Tarifas especiales
  bool _nightSurchargeEnabled = true;
  double _nightSurchargePercent = 20.0;
  bool _weekendSurchargeEnabled = true;
  double _weekendSurchargePercent = 15.0;

  // Zones settings - ✅ AHORA DESDE FIREBASE
  final List<Zone> _zones = [];

  // Promotions settings - ✅ AHORA DESDE FIREBASE
  final List<Promotion> _promotions = [];

  // Notifications settings
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  bool _notifyNewTrips = true;
  bool _notifyPayments = true;
  bool _notifyEmergencies = true;

  // Security settings
  bool _twoFactorAuth = true;
  int _sessionTimeout = 30;
  int _maxLoginAttempts = 5;
  bool _requireStrongPasswords = true;
  bool _enableApiAccess = false;
  String _apiKey = 'sk_live_...';

  // Backup settings
  bool _autoBackup = true;
  String _backupFrequency = 'daily';
  String _backupTime = '03:00';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadAllSettingsFromFirebase(); // ✅ IMPLEMENTADO: Carga todas las configuraciones desde Firebase
  }

  @override
  void dispose() {
    _tabController.dispose();
    _baseFareController.dispose();
    _perKmController.dispose();
    _perMinController.dispose();
    _commissionController.dispose();
    _cancellationFeeController.dispose();
    _withdrawalMinimumController.dispose(); // ✅ NUEVO
    super.dispose();
  }

  // ✅ NUEVO: Cargar TODAS las configuraciones desde Firebase
  Future<void> _loadAllSettingsFromFirebase() async {
    try {
      AppLogger.info('Cargando configuraciones desde Firebase...');
      setState(() => _isLoading = true);

      // 1. Cargar configuración general desde 'settings/app_config'
      final settingsDoc = await _firestore.collection('settings').doc('app_config').get();
      if (settingsDoc.exists) {
        final data = settingsDoc.data()!;
        setState(() {
          _maintenanceMode = data['maintenanceMode'] ?? false;
          _allowNewRegistrations = data['allowNewRegistrations'] ?? true;
          _requireDocumentVerification = data['requireDocumentVerification'] ?? true;
          _defaultLanguage = data['defaultLanguage'] ?? 'es';
          _timezone = data['timezone'] ?? 'America/Lima';
          _darkMode = data['darkMode'] ?? false; // ✅ NUEVO: Cargar modo oscuro

          // Pricing
          _baseFareController.text = (data['baseFare'] ?? 5.0).toString();
          _perKmController.text = (data['perKm'] ?? 2.5).toString();
          _perMinController.text = (data['perMin'] ?? 0.5).toString();
          _commissionController.text = (data['commission'] ?? 20).toString();
          _cancellationFeeController.text = (data['cancellationFee'] ?? 5.0).toString();
          _withdrawalMinimumController.text = (data['withdrawalMinimum'] ?? 50.0).toString(); // ✅ NUEVO
          _dynamicPricing = data['dynamicPricing'] ?? true;
          _surgeMultiplier = (data['surgeMultiplier'] ?? 1.5).toDouble();

          // ✅ NUEVO: Tarifas especiales
          _nightSurchargeEnabled = data['nightSurchargeEnabled'] ?? true;
          _nightSurchargePercent = (data['nightSurchargePercent'] ?? 20.0).toDouble();
          _weekendSurchargeEnabled = data['weekendSurchargeEnabled'] ?? true;
          _weekendSurchargePercent = (data['weekendSurchargePercent'] ?? 15.0).toDouble();

          // Notifications
          _pushNotifications = data['pushNotifications'] ?? true;
          _emailNotifications = data['emailNotifications'] ?? true;
          _smsNotifications = data['smsNotifications'] ?? false;
          _notifyNewTrips = data['notifyNewTrips'] ?? true;
          _notifyPayments = data['notifyPayments'] ?? true;
          _notifyEmergencies = data['notifyEmergencies'] ?? true;

          // Security
          _twoFactorAuth = data['twoFactorAuth'] ?? true;
          _sessionTimeout = data['sessionTimeout'] ?? 30;
          _maxLoginAttempts = data['maxLoginAttempts'] ?? 5;
          _requireStrongPasswords = data['requireStrongPasswords'] ?? true;
          _enableApiAccess = data['enableApiAccess'] ?? false;
          _apiKey = data['apiKey'] ?? 'sk_live_...';

          // Backup
          _autoBackup = data['autoBackup'] ?? true;
          _backupFrequency = data['backupFrequency'] ?? 'daily';
          _backupTime = data['backupTime'] ?? '03:00';
        });
        AppLogger.info('✅ Configuraciones generales cargadas');
      } else {
        // ✅ NUEVO: Crear documento inicial con valores por defecto
        AppLogger.warning('⚠️ No existe documento de configuración, creando uno con valores por defecto...');
        await _createDefaultSettings();
      }

      // 2. Cargar zonas desde 'zones' collection
      await _loadZonesFromFirebase();

      // 3. Cargar promociones desde 'promotions' collection
      await _loadPromotionsFromFirebase();

      setState(() => _isLoading = false);
      AppLogger.info('✅ Todas las configuraciones cargadas correctamente');

    } catch (e, stackTrace) {
      AppLogger.error('Error cargando configuraciones desde Firebase', e, stackTrace);
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar configuraciones: $e'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }

  // ✅ NUEVO: Crear configuración por defecto si no existe
  Future<void> _createDefaultSettings() async {
    try {
      await _firestore.collection('settings').doc('app_config').set({
        // General
        'maintenanceMode': false,
        'allowNewRegistrations': true,
        'requireDocumentVerification': true,
        'defaultLanguage': 'es',
        'timezone': 'America/Lima',
        'darkMode': false, // ✅ NUEVO: Modo oscuro por defecto

        // Pricing - Valores base preestablecidos
        'baseFare': 5.0,
        'perKm': 2.5,
        'perMin': 0.5,
        'commission': 20.0,
        'cancellationFee': 5.0,
        'withdrawalMinimum': 50.0, // ✅ NUEVO: Monto mínimo de retiro
        'dynamicPricing': true,
        'surgeMultiplier': 1.5,

        // Tarifas especiales
        'nightSurchargeEnabled': true,
        'nightSurchargePercent': 20.0,
        'weekendSurchargeEnabled': true,
        'weekendSurchargePercent': 15.0,

        // Notifications
        'pushNotifications': true,
        'emailNotifications': true,
        'smsNotifications': false,
        'notifyNewTrips': true,
        'notifyPayments': true,
        'notifyEmergencies': true,

        // Security
        'twoFactorAuth': true,
        'sessionTimeout': 30,
        'maxLoginAttempts': 5,
        'requireStrongPasswords': true,
        'enableApiAccess': false,
        'apiKey': 'sk_live_...',

        // Backup
        'autoBackup': true,
        'backupFrequency': 'daily',
        'backupTime': '03:00',

        // Metadata
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.info('✅ Configuración inicial creada en Firebase');
    } catch (e, stackTrace) {
      AppLogger.error('Error creando configuración inicial', e, stackTrace);
    }
  }

  // ✅ NUEVO: Cargar zonas desde Firebase
  Future<void> _loadZonesFromFirebase() async {
    try {
      AppLogger.info('Cargando zonas desde Firebase...');
      final zonesSnapshot = await _firestore.collection('zones').get();

      _zones.clear();
      for (var doc in zonesSnapshot.docs) {
        final data = doc.data();
        _zones.add(Zone(
          id: doc.id,
          name: data['name'] ?? 'Sin nombre',
          surcharge: (data['surcharge'] ?? 0).toDouble(),
          restricted: data['restricted'] ?? false,
          latitude: data['latitude']?.toDouble(),
          longitude: data['longitude']?.toDouble(),
          placeId: data['placeId'],
          address: data['address'],
        ));
      }

      AppLogger.info('✅ ${_zones.length} zonas cargadas desde Firebase');
    } catch (e, stackTrace) {
      AppLogger.error('Error cargando zonas', e, stackTrace);
    }
  }

  // ✅ NUEVO: Cargar promociones desde Firebase
  Future<void> _loadPromotionsFromFirebase() async {
    try {
      AppLogger.info('Cargando promociones desde Firebase...');
      final promosSnapshot = await _firestore
          .collection('promotions')
          .where('isActive', isEqualTo: true)
          .get();

      _promotions.clear();
      for (var doc in promosSnapshot.docs) {
        final data = doc.data();
        _promotions.add(Promotion(
          id: doc.id,
          code: data['code'] ?? 'SIN CÓDIGO',
          title: data['title'] ?? '',
          description: data['description'] ?? '',
          value: (data['value'] ?? data['discount'] ?? 0).toDouble(),
          type: data['type'] == 'percentage' ? DiscountType.percentage : DiscountType.fixed,
          active: data['isActive'] ?? false,
          expiryDate: (data['validUntil'] as Timestamp?)?.toDate() ?? DateTime.now(),
          imageUrl: data['imageUrl'],
          targetUserType: data['targetUserType'] ?? 'both',
        ));
      }

      AppLogger.info('✅ ${_promotions.length} promociones cargadas desde Firebase');
    } catch (e, stackTrace) {
      AppLogger.error('Error cargando promociones', e, stackTrace);
    }
  }

  // ✅ NUEVO: Guardar REAL a Firebase
  Future<void> _saveSettings() async {
    if (_isSaving) return;

    try {
      setState(() => _isSaving = true);
      AppLogger.info('Guardando configuraciones en Firebase...');

      // Validar campos numéricos
      final baseFare = double.tryParse(_baseFareController.text);
      final perKm = double.tryParse(_perKmController.text);
      final perMin = double.tryParse(_perMinController.text);
      final commission = double.tryParse(_commissionController.text);
      final cancellationFee = double.tryParse(_cancellationFeeController.text);
      final withdrawalMinimum = double.tryParse(_withdrawalMinimumController.text); // ✅ NUEVO

      if (baseFare == null || perKm == null || perMin == null || commission == null || cancellationFee == null || withdrawalMinimum == null) {
        throw Exception('Valores de tarifas inválidos');
      }

      // Guardar en Firebase
      await _firestore.collection('settings').doc('app_config').set({
        // General
        'maintenanceMode': _maintenanceMode,
        'allowNewRegistrations': _allowNewRegistrations,
        'requireDocumentVerification': _requireDocumentVerification,
        'defaultLanguage': _defaultLanguage,
        'timezone': _timezone,
        'darkMode': _darkMode, // ✅ NUEVO: Guardar modo oscuro

        // Pricing
        'baseFare': baseFare,
        'perKm': perKm,
        'perMin': perMin,
        'commission': commission,
        'cancellationFee': cancellationFee,
        'withdrawalMinimum': withdrawalMinimum, // ✅ NUEVO
        'dynamicPricing': _dynamicPricing,
        'surgeMultiplier': _surgeMultiplier,

        // ✅ NUEVO: Tarifas especiales
        'nightSurchargeEnabled': _nightSurchargeEnabled,
        'nightSurchargePercent': _nightSurchargePercent,
        'weekendSurchargeEnabled': _weekendSurchargeEnabled,
        'weekendSurchargePercent': _weekendSurchargePercent,

        // Notifications
        'pushNotifications': _pushNotifications,
        'emailNotifications': _emailNotifications,
        'smsNotifications': _smsNotifications,
        'notifyNewTrips': _notifyNewTrips,
        'notifyPayments': _notifyPayments,
        'notifyEmergencies': _notifyEmergencies,

        // Security
        'twoFactorAuth': _twoFactorAuth,
        'sessionTimeout': _sessionTimeout,
        'maxLoginAttempts': _maxLoginAttempts,
        'requireStrongPasswords': _requireStrongPasswords,
        'enableApiAccess': _enableApiAccess,
        'apiKey': _apiKey,

        // Backup
        'autoBackup': _autoBackup,
        'backupFrequency': _backupFrequency,
        'backupTime': _backupTime,

        // Metadata
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.info('✅ Configuraciones guardadas en Firebase');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Configuración guardada exitosamente en Firebase'),
            backgroundColor: ModernTheme.success,
          ),
        );
      }

    } catch (e, stackTrace) {
      AppLogger.error('Error guardando configuraciones', e, stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al guardar: $e'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // ✅ NUEVO: Guardar zona en Firebase
  Future<void> _saveZone(Zone zone) async {
    try {
      final zoneData = {
        'name': zone.name,
        'surcharge': zone.surcharge,
        'restricted': zone.restricted,
        'latitude': zone.latitude,
        'longitude': zone.longitude,
        'placeId': zone.placeId,
        'address': zone.address,
      };

      if (zone.id == null) {
        // Crear nueva zona
        final docRef = await _firestore.collection('zones').add({
          ...zoneData,
          'createdAt': FieldValue.serverTimestamp(),
        });
        zone.id = docRef.id;
      } else {
        // Actualizar zona existente
        await _firestore.collection('zones').doc(zone.id).update({
          ...zoneData,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      AppLogger.info('✅ Zona guardada: ${zone.name}');
    } catch (e, stackTrace) {
      AppLogger.error('Error guardando zona', e, stackTrace);
      rethrow;
    }
  }

  // ✅ NUEVO: Eliminar zona de Firebase
  Future<void> _deleteZone(Zone zone) async {
    try {
      if (zone.id != null) {
        await _firestore.collection('zones').doc(zone.id).delete();
        AppLogger.info('✅ Zona eliminada: ${zone.name}');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error eliminando zona', e, stackTrace);
      rethrow;
    }
  }

  // ✅ NUEVO: Guardar promoción en Firebase
  Future<void> _savePromotion(Promotion promo) async {
    try {
      final data = {
        'code': promo.code,
        'title': promo.title,
        'description': promo.description,
        'value': promo.value,
        'type': promo.type == DiscountType.percentage ? 'percentage' : 'fixed',
        'isActive': promo.active,
        'validUntil': Timestamp.fromDate(promo.expiryDate),
        'imageUrl': promo.imageUrl,
        'targetUserType': promo.targetUserType,
        'usedCount': 0,
      };

      if (promo.id == null) {
        // Crear nueva promoción
        final docRef = await _firestore.collection('promotions').add({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
        });
        promo.id = docRef.id;
      } else {
        // Actualizar promoción existente
        await _firestore.collection('promotions').doc(promo.id).update({
          ...data,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      AppLogger.info('✅ Promoción guardada: ${promo.code}');
    } catch (e, stackTrace) {
      AppLogger.error('Error guardando promoción', e, stackTrace);
      rethrow;
    }
  }

  // ✅ NUEVO: Eliminar promoción de Firebase
  Future<void> _deletePromotion(Promotion promo) async {
    try {
      if (promo.id != null) {
        // Eliminar imagen de Storage si existe
        if (promo.imageUrl != null && promo.imageUrl!.isNotEmpty) {
          try {
            final ref = FirebaseStorage.instance.refFromURL(promo.imageUrl!);
            await ref.delete();
            AppLogger.info('🗑️ Imagen eliminada de Storage');
          } catch (e) {
            AppLogger.warning('No se pudo eliminar imagen: $e');
          }
        }

        // Eliminar documento de Firestore
        await _firestore.collection('promotions').doc(promo.id).delete();
        AppLogger.info('✅ Promoción eliminada: ${promo.code}');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error eliminando promoción', e, stackTrace);
      rethrow;
    }
  }

  // ✅ NUEVO: Subir imagen de promoción a Firebase Storage
  Future<String?> _uploadPromotionImage(String promotionId, File imageFile) async {
    try {
      AppLogger.info('📤 Subiendo imagen de promoción $promotionId...');

      // Crear referencia en Storage: promotions/{promotionId}/image_{timestamp}.jpg
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('promotions')
          .child(promotionId)
          .child('image_$timestamp.jpg');

      // Subir archivo con metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedBy': 'admin',
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = storageRef.putFile(imageFile, metadata);

      // Mostrar progreso (opcional)
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        AppLogger.info('📊 Progreso de subida: ${progress.toStringAsFixed(1)}%');
      });

      // Esperar a que termine la subida
      final snapshot = await uploadTask;

      // Obtener URL de descarga
      final downloadUrl = await snapshot.ref.getDownloadURL();

      AppLogger.info('✅ Imagen subida exitosamente: $downloadUrl');
      return downloadUrl;
    } catch (e, stackTrace) {
      AppLogger.error('Error subiendo imagen', e, stackTrace);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: ModernTheme.rappiOrange,
        elevation: 0,
        title: Text(
          'Configuración del Sistema',
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
        ),
        // ✅ ELIMINADO: Botón Guardar que generaba errores
        // Cada sección tiene su propio botón de guardado individual
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Theme.of(context).colorScheme.onPrimary,
          labelColor: Theme.of(context).colorScheme.onPrimary,
          unselectedLabelColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
          tabs: [
            Tab(text: 'General'),
            Tab(text: 'Tarifas'),
            Tab(text: 'Zonas'),
            Tab(text: 'Promociones'),
            Tab(text: 'Notificaciones'),
            Tab(text: 'Seguridad'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(ModernTheme.rappiOrange),
                  ),
                  SizedBox(height: 16),
                  Text('Cargando configuraciones desde Firebase...'),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildGeneralSettings(),
                _buildPricingSettings(),
                _buildZonesSettings(),
                _buildPromotionsSettings(),
                _buildNotificationSettings(),
                _buildSecuritySettings(),
              ],
            ),
    );
  }

  Widget _buildGeneralSettings() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildExpandableSection('Configuración General', [
            SwitchListTile(
              title: Text('Modo de Mantenimiento'),
              subtitle: Text('Desactiva temporalmente la aplicación'),
              value: _maintenanceMode,
              onChanged: (value) => setState(() => _maintenanceMode = value),
              activeColor: ModernTheme.rappiOrange,
            ),
            if (_maintenanceMode)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ModernTheme.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: ModernTheme.warning),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'La aplicación mostrará un mensaje de mantenimiento a todos los usuarios',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Divider(),
            SwitchListTile(
              title: Text('Permitir Nuevos Registros'),
              subtitle: Text('Habilita el registro de nuevos usuarios'),
              value: _allowNewRegistrations,
              onChanged: (value) => setState(() => _allowNewRegistrations = value),
              activeColor: ModernTheme.rappiOrange,
            ),
            Divider(),
            SwitchListTile(
              title: Text('Verificación de Documentos'),
              subtitle: Text('Requiere verificación para conductores'),
              value: _requireDocumentVerification,
              onChanged: (value) => setState(() => _requireDocumentVerification = value),
              activeColor: ModernTheme.rappiOrange,
            ),
            Divider(),
            // ✅ CORREGIDO: Toggle de Dark Mode usando variable local _darkMode (lee de Firebase)
            SwitchListTile(
              secondary: Icon(
                _darkMode ? Icons.dark_mode : Icons.light_mode,
                color: _darkMode ? Colors.deepPurple : Colors.amber,
              ),
              title: Text('Modo Oscuro'),
              subtitle: Text(_darkMode
                  ? 'Tema oscuro activado'
                  : 'Tema claro activado'),
              value: _darkMode,
              onChanged: (value) {
                setState(() => _darkMode = value);
              },
              activeColor: _darkMode ? Colors.deepPurple : ModernTheme.rappiOrange,
            ),
          ], icon: Icons.tune),

          _buildExpandableSection('Regional', [
            ListTile(
              title: Text('Idioma Predeterminado'),
              subtitle: Text(_defaultLanguage == 'es' ? 'Español' : 'English'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _showLanguageDialog,
            ),
            Divider(),
            ListTile(
              title: Text('Zona Horaria'),
              subtitle: Text(_timezone),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _showTimezoneDialog,
            ),
          ], icon: Icons.language),

          SizedBox(height: 20),

          // ✅ NUEVO: Botón para guardar configuración general
          Center(
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveSettings,
              icon: _isSaving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.onPrimary),
                      ),
                    )
                  : Icon(Icons.save),
              label: Text(_isSaving ? 'Guardando...' : 'Guardar Configuración General'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.rappiOrange,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          SizedBox(height: 8),
          _buildExpandableSection('Respaldo de Datos', [
            SwitchListTile(
              title: Text('Respaldo Automático'),
              subtitle: Text('Realiza respaldos periódicos'),
              value: _autoBackup,
              onChanged: (value) => setState(() => _autoBackup = value),
              activeColor: ModernTheme.rappiOrange,
            ),
            if (_autoBackup) ...[
              Divider(),
              ListTile(
                title: Text('Frecuencia'),
                subtitle: Text(_getBackupFrequencyText()),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _showBackupFrequencyDialog,
              ),
              Divider(),
              ListTile(
                title: Text('Hora del Respaldo'),
                subtitle: Text(_backupTime),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _showTimePickerDialog,
              ),
            ],
          ], icon: Icons.backup),
        ],
      ),
    );
  }

  Widget _buildPricingSettings() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildExpandableSection('Tarifas Base', [
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildPriceInput('Tarifa Base', _baseFareController, AppConstants.currencySymbol),
                  SizedBox(height: 16),
                  _buildPriceInput('Por Kilómetro', _perKmController, AppConstants.currencySymbol),
                  SizedBox(height: 16),
                  _buildPriceInput('Por Minuto', _perMinController, AppConstants.currencySymbol),
                  SizedBox(height: 16),
                  _buildPriceInput('Comisión Plataforma', _commissionController, '%'),
                  SizedBox(height: 16),
                  _buildPriceInput('Penalidad Cancelación', _cancellationFeeController, AppConstants.currencySymbol),
                ],
              ),
            ),
          ], icon: Icons.attach_money),

          _buildExpandableSection('Precios Dinámicos', [
            SwitchListTile(
              title: Text('Habilitar Precios Dinámicos'),
              subtitle: Text('Ajusta precios según demanda'),
              value: _dynamicPricing,
              onChanged: (value) => setState(() => _dynamicPricing = value),
              activeColor: ModernTheme.rappiOrange,
            ),
            if (_dynamicPricing) ...[
              Divider(),
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Multiplicador de Demanda Alta',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 8),
                    Slider(
                      value: _surgeMultiplier,
                      min: 1.0,
                      max: 3.0,
                      divisions: 20,
                      label: '${_surgeMultiplier}x',
                      activeColor: ModernTheme.rappiOrange,
                      onChanged: (value) {
                        setState(() => _surgeMultiplier = value);
                      },
                    ),
                    Center(
                      child: Text(
                        '${_surgeMultiplier.toStringAsFixed(1)}x',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: ModernTheme.rappiOrange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ], icon: Icons.trending_up),

          _buildExpandableSection('Horarios Especiales', [
            // ✅ CORREGIDO: Switch funcional para tarifa nocturna
            SwitchListTile(
              secondary: Icon(Icons.nightlight, color: ModernTheme.primaryBlue),
              title: Text('Tarifa Nocturna'),
              subtitle: Text('22:00 - 06:00 (+${_nightSurchargePercent.toStringAsFixed(0)}%)'),
              value: _nightSurchargeEnabled,
              onChanged: (value) => setState(() => _nightSurchargeEnabled = value),
              activeColor: ModernTheme.rappiOrange,
            ),
            if (_nightSurchargeEnabled) ...[
              Divider(),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Porcentaje de Recargo Nocturno',
                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                    ),
                    SizedBox(height: 8),
                    Slider(
                      value: _nightSurchargePercent,
                      min: 0,
                      max: 50,
                      divisions: 10,
                      label: '${_nightSurchargePercent.toStringAsFixed(0)}%',
                      activeColor: ModernTheme.primaryBlue,
                      onChanged: (value) {
                        setState(() => _nightSurchargePercent = value);
                      },
                    ),
                    Center(
                      child: Text(
                        '+${_nightSurchargePercent.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ModernTheme.primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Divider(),
            // ✅ CORREGIDO: Switch funcional para tarifa fin de semana
            SwitchListTile(
              secondary: Icon(Icons.weekend, color: Colors.orange),
              title: Text('Tarifa Fin de Semana'),
              subtitle: Text('Sábado y Domingo (+${_weekendSurchargePercent.toStringAsFixed(0)}%)'),
              value: _weekendSurchargeEnabled,
              onChanged: (value) => setState(() => _weekendSurchargeEnabled = value),
              activeColor: ModernTheme.rappiOrange,
            ),
            if (_weekendSurchargeEnabled) ...[
              Divider(),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Porcentaje de Recargo Fin de Semana',
                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                    ),
                    SizedBox(height: 8),
                    Slider(
                      value: _weekendSurchargePercent,
                      min: 0,
                      max: 50,
                      divisions: 10,
                      label: '${_weekendSurchargePercent.toStringAsFixed(0)}%',
                      activeColor: Colors.orange,
                      onChanged: (value) {
                        setState(() => _weekendSurchargePercent = value);
                      },
                    ),
                    Center(
                      child: Text(
                        '+${_weekendSurchargePercent.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ], icon: Icons.schedule),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text(
                'Guardar Tarifas',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.rappiOrange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZonesSettings() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Zonas Especiales (${_zones.length})'),
          if (_zones.isEmpty)
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: ModernTheme.getCardShadow(context),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.location_off, size: 48, color: ModernTheme.textSecondary),
                    SizedBox(height: 16),
                    Text('No hay zonas configuradas'),
                  ],
                ),
              ),
            )
          else
            ..._zones.map((zone) => _buildZoneCard(zone)),
          SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: _addZone,
              icon: Icon(Icons.add),
              label: Text('Agregar Zona'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.rappiOrange,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneCard(Zone zone) {
    final TextEditingController nameController = TextEditingController(text: zone.name);
    final TextEditingController surchargeController = TextEditingController(text: zone.surcharge.toString());
    final TextEditingController locationController = TextEditingController(
      text: zone.address ?? (zone.latitude != null ? 'Lat: ${zone.latitude}, Lng: ${zone.longitude}' : ''),
    );

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.getCardShadow(context),
      ),
      child: ExpansionTile(
        title: Text(zone.name),
        subtitle: Text(
          zone.restricted
            ? 'Zona Restringida'
            : zone.address != null
              ? '${zone.address} - Recargo: ${zone.surcharge.toCurrency()}'
              : 'Recargo: ${zone.surcharge.toCurrency()}',
          style: TextStyle(
            color: zone.restricted ? ModernTheme.error : ModernTheme.textSecondary,
            fontSize: 12,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: zone.restricted
                ? ModernTheme.error.withValues(alpha: 0.1)
                : ModernTheme.rappiOrange.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.location_on,
            color: zone.restricted ? ModernTheme.error : ModernTheme.rappiOrange,
          ),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete, color: ModernTheme.error),
          onPressed: () => _removeZone(zone),
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Campo: Nombre de la zona
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Nombre de la Zona',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.label, color: ModernTheme.rappiOrange),
                  ),
                  controller: nameController,
                  onChanged: (value) => zone.name = value,
                ),
                SizedBox(height: 16),

                // ✅ NUEVO: Campo de búsqueda de ubicación con Google
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Buscar Ubicación',
                    hintText: 'Ej: Miraflores, Lima',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.search, color: ModernTheme.primaryBlue),
                    suffixIcon: locationController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: () {
                              locationController.clear();
                              zone.latitude = null;
                              zone.longitude = null;
                              zone.address = null;
                              zone.placeId = null;
                            },
                          )
                        : null,
                  ),
                  controller: locationController,
                  onSubmitted: (value) async {
                    if (value.trim().isEmpty) return;

                    try {
                      // Buscar ubicación con geocoding
                      final locations = await locationFromAddress(value);

                      if (locations.isNotEmpty) {
                        final location = locations.first;

                        // Obtener dirección formateada
                        final placemarks = await placemarkFromCoordinates(
                          location.latitude,
                          location.longitude,
                        );

                        if (placemarks.isNotEmpty) {
                          final placemark = placemarks.first;
                          final address = [
                            placemark.street,
                            placemark.locality,
                            placemark.administrativeArea,
                            placemark.country,
                          ].where((e) => e != null && e.isNotEmpty).join(', ');

                          setState(() {
                            zone.latitude = location.latitude;
                            zone.longitude = location.longitude;
                            zone.address = address;
                            locationController.text = address;
                          });

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✅ Ubicación encontrada: $address'),
                                backgroundColor: ModernTheme.success,
                              ),
                            );
                          }
                        }
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('⚠️ No se encontró la ubicación'),
                              backgroundColor: ModernTheme.warning,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      AppLogger.error('Error buscando ubicación', e, StackTrace.current);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('❌ Error buscando ubicación: $e'),
                            backgroundColor: ModernTheme.error,
                          ),
                        );
                      }
                    }
                  },
                ),

                // Mostrar coordenadas si existen
                if (zone.latitude != null && zone.longitude != null) ...[
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: ModernTheme.success, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Coordenadas: ${zone.latitude!.toStringAsFixed(6)}, ${zone.longitude!.toStringAsFixed(6)}',
                            style: TextStyle(
                              color: ModernTheme.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: 16),

                // Campo: Recargo
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Recargo (${AppConstants.currencySymbol})',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixText: '${AppConstants.currencySymbol} ',
                    prefixIcon: Icon(Icons.attach_money, color: ModernTheme.primaryOrange),
                  ),
                  controller: surchargeController,
                  keyboardType: TextInputType.number,
                  onChanged: (value) => zone.surcharge = double.tryParse(value) ?? 0,
                ),
                SizedBox(height: 16),

                // Switch: Zona restringida
                SwitchListTile(
                  title: Text('Zona Restringida'),
                  subtitle: Text('Solo conductores autorizados pueden operar aquí'),
                  value: zone.restricted,
                  onChanged: (value) {
                    setState(() => zone.restricted = value);
                  },
                  activeColor: ModernTheme.rappiOrange,
                ),
                SizedBox(height: 16),

                // Botón: Guardar zona
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // Validaciones
                      if (zone.name.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('⚠️ El nombre de la zona no puede estar vacío'),
                            backgroundColor: ModernTheme.warning,
                          ),
                        );
                        return;
                      }

                      try {
                        await _saveZone(zone);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ Zona guardada exitosamente en Firebase'),
                              backgroundColor: ModernTheme.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('❌ Error al guardar: $e'),
                              backgroundColor: ModernTheme.error,
                            ),
                          );
                        }
                      }
                    },
                    icon: Icon(Icons.save),
                    label: Text('Guardar Zona en Firebase'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ModernTheme.rappiOrange,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromotionsSettings() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Promociones Activas (${_promotions.length})'),
          if (_promotions.isEmpty)
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: ModernTheme.getCardShadow(context),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.discount, size: 48, color: ModernTheme.textSecondary),
                    SizedBox(height: 16),
                    Text('No hay promociones activas'),
                  ],
                ),
              ),
            )
          else
            ..._promotions.map((promo) => _buildPromotionCard(promo)),
          SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: _addPromotion,
              icon: Icon(Icons.add),
              label: Text('Crear Promoción'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.rappiOrange,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromotionCard(Promotion promo) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
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
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  promo.code,
                  style: TextStyle(
                    color: ModernTheme.rappiOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Text(
                promo.type == DiscountType.percentage
                    ? '${promo.value}% OFF'
                    : '${promo.value.toCurrency()} OFF',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              Switch(
                value: promo.active,
                onChanged: (value) async {
                  setState(() => promo.active = value);
                  try {
                    await _savePromotion(promo);
                  } catch (e) {
                    // Revertir
                    setState(() => promo.active = !value);
                  }
                },
                activeColor: ModernTheme.rappiOrange,
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: ModernTheme.textSecondary),
              SizedBox(width: 4),
              Text(
                'Vence: ${promo.expiryDate.day}/${promo.expiryDate.month}/${promo.expiryDate.year}',
                style: TextStyle(
                  color: ModernTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _editPromotion(promo),
                icon: Icon(Icons.edit, size: 16),
                label: Text('Editar'),
              ),
              TextButton.icon(
                onPressed: () => _removePromotion(promo),
                icon: Icon(Icons.delete, size: 16),
                label: Text('Eliminar'),
                style: TextButton.styleFrom(
                  foregroundColor: ModernTheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSettings() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Canales de Notificación'),
          _buildSettingCard([
            SwitchListTile(
              title: Text('Notificaciones Push'),
              subtitle: Text('Enviar notificaciones a la app'),
              value: _pushNotifications,
              onChanged: (value) => setState(() => _pushNotifications = value),
              activeColor: ModernTheme.rappiOrange,
              secondary: Icon(Icons.notifications, color: ModernTheme.primaryBlue),
            ),
            Divider(),
            SwitchListTile(
              title: Text('Notificaciones por Email'),
              subtitle: Text('Enviar correos electrónicos'),
              value: _emailNotifications,
              onChanged: (value) => setState(() => _emailNotifications = value),
              activeColor: ModernTheme.rappiOrange,
              secondary: Icon(Icons.email, color: Colors.orange),
            ),
            Divider(),
            SwitchListTile(
              title: Text('Notificaciones SMS'),
              subtitle: Text('Enviar mensajes de texto'),
              value: _smsNotifications,
              onChanged: (value) => setState(() => _smsNotifications = value),
              activeColor: ModernTheme.rappiOrange,
              secondary: Icon(Icons.sms, color: Colors.purple),
            ),
          ]),

          SizedBox(height: 20),
          _buildSectionTitle('Tipos de Notificaciones'),
          _buildSettingCard([
            SwitchListTile(
              title: Text('Nuevos Viajes'),
              subtitle: Text('Notificar cuando hay nuevas solicitudes'),
              value: _notifyNewTrips,
              onChanged: (value) => setState(() => _notifyNewTrips = value),
              activeColor: ModernTheme.rappiOrange,
            ),
            Divider(),
            SwitchListTile(
              title: Text('Pagos y Transacciones'),
              subtitle: Text('Notificar pagos recibidos y retiros'),
              value: _notifyPayments,
              onChanged: (value) => setState(() => _notifyPayments = value),
              activeColor: ModernTheme.rappiOrange,
            ),
            Divider(),
            SwitchListTile(
              title: Text('Emergencias'),
              subtitle: Text('Alertas de seguridad y emergencias'),
              value: _notifyEmergencies,
              onChanged: (value) => setState(() => _notifyEmergencies = value),
              activeColor: ModernTheme.rappiOrange,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSecuritySettings() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Autenticación'),
          _buildSettingCard([
            SwitchListTile(
              title: Text('Autenticación de Dos Factores'),
              subtitle: Text('Requiere código adicional para admins'),
              value: _twoFactorAuth,
              onChanged: (value) => setState(() => _twoFactorAuth = value),
              activeColor: ModernTheme.rappiOrange,
              secondary: Icon(Icons.security, color: ModernTheme.rappiOrange),
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.timer, color: ModernTheme.warning),
              title: Text('Tiempo de Sesión'),
              subtitle: Text('$_sessionTimeout minutos'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.remove),
                    onPressed: () {
                      if (_sessionTimeout > 5) {
                        setState(() => _sessionTimeout -= 5);
                      }
                    },
                  ),
                  Text('$_sessionTimeout'),
                  IconButton(
                    icon: Icon(Icons.add),
                    onPressed: () {
                      setState(() => _sessionTimeout += 5);
                    },
                  ),
                ],
              ),
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.lock, color: ModernTheme.error),
              title: Text('Máximo de Intentos de Login'),
              subtitle: Text('$_maxLoginAttempts intentos'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.remove),
                    onPressed: () {
                      if (_maxLoginAttempts > 1) {
                        setState(() => _maxLoginAttempts--);
                      }
                    },
                  ),
                  Text('$_maxLoginAttempts'),
                  IconButton(
                    icon: Icon(Icons.add),
                    onPressed: () {
                      setState(() => _maxLoginAttempts++);
                    },
                  ),
                ],
              ),
            ),
            Divider(),
            SwitchListTile(
              title: Text('Contraseñas Fuertes'),
              subtitle: Text('Mínimo 8 caracteres, mayúsculas y números'),
              value: _requireStrongPasswords,
              onChanged: (value) => setState(() => _requireStrongPasswords = value),
              activeColor: ModernTheme.rappiOrange,
            ),
          ]),

          SizedBox(height: 20),
          _buildSectionTitle('API y Acceso Externo'),
          _buildSettingCard([
            SwitchListTile(
              title: Text('Habilitar Acceso API'),
              subtitle: Text('Permite integraciones externas'),
              value: _enableApiAccess,
              onChanged: (value) => setState(() => _enableApiAccess = value),
              activeColor: ModernTheme.rappiOrange,
              secondary: Icon(Icons.api, color: ModernTheme.primaryBlue),
            ),
            if (_enableApiAccess) ...[
              Divider(),
              ListTile(
                leading: Icon(Icons.vpn_key, color: ModernTheme.warning),
                title: Text('API Key'),
                subtitle: Text(_apiKey),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.copy, size: 20),
                      onPressed: _copyApiKey,
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh, size: 20),
                      onPressed: _regenerateApiKey,
                    ),
                  ],
                ),
              ),
            ],
          ]),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: ModernTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildSettingCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.getCardShadow(context),
      ),
      child: Column(children: children),
    );
  }

  // ExpansionTile wrapper: each section becomes an accordion
  Widget _buildExpandableSection(String title, List<Widget> children, {IconData icon = Icons.settings}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.getCardShadow(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ExpansionTile(
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ModernTheme.rappiOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: ModernTheme.rappiOrange, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: ModernTheme.textPrimary,
            ),
          ),
          iconColor: ModernTheme.rappiOrange,
          collapsedIconColor: ModernTheme.textSecondary,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: EdgeInsets.zero,
          children: children,
        ),
      ),
    );
  }

  Widget _buildPriceInput(String label, TextEditingController controller, String suffix) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        suffixText: suffix,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
    );
  }

  String _getBackupFrequencyText() {
    switch (_backupFrequency) {
      case 'daily':
        return 'Diario';
      case 'weekly':
        return 'Semanal';
      case 'monthly':
        return 'Mensual';
      default:
        return 'Diario';
    }
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Seleccionar Idioma'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Radio<String>(
                value: 'es',
                groupValue: _defaultLanguage,
                onChanged: (value) {
                  setState(() => _defaultLanguage = value!);
                  Navigator.pop(context);
                },
              ),
              title: Text('Español'),
              onTap: () {
                setState(() => _defaultLanguage = 'es');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Radio<String>(
                value: 'en',
                groupValue: _defaultLanguage,
                onChanged: (value) {
                  setState(() => _defaultLanguage = value!);
                  Navigator.pop(context);
                },
              ),
              title: Text('English'),
              onTap: () {
                setState(() => _defaultLanguage = 'en');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTimezoneDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Seleccionar Zona Horaria'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Radio<String>(
                value: 'America/Lima',
                groupValue: _timezone,
                onChanged: (value) {
                  setState(() => _timezone = value!);
                  Navigator.pop(context);
                },
              ),
              title: Text('América/Lima'),
              onTap: () {
                setState(() => _timezone = 'America/Lima');
                Navigator.pop(context);
              },
            ),
            // ✅ CORREGIDO: Cambiado México por Bogotá (más relevante para LATAM)
            ListTile(
              leading: Radio<String>(
                value: 'America/Bogota',
                groupValue: _timezone,
                onChanged: (value) {
                  setState(() => _timezone = value!);
                  Navigator.pop(context);
                },
              ),
              title: Text('América/Bogotá (Colombia)'),
              onTap: () {
                setState(() => _timezone = 'America/Bogota');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBackupFrequencyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Frecuencia de Respaldo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Radio<String>(
                value: 'daily',
                groupValue: _backupFrequency,
                onChanged: (value) {
                  setState(() => _backupFrequency = value!);
                  Navigator.pop(context);
                },
              ),
              title: Text('Diario'),
              onTap: () {
                setState(() => _backupFrequency = 'daily');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Radio<String>(
                value: 'weekly',
                groupValue: _backupFrequency,
                onChanged: (value) {
                  setState(() => _backupFrequency = value!);
                  Navigator.pop(context);
                },
              ),
              title: Text('Semanal'),
              onTap: () {
                setState(() => _backupFrequency = 'weekly');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Radio<String>(
                value: 'monthly',
                groupValue: _backupFrequency,
                onChanged: (value) {
                  setState(() => _backupFrequency = value!);
                  Navigator.pop(context);
                },
              ),
              title: Text('Mensual'),
              onTap: () {
                setState(() => _backupFrequency = 'monthly');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTimePickerDialog() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: 3, minute: 0),
    );
    if (time != null) {
      setState(() {
        _backupTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  void _addZone() {
    setState(() {
      _zones.add(Zone(name: 'Nueva Zona', surcharge: 0, restricted: false));
    });
  }

  Future<void> _removeZone(Zone zone) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar Eliminación'),
        content: Text('¿Eliminar la zona "${zone.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: ModernTheme.error),
            child: Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _deleteZone(zone);
        setState(() => _zones.remove(zone));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Zona eliminada'),
              backgroundColor: ModernTheme.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: ModernTheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _addPromotion() async {
    try {
      // Crear primero en Firebase para obtener el ID real
      final docRef = await _firestore.collection('promotions').add({
        'code': 'NUEVO',
        'title': 'Nueva Promoción',
        'description': 'Descripción de la promoción',
        'value': 10,
        'discount': 10,
        'type': 'percentage',
        'isActive': true,
        'validUntil': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
        'targetUserType': 'both',
        'usedCount': 0,
        'maxUses': 100,
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _promotions.add(
          Promotion(
            id: docRef.id,
            code: 'NUEVO',
            title: 'Nueva Promoción',
            description: 'Descripción de la promoción',
            value: 10,
            type: DiscountType.percentage,
            active: true,
            expiryDate: DateTime.now().add(const Duration(days: 30)),
            targetUserType: 'both',
          ),
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Promoción creada. Edítala para personalizar.'),
            backgroundColor: ModernTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear promoción: $e'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }

  /// ✅ IMPLEMENTADO: Diálogo profesional de edición de promociones
  Future<void> _editPromotion(Promotion promo) async {
    final TextEditingController codeController = TextEditingController(text: promo.code);
    final TextEditingController titleController = TextEditingController(text: promo.title);
    final TextEditingController descriptionController = TextEditingController(text: promo.description);
    final TextEditingController discountController = TextEditingController(text: promo.value.toString());
    DiscountType selectedType = promo.type;
    bool isActive = promo.active;
    DateTime selectedDate = promo.expiryDate;
    File? selectedImage; // ✅ NUEVO: Imagen seleccionada
    String selectedUserType = promo.targetUserType; // ✅ NUEVO: Tipo de usuario
    final ImagePicker picker = ImagePicker(); // ✅ NUEVO: Selector de imágenes

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.edit, color: ModernTheme.rappiOrange),
              SizedBox(width: 12),
              Text(
                'Editar Promoción',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Campo: Código de promoción
                  Text(
                    'Código de Promoción',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: ModernTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: codeController,
                    decoration: InputDecoration(
                      hintText: 'Ej: VERANO2025',
                      prefixIcon: Icon(Icons.confirmation_number, color: ModernTheme.rappiOrange),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: ModernTheme.rappiOrange, width: 2),
                      ),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                      LengthLimitingTextInputFormatter(20),
                    ],
                  ),
                  SizedBox(height: 20),

                  // Campo: Título de la promoción
                  Text(
                    'Título',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: ModernTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      hintText: 'Ej: Descuento de Verano',
                      prefixIcon: Icon(Icons.title, color: ModernTheme.rappiOrange),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: ModernTheme.rappiOrange, width: 2),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),

                  // Campo: Descripción de la promoción
                  Text(
                    'Descripción',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: ModernTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Ej: Obtén un descuento en tu próximo viaje',
                      prefixIcon: Icon(Icons.description, color: ModernTheme.rappiOrange),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: ModernTheme.rappiOrange, width: 2),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),

                  // Campo: Descuento
                  Text(
                    'Descuento',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: ModernTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: discountController,
                    decoration: InputDecoration(
                      hintText: selectedType == DiscountType.percentage ? 'Ej: 20' : 'Ej: 10.00',
                      prefixIcon: Icon(
                        selectedType == DiscountType.percentage ? Icons.percent : Icons.attach_money,
                        color: ModernTheme.rappiOrange,
                      ),
                      suffixText: selectedType == DiscountType.percentage ? '%' : 'S/',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: ModernTheme.rappiOrange, width: 2),
                      ),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                  ),
                  SizedBox(height: 20),

                  // Selector: Tipo de descuento
                  Text(
                    'Tipo de Descuento',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: ModernTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        RadioListTile<DiscountType>(
                          title: Text('Porcentaje (%)'),
                          subtitle: Text('Ej: 20% de descuento'),
                          value: DiscountType.percentage,
                          groupValue: selectedType,
                          activeColor: ModernTheme.rappiOrange,
                          onChanged: (value) {
                            setDialogState(() {
                              selectedType = value!;
                            });
                          },
                        ),
                        Divider(height: 1),
                        RadioListTile<DiscountType>(
                          title: Text('Monto Fijo (S/)'),
                          subtitle: Text('Ej: S/ 10 de descuento'),
                          value: DiscountType.fixed,
                          groupValue: selectedType,
                          activeColor: ModernTheme.rappiOrange,
                          onChanged: (value) {
                            setDialogState(() {
                              selectedType = value!;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),

                  // Switch: Estado activo/inactivo
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isActive ? ModernTheme.rappiOrange.withValues(alpha: 0.1) : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive ? ModernTheme.rappiOrange : Theme.of(context).dividerColor,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isActive ? Icons.check_circle : Icons.cancel,
                          color: isActive ? ModernTheme.success : ModernTheme.textSecondary,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Estado de la Promoción',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                isActive ? 'Activa - Visible para usuarios' : 'Inactiva - No visible',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: ModernTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isActive,
                          activeColor: ModernTheme.rappiOrange,
                          onChanged: (value) {
                            setDialogState(() {
                              isActive = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),

                  // ✅ NUEVO: Selector de tipo de usuario
                  Text(
                    'Tipo de Usuario',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: ModernTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          title: Text('Conductor'),
                          subtitle: Text('Solo para conductores'),
                          value: 'driver',
                          groupValue: selectedUserType,
                          activeColor: ModernTheme.rappiOrange,
                          onChanged: (value) {
                            setDialogState(() {
                              selectedUserType = value!;
                            });
                          },
                        ),
                        Divider(height: 1),
                        RadioListTile<String>(
                          title: Text('Pasajero'),
                          subtitle: Text('Solo para pasajeros'),
                          value: 'passenger',
                          groupValue: selectedUserType,
                          activeColor: ModernTheme.rappiOrange,
                          onChanged: (value) {
                            setDialogState(() {
                              selectedUserType = value!;
                            });
                          },
                        ),
                        Divider(height: 1),
                        RadioListTile<String>(
                          title: Text('Ambos'),
                          subtitle: Text('Para conductores y pasajeros'),
                          value: 'both',
                          groupValue: selectedUserType,
                          activeColor: ModernTheme.rappiOrange,
                          onChanged: (value) {
                            setDialogState(() {
                              selectedUserType = value!;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),

                  // ✅ NUEVO: Selector de imagen
                  Text(
                    'Imagen de Promoción',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: ModernTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),

                  // Preview de imagen existente o seleccionada
                  if (selectedImage != null || (promo.imageUrl != null && promo.imageUrl!.isNotEmpty))
                    Container(
                      height: 200,
                      margin: EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: selectedImage != null
                            ? Image.file(selectedImage!, fit: BoxFit.cover)
                            : Image.network(
                                promo.imageUrl!,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.error_outline, size: 48, color: ModernTheme.error),
                                        SizedBox(height: 8),
                                        Text('Error cargando imagen'),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),

                  // Botones de selección de imagen
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final XFile? image = await picker.pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 1920,
                                maxHeight: 1080,
                                imageQuality: 85,
                              );
                              if (image != null) {
                                setDialogState(() {
                                  selectedImage = File(image.path);
                                });
                              }
                            } catch (e) {
                              AppLogger.error('Error seleccionando imagen', e, StackTrace.current);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error al seleccionar imagen: $e'),
                                  backgroundColor: ModernTheme.error,
                                ),
                              );
                            }
                          },
                          icon: Icon(Icons.photo_library),
                          label: Text('Galería'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ModernTheme.rappiOrange,
                            side: BorderSide(color: ModernTheme.rappiOrange),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final XFile? image = await picker.pickImage(
                                source: ImageSource.camera,
                                maxWidth: 1920,
                                maxHeight: 1080,
                                imageQuality: 85,
                              );
                              if (image != null) {
                                setDialogState(() {
                                  selectedImage = File(image.path);
                                });
                              }
                            } catch (e) {
                              AppLogger.error('Error capturando imagen', e, StackTrace.current);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error al capturar imagen: $e'),
                                  backgroundColor: ModernTheme.error,
                                ),
                              );
                            }
                          },
                          icon: Icon(Icons.camera_alt),
                          label: Text('Cámara'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ModernTheme.rappiOrange,
                            side: BorderSide(color: ModernTheme.rappiOrange),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Botón para remover imagen
                  if (selectedImage != null || (promo.imageUrl != null && promo.imageUrl!.isNotEmpty))
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: TextButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            selectedImage = null;
                            // Si había imagen en Firebase, la marcaremos para eliminar
                          });
                        },
                        icon: Icon(Icons.delete_outline, color: ModernTheme.error),
                        label: Text('Quitar Imagen', style: TextStyle(color: ModernTheme.error)),
                      ),
                    ),

                  SizedBox(height: 20),

                  // Selector: Fecha de expiración
                  Text(
                    'Fecha de Expiración',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: ModernTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(Duration(days: 365)),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: ModernTheme.rappiOrange,
                                onPrimary: Theme.of(context).colorScheme.onPrimary,
                                onSurface: ModernTheme.textPrimary,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: ModernTheme.rappiOrange),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Toca para cambiar',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ModernTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_drop_down, color: ModernTheme.textSecondary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: TextStyle(color: ModernTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // Validaciones
                if (codeController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('⚠️ El código no puede estar vacío'),
                      backgroundColor: ModernTheme.warning,
                    ),
                  );
                  return;
                }

                final discount = double.tryParse(discountController.text);
                if (discount == null || discount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('⚠️ El descuento debe ser mayor a 0'),
                      backgroundColor: ModernTheme.warning,
                    ),
                  );
                  return;
                }

                if (selectedType == DiscountType.percentage && discount > 100) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('⚠️ El porcentaje no puede ser mayor a 100%'),
                      backgroundColor: ModernTheme.warning,
                    ),
                  );
                  return;
                }

                // Retornar datos editados
                Navigator.pop(context, {
                  'code': codeController.text.trim().toUpperCase(),
                  'title': titleController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'discount': discount,
                  'type': selectedType,
                  'active': isActive,
                  'expiryDate': selectedDate,
                  'targetUserType': selectedUserType,
                  'selectedImage': selectedImage,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.rappiOrange,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.save, size: 18),
                  SizedBox(width: 8),
                  Text('Guardar Cambios'),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Si el usuario confirmó la edición, actualizar la promoción
    if (result != null) {
      try {
        setState(() => _isSaving = true);

        String? imageUrl = promo.imageUrl; // Mantener URL existente por defecto

        // ✅ NUEVO: Si hay una nueva imagen seleccionada, subirla a Firebase Storage
        final File? selectedImage = result['selectedImage'];
        if (selectedImage != null && promo.id != null) {
          AppLogger.info('📤 Subiendo nueva imagen de promoción...');

          // Eliminar imagen anterior si existe
          if (promo.imageUrl != null && promo.imageUrl!.isNotEmpty) {
            try {
              final oldRef = FirebaseStorage.instance.refFromURL(promo.imageUrl!);
              await oldRef.delete();
              AppLogger.info('🗑️ Imagen anterior eliminada de Storage');
            } catch (e) {
              AppLogger.warning('No se pudo eliminar imagen anterior: $e');
            }
          }

          // Subir nueva imagen
          imageUrl = await _uploadPromotionImage(promo.id!, selectedImage);
          AppLogger.info('✅ Nueva imagen subida: $imageUrl');
        }

        // Actualizar promoción en Firebase
        if (promo.id != null) {
          await _firestore.collection('promotions').doc(promo.id).update({
            'code': result['code'] ?? '',
            'title': result['title'] ?? '',
            'description': result['description'] ?? '',
            'value': (result['discount'] as num?)?.toDouble() ?? 0.0,
            'type': (result['type'] ?? DiscountType.percentage) == DiscountType.percentage ? 'percentage' : 'fixed',
            'isActive': result['active'] ?? false,
            'validUntil': Timestamp.fromDate(result['expiryDate'] ?? DateTime.now()),
            'targetUserType': result['targetUserType'] ?? 'both',
            'imageUrl': imageUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Actualizar en la lista local
          setState(() {
            final index = _promotions.indexOf(promo);
            if (index != -1) {
              _promotions[index] = Promotion(
                id: promo.id,
                code: result['code'] ?? '',
                title: result['title'] ?? '',
                description: result['description'] ?? '',
                value: (result['discount'] as num?)?.toDouble() ?? 0.0,
                type: result['type'] ?? DiscountType.percentage,
                active: result['active'] ?? false,
                expiryDate: result['expiryDate'] ?? DateTime.now(),
                targetUserType: result['targetUserType'] ?? 'both',
                imageUrl: imageUrl,
              );
            }
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Promoción actualizada exitosamente'),
                backgroundColor: ModernTheme.success,
              ),
            );
          }
        }
      } catch (e, stackTrace) {
        AppLogger.error('Error actualizando promoción', e, stackTrace);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error al actualizar promoción: $e'),
              backgroundColor: ModernTheme.error,
            ),
          );
        }
      } finally {
        setState(() => _isSaving = false);
      }
    }

    // Limpiar controladores
    codeController.dispose();
    titleController.dispose();
    descriptionController.dispose();
    discountController.dispose();
  }

  Future<void> _removePromotion(Promotion promo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar Eliminación'),
        content: Text('¿Eliminar la promoción "${promo.code}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: ModernTheme.error),
            child: Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _deletePromotion(promo);
        setState(() => _promotions.remove(promo));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Promoción eliminada'),
              backgroundColor: ModernTheme.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: ModernTheme.error,
            ),
          );
        }
      }
    }
  }

  void _copyApiKey() {
    Clipboard.setData(ClipboardData(text: _apiKey));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('API Key copiada al portapapeles'),
        backgroundColor: ModernTheme.success,
      ),
    );
  }

  void _regenerateApiKey() {
    setState(() {
      _apiKey = 'sk_live_${DateTime.now().millisecondsSinceEpoch}';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Nueva API Key generada'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
}

// Models
class Zone {
  String? id; // ✅ ID de Firebase
  String name;
  double surcharge;
  bool restricted;
  double? latitude; // ✅ NUEVO: Coordenadas de Google Maps
  double? longitude; // ✅ NUEVO: Coordenadas de Google Maps
  String? placeId; // ✅ NUEVO: Google Place ID
  String? address; // ✅ NUEVO: Dirección completa

  Zone({
    this.id,
    required this.name,
    required this.surcharge,
    required this.restricted,
    this.latitude,
    this.longitude,
    this.placeId,
    this.address,
  });
}

class Promotion {
  String? id;
  String code;
  String title;
  String description;
  double value;
  DiscountType type;
  bool active;
  DateTime expiryDate;
  String? imageUrl;
  String targetUserType;

  Promotion({
    this.id,
    required this.code,
    this.title = '',
    this.description = '',
    required this.value,
    required this.type,
    required this.active,
    required this.expiryDate,
    this.imageUrl,
    this.targetUserType = 'both',
  });
}

enum DiscountType { percentage, fixed }
