// API Configuration for Rappi Taxi
class ApiConfig {
  // Environment configuration
  static const String environment = String.fromEnvironment('ENV', defaultValue: 'development');
  
  // Base URLs for different environments
  static const Map<String, String> _baseUrls = {
    'development': 'http://localhost:5001/rappitaxi-app/us-central1',
    'staging': 'https://us-central1-rappitaxi-app-staging.cloudfunctions.net', 
    'production': 'https://us-central1-rappitaxi-app-prod.cloudfunctions.net',
  };
  
  // Get base URL for current environment
  static String get baseUrl => _baseUrls[environment] ?? _baseUrls['development']!;
  
  // API version
  static const String apiVersion = 'v1';
  
  // Full API base URL
  static String get apiBaseUrl => '$baseUrl/api/$apiVersion';
  
  // Individual service endpoints
  static String get authUrl => '$baseUrl/auth';
  static String get ridesUrl => '$baseUrl/rides';
  static String get paymentsUrl => '$baseUrl/payments';
  static String get notificationsUrl => '$baseUrl/notifications';

  // Feature flags
  static const bool enableOfflineMode = true;
  static const bool enablePushNotifications = true;
  static const bool enableLocationTracking = true;
  static const bool enableCrashReporting = true;
  static const bool enableAnalytics = true;
  static const bool enableDebugMode = true;
  
  // Timeout configuration
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);
  
  // Retry configuration
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 1);

  // Security configuration
  static const Duration tokenRefreshThreshold = Duration(minutes: 5);
  static const Duration sessionTimeout = Duration(hours: 24);

  // Headers configuration
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'User-Agent': 'RAPPI-TAXI-APP/1.0.0',
  };

  // Environment specific configurations
  static Map<String, dynamic> get environmentConfig {
    switch (environment) {
      case 'production':
        return {
          'logLevel': 'ERROR',
          'enableDebugPrints': false,
          'enableNetworkLogging': false,
          'crashReportingEnabled': true,
          'analyticsEnabled': true,
        };
      case 'staging':
        return {
          'logLevel': 'INFO',
          'enableDebugPrints': true,
          'enableNetworkLogging': true,
          'crashReportingEnabled': true,
          'analyticsEnabled': true,
        };
      default: // development
        return {
          'logLevel': 'DEBUG',
          'enableDebugPrints': true,
          'enableNetworkLogging': true,
          'crashReportingEnabled': false,
          'analyticsEnabled': false,
        };
    }
  }
  
  // Build URL with parameters
  static String buildUrl(String endpoint, {Map<String, String>? pathParams, Map<String, String>? queryParams}) {
    String url = '$apiBaseUrl$endpoint';
    
    // Replace path parameters
    if (pathParams != null) {
      pathParams.forEach((key, value) {
        url = url.replaceAll('{$key}', value);
      });
    }
    
    // Add query parameters
    if (queryParams != null && queryParams.isNotEmpty) {
      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      url += '?$queryString';
    }
    
    return url;
  }
  
  // Check if running in debug mode
  static bool get isDebugMode => environmentConfig['enableDebugPrints'] as bool;
  
  // Check if analytics is enabled
  static bool get isAnalyticsEnabled => environmentConfig['analyticsEnabled'] as bool;
  
  // Check if crash reporting is enabled
  static bool get isCrashReportingEnabled => environmentConfig['crashReportingEnabled'] as bool;

  // Endpoints getter  
  static final Endpoints = _endpoints;
  static final _endpoints = EndpointsClass();
}

// API Endpoints
class EndpointsClass {
  // Authentication endpoints
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String refreshToken = '/auth/refresh';
  static const String resetPassword = '/auth/reset-password';
  static const String verifyEmail = '/auth/verify-email';
  static const String changePassword = '/auth/change-password';
  static const String updateProfile = '/auth/profile';
  static const String deleteAccount = '/auth/account';
  
  // User management endpoints
  static const String getUserProfile = '/auth/profile';
  static const String updateUserProfile = '/auth/profile';
  static const String uploadProfilePhoto = '/auth/profile/photo';
  static const String updateRole = '/auth/role';
  
  // Rides endpoints
  static const String createRide = '/rides';
  static const String getRides = '/rides';
  static const String getRide = '/rides/{id}';
  static const String updateRide = '/rides/{id}';
  static const String cancelRide = '/rides/{id}/cancel';
  static const String acceptRide = '/rides/{id}/accept';
  static const String startRide = '/rides/{id}/start';
  static const String completeRide = '/rides/{id}/complete';
  static const String getRideHistory = '/rides/history';
  static const String updateLocation = '/rides/{id}/location';
  static const String getNearbyRides = '/rides/nearby';
  static const String estimateFare = '/rides/estimate';
  
  // Driver specific endpoints
  static const String updateDriverStatus = '/rides/driver/status';
  static const String getDriverEarnings = '/rides/driver/earnings';
  static const String getDriverAnalytics = '/rides/driver/analytics';
  
  // Payments endpoints
  static const String createPayment = '/payments';
  static const String getPayments = '/payments';
  static const String getPayment = '/payments/{id}';
  static const String processPayment = '/payments/{id}/process';
  static const String refundPayment = '/payments/{id}/refund';
  static const String getPaymentMethods = '/payments/methods';
  static const String addPaymentMethod = '/payments/methods';
  static const String removePaymentMethod = '/payments/methods/{id}';
  
  // Notification endpoints
  static const String getNotifications = '/notifications';
  static const String markAsRead = '/notifications/{id}/read';
  static const String clearNotifications = '/notifications/clear';
  static const String updatePushToken = '/notifications/token';
  
  // Chat endpoints
  static const String sendMessage = '/chat/{rideId}/message';
  static const String getMessages = '/chat/{rideId}/messages';
  static const String getChatHistory = '/chat/{rideId}';
  
  // Analytics endpoints
  static const String trackEvent = '/analytics/event';
  static const String getUserAnalytics = '/analytics/user';
  static const String getSystemAnalytics = '/analytics/system';
  
  // Admin endpoints
  static const String adminDashboard = '/admin/dashboard';
  static const String adminUsers = '/admin/users';
  static const String adminRides = '/admin/rides';
  static const String adminPayments = '/admin/payments';
  static const String adminReports = '/admin/reports';
  
  // Rating endpoints
  static const String rateRide = '/rides/{id}/rate';
  static const String getRatings = '/ratings';
}

// Error codes
class ErrorCodes {
  static const String networkError = 'NETWORK_ERROR';
  static const String timeoutError = 'TIMEOUT_ERROR';
  static const String unauthorizedError = 'UNAUTHORIZED';
  static const String forbiddenError = 'FORBIDDEN';
  static const String notFoundError = 'NOT_FOUND';
  static const String validationError = 'VALIDATION_ERROR';
  static const String serverError = 'SERVER_ERROR';
  static const String unknownError = 'UNKNOWN_ERROR';
}

// Success messages
class Messages {
  static const String loginSuccess = 'Inicio de sesión exitoso';
  static const String registerSuccess = 'Registro exitoso';
  static const String profileUpdated = 'Perfil actualizado';
  static const String rideCreated = 'Viaje creado';
  static const String rideAccepted = 'Viaje aceptado';
  static const String rideCancelled = 'Viaje cancelado';
  static const String rideCompleted = 'Viaje completado';
  static const String paymentProcessed = 'Pago procesado';
  static const String notificationSent = 'Notificación enviada';
}

// Validation rules
class Validation {
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 50;
  static const int minNameLength = 2;
  static const int maxNameLength = 50;
  static const String phoneRegex = r'^\+[1-9]\d{1,14}$';
  static const String emailRegex = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
}