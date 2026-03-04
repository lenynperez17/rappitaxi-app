// ignore_for_file: use_build_context_synchronously, unused_import
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart';
import '../../widgets/animated/modern_animated_widgets.dart';
import '../../utils/logger.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart' as app_auth;

/// Pantalla de verificación de email
///
/// IMPORTANTE: Si el usuario inició con Google/Facebook, su email ya está
/// verificado por el proveedor. En ese caso, simplemente lo marcamos como verificado.
///
/// Solo usamos sendEmailVerification() cuando el usuario tiene email en Firebase Auth
/// pero NO está verificado (caso de registro con email/password).
class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String? loginProvider; // google, facebook, apple, email, phone

  const EmailVerificationScreen({
    super.key,
    required this.email,
    this.loginProvider,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isVerifying = false;
  bool _canResend = false;
  int _resendCountdown = 60;
  Timer? _timer;
  Timer? _verificationTimer;
  bool _isDisposed = false;

  // Estado de verificación
  bool _emailSentSuccessfully = false;
  bool _isProviderVerified = false; // Si el email viene de un proveedor OAuth
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVerification();
  }

  /// Inicializa el proceso de verificación según el contexto
  Future<void> _initializeVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _errorMessage = 'No hay usuario autenticado');
      return;
    }

    // Verificar si el email viene de un proveedor OAuth (Google, Facebook, Apple)
    final provider = widget.loginProvider?.toLowerCase() ?? '';
    final isOAuthProvider = provider == 'google' || provider == 'facebook' || provider == 'apple';

    AppLogger.debug('Verificación de email - Provider: $provider, isOAuth: $isOAuthProvider');
    AppLogger.debug('Email del widget: ${widget.email}');
    AppLogger.debug('Email en Firebase Auth: ${user.email}');
    AppLogger.debug('emailVerified en Firebase Auth: ${user.emailVerified}');

    // CASO 1: Email de proveedor OAuth (Google, Facebook, Apple)
    // Estos proveedores ya verificaron el email, podemos marcarlo como verificado
    if (isOAuthProvider && widget.email.isNotEmpty) {
      AppLogger.info('Email de proveedor OAuth - marcando como verificado automáticamente');
      await _markEmailAsVerifiedInFirestore();
      return;
    }

    // CASO 2: Usuario tiene email en Firebase Auth
    if (user.email != null && user.email!.isNotEmpty && user.email!.contains('@')) {
      // Si ya está verificado, marcar y salir
      if (user.emailVerified) {
        AppLogger.info('Email ya verificado en Firebase Auth');
        await _markEmailAsVerifiedInFirestore();
        return;
      }

      // Enviar email de verificación
      await _sendVerificationEmail();
      _startVerificationCheck();
      return;
    }

    // CASO 3: Usuario NO tiene email en Firebase Auth (login con teléfono)
    // En este caso, guardamos el email en Firestore pero no podemos verificarlo
    // con Firebase Auth. Marcamos como "pendiente" y el usuario podrá verificar después.
    AppLogger.warning('Usuario sin email en Firebase Auth - guardando en Firestore sin verificar');

    if (widget.email.isNotEmpty && widget.email.contains('@')) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'email': widget.email,
          'emailVerified': false, // Pendiente de verificación
          'updatedAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          _errorMessage = 'Tu email ha sido guardado. La verificación por enlace no está disponible '
              'para cuentas creadas con teléfono. Podrás verificarlo más tarde.';
        });

        // Después de 3 segundos, volver con éxito parcial
        await Future.delayed(const Duration(seconds: 3));
        if (mounted && !_isDisposed) {
          Navigator.of(context).pop(false); // false = no verificado pero guardado
        }
      } catch (e) {
        AppLogger.error('Error guardando email', e);
        setState(() => _errorMessage = 'Error guardando email: $e');
      }
    } else {
      setState(() => _errorMessage = 'Email inválido');
    }
  }

  /// Marca el email como verificado en Firestore y navega al home
  Future<void> _markEmailAsVerifiedInFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String userType = 'passenger'; // Default
    String driverStatus = 'pending_documents';
    bool documentVerified = false;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        userType = data['userType'] ?? 'passenger';
        driverStatus = data['driverStatus'] ?? 'pending_documents';
        documentVerified = data['documentVerified'] ?? false;

        await userDoc.reference.update({
          'email': widget.email,
          'emailVerified': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      AppLogger.info('Email marcado como verificado en Firestore: ${widget.email}');

      setState(() => _isProviderVerified = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email verificado correctamente. Bienvenido!'),
            backgroundColor: ModernTheme.rappiOrange,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted && !_isDisposed) {
        // Navegar según tipo de usuario
        String route;
        if (userType == 'driver') {
          // Conductor: verificar estado de documentos
          if (documentVerified && driverStatus == 'approved') {
            route = '/driver/home';
          } else if (driverStatus == 'pending_approval') {
            // Documentos enviados, esperando aprobación → usar como pasajero
            route = '/passenger/home';
          } else {
            // Conductor nuevo, debe subir documentos → UpgradeToDriverScreen
            route = '/upgrade-to-driver';
          }
        } else if (userType == 'admin') {
          // Only allow the designated admin email
          final currentEmail = FirebaseAuth.instance.currentUser?.email?.toLowerCase();
          if (currentEmail == UserModel.adminEmail) {
            route = '/admin/dashboard';
          } else {
            AppLogger.warning('User $currentEmail has admin userType but is not the authorized admin. Routing as passenger.');
            route = '/passenger/home';
          }
        } else {
          route = '/passenger/home';
        }

        // ✅ CRÍTICO: Refrescar datos del usuario en AuthProvider ANTES de navegar
        final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
        await authProvider.refreshUserData();
        AppLogger.info('✅ AuthProvider actualizado con datos del usuario (OAuth)');

        AppLogger.info('Navegando a $route después de verificación OAuth');
        Navigator.of(context).pushNamedAndRemoveUntil(route, (route) => false);
      }
    } catch (e) {
      AppLogger.error('Error marcando email como verificado', e);
      setState(() => _errorMessage = 'Error: $e');
    }
  }

  /// Envía email de verificación usando Firebase Auth
  Future<void> _sendVerificationEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await user.sendEmailVerification();
      AppLogger.info('Email de verificación enviado a: ${user.email}');

      setState(() {
        _emailSentSuccessfully = true;
        _errorMessage = null;
      });

      _startResendCountdown();
    } catch (e) {
      AppLogger.error('Error enviando email de verificación', e);
      String errorMsg = e.toString();

      if (errorMsg.contains('too-many-requests')) {
        // En caso de rate limit, mostrar mensaje amigable pero permitir continuar
        setState(() {
          _emailSentSuccessfully = true; // Permitir ver instrucciones
          _errorMessage = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Tu cuenta fue creada exitosamente.\n'
                'El email de verificación se enviará cuando Firebase lo permita.\n'
                'Puedes intentar reenviar en unos minutos.',
              ),
              backgroundColor: ModernTheme.warning,
              duration: Duration(seconds: 5),
            ),
          );
        }

        _startResendCountdown();
        return;
      } else if (errorMsg.contains('missing-email')) {
        errorMsg = 'No hay email asociado a esta cuenta.';
      }

      setState(() => _errorMessage = errorMsg);
      _startResendCountdown(); // Permitir reintentar después
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    _timer = null;
    _verificationTimer?.cancel();
    _verificationTimer = null;
    super.dispose();
  }

  void _startResendCountdown() {
    if (!mounted || _isDisposed) return;

    setState(() {
      _canResend = false;
      _resendCountdown = 60;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed || !mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  void _startVerificationCheck() {
    _verificationTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_isDisposed || !mounted) {
        timer.cancel();
        return;
      }
      await _checkEmailVerified();
    });
  }

  Future<void> _checkEmailVerified() async {
    if (!mounted || _isDisposed) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      AppLogger.warning('No hay usuario - sesión expirada');
      return;
    }

    try {
      await user.reload();
    } catch (e) {
      AppLogger.error('Error recargando usuario', e);
      return;
    }

    if (!mounted || _isDisposed) return;

    final updatedUser = FirebaseAuth.instance.currentUser;
    if (updatedUser?.emailVerified ?? false) {
      _verificationTimer?.cancel();
      _verificationTimer = null;

      // Actualizar Firestore y obtener datos del usuario
      String userType = 'passenger'; // Default
      String driverStatus = 'pending_documents';
      bool documentVerified = false;

      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(updatedUser!.uid)
            .get();

        if (userDoc.exists) {
          userType = userDoc.data()?['userType'] ?? 'passenger';
          driverStatus = userDoc.data()?['driverStatus'] ?? 'pending_documents';
          documentVerified = userDoc.data()?['documentVerified'] ?? false;

          await userDoc.reference.update({
            'emailVerified': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        AppLogger.info('emailVerified sincronizado con Firestore');
      } catch (e) {
        AppLogger.error('Error actualizando Firestore', e);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Email verificado exitosamente. Bienvenido!'),
          backgroundColor: ModernTheme.rappiOrange,
          duration: const Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted || _isDisposed) return;

      // Navegar según tipo de usuario
      String route;
      if (userType == 'driver') {
        // Conductor: verificar estado de documentos
        if (documentVerified && driverStatus == 'approved') {
          // Conductor ya aprobado, ir al home de conductor
          route = '/driver/home';
          AppLogger.info('Conductor aprobado → /driver/home');
        } else if (driverStatus == 'pending_approval') {
          // Documentos enviados, esperando aprobación → usar como pasajero
          route = '/passenger/home';
          AppLogger.info('Conductor pendiente de aprobación → /passenger/home');
          // Mostrar mensaje informativo
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tus documentos están en revisión. Puedes usar la app como pasajero mientras tanto.'),
                backgroundColor: ModernTheme.primaryBlue,
                duration: Duration(seconds: 4),
              ),
            );
          }
        } else {
          // Conductor nuevo, debe subir documentos → UpgradeToDriverScreen
          route = '/upgrade-to-driver';
          AppLogger.info('Conductor nuevo → /upgrade-to-driver para subir documentos');
        }
      } else if (userType == 'admin') {
        // Only allow the designated admin email
        final currentEmail = FirebaseAuth.instance.currentUser?.email?.toLowerCase();
        if (currentEmail == UserModel.adminEmail) {
          route = '/admin/dashboard';
        } else {
          AppLogger.warning('User $currentEmail has admin userType but is not the authorized admin. Routing as passenger.');
          route = '/passenger/home';
        }
      } else {
        route = '/passenger/home';
      }

      // ✅ CRÍTICO: Refrescar datos del usuario en AuthProvider ANTES de navegar
      // Esto asegura que _currentUser tenga los datos correctos (userType, driverStatus, etc.)
      final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
      await authProvider.refreshUserData();
      AppLogger.info('✅ AuthProvider actualizado con datos del usuario');

      AppLogger.info('Navegando a $route después de verificación de email');
      Navigator.of(context).pushNamedAndRemoveUntil(route, (route) => false);
    }
  }

  Future<void> _resendVerificationEmail() async {
    setState(() => _isVerifying = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Sesión expirada. Vuelve a iniciar sesión.'),
              backgroundColor: ModernTheme.error,
              action: SnackBarAction(
                label: 'Volver',
                textColor: Colors.white,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
          );
        }
        return;
      }

      if (user.email != null && user.email!.isNotEmpty) {
        await user.sendEmailVerification();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Email enviado a ${user.email}'),
              backgroundColor: ModernTheme.rappiOrange,
            ),
          );
        }
        _startResendCountdown();
      } else {
        throw Exception('No hay email en Firebase Auth');
      }
    } catch (e) {
      AppLogger.error('Error reenviando email', e);
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.contains('too-many-requests')) {
          errorMsg = 'Demasiados intentos. Espera unos minutos.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMsg'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  void _goBack() {
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    // Si es proveedor OAuth, mostrar pantalla de exito con Card
    if (_isProviderVerified) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Center(
          child: Card(
            elevation: 4,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_user,
                      size: 72,
                      color: ModernTheme.rappiOrange,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Email verificado',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tu cuenta ha sido verificada correctamente.',
                    style: TextStyle(
                      color: ModernTheme.textSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Card flotante con borderRadius 24, elevation 4
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Icono de verificacion grande arriba
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: _errorMessage != null
                                ? Colors.orange.withValues(alpha: 0.1)
                                : ModernTheme.rappiOrange.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _errorMessage != null
                                ? Icons.warning_amber_rounded
                                : Icons.verified_user,
                            size: 72,
                            color: _errorMessage != null
                                ? Colors.orange
                                : ModernTheme.rappiOrange,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Titulo centrado
                        Text(
                          _errorMessage != null ? 'Atención' : 'Verifica tu email',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 16),

                        // Contenido centrado
                        if (_errorMessage != null) ...[
                          Text(
                            _errorMessage!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange.shade800,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ] else if (_emailSentSuccessfully) ...[
                          Text(
                            'Hemos enviado un correo de verificación a:',
                            style: TextStyle(
                              fontSize: 15,
                              color: ModernTheme.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.email,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: ModernTheme.rappiOrange,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 16),
                          const Text(
                            '1. Revisa tu bandeja de entrada\n'
                            '2. Haz clic en el enlace de verificación\n'
                            '3. Vuelve a esta pantalla',
                            style: TextStyle(
                              fontSize: 14,
                              color: ModernTheme.textSecondary,
                              height: 1.7,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ] else ...[
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(ModernTheme.rappiOrange),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Procesando...',
                            style: TextStyle(color: ModernTheme.textSecondary),
                          ),
                        ],

                        const SizedBox(height: 28),

                        // Botones centrados dentro de la card
                        if (_emailSentSuccessfully) ...[
                          SizedBox(
                            width: double.infinity,
                            child: AnimatedPulseButton(
                              text: _canResend
                                  ? 'Reenviar email'
                                  : 'Espera $_resendCountdown segundos',
                              icon: Icons.refresh,
                              isLoading: _isVerifying,
                              onPressed: _canResend ? _resendVerificationEmail : () {},
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _goBack,
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Volver'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: ModernTheme.rappiOrange, width: 1.5),
                              foregroundColor: ModernTheme.rappiOrange,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),

                        if (_emailSentSuccessfully) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: ModernTheme.warning.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: ModernTheme.warning.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: ModernTheme.warning,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '¿No ves el email? Revisa tu carpeta de spam',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: ModernTheme.warning,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
