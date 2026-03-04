/// Configuración de la API Backend
class ApiConfig {
  // Configuración de desarrollo
  static const String devBaseUrl = 'http://localhost:3000/api';
  
  // Configuración de producción
  static const String prodBaseUrl = 'https://api.rapiteam.app/api';
  
  // URL base actual (cambiar según el entorno)
  static const bool isProduction = false; // Cambiar a true para producción
  static String get baseUrl => isProduction ? prodBaseUrl : devBaseUrl;
  
  // Endpoints
  static const String authLogin = '/auth/login';
  static const String authRegister = '/auth/register';
  static const String authLogout = '/auth/logout';
  static const String authVerifyToken = '/auth/verify';
  
  // Endpoints de usuario
  static const String userProfile = '/users/profile';
  static const String userUpdate = '/users/update';
  static const String userDelete = '/users/delete';
  
  // Endpoints de viajes
  static const String ridesCreate = '/rides/create';
  static const String ridesHistory = '/rides/history';
  static const String ridesActive = '/rides/active';
  static const String ridesCancel = '/rides/cancel';
  static const String ridesComplete = '/rides/complete';
  
  // Endpoints de conductor
  static const String driverStatus = '/drivers/status';
  static const String driverLocation = '/drivers/location';
  static const String driverEarnings = '/drivers/earnings';
  static const String driverMetrics = '/drivers/metrics';
  
  // Timeout configuraciones
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
  // Headers por defecto
  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  // Obtener headers con token
  static Map<String, String> getAuthHeaders(String token) {
    return {
      ...defaultHeaders,
      'Authorization': 'Bearer $token',
    };
  }
}