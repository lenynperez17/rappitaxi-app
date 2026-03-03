import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/design_system.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../../shared/settings_screen.dart';
import '../../shared/help_center_screen.dart';

/// Drawer del menu lateral del pasajero.
/// Muestra datos reales del usuario desde AuthProvider (nombre, email, foto).
/// Contiene navegación a historial, perfil, ajustes, wallet, etc.
class PassengerDrawer extends StatelessWidget {
  final VoidCallback onLogout;

  const PassengerDrawer({
    super.key,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Obtener datos reales del usuario desde AuthProvider
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    final userName = user?.fullName ?? 'Usuario';
    final userEmail = user?.email ?? '';
    final userPhoto = user?.profilePhotoUrl ?? '';

    return Drawer(
      child: Container(
        color: isDark ? RtColors.neutral900 : RtColors.white,
        child: Column(
          children: [
            // Header del drawer con gradiente brand
            _buildHeader(
              context,
              isDark,
              userName,
              userEmail,
              userPhoto,
            ),

            // Menu items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildMenuItem(
                    context,
                    isDark,
                    Icons.history_rounded,
                    l10n.tripHistory,
                    () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/passenger/trip-history');
                    },
                  ),
                  _buildMenuItem(
                    context,
                    isDark,
                    Icons.star_rounded,
                    l10n.ratings,
                    () {
                      Navigator.pop(context);
                      Navigator.pushNamed(
                          context, '/passenger/ratings-history');
                    },
                  ),
                  _buildMenuItem(
                    context,
                    isDark,
                    Icons.favorite_rounded,
                    l10n.favoritePlaces,
                    () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/passenger/favorites');
                    },
                  ),
                  _buildMenuItem(
                    context,
                    isDark,
                    Icons.local_offer_rounded,
                    l10n.promotions,
                    () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/passenger/promotions');
                    },
                  ),
                  // Separador sutil
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: RtSpacing.lg,
                    ),
                    child: Divider(
                      color: isDark
                          ? RtColors.neutral800
                          : RtColors.neutral200,
                      height: 1,
                    ),
                  ),
                  _buildMenuItem(
                    context,
                    isDark,
                    Icons.person_rounded,
                    l10n.profile,
                    () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/passenger/profile');
                    },
                  ),
                  _buildMenuItem(
                    context,
                    isDark,
                    Icons.settings_rounded,
                    l10n.settings,
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildMenuItem(
                    context,
                    isDark,
                    Icons.help_outline_rounded,
                    l10n.helpCenter,
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HelpCenterScreen(),
                        ),
                      );
                    },
                  ),
                  // Separador sutil
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: RtSpacing.lg,
                    ),
                    child: Divider(
                      color: isDark
                          ? RtColors.neutral800
                          : RtColors.neutral200,
                      height: 1,
                    ),
                  ),
                  // Cambiar a conductor (solo si tiene el rol disponible)
                  if (_canSwitchToDriver(authProvider))
                    _buildMenuItem(
                      context,
                      isDark,
                      Icons.swap_horiz_rounded,
                      'Cambiar a Conductor',
                      () async {
                        Navigator.pop(context);
                        await authProvider.switchMode('driver');
                        if (context.mounted) {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/driver/home',
                            (r) => false,
                          );
                        }
                      },
                    ),
                  // Cambiar a admin (solo si tiene el rol disponible)
                  if (_canSwitchToAdmin(authProvider))
                    _buildMenuItem(
                      context,
                      isDark,
                      Icons.admin_panel_settings_rounded,
                      'Cambiar a Admin',
                      () async {
                        Navigator.pop(context);
                        await authProvider.switchMode('admin');
                        if (context.mounted) {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/admin/dashboard',
                            (r) => false,
                          );
                        }
                      },
                    ),
                  _buildMenuItem(
                    context,
                    isDark,
                    Icons.logout_rounded,
                    l10n.logout,
                    () {
                      Navigator.pop(context);
                      onLogout();
                    },
                    color: RtColors.error,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Header con gradiente brand, logo, avatar, nombre, email y badge de tipo
  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    String userName,
    String userEmail,
    String userPhoto,
  ) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RtGradients.brand,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            RtSpacing.lg,
            RtSpacing.base,
            RtSpacing.lg,
            RtSpacing.xl,
          ),
          child: Column(
            children: [
              // Fila superior: Logo RapiTeam pequeno
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: RtColors.white.withValues(alpha: 0.15),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Image.asset(
                      'assets/images/logo_rapiteam.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.local_taxi,
                          color: RtColors.white,
                          size: 22,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: RtSpacing.sm),
                  Text(
                    'RAPITEAM',
                    style: RtTypo.labelLarge.copyWith(
                      color: RtColors.white,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: RtSpacing.lg),

              // Avatar circular grande con Hero
              Hero(
                tag: 'user-avatar',
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: RtColors.white.withValues(alpha: 0.3),
                        width: 3,
                      ),
                    ),
                    child: ClipOval(
                      child: _buildAvatarContent(userName, userPhoto),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: RtSpacing.md),

              // Nombre real del usuario
              Text(
                userName,
                style: RtTypo.headingSmall.copyWith(
                  color: RtColors.white,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),

              // Email del usuario
              if (userEmail.isNotEmpty)
                Text(
                  userEmail,
                  style: RtTypo.bodySmall.copyWith(
                    color: RtColors.white.withValues(alpha: 0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: RtSpacing.sm),

              // Badge de tipo de usuario
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: RtSpacing.md,
                  vertical: RtSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: RtColors.white.withValues(alpha: 0.2),
                  borderRadius: RtRadius.borderFull,
                ),
                child: Text(
                  'Pasajero',
                  style: RtTypo.labelSmall.copyWith(
                    color: RtColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construye el contenido del avatar: imagen de red o iniciales
  Widget _buildAvatarContent(String userName, String userPhoto) {
    if (userPhoto.isNotEmpty) {
      return Image.network(
        userPhoto,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildInitialsAvatar(userName);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 72,
            height: 72,
            color: RtColors.white.withValues(alpha: 0.2),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: RtColors.white,
                ),
              ),
            ),
          );
        },
      );
    }

    return _buildInitialsAvatar(userName);
  }

  /// Avatar con iniciales del nombre sobre fondo semi-transparente
  Widget _buildInitialsAvatar(String userName) {
    final initials = _extractInitials(userName);

    return Container(
      width: 72,
      height: 72,
      color: RtColors.white.withValues(alpha: 0.2),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: RtTypo.headingLarge.copyWith(
          color: RtColors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// Extrae las primeras 2 iniciales del nombre
  String _extractInitials(String fullName) {
    final parts =
        fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  /// Verifica si el usuario tiene el rol de conductor disponible
  bool _canSwitchToDriver(AuthProvider authProvider) {
    final user = authProvider.currentUser;
    if (user == null) return false;
    final roles = user.availableRoles;
    if (roles != null && roles.contains('driver')) return true;
    if (user.userType == 'both') return true;
    return false;
  }

  bool _canSwitchToAdmin(AuthProvider authProvider) {
    final user = authProvider.currentUser;
    if (user == null) return false;
    final roles = user.availableRoles;
    return roles != null && roles.contains('admin');
  }

  /// Item de menu con icono en circulo de fondo suave
  Widget _buildMenuItem(
    BuildContext context,
    bool isDark,
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color? color,
  }) {
    final itemColor = color ?? RtColors.brand;
    final textColor =
        color ?? (isDark ? RtColors.white : RtColors.neutral900);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RtSpacing.base,
          vertical: RtSpacing.md,
        ),
        child: Row(
          children: [
            // Icono dentro de circulo con fondo suave
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: itemColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: RtIconSize.sm,
                color: itemColor,
              ),
            ),
            const SizedBox(width: RtSpacing.md),
            // Titulo del item
            Expanded(
              child: Text(
                title,
                style: RtTypo.bodyMedium.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Flecha de navegación (no para logout)
            if (color == null)
              Icon(
                Icons.chevron_right_rounded,
                size: RtIconSize.sm,
                color: isDark ? RtColors.neutral600 : RtColors.neutral300,
              ),
          ],
        ),
      ),
    );
  }
}
