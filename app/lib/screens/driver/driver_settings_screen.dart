// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive_bottom_sheet.dart';
import '../../providers/auth_provider.dart' as app;
import '../../providers/preferences_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/account_deletion_service.dart';
import '../../generated/l10n/app_localizations.dart';

class DriverSettingsScreen extends StatefulWidget {
  const DriverSettingsScreen({super.key});

  @override
  State<DriverSettingsScreen> createState() => _DriverSettingsScreenState();
}

class _DriverSettingsScreenState extends State<DriverSettingsScreen> {
  String _selectedNav = 'Google Maps';
  String _selectedUnits = 'km';

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  // Las preferencias de servicio del conductor (navegador, unidades de distancia)
  // se guardan localmente en SharedPreferences hasta que el backend exponga
  // un endpoint dedicado. No son sensibles y se recuperan por dispositivo.
  Future<void> _loadSavedSettings() async {
    try {
      final sp = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _selectedNav = sp.getString('driver_pref_navigator') ?? 'Google Maps';
          _selectedUnits = sp.getString('driver_pref_distanceUnits') ?? 'km';
        });
      }
    } catch (_) {}
  }

  Future<void> _saveDriverPref(String key, String value) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString('driver_pref_$key', value);
    } catch (_) {}
  }

  String _getLanguageLabel(LocaleProvider locale) {
    return locale.locale.languageCode == 'en' ? 'English' : 'Español';
  }

  String _getUnitsLabel(AppLocalizations l10n) {
    return _selectedUnits == 'mi'
        ? (l10n.language == 'Language' ? 'Miles' : 'Millas')
        : (l10n.language == 'Language' ? 'Kilometers' : 'Kilómetros');
  }

  void _showOptionPicker(String title, List<String> options, String current, ValueChanged<String> onChanged) {
    showResponsiveBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
          ),
          ...options.map((option) => ListTile(
            title: Text(option),
            trailing: option == current ? const Icon(Icons.check, color: AppColors.rappiRed) : null,
            onTap: () {
              onChanged(option);
              Navigator.pop(ctx);
            },
          )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefsProvider = Provider.of<PreferencesProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    final isEn = localeProvider.locale.languageCode == 'en';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back, size: 28, color: AppColors.getTextPrimary(context)),
                  ),
                  const SizedBox(width: 28),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'App\nSettings' : 'Configuración de\nla aplicación',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context)),
                    ),
                    const SizedBox(height: 24),

                    // Navigator
                    _SettingsItem(
                      icon: Icons.navigation,
                      title: isEn ? 'Navigator' : 'Navegador',
                      subtitle: _selectedNav,
                      onTap: () => _showOptionPicker(
                        isEn ? 'Navigator' : 'Navegador',
                        ['Google Maps', 'Waze', 'Apple Maps'],
                        _selectedNav,
                        (v) {
                          setState(() => _selectedNav = v);
                          _saveDriverPref('navigator', v);
                        },
                      ),
                    ),

                    // Appearance
                    _SettingsItem(
                      icon: Icons.dark_mode_outlined,
                      title: isEn ? 'Appearance' : 'Apariencia',
                      subtitle: prefsProvider.darkMode
                          ? (isEn ? 'Dark' : 'Oscuro')
                          : (isEn ? 'Light' : 'Claro'),
                      onTap: () {
                        final darkLabel = isEn ? 'Dark' : 'Oscuro';
                        final lightLabel = isEn ? 'Light' : 'Claro';
                        final current = prefsProvider.darkMode ? darkLabel : lightLabel;
                        _showOptionPicker(
                          isEn ? 'Appearance' : 'Apariencia',
                          [lightLabel, darkLabel],
                          current,
                          (v) {
                            prefsProvider.setDarkMode(v == darkLabel);
                          },
                        );
                      },
                    ),

                    // Distance units
                    _SettingsItem(
                      icon: Icons.straighten,
                      title: isEn ? 'Distance units' : 'Unidades de distancia',
                      subtitle: _getUnitsLabel(l10n),
                      onTap: () {
                        final kmLabel = isEn ? 'Kilometers' : 'Kilómetros';
                        final miLabel = isEn ? 'Miles' : 'Millas';
                        final current = _selectedUnits == 'mi' ? miLabel : kmLabel;
                        _showOptionPicker(
                          isEn ? 'Distance units' : 'Unidades de distancia',
                          [kmLabel, miLabel],
                          current,
                          (v) {
                            final code = v == miLabel ? 'mi' : 'km';
                            setState(() => _selectedUnits = code);
                            _saveDriverPref('distanceUnits', code);
                          },
                        );
                      },
                    ),

                    // Language
                    _SettingsItem(
                      icon: Icons.translate,
                      title: l10n.language,
                      subtitle: _getLanguageLabel(localeProvider),
                      onTap: () => _showOptionPicker(
                        l10n.language,
                        ['Español', 'English'],
                        _getLanguageLabel(localeProvider),
                        (v) {
                          final newLocale = v == 'English'
                              ? const Locale('en')
                              : const Locale('es');
                          localeProvider.setLocale(newLocale);
                          prefsProvider.setLanguage(newLocale.languageCode);
                        },
                      ),
                    ),
                    const Divider(height: 32),

                    // Legal documents
                    _SettingsItem(
                      icon: Icons.description_outlined,
                      title: isEn ? 'Legal documents' : 'Documentos legales',
                      onTap: () {
                        showResponsiveBottomSheet(
                          context: context,
                          builder: (ctx) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  isEn ? 'Legal documents' : 'Documentos legales',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context)),
                                ),
                              ),
                              ListTile(
                                leading: const Icon(Icons.article_outlined),
                                title: Text(l10n.termsAndConditions),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  launchUrl(Uri.parse('https://rapiteam.com/terminos'), mode: LaunchMode.externalApplication);
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.privacy_tip_outlined),
                                title: Text(l10n.privacyPolicy),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  launchUrl(Uri.parse('https://rapiteam.com/privacidad'), mode: LaunchMode.externalApplication);
                                },
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        );
                      },
                    ),

                    // App version
                    _SettingsItem(
                      icon: Icons.phone_android,
                      title: isEn ? 'App version' : 'Versión de la aplicación',
                      subtitle: '2.0.36',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(isEn ? 'You are using the latest version' : 'Estás usando la versión más reciente')),
                        );
                      },
                      showChevron: false,
                    ),
                    const Divider(height: 32),

                    // Logout
                    _SettingsItem(
                      icon: Icons.logout,
                      title: l10n.logout,
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(l10n.logoutConfirmation),
                            content: Text(isEn ? 'Are you sure you want to log out?' : '¿Estás seguro que deseas cerrar sesión?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
                              TextButton(
                                onPressed: () async {
                                  // capture-before-pop
                                  final rootNav = Navigator.of(context, rootNavigator: true);
                                  final authProvider = Provider.of<app.AuthProvider>(context, listen: false);
                                  Navigator.pop(ctx); // cierra dialog
                                  try {
                                    await authProvider.logout();
                                  } catch (_) {}
                                  rootNav.pushNamedAndRemoveUntil('/login', (route) => false);
                                },
                                child: Text(l10n.logout, style: const TextStyle(color: AppColors.rappiRed)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Delete account
                    _SettingsItem(
                      icon: Icons.delete_outline,
                      title: l10n.deleteAccount,
                      titleColor: AppColors.error,
                      onTap: () => _confirmDeleteAccount(context, isEn),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Doble confirmación + invocación de Cloud Function `deleteMyAccount`.
  /// Tras éxito hace logout local y vuelve al login.
  Future<void> _confirmDeleteAccount(BuildContext context, bool isEn) async {
    final l10n = AppLocalizations.of(context)!;
    // Dialog 1: explicar consecuencias
    final firstOk = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteAccountTitle),
        content: Text(l10n.deleteAccountConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isEn ? 'Continue' : 'Continuar',
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (firstOk != true || !context.mounted) return;

    // Dialog 2: requiere escribir "ELIMINAR" para confirmar
    final controller = TextEditingController();
    final keyword = isEn ? 'DELETE' : 'ELIMINAR';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (innerCtx, setLocalState) {
            final valid = controller.text.trim().toUpperCase() == keyword;
            return AlertDialog(
              title: Text(
                isEn ? 'Final confirmation' : 'Confirmación final',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEn
                        ? 'Type "$keyword" to permanently delete your account. This action cannot be undone.'
                        : 'Escribe "$keyword" para eliminar tu cuenta permanentemente. Esta acción no se puede deshacer.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: keyword,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setLocalState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: valid ? () => Navigator.pop(ctx, true) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isEn ? 'Delete' : 'Eliminar'),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true || !context.mounted) return;

    // Capture references before any await + pop
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    // Spinner mientras corre la callable
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await AccountDeletionService.deleteCurrentUserAccount();
      // El servicio de eliminación ya limpia la sesión del backend Node.
      if (!context.mounted) return;
      navigator.pop(); // cierra spinner
      navigator.pushNamedAndRemoveUntil('/login', (_) => false);
    } on AccountDeletionException catch (e) {
      if (!context.mounted) return;
      navigator.pop(); // cierra spinner
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isEn
                ? 'Failed to delete account: ${e.message}'
                : 'No se pudo eliminar la cuenta: ${e.message}',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(isEn ? 'Unexpected error' : 'Error inesperado'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? titleColor;
  final bool showChevron;

  const _SettingsItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.titleColor,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.getTextSecondary(context), size: 24),
      title: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: titleColor ?? AppColors.getTextPrimary(context))),
      subtitle: subtitle != null
          ? Text(subtitle!, style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context)))
          : null,
      trailing: showChevron ? Icon(Icons.chevron_right, color: AppColors.getTextSecondary(context)) : null,
      onTap: onTap,
    );
  }
}
