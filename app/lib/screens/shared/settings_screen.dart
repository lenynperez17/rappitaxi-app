// ignore_for_file: deprecated_member_use
// Pantalla de Configuración - Estilo InDriver (Simplificado)
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/preferences_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../services/account_deletion_service.dart';
import '../../utils/error_messages.dart';

class SettingsScreen extends StatefulWidget {
  final String? userType;

  const SettingsScreen({super.key, this.userType});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  String _language = 'es';

  late final AnimationController _contentController;

  @override
  void initState() {
    super.initState();

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prefsProvider = Provider.of<PreferencesProvider>(context, listen: false);
      setState(() {
        _language = prefsProvider.language;
      });
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  /// Helper para animacion staggered de secciones
  Widget _animatedSection(Widget child, int index) {
    final double start = (index * 0.12).clamp(0.0, 0.8);
    final double end = (start + 0.4).clamp(0.0, 1.0);
    final animation = CurvedAnimation(
      parent: _contentController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, 30 * (1 - animation.value)),
        child: Opacity(opacity: animation.value, child: child),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.rappiOrange,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Configuración',
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 20),

            // Seccion: General (index 0)
            _animatedSection(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(context, 'GENERAL'),
                  _buildCard([
                    _buildLanguageTile(context),
                    _buildDivider(context),
                    Consumer<PreferencesProvider>(
                      builder: (ctx, prefs, _) => _buildSwitchTile(
                        context: ctx,
                        icon: Icons.dark_mode_outlined,
                        title: 'Modo Oscuro',
                        value: prefs.darkMode,
                        onChanged: (v) => prefs.setDarkMode(v),
                      ),
                    ),
                  ], context),
                ],
              ),
              0,
            ),

            SizedBox(height: 16),

            // Seccion: Notificaciones (index 1)
            _animatedSection(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(context, 'NOTIFICACIONES'),
                  _buildCard([
                    Consumer<PreferencesProvider>(
                      builder: (ctx, prefs, _) => _buildSwitchTile(
                        context: ctx,
                        icon: Icons.notifications_outlined,
                        title: 'Notificaciones push',
                        value: prefs.pushNotifications,
                        onChanged: (v) => prefs.setPushNotifications(v),
                      ),
                    ),
                  ], context),
                ],
              ),
              1,
            ),

            SizedBox(height: 16),

            // Seccion: Privacidad (index 2)
            _animatedSection(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(context, 'PRIVACIDAD'),
                  _buildCard([
                    Consumer<PreferencesProvider>(
                      builder: (ctx, prefs, _) => _buildLocationTile(ctx, prefs),
                    ),
                  ], context),
                ],
              ),
              2,
            ),

            SizedBox(height: 16),

            // Seccion: Soporte (index 3)
            _animatedSection(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(context, 'SOPORTE'),
                  _buildCard([
                    _buildActionTile(
                      context: context,
                      icon: Icons.help_outline,
                      title: 'Centro de Ayuda',
                      onTap: _openHelpCenter,
                    ),
                    _buildDivider(context),
                    _buildActionTile(
                      context: context,
                      icon: Icons.support_agent_outlined,
                      title: 'Contactar Soporte',
                      onTap: _contactSupport,
                    ),
                    _buildDivider(context),
                    _buildActionTile(
                      context: context,
                      icon: Icons.info_outline,
                      title: 'Acerca de la App',
                      onTap: _showAbout,
                    ),
                    _buildDivider(context),
                    _buildActionTile(
                      context: context,
                      icon: Icons.star_outline,
                      title: 'Calificar la App',
                      onTap: _rateApp,
                    ),
                  ], context),
                ],
              ),
              3,
            ),

            SizedBox(height: 16),

            // Seccion: Cuenta (index 4)
            _animatedSection(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(context, 'CUENTA'),
                  _buildCard([
                    _buildActionTile(
                      context: context,
                      icon: Icons.delete_outline,
                      title: 'Eliminar Cuenta',
                      iconColor: AppColors.error,
                      textColor: AppColors.error,
                      onTap: _deleteAccount,
                    ),
                  ], context),
                ],
              ),
              4,
            ),

            SizedBox(height: 32),

            // Version (index 5)
            _animatedSection(
              Center(
                child: Text(
                  'Rappi Team v1.0.0',
                  style: TextStyle(
                    color: AppColors.getTextSecondary(context),
                    fontSize: 12,
                  ),
                ),
              ),
              5,
            ),

            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.getTextSecondary(context),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children, BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.isDark(context)
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(height: 1, indent: 60, color: AppColors.getDivider(context));
  }

  Widget _buildSwitchTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.rappiOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.rappiOrange, size: 20),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.getTextPrimary(context),
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.rappiOrange,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    final color = iconColor ?? AppColors.rappiOrange;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textColor ?? AppColors.getTextPrimary(context),
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.getIcon(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageTile(BuildContext context) {
    return InkWell(
      onTap: _showLanguageDialog,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.rappiOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.language, color: AppColors.rappiOrange, size: 20),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                'Idioma',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
            ),
            Text(
              _language == 'es' ? 'Español' : 'English',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.getTextSecondary(context),
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.chevron_right, color: AppColors.getIcon(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationTile(BuildContext context, PreferencesProvider prefs) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.rappiOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.location_on_outlined, color: AppColors.rappiOrange, size: 20),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Compartir Ubicación',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.getTextPrimary(context),
              ),
            ),
          ),
          Switch(
            value: prefs.shareLocation,
            onChanged: (value) async {
              await prefs.setShareLocation(value);
            },
            activeColor: AppColors.rappiOrange,
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    final prefsProvider = Provider.of<PreferencesProvider>(context, listen: false);
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Seleccionar Idioma'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Radio<String>(
                value: 'es',
                groupValue: _language,
                onChanged: (v) {
                  setState(() => _language = v!);
                  Navigator.pop(ctx);
                  prefsProvider.setLanguage(v!);
                  localeProvider.setLocale(Locale(v));
                },
                activeColor: AppColors.rappiOrange,
              ),
              title: Text('Español'),
              onTap: () {
                setState(() => _language = 'es');
                Navigator.pop(ctx);
                prefsProvider.setLanguage('es');
                localeProvider.setLocale(Locale('es'));
              },
            ),
            ListTile(
              leading: Radio<String>(
                value: 'en',
                groupValue: _language,
                onChanged: (v) {
                  setState(() => _language = v!);
                  Navigator.pop(ctx);
                  prefsProvider.setLanguage(v!);
                  localeProvider.setLocale(Locale(v));
                },
                activeColor: AppColors.rappiOrange,
              ),
              title: Text('English'),
              onTap: () {
                setState(() => _language = 'en');
                Navigator.pop(ctx);
                prefsProvider.setLanguage('en');
                localeProvider.setLocale(Locale('en'));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openHelpCenter() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.help_outline, color: AppColors.rappiOrange),
            SizedBox(width: 12),
            Text('Centro de Ayuda'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.question_answer, color: AppColors.rappiOrange),
              title: Text('Preguntas frecuentes'),
              onTap: () {
                Navigator.pop(ctx);
                _launchUrl('https://rapiteam.com/faq');
              },
            ),
            ListTile(
              leading: Icon(Icons.phone, color: AppColors.rappiOrange),
              title: Text('Llamar a soporte'),
              onTap: () {
                Navigator.pop(ctx);
                _launchUrl('tel:+51928469836');
              },
            ),
            ListTile(
              leading: Icon(Icons.chat, color: Colors.green),
              title: Text('WhatsApp'),
              onTap: () {
                Navigator.pop(ctx);
                _contactSupport();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _contactSupport() async {
    final whatsappUrl = Uri.parse(
      'https://wa.me/51928469836?text=Hola,%20necesito%20ayuda%20con%20Rappi%20Team'
    );
    try {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo abrir WhatsApp'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo abrir el enlace'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.rappiOrange, AppColors.rappiOrangeDark],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.local_taxi, color: Colors.white, size: 24),
            ),
            SizedBox(width: 12),
            Text('Rappi Team'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tu servicio de transporte confiable.'),
              SizedBox(height: 16),
              Text('Versión: 1.0.0', style: TextStyle(color: AppColors.grey500)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _rateApp() async {
    Uri storeUrl;
    if (Platform.isAndroid) {
      storeUrl = Uri.parse('market://details?id=com.rapiteam.app');
    } else {
      storeUrl = Uri.parse('https://apps.apple.com/app/rappi-team/id123456789');
    }

    try {
      await launchUrl(storeUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      // If market:// fails, try web URL
      if (Platform.isAndroid) {
        await launchUrl(
          Uri.parse('https://play.google.com/store/apps/details?id=com.rapiteam.app'),
          mode: LaunchMode.externalApplication,
        );
      }
    }
  }

  void _deleteAccount() {
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Eliminar Cuenta',
          style: TextStyle(color: AppColors.error),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Esta acción es irreversible. Se eliminarán:'),
              SizedBox(height: 12),
              Text('• Todos tus datos personales'),
              Text('• Historial de viajes'),
              Text('• Métodos de pago'),
              SizedBox(height: 16),
              Text(
                'Escribe ELIMINAR para confirmar:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              TextField(
                controller: confirmController,
                decoration: InputDecoration(
                  hintText: 'ELIMINAR',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (confirmController.text.trim().toUpperCase() != 'ELIMINAR') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Debes escribir ELIMINAR para confirmar'),
                    backgroundColor: AppColors.warning,
                  ),
                );
                return;
              }

              Navigator.pop(ctx);
              await _performAccountDeletion();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Eliminar Cuenta'),
          ),
        ],
      ),
    );
  }

  Future<void> _performAccountDeletion() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: AppColors.rappiOrange),
            const SizedBox(width: 16),
            const Text('Eliminando cuenta...'),
          ],
        ),
      ),
    );

    try {
      // Server-side delete: limpia Firestore + Storage + Auth en una sola
      // operación atómica (Cloud Function `deleteMyAccount` 2nd gen).
      // No requiere reauth con password — funciona también con OAuth.
      await AccountDeletionService.deleteCurrentUserAccount();

      try {
        await authProvider.logout();
      } catch (_) {/* el server ya borró el user; logout local es best-effort */}

      if (!mounted) return;
      navigator.pop(); // Close loading
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Cuenta eliminada correctamente'),
          backgroundColor: AppColors.success,
        ),
      );
      navigator.pushNamedAndRemoveUntil('/login', (route) => false);
    } on AccountDeletionException catch (e) {
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo eliminar la cuenta: ${e.message}'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(userFriendlyError(e, fallback: 'Error inesperado')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
