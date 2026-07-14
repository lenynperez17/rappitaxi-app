// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/modern_theme.dart';
import '../../utils/logger.dart';
import '../../providers/auth_provider.dart' as app_auth;

/// Pantalla de verificación de email — MIGRADA a backend Node.
///
/// La verificación de email por Firebase link (`sendEmailVerification()` +
/// deep link) ya no aplica en la arquitectura Node/Postgres. El backend
/// aún no expone un endpoint de verificación por email, por lo que esta
/// pantalla ahora sirve únicamente como un "aviso" al usuario:
///
///   - Le informa que la verificación no está disponible por ahora.
///   - Le permite continuar sin verificar (retornando `false` al caller).
///   - Le permite volver atrás (retornando `false`).
///
/// TODO(node-migration): reemplazar con endpoint /api/auth/verify-email
/// (envío + confirmación) cuando exista en el backend.
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
  // TODO(node-migration): reemplazar toda la lógica anterior de
  // sendEmailVerification / reload / _startVerificationCheck / _markEmailAsVerifiedInFirestore
  // por llamadas al backend Node cuando exista el endpoint.
  //
  // Lógica original (comentada arriba en el historial de git):
  //   - user.sendEmailVerification()
  //   - user.reload() en Timer periódico
  //   - update Firestore { emailVerified: true }

  @override
  void initState() {
    super.initState();
    AppLogger.info(
      'EmailVerificationScreen: verificación por email no disponible en Node — '
      'mostrando aviso al usuario (email=${widget.email}, provider=${widget.loginProvider})',
    );
  }

  /// Actualiza el email en el perfil (sin marcar como verificado) y sale.
  Future<void> _continueWithoutVerify() async {
    try {
      final authProvider = Provider.of<app_auth.AuthProvider>(
        context,
        listen: false,
      );

      // Guardar el email en el backend (queda como no verificado)
      if (widget.email.isNotEmpty && widget.email.contains('@')) {
        await authProvider.updateEmail(widget.email);
      }
    } catch (e) {
      AppLogger.error('Error guardando email al continuar sin verificar', e);
    }

    if (!mounted) return;
    // Retornamos `false` para indicar "no verificado, pero el usuario decidió continuar".
    Navigator.of(context).pop(false);
  }

  void _goBack() {
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icono informativo
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.info_outline_rounded,
                        size: 72,
                        color: Colors.orange,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Título
                    const Text(
                      'Verificación no disponible',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    // Descripción
                    Text(
                      'La verificación por email no está disponible por ahora.',
                      style: TextStyle(
                        fontSize: 15,
                        color: ModernTheme.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 12),

                    // Email del usuario
                    if (widget.email.isNotEmpty) ...[
                      Text(
                        widget.email,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: ModernTheme.rappiOrange,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                    ],

                    Text(
                      'Podrás verificar tu email más adelante cuando la '
                      'función esté disponible. Puedes continuar sin '
                      'verificar por ahora.',
                      style: TextStyle(
                        fontSize: 13,
                        color: ModernTheme.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 28),

                    // Botón continuar sin verificar (principal)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _continueWithoutVerify,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text(
                          'Continuar sin verificar',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ModernTheme.rappiOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Botón volver (secundario)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _goBack,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Volver'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(
                            color: ModernTheme.rappiOrange,
                            width: 1.5,
                          ),
                          foregroundColor: ModernTheme.rappiOrange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
