import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../shared/providers/riverpod_compat.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class DrawerMenu extends ConsumerWidget {
  const DrawerMenu({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Header del drawer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Text(
                      currentUser?.name.substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentUser?.name ?? 'Usuario',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentUser?.email ?? '',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Opciones del menú
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildMenuItem(
                    context,
                    icon: Icons.history,
                    title: 'Historial de viajes',
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/history');
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.payment,
                    title: 'Métodos de pago',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/profile/payment-methods');
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.star_outline,
                    title: 'Mis favoritos',
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Navegar a favoritos
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.local_offer_outlined,
                    title: 'Promociones',
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Navegar a promociones
                    },
                  ),
                  const Divider(),
                  _buildMenuItem(
                    context,
                    icon: Icons.help_outline,
                    title: 'Ayuda y soporte',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/profile/support');
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.info_outline,
                    title: 'Acerca de',
                    onTap: () {
                      Navigator.pop(context);
                      _showAboutDialog(context);
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.settings_outlined,
                    title: 'Configuración',
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Navegar a configuración
                    },
                  ),
                  const Divider(),
                  _buildMenuItem(
                    context,
                    icon: Icons.logout,
                    title: 'Cerrar sesión',
                    textColor: AppTheme.errorColor,
                    iconColor: AppTheme.errorColor,
                    onTap: () async {
                      Navigator.pop(context);
                      await _showLogoutDialog(context, ref);
                    },
                  ),
                ],
              ),
            ),
            
            // Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Versión 1.0.0',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? AppTheme.textSecondaryColor,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? AppTheme.textColor,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
      horizontalTitleGap: 0,
    );
  }
  
  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rappi Taxi'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Versión: 1.0.0'),
            SizedBox(height: 8),
            Text('Tu viaje seguro y confiable'),
            SizedBox(height: 16),
            Text('© 2025 Rappi Taxi'),
            Text('Todos los derechos reservados'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _showLogoutDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      await ref.read(authRepositoryProvider).signOut();
      if (context.mounted) {
        context.go('/auth/login');
      }
    }
  }
}