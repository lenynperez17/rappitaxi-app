import 'package:shared_preferences/shared_preferences.dart';

class PreferenceService {
  static late SharedPreferences _prefs;
  
  // Inicializar preferencias
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  // Claves de configuración
  static const String notificationsEnabled = 'notifications_enabled';
  static const String locationServices = 'location_services';
  static const String darkMode = 'dark_mode';
  static const String language = 'language';
  static const String currency = 'currency';
  
  static const String shareLocation = 'share_location';
  static const String shareTrips = 'share_trips';
  static const String analytics = 'analytics';
  static const String crashReports = 'crash_reports';
  
  static const String pushNotifications = 'push_notifications';
  static const String emailNotifications = 'email_notifications';
  static const String smsNotifications = 'sms_notifications';
  static const String tripUpdates = 'trip_updates';
  static const String promotions = 'promotions';
  static const String newsUpdates = 'news_updates';
  
  static const String biometricAuth = 'biometric_auth';
  static const String twoFactorAuth = 'two_factor_auth';
  static const String autoLockTime = 'auto_lock_time';
  
  static const String autoUpdate = 'auto_update';
  static const String offlineMaps = 'offline_maps';
  static const String mapStyle = 'map_style';
  static const String soundEffects = 'sound_effects';
  static const String hapticFeedback = 'haptic_feedback';
  
  static const String syncOnWiFiOnly = 'sync_on_wifi_only';
  static const String compressImages = 'compress_images';
  
  // Métodos GET
  static bool getNotificationsEnabled() => _prefs.getBool(notificationsEnabled) ?? true;
  static bool getLocationServices() => _prefs.getBool(locationServices) ?? true;
  static bool getDarkMode() => _prefs.getBool(darkMode) ?? false;
  static String getLanguage() => _prefs.getString(language) ?? 'es';
  static String getCurrency() => _prefs.getString(currency) ?? 'PEN';
  
  static bool getShareLocation() => _prefs.getBool(shareLocation) ?? true;
  static bool getShareTrips() => _prefs.getBool(shareTrips) ?? false;
  static bool getAnalytics() => _prefs.getBool(analytics) ?? true;
  static bool getCrashReports() => _prefs.getBool(crashReports) ?? true;
  
  static bool getPushNotifications() => _prefs.getBool(pushNotifications) ?? true;
  static bool getEmailNotifications() => _prefs.getBool(emailNotifications) ?? true;
  static bool getSmsNotifications() => _prefs.getBool(smsNotifications) ?? false;
  static bool getTripUpdates() => _prefs.getBool(tripUpdates) ?? true;
  static bool getPromotions() => _prefs.getBool(promotions) ?? true;
  static bool getNewsUpdates() => _prefs.getBool(newsUpdates) ?? false;
  
  static bool getBiometricAuth() => _prefs.getBool(biometricAuth) ?? false;
  static bool getTwoFactorAuth() => _prefs.getBool(twoFactorAuth) ?? false;
  static int getAutoLockTime() => _prefs.getInt(autoLockTime) ?? 5;
  
  static bool getAutoUpdate() => _prefs.getBool(autoUpdate) ?? true;
  static bool getOfflineMaps() => _prefs.getBool(offlineMaps) ?? false;
  static String getMapStyle() => _prefs.getString(mapStyle) ?? 'standard';
  static bool getSoundEffects() => _prefs.getBool(soundEffects) ?? true;
  static bool getHapticFeedback() => _prefs.getBool(hapticFeedback) ?? true;
  
  static bool getSyncOnWiFiOnly() => _prefs.getBool(syncOnWiFiOnly) ?? false;
  static bool getCompressImages() => _prefs.getBool(compressImages) ?? true;
  
  // Métodos SET
  static Future<bool> setNotificationsEnabled(bool value) => _prefs.setBool(notificationsEnabled, value);
  static Future<bool> setLocationServices(bool value) => _prefs.setBool(locationServices, value);
  static Future<bool> setDarkMode(bool value) => _prefs.setBool(darkMode, value);
  static Future<bool> setLanguage(String value) => _prefs.setString(language, value);
  static Future<bool> setCurrency(String value) => _prefs.setString(currency, value);
  
  static Future<bool> setShareLocation(bool value) => _prefs.setBool(shareLocation, value);
  static Future<bool> setShareTrips(bool value) => _prefs.setBool(shareTrips, value);
  static Future<bool> setAnalytics(bool value) => _prefs.setBool(analytics, value);
  static Future<bool> setCrashReports(bool value) => _prefs.setBool(crashReports, value);
  
  static Future<bool> setPushNotifications(bool value) => _prefs.setBool(pushNotifications, value);
  static Future<bool> setEmailNotifications(bool value) => _prefs.setBool(emailNotifications, value);
  static Future<bool> setSmsNotifications(bool value) => _prefs.setBool(smsNotifications, value);
  static Future<bool> setTripUpdates(bool value) => _prefs.setBool(tripUpdates, value);
  static Future<bool> setPromotions(bool value) => _prefs.setBool(promotions, value);
  static Future<bool> setNewsUpdates(bool value) => _prefs.setBool(newsUpdates, value);
  
  static Future<bool> setBiometricAuth(bool value) => _prefs.setBool(biometricAuth, value);
  static Future<bool> setTwoFactorAuth(bool value) => _prefs.setBool(twoFactorAuth, value);
  static Future<bool> setAutoLockTime(int value) => _prefs.setInt(autoLockTime, value);
  
  static Future<bool> setAutoUpdate(bool value) => _prefs.setBool(autoUpdate, value);
  static Future<bool> setOfflineMaps(bool value) => _prefs.setBool(offlineMaps, value);
  static Future<bool> setMapStyle(String value) => _prefs.setString(mapStyle, value);
  static Future<bool> setSoundEffects(bool value) => _prefs.setBool(soundEffects, value);
  static Future<bool> setHapticFeedback(bool value) => _prefs.setBool(hapticFeedback, value);
  
  static Future<bool> setSyncOnWiFiOnly(bool value) => _prefs.setBool(syncOnWiFiOnly, value);
  static Future<bool> setCompressImages(bool value) => _prefs.setBool(compressImages, value);
  
  // Restablecer todas las configuraciones
  static Future<void> resetAll() async {
    await _prefs.clear();
  }
  
  // Obtener todas las configuraciones como Map
  static Map<String, dynamic> getAllSettings() {
    return {
      notificationsEnabled: getNotificationsEnabled(),
      locationServices: getLocationServices(),
      darkMode: getDarkMode(),
      language: getLanguage(),
      currency: getCurrency(),
      shareLocation: getShareLocation(),
      shareTrips: getShareTrips(),
      analytics: getAnalytics(),
      crashReports: getCrashReports(),
      pushNotifications: getPushNotifications(),
      emailNotifications: getEmailNotifications(),
      smsNotifications: getSmsNotifications(),
      tripUpdates: getTripUpdates(),
      promotions: getPromotions(),
      newsUpdates: getNewsUpdates(),
      biometricAuth: getBiometricAuth(),
      twoFactorAuth: getTwoFactorAuth(),
      autoLockTime: getAutoLockTime(),
      autoUpdate: getAutoUpdate(),
      offlineMaps: getOfflineMaps(),
      mapStyle: getMapStyle(),
      soundEffects: getSoundEffects(),
      hapticFeedback: getHapticFeedback(),
      syncOnWiFiOnly: getSyncOnWiFiOnly(),
      compressImages: getCompressImages(),
    };
  }
}