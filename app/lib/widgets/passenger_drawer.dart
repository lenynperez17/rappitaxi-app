import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/widgets/mode_switch_button.dart';
import '../providers/auth_provider.dart';

class PassengerDrawer extends StatelessWidget {
  const PassengerDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Drawer(
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            // Header del drawer
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 20,
                bottom: 20,
                left: 20,
                right: 20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.rappiTurquoise,
                    AppColors.rappiTurquoiseLight,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar del usuario
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).colorScheme.onPrimary, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: user != null && user.profilePhotoUrl.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              user.profilePhotoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                Icons.person,
                                size: 50,
                                color: AppColors.rappiTurquoise,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.person,
                            size: 50,
                            color: AppColors.rappiTurquoise,
                          ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    user?.fullName ?? 'Usuario',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    user?.email ?? 'email@example.com',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          (user?.rating ?? 0.0).toStringAsFixed(1),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          ' • ${user?.totalTrips ?? 0} viajes',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Botón de cambio de modo (solo si tiene múltiples roles)
            if (user != null &&
                user.availableRoles != null &&
                user.availableRoles!.length > 1)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: ModeSwitchButton(compact: false),
              ),

            // Opciones del menú
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildMenuItem(
                    icon: Icons.person_outline,
                    title: 'Mi perfil',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/profile');
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.history,
                    title: 'Historial de viajes',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/passenger/trip-history');
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.account_balance_wallet,
                    title: 'Mi Billetera',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/wallet');
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.payment,
                    title: 'Métodos de pago',
                    badge: '2',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/passenger/payment-methods');
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.local_offer,
                    title: 'Promociones',
                    badge: 'Nuevo',
                    badgeColor: Color(0xFF10B981),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/passenger/promotions');
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.favorite,
                    title: 'Lugares favoritos',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/passenger/favorites');
                    },
                  ),
                  Divider(height: 1),
                  _buildMenuItem(
                    icon: Icons.help_outline,
                    title: 'Ayuda y soporte',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/help');
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.info_outline,
                    title: 'Acerca de Rappi Team',
                    onTap: () {
                      Navigator.pop(context);
                      _showAboutDialog(context);
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.settings,
                    title: 'Configuración',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/settings');
                    },
                  ),
                ],
              ),
            ),
            
            // Botón de cerrar sesión
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                ),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.logout,
                  color: Colors.red,
                ),
                title: Text(
                  'Cerrar sesión',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  _showLogoutDialog(context);
                },
              ),
            ),
            
            // Versión de la app
            Container(
              padding: EdgeInsets.all(16),
              child: Text(
                'Versión 1.0.0',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? badge,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    return Builder(
      builder: (context) => ListTile(
        leading: Icon(icon, color: AppColors.rappiTurquoise),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      trailing: badge != null
          ? Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor ?? AppColors.rappiTurquoise,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
        onTap: onTap,
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.rappiTurquoise, AppColors.rappiTurquoiseLight],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.local_taxi,
                color: Theme.of(context).colorScheme.onPrimary,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Text('Rappi Team'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tu servicio de taxi confiable y seguro.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'Versión: 1.0.0',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
            Text(
              'Desarrollado por: Rappi Team Tech',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text('Cerrar sesión'),
        content: Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}