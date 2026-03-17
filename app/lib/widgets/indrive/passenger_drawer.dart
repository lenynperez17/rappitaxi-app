import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/rappi_app_bar.dart';
import '../../screens/shared/settings_screen.dart';
import '../../screens/shared/about_screen.dart';
import '../../utils/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Drawer for the passenger home screen (inDrive style).
/// Handles navigation, driver mode switch, logout, etc.
class PassengerDrawer extends StatelessWidget {
  /// Called when user selects a favorite destination from the drawer.
  final void Function(String address, double lat, double lng)? onFavoriteSelected;

  const PassengerDrawer({super.key, this.onFavoriteSelected});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authProvider = context.watch<AuthProvider>();
    final userName = authProvider.currentUser?.fullName ?? 'Pasajero';

    return Drawer(
      child: Container(
        color: AppColors.getSurface(context),
        child: Column(
          children: [
            RappiTeamDrawerHeader(
              userType: 'passenger',
              userName: userName,
              onProfileTap: () {
                Navigator.pop(context); // Close drawer first
                Navigator.pushNamed(context, '/passenger/profile');
              },
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _DrawerItem(
                    icon: Icons.history_rounded,
                    title: l10n.tripHistory,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/passenger/trip-history');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.favorite_rounded,
                    title: l10n.favoritePlaces,
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
                    title: l10n.settings,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen()));
                    },
                  ),
                  const Divider(),
                  _DrawerItem(
                    icon: Icons.logout_rounded,
                    title: l10n.logout,
                    color: AppColors.error,
                    onTap: () async {
                      Navigator.pop(context);
                      final auth = Provider.of<AuthProvider>(context, listen: false);
                      await auth.logout();
                      if (!context.mounted) return;
                      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
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
    AppLogger.info('Usuario compartio la app');
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
        final hasDriverRole = user?.availableRoles?.contains('driver') ?? false;

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
    Navigator.pop(context);
    if (hasDriverRole) {
      final success = await authProvider.switchMode('driver');
      if (!context.mounted) return;
      if (success) {
        Navigator.pushNamedAndRemoveUntil(context, '/driver/home', (route) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authProvider.errorMessage ?? 'Error al cambiar modo'), backgroundColor: AppColors.error),
        );
      }
    } else {
      final userId = authProvider.currentUser?.id;
      if (userId != null) {
        _showLoadingDialog(context, 'Verificando...');
        final pendingApplication = await _checkPendingDriverApplication(userId);
        if (context.mounted) Navigator.pop(context);
        if (!context.mounted) return;
        if (pendingApplication != null) {
          Navigator.pushNamed(context, '/driver/register/pending', arguments: pendingApplication);
        } else {
          Navigator.pushNamed(context, '/driver/register');
        }
      } else {
        Navigator.pushNamed(context, '/driver/register');
      }
    }
  }

  void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
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
              children: [
                const CircularProgressIndicator(color: AppColors.rappiOrange),
                const SizedBox(height: 16),
                Text(message, style: TextStyle(color: AppColors.getTextPrimary(ctx), fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _checkPendingDriverApplication(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('driver_applications')
          .where('userId', isEqualTo: userId)
          .where('status', whereIn: ['pending', 'under_review'])
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) return snapshot.docs.first.data();
      return null;
    } catch (e) {
      AppLogger.error('Error verificando solicitud pendiente: $e');
      return null;
    }
  }
}
