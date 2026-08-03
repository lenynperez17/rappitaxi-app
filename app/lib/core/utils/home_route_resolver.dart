import '../../models/user_model.dart';

/// Ronda 269: única fuente de verdad para decidir a qué pantalla va un usuario.
///
/// POR QUÉ EXISTE
/// --------------
/// Esta decisión estaba escrita TRES veces, y las tres no coincidían:
///
///   - `modern_splash_screen.dart:274` usaba `activeMode` (currentMode ?? userType)
///   - `rapi_otp_screen.dart:60`       usaba `userType` a secas
///   - `rapi_login_screen.dart:202`    usaba `userType` a secas
///
/// Con una cuenta `dual` cuyo `current_mode` es `'driver'` —caso real,
/// verificado en producción— abrir la app en frío llevaba al home de CONDUCTOR
/// y entrar por SMS llevaba al de PASAJERO. El mismo usuario, dos destinos
/// distintos según por dónde entrara. Ése es el "a veces me lleva a pantallas
/// que no tienen nada que ver" que reportaban los usuarios.
///
/// Con las tres pantallas llamando aquí, la incoherencia no puede volver:
/// para cambiar el enrutado hay que cambiar esta función, y cambia en todas.
///
/// SIN EFECTOS SECUNDARIOS
/// -----------------------
/// Esta función solo lee y devuelve una ruta. No llama al backend ni muta el
/// modo del usuario. El splash lo hacía —`await switchMode('passenger')` en
/// mitad del arranque, sin timeout— y podía bloquear el inicio hasta 25 s
/// contra una red lenta. Sincronizar el modo es responsabilidad de quien lo
/// cambia, no de quien decide a dónde navegar.
class HomeRouteResolver {
  const HomeRouteResolver._();

  static const String login = '/login';
  static const String completeProfile = '/auth/complete-profile';
  static const String adminDashboard = '/admin/dashboard';
  static const String driverHome = '/driver/home';
  static const String passengerHome = '/passenger/home';
  static const String upgradeToDriver = '/upgrade-to-driver';

  /// Ruta destino para [user]. `null` significa "no hay sesión" → [login].
  ///
  /// [needsProfileCompletion] lo decide `AuthProvider`, que es quien conoce
  /// los datos obligatorios que falten.
  static String resolve(UserModel? user, {bool needsProfileCompletion = false}) {
    if (user == null) return login;
    if (needsProfileCompletion) return completeProfile;
    if (user.isAdmin) return adminDashboard;

    // `activeMode` (currentMode ?? userType) y no `userType`: un usuario dual
    // que quedó en modo conductor debe volver al home de conductor, aunque su
    // tipo de cuenta admita ambos.
    if (user.activeMode != 'driver') return passengerHome;

    // Modo conductor. El alta debe estar aprobada: si no, el conductor entraría
    // a una pantalla desde la que no puede aceptar viajes.
    final isApproved =
        user.isVerified && (user.userType == 'driver' || user.userType == 'dual');
    if (isApproved) return driverHome;

    // Sin aprobar. Desde la ronda 269 el backend sí envía `driverStatus`
    // (derivado en `api/src/app/api/auth/me/route.ts`); antes era siempre null
    // y TODOS caían en el alta de conductor, incluso quienes ya habían subido
    // sus documentos y solo estaban esperando revisión.
    if (user.driverStatus == 'pending_approval') return passengerHome;
    return upgradeToDriver;
  }

  /// Variante para cuando solo se tiene el JSON crudo del login y no un
  /// [UserModel] — por ejemplo si el refresco del perfil falló por falta de red.
  ///
  /// Aplica exactamente el mismo criterio que [resolve]; existe para que ese
  /// camino degradado no acabe reimplementando la decisión por su cuenta, que
  /// es justo como aparecieron las tres versiones divergentes.
  static String resolveFromJson(Map<String, dynamic>? userJson) {
    if (userJson == null) return login;
    final userType = (userJson['userType'] as String?) ?? 'passenger';
    final currentMode = userJson['currentMode'] as String?;
    final isVerified = userJson['isVerified'] == true;
    final driverStatus = userJson['driverStatus'] as String?;

    if (userType == 'admin') return adminDashboard;
    if ((currentMode ?? userType) != 'driver') return passengerHome;
    if (isVerified && (userType == 'driver' || userType == 'dual')) return driverHome;
    if (driverStatus == 'pending_approval') return passengerHome;
    return upgradeToDriver;
  }

  /// `true` si el modo guardado en el usuario contradice la pantalla a la que
  /// se le va a enviar, y por tanto conviene sincronizarlo con el servidor.
  ///
  /// Se expone aparte justamente para que la sincronización ocurra FUERA de la
  /// ruta de arranque: quien navega decide si esperar a que termine o dejarla
  /// en segundo plano, pero el splash ya no se queda colgado por ella.
  static bool needsModeSync(UserModel? user) {
    if (user == null) return false;
    if (user.currentMode != 'driver') return false;
    final isApproved =
        user.isVerified && (user.userType == 'driver' || user.userType == 'dual');
    return !isApproved;
  }
}
