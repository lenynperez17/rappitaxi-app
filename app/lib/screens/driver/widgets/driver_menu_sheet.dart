import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/design_system.dart';
import '../../../core/widgets/rt_list_tile.dart';
import '../../../providers/auth_provider.dart';
import '../wallet_screen.dart';
import '../../shared/settings_screen.dart';
import '../../shared/help_center_screen.dart';
import '../../shared/about_screen.dart';

/// Bottom sheet con menú de opciones del conductor
class DriverMenuSheet extends StatelessWidget {
  final VoidCallback onLogout;

  const DriverMenuSheet({
    super.key,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Container(
      padding: const EdgeInsets.all(RtSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: RtRadius.sheetTop,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: RtSpacing.base),
            decoration: BoxDecoration(
              color: RtColors.neutral300,
              borderRadius: RtRadius.borderFull,
            ),
          ),
          RtListTile(
            title: 'Mi Perfil',
            leadingIcon: Icons.person,
            leadingIconColor: RtColors.brand,
            showChevron: true,
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/driver/profile');
            },
          ),
          RtListTile(
            title: 'Métricas',
            leadingIcon: Icons.analytics,
            leadingIconColor: RtColors.info,
            showChevron: true,
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/driver/metrics');
            },
          ),
          RtListTile(
            title: 'Historial',
            leadingIcon: Icons.history,
            leadingIconColor: RtColors.success,
            showChevron: true,
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/driver/transactions-history');
            },
          ),
          RtListTile(
            title: 'Billetera',
            leadingIcon: Icons.account_balance_wallet,
            leadingIconColor: RtColors.accentAmber,
            showChevron: true,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WalletScreen()),
              );
            },
          ),
          const SizedBox(height: RtSpacing.sm),
          const Divider(),
          const SizedBox(height: RtSpacing.sm),
          RtListTile(
            title: 'Configuración',
            leadingIcon: Icons.settings,
            leadingIconColor: RtColors.neutral500,
            showChevron: true,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          RtListTile(
            title: 'Ayuda',
            leadingIcon: Icons.help_outline,
            leadingIconColor: RtColors.info,
            showChevron: true,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpCenterScreen()),
              );
            },
          ),
          RtListTile(
            title: 'Acerca de',
            leadingIcon: Icons.info_outline,
            leadingIconColor: RtColors.neutral400,
            showChevron: true,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              );
            },
          ),
          const SizedBox(height: RtSpacing.sm),
          const Divider(),
          const SizedBox(height: RtSpacing.sm),
          RtListTile(
            title: 'Cambiar a Pasajero',
            leadingIcon: Icons.swap_horiz,
            leadingIconColor: RtColors.brand,
            onTap: () async {
              Navigator.pop(context);
              final success = await authProvider.switchMode('passenger');
              if (success && context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/passenger/home',
                  (r) => false,
                );
              }
            },
          ),
          if (authProvider.currentUser?.availableRoles?.contains('admin') == true)
            RtListTile(
              title: 'Cambiar a Admin',
              leadingIcon: Icons.admin_panel_settings_rounded,
              leadingIconColor: const Color(0xFFEF4444),
              onTap: () async {
                Navigator.pop(context);
                final success = await authProvider.switchMode('admin');
                if (success && context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/admin/dashboard',
                    (r) => false,
                  );
                }
              },
            ),
          RtListTile(
            title: 'Cerrar Sesión',
            leadingIcon: Icons.logout,
            leadingIconColor: RtColors.error,
            onTap: () {
              Navigator.pop(context);
              onLogout();
            },
          ),
          const SizedBox(height: RtSpacing.sm),
        ],
      ),
    );
  }

  /// Muestra el sheet como modal bottom sheet scrollable
  static void show(BuildContext context, {required VoidCallback onLogout}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: RtRadius.sheetTop),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      builder: (_) => SingleChildScrollView(
        child: DriverMenuSheet(onLogout: onLogout),
      ),
    );
  }
}
