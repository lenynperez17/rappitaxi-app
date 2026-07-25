import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/rapi_api_client.dart';
import '../../widgets/common/rappi_app_bar.dart';
import '../../screens/shared/settings_screen.dart';
import '../../screens/shared/about_screen.dart';
import '../../utils/logger.dart';

/// Drawer for the passenger home screen (inDrive style).
/// Handles navigation, driver mode switch, logout, etc.
class PassengerDrawer extends StatelessWidget {
  /// Called when user selects a favorite destination from the drawer.
  final void Function(String address, double lat, double lng)? onFavoriteSelected;

  const PassengerDrawer({super.key, this.onFavoriteSelected});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userName = authProvider.currentUser?.fullName.split(' ').first ?? 'Pasajero';

    return Drawer(
      child: Container(
        color: AppColors.getSurface(context),
        child: Column(
          children: [
            RappiTeamDrawerHeader(
              userType: 'passenger',
              userName: userName,
              onProfileTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/passenger/profile');
              },
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _DrawerItem(
                    icon: Icons.history_rounded,
                    title: 'Historial de viajes',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/passenger/trip-history');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.favorite_rounded,
                    title: 'Lugares favoritos',
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await Navigator.pushNamed(context, '/passenger/favorites');
                      if (result != null && context.mounted) {
                        if (result is Map<String, dynamic>) {
                          final address = result['address'] as String?;
                          final lat = result['latitude'] as double?;
                          final lng = result['longitude'] as double?;
                          if (address != null && lat != null && lng != null) {
                            onFavoriteSelected?.call(address, lat, lng);
                          }
                        }
                      }
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.share_rounded,
                    title: 'Compartir App',
                    onTap: () {
                      Navigator.pop(context);
                      _shareApp();
                    },
                  ),
                  const Divider(),
                  _DrawerItem(
                    icon: Icons.support_agent_rounded,
                    title: 'Soporte',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => AboutScreen()));
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.settings_rounded,
                    title: 'Configuración',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen()));
                    },
                  ),
                  const Divider(),
                  _DrawerItem(
                    icon: Icons.logout_rounded,
                    title: 'Cerrar sesión',
                    color: AppColors.error,
                    onTap: () async {
                      // capture-before-pop: capturamos las referencias ANTES
                      // del pop porque el context del drawer se desmonta y
                      // los pushNamedAndRemoveUntil posteriores fallarían
                      // silenciosamente con context "deactivated".
                      final rootNav = Navigator.of(context, rootNavigator: true);
                      final auth = Provider.of<AuthProvider>(context, listen: false);
                      Navigator.pop(context); // cierra drawer
                      await auth.logout();
                      rootNav.pushNamedAndRemoveUntil('/login', (route) => false);
                    },
                  ),
                ],
              ),
            ),
            const _DriverModeButton(),
          ],
        ),
      ),
    );
  }

  void _shareApp() {
    Share.share(
      '¡Descarga Rappi Team y viaja seguro!\n\n'
      'La mejor app de transporte de tu ciudad.\n\n'
      'Android: https://play.google.com/store/apps/details?id=com.rapiteam.app\n'
      'iOS: https://apps.apple.com/app/rapiteam',
      subject: 'Rappi Team - Tu app de transporte',
    );
    AppLogger.info('Usuario compartió la app');
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  const _DrawerItem({required this.icon, required this.title, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.rappiOrange),
      title: Text(title, style: TextStyle(color: color ?? AppColors.getTextPrimary(context))),
      onTap: onTap,
    );
  }
}

/// Button at the bottom of the drawer to switch to driver mode.
class _DriverModeButton extends StatelessWidget {
  const _DriverModeButton();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.currentUser;
        // Ronda 228: fallback por userType — ver comentario en modern_passenger_home.
        final hasDriverRole = user?.userType == 'dual' ||
            user?.userType == 'driver' ||
            (user?.availableRoles?.contains('driver') ?? false);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Material(
            color: AppColors.rappiOrange,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _handleDriverModeTap(context, authProvider, hasDriverRole),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.local_taxi_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Modo Conductor',
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          Text(
                            hasDriverRole ? 'Cambiar a conductor' : 'Empieza a ganar dinero',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleDriverModeTap(BuildContext context, AuthProvider authProvider, bool hasDriverRole) async {
    // Ronda 225 (141) BUG: antes hacíamos Navigator.pop(context) para cerrar
    // el drawer y luego usábamos ese MISMO context para mostrar el dialog
    // "Verificando..." → context desmontado → el dialog quedaba huérfano y
    // el Navigator.pop posterior no lo cerraba → spinner infinito.
    // Fix: capturamos rootNavigator y messenger ANTES de cerrar el drawer,
    // y añadimos timeout defensivo por si la request al backend cuelga.
    final rootNav = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context); // cierra el drawer

    if (hasDriverRole) {
      final success = await authProvider.switchMode('driver');
      if (success) {
        rootNav.pushNamedAndRemoveUntil('/driver/home', (route) => false);
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(authProvider.errorMessage ?? 'Error al cambiar modo'), backgroundColor: AppColors.error),
        );
      }
      return;
    }

    final userId = authProvider.currentUser?.id;
    if (userId == null) {
      rootNav.pushNamed('/driver/register');
      return;
    }

    // Mostrar dialog usando rootNav.context (sigue montado aunque el drawer cerró).
    showDialog<void>(
      context: rootNav.context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.getSurface(ctx),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(color: AppColors.rappiOrange),
                SizedBox(height: 16),
                Text('Verificando...', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );

    Map<String, dynamic>? pendingApplication;
    try {
      pendingApplication = await _checkPendingDriverApplication(userId).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          AppLogger.warning('_checkPendingDriverApplication TIMEOUT tras 15s');
          return null;
        },
      );
    } catch (e) {
      AppLogger.error('_checkPendingDriverApplication error: $e');
      pendingApplication = null;
    }

    // Cerrar SIEMPRE el loading dialog vía rootNav (no context desmontado).
    if (rootNav.canPop()) rootNav.pop();

    if (pendingApplication != null) {
      rootNav.pushNamed('/driver/register/pending', arguments: pendingApplication);
    } else {
      rootNav.pushNamed('/driver/register');
    }
  }

  Future<Map<String, dynamic>?> _checkPendingDriverApplication(String userId) async {
    // Ronda 224 (build 138) BUG CRÍTICO: este método antes era un stub que
    // SIEMPRE devolvía null → cada vez que un aplicante abría el drawer y
    // tocaba "Convertirme en conductor" era mandado al wizard desde cero,
    // aunque ya tuviera 9 documentos subidos y estuviera esperando revisión.
    // La versión buena vive en modern_passenger_home; se duplica acá para
    // que el drawer también reconozca la solicitud pendiente.
    try {
      AppLogger.info('Verificando solicitud de conductor pendiente (drawer) para $userId');
      final api = RapiApiClient.instance;

      // Fast path: profile con status pending/under_review.
      try {
        final profile = await api.myDriverProfile();
        final data = (profile['driver'] as Map?) ??
            (profile['profile'] as Map?) ??
            profile;
        final status = (data['status'] ?? data['verificationStatus'])?.toString();
        if (status == 'pending' || status == 'under_review') {
          return Map<String, dynamic>.from(data);
        }
      } catch (_) {
        // /profile devuelve 403 para passenger — esperado, seguimos al fallback.
      }

      // Fallback: existen documentos subidos (aplicante activo aunque siga passenger).
      try {
        final docsResp = await api.myDocuments();
        final docs = docsResp['documents'] as List? ?? const [];
        if (docs.isNotEmpty) {
          final hasPending = docs.any((d) {
            if (d is! Map) return false;
            final st = d['status']?.toString();
            return st == 'pending' || st == 'approved' || st == 'rejected';
          });
          if (hasPending) {
            return {
              'status': 'pending',
              'workType': _inferWorkType(docs),
              'documents': docs,
            };
          }
        }
      } catch (_) {
        // Sin docs — usuario nuevo, iniciar wizard normal.
      }
      return null;
    } catch (e) {
      AppLogger.info('checkPendingDriverApplication drawer error: $e');
      return null;
    }
  }

  String _inferWorkType(List<dynamic> docs) {
    for (final d in docs) {
      if (d is Map) {
        final scope = d['scope']?.toString() ?? d['docType']?.toString() ?? '';
        if (scope.contains('moto')) return 'moto';
        if (scope.contains('courier')) return 'courier';
      }
    }
    return 'auto';
  }
}
