import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../core/design/design_system.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../core/widgets/rt_animated_widgets.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../utils/firestore_error_handler.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late AnimationController _backgroundController;
  late AnimationController _formController;
  late AnimationController _iconController;

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();

    _backgroundController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();

    _formController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..forward();

    _iconController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _formController.dispose();
    _iconController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);

        final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (!mounted) return;

        if (credential.user != null) {
          // Cargar datos del usuario en el provider
          await authProvider.refreshUserData();

          final user = authProvider.currentUser;

          // Verificar que el usuario sea administrador
          if (user != null && user.userType == 'admin') {
            // Acceso directo al dashboard admin (sin 2FA)
            if (!mounted) return;
            Navigator.pushReplacementNamed(context, '/admin/dashboard');
          } else {
            // Usuario autenticado pero NO es admin
            await authProvider.logout();
            if (!mounted) return;
            RtSnackbar.show(context, message: 'Acceso denegado. Solo administradores pueden ingresar.', type: RtSnackbarType.error);
            setState(() => _isLoading = false);
          }
        } else {
          RtSnackbar.show(context, message: 'Credenciales inválidas', type: RtSnackbarType.error);
          setState(() => _isLoading = false);
        }
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        String errorMsg;
        switch (e.code) {
          case 'user-not-found':
            errorMsg = 'No existe una cuenta con este email';
            break;
          case 'wrong-password':
            errorMsg = 'Contraseña incorrecta';
            break;
          case 'invalid-email':
            errorMsg = 'Email inválido';
            break;
          case 'user-disabled':
            errorMsg = 'Cuenta deshabilitada';
            break;
          case 'too-many-requests':
            errorMsg = 'Demasiados intentos. Intenta más tarde';
            break;
          default:
            errorMsg = 'Error de autenticación: ${e.message}';
        }
        RtSnackbar.show(context, message: errorMsg, type: RtSnackbarType.error);
        setState(() => _isLoading = false);
      } catch (e) {
        if (!mounted) return;
        RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RtColors.neutral950,
      body: Stack(
        children: [
          // Fondo animado oscuro
          AnimatedBuilder(
            animation: _backgroundController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      RtColors.neutral950,
                      RtColors.neutral400,
                      RtColors.brand.withValues(alpha: 0.2),
                    ],
                    transform: GradientRotation(
                      _backgroundController.value * 2 * math.pi,
                    ),
                  ),
                ),
              );
            },
          ),

          // Patrón de seguridad
          ...List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _backgroundController,
              builder: (context, child) {
                final progress = (_backgroundController.value + index * 0.33) % 1;
                return Positioned(
                  left: MediaQuery.of(context).size.width * progress,
                  top: MediaQuery.of(context).size.height * 0.2 * (index + 1),
                  child: Transform.rotate(
                    angle: progress * 2 * math.pi,
                    child: Icon(
                      Icons.security,
                      size: 30,
                      color: RtColors.brand.withValues(alpha: 0.1),
                    ),
                  ),
                );
              },
            );
          }),

          // Contenido principal
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: AnimatedBuilder(
                  animation: _formController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _formController.value,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: RtColors.brand.withValues(alpha: 0.3),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: _buildLoginForm(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icono de admin con animación
          AnimatedBuilder(
            animation: _iconController,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      RtColors.brand,
                      RtColors.brand.withValues(alpha: 0.7),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: RtColors.brand.withValues(alpha: 0.5),
                      blurRadius: 20 + (_iconController.value * 10),
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.admin_panel_settings,
                  size: 50,
                  color: context.onPrimaryText,
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          Text(
            'ADMIN PANEL',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: context.primaryText,
              letterSpacing: 2,
            ),
          ),

          Text(
            'Acceso Restringido',
            style: TextStyle(
              color: context.secondaryText,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 32),

          // Campo de email
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: context.primaryText),
            decoration: InputDecoration(
              labelText: 'Correo Administrativo',
              prefixIcon: const Icon(Icons.email, color: RtColors.brand),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: RtColors.brand, width: 2),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa el correo administrativo';
              }
              if (!value.contains('@')) {
                return 'Correo inválido';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Campo de contraseña
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: TextStyle(color: context.primaryText),
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock, color: RtColors.brand),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  color: context.secondaryText,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: RtColors.brand, width: 2),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa la contraseña';
              }
              if (value.length < 6) {
                return 'Contraseña muy corta';
              }
              return null;
            },
          ),

          const SizedBox(height: 24),

          // Botón de login
          AnimatedPulseButton(
            text: 'ACCEDER AL PANEL',
            icon: Icons.security,
            isLoading: _isLoading,
            onPressed: _login,
            color: RtColors.brand,
          ),

          const SizedBox(height: 16),

          // Información de seguridad
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: RtColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: RtColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: RtColors.warning, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Este acceso es solo para administradores autorizados',
                    style: TextStyle(
                      fontSize: 12,
                      color: RtColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Volver al login normal
          TextButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
            child: Text(
              'Volver al Login Normal',
              style: TextStyle(color: context.secondaryText),
            ),
          ),
        ],
      ),
    );
  }
}
