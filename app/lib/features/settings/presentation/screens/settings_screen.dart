import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/oasis_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// Providers para configuraciones
final darkModeProvider = StateProvider<bool>((ref) => false);
final notificationsProvider = StateProvider<bool>((ref) => true);
final locationSharingProvider = StateProvider<bool>((ref) => true);
final rideRemindersProvider = StateProvider<bool>((ref) => true);
final promotionNotificationsProvider = StateProvider<bool>((ref) => false);
final languageProvider = StateProvider<String>((ref) => 'es');
final emergencyContactProvider = StateProvider<String?>((ref) => null);
final favoriteAddressesProvider = StateProvider<List<String>>((ref) => []);

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final isDarkMode = ref.watch(darkModeProvider);
    final notificationsEnabled = ref.watch(notificationsProvider);
    final locationSharing = ref.watch(locationSharingProvider);
    final rideReminders = ref.watch(rideRemindersProvider);
    final promotionNotifications = ref.watch(promotionNotificationsProvider);
    final selectedLanguage = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header del perfil
            _buildProfileHeader(currentUser),
            
            const SizedBox(height: 20),
            
            // Secciones de configuración
            _buildAccountSection(context),
            _buildPrivacySection(context, locationSharing),
            _buildNotificationSection(context, notificationsEnabled, rideReminders, promotionNotifications),
            _buildAppearanceSection(context, isDarkMode, selectedLanguage),
            _buildSafetySection(context),
            _buildSupportSection(context),
            _buildAboutSection(context),
            
            const SizedBox(height: 32),
            
            // Cerrar sesión
            _buildSignOutSection(context),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(currentUser) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            Colors.white,
          ],
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppTheme.primaryColor,
            child: Text(
              currentUser?.name?.substring(0, 1)?.toUpperCase() ?? 'U',
              style: const TextStyle(
                color: Colors.white,
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
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentUser?.email ?? 'usuario@ejemplo.com',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.star,
                      color: Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '4.8 • 127 viajes',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          IconButton(
            onPressed: () => context.push('/profile/edit'),
            icon: const Icon(Icons.edit),
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey.shade100,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.1, end: 0);
  }

  Widget _buildAccountSection(BuildContext context) {
    return _buildSection(
      title: 'Cuenta',
      items: [
        _buildSettingItem(
          icon: Icons.person_outline,
          title: 'Información personal',
          subtitle: 'Nombre, teléfono, correo',
          onTap: () => context.push('/profile/edit'),
        ),
        _buildSettingItem(
          icon: Icons.payment,
          title: 'Métodos de pago',
          subtitle: 'Tarjetas, efectivo, Mercado Pago',
          onTap: () => context.push('/profile/payment-methods'),
        ),
        _buildSettingItem(
          icon: Icons.location_on_outlined,
          title: 'Direcciones guardadas',
          subtitle: 'Casa, trabajo, favoritos',
          onTap: () => _showSavedAddressesDialog(context),
        ),
        _buildSettingItem(
          icon: Icons.history,
          title: 'Historial de viajes',
          subtitle: 'Ver todos mis viajes',
          onTap: () => context.push('/ride/history'),
        ),
      ],
    );
  }

  Widget _buildPrivacySection(BuildContext context, bool locationSharing) {
    return _buildSection(
      title: 'Privacidad y seguridad',
      items: [
        _buildSwitchItem(
          icon: Icons.location_on,
          title: 'Compartir ubicación',
          subtitle: 'Permite a familiares ver tu ubicación durante viajes',
          value: locationSharing,
          onChanged: (value) {
            ref.read(locationSharingProvider.notifier).state = value;
          },
        ),
        _buildSettingItem(
          icon: Icons.contacts,
          title: 'Contactos de emergencia',
          subtitle: 'Configurar contactos de emergencia',
          onTap: () => _showEmergencyContactsDialog(context),
        ),
        _buildSettingItem(
          icon: Icons.security,
          title: 'Verificación de identidad',
          subtitle: 'Verificar tu identidad para mayor seguridad',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Verificado',
              style: TextStyle(
                color: AppTheme.successColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          onTap: () {},
        ),
        _buildSettingItem(
          icon: Icons.privacy_tip_outlined,
          title: 'Política de privacidad',
          subtitle: 'Cómo usamos tu información',
          onTap: () => _showPrivacyPolicyDialog(context),
        ),
      ],
    );
  }

  Widget _buildNotificationSection(BuildContext context, bool notificationsEnabled, bool rideReminders, bool promotionNotifications) {
    return _buildSection(
      title: 'Notificaciones',
      items: [
        _buildSwitchItem(
          icon: Icons.notifications_outlined,
          title: 'Notificaciones push',
          subtitle: 'Recibir notificaciones en tu dispositivo',
          value: notificationsEnabled,
          onChanged: (value) {
            ref.read(notificationsProvider.notifier).state = value;
          },
        ),
        _buildSwitchItem(
          icon: Icons.schedule,
          title: 'Recordatorios de viajes',
          subtitle: 'Recordatorios de viajes programados',
          value: rideReminders,
          onChanged: (value) {
            ref.read(rideRemindersProvider.notifier).state = value;
          },
        ),
        _buildSwitchItem(
          icon: Icons.local_offer,
          title: 'Ofertas y promociones',
          subtitle: 'Recibir notificaciones de descuentos',
          value: promotionNotifications,
          onChanged: (value) {
            ref.read(promotionNotificationsProvider.notifier).state = value;
          },
        ),
        _buildSettingItem(
          icon: Icons.email_outlined,
          title: 'Notificaciones por correo',
          subtitle: 'Gestionar notificaciones por email',
          onTap: () => _showEmailNotificationsDialog(context),
        ),
      ],
    );
  }

  Widget _buildAppearanceSection(BuildContext context, bool isDarkMode, String selectedLanguage) {
    return _buildSection(
      title: 'Apariencia',
      items: [
        _buildSwitchItem(
          icon: Icons.dark_mode_outlined,
          title: 'Modo oscuro',
          subtitle: 'Usar tema oscuro en la aplicación',
          value: isDarkMode,
          onChanged: (value) {
            ref.read(darkModeProvider.notifier).state = value;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(value ? 'Modo oscuro activado' : 'Modo claro activado'),
                backgroundColor: AppTheme.primaryColor,
              ),
            );
          },
        ),
        _buildSettingItem(
          icon: Icons.language,
          title: 'Idioma',
          subtitle: _getLanguageName(selectedLanguage),
          onTap: () => _showLanguageDialog(context),
        ),
        _buildSettingItem(
          icon: Icons.map,
          title: 'Estilo del mapa',
          subtitle: 'Personalizar apariencia del mapa',
          onTap: () => _showMapStyleDialog(context),
        ),
      ],
    );
  }

  Widget _buildSafetySection(BuildContext context) {
    return _buildSection(
      title: 'Seguridad',
      items: [
        _buildSettingItem(
          icon: Icons.shield_outlined,
          title: 'Centro de seguridad',
          subtitle: 'Consejos y herramientas de seguridad',
          onTap: () => _showSafetyCenterDialog(context),
        ),
        _buildSettingItem(
          icon: Icons.warning_amber_outlined,
          title: 'Reportar problema',
          subtitle: 'Reportar incidentes de seguridad',
          onTap: () => _showReportDialog(context),
        ),
        _buildSettingItem(
          icon: Icons.sos,
          title: 'Botón de emergencia',
          subtitle: 'Configurar botón de pánico',
          onTap: () => _showEmergencyButtonDialog(context),
        ),
      ],
    );
  }

  Widget _buildSupportSection(BuildContext context) {
    return _buildSection(
      title: 'Ayuda y soporte',
      items: [
        _buildSettingItem(
          icon: Icons.help_outline,
          title: 'Centro de ayuda',
          subtitle: 'Preguntas frecuentes y guías',
          onTap: () => context.push('/support/faq'),
        ),
        _buildSettingItem(
          icon: Icons.chat_bubble_outline,
          title: 'Contactar soporte',
          subtitle: 'Chat en vivo con nuestro equipo',
          onTap: () => context.push('/support'),
        ),
        _buildSettingItem(
          icon: Icons.feedback_outlined,
          title: 'Enviar comentarios',
          subtitle: 'Ayúdanos a mejorar la app',
          onTap: () => _showFeedbackDialog(context),
        ),
        _buildSettingItem(
          icon: Icons.star_rate_outlined,
          title: 'Calificar la app',
          subtitle: 'Califica en la tienda de aplicaciones',
          onTap: () => _showRateAppDialog(context),
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return _buildSection(
      title: 'Acerca de',
      items: [
        _buildSettingItem(
          icon: Icons.info_outline,
          title: 'Versión de la app',
          subtitle: '2.4.1 (Build 241)',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Actualizada',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          onTap: () {},
        ),
        _buildSettingItem(
          icon: Icons.article_outlined,
          title: 'Términos y condiciones',
          subtitle: 'Leer términos de servicio',
          onTap: () => _showTermsDialog(context),
        ),
        _buildSettingItem(
          icon: Icons.business,
          title: 'Sobre RappiTaxi',
          subtitle: 'Información de la empresa',
          onTap: () => _showAboutDialog(context),
        ),
      ],
    );
  }

  Widget _buildSignOutSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          OasisButton(
            text: 'Cerrar sesión',
            onPressed: () => _showSignOutDialog(context),
            isOutlined: true,
            icon: const Icon(Icons.logout),
          ).animate().fadeIn(delay: 800.ms),
          
          const SizedBox(height: 16),
          
          TextButton(
            onPressed: () => _showDeleteAccountDialog(context),
            child: Text(
              'Eliminar cuenta',
              style: TextStyle(
                color: AppTheme.errorColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
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
            children: items,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: AppTheme.primaryColor,
          size: 20,
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
        style: TextStyle(
          color: AppTheme.textSecondaryColor,
          fontSize: 12,
        ),
      ),
      trailing: trailing ?? const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey,
      ),
      onTap: onTap,
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: AppTheme.primaryColor,
          size: 20,
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
        style: TextStyle(
          color: AppTheme.textSecondaryColor,
          fontSize: 12,
        ),
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.primaryColor,
      ),
    );
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'es':
        return 'Español';
      case 'en':
        return 'English';
      case 'pt':
        return 'Português';
      default:
        return 'Español';
    }
  }

  // Dialog methods
  void _showSavedAddressesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Direcciones guardadas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Gestiona tus direcciones favoritas'),
            const SizedBox(height: 16),
            // Lista de direcciones guardadas
            Container(
              height: 200,
              child: ListView.builder(
                itemCount: 3,
                itemBuilder: (context, index) {
                  final addresses = ['Casa', 'Trabajo', 'Gimnasio'];
                  return ListTile(
                    leading: Icon(
                      index == 0 ? Icons.home : index == 1 ? Icons.work : Icons.place,
                      color: AppTheme.primaryColor,
                    ),
                    title: Text(addresses[index]),
                    subtitle: const Text('Configurar dirección'),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {},
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {},
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  void _showEmergencyContactsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contactos de emergencia'),
        content: const Text(
          'Configura contactos que serán notificados automáticamente en caso de emergencia durante un viaje.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navegar a pantalla de contactos de emergencia
            },
            child: const Text('Configurar'),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar idioma'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Español'),
              value: 'es',
              groupValue: ref.read(languageProvider),
              onChanged: (value) {
                ref.read(languageProvider.notifier).state = value ?? 'es';
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('English'),
              value: 'en',
              groupValue: ref.read(languageProvider),
              onChanged: (value) {
                ref.read(languageProvider.notifier).state = value ?? 'es';
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Português'),
              value: 'pt',
              groupValue: ref.read(languageProvider),
              onChanged: (value) {
                ref.read(languageProvider.notifier).state = value ?? 'es';
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // TODO: Implementar cierre de sesión
              // await ref.read(authProvider.notifier).signOut();
              context.go('/auth/login');
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '¿Eliminar cuenta?',
          style: TextStyle(color: AppTheme.errorColor),
        ),
        content: const Text(
          'Esta acción es irreversible. Se eliminarán todos tus datos, historial de viajes y métodos de pago.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showDeleteAccountConfirmationDialog(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountConfirmationDialog(BuildContext context) {
    final confirmController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Confirmación requerida',
          style: TextStyle(color: AppTheme.errorColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Escribe "ELIMINAR" para confirmar:'),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'ELIMINAR',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (confirmController.text == 'ELIMINAR') {
                Navigator.pop(context);
                // TODO: Implementar eliminación de cuenta
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Función no implementada'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('Eliminar cuenta'),
          ),
        ],
      ),
    );
  }

  // Más métodos de dialog simplificados
  void _showPrivacyPolicyDialog(BuildContext context) => _showInfoDialog(context, 'Política de privacidad', 'Aquí iría el contenido de la política de privacidad...');
  void _showEmailNotificationsDialog(BuildContext context) => _showInfoDialog(context, 'Notificaciones por correo', 'Configura qué tipo de emails deseas recibir.');
  void _showMapStyleDialog(BuildContext context) => _showInfoDialog(context, 'Estilo del mapa', 'Personaliza la apariencia del mapa según tus preferencias.');
  void _showSafetyCenterDialog(BuildContext context) => _showInfoDialog(context, 'Centro de seguridad', 'Consejos y herramientas para viajes seguros.');
  void _showReportDialog(BuildContext context) => _showInfoDialog(context, 'Reportar problema', 'Reporta cualquier incidente de seguridad.');
  void _showEmergencyButtonDialog(BuildContext context) => _showInfoDialog(context, 'Botón de emergencia', 'Configura el botón de pánico para emergencias.');
  void _showFeedbackDialog(BuildContext context) => _showInfoDialog(context, 'Enviar comentarios', 'Ayúdanos a mejorar enviando tus sugerencias.');
  void _showRateAppDialog(BuildContext context) => _showInfoDialog(context, 'Calificar la app', '¡Califícanos en la tienda de aplicaciones!');
  void _showTermsDialog(BuildContext context) => _showInfoDialog(context, 'Términos y condiciones', 'Términos y condiciones del servicio...');
  void _showAboutDialog(BuildContext context) => _showInfoDialog(context, 'Sobre RappiTaxi', 'RappiTaxi - Tu app de transporte confiable desde 2024.');

  void _showInfoDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}