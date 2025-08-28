import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/oasis_button.dart';
import '../../../../core/widgets/oasis_text_field.dart';
import '../providers/auth_provider.dart';
import '../../../../shared/providers/riverpod_compat.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _isLoading = false;
  bool _emailSent = false;
  
  Future<void> _handleResetPassword() async {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      setState(() => _isLoading = true);
      
      final email = _formKey.currentState!.value['email'] as String;
      
      try {
        await ref.read(authRepositoryProvider).resetPassword(email);
        
        setState(() {
          _emailSent = true;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Correo de recuperación enviado'),
              // backgroundColor: AppTheme.successColor,
            ),
          );
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icono
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_reset_rounded,
                  size: 48,
                  color: AppTheme.primaryColor,
                ),
              )
                  .animate()
                  .scale(duration: 600.ms, curve: Curves.elasticOut),
              
              const SizedBox(height: 32),
              
              // Título
              Text(
                _emailSent ? '¡Correo enviado!' : 'Recuperar contraseña',
                style: Theme.of(context).textTheme.headlineLarge,
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(delay: 300.ms),
              
              const SizedBox(height: 16),
              
              Text(
                _emailSent
                    ? 'Revisa tu bandeja de entrada y sigue las instrucciones para restablecer tu contraseña.'
                    : 'Ingresa tu correo electrónico y te enviaremos instrucciones para restablecer tu contraseña.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondaryColor,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(delay: 400.ms),
              
              const SizedBox(height: 48),
              
              if (!_emailSent) ...[
                // Formulario
                FormBuilder(
                  key: _formKey,
                  child: OasisTextField(
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
                  ),
                )
                    .animate()
                    .fadeIn(delay: 500.ms)
                    .slideX(begin: -0.1),
                
                const SizedBox(height: 32),
                
                // Botón de enviar
                OasisButton(
                  text: 'Enviar instrucciones',
                  onPressed: _isLoading ? () {} : _handleResetPassword,
                  isLoading: _isLoading,
                )
                    .animate()
                    .fadeIn(delay: 600.ms)
                    .scale(begin: Offset(0.9, 0.9), end: Offset(1, 1)),
              ] else ...[
                // Confirmación de envío
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.successColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: AppTheme.successColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Correo enviado exitosamente',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.successColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn()
                    .scale(),
                
                const SizedBox(height: 32),
                
                // Botón de volver
                OasisButton(
                  text: 'Volver al inicio de sesión',
                  onPressed: () => context.go('/auth/login'),
                )
                    .animate()
                    .fadeIn(delay: 300.ms),
              ],
              
              const SizedBox(height: 24),
              
              // Link de soporte
              TextButton(
                onPressed: () {
                  // TODO: Abrir soporte
                },
                child: const Text('¿Necesitas ayuda?'),
              )
                  .animate()
                  .fadeIn(delay: 700.ms),
            ],
          ),
        ),
      ),
    );
  }
}