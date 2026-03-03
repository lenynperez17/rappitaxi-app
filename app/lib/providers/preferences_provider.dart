import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_service.dart';
import '../utils/firestore_error_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// PreferencesProvider - Maneja todas las configuraciones de la app
/// ✅ IMPLEMENTACIÓN COMPLETA con persistencia en SharedPreferences y Firebase

class PreferencesProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseService().firestore;
  late SharedPreferences _prefs;
  
  // Estado de inicialización
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;
  
  // Preferencias generales
  bool _notificationsEnabled = true;
  bool _locationServices = true;
  bool _darkMode = false;
  String _language = 'es';
  String _currency = 'PEN';
  
  // Preferencias de privacidad
  bool _shareLocation = true;
  bool _shareTrips = false;
  bool _analytics = true;
  bool _crashReports = true;
  
  // Preferencias de notificaciones
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  bool _tripUpdates = true;
  bool _promotions = true;
  bool _newsUpdates = false;
  
  // Preferencias de seguridad
  bool _biometricAuth = false;
  bool _twoFactorAuth = false;
  int _autoLockTime = 5; // minutos
  
  // Preferencias de la app
  bool _autoUpdate = true;
  bool _offlineMaps = false;
  String _mapStyle = 'standard';
  bool _soundEffects = true;
  bool _hapticFeedback = true;
  
  // Preferencias de datos
  bool _syncOnWiFiOnly = false;
  bool _compressImages = true;
  String _cacheSize = '150 MB';
  
  // Preferencias de conductor (si aplica)
  bool _autoAcceptRides = false;
  int _searchRadius = 5000; // metros
  bool _saveHistory = true;
  
  // Getters de estado
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Getters generales
  bool get notificationsEnabled => _notificationsEnabled;
  bool get locationServices => _locationServices;
  bool get darkMode => _darkMode;
  String get language => _language;
  String get currency => _currency;
  
  // Getters de privacidad
  bool get shareLocation => _shareLocation;
  bool get shareTrips => _shareTrips;
  bool get analytics => _analytics;
  bool get crashReports => _crashReports;
  
  // Getters de notificaciones
  bool get pushNotifications => _pushNotifications;
  bool get emailNotifications => _emailNotifications;
  bool get smsNotifications => _smsNotifications;
  bool get tripUpdates => _tripUpdates;
  bool get promotions => _promotions;
  bool get newsUpdates => _newsUpdates;
  
  // Getters de seguridad
  bool get biometricAuth => _biometricAuth;
  bool get twoFactorAuth => _twoFactorAuth;
  int get autoLockTime => _autoLockTime;
  
  // Getters de la app
  bool get autoUpdate => _autoUpdate;
  bool get offlineMaps => _offlineMaps;
  String get mapStyle => _mapStyle;
  bool get soundEffects => _soundEffects;
  bool get hapticFeedback => _hapticFeedback;
  
  // Getters de datos
  bool get syncOnWiFiOnly => _syncOnWiFiOnly;
  bool get compressImages => _compressImages;
  String get cacheSize => _cacheSize;
  
  // Getters de conductor
  bool get autoAcceptRides => _autoAcceptRides;
  int get searchRadius => _searchRadius;
  bool get saveHistory => _saveHistory;

  /// Inicializar preferencias
  Future<void> init() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      _prefs = await SharedPreferences.getInstance();
      await loadPreferences();
      
      _isInitialized = true;
      _isLoading = false;
      debugPrint('✅ PreferencesProvider inicializado exitosamente');
    } catch (e) {
      _error = FirestoreErrorHandler.getSpanishMessage(e);
      _isLoading = false;
      _isInitialized = false;
      debugPrint('❌ Error en PreferencesProvider.init: $e');
    }
    notifyListeners();
  }

  /// Cargar todas las preferencias desde SharedPreferences
  Future<void> loadPreferences() async {
    try {
      // Preferencias generales
      _notificationsEnabled = _prefs.getBool('notifications_enabled') ?? true;
      _locationServices = _prefs.getBool('location_services') ?? true;
      _darkMode = _prefs.getBool('dark_mode') ?? false;
      _language = _prefs.getString('language') ?? 'es';
      _currency = _prefs.getString('currency') ?? 'PEN';
      
      // Preferencias de privacidad
      _shareLocation = _prefs.getBool('share_location') ?? true;
      _shareTrips = _prefs.getBool('share_trips') ?? false;
      _analytics = _prefs.getBool('analytics') ?? true;
      _crashReports = _prefs.getBool('crash_reports') ?? true;
      
      // Preferencias de notificaciones
      _pushNotifications = _prefs.getBool('push_notifications') ?? true;
      _emailNotifications = _prefs.getBool('email_notifications') ?? true;
      _smsNotifications = _prefs.getBool('sms_notifications') ?? false;
      _tripUpdates = _prefs.getBool('trip_updates') ?? true;
      _promotions = _prefs.getBool('promotions') ?? true;
      _newsUpdates = _prefs.getBool('news_updates') ?? false;
      
      // Preferencias de seguridad
      _biometricAuth = _prefs.getBool('biometric_auth') ?? false;
      _twoFactorAuth = _prefs.getBool('two_factor_auth') ?? false;
      _autoLockTime = _prefs.getInt('auto_lock_time') ?? 5;
      
      // Preferencias de la app
      _autoUpdate = _prefs.getBool('auto_update') ?? true;
      _offlineMaps = _prefs.getBool('offline_maps') ?? false;
      _mapStyle = _prefs.getString('map_style') ?? 'standard';
      _soundEffects = _prefs.getBool('sound_effects') ?? true;
      _hapticFeedback = _prefs.getBool('haptic_feedback') ?? true;
      
      // Preferencias de datos
      _syncOnWiFiOnly = _prefs.getBool('sync_on_wifi_only') ?? false;
      _compressImages = _prefs.getBool('compress_images') ?? true;
      _cacheSize = _prefs.getString('cache_size') ?? '150 MB';
      
      // Preferencias de conductor
      _autoAcceptRides = _prefs.getBool('auto_accept_rides') ?? false;
      _searchRadius = _prefs.getInt('search_radius') ?? 5000;
      _saveHistory = _prefs.getBool('save_history') ?? true;
      
      debugPrint('📱 Preferencias cargadas desde SharedPreferences');
    } catch (e) {
      debugPrint('❌ Error cargando preferencias: $e');
    }
    
    notifyListeners();
  }

  // Guardar preferencias en Firebase
  Future<void> saveToFirebase(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'preferences': {
          // Generales
          'notificationsEnabled': _notificationsEnabled,
          'locationServices': _locationServices,
          'darkMode': _darkMode,
          'language': _language,
          'currency': _currency,
          
          // Privacidad
          'shareLocation': _shareLocation,
          'shareTrips': _shareTrips,
          'analytics': _analytics,
          'crashReports': _crashReports,
          
          // Notificaciones
          'pushNotifications': _pushNotifications,
          'emailNotifications': _emailNotifications,
          'smsNotifications': _smsNotifications,
          'tripUpdates': _tripUpdates,
          'promotions': _promotions,
          'newsUpdates': _newsUpdates,
          
          // Seguridad
          'biometricAuth': _biometricAuth,
          'twoFactorAuth': _twoFactorAuth,
          'autoLockTime': _autoLockTime,
          
          // App
          'autoUpdate': _autoUpdate,
          'offlineMaps': _offlineMaps,
          'mapStyle': _mapStyle,
          'soundEffects': _soundEffects,
          'hapticFeedback': _hapticFeedback,
          
          // Datos
          'syncOnWiFiOnly': _syncOnWiFiOnly,
          'compressImages': _compressImages,
          'cacheSize': _cacheSize,
          
          // Conductor
          'autoAcceptRides': _autoAcceptRides,
          'searchRadius': _searchRadius,
          'saveHistory': _saveHistory,
        }
      });
    } catch (e) {
      print('Error al guardar preferencias en Firebase: $e');
    }
  }

  // Cargar preferencias desde Firebase
  Future<void> loadFromFirebase(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists && doc.data()?['preferences'] != null) {
        final prefs = doc.data()!['preferences'];
        
        // Generales
        _notificationsEnabled = prefs['notificationsEnabled'] ?? true;
        _locationServices = prefs['locationServices'] ?? true;
        _darkMode = prefs['darkMode'] ?? false;
        _language = prefs['language'] ?? 'es';
        _currency = prefs['currency'] ?? 'PEN';
        
        // Privacidad
        _shareLocation = prefs['shareLocation'] ?? true;
        _shareTrips = prefs['shareTrips'] ?? false;
        _analytics = prefs['analytics'] ?? true;
        _crashReports = prefs['crashReports'] ?? true;
        
        // Notificaciones
        _pushNotifications = prefs['pushNotifications'] ?? true;
        _emailNotifications = prefs['emailNotifications'] ?? true;
        _smsNotifications = prefs['smsNotifications'] ?? false;
        _tripUpdates = prefs['tripUpdates'] ?? true;
        _promotions = prefs['promotions'] ?? true;
        _newsUpdates = prefs['newsUpdates'] ?? false;
        
        // Seguridad
        _biometricAuth = prefs['biometricAuth'] ?? false;
        _twoFactorAuth = prefs['twoFactorAuth'] ?? false;
        _autoLockTime = prefs['autoLockTime'] ?? 5;
        
        // App
        _autoUpdate = prefs['autoUpdate'] ?? true;
        _offlineMaps = prefs['offlineMaps'] ?? false;
        _mapStyle = prefs['mapStyle'] ?? 'standard';
        _soundEffects = prefs['soundEffects'] ?? true;
        _hapticFeedback = prefs['hapticFeedback'] ?? true;
        
        // Datos
        _syncOnWiFiOnly = prefs['syncOnWiFiOnly'] ?? false;
        _compressImages = prefs['compressImages'] ?? true;
        _cacheSize = prefs['cacheSize'] ?? '150 MB';
        
        // Conductor
        _autoAcceptRides = prefs['autoAcceptRides'] ?? false;
        _searchRadius = prefs['searchRadius'] ?? 5000;
        _saveHistory = prefs['saveHistory'] ?? true;
        
        // Guardar en SharedPreferences
        await _saveAllToPrefs();
        notifyListeners();
      }
    } catch (e) {
      print('Error al cargar preferencias desde Firebase: $e');
    }
  }

  /// Guardar todas las preferencias en SharedPreferences
  Future<void> _saveAllToPrefs() async {
    try {
      // Preferencias generales
      await _prefs.setBool('notifications_enabled', _notificationsEnabled);
      await _prefs.setBool('location_services', _locationServices);
      await _prefs.setBool('dark_mode', _darkMode);
      await _prefs.setString('language', _language);
      await _prefs.setString('currency', _currency);
      
      // Preferencias de privacidad
      await _prefs.setBool('share_location', _shareLocation);
      await _prefs.setBool('share_trips', _shareTrips);
      await _prefs.setBool('analytics', _analytics);
      await _prefs.setBool('crash_reports', _crashReports);
      
      // Preferencias de notificaciones
      await _prefs.setBool('push_notifications', _pushNotifications);
      await _prefs.setBool('email_notifications', _emailNotifications);
      await _prefs.setBool('sms_notifications', _smsNotifications);
      await _prefs.setBool('trip_updates', _tripUpdates);
      await _prefs.setBool('promotions', _promotions);
      await _prefs.setBool('news_updates', _newsUpdates);
      
      // Preferencias de seguridad
      await _prefs.setBool('biometric_auth', _biometricAuth);
      await _prefs.setBool('two_factor_auth', _twoFactorAuth);
      await _prefs.setInt('auto_lock_time', _autoLockTime);
      
      // Preferencias de la app
      await _prefs.setBool('auto_update', _autoUpdate);
      await _prefs.setBool('offline_maps', _offlineMaps);
      await _prefs.setString('map_style', _mapStyle);
      await _prefs.setBool('sound_effects', _soundEffects);
      await _prefs.setBool('haptic_feedback', _hapticFeedback);
      
      // Preferencias de datos
      await _prefs.setBool('sync_on_wifi_only', _syncOnWiFiOnly);
      await _prefs.setBool('compress_images', _compressImages);
      await _prefs.setString('cache_size', _cacheSize);
      
      // Preferencias de conductor
      await _prefs.setBool('auto_accept_rides', _autoAcceptRides);
      await _prefs.setInt('search_radius', _searchRadius);
      await _prefs.setBool('save_history', _saveHistory);
      
      debugPrint('💾 Preferencias guardadas en SharedPreferences');
    } catch (e) {
      debugPrint('❌ Error guardando preferencias: $e');
    }
  }

  // === SETTERS GENERALES ===
  
  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    await _prefs.setBool('notifications_enabled', value);
    notifyListeners();
  }
  
  Future<void> setLocationServices(bool value) async {
    _locationServices = value;
    await _prefs.setBool('location_services', value);
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    print('🌙 DEBUG: setDarkMode llamado con value=$value');
    _darkMode = value;
    print('🌙 DEBUG: _darkMode actualizado a $_darkMode');
    await _prefs.setBool('dark_mode', value);
    print('🌙 DEBUG: SharedPreferences guardado');
    notifyListeners();
    print('🌙 DEBUG: notifyListeners() ejecutado');
  }

  Future<void> setLanguage(String value) async {
    _language = value;
    await _prefs.setString('language', value);
    notifyListeners();
  }

  Future<void> setCurrency(String value) async {
    _currency = value;
    await _prefs.setString('currency', value);
    notifyListeners();
  }
  
  // === SETTERS DE PRIVACIDAD ===

  Future<void> setShareLocation(bool value) async {
    _shareLocation = value;
    await _prefs.setBool('share_location', value);
    notifyListeners();
  }
  
  Future<void> setShareTrips(bool value) async {
    _shareTrips = value;
    await _prefs.setBool('share_trips', value);
    notifyListeners();
  }
  
  Future<void> setAnalytics(bool value) async {
    _analytics = value;
    await _prefs.setBool('analytics', value);
    notifyListeners();
  }
  
  Future<void> setCrashReports(bool value) async {
    _crashReports = value;
    await _prefs.setBool('crash_reports', value);
    notifyListeners();
  }
  
  // === SETTERS DE NOTIFICACIONES ===
  
  Future<void> setPushNotifications(bool value) async {
    _pushNotifications = value;
    await _prefs.setBool('push_notifications', value);
    notifyListeners();
  }
  
  Future<void> setEmailNotifications(bool value) async {
    _emailNotifications = value;
    await _prefs.setBool('email_notifications', value);
    notifyListeners();
  }
  
  Future<void> setSmsNotifications(bool value) async {
    _smsNotifications = value;
    await _prefs.setBool('sms_notifications', value);
    notifyListeners();
  }
  
  Future<void> setTripUpdates(bool value) async {
    _tripUpdates = value;
    await _prefs.setBool('trip_updates', value);
    notifyListeners();
  }
  
  Future<void> setPromotions(bool value) async {
    _promotions = value;
    await _prefs.setBool('promotions', value);
    notifyListeners();
  }
  
  Future<void> setNewsUpdates(bool value) async {
    _newsUpdates = value;
    await _prefs.setBool('news_updates', value);
    notifyListeners();
  }
  
  // === SETTERS DE SEGURIDAD ===
  
  Future<void> setBiometricAuth(bool value) async {
    _biometricAuth = value;
    await _prefs.setBool('biometric_auth', value);
    notifyListeners();
  }
  
  Future<void> setTwoFactorAuth(bool value) async {
    _twoFactorAuth = value;
    await _prefs.setBool('two_factor_auth', value);
    notifyListeners();
  }
  
  Future<void> setAutoLockTime(int value) async {
    _autoLockTime = value;
    await _prefs.setInt('auto_lock_time', value);
    notifyListeners();
  }
  
  // === SETTERS DE LA APP ===
  
  Future<void> setAutoUpdate(bool value) async {
    _autoUpdate = value;
    await _prefs.setBool('auto_update', value);
    notifyListeners();
  }
  
  Future<void> setOfflineMaps(bool value) async {
    _offlineMaps = value;
    await _prefs.setBool('offline_maps', value);
    notifyListeners();
  }
  
  Future<void> setMapStyle(String value) async {
    _mapStyle = value;
    await _prefs.setString('map_style', value);
    notifyListeners();
  }
  
  Future<void> setSoundEffects(bool value) async {
    _soundEffects = value;
    await _prefs.setBool('sound_effects', value);
    notifyListeners();
  }
  
  Future<void> setHapticFeedback(bool value) async {
    _hapticFeedback = value;
    await _prefs.setBool('haptic_feedback', value);
    notifyListeners();
  }
  
  // === SETTERS DE DATOS ===
  
  Future<void> setSyncOnWiFiOnly(bool value) async {
    _syncOnWiFiOnly = value;
    await _prefs.setBool('sync_on_wifi_only', value);
    notifyListeners();
  }
  
  Future<void> setCompressImages(bool value) async {
    _compressImages = value;
    await _prefs.setBool('compress_images', value);
    notifyListeners();
  }
  
  Future<void> setCacheSize(String value) async {
    _cacheSize = value;
    await _prefs.setString('cache_size', value);
    notifyListeners();
  }
  
  // === SETTERS DE CONDUCTOR ===

  Future<void> setAutoAcceptRides(bool value) async {
    _autoAcceptRides = value;
    await _prefs.setBool('auto_accept_rides', value);
    notifyListeners();
  }

  Future<void> setSearchRadius(int value) async {
    _searchRadius = value;
    await _prefs.setInt('search_radius', value);
    notifyListeners();
  }

  Future<void> setSaveHistory(bool value) async {
    _saveHistory = value;
    await _prefs.setBool('save_history', value);
    notifyListeners();
  }

  /// Restablecer todas las preferencias a los valores por defecto
  Future<void> resetToDefaults() async {
    try {
      // Preferencias generales
      _notificationsEnabled = true;
      _locationServices = true;
      _darkMode = false;
      _language = 'es';
      _currency = 'PEN';
      
      // Preferencias de privacidad
      _shareLocation = true;
      _shareTrips = false;
      _analytics = true;
      _crashReports = true;
      
      // Preferencias de notificaciones
      _pushNotifications = true;
      _emailNotifications = true;
      _smsNotifications = false;
      _tripUpdates = true;
      _promotions = true;
      _newsUpdates = false;
      
      // Preferencias de seguridad
      _biometricAuth = false;
      _twoFactorAuth = false;
      _autoLockTime = 5;
      
      // Preferencias de la app
      _autoUpdate = true;
      _offlineMaps = false;
      _mapStyle = 'standard';
      _soundEffects = true;
      _hapticFeedback = true;
      
      // Preferencias de datos
      _syncOnWiFiOnly = false;
      _compressImages = true;
      _cacheSize = '150 MB';
      
      // Preferencias de conductor
      _autoAcceptRides = false;
      _searchRadius = 5000;
      _saveHistory = true;
      
      await _saveAllToPrefs();
      debugPrint('🔄 Preferencias restablecidas a valores por defecto');
    } catch (e) {
      debugPrint('❌ Error restableciendo preferencias: $e');
    }
    notifyListeners();
  }

  /// Limpiar todas las preferencias
  Future<void> clearAll() async {
    try {
      await _prefs.clear();
      await resetToDefaults();
      debugPrint('🗑️ Todas las preferencias limpiadas');
    } catch (e) {
      debugPrint('❌ Error limpiando preferencias: $e');
    }
  }
  
  /// Obtener texto del estilo de mapa
  String getMapStyleText() {
    switch (_mapStyle) {
      case 'standard':
        return 'Estándar';
      case 'satellite':
        return 'Satélite';
      case 'terrain':
        return 'Terreno';
      case 'hybrid':
        return 'Híbrido';
      default:
        return 'Estándar';
    }
  }
  
  /// Limpiar caché (simulado)
  Future<void> clearCache() async {
    try {
      // En una implementación real, aquí limpiarías el caché
      _cacheSize = '0 MB';
      await _prefs.setString('cache_size', _cacheSize);
      debugPrint('🧹 Caché limpiado');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error limpiando caché: $e');
    }
  }
  
  /// Restablecer estado de error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}