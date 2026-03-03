import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design/design_system.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../providers/preferences_provider.dart';
import '../../providers/auth_provider.dart';
import 'complaints_book_screen.dart';
import 'help_center_screen.dart';
import 'support_screen.dart';
import 'about_screen.dart';

/// Pantalla de configuración simplificada — solo opciones funcionales
class SettingsScreen extends StatefulWidget {
  final String? userType;

  const SettingsScreen({super.key, this.userType});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Control de double-trigger para dark mode
  bool _isDarkModeChanging = false;

  // Estado local sincronizado con PreferencesProvider
  bool _darkModeEnabled = false;
  bool _pushNotifications = true;
  bool _tripUpdates = true;
  bool _promotions = true;

  @override
  void initState() {
    super.initState();

    // Inicializar valores desde el provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prefs = context.read<PreferencesProvider>();
      setState(() {
        _darkModeEnabled = prefs.darkMode;
        _pushNotifications = prefs.pushNotifications;
        _tripUpdates = prefs.tripUpdates;
        _promotions = prefs.promotions;
      });
    });

    _fadeController = AnimationController(
      duration: RtDuration.slow,
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: RtCurve.enter,
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: const RtAppBar(
        title: 'Configuración',
        variant: RtAppBarVariant.gradient,
      ),
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Sección 1: General
                  _buildSection(
                    'General',
                    Icons.settings,
                    RtColors.info,
                    [
                      _buildDarkModeTile(),
                    ],
                  ),

                  // Sección 2: Notificaciones
                  _buildSection(
                    'Notificaciones',
                    Icons.notifications,
                    RtColors.warning,
                    [
                      _buildSwitchTile(
                        'Notificaciones Push',
                        'Recibir notificaciones en tu dispositivo',
                        Icons.notifications_active,
                        _pushNotifications,
                        (value) async {
                          setState(() => _pushNotifications = value);
                          await context
                              .read<PreferencesProvider>()
                              .setPushNotifications(value);
                        },
                      ),
                      _buildSwitchTile(
                        'Actualizaciones de Viaje',
                        'Estados del viaje y conductor',
                        Icons.directions_car,
                        _tripUpdates,
                        (value) async {
                          setState(() => _tripUpdates = value);
                          await context
                              .read<PreferencesProvider>()
                              .setTripUpdates(value);
                        },
                      ),
                      _buildSwitchTile(
                        'Promociones',
                        'Ofertas y descuentos especiales',
                        Icons.local_offer,
                        _promotions,
                        (value) async {
                          setState(() => _promotions = value);
                          await context
                              .read<PreferencesProvider>()
                              .setPromotions(value);
                        },
                      ),
                    ],
                  ),

                  // Sección 3: Soporte y Legal
                  _buildSection(
                    'Soporte y Legal',
                    Icons.help,
                    RtColors.info,
                    [
                      _buildActionTile(
                        'Centro de Ayuda',
                        'Preguntas frecuentes y tutoriales',
                        Icons.help_center,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const HelpCenterScreen(),
                          ),
                        ),
                      ),
                      _buildActionTile(
                        'Contactar Soporte',
                        'Obtener ayuda personalizada',
                        Icons.support_agent,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SupportScreen(),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      _buildActionTile(
                        'Libro de Reclamaciones',
                        'Presenta reclamos según Ley N° 29571',
                        Icons.menu_book,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ComplaintsBookScreen(),
                          ),
                        ),
                        color: RtColors.warning,
                      ),
                      _buildActionTile(
                        'Acerca de la App',
                        'Versión e información legal',
                        Icons.info,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AboutScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Sección 4: Gestión de Cuenta
                  _buildSection(
                    'Cuenta',
                    Icons.account_circle,
                    RtColors.neutral500,
                    [
                      _buildActionTile(
                        'Cambiar Contraseña',
                        'Actualizar tu contraseña',
                        Icons.lock,
                        _changePassword,
                      ),
                      const Divider(height: 1),
                      _buildActionTile(
                        'Cerrar Sesión',
                        'Salir de tu cuenta',
                        Icons.logout,
                        _logout,
                        color: RtColors.warning,
                      ),
                      _buildActionTile(
                        'Eliminar Cuenta',
                        'Borrar permanentemente tu cuenta',
                        Icons.delete_forever,
                        _deleteAccount,
                        color: RtColors.error,
                      ),
                    ],
                  ),

                  const SizedBox(height: RtSpacing.xxl),

                  // Versión de la app
                  Padding(
                    padding: RtSpacing.screenH,
                    child: Text(
                      'RapiTeam v1.3.0 (Build 56)',
                      style: RtTypo.labelSmall.copyWith(
                        color: RtColors.neutral400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: RtSpacing.xxl),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // === WIDGETS REUTILIZABLES ===

  Widget _buildSection(
      String title, IconData icon, Color color, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            RtSpacing.base,
            RtSpacing.xl,
            RtSpacing.base,
            RtSpacing.md,
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: RtIconSize.sm),
              const SizedBox(width: RtSpacing.sm),
              Text(
                title,
                style: RtTypo.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: RtSpacing.screenH,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: RtRadius.borderMd,
            boxShadow: RtShadow.soft(),
          ),
          child: ClipRRect(
            borderRadius: RtRadius.borderMd,
            child: Column(children: children),
          ),
        ),
      ],
    );
  }

  // Dark Mode con throttle para prevenir double-trigger
  Widget _buildDarkModeTile() {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(RtSpacing.sm),
        decoration: BoxDecoration(
          color: RtColors.brand.withValues(alpha: 0.1),
          borderRadius: RtRadius.borderSm,
        ),
        child: const Icon(Icons.dark_mode,
            color: RtColors.brand, size: RtIconSize.sm),
      ),
      title: Text('Modo Oscuro', style: RtTypo.titleMedium),
      subtitle: Text(
        'Cambiar apariencia de la app',
        style: RtTypo.bodySmall.copyWith(
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.6),
        ),
      ),
      trailing: Switch.adaptive(
        value: _darkModeEnabled,
        onChanged: _isDarkModeChanging
            ? null
            : (bool newValue) {
                setState(() {
                  _isDarkModeChanging = true;
                  _darkModeEnabled = newValue;
                });

                context
                    .read<PreferencesProvider>()
                    .setDarkMode(newValue)
                    .then((_) {
                  Future.delayed(RtDuration.normal, () {
                    if (mounted) {
                      setState(() {
                        _isDarkModeChanging = false;
                      });
                    }
                  });
                });
              },
        activeThumbColor: RtColors.brand,
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, IconData icon,
      bool value, Function(bool) onChanged) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(RtSpacing.sm),
        decoration: BoxDecoration(
          color: RtColors.brand.withValues(alpha: 0.1),
          borderRadius: RtRadius.borderSm,
        ),
        child: Icon(icon, color: RtColors.brand, size: RtIconSize.sm),
      ),
      title: Text(title, style: RtTypo.titleMedium),
      subtitle: Text(
        subtitle,
        style: RtTypo.bodySmall.copyWith(
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.6),
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: RtColors.brand,
      ),
    );
  }

  Widget _buildActionTile(
      String title, String subtitle, IconData icon, VoidCallback onTap,
      {Color? color}) {
    final tileColor = color ?? RtColors.info;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(RtSpacing.sm),
        decoration: BoxDecoration(
          color: tileColor.withValues(alpha: 0.1),
          borderRadius: RtRadius.borderSm,
        ),
        child: Icon(icon, color: tileColor, size: RtIconSize.sm),
      ),
      title: Text(
        title,
        style: RtTypo.titleMedium.copyWith(color: color),
      ),
      subtitle: Text(
        subtitle,
        style: RtTypo.bodySmall.copyWith(
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.6),
        ),
      ),
      trailing: Icon(Icons.arrow_forward_ios,
          size: RtIconSize.xs, color: RtColors.neutral400),
      onTap: onTap,
    );
  }

  // === ACCIONES FUNCIONALES ===

  void _changePassword() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
        title: Text('Cambiar Contraseña', style: RtTypo.headingSmall),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña Actual',
                  border:
                      OutlineInputBorder(borderRadius: RtRadius.borderMd),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: RtSpacing.base),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Nueva Contraseña',
                  border:
                      OutlineInputBorder(borderRadius: RtRadius.borderMd),
                  prefixIcon: const Icon(Icons.lock),
                  helperText:
                      'Mín. 8 caracteres, mayúsculas, minúsculas, números y símbolos',
                  helperMaxLines: 2,
                ),
              ),
              const SizedBox(height: RtSpacing.base),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirmar Nueva Contraseña',
                  border:
                      OutlineInputBorder(borderRadius: RtRadius.borderMd),
                  prefixIcon: const Icon(Icons.check_circle_outline),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              currentPasswordController.dispose();
              newPasswordController.dispose();
              confirmPasswordController.dispose();
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPasswordController.text !=
                  confirmPasswordController.text) {
                RtSnackbar.show(
                  dialogContext,
                  message: 'Las contraseñas no coinciden',
                  type: RtSnackbarType.error,
                );
                return;
              }

              final password = newPasswordController.text;
              if (password.length < 8 ||
                  !password.contains(RegExp(r'[A-Z]')) ||
                  !password.contains(RegExp(r'[a-z]')) ||
                  !password.contains(RegExp(r'[0-9]')) ||
                  !password
                      .contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
                RtSnackbar.show(
                  dialogContext,
                  message:
                      'La contraseña debe tener al menos 8 caracteres con mayúsculas, minúsculas, números y caracteres especiales',
                  type: RtSnackbarType.error,
                );
                return;
              }

              final authProvider =
                  Provider.of<AuthProvider>(dialogContext, listen: false);
              final navigator = Navigator.of(dialogContext);

              final success = await authProvider.changePassword(
                currentPasswordController.text,
                newPasswordController.text,
              );

              currentPasswordController.dispose();
              newPasswordController.dispose();
              confirmPasswordController.dispose();

              navigator.pop();

              if (!mounted) return;
              if (success) {
                RtSnackbar.show(
                  context,
                  message: 'Contraseña actualizada exitosamente',
                  type: RtSnackbarType.success,
                );
              } else {
                RtSnackbar.show(
                  context,
                  message: authProvider.errorMessage ??
                      'Error al cambiar contraseña',
                  type: RtSnackbarType.error,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: RtColors.brand,
              foregroundColor: RtColors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: RtRadius.borderSm),
            ),
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
        title: Text('Cerrar Sesión', style: RtTypo.headingSmall),
        content: Text(
          '¿Estás seguro de que deseas cerrar sesión?',
          style: RtTypo.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final authProvider =
                  Provider.of<AuthProvider>(context, listen: false);
              await authProvider.logout();
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: RtColors.warning,
              foregroundColor: RtColors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: RtRadius.borderSm),
            ),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }

  void _deleteAccount() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
        title: Text(
          'Eliminar Cuenta',
          style: RtTypo.headingSmall.copyWith(color: RtColors.error),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Esta acción es irreversible. Se eliminará:',
                style: RtTypo.bodyMedium),
            const SizedBox(height: RtSpacing.sm),
            Text('• Todos tus datos personales', style: RtTypo.bodySmall),
            Text('• Historial de viajes', style: RtTypo.bodySmall),
            Text('• Métodos de pago', style: RtTypo.bodySmall),
            Text('• Calificaciones y comentarios',
                style: RtTypo.bodySmall),
            const SizedBox(height: RtSpacing.base),
            Text(
              '¿Estás completamente seguro?',
              style:
                  RtTypo.titleMedium.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final authProvider =
                    Provider.of<AuthProvider>(context, listen: false);
                await authProvider.deleteAccount();
                if (!mounted) return;
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              } catch (e) {
                if (!mounted) return;
                final errorMsg = e.toString().contains('requires-recent-login')
                    ? 'Por seguridad, debes volver a iniciar sesión antes de eliminar tu cuenta'
                    : 'Error al eliminar la cuenta. Inténtalo de nuevo.';
                RtSnackbar.show(
                  context,
                  message: errorMsg,
                  type: RtSnackbarType.error,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: RtColors.error,
              foregroundColor: RtColors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: RtRadius.borderSm),
            ),
            child: const Text('Eliminar Cuenta'),
          ),
        ],
      ),
    );
  }
}
