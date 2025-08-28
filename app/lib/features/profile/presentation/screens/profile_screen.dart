import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../shared/providers/riverpod_compat.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/oasis_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    
    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('Usuario no autenticado'),
        ),
      );
    }
    
    return Scaffold(
      // backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // AppBar con foto de perfil
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            // backgroundColor: AppTheme.primaryColor,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    // Foto de perfil
                    Hero(
                      tag: 'profile-photo',
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.white,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: currentUser.photoUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  currentUser.photoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person,
                                    size: 50,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                size: 50,
                                color: AppTheme.primaryColor,
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Nombre
                    Text(
                      currentUser.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Email
                    Text(
                      currentUser.email,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Contenido
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Estadísticas
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        icon: Icons.directions_car,
                        value: '${currentUser.passengerData?.totalRides ?? 0}',
                        label: 'Viajes',
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.grey[300],
                      ),
                      _buildStatItem(
                        icon: Icons.star,
                        value: currentUser.passengerData?.rating.toStringAsFixed(1) ?? '5.0',
                        label: 'Calificación',
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.grey[300],
                      ),
                      _buildStatItem(
                        icon: Icons.payment,
                        value: '${currentUser.passengerData?.paymentMethods.length ?? 0}',
                        label: 'Métodos',
                      ),
                    ],
                  ),
                ).animate().fadeIn().slideY(begin: 0.1, end: 0),
                
                // Opciones del menú
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildMenuItem(
                        icon: Icons.person_outline,
                        title: 'Editar perfil',
                        subtitle: 'Actualiza tu información personal',
                        onTap: () => context.push('/profile/edit'),
                      ),
                      _buildDivider(),
                      _buildMenuItem(
                        icon: Icons.credit_card,
                        title: 'Métodos de pago',
                        subtitle: 'Administra tus métodos de pago',
                        onTap: () => context.push('/profile/payment-methods'),
                      ),
                      _buildDivider(),
                      _buildMenuItem(
                        icon: Icons.history,
                        title: 'Historial de viajes',
                        subtitle: 'Revisa tus viajes anteriores',
                        onTap: () => context.push('/profile/ride-history'),
                      ),
                      _buildDivider(),
                      _buildMenuItem(
                        icon: Icons.location_on,
                        title: 'Direcciones favoritas',
                        subtitle: 'Gestiona tus lugares frecuentes',
                        onTap: () => context.push('/profile/favorite-places'),
                      ),
                      _buildDivider(),
                      _buildMenuItem(
                        icon: Icons.settings,
                        title: 'Configuración',
                        subtitle: 'Preferencias de la aplicación',
                        onTap: () => context.push('/profile/settings'),
                      ),
                    ],
                  ),
                ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.1, end: 0),
                
                const SizedBox(height: 24),
                
                // Botón de cerrar sesión
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OasisButton(
                    text: 'Cerrar sesión',
                    onPressed: () => _showLogoutDialog(context, ref),
                    isOutlined: true,
                    // textColor: AppTheme.errorColor,
                    // borderColor: AppTheme.errorColor,
                  ),
                ).animate(delay: 200.ms).fadeIn(),
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppTheme.primaryColor,
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
  
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: AppTheme.primaryColor,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
  
  Widget _buildDivider() {
    return const Divider(
      height: 1,
      indent: 72,
      endIndent: 16,
    );
  }
  
  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(authRepositoryProvider).signOut();
              context.go('/auth/login');
            },
            child: Text(
              'Cerrar sesión',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );
  }
}