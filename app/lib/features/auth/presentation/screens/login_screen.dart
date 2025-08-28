import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:go_router/go_router.dart';
import '../../../../../shared/providers/riverpod_compat.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/oasis_button.dart';
import '../../../../core/widgets/oasis_text_field.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  
  Future<void> _handleLogin() async {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      setState(() => _isLoading = true);
      
      final values = _formKey.currentState!.value;
      final email = values['email'] as String;
      final password = values['password'] as String;
      
      try {
        await ref.read(authRepositoryProvider).signInWithEmail(
          email: email,
          password: password,
        );
        
        if (mounted) {
          context.go('/home');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              // backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }
  
  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            // backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: FormBuilder(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                
                // Logo y título
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.local_taxi_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                      )
                          .animate()
                          .scale(duration: 600.ms, curve: Curves.elasticOut),
                      
                      const SizedBox(height: 16),
                      
                      Text(
                        'Bienvenido',
                        style: Theme.of(context).textTheme.headlineLarge,
                      )
                          .animate()
                          .fadeIn(delay: 300.ms),
                      
                      const SizedBox(height: 8),
                      
                      Text(
                        'Inicia sesión para continuar',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textSecondaryColor,
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 400.ms),
                    ],
                  ),
                ),
                
                const SizedBox(height: 48),
                
                // Formulario
                OasisTextField(
                  name: 'email',
                  label: 'Correo electrónico',
                  hintText: 'correo@ejemplo.com',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  validators: [
                    FormBuilderValidators.required(
                      errorText: 'El correo es requerido',
                    ),
                    FormBuilderValidators.email(
                      errorText: 'Ingresa un correo válido',
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(delay: 500.ms)
                    .slideX(begin: -0.1),
                
                const SizedBox(height: 16),
                
                OasisTextField(
                  name: 'password',
                  label: 'Contraseña',
                  hintText: '••••••••',
                  obscureText: !_isPasswordVisible,
                  prefixIcon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppTheme.textSecondaryColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                  validators: [
                    FormBuilderValidators.required(
                      errorText: 'La contraseña es requerida',
                    ),
                    FormBuilderValidators.minLength(
                      6,
                      errorText: 'Mínimo 6 caracteres',
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(delay: 600.ms)
                    .slideX(begin: -0.1),
                
                const SizedBox(height: 12),
                
                // Olvidé mi contraseña
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/auth/forgot-password'),
                    child: const Text('¿Olvidaste tu contraseña?'),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 700.ms),
                
                const SizedBox(height: 24),
                
                // Botón de login
                OasisButton(
                  text: 'Iniciar Sesión',
                  onPressed: _isLoading ? () {} : _handleLogin,
                  isLoading: _isLoading,
                )
                    .animate()
                    .fadeIn(delay: 800.ms)
                    .scale(begin: Offset(0.9, 0.9), end: Offset(1, 1)),
                
                const SizedBox(height: 24),
                
                // Divider con "O"
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'O',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                )
                    .animate()
                    .fadeIn(delay: 900.ms),
                
                const SizedBox(height: 24),
                
                // Botón de Google
                OasisButton(
                  isOutlined: true,
                  text: 'Continuar con Google',
                  onPressed: _isLoading ? () {} : () => _handleGoogleLogin(),
                  icon: Image.asset(
                    'assets/icons/google.png',
                    width: 24,
                    height: 24,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 1000.ms)
                    .scale(begin: Offset(0.9, 0.9), end: Offset(1, 1)),
                
                const SizedBox(height: 32),
                
                // Link de registro
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '¿No tienes cuenta? ',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () => context.push('/auth/register'),
                      child: const Text('Regístrate'),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(delay: 1100.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}