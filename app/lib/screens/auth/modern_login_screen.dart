// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api, unused_import
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:email_validator/email_validator.dart';
import '../../generated/l10n/app_localizations.dart'; // ✅ NUEVO: Import de localizaciones
import '../../core/theme/modern_theme.dart';
import '../../widgets/animated/modern_animated_widgets.dart';
import '../../providers/auth_provider.dart';
import '../../config/oauth_config.dart'; // Para validación estricta
import 'phone_verification_screen.dart';
import '../../utils/logger.dart'; // ✅ CRÍTICO: Import de AppLogger

class ModernLoginScreen extends StatefulWidget {
  const ModernLoginScreen({super.key});

  @override
  _ModernLoginScreenState createState() => _ModernLoginScreenState();
}

class _ModernLoginScreenState extends State<ModernLoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // ✅ FocusNodes para manejo de teclado y navegación entre campos
  final _phoneFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  late AnimationController _backgroundController;
  late AnimationController _formController;
  late AnimationController _logoController;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _formAnimation;
  late Animation<double> _logoAnimation;
  late Animation<double> _floatAnimation;
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _usePhoneLogin = true; // Toggle entre teléfono y email
  int _failedAttempts = 0;
  DateTime? _lastFailedAttempt;

  @override
  void initState() {
    super.initState();
    
    
    _backgroundController = AnimationController(
      duration: Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    _formController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _logoController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _backgroundAnimation = CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.linear,
    );
    
    _formAnimation = CurvedAnimation(
      parent: _formController,
      curve: Curves.elasticOut,
    );
    
    _logoAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.bounceOut,
    );
    
    _floatAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeInOut,
    ));
    
    _formController.forward();
    _logoController.forward();
    _logoController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _formController.dispose();
    _logoController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    // ✅ Dispose de FocusNodes
    _phoneFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  // ✅ Método helper para ocultar teclado de manera confiable en Android
  void _hideKeyboard() {
    FocusScope.of(context).unfocus(); // Quita el foco
    SystemChannels.textInput.invokeMethod('TextInput.hide'); // Fuerza el ocultamiento en Android
  }

  Future<void> _login() async {
    AppLogger.critical('🚀🚀🚀 _login INICIADO');
    AppLogger.critical('📧 Usando login por: ${_usePhoneLogin ? "TELÉFONO" : "EMAIL"}');

    if (_formKey.currentState!.validate()) {
      AppLogger.critical('✅ Validación de formulario OK');

      // Verificar intentos fallidos (rate limiting) - REDUCIDO A 5 MINUTOS
      if (_failedAttempts >= 5 && _lastFailedAttempt != null) {
        AppLogger.warning('⚠️ Verificando rate limiting... intentos fallidos: $_failedAttempts');
        final timeSinceLastAttempt = DateTime.now().difference(_lastFailedAttempt!);
        if (timeSinceLastAttempt.inMinutes < 5) {
          final remainingTime = 5 - timeSinceLastAttempt.inMinutes;
          AppLogger.error('❌ BLOQUEADO por rate limiting. Tiempo restante: $remainingTime minutos');
          _showErrorMessage(
            AppLocalizations.of(context)!.tooManyAttempts(remainingTime),
          );
          return;
        } else {
          AppLogger.info('✅ Rate limiting expirado, reseteando intentos');
          _failedAttempts = 0; // Reset después de 5 minutos
          _lastFailedAttempt = null;
        }
      }

      AppLogger.critical('🔄 Iniciando proceso de autenticación...');
      setState(() => _isLoading = true);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      try {
        bool success = false;

        if (_usePhoneLogin) {
          // Login con teléfono - VALIDACIÓN ESTRICTA OBLIGATORIA
          final phone = _phoneController.text.trim();
          
          // CRÍTICO: Usar validación centralizada y estricta
          if (!ValidationPatterns.isValidPeruMobile(phone)) {
            _showErrorMessage(
              AppLocalizations.of(context)!.invalidPhoneDetails
            );
            setState(() => _isLoading = false);
            return;
          }
          
          // Verificación adicional de operador móvil
          final operatorCode = phone.substring(0, 2);
          final validOperators = {'90', '91', '92', '93', '94', '95', '96', '97', '98', '99'};
          if (!validOperators.contains(operatorCode)) {
            _showErrorMessage(AppLocalizations.of(context)!.operatorNotRecognized);
            setState(() => _isLoading = false);
            return;
          }
          
          // Navegar a pantalla de verificación OTP
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PhoneVerificationScreen(
                phoneNumber: phone,
                isRegistration: false,
              ),
            ),
          );
          setState(() => _isLoading = false);
          return;
        } else {
          // Login con email
          final email = _emailController.text.trim();
          AppLogger.critical('📧 Intentando login con email: $email');

          // Validar email profesional
          if (!EmailValidator.validate(email)) {
            AppLogger.error('❌ Email inválido');
            _showErrorMessage(AppLocalizations.of(context)!.email);
            setState(() => _isLoading = false);
            return;
          }

          AppLogger.critical('📧 Email válido, llamando a authProvider.login...');
          success = await authProvider.login(email, _passwordController.text);
          AppLogger.critical('📧 authProvider.login retornó: $success');
        }

        if (!mounted) return;

        if (success) {
          AppLogger.critical('🎉🎉🎉 LOGIN EXITOSO!');

          // Reset intentos fallidos
          _failedAttempts = 0;
          _lastFailedAttempt = null;

          // Vibración de éxito
          HapticFeedback.mediumImpact();

          // Verificar si el email está verificado
          if (!authProvider.emailVerified && !_usePhoneLogin) {
            AppLogger.warning('⚠️ Email NO verificado, navegando a verificación');

            // Mostrar mensaje informativo
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Tu email no está verificado. Te llevaremos a verificarlo.'),
                backgroundColor: ModernTheme.warning,
                duration: Duration(seconds: 2),
              ),
            );

            setState(() => _isLoading = false);

            // Navegar a la pantalla de verificación de email
            Navigator.pushNamed(
              context,
              '/email-verification',
              arguments: _emailController.text.trim(),
            );
            return;
          }

          AppLogger.critical('✅ Email verificado o login con teléfono');

          // ✅ FIX: Navegar según el currentMode/activeMode REAL del usuario autenticado
          // NO usar el toggle _userType del UI - ese solo es para el formulario
          final user = authProvider.currentUser!;
          AppLogger.critical('👤 Usuario actual: ${user.email.isNotEmpty ? user.email : user.phone}');
          AppLogger.critical('👤 isAdmin: ${user.isAdmin}');
          AppLogger.critical('👤 userType: ${user.userType}');
          AppLogger.critical('👤 activeMode: ${user.activeMode}');

          String route;

          if (user.isAdmin) {
            // Admin siempre va al dashboard
            route = '/admin/dashboard';
            AppLogger.critical('🔐 Usuario ADMIN → Navegando a: $route');
          } else {
            // Usuario dual o single: usar activeMode (currentMode si existe, sino userType)
            final mode = user.activeMode; // Usa currentMode si existe, sino userType
            AppLogger.critical('🎭 Modo activo determinado: $mode');

            if (mode == 'driver') {
              // Verificar si el conductor tiene documentos aprobados
              if (user.documentVerified) {
                route = '/driver/home';
                AppLogger.critical('🚗 Conductor APROBADO → Navegando a: $route');
              } else {
                // Conductor sin documentos aprobados
                final driverStatus = user.driverStatus ?? 'pending_documents';

                if (driverStatus == 'pending_approval') {
                  // Ya envió documentos, puede usar como pasajero mientras espera
                  route = '/passenger/home';
                  AppLogger.critical('🚗 Conductor ESPERANDO APROBACIÓN → Navegando a: $route');
                } else {
                  // Conductor nuevo, debe subir documentos
                  route = '/upgrade-to-driver';
                  AppLogger.critical('🚗 Conductor NUEVO → Navegando a: $route');
                }
              }
            } else {
              // Default: modo pasajero (passenger o cualquier otro)
              route = '/passenger/home';
              AppLogger.critical('🚶 Usuario PASAJERO → Navegando a: $route');
            }
          }

          AppLogger.critical('🧭 NAVEGANDO A: $route');
          Navigator.pushReplacementNamed(context, route);
          AppLogger.critical('✅ Navigator.pushReplacementNamed EJECUTADO');
        } else {
          AppLogger.error('❌ Login FALLIDO');
          AppLogger.error('❌ Error: ${authProvider.errorMessage}');
          // Incrementar intentos fallidos
          _failedAttempts++;
          _lastFailedAttempt = DateTime.now();
          
          // Vibración de error
          HapticFeedback.heavyImpact();
          
          // Mostrar mensaje de error específico
          final errorMsg = authProvider.errorMessage ?? AppLocalizations.of(context)!.loginError;
          _showErrorMessage(errorMsg);

          // Si la cuenta está bloqueada
          if (authProvider.isAccountLocked) {
            _showErrorMessage(
              AppLocalizations.of(context)!.accountLocked,
            );
          }
        }
      } catch (e, stackTrace) {
        if (!mounted) return;
        AppLogger.error('🔴🔴🔴 LOGIN SCREEN CATCH: $e');
        AppLogger.error('🔴 Stack: $stackTrace');
        _showErrorMessage('DEBUG ERROR: $e');
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }
  
  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onError),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: ModernTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: Duration(seconds: 4),
      ),
    );
  }

  Future<void> _loginWithGoogle() async {
    // VERIFICACIÓN DE CONFIGURACIÓN OAUTH
    if (!OAuthConfig.isGoogleConfigured) {
      _showErrorMessage(
        AppLocalizations.of(context)!.googleSignInNotConfigured
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      setState(() => _isLoading = true);
      HapticFeedback.selectionClick();

      final success = await authProvider.signInWithGoogle();

      if (!mounted) return;

      if (success) {
        HapticFeedback.mediumImpact();

        // ✅ NUEVO: Verificar si necesita completar perfil
        if (authProvider.needsProfileCompletion()) {
          AppLogger.info('Usuario necesita completar perfil después de Google Sign-In');
          Navigator.pushReplacementNamed(
            context,
            '/auth/complete-profile',
            arguments: {'loginMethod': 'google'},
          );
          return;
        }

        // ✅ FIX: Navegar según el currentMode REAL del usuario autenticado
        final user = authProvider.currentUser!;
        String route;

        if (user.isAdmin) {
          route = '/admin/dashboard';
        } else {
          final mode = user.activeMode;
          if (mode == 'driver') {
            // Verificar si el conductor tiene documentos aprobados
            if (user.documentVerified) {
              route = '/driver/home';
              AppLogger.critical('🚗 [Google] Conductor APROBADO → Navegando a: $route');
            } else {
              final driverStatus = user.driverStatus ?? 'pending_documents';
              if (driverStatus == 'pending_approval') {
                route = '/passenger/home';
                AppLogger.critical('🚗 [Google] Conductor ESPERANDO → Navegando a: $route');
              } else {
                route = '/upgrade-to-driver';
                AppLogger.critical('🚗 [Google] Conductor NUEVO → Navegando a: $route');
              }
            }
          } else {
            route = '/passenger/home';
          }
        }

        Navigator.pushReplacementNamed(context, route);
      } else {
        _showErrorMessage(
          authProvider.errorMessage ??
          AppLocalizations.of(context)!.googleSignInError
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage(AppLocalizations.of(context)!.unexpectedError('Google Sign-In: $e'));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginWithApple() async {
    // VERIFICACIÓN DE CONFIGURACIÓN OAUTH
    if (!OAuthConfig.isAppleConfigured) {
      _showErrorMessage(
        AppLocalizations.of(context)!.appleSignInNotConfigured
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      setState(() => _isLoading = true);
      HapticFeedback.selectionClick();

      final success = await authProvider.signInWithApple();

      if (!mounted) return;

      if (success) {
        HapticFeedback.mediumImpact();

        // ✅ NUEVO: Verificar si necesita completar perfil
        if (authProvider.needsProfileCompletion()) {
          AppLogger.info('Usuario necesita completar perfil después de Apple Sign-In');
          Navigator.pushReplacementNamed(
            context,
            '/auth/complete-profile',
            arguments: {'loginMethod': 'apple'},
          );
          return;
        }

        // ✅ FIX: Navegar según el currentMode REAL del usuario autenticado
        final user = authProvider.currentUser!;
        String route;

        if (user.isAdmin) {
          route = '/admin/dashboard';
        } else {
          final mode = user.activeMode;
          if (mode == 'driver') {
            // Verificar si el conductor tiene documentos aprobados
            if (user.documentVerified) {
              route = '/driver/home';
              AppLogger.critical('🚗 [Apple] Conductor APROBADO → Navegando a: $route');
            } else {
              final driverStatus = user.driverStatus ?? 'pending_documents';
              if (driverStatus == 'pending_approval') {
                route = '/passenger/home';
                AppLogger.critical('🚗 [Apple] Conductor ESPERANDO → Navegando a: $route');
              } else {
                route = '/upgrade-to-driver';
                AppLogger.critical('🚗 [Apple] Conductor NUEVO → Navegando a: $route');
              }
            }
          } else {
            route = '/passenger/home';
          }
        }

        Navigator.pushReplacementNamed(context, route);
      } else {
        _showErrorMessage(
          authProvider.errorMessage ??
          AppLocalizations.of(context)!.appleSignInError
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage(AppLocalizations.of(context)!.unexpectedError('Apple: $e'));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false, // Manejar teclado manualmente con scroll padding
      body: GestureDetector(
        onTap: _hideKeyboard,
        child: Stack(
          children: [
            // Fondo blanco limpio - solo el area superior con color naranja suave
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: screenHeight * 0.40,
              child: Container(
                color: Colors.white,
              ),
            ),

            // Logo centrado en la parte superior (1/3 de la pantalla)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: screenHeight * 0.35,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo animado con scale
                  AnimatedBuilder(
                    animation: _logoAnimation,
                    builder: (context, child) {
                      return ScaleTransition(
                        scale: _logoAnimation,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: ModernTheme.rappiOrange.withValues(alpha: 0.25),
                                blurRadius: 30,
                                spreadRadius: 4,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Image.asset(
                            'assets/images/logo_rappi_taxi.png',
                            width: 88,
                            height: 88,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.local_taxi,
                                size: 60,
                                color: ModernTheme.rappiOrange,
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'RAPPI TEAM',
                    style: TextStyle(
                      color: ModernTheme.rappiOrange,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context)!.tagline,
                    style: TextStyle(
                      color: ModernTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Panel inferior estilo bottom sheet con borderRadius en la parte superior
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              top: screenHeight * 0.35,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 24,
                      spreadRadius: 0,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
                  child: Column(
                    children: [
                    // Formulario directo sin container extra (el panel blanco ya es el contenedor)
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                                  // Toggle entre teléfono y email
                                  Container(
                                    decoration: BoxDecoration(
                                      color: ModernTheme.backgroundLight,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => setState(() => _usePhoneLogin = true),
                                            child: AnimatedContainer(
                                              duration: Duration(milliseconds: 200),
                                              padding: EdgeInsets.symmetric(vertical: 12),
                                              decoration: BoxDecoration(
                                                color: _usePhoneLogin
                                                  ? ModernTheme.rappiOrange
                                                  : Colors.transparent,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.phone_android,
                                                    color: _usePhoneLogin
                                                      ? Theme.of(context).colorScheme.onPrimary
                                                      : ModernTheme.textSecondary,
                                                    size: 16,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Flexible(
                                                    child: Text(
                                                      AppLocalizations.of(context)!.phone,
                                                      style: TextStyle(
                                                        color: _usePhoneLogin
                                                          ? Theme.of(context).colorScheme.onPrimary
                                                          : ModernTheme.textSecondary,
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 12,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => setState(() => _usePhoneLogin = false),
                                            child: AnimatedContainer(
                                              duration: Duration(milliseconds: 200),
                                              padding: EdgeInsets.symmetric(vertical: 12),
                                              decoration: BoxDecoration(
                                                color: !_usePhoneLogin
                                                  ? ModernTheme.rappiOrange
                                                  : Colors.transparent,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.email,
                                                    color: !_usePhoneLogin
                                                      ? Theme.of(context).colorScheme.onPrimary
                                                      : ModernTheme.textSecondary,
                                                    size: 16,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Flexible(
                                                    child: Text(
                                                      AppLocalizations.of(context)!.email,
                                                      style: TextStyle(
                                                        color: !_usePhoneLogin
                                                          ? Theme.of(context).colorScheme.onPrimary
                                                          : ModernTheme.textSecondary,
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 12,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  SizedBox(height: 24),
                                  
                                  // Campo de teléfono o email según selección
                                  if (_usePhoneLogin)
                                    TextFormField(
                                      controller: _phoneController,
                                      focusNode: _phoneFocusNode, // ✅ FocusNode configurado
                                      keyboardType: TextInputType.phone,
                                      textInputAction: TextInputAction.done, // ✅ Botón Done en teclado
                                      onFieldSubmitted: (_) => _login(), // ✅ Ejecuta login al presionar Done
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(9),
                                      ],
                                      decoration: InputDecoration(
                                        labelText: AppLocalizations.of(context)!.phoneNumber,
                                        hintText: AppLocalizations.of(context)!.phoneHint,
                                        prefixIcon: Icon(Icons.phone, color: ModernTheme.primaryOrange),
                                        prefixText: '+51 ',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(color: ModernTheme.rappiOrange, width: 2),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(color: ModernTheme.error, width: 1),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return AppLocalizations.of(context)!.enterPhoneNumber;
                                        }

                                        // VALIDACIÓN ESTRICTA OBLIGATORIA
                                        if (!ValidationPatterns.isValidPeruMobile(value)) {
                                          return AppLocalizations.of(context)!.invalidPhoneNumber;
                                        }

                                        // Verificar operador móvil válido
                                        if (value.length == 9) {
                                          final operatorCode = value.substring(0, 2);
                                          final validOperators = {'90', '91', '92', '93', '94', '95', '96', '97', '98', '99'};
                                          if (!validOperators.contains(operatorCode)) {
                                            return AppLocalizations.of(context)!.operatorNotValid;
                                          }
                                        }

                                        return null;
                                      },
                                    )
                                  else
                                    TextFormField(
                                      controller: _emailController,
                                      focusNode: _emailFocusNode, // ✅ FocusNode configurado
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next, // ✅ Botón Next para ir a contraseña
                                      onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(), // ✅ Avanza al campo de contraseña
                                      autocorrect: false,
                                      decoration: InputDecoration(
                                        labelText: AppLocalizations.of(context)!.email,
                                        hintText: 'correo@ejemplo.com',
                                        prefixIcon: Icon(Icons.email, color: ModernTheme.primaryOrange),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(color: ModernTheme.rappiOrange, width: 2),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(color: ModernTheme.error, width: 1),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return AppLocalizations.of(context)!.email;
                                        }
                                        if (!EmailValidator.validate(value)) {
                                          return AppLocalizations.of(context)!.email;
                                        }
                                        return null;
                                      },
                                    ),
                                  
                                  SizedBox(height: 16),
                                  
                                  // Campo de contraseña (solo para login con email)
                                  if (!_usePhoneLogin)
                                    TextFormField(
                                      controller: _passwordController,
                                      focusNode: _passwordFocusNode, // ✅ FocusNode configurado
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.done, // ✅ Botón Done en teclado
                                      onFieldSubmitted: (_) => _login(), // ✅ Ejecuta login al presionar Done
                                      decoration: InputDecoration(
                                        labelText: AppLocalizations.of(context)!.password,
                                        hintText: AppLocalizations.of(context)!.passwordHint,
                                        prefixIcon: Icon(Icons.lock, color: ModernTheme.primaryOrange),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                            color: ModernTheme.textSecondary,
                                          ),
                                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(color: ModernTheme.rappiOrange, width: 2),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(color: ModernTheme.error, width: 1),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (!_usePhoneLogin) {
                                          if (value == null || value.isEmpty) {
                                            return AppLocalizations.of(context)!.enterPassword;
                                          }
                                          if (value.length < 8) {
                                            return AppLocalizations.of(context)!.passwordMinLength;
                                          }
                                        }
                                        return null;
                                      },
                                    ),
                                  
                                  SizedBox(height: 12),
                                  
                                  // Olvidé mi contraseña
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () {
                                        Navigator.pushNamed(context, '/forgot-password');
                                      },
                                      child: Text(
                                        AppLocalizations.of(context)!.forgotPassword,
                                        style: TextStyle(
                                          color: ModernTheme.rappiBlack,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 24),

                                  // Boton de inicio de sesion: ancho completo, borderRadius 16, altura 56
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _login,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: ModernTheme.rappiOrange,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2.5,
                                              ),
                                            )
                                          : Text(
                                              AppLocalizations.of(context)!.signIn,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  // Divider "o" entre social y formulario
                                  Row(
                                    children: [
                                      const Expanded(child: Divider()),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: Text(
                                          AppLocalizations.of(context)!.orContinueWith,
                                          style: TextStyle(color: ModernTheme.textSecondary, fontSize: 13),
                                        ),
                                      ),
                                      const Expanded(child: Divider()),
                                    ],
                                  ),
                                  
                                  SizedBox(height: 20),
                                  
                                  // Botones de redes sociales en fila horizontal con iconos circulares
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildSocialButton(
                                        icon: Icons.g_mobiledata,
                                        color: const Color(0xFFDB4437),
                                        onPressed: _loginWithGoogle,
                                      ),
                                      const SizedBox(width: 20),
                                      _buildSocialButton(
                                        icon: Icons.apple,
                                        color: Colors.black,
                                        onPressed: _loginWithApple,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ), // Positioned panel inferior
          ],
        ),
      ),
    );
  }

  // Botones de login social circulares
  Widget _buildSocialButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(32),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }
}