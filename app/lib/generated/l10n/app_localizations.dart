import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es')
  ];

  /// Título de la pantalla de perfil
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get profile;

  /// Etiqueta para la opción de idioma
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get language;

  /// Nombre del idioma español
  ///
  /// In es, this message translates to:
  /// **'Español'**
  String get spanish;

  /// Nombre del idioma inglés
  ///
  /// In es, this message translates to:
  /// **'English'**
  String get english;

  /// Etiqueta para notificaciones
  ///
  /// In es, this message translates to:
  /// **'Notificaciones'**
  String get notifications;

  /// Etiqueta para sonido
  ///
  /// In es, this message translates to:
  /// **'Sonido'**
  String get sound;

  /// Etiqueta para vibración
  ///
  /// In es, this message translates to:
  /// **'Vibración'**
  String get vibration;

  /// Etiqueta para promociones
  ///
  /// In es, this message translates to:
  /// **'Promociones'**
  String get promotions;

  /// Etiqueta para noticias
  ///
  /// In es, this message translates to:
  /// **'Noticias'**
  String get news;

  /// Etiqueta para privacidad
  ///
  /// In es, this message translates to:
  /// **'Privacidad'**
  String get privacy;

  /// Términos y condiciones del servicio
  ///
  /// In es, this message translates to:
  /// **'Términos y Condiciones'**
  String get termsAndConditions;

  /// Política de privacidad
  ///
  /// In es, this message translates to:
  /// **'Política de Privacidad'**
  String get privacyPolicy;

  /// Gestionar permisos de la aplicación
  ///
  /// In es, this message translates to:
  /// **'Gestionar Permisos'**
  String get managePermissions;

  /// Exportar datos personales
  ///
  /// In es, this message translates to:
  /// **'Exportar mis Datos'**
  String get exportMyData;

  /// Métodos de pago disponibles
  ///
  /// In es, this message translates to:
  /// **'Métodos de Pago'**
  String get paymentMethods;

  /// Título historial de viajes
  ///
  /// In es, this message translates to:
  /// **'Historial de Viajes'**
  String get tripHistory;

  /// Calificaciones del usuario
  ///
  /// In es, this message translates to:
  /// **'Calificaciones'**
  String get ratings;

  /// Lugares favoritos guardados
  ///
  /// In es, this message translates to:
  /// **'Lugares Favoritos'**
  String get favoritePlaces;

  /// Cerrar sesión del usuario
  ///
  /// In es, this message translates to:
  /// **'Cerrar Sesión'**
  String get logout;

  /// Mensaje de confirmación de cambio de idioma a español
  ///
  /// In es, this message translates to:
  /// **'Idioma cambiado a Español'**
  String get languageChangedToSpanish;

  /// Mensaje de confirmación de cambio de idioma a inglés
  ///
  /// In es, this message translates to:
  /// **'Language changed to English'**
  String get languageChangedToEnglish;

  /// Método de pago predeterminado
  ///
  /// In es, this message translates to:
  /// **'Método de Pago Predeterminado'**
  String get defaultPaymentMethod;

  /// Método de pago en efectivo
  ///
  /// In es, this message translates to:
  /// **'Efectivo'**
  String get cash;

  /// Método de pago con tarjeta
  ///
  /// In es, this message translates to:
  /// **'Tarjeta'**
  String get card;

  /// Pantalla de inicio
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get home;

  /// Sección de viajes
  ///
  /// In es, this message translates to:
  /// **'Viajes'**
  String get trips;

  /// Sección de mensajes
  ///
  /// In es, this message translates to:
  /// **'Mensajes'**
  String get messages;

  /// Configuración de la aplicación
  ///
  /// In es, this message translates to:
  /// **'Configuración'**
  String get settings;

  /// Opción para convertirse en conductor
  ///
  /// In es, this message translates to:
  /// **'Convertirse en Conductor'**
  String get upgradeToDriver;

  /// Mensaje de carga
  ///
  /// In es, this message translates to:
  /// **'Cargando...'**
  String get loading;

  /// Mensaje de error genérico
  ///
  /// In es, this message translates to:
  /// **'Error'**
  String get error;

  /// Mensaje de éxito genérico
  ///
  /// In es, this message translates to:
  /// **'Éxito'**
  String get success;

  /// Botón cancelar
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// Botón aceptar
  ///
  /// In es, this message translates to:
  /// **'Aceptar'**
  String get accept;

  /// Botón guardar
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get save;

  /// Tab de información personal
  ///
  /// In es, this message translates to:
  /// **'Información'**
  String get information;

  /// Tab de estadísticas
  ///
  /// In es, this message translates to:
  /// **'Estadísticas'**
  String get statistics;

  /// Tab de preferencias
  ///
  /// In es, this message translates to:
  /// **'Preferencias'**
  String get preferences;

  /// Título de sección información personal
  ///
  /// In es, this message translates to:
  /// **'Información Personal'**
  String get personalInformation;

  /// Campo nombre completo
  ///
  /// In es, this message translates to:
  /// **'Nombre completo'**
  String get fullName;

  /// Campo correo electrónico
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico'**
  String get email;

  /// Campo teléfono
  ///
  /// In es, this message translates to:
  /// **'Teléfono'**
  String get phone;

  /// Campo fecha de nacimiento
  ///
  /// In es, this message translates to:
  /// **'Fecha de nacimiento'**
  String get birthDate;

  /// Título de verificación de cuenta
  ///
  /// In es, this message translates to:
  /// **'Verificación'**
  String get verification;

  /// Email verificado
  ///
  /// In es, this message translates to:
  /// **'Email verificado'**
  String get emailVerified;

  /// Teléfono verificado
  ///
  /// In es, this message translates to:
  /// **'Teléfono verificado'**
  String get phoneVerified;

  /// Documento de identidad
  ///
  /// In es, this message translates to:
  /// **'Documento de identidad'**
  String get identityDocument;

  /// Llamada a acción para ser conductor
  ///
  /// In es, this message translates to:
  /// **'¡Conviértete en Conductor!'**
  String get becomeDriver;

  /// Subtítulo convertirse en conductor
  ///
  /// In es, this message translates to:
  /// **'Gana dinero conduciendo'**
  String get earnMoneyDriving;

  /// Botón cambiar contraseña
  ///
  /// In es, this message translates to:
  /// **'Cambiar contraseña'**
  String get changePassword;

  /// Botón eliminar cuenta
  ///
  /// In es, this message translates to:
  /// **'Eliminar cuenta'**
  String get deleteAccount;

  /// Título de estadísticas
  ///
  /// In es, this message translates to:
  /// **'Tus Estadísticas'**
  String get yourStatistics;

  /// Total de viajes
  ///
  /// In es, this message translates to:
  /// **'Viajes Totales'**
  String get totalTrips;

  /// Gasto total
  ///
  /// In es, this message translates to:
  /// **'Gasto Total'**
  String get totalSpent;

  /// Distancia recorrida
  ///
  /// In es, this message translates to:
  /// **'Distancia'**
  String get distance;

  /// Calificación del usuario
  ///
  /// In es, this message translates to:
  /// **'Calificación'**
  String get rating;

  /// Título de logros
  ///
  /// In es, this message translates to:
  /// **'Logros Desbloqueados'**
  String get achievementsUnlocked;

  /// Logro viajero frecuente
  ///
  /// In es, this message translates to:
  /// **'Viajero Frecuente'**
  String get frequentTraveler;

  /// Logro puntual
  ///
  /// In es, this message translates to:
  /// **'Puntual'**
  String get punctual;

  /// Logro explorador
  ///
  /// In es, this message translates to:
  /// **'Explorador'**
  String get explorer;

  /// Logro VIP
  ///
  /// In es, this message translates to:
  /// **'VIP'**
  String get vip;

  /// Logro embajador
  ///
  /// In es, this message translates to:
  /// **'Embajador'**
  String get ambassador;

  /// Título de actividad mensual
  ///
  /// In es, this message translates to:
  /// **'Actividad Mensual'**
  String get monthlyActivity;

  /// Miembro desde
  ///
  /// In es, this message translates to:
  /// **'Miembro desde'**
  String get memberSince;

  /// Amigos referidos
  ///
  /// In es, this message translates to:
  /// **'Amigos referidos'**
  String get referredFriends;

  /// Notificaciones push
  ///
  /// In es, this message translates to:
  /// **'Notificaciones push'**
  String get pushNotifications;

  /// Descripción notificaciones
  ///
  /// In es, this message translates to:
  /// **'Recibe alertas de viajes y ofertas'**
  String get receiveTripAlerts;

  /// Descripción sonido
  ///
  /// In es, this message translates to:
  /// **'Activa sonidos de notificación'**
  String get activateSounds;

  /// Descripción vibración
  ///
  /// In es, this message translates to:
  /// **'Vibra al recibir notificaciones'**
  String get vibrateOnNotifications;

  /// Descripción promociones
  ///
  /// In es, this message translates to:
  /// **'Recibe ofertas y descuentos especiales'**
  String get receiveOffers;

  /// Título novedades
  ///
  /// In es, this message translates to:
  /// **'Novedades'**
  String get newsTitle;

  /// Descripción novedades
  ///
  /// In es, this message translates to:
  /// **'Entérate de nuevas funciones'**
  String get learnNewFeatures;

  /// Título preferencias de viaje
  ///
  /// In es, this message translates to:
  /// **'Preferencias de Viaje'**
  String get travelPreferences;

  /// Método de pago billetera
  ///
  /// In es, this message translates to:
  /// **'Billetera'**
  String get wallet;

  /// Título privacidad y seguridad
  ///
  /// In es, this message translates to:
  /// **'Privacidad y Seguridad'**
  String get privacyAndSecurity;

  /// Mensaje perfil actualizado
  ///
  /// In es, this message translates to:
  /// **'Perfil actualizado exitosamente'**
  String get profileUpdated;

  /// Cambiar foto de perfil
  ///
  /// In es, this message translates to:
  /// **'Cambiar foto de perfil'**
  String get changeProfilePhoto;

  /// Tomar foto
  ///
  /// In es, this message translates to:
  /// **'Tomar foto'**
  String get takePhoto;

  /// Elegir de galería
  ///
  /// In es, this message translates to:
  /// **'Elegir de galería'**
  String get chooseFromGallery;

  /// Eliminar foto
  ///
  /// In es, this message translates to:
  /// **'Eliminar foto'**
  String get deletePhoto;

  /// Foto eliminada
  ///
  /// In es, this message translates to:
  /// **'Foto de perfil eliminada'**
  String get profilePhotoDeleted;

  /// Se necesitan permisos
  ///
  /// In es, this message translates to:
  /// **'Se necesitan permisos para acceder a la cámara/galería'**
  String get permissionsNeeded;

  /// Abrir configuración
  ///
  /// In es, this message translates to:
  /// **'Abrir configuración'**
  String get openSettings;

  /// Foto actualizada
  ///
  /// In es, this message translates to:
  /// **'Foto de perfil actualizada'**
  String get profilePhotoUpdated;

  /// Error al seleccionar imagen
  ///
  /// In es, this message translates to:
  /// **'Error al seleccionar imagen'**
  String get errorSelectingImage;

  /// Prefijo método de pago
  ///
  /// In es, this message translates to:
  /// **'Método de pago:'**
  String get paymentMethodPrefix;

  /// Título cambiar contraseña
  ///
  /// In es, this message translates to:
  /// **'Cambiar Contraseña'**
  String get changePasswordTitle;

  /// Contraseña actual
  ///
  /// In es, this message translates to:
  /// **'Contraseña actual'**
  String get currentPassword;

  /// Nueva contraseña
  ///
  /// In es, this message translates to:
  /// **'Nueva contraseña'**
  String get newPassword;

  /// Confirmar nueva contraseña
  ///
  /// In es, this message translates to:
  /// **'Confirmar nueva contraseña'**
  String get confirmNewPassword;

  /// Contraseña actualizada
  ///
  /// In es, this message translates to:
  /// **'Contraseña actualizada'**
  String get passwordUpdated;

  /// Botón cambiar
  ///
  /// In es, this message translates to:
  /// **'Cambiar'**
  String get change;

  /// Título eliminar cuenta
  ///
  /// In es, this message translates to:
  /// **'Eliminar Cuenta'**
  String get deleteAccountTitle;

  /// Confirmación eliminar cuenta
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro de que deseas eliminar tu cuenta? Esta acción no se puede deshacer.'**
  String get deleteAccountConfirmation;

  /// Botón eliminar
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get delete;

  /// Botón entendido
  ///
  /// In es, this message translates to:
  /// **'Entendido'**
  String get understood;

  /// Error obteniendo info usuario
  ///
  /// In es, this message translates to:
  /// **'No se pudo obtener información del usuario'**
  String get userInfoError;

  /// Título datos exportados
  ///
  /// In es, this message translates to:
  /// **'Datos Exportados'**
  String get dataExported;

  /// Mensaje éxito exportación
  ///
  /// In es, this message translates to:
  /// **'Tus datos han sido exportados exitosamente.'**
  String get dataExportedSuccess;

  /// Ubicación del archivo
  ///
  /// In es, this message translates to:
  /// **'Ubicación:'**
  String get location;

  /// Error exportando datos
  ///
  /// In es, this message translates to:
  /// **'Error al exportar datos:'**
  String get errorExportingData;

  /// No se pudo abrir configuración
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir la configuración'**
  String get couldNotOpenSettings;

  /// Instrucciones abrir configuración manualmente
  ///
  /// In es, this message translates to:
  /// **'Por favor, abre Configuración > Apps > Rappi Team > Permisos manualmente'**
  String get openSettingsManually;

  /// Rol de usuario pasajero
  ///
  /// In es, this message translates to:
  /// **'Pasajero'**
  String get passenger;

  /// Rol de usuario conductor
  ///
  /// In es, this message translates to:
  /// **'Conductor'**
  String get driver;

  /// Rol de usuario administrador
  ///
  /// In es, this message translates to:
  /// **'Administrador'**
  String get administrator;

  /// Campo número de teléfono
  ///
  /// In es, this message translates to:
  /// **'Número de teléfono'**
  String get phoneNumber;

  /// Hint para formato de teléfono
  ///
  /// In es, this message translates to:
  /// **'999 999 999'**
  String get phoneHint;

  /// Validación campo teléfono vacío
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu número de teléfono'**
  String get enterPhoneNumber;

  /// Error de validación número de teléfono
  ///
  /// In es, this message translates to:
  /// **'Número peruano inválido\\nFormato: 9XXXXXXXX'**
  String get invalidPhoneNumber;

  /// Error detallado de validación de teléfono
  ///
  /// In es, this message translates to:
  /// **'Número inválido. Debe ser peruano móvil: 9XXXXXXXX\\nOperadores válidos: Claro, Movistar, Entel'**
  String get invalidPhoneDetails;

  /// Error operador móvil no válido
  ///
  /// In es, this message translates to:
  /// **'Operador móvil no reconocido. Use números de Claro, Movistar o Entel.'**
  String get operatorNotRecognized;

  /// Error operador no válido corto
  ///
  /// In es, this message translates to:
  /// **'Operador no válido\\nUse Claro, Movistar o Entel'**
  String get operatorNotValid;

  /// Campo contraseña
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get password;

  /// Hint de contraseña
  ///
  /// In es, this message translates to:
  /// **'Mínimo 8 caracteres'**
  String get passwordHint;

  /// Validación contraseña vacía
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu contraseña'**
  String get enterPassword;

  /// Error longitud mínima contraseña
  ///
  /// In es, this message translates to:
  /// **'La contraseña debe tener al menos 8 caracteres'**
  String get passwordMinLength;

  /// Link recuperar contraseña
  ///
  /// In es, this message translates to:
  /// **'¿Olvidaste tu contraseña?'**
  String get forgotPassword;

  /// Botón de inicio de sesión
  ///
  /// In es, this message translates to:
  /// **'Iniciar Sesión'**
  String get signIn;

  /// Divider para login con redes sociales
  ///
  /// In es, this message translates to:
  /// **'O continúa con'**
  String get orContinueWith;

  /// Pregunta si no tiene cuenta
  ///
  /// In es, this message translates to:
  /// **'¿No tienes cuenta? '**
  String get noAccount;

  /// Link para registrarse
  ///
  /// In es, this message translates to:
  /// **'Regístrate'**
  String get register;

  /// Eslogan de Rappi Team
  ///
  /// In es, this message translates to:
  /// **'Tu viaje, tu precio'**
  String get tagline;

  /// Error de rate limiting
  ///
  /// In es, this message translates to:
  /// **'Demasiados intentos fallidos. Intenta de nuevo en {minutes} minutos.'**
  String tooManyAttempts(int minutes);

  /// Mensaje de cuenta bloqueada
  ///
  /// In es, this message translates to:
  /// **'Tu cuenta ha sido bloqueada temporalmente por seguridad. Intenta de nuevo más tarde o contacta soporte.'**
  String get accountLocked;

  /// Error email no verificado
  ///
  /// In es, this message translates to:
  /// **'Por favor verifica tu email antes de continuar. Revisa tu bandeja de entrada.'**
  String get verifyEmailFirst;

  /// Error genérico de login
  ///
  /// In es, this message translates to:
  /// **'Error al iniciar sesión'**
  String get loginError;

  /// Error inesperado genérico
  ///
  /// In es, this message translates to:
  /// **'Error inesperado: {error}'**
  String unexpectedError(String error);

  /// Error Google OAuth no configurado
  ///
  /// In es, this message translates to:
  /// **'Google Sign-In no configurado.\\nContacta al administrador del sistema.'**
  String get googleSignInNotConfigured;

  /// Error Facebook OAuth no configurado
  ///
  /// In es, this message translates to:
  /// **'Facebook Login no configurado.\\nContacta al administrador del sistema.'**
  String get facebookLoginNotConfigured;

  /// Error Apple OAuth no configurado
  ///
  /// In es, this message translates to:
  /// **'Apple Sign-In no configurado.\\nContacta al administrador del sistema.'**
  String get appleSignInNotConfigured;

  /// Error genérico Google Sign-In
  ///
  /// In es, this message translates to:
  /// **'Error al iniciar sesión con Google. Intenta nuevamente.'**
  String get googleSignInError;

  /// Error genérico Facebook Login
  ///
  /// In es, this message translates to:
  /// **'Error al iniciar sesión con Facebook. Intenta nuevamente.'**
  String get facebookSignInError;

  /// Error genérico Apple Sign-In
  ///
  /// In es, this message translates to:
  /// **'Error al iniciar sesión con Apple. Intenta nuevamente.'**
  String get appleSignInError;

  /// Título resumen mensual
  ///
  /// In es, this message translates to:
  /// **'Resumen del Mes'**
  String get monthSummary;

  /// Label de dinero gastado
  ///
  /// In es, this message translates to:
  /// **'Gastado'**
  String get spent;

  /// Filtro todos
  ///
  /// In es, this message translates to:
  /// **'Todos'**
  String get all;

  /// Filtro viajes completados
  ///
  /// In es, this message translates to:
  /// **'Completados'**
  String get completed;

  /// Filtro viajes cancelados
  ///
  /// In es, this message translates to:
  /// **'Cancelados'**
  String get cancelled;

  /// Label fecha
  ///
  /// In es, this message translates to:
  /// **'Fecha'**
  String get date;

  /// Mensaje descargando historial
  ///
  /// In es, this message translates to:
  /// **'Descargando historial...'**
  String get downloading;

  /// Mensaje sin viajes
  ///
  /// In es, this message translates to:
  /// **'No hay viajes'**
  String get noTrips;

  /// Sugerencia ajustar filtros
  ///
  /// In es, this message translates to:
  /// **'Ajusta los filtros para ver más resultados'**
  String get adjustFilters;

  /// Título detalles del viaje
  ///
  /// In es, this message translates to:
  /// **'Detalles del Viaje'**
  String get tripDetails;

  /// Sección ruta del viaje
  ///
  /// In es, this message translates to:
  /// **'Ruta del Viaje'**
  String get tripRoute;

  /// Label origen
  ///
  /// In es, this message translates to:
  /// **'Origen'**
  String get origin;

  /// Label destino
  ///
  /// In es, this message translates to:
  /// **'Destino'**
  String get destination;

  /// Label duración
  ///
  /// In es, this message translates to:
  /// **'Duración'**
  String get duration;

  /// Label vehículo
  ///
  /// In es, this message translates to:
  /// **'Vehículo'**
  String get vehicle;

  /// Sección pago
  ///
  /// In es, this message translates to:
  /// **'Pago'**
  String get payment;

  /// Label monto
  ///
  /// In es, this message translates to:
  /// **'Monto'**
  String get amount;

  /// Label método de pago
  ///
  /// In es, this message translates to:
  /// **'Método'**
  String get method;

  /// Método de pago predeterminado
  ///
  /// In es, this message translates to:
  /// **'Efectivo (predeterminado)'**
  String get defaultCash;

  /// Botón calificar viaje
  ///
  /// In es, this message translates to:
  /// **'Calificar Viaje'**
  String get rateTrip;

  /// Label tu calificación
  ///
  /// In es, this message translates to:
  /// **'Tu calificación: {rating}'**
  String yourRating(String rating);

  /// Botón reportar problema
  ///
  /// In es, this message translates to:
  /// **'Reportar problema'**
  String get reportProblem;

  /// Botón ver recibo
  ///
  /// In es, this message translates to:
  /// **'Ver recibo'**
  String get viewReceipt;

  /// Fecha relativa hoy
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get today;

  /// Fecha relativa ayer
  ///
  /// In es, this message translates to:
  /// **'Ayer'**
  String get yesterday;

  /// Fecha relativa días atrás
  ///
  /// In es, this message translates to:
  /// **'Hace {days} días'**
  String daysAgo(int days);

  /// Estado completado
  ///
  /// In es, this message translates to:
  /// **'Completado'**
  String get completedStatus;

  /// Estado cancelado
  ///
  /// In es, this message translates to:
  /// **'Cancelado'**
  String get cancelledStatus;

  /// Hint campo origen
  ///
  /// In es, this message translates to:
  /// **'¿Dónde estás?'**
  String get whereAreYou;

  /// Hint campo destino
  ///
  /// In es, this message translates to:
  /// **'¿A dónde vas?'**
  String get whereAreYouGoing;

  /// Error validación origen y destino
  ///
  /// In es, this message translates to:
  /// **'Debes ingresar origen y destino'**
  String get enterOriginAndDestination;

  /// Error usuario no autenticado
  ///
  /// In es, this message translates to:
  /// **'Error: Usuario no autenticado'**
  String get userNotAuthenticated;

  /// Error permisos de ubicación
  ///
  /// In es, this message translates to:
  /// **'No se pudo obtener la ubicación actual. Verifica los permisos GPS.'**
  String get locationPermissionDenied;

  /// Error geocoding destino
  ///
  /// In es, this message translates to:
  /// **'No se pudo encontrar la dirección de destino'**
  String get destinationAddressNotFound;

  /// Mensaje buscando conductores
  ///
  /// In es, this message translates to:
  /// **'Buscando conductores disponibles...'**
  String get searchingAvailableDrivers;

  /// Error al solicitar viaje
  ///
  /// In es, this message translates to:
  /// **'Error al solicitar viaje: {error}'**
  String errorRequestingTrip(String error);

  /// Error validación destino vacío
  ///
  /// In es, this message translates to:
  /// **'Por favor selecciona un destino'**
  String get selectDestinationFirst;

  /// Error obtener ubicación actual
  ///
  /// In es, this message translates to:
  /// **'No se pudo obtener tu ubicación actual'**
  String get couldNotGetCurrentLocation;

  /// Menú ayuda
  ///
  /// In es, this message translates to:
  /// **'Ayuda'**
  String get helpCenter;

  /// Confirmación cerrar sesión
  ///
  /// In es, this message translates to:
  /// **'¿Cerrar sesión?'**
  String get logoutConfirmation;

  /// Mensaje éxito al calificar
  ///
  /// In es, this message translates to:
  /// **'Calificación enviada correctamente'**
  String get ratingSubmittedSuccessfully;

  /// Error al calificar
  ///
  /// In es, this message translates to:
  /// **'Error al enviar calificación: {error}'**
  String errorSubmittingRating(String error);

  /// Hint campo precio
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu precio'**
  String get enterPrice;

  /// No description provided for @rappiTeam.
  ///
  /// In es, this message translates to:
  /// **'RAPPI TEAM'**
  String get rappiTeam;

  /// No description provided for @preparingExperience.
  ///
  /// In es, this message translates to:
  /// **'Preparando tu experiencia...'**
  String get preparingExperience;

  /// No description provided for @appVersion.
  ///
  /// In es, this message translates to:
  /// **'Versión 2.0.0'**
  String get appVersion;

  /// No description provided for @createAccount.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta'**
  String get createAccount;

  /// No description provided for @continueButton.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get continueButton;

  /// No description provided for @back.
  ///
  /// In es, this message translates to:
  /// **'Atrás'**
  String get back;

  /// No description provided for @howToUseRappiTeam.
  ///
  /// In es, this message translates to:
  /// **'¿Cómo quieres usar Rappi Team?'**
  String get howToUseRappiTeam;

  /// No description provided for @requestTrips.
  ///
  /// In es, this message translates to:
  /// **'Solicita viajes y negocia precios'**
  String get requestTrips;

  /// No description provided for @acceptTrips.
  ///
  /// In es, this message translates to:
  /// **'Acepta viajes y gana dinero'**
  String get acceptTrips;

  /// No description provided for @personalInfo.
  ///
  /// In es, this message translates to:
  /// **'Información personal'**
  String get personalInfo;

  /// No description provided for @enterName.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu nombre'**
  String get enterName;

  /// No description provided for @nineDigits.
  ///
  /// In es, this message translates to:
  /// **'9 dígitos'**
  String get nineDigits;

  /// No description provided for @enterPhoneNumberShort.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu número'**
  String get enterPhoneNumberShort;

  /// No description provided for @mustBeNineDigits.
  ///
  /// In es, this message translates to:
  /// **'Debe tener exactamente 9 dígitos'**
  String get mustBeNineDigits;

  /// No description provided for @mustStartWith9.
  ///
  /// In es, this message translates to:
  /// **'Número móvil debe empezar con 9'**
  String get mustStartWith9;

  /// No description provided for @enterEmail.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu correo'**
  String get enterEmail;

  /// No description provided for @enterValidEmail.
  ///
  /// In es, this message translates to:
  /// **'Ingresa un correo válido'**
  String get enterValidEmail;

  /// No description provided for @createPassword.
  ///
  /// In es, this message translates to:
  /// **'Crea tu contraseña'**
  String get createPassword;

  /// No description provided for @passwordRequirements.
  ///
  /// In es, this message translates to:
  /// **'Mín. 8 caracteres: MAYÚSCULA, minúscula, número y especial (!@#\$%)'**
  String get passwordRequirements;

  /// No description provided for @enterPasswordShort.
  ///
  /// In es, this message translates to:
  /// **'Ingresa una contraseña'**
  String get enterPasswordShort;

  /// No description provided for @minimumEightChars.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 8 caracteres'**
  String get minimumEightChars;

  /// No description provided for @mustIncludeUppercase.
  ///
  /// In es, this message translates to:
  /// **'Debe incluir al menos una MAYÚSCULA'**
  String get mustIncludeUppercase;

  /// No description provided for @mustIncludeLowercase.
  ///
  /// In es, this message translates to:
  /// **'Debe incluir al menos una minúscula'**
  String get mustIncludeLowercase;

  /// No description provided for @mustIncludeNumber.
  ///
  /// In es, this message translates to:
  /// **'Debe incluir al menos un número'**
  String get mustIncludeNumber;

  /// No description provided for @mustIncludeSpecialChar.
  ///
  /// In es, this message translates to:
  /// **'Debe incluir un carácter especial (!@#\$%^&*)'**
  String get mustIncludeSpecialChar;

  /// No description provided for @confirmPassword.
  ///
  /// In es, this message translates to:
  /// **'Confirmar contraseña'**
  String get confirmPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In es, this message translates to:
  /// **'Las contraseñas no coinciden'**
  String get passwordsDoNotMatch;

  /// No description provided for @acceptTerms.
  ///
  /// In es, this message translates to:
  /// **'Acepto los términos y condiciones'**
  String get acceptTerms;

  /// No description provided for @mustAcceptTerms.
  ///
  /// In es, this message translates to:
  /// **'Debes aceptar los términos para continuar'**
  String get mustAcceptTerms;

  /// No description provided for @createAccountButton.
  ///
  /// In es, this message translates to:
  /// **'CREAR CUENTA'**
  String get createAccountButton;

  /// No description provided for @registrationSuccess.
  ///
  /// In es, this message translates to:
  /// **'✅ REGISTRO EXITOSO! Redirigiendo...'**
  String get registrationSuccess;

  /// No description provided for @registrationFailed.
  ///
  /// In es, this message translates to:
  /// **'❌ El registro falló. Intenta nuevamente.'**
  String get registrationFailed;

  /// No description provided for @recoverPassword.
  ///
  /// In es, this message translates to:
  /// **'Recuperar Contraseña'**
  String get recoverPassword;

  /// No description provided for @phoneTab.
  ///
  /// In es, this message translates to:
  /// **'Teléfono'**
  String get phoneTab;

  /// No description provided for @verifyTab.
  ///
  /// In es, this message translates to:
  /// **'Verificar'**
  String get verifyTab;

  /// No description provided for @newTab.
  ///
  /// In es, this message translates to:
  /// **'Nueva'**
  String get newTab;

  /// No description provided for @enterPhoneNumberForgot.
  ///
  /// In es, this message translates to:
  /// **'Ingrese su número de teléfono'**
  String get enterPhoneNumberForgot;

  /// No description provided for @enterPhoneNumberPlaceholder.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu número de teléfono'**
  String get enterPhoneNumberPlaceholder;

  /// No description provided for @sendVerificationCode.
  ///
  /// In es, this message translates to:
  /// **'Te enviaremos un código de verificación por SMS'**
  String get sendVerificationCode;

  /// No description provided for @sendCode.
  ///
  /// In es, this message translates to:
  /// **'Enviar Código'**
  String get sendCode;

  /// No description provided for @smsVerification.
  ///
  /// In es, this message translates to:
  /// **'Verificación por SMS'**
  String get smsVerification;

  /// No description provided for @enterSixDigitCode.
  ///
  /// In es, this message translates to:
  /// **'Ingresa el código de 6 dígitos enviado a'**
  String get enterSixDigitCode;

  /// No description provided for @resendCode.
  ///
  /// In es, this message translates to:
  /// **'Reenviar código'**
  String get resendCode;

  /// No description provided for @verify.
  ///
  /// In es, this message translates to:
  /// **'Verificar'**
  String get verify;

  /// No description provided for @createNewPassword.
  ///
  /// In es, this message translates to:
  /// **'Crear Nueva Contraseña'**
  String get createNewPassword;

  /// No description provided for @enterNewSecurePassword.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu nueva contraseña segura'**
  String get enterNewSecurePassword;

  /// No description provided for @newPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Nueva contraseña'**
  String get newPasswordLabel;

  /// No description provided for @enterPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Ingrese una contraseña'**
  String get enterPasswordLabel;

  /// No description provided for @passwordMinSixChars.
  ///
  /// In es, this message translates to:
  /// **'La contraseña debe tener al menos 6 caracteres'**
  String get passwordMinSixChars;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Confirmar contraseña'**
  String get confirmPasswordLabel;

  /// No description provided for @passwordsDoNotMatchLabel.
  ///
  /// In es, this message translates to:
  /// **'Las contraseñas no coinciden'**
  String get passwordsDoNotMatchLabel;

  /// No description provided for @updatePassword.
  ///
  /// In es, this message translates to:
  /// **'Actualizar Contraseña'**
  String get updatePassword;

  /// No description provided for @passwordUpdatedSuccess.
  ///
  /// In es, this message translates to:
  /// **'¡Contraseña Actualizada!'**
  String get passwordUpdatedSuccess;

  /// No description provided for @passwordUpdatedMessage.
  ///
  /// In es, this message translates to:
  /// **'Tu contraseña ha sido actualizada exitosamente'**
  String get passwordUpdatedMessage;

  /// No description provided for @goToLogin.
  ///
  /// In es, this message translates to:
  /// **'Ir al Login'**
  String get goToLogin;

  /// No description provided for @incorrectCode.
  ///
  /// In es, this message translates to:
  /// **'Código incorrecto'**
  String get incorrectCode;

  /// Título de la pantalla de favoritos
  ///
  /// In es, this message translates to:
  /// **'Lugares Favoritos'**
  String get favoritePlacesTitle;

  /// Placeholder del campo de búsqueda
  ///
  /// In es, this message translates to:
  /// **'Buscar lugar...'**
  String get searchPlaceholder;

  /// Título de la sección de lugares
  ///
  /// In es, this message translates to:
  /// **'Tus Lugares'**
  String get yourPlaces;

  /// Título de lugares visitados recientemente
  ///
  /// In es, this message translates to:
  /// **'Visitados Recientemente'**
  String get recentlyVisited;

  /// Label de favoritos
  ///
  /// In es, this message translates to:
  /// **'Favoritos'**
  String get favorites;

  /// Label de visitas
  ///
  /// In es, this message translates to:
  /// **'Visitas'**
  String get visits;

  /// Label de más visitado
  ///
  /// In es, this message translates to:
  /// **'Más visitado'**
  String get mostVisited;

  /// Badge de lugar principal
  ///
  /// In es, this message translates to:
  /// **'Principal'**
  String get mainBadge;

  /// Texto de visitas
  ///
  /// In es, this message translates to:
  /// **'visitas'**
  String get visitsLabel;

  /// Botón agregar lugar
  ///
  /// In es, this message translates to:
  /// **'Agregar Lugar'**
  String get addPlace;

  /// Título diálogo agregar favorito
  ///
  /// In es, this message translates to:
  /// **'Agregar Favorito'**
  String get addFavorite;

  /// Título diálogo editar lugar
  ///
  /// In es, this message translates to:
  /// **'Editar Lugar'**
  String get editPlace;

  /// Label nombre del lugar
  ///
  /// In es, this message translates to:
  /// **'Nombre del lugar'**
  String get placeName;

  /// Label dirección
  ///
  /// In es, this message translates to:
  /// **'Dirección'**
  String get address;

  /// Label icono
  ///
  /// In es, this message translates to:
  /// **'Icono'**
  String get icon;

  /// Label color
  ///
  /// In es, this message translates to:
  /// **'Color'**
  String get color;

  /// Botón agregar
  ///
  /// In es, this message translates to:
  /// **'Agregar'**
  String get add;

  /// Error validación dirección
  ///
  /// In es, this message translates to:
  /// **'Por favor, selecciona una dirección del autocomplete'**
  String get selectAddressFromAutocomplete;

  /// Mensaje éxito agregar favorito
  ///
  /// In es, this message translates to:
  /// **'Lugar agregado a favoritos'**
  String get placeAddedToFavorites;

  /// Error al cargar favoritos
  ///
  /// In es, this message translates to:
  /// **'Error al cargar favoritos'**
  String get errorLoadingFavorites;

  /// Error al agregar favorito
  ///
  /// In es, this message translates to:
  /// **'Error al agregar favorito'**
  String get errorAddingFavorite;

  /// Mensaje éxito actualizar lugar
  ///
  /// In es, this message translates to:
  /// **'Lugar actualizado'**
  String get placeUpdated;

  /// Error al actualizar favorito
  ///
  /// In es, this message translates to:
  /// **'Error al actualizar favorito'**
  String get errorUpdatingFavorite;

  /// Confirmación eliminar favorito
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro de que deseas eliminar este lugar de tus favoritos?'**
  String get deleteConfirmation;

  /// Mensaje navegando a lugar
  ///
  /// In es, this message translates to:
  /// **'Navegando a'**
  String get navigatingTo;

  /// Título del mapa de favoritos
  ///
  /// In es, this message translates to:
  /// **'Mapa de Favoritos'**
  String get favoritesMap;

  /// Mensaje mapa vacío
  ///
  /// In es, this message translates to:
  /// **'Agrega lugares favoritos para verlos en el mapa'**
  String get addFavoritePlacesToSeeMap;

  /// Título de métodos de pago
  ///
  /// In es, this message translates to:
  /// **'Métodos de Pago'**
  String get paymentMethodsTitle;

  /// Tab de métodos de pago
  ///
  /// In es, this message translates to:
  /// **'Métodos de Pago'**
  String get paymentMethodsTab;

  /// Tab de historial
  ///
  /// In es, this message translates to:
  /// **'Historial'**
  String get historyTab;

  /// Botón agregar método
  ///
  /// In es, this message translates to:
  /// **'Agregar Método'**
  String get addMethod;

  /// Título billetera Rappi Team
  ///
  /// In es, this message translates to:
  /// **'Billetera Rappi Team'**
  String get rappiWallet;

  /// Botón recargar
  ///
  /// In es, this message translates to:
  /// **'Recargar'**
  String get recharge;

  /// Botón historial
  ///
  /// In es, this message translates to:
  /// **'Historial'**
  String get history;

  /// Título métodos guardados
  ///
  /// In es, this message translates to:
  /// **'Métodos Guardados'**
  String get savedMethods;

  /// Label predeterminado
  ///
  /// In es, this message translates to:
  /// **'PREDETERMINADO'**
  String get defaultLabel;

  /// Label titular
  ///
  /// In es, this message translates to:
  /// **'TITULAR'**
  String get holder;

  /// Label vence
  ///
  /// In es, this message translates to:
  /// **'VENCE'**
  String get expires;

  /// Badge predeterminado
  ///
  /// In es, this message translates to:
  /// **'Predeterminado'**
  String get defaultBadge;

  /// Tipo tarjeta de crédito
  ///
  /// In es, this message translates to:
  /// **'Tarjeta de Crédito'**
  String get creditCard;

  /// Tipo tarjeta de débito
  ///
  /// In es, this message translates to:
  /// **'Tarjeta de Débito'**
  String get debitCard;

  /// Método PayPal
  ///
  /// In es, this message translates to:
  /// **'PayPal'**
  String get paypal;

  /// Método efectivo
  ///
  /// In es, this message translates to:
  /// **'Efectivo'**
  String get cashPayment;

  /// Opción establecer como predeterminado
  ///
  /// In es, this message translates to:
  /// **'Establecer como predeterminado'**
  String get setAsDefault;

  /// Opción editar método
  ///
  /// In es, this message translates to:
  /// **'Editar método'**
  String get editMethod;

  /// Opción eliminar método
  ///
  /// In es, this message translates to:
  /// **'Eliminar método'**
  String get deleteMethod;

  /// Mensaje sin métodos de pago
  ///
  /// In es, this message translates to:
  /// **'No hay métodos de pago'**
  String get noPaymentMethods;

  /// Mensaje agregar primer método
  ///
  /// In es, this message translates to:
  /// **'Agrega tu primer método de pago para realizar transacciones más rápido'**
  String get addFirstPaymentMethod;

  /// Título diálogo eliminar método
  ///
  /// In es, this message translates to:
  /// **'Eliminar Método de Pago'**
  String get deletePaymentMethodTitle;

  /// Confirmación eliminar método
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro de que deseas eliminar este método de pago?'**
  String get deletePaymentMethodConfirmation;

  /// Mensaje método eliminado
  ///
  /// In es, this message translates to:
  /// **'Método de pago eliminado'**
  String get paymentMethodDeleted;

  /// Mensaje método predeterminado actualizado
  ///
  /// In es, this message translates to:
  /// **'Método predeterminado actualizado'**
  String get defaultMethodUpdated;

  /// Título agregar método de pago
  ///
  /// In es, this message translates to:
  /// **'Agregar Método de Pago'**
  String get addPaymentMethodTitle;

  /// Instrucción seleccionar tipo
  ///
  /// In es, this message translates to:
  /// **'Selecciona el tipo de pago'**
  String get selectPaymentType;

  /// Label número de tarjeta
  ///
  /// In es, this message translates to:
  /// **'Número de tarjeta'**
  String get cardNumber;

  /// Placeholder número de tarjeta
  ///
  /// In es, this message translates to:
  /// **'1234 5678 9012 3456'**
  String get cardNumberPlaceholder;

  /// Label nombre titular
  ///
  /// In es, this message translates to:
  /// **'Nombre del titular'**
  String get cardholderName;

  /// Placeholder nombre titular
  ///
  /// In es, this message translates to:
  /// **'JUAN PÉREZ'**
  String get cardholderNamePlaceholder;

  /// Label fecha expiración
  ///
  /// In es, this message translates to:
  /// **'Fecha de expiración'**
  String get expirationDate;

  /// Placeholder fecha expiración
  ///
  /// In es, this message translates to:
  /// **'MM/AA'**
  String get expirationDatePlaceholder;

  /// Label CVV
  ///
  /// In es, this message translates to:
  /// **'CVV'**
  String get cvv;

  /// Placeholder CVV
  ///
  /// In es, this message translates to:
  /// **'123'**
  String get cvvPlaceholder;

  /// Label email PayPal
  ///
  /// In es, this message translates to:
  /// **'Email de PayPal'**
  String get paypalEmail;

  /// Placeholder email PayPal
  ///
  /// In es, this message translates to:
  /// **'correo@paypal.com'**
  String get paypalEmailPlaceholder;

  /// Nota método efectivo
  ///
  /// In es, this message translates to:
  /// **'Paga directamente al conductor al finalizar el viaje'**
  String get cashNote;

  /// Botón agregar método de pago
  ///
  /// In es, this message translates to:
  /// **'Agregar Método de Pago'**
  String get addPaymentMethod;

  /// Mensaje método agregado
  ///
  /// In es, this message translates to:
  /// **'Método de pago agregado'**
  String get paymentMethodAdded;

  /// Error número tarjeta inválido
  ///
  /// In es, this message translates to:
  /// **'Número de tarjeta inválido'**
  String get invalidCardNumber;

  /// Error fecha expiración inválida
  ///
  /// In es, this message translates to:
  /// **'Fecha de expiración inválida'**
  String get invalidExpirationDate;

  /// Error CVV inválido
  ///
  /// In es, this message translates to:
  /// **'CVV inválido'**
  String get invalidCvv;

  /// Error email PayPal inválido
  ///
  /// In es, this message translates to:
  /// **'Email de PayPal inválido'**
  String get invalidPaypalEmail;

  /// Título recargar billetera
  ///
  /// In es, this message translates to:
  /// **'Recargar Billetera'**
  String get rechargeWalletTitle;

  /// Instrucción ingresar monto
  ///
  /// In es, this message translates to:
  /// **'Ingresa el monto a recargar'**
  String get enterAmount;

  /// Label monto a recargar
  ///
  /// In es, this message translates to:
  /// **'Monto a recargar'**
  String get amountToRecharge;

  /// Título montos rápidos
  ///
  /// In es, this message translates to:
  /// **'Montos Rápidos'**
  String get quickAmounts;

  /// Label seleccionar método
  ///
  /// In es, this message translates to:
  /// **'Selecciona método de pago'**
  String get selectPaymentMethod;

  /// Botón recargar con monto
  ///
  /// In es, this message translates to:
  /// **'Recargar S/. {amount}'**
  String rechargeButton(String amount);

  /// Error monto mínimo
  ///
  /// In es, this message translates to:
  /// **'El monto mínimo de recarga es S/. 10'**
  String get minimumRechargeAmount;

  /// Error monto máximo
  ///
  /// In es, this message translates to:
  /// **'El monto máximo de recarga es S/. 1000'**
  String get maximumRechargeAmount;

  /// Error seleccionar método
  ///
  /// In es, this message translates to:
  /// **'Selecciona un método de pago'**
  String get selectPaymentMethodToRecharge;

  /// Mensaje recarga exitosa
  ///
  /// In es, this message translates to:
  /// **'Recarga exitosa'**
  String get rechargeSuccessful;

  /// Título historial de transacciones
  ///
  /// In es, this message translates to:
  /// **'Historial de Transacciones'**
  String get transactionHistory;

  /// Label filtrar por tipo
  ///
  /// In es, this message translates to:
  /// **'Filtrar por tipo'**
  String get filterByType;

  /// Filtro todas las transacciones
  ///
  /// In es, this message translates to:
  /// **'Todas'**
  String get allTransactions;

  /// Filtro recargas
  ///
  /// In es, this message translates to:
  /// **'Recargas'**
  String get recharges;

  /// Filtro pagos
  ///
  /// In es, this message translates to:
  /// **'Pagos'**
  String get payments;

  /// Filtro reembolsos
  ///
  /// In es, this message translates to:
  /// **'Reembolsos'**
  String get refunds;

  /// Mensaje sin transacciones
  ///
  /// In es, this message translates to:
  /// **'No hay transacciones'**
  String get noTransactions;

  /// Mensaje sin transacciones descripción
  ///
  /// In es, this message translates to:
  /// **'Aquí aparecerán tus transacciones realizadas'**
  String get transactionsWillAppearHere;

  /// Tipo transacción recarga
  ///
  /// In es, this message translates to:
  /// **'Recarga de billetera'**
  String get walletRecharge;

  /// Tipo transacción pago viaje
  ///
  /// In es, this message translates to:
  /// **'Pago de viaje'**
  String get tripPayment;

  /// Tipo transacción reembolso
  ///
  /// In es, this message translates to:
  /// **'Reembolso'**
  String get refund;

  /// Título mis calificaciones
  ///
  /// In es, this message translates to:
  /// **'Mis Calificaciones'**
  String get myRatingsTitle;

  /// Label total
  ///
  /// In es, this message translates to:
  /// **'Total'**
  String get totalLabel;

  /// Label promedio
  ///
  /// In es, this message translates to:
  /// **'Promedio'**
  String get averageLabel;

  /// Filtro todas las calificaciones
  ///
  /// In es, this message translates to:
  /// **'Todas'**
  String get allRatings;

  /// Filtro 1 estrella
  ///
  /// In es, this message translates to:
  /// **'1 estrella'**
  String get oneStarRating;

  /// Filtro 2 estrellas
  ///
  /// In es, this message translates to:
  /// **'2 estrellas'**
  String get twoStarRating;

  /// Filtro 3 estrellas
  ///
  /// In es, this message translates to:
  /// **'3 estrellas'**
  String get threeStarRating;

  /// Filtro 4 estrellas
  ///
  /// In es, this message translates to:
  /// **'4 estrellas'**
  String get fourStarRating;

  /// Filtro 5 estrellas
  ///
  /// In es, this message translates to:
  /// **'5 estrellas'**
  String get fiveStarRating;

  /// Mensaje sin calificaciones
  ///
  /// In es, this message translates to:
  /// **'No hay calificaciones'**
  String get noRatings;

  /// Mensaje sin calificaciones descripción
  ///
  /// In es, this message translates to:
  /// **'Aquí aparecerán tus calificaciones'**
  String get ratingsWillAppearHere;

  /// Título detalles calificación
  ///
  /// In es, this message translates to:
  /// **'Detalles de la Calificación'**
  String get ratingDetailsTitle;

  /// Label fecha
  ///
  /// In es, this message translates to:
  /// **'Fecha'**
  String get dateLabel;

  /// Label hora
  ///
  /// In es, this message translates to:
  /// **'Hora'**
  String get timeLabel;

  /// Label ruta
  ///
  /// In es, this message translates to:
  /// **'Ruta'**
  String get routeLabel;

  /// Label monto
  ///
  /// In es, this message translates to:
  /// **'Monto'**
  String get amountLabel;

  /// Label ID viaje
  ///
  /// In es, this message translates to:
  /// **'ID Viaje'**
  String get tripIdLabel;

  /// Tag excelente servicio
  ///
  /// In es, this message translates to:
  /// **'Excelente servicio'**
  String get excellentService;

  /// Tag muy satisfecho
  ///
  /// In es, this message translates to:
  /// **'Muy satisfecho'**
  String get verySatisfied;

  /// Tag buen servicio
  ///
  /// In es, this message translates to:
  /// **'Buen servicio'**
  String get goodService;

  /// Tag satisfecho
  ///
  /// In es, this message translates to:
  /// **'Satisfecho'**
  String get satisfied;

  /// Tag servicio aceptable
  ///
  /// In es, this message translates to:
  /// **'Servicio aceptable'**
  String get acceptableService;

  /// Tag servicio regular
  ///
  /// In es, this message translates to:
  /// **'Servicio regular'**
  String get regularService;

  /// Tag mal servicio
  ///
  /// In es, this message translates to:
  /// **'Mal servicio'**
  String get poorService;

  /// Tag necesita mejorar
  ///
  /// In es, this message translates to:
  /// **'Necesita mejorar'**
  String get needsImprovement;

  /// Tag muy mal servicio
  ///
  /// In es, this message translates to:
  /// **'Muy mal servicio'**
  String get veryPoorService;

  /// Tag inaceptable
  ///
  /// In es, this message translates to:
  /// **'Inaceptable'**
  String get unacceptable;

  /// Error al cargar calificaciones
  ///
  /// In es, this message translates to:
  /// **'Error al cargar calificaciones'**
  String get errorLoadingRatings;

  /// Mensaje iniciando chat
  ///
  /// In es, this message translates to:
  /// **'Iniciando chat...'**
  String get initializingChat;

  /// Estado en línea
  ///
  /// In es, this message translates to:
  /// **'En línea'**
  String get onlineStatus;

  /// Visto hace un momento
  ///
  /// In es, this message translates to:
  /// **'Visto hace un momento'**
  String get lastSeenJustNow;

  /// Visto hace minutos
  ///
  /// In es, this message translates to:
  /// **'Visto hace {minutes} min'**
  String lastSeenMinutesAgo(int minutes);

  /// Visto hace horas
  ///
  /// In es, this message translates to:
  /// **'Visto hace {hours}h'**
  String lastSeenHoursAgo(int hours);

  /// Visto hace días
  ///
  /// In es, this message translates to:
  /// **'Visto hace {days}d'**
  String lastSeenDaysAgo(int days);

  /// Mensaje iniciar conversación
  ///
  /// In es, this message translates to:
  /// **'¡Inicia la conversación!'**
  String get startConversation;

  /// Mensaje mantente en contacto
  ///
  /// In es, this message translates to:
  /// **'Mantente en contacto con tu conductor/pasajero'**
  String get stayInTouch;

  /// Tipo mensaje ubicación
  ///
  /// In es, this message translates to:
  /// **'Ubicación compartida'**
  String get sharedLocation;

  /// Tipo mensaje imagen
  ///
  /// In es, this message translates to:
  /// **'Imagen'**
  String get imageMessage;

  /// Tipo mensaje audio
  ///
  /// In es, this message translates to:
  /// **'Audio'**
  String get audioMessage;

  /// Tipo mensaje video
  ///
  /// In es, this message translates to:
  /// **'Video'**
  String get videoMessage;

  /// Tipo mensaje archivo
  ///
  /// In es, this message translates to:
  /// **'Archivo'**
  String get fileMessage;

  /// Placeholder escribir mensaje
  ///
  /// In es, this message translates to:
  /// **'Escribe un mensaje...'**
  String get writeMessagePlaceholder;

  /// Mensaje rápido en camino
  ///
  /// In es, this message translates to:
  /// **'En camino'**
  String get onWay;

  /// Mensaje rápido he llegado
  ///
  /// In es, this message translates to:
  /// **'He llegado'**
  String get arrived;

  /// Mensaje rápido esperando
  ///
  /// In es, this message translates to:
  /// **'Esperando'**
  String get waiting;

  /// Mensaje rápido hay tráfico
  ///
  /// In es, this message translates to:
  /// **'Hay tráfico'**
  String get traffic;

  /// Mensaje rápido no te encuentro
  ///
  /// In es, this message translates to:
  /// **'No te encuentro'**
  String get cantFindYou;

  /// Tiempo ahora
  ///
  /// In es, this message translates to:
  /// **'Ahora'**
  String get now;

  /// Opción limpiar chat
  ///
  /// In es, this message translates to:
  /// **'Limpiar chat'**
  String get clearChat;

  /// Opción reportar usuario
  ///
  /// In es, this message translates to:
  /// **'Reportar usuario'**
  String get reportUser;

  /// Confirmación limpiar chat
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro de que quieres limpiar toda la conversación?'**
  String get clearChatConfirmation;

  /// Error inicializar chat
  ///
  /// In es, this message translates to:
  /// **'Error al inicializar el chat'**
  String get errorInitializingChat;

  /// Error enviar mensaje
  ///
  /// In es, this message translates to:
  /// **'Error al enviar mensaje'**
  String get errorSendingMessage;

  /// Error enviar archivo
  ///
  /// In es, this message translates to:
  /// **'Error al enviar archivo'**
  String get errorSendingFile;

  /// Título detalles del viaje
  ///
  /// In es, this message translates to:
  /// **'Detalles del Viaje'**
  String get tripDetailsTitle;

  /// Mensaje cargando detalles
  ///
  /// In es, this message translates to:
  /// **'Cargando detalles del viaje...'**
  String get loadingTripDetails;

  /// Mensaje viaje no encontrado
  ///
  /// In es, this message translates to:
  /// **'Viaje no encontrado'**
  String get tripNotFound;

  /// Mensaje error cargar detalles
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar los detalles de este viaje'**
  String get couldNotLoadTripDetails;

  /// Label distancia
  ///
  /// In es, this message translates to:
  /// **'Distancia'**
  String get distanceLabel;

  /// Label duración
  ///
  /// In es, this message translates to:
  /// **'Duración'**
  String get durationLabel;

  /// Label tarifa
  ///
  /// In es, this message translates to:
  /// **'Tarifa'**
  String get fareLabel;

  /// Estado viaje completado
  ///
  /// In es, this message translates to:
  /// **'Viaje Completado'**
  String get tripCompleted;

  /// Estado en progreso
  ///
  /// In es, this message translates to:
  /// **'En Progreso'**
  String get inProgress;

  /// Estado cancelado
  ///
  /// In es, this message translates to:
  /// **'Cancelado'**
  String get cancelledTrip;

  /// Estado pendiente
  ///
  /// In es, this message translates to:
  /// **'Pendiente'**
  String get pendingTrip;

  /// Título participantes
  ///
  /// In es, this message translates to:
  /// **'Participantes'**
  String get participants;

  /// Label conductor
  ///
  /// In es, this message translates to:
  /// **'Conductor'**
  String get driverLabel;

  /// Label pasajero
  ///
  /// In es, this message translates to:
  /// **'Pasajero'**
  String get passengerLabel;

  /// Label cliente
  ///
  /// In es, this message translates to:
  /// **'Cliente'**
  String get clientLabel;

  /// Título ruta del viaje
  ///
  /// In es, this message translates to:
  /// **'Ruta del Viaje'**
  String get tripRouteLabel;

  /// Label origen
  ///
  /// In es, this message translates to:
  /// **'Origen'**
  String get originLabel;

  /// Label destino
  ///
  /// In es, this message translates to:
  /// **'Destino'**
  String get destinationLabel;

  /// Título método de pago
  ///
  /// In es, this message translates to:
  /// **'Método de Pago'**
  String get paymentMethodLabel;

  /// Título historial del viaje
  ///
  /// In es, this message translates to:
  /// **'Historial del Viaje'**
  String get tripHistoryLabel;

  /// Evento solicitud creada
  ///
  /// In es, this message translates to:
  /// **'Solicitud creada'**
  String get requestCreated;

  /// Evento viaje iniciado
  ///
  /// In es, this message translates to:
  /// **'Viaje iniciado'**
  String get tripStarted;

  /// Evento viaje completado
  ///
  /// In es, this message translates to:
  /// **'Viaje completado'**
  String get tripCompletedEvent;

  /// Botón ver en Maps
  ///
  /// In es, this message translates to:
  /// **'Ver en Maps'**
  String get viewOnMaps;

  /// Botón chat
  ///
  /// In es, this message translates to:
  /// **'Chat'**
  String get chat;

  /// Botón repetir viaje
  ///
  /// In es, this message translates to:
  /// **'Repetir Viaje'**
  String get repeatTrip;

  /// Opción compartir viaje
  ///
  /// In es, this message translates to:
  /// **'Compartir viaje'**
  String get shareTrip;

  /// Opción descargar recibo
  ///
  /// In es, this message translates to:
  /// **'Descargar recibo'**
  String get downloadReceipt;

  /// Opción reportar problema
  ///
  /// In es, this message translates to:
  /// **'Reportar problema'**
  String get reportProblemOption;

  /// Error no se puede llamar
  ///
  /// In es, this message translates to:
  /// **'No se puede realizar la llamada'**
  String get cannotMakeCall;

  /// Error no se puede abrir Maps
  ///
  /// In es, this message translates to:
  /// **'No se puede abrir Google Maps'**
  String get cannotOpenGoogleMaps;

  /// Tag calificación aceptable
  ///
  /// In es, this message translates to:
  /// **'Aceptable'**
  String get acceptable;

  /// Tag insatisfecho
  ///
  /// In es, this message translates to:
  /// **'Insatisfecho'**
  String get dissatisfied;

  /// Label información del viaje
  ///
  /// In es, this message translates to:
  /// **'Información del Viaje'**
  String get tripInfoLabel;

  /// Label tu comentario
  ///
  /// In es, this message translates to:
  /// **'Tu Comentario'**
  String get yourCommentLabel;

  /// Label etiquetas
  ///
  /// In es, this message translates to:
  /// **'Etiquetas'**
  String get tagsLabel;

  /// Mensaje no se puede editar
  ///
  /// In es, this message translates to:
  /// **'No se puede editar'**
  String get cannotEdit;

  /// Mensaje enviando archivo
  ///
  /// In es, this message translates to:
  /// **'Enviando archivo...'**
  String get sendingFile;

  /// Mensaje iniciando chat
  ///
  /// In es, this message translates to:
  /// **'Iniciando chat...'**
  String get initiatingChat;

  /// Estado en línea
  ///
  /// In es, this message translates to:
  /// **'En línea'**
  String get online;

  /// Visto hace un momento
  ///
  /// In es, this message translates to:
  /// **'Visto hace un momento'**
  String get seenMomentAgo;

  /// Visto hace minutos
  ///
  /// In es, this message translates to:
  /// **'Visto hace {minutes} min'**
  String seenMinutesAgo(int minutes);

  /// Visto hace horas
  ///
  /// In es, this message translates to:
  /// **'Visto hace {hours}h'**
  String seenHoursAgo(int hours);

  /// Visto hace días
  ///
  /// In es, this message translates to:
  /// **'Visto hace {days}d'**
  String seenDaysAgo(int days);

  /// Mensaje mantente en contacto conductor
  ///
  /// In es, this message translates to:
  /// **'Mantente en contacto con tu conductor'**
  String get stayInTouchWithDriver;

  /// Mensaje mantente en contacto pasajero
  ///
  /// In es, this message translates to:
  /// **'Mantente en contacto con tu pasajero'**
  String get stayInTouchWithPassenger;

  /// Label tipo imagen
  ///
  /// In es, this message translates to:
  /// **'Imagen'**
  String get imageLabel;

  /// Label tipo audio
  ///
  /// In es, this message translates to:
  /// **'Audio'**
  String get audioLabel;

  /// Label tipo video
  ///
  /// In es, this message translates to:
  /// **'Video'**
  String get videoLabel;

  /// Label tipo archivo
  ///
  /// In es, this message translates to:
  /// **'Archivo'**
  String get fileLabel;

  /// Placeholder escribir mensaje
  ///
  /// In es, this message translates to:
  /// **'Escribe un mensaje...'**
  String get writeMessage;

  /// Mensaje rápido voy en camino
  ///
  /// In es, this message translates to:
  /// **'Voy en camino'**
  String get onMyWay;

  /// Botón limpiar
  ///
  /// In es, this message translates to:
  /// **'Limpiar'**
  String get clear;

  /// Mensaje rápido no encuentro
  ///
  /// In es, this message translates to:
  /// **'No te encuentro'**
  String get cantFind;

  /// Mensaje rápido tráfico
  ///
  /// In es, this message translates to:
  /// **'Hay tráfico, llegaré tarde'**
  String get trafficDelay;

  /// Error cargar detalles viaje
  ///
  /// In es, this message translates to:
  /// **'Error al cargar detalles del viaje'**
  String get errorLoadingTripDetails;

  /// Botón volver
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get goBack;

  /// Label participantes
  ///
  /// In es, this message translates to:
  /// **'Participantes'**
  String get participantsLabel;

  /// Título ruta del viaje
  ///
  /// In es, this message translates to:
  /// **'Ruta del Viaje'**
  String get tripRouteTitle;

  /// Label calificación
  ///
  /// In es, this message translates to:
  /// **'Calificación'**
  String get ratingLabel;

  /// Título historial del viaje
  ///
  /// In es, this message translates to:
  /// **'Historial del Viaje'**
  String get tripHistoryTitle;

  /// Label solicitud creada
  ///
  /// In es, this message translates to:
  /// **'Solicitud creada'**
  String get requestCreatedLabel;

  /// Label viaje iniciado
  ///
  /// In es, this message translates to:
  /// **'Viaje iniciado'**
  String get tripStartedLabel;

  /// Label viaje completado
  ///
  /// In es, this message translates to:
  /// **'Viaje completado'**
  String get tripCompletedLabel;

  /// Botón ver en Maps
  ///
  /// In es, this message translates to:
  /// **'Ver en Maps'**
  String get viewInMaps;

  /// Botón chat
  ///
  /// In es, this message translates to:
  /// **'Chat'**
  String get chatButton;

  /// Mensaje función próximamente
  ///
  /// In es, this message translates to:
  /// **'Próximamente disponible'**
  String get repeatTripComingSoon;

  /// Error abrir Maps
  ///
  /// In es, this message translates to:
  /// **'No se puede abrir Google Maps'**
  String get cannotOpenMaps;

  /// Estado pendiente
  ///
  /// In es, this message translates to:
  /// **'Pendiente'**
  String get pending;

  /// Mensaje lugar eliminado
  ///
  /// In es, this message translates to:
  /// **'{name} eliminado'**
  String placeRemovedMessage(String name);

  /// Botón deshacer
  ///
  /// In es, this message translates to:
  /// **'Deshacer'**
  String get undo;

  /// Error eliminar favorito
  ///
  /// In es, this message translates to:
  /// **'Error al eliminar favorito'**
  String get errorRemovingFavorite;

  /// Hint buscar lugar
  ///
  /// In es, this message translates to:
  /// **'Buscar lugar...'**
  String get searchPlaceHint;

  /// Label favoritos
  ///
  /// In es, this message translates to:
  /// **'Favoritos'**
  String get favoritesLabel;

  /// Badge principal
  ///
  /// In es, this message translates to:
  /// **'Principal'**
  String get mainLabel;

  /// Contador visitas
  ///
  /// In es, this message translates to:
  /// **'{count} visitas'**
  String visitsCount(int count);

  /// Tiempo hace minutos
  ///
  /// In es, this message translates to:
  /// **'Hace {minutes} min'**
  String minutesAgo(int minutes);

  /// Tiempo hace horas
  ///
  /// In es, this message translates to:
  /// **'Hace {hours} h'**
  String hoursAgo(int hours);

  /// Tiempo hace días
  ///
  /// In es, this message translates to:
  /// **'Hace {days} días'**
  String daysAgoFavorites(int days);

  /// Label nombre del lugar
  ///
  /// In es, this message translates to:
  /// **'Nombre del lugar'**
  String get placeNameLabel;

  /// Label dirección
  ///
  /// In es, this message translates to:
  /// **'Dirección'**
  String get addressLabel;

  /// Hint buscar dirección
  ///
  /// In es, this message translates to:
  /// **'Buscar dirección...'**
  String get searchAddressHint;

  /// Label ícono
  ///
  /// In es, this message translates to:
  /// **'Ícono'**
  String get iconLabel;

  /// Label color
  ///
  /// In es, this message translates to:
  /// **'Color'**
  String get colorLabel;

  /// Título eliminar lugar
  ///
  /// In es, this message translates to:
  /// **'Eliminar {name}'**
  String deletePlace(String name);

  /// Confirmación eliminar lugar
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro de que deseas eliminar este lugar?'**
  String get confirmDeletePlace;

  /// Mensaje mapa vacío
  ///
  /// In es, this message translates to:
  /// **'Agrega lugares favoritos para verlos en el mapa'**
  String get addFavoritesToViewMap;

  /// Título mapa favoritos
  ///
  /// In es, this message translates to:
  /// **'Mapa de Favoritos'**
  String get favoritesMapTitle;

  /// Botón historial
  ///
  /// In es, this message translates to:
  /// **'Historial'**
  String get historyButton;

  /// Label titular tarjeta
  ///
  /// In es, this message translates to:
  /// **'TITULAR'**
  String get cardHolder;

  /// Label vence
  ///
  /// In es, this message translates to:
  /// **'VENCE'**
  String get expiresLabel;

  /// Label saldo
  ///
  /// In es, this message translates to:
  /// **'Saldo: S/. {balance}'**
  String balanceLabel(String balance);

  /// Opción hacer predeterminado
  ///
  /// In es, this message translates to:
  /// **'Hacer predeterminado'**
  String get makeDefault;

  /// Botón eliminar
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get deleteButton;

  /// Título resumen mensual
  ///
  /// In es, this message translates to:
  /// **'Resumen del Mes'**
  String get monthlySummary;

  /// Label transacciones
  ///
  /// In es, this message translates to:
  /// **'Transacciones'**
  String get transactionsLabel;

  /// Label exitosas
  ///
  /// In es, this message translates to:
  /// **'Exitosas'**
  String get successfulLabel;

  /// Label viaje con ID
  ///
  /// In es, this message translates to:
  /// **'Viaje {tripId}'**
  String tripLabel(String tripId);

  /// Estado exitoso
  ///
  /// In es, this message translates to:
  /// **'Exitoso'**
  String get successfulStatus;

  /// Estado fallido
  ///
  /// In es, this message translates to:
  /// **'Fallido'**
  String get failedStatus;

  /// Mensaje pagos protegidos
  ///
  /// In es, this message translates to:
  /// **'Tus pagos están protegidos'**
  String get paymentsProtected;

  /// Mensaje encriptación
  ///
  /// In es, this message translates to:
  /// **'Utilizamos encriptación de grado bancario para proteger tu información.'**
  String get encryptionMessage;

  /// Descripción método efectivo
  ///
  /// In es, this message translates to:
  /// **'Pago al finalizar el viaje'**
  String get cashDescription;

  /// Descripción método billetera
  ///
  /// In es, this message translates to:
  /// **'Pago con saldo de billetera'**
  String get walletDescription;

  /// Descripción método PayPal
  ///
  /// In es, this message translates to:
  /// **'Pago seguro con PayPal'**
  String get paypalDescription;

  /// Descripción método por defecto
  ///
  /// In es, this message translates to:
  /// **'Método de pago'**
  String get paymentMethodDefault;

  /// Fecha hoy
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get todayDate;

  /// Fecha ayer
  ///
  /// In es, this message translates to:
  /// **'Ayer'**
  String get yesterdayDate;

  /// Mensaje método predeterminado
  ///
  /// In es, this message translates to:
  /// **'{name} es ahora tu método predeterminado'**
  String defaultMethodMessage(String name);

  /// Título eliminar método
  ///
  /// In es, this message translates to:
  /// **'Eliminar método de pago'**
  String get deletePaymentMethod;

  /// Confirmación eliminar método
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro de que deseas eliminar {name}?'**
  String confirmDeleteMethod(String name);

  /// Botón cancelar
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancelButton;

  /// Mensaje método eliminado
  ///
  /// In es, this message translates to:
  /// **'Método de pago eliminado'**
  String get methodDeleted;

  /// Título recargar billetera
  ///
  /// In es, this message translates to:
  /// **'Recargar Billetera'**
  String get rechargeWallet;

  /// Mensaje recargando
  ///
  /// In es, this message translates to:
  /// **'Recargando S/. {amount}...'**
  String rechargingAmount(String amount);

  /// Label monto personalizado
  ///
  /// In es, this message translates to:
  /// **'Monto personalizado'**
  String get customAmount;

  /// Mensaje procesando recarga
  ///
  /// In es, this message translates to:
  /// **'Procesando recarga...'**
  String get processingRecharge;

  /// Mensaje cargando historial billetera
  ///
  /// In es, this message translates to:
  /// **'Cargando historial de billetera...'**
  String get loadingWalletHistory;

  /// Título detalles transacción
  ///
  /// In es, this message translates to:
  /// **'Detalles de Transacción'**
  String get transactionDetails;

  /// Label ID transacción
  ///
  /// In es, this message translates to:
  /// **'ID Transacción'**
  String get transactionId;

  /// Label viaje en detalles
  ///
  /// In es, this message translates to:
  /// **'Viaje'**
  String get tripDetailLabel;

  /// Label fecha en detalles
  ///
  /// In es, this message translates to:
  /// **'Fecha'**
  String get dateDetailLabel;

  /// Label método en detalles
  ///
  /// In es, this message translates to:
  /// **'Método'**
  String get methodDetailLabel;

  /// Label monto en detalles
  ///
  /// In es, this message translates to:
  /// **'Monto'**
  String get amountDetailLabel;

  /// Label estado en detalles
  ///
  /// In es, this message translates to:
  /// **'Estado'**
  String get statusDetailLabel;

  /// Mensaje descargando recibo
  ///
  /// In es, this message translates to:
  /// **'Descargando recibo...'**
  String get downloadingReceipt;

  /// Botón descargar
  ///
  /// In es, this message translates to:
  /// **'Descargar'**
  String get downloadButton;

  /// Mensaje abriendo soporte
  ///
  /// In es, this message translates to:
  /// **'Abriendo soporte...'**
  String get openingSupport;

  /// Botón ayuda
  ///
  /// In es, this message translates to:
  /// **'Ayuda'**
  String get helpButton;

  /// Título ayuda
  ///
  /// In es, this message translates to:
  /// **'Ayuda'**
  String get helpTitle;

  /// Item ayuda 1
  ///
  /// In es, this message translates to:
  /// **'• Para establecer un método predeterminado, mantén presionado sobre él.'**
  String get helpItem1;

  /// Item ayuda 2
  ///
  /// In es, this message translates to:
  /// **'• Puedes eliminar métodos de pago deslizando hacia la izquierda.'**
  String get helpItem2;

  /// Item ayuda 3
  ///
  /// In es, this message translates to:
  /// **'• Tu información está encriptada y segura.'**
  String get helpItem3;

  /// Item ayuda 4
  ///
  /// In es, this message translates to:
  /// **'• La billetera Rappi Team te permite pagar sin tarjetas.'**
  String get helpItem4;

  /// Título agregar tarjeta
  ///
  /// In es, this message translates to:
  /// **'Agregar Tarjeta'**
  String get addCard;

  /// Label número de tarjeta
  ///
  /// In es, this message translates to:
  /// **'Número de tarjeta'**
  String get cardNumberLabel;

  /// Validación número tarjeta
  ///
  /// In es, this message translates to:
  /// **'Por favor ingresa el número de tarjeta'**
  String get cardNumberRequired;

  /// Label titular de tarjeta
  ///
  /// In es, this message translates to:
  /// **'Titular de la tarjeta'**
  String get cardHolderLabel;

  /// Validación titular tarjeta
  ///
  /// In es, this message translates to:
  /// **'Por favor ingresa el nombre del titular'**
  String get cardHolderRequired;

  /// Label fecha expiración
  ///
  /// In es, this message translates to:
  /// **'MM/AA'**
  String get expiryLabel;

  /// Validación campo requerido
  ///
  /// In es, this message translates to:
  /// **'Requerido'**
  String get requiredField;

  /// Label CVV
  ///
  /// In es, this message translates to:
  /// **'CVV'**
  String get cvvLabel;

  /// Mensaje datos seguros
  ///
  /// In es, this message translates to:
  /// **'Tus datos están seguros y encriptados'**
  String get dataSecureMessage;

  /// Mensaje tarjeta agregada
  ///
  /// In es, this message translates to:
  /// **'Tarjeta agregada exitosamente'**
  String get cardAddedSuccess;

  /// Título correo enviado
  ///
  /// In es, this message translates to:
  /// **'Correo enviado'**
  String get emailSent;

  /// Instrucciones revisar bandeja
  ///
  /// In es, this message translates to:
  /// **'Revisa tu bandeja de entrada y sigue las instrucciones para recuperar tu contraseña.'**
  String get checkInboxInstructions;

  /// Pregunta olvidaste contraseña
  ///
  /// In es, this message translates to:
  /// **'¿Olvidaste tu contraseña?'**
  String get forgotPasswordQuestion;

  /// Instrucciones ingresar email para recuperar
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.'**
  String get enterEmailInstructions;

  /// Botón enviar enlace de recuperación
  ///
  /// In es, this message translates to:
  /// **'Enviar enlace de recuperación'**
  String get sendRecoveryLink;

  /// Título email ya registrado
  ///
  /// In es, this message translates to:
  /// **'Email ya registrado'**
  String get emailAlreadyRegistered;

  /// Mensaje email ya registrado
  ///
  /// In es, this message translates to:
  /// **'El email {email} ya está registrado como {userType}.\n\n¿Deseas iniciar sesión en su lugar?'**
  String emailAlreadyRegisteredMessage(String email, String userType);

  /// Botón ir a login
  ///
  /// In es, this message translates to:
  /// **'Ir a Login'**
  String get goToLoginButton;

  /// Título teléfono ya registrado
  ///
  /// In es, this message translates to:
  /// **'Teléfono ya registrado'**
  String get phoneAlreadyRegistered;

  /// Mensaje teléfono ya registrado
  ///
  /// In es, this message translates to:
  /// **'El teléfono {phone} ya está registrado con el email:\n\n{email}\n\nTipo de cuenta: {userType}\n\n¿Deseas iniciar sesión?'**
  String phoneAlreadyRegisteredMessage(
      String phone, String email, String userType);

  /// Mensaje debug botón presionado
  ///
  /// In es, this message translates to:
  /// **'✅ BOTÓN PRESIONADO!'**
  String get buttonPressed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
