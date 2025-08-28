import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool _acceptTerms = false;
  
  Future<void> _handleRegister() async {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      if (!_acceptTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes aceptar los términos y condiciones'),
            // backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
      
      setState(() => _isLoading = true);
      
      final values = _formKey.currentState!.value;
      final name = values['name'] as String;
      final email = values['email'] as String;
      final phone = values['phone'] as String;
      final password = values['password'] as String;
      
      try {
        await ref.read(authRepositoryProvider).signUpWithEmail(
          email: email,
          password: password,
          name: name,
          phone: phone,
        );
        
        if (mounted) {
          // Ir a verificación de teléfono
          context.go('/auth/otp-verification', extra: phone);
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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.white,
      appBar: AppBar(
        // backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: FormBuilder(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Título
                Text(
                  'Crear cuenta',
                  style: Theme.of(context).textTheme.headlineLarge,
                )
                    .animate()
                    .fadeIn(),
                
                const SizedBox(height: 8),
                
                Text(
                  'Completa tus datos para registrarte',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 100.ms),
                
                const SizedBox(height: 32),
                
                // Formulario
                OasisTextField(
                  name: 'name',
                  label: 'Nombre completo',
                  hintText: 'Juan Pérez',
                  prefixIcon: Icons.person_outline,
                  textCapitalization: TextCapitalization.words,
                  validators: [
                    FormBuilderValidators.required(
                      errorText: 'El nombre es requerido',
                    ),
                    FormBuilderValidators.match(
                      AppConstants.nameRegex.pattern,
                      errorText: 'Ingresa un nombre válido',
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(delay: 200.ms)
                    .slideX(begin: -0.1),
                
                const SizedBox(height: 16),
                
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
                    .fadeIn(delay: 300.ms)
                    .slideX(begin: -0.1),
                
                const SizedBox(height: 16),
                
                OasisTextField(
                  name: 'phone',
                  label: 'Número de teléfono',
                  hintText: '999 999 999',
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_outlined,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                  ],
                  validators: [
                    FormBuilderValidators.required(
                      errorText: 'El teléfono es requerido',
                    ),
                    FormBuilderValidators.match(
                      r'^\d{9}$',
                      errorText: 'Ingresa un número válido de 9 dígitos',
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(delay: 400.ms)
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
                    .fadeIn(delay: 500.ms)
                    .slideX(begin: -0.1),
                
                const SizedBox(height: 16),
                
                OasisTextField(
                  name: 'confirmPassword',
                  label: 'Confirmar contraseña',
                  hintText: '••••••••',
                  obscureText: !_isConfirmPasswordVisible,
                  prefixIcon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isConfirmPasswordVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppTheme.textSecondaryColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                      });
                    },
                  ),
                  validators: [
                    FormBuilderValidators.required(
                      errorText: 'Confirma tu contraseña',
                    ),
                    (value) {
                      if (value != _formKey.currentState?.fields['password']?.value) {
                        return 'Las contraseñas no coinciden';
                      }
                      return null;
                    },
                  ],
                )
                    .animate()
                    .fadeIn(delay: 600.ms)
                    .slideX(begin: -0.1),
                
                const SizedBox(height: 24),
                
                // Términos y condiciones
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _acceptTerms,
                        onChanged: (value) {
                          setState(() {
                            _acceptTerms = value ?? false;
                          });
                        },
                        activeColor: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _acceptTerms = !_acceptTerms;
                          });
                        },
                        child: RichText(
                          text: TextSpan(
                            style: Theme.of(context).textTheme.bodySmall,
                            children: [
                              const TextSpan(text: 'Acepto los '),
                              TextSpan(
                                text: 'términos y condiciones',
                                style: TextStyle(
                                  color: AppTheme.primaryColor,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const TextSpan(text: ' y la '),
                              TextSpan(
                                text: 'política de privacidad',
                                style: TextStyle(
                                  color: AppTheme.primaryColor,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(delay: 700.ms),
                
                const SizedBox(height: 32),
                
                // Botón de registro
                OasisButton(
                  text: 'Crear cuenta',
                  onPressed: _isLoading ? () {} : _handleRegister,
                  isLoading: _isLoading,
                )
                    .animate()
                    .fadeIn(delay: 800.ms)
                    .scale(begin: Offset(0.9, 0.9), end: Offset(1, 1)),
                
                const SizedBox(height: 24),
                
                // Link de login
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '¿Ya tienes cuenta? ',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Inicia sesión'),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(delay: 900.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}