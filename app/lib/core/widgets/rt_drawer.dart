import 'package:flutter/material.dart';

import '../design/rt_colors.dart';
import '../design/rt_gradients.dart';
import '../design/rt_tokens.dart';
import '../design/rt_typography.dart';
import 'rt_avatar.dart';

/// Modelo de datos para cada item del menu del drawer
class RtDrawerMenuItem {
  final IconData icon;
  final String label;
  final String? route;
  final String? badge;
  final VoidCallback? onTap;

  const RtDrawerMenuItem({
    required this.icon,
    required this.label,
    this.route,
    this.badge,
    this.onTap,
  });
}

/// Drawer lateral reutilizable del design system RapiTeam.
/// Incluye header con gradiente, avatar, información de usuario,
/// lista de items del menu, boton de logout y version opcional.
class RtDrawer extends StatelessWidget {
  final String userName;
  final String userEmail;
  final String? userPhotoUrl;
  final double? userRating;
  final int? totalTrips;
  final String userType;
  final List<RtDrawerMenuItem> menuItems;
  final VoidCallback onLogout;
  final String? footerVersion;

  const RtDrawer({
    super.key,
    required this.userName,
    required this.userEmail,
    this.userPhotoUrl,
    this.userRating,
    this.totalTrips,
    required this.userType,
    required this.menuItems,
    required this.onLogout,
    this.footerVersion,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(child: _buildMenuList(context)),
            _buildLogoutButton(context),
            if (footerVersion != null) _buildVersionFooter(context),
          ],
        ),
      ),
    );
  }

  /// Header con gradiente brand, avatar, nombre, email y rating
  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + RtSpacing.lg,
        bottom: RtSpacing.lg,
        left: RtSpacing.xl,
        right: RtSpacing.xl,
      ),
      decoration: const BoxDecoration(gradient: RtGradients.brand),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RtAvatar(
            imageUrl: userPhotoUrl,
            name: userName,
            size: RtAvatarSize.xlarge,
          ),
          const SizedBox(height: RtSpacing.base),
          Text(
            userName,
            style: RtTypo.headingLarge.copyWith(color: RtColors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: RtSpacing.xs),
          Text(
            userEmail,
            style: RtTypo.bodySmall.copyWith(
              color: RtColors.white.withValues(alpha: 0.9),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (userRating != null || totalTrips != null) ...[
            const SizedBox(height: RtSpacing.sm),
            _buildRatingBadge(),
          ],
        ],
      ),
    );
  }

  /// Badge con rating y total de viajes sobre fondo semi-transparente
  Widget _buildRatingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: RtColors.white.withValues(alpha: 0.2),
        borderRadius: RtRadius.borderFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (userRating != null) ...[
            const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
            const SizedBox(width: 4),
            Text(
              userRating!.toStringAsFixed(1),
              style: RtTypo.labelLarge.copyWith(
                color: RtColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (userRating != null && totalTrips != null)
            Text(
              ' \u2022 ',
              style: RtTypo.bodySmall.copyWith(
                color: RtColors.white.withValues(alpha: 0.9),
              ),
            ),
          if (totalTrips != null)
            Text(
              '$totalTrips viajes',
              style: RtTypo.bodySmall.copyWith(
                color: RtColors.white.withValues(alpha: 0.9),
              ),
            ),
        ],
      ),
    );
  }

  /// Lista de items del menu con icono, label, badge opcional y chevron
  Widget _buildMenuList(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: menuItems.length,
      itemBuilder: (context, index) {
        return _buildMenuItem(context, menuItems[index]);
      },
    );
  }

  /// Item individual del menu
  Widget _buildMenuItem(BuildContext context, RtDrawerMenuItem item) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Icon(item.icon, color: RtColors.brand, size: RtIconSize.md),
      title: Text(
        item.label,
        style: RtTypo.titleLarge,
      ),
      trailing: item.badge != null
          ? _buildItemBadge(item.badge!)
          : Icon(
              Icons.chevron_right_rounded,
              color: isDark ? RtColors.neutral500 : RtColors.neutral400,
            ),
      onTap: () {
        Navigator.pop(context);
        if (item.onTap != null) {
          item.onTap!();
        } else if (item.route != null) {
          Navigator.pushNamed(context, item.route!);
        }
      },
    );
  }

  /// Badge numerico o texto dentro de un item del menu
  Widget _buildItemBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: RtColors.brand,
        borderRadius: RtRadius.borderFull,
      ),
      child: Text(
        text,
        style: RtTypo.labelSmall.copyWith(
          color: RtColors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// Boton de cerrar sesión en la parte inferior
  Widget _buildLogoutButton(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? RtColors.neutral700 : RtColors.neutral200,
          ),
        ),
      ),
      child: ListTile(
        leading: const Icon(Icons.logout_rounded, color: RtColors.error),
        title: Text(
          'Cerrar sesión',
          style: RtTypo.titleLarge.copyWith(
            color: RtColors.error,
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: onLogout,
      ),
    );
  }

  /// Version de la app en el footer
  Widget _buildVersionFooter(BuildContext context) {
    return Padding(
      padding: RtSpacing.paddingBase,
      child: Text(
        footerVersion!,
        style: RtTypo.bodySmall.copyWith(color: RtColors.neutral400),
        textAlign: TextAlign.center,
      ),
    );
  }
}
