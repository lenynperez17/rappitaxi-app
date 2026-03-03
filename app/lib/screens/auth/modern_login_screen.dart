import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/design/design_system.dart';
import '../../core/widgets/rt_button.dart';
import '../../core/widgets/rt_text_field.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../config/oauth_config.dart';
import '../../utils/logger.dart';
import '../../utils/firestore_error_handler.dart';
import 'phone_verification_screen.dart';

/// Pantalla de inicio de sesión de RapiTeam
///
/// Diseno limpio y simplificado con solo dos métodos de login:
/// - Google Sign-In
/// - Teléfono con verificación OTP
/// Sin toggle email/password, sin registro separado, sin contraseña.
class ModernLoginScreen extends StatefulWidget {
  const ModernLoginScreen({super.key});

  @override
  State<ModernLoginScreen> createState() => _ModernLoginScreenState();
}

class _ModernLoginScreenState extends State<ModernLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _phoneFocusNode = FocusNode();

  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  // ================================================================
  // LOGICA DE AUTENTICACION
  // ================================================================

  /// Oculta el teclado de forma confiable en Android
  void _hideKeyboard() {
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  /// Determina la ruta de navegación según el rol y estado del usuario
  String _resolveRouteForUser(dynamic user) {
    if (user.isAdmin) {
      AppLogger.critical('Usuario ADMIN -> /admin/dashboard');
      return '/admin/dashboard';
    }

    final mode = user.activeMode;

    if (mode == 'driver') {
      if (user.documentVerified) {
        AppLogger.critical('Conductor APROBADO -> /driver/home');
        return '/driver/home';
      }

      final driverStatus = user.driverStatus ?? 'pending_documents';
      if (driverStatus == 'pending_approval') {
        AppLogger.critical('Conductor ESPERANDO APROBACION -> /passenger/home');
        return '/passenger/home';
      }

      AppLogger.critical('Conductor NUEVO -> /upgrade-to-driver');
      return '/upgrade-to-driver';
    }

    AppLogger.critical('Usuario PASAJERO -> /passenger/home');
    return '/passenger/home';
  }

  /// Valida el teléfono peruano y navega a la pantalla de verificación OTP
  Future<void> _handlePhoneLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();

    if (!ValidationPatterns.isValidPeruMobile(phone)) {
      _showError(AppLocalizations.of(context)!.invalidPhoneDetails);
      return;
    }

    final operatorCode = phone.substring(0, 2);
    final validOperators = {
      '90', '91', '92', '93', '94', '95', '96', '97', '98', '99',
    };
    if (!validOperators.contains(operatorCode)) {
      _showError(AppLocalizations.of(context)!.operatorNotRecognized);
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhoneVerificationScreen(
          phoneNumber: phone,
          isRegistration: false,
        ),
      ),
    );
  }

  /// Login con Google: ejecuta el sign-in y navega según resultado
  Future<void> _loginWithGoogle() async {
    final l10n = AppLocalizations.of(context)!;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!OAuthConfig.isGoogleConfigured) {
      _showError(l10n.googleSignInNotConfigured);
      return;
    }

    try {
      setState(() => _isLoading = true);
      HapticFeedback.selectionClick();

      final success = await authProvider.signInWithGoogle();
      if (!mounted) return;

      if (success) {
        HapticFeedback.mediumImpact();

        if (authProvider.needsProfileCompletion()) {
          AppLogger.info('Perfil incompleto después de Google Sign-In');
          Navigator.pushReplacementNamed(
            context,
            '/auth/complete-profile',
            arguments: {'loginMethod': 'google'},
          );
          return;
        }

        final user = authProvider.currentUser!;
        final route = _resolveRouteForUser(user);
        Navigator.pushReplacementNamed(context, route);
      } else {
        _showError(authProvider.errorMessage ?? l10n.googleSignInError);
      }
    } catch (e) {
      if (!mounted) return;
      _showError(FirestoreErrorHandler.getSpanishMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    RtSnackbar.show(context, message: message, type: RtSnackbarType.error);
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RtColors.neutral50,
      body: GestureDetector(
        onTap: _hideKeyboard,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: RtSpacing.xl),
            child: Column(
              children: [
                const SizedBox(height: 56),

                // Logo
                _buildLogo(),
                const SizedBox(height: RtSpacing.xl),

                // Titulo de bienvenida
                Text(
                  'Bienvenido a RapiTeam',
                  style: RtTypo.displayMedium.copyWith(
                    color: RtColors.neutral900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: RtSpacing.xs),
                Text(
                  'Inicia sesión para continuar',
                  style: RtTypo.bodyMedium.copyWith(
                    color: RtColors.neutral500,
                  ),
                ),

                const SizedBox(height: RtSpacing.xxl),

                // Contenedor principal del formulario
                _buildFormCard(),

                const SizedBox(height: RtSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Hero(
      tag: 'app-logo',
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: RtColors.white,
            borderRadius: RtRadius.borderLg,
            boxShadow: RtShadow.soft(),
          ),
          padding: const EdgeInsets.all(RtSpacing.md),
          child: Image.asset(
            'assets/images/logo_rapiteam.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.local_taxi,
              size: 48,
              color: RtColors.brand,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(RtSpacing.xl),
      decoration: BoxDecoration(
        color: RtColors.white,
        borderRadius: RtRadius.borderXl,
        boxShadow: RtShadow.soft(),
      ),
      child: Column(
        children: [
          // Boton de Google
          _buildGoogleButton(),

          const SizedBox(height: RtSpacing.xl),

          // Separador "o"
          _buildDivider(l10n),

          const SizedBox(height: RtSpacing.xl),

          // Campo de teléfono con formulario
          Form(
            key: _formKey,
            child: Column(
              children: [
                _buildPhoneField(l10n),
                const SizedBox(height: RtSpacing.lg),

                // Boton enviar código
                RtButton(
                  label: 'Enviar código',
                  onPressed: _isLoading ? null : _handlePhoneLogin,
                  icon: Icons.sms_outlined,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Boton estilizado de Google con icono, fondo blanco, borde gris y texto negro
  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _loginWithGoogle,
        style: OutlinedButton.styleFrom(
          backgroundColor: RtColors.white,
          side: const BorderSide(color: RtColors.neutral300, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RtRadius.md),
          ),
          padding: const EdgeInsets.symmetric(horizontal: RtSpacing.lg),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: RtColors.neutral500,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icono de Google con colores oficiales
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.g_mobiledata,
                      size: 28,
                      color: Color(0xFFDB4437),
                    ),
                  ),
                  const SizedBox(width: RtSpacing.md),
                  Text(
                    'Continuar con Google',
                    style: RtTypo.titleSmall.copyWith(
                      color: RtColors.neutral800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDivider(AppLocalizations l10n) {
    return Row(
      children: [
        const Expanded(child: Divider(color: RtColors.neutral200)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RtSpacing.base),
          child: Text(
            'o',
            style: RtTypo.bodySmall.copyWith(color: RtColors.neutral400),
          ),
        ),
        const Expanded(child: Divider(color: RtColors.neutral200)),
      ],
    );
  }

  Widget _buildPhoneField(AppLocalizations l10n) {
    return RtTextField(
      controller: _phoneController,
      focusNode: _phoneFocusNode,
      label: l10n.phoneNumber,
      hint: l10n.phoneHint,
      prefixIcon: Icons.phone,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _handlePhoneLogin(),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(9),
      ],
      validator: (value) {
        if (value == null || value.isEmpty) {
          return l10n.enterPhoneNumber;
        }
        if (!ValidationPatterns.isValidPeruMobile(value)) {
          return l10n.invalidPhoneNumber;
        }
        if (value.length == 9) {
          final operatorCode = value.substring(0, 2);
          final validOperators = {
            '90', '91', '92', '93', '94', '95', '96', '97', '98', '99',
          };
          if (!validOperators.contains(operatorCode)) {
            return l10n.operatorNotValid;
          }
        }
        return null;
      },
    );
  }
}
