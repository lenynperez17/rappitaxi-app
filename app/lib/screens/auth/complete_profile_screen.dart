// ignore_for_file: use_build_context_synchronously, unused_element
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/modern_theme.dart';
import '../../utils/logger.dart';
import 'email_verification_screen.dart';

/// Pantalla OBLIGATORIA para completar perfil después de login social
/// REDISEÑO: Flujo por pasos para mejor UX
/// Paso 1: Teléfono (verificación SMS)
/// Paso 2: Email (verificación si es necesario)
/// Paso 3: Contraseña
class CompleteProfileScreen extends StatefulWidget {
  final String loginMethod;

  const CompleteProfileScreen({
    super.key,
    required this.loginMethod,
  });

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  // Control de pasos
  int _currentStep = 0;

  // Controllers
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Estados de carga
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Estados de verificación de teléfono
  bool _isOTPSent = false;
  bool _isPhoneVerified = false;
  bool _phoneVerificationSkipped = false;

  // Estados de email
  bool _needsEmail = true;
  bool _isEmailVerified = false;
  String? _existingEmail;
  bool _emailVerificationSkipped = false;

  @override
  void initState() {
    super.initState();
    _checkEmailStatus();
  }

  /// Verifica estados de verificación desde Firestore y Firebase Auth
  Future<void> _checkEmailStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      // PASO 1: Leer documento de Firestore para obtener estados guardados
      String? email;
      String? phone;
      bool phoneVerifiedInFirestore = false;
      bool emailVerifiedInFirestore = false;

      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (doc.exists) {
          final data = doc.data()!;

          // Leer email
          final firestoreEmail = data['email'] as String?;
          if (firestoreEmail != null && firestoreEmail.isNotEmpty && firestoreEmail.contains('@')) {
            email = firestoreEmail;
            AppLogger.debug('Email desde Firestore: $email');
          }

          // Leer teléfono
          phone = data['phone'] as String?;
          AppLogger.debug('Teléfono desde Firestore: $phone');

          // Leer estados de verificación
          phoneVerifiedInFirestore = data['phoneVerified'] == true;
          emailVerifiedInFirestore = data['emailVerified'] == true;

          AppLogger.debug('Estados Firestore - phoneVerified: $phoneVerifiedInFirestore, emailVerified: $emailVerifiedInFirestore');
        }
      } catch (e) {
        AppLogger.error('Error leyendo Firestore', e);
      }

      // PASO 2: Buscar email en otras fuentes si no está en Firestore
      if (email == null || email.isEmpty) {
        email = currentUser.email;
        AppLogger.debug('Email desde Firebase Auth: $email');
      }

      if (email == null || email.isEmpty) {
        for (final provider in currentUser.providerData) {
          if (provider.email != null && provider.email!.isNotEmpty) {
            email = provider.email;
            AppLogger.debug('Email desde providerData (${provider.providerId}): $email');
            break;
          }
        }
      }

      if (email == null || email.isEmpty) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        email = authProvider.currentUser?.email;
        AppLogger.debug('Email desde AuthProvider: $email');
      }

      // PASO 3: Verificar estado de email
      bool emailVerifiedInAuth = false;
      try {
        await currentUser.reload();
        final refreshedUser = FirebaseAuth.instance.currentUser;
        emailVerifiedInAuth = refreshedUser?.emailVerified ?? false;
        AppLogger.debug('emailVerified en Firebase Auth: $emailVerifiedInAuth');
      } catch (e) {
        AppLogger.error('Error recargando usuario', e);
      }

      // IMPORTANTE: Si el login es con Google/Facebook/Apple, el email YA está verificado
      // por el proveedor OAuth, no necesita verificación adicional
      final String loginMethod = widget.loginMethod.toLowerCase();
      final bool isOAuthProvider = loginMethod == 'google' || loginMethod == 'facebook' || loginMethod == 'apple';
      final bool isValidEmail = email != null && email.isNotEmpty && email.contains('@');

      AppLogger.debug('Login method: $loginMethod, isOAuth: $isOAuthProvider');

      // El email está verificado si:
      // 1. Tiene un email válido Y
      // 2. (Está marcado en Firebase Auth O está marcado en Firestore O es OAuth)
      // ✅ IMPORTANTE: Sin email válido, NO puede estar verificado
      bool isEmailVerified = isValidEmail && (emailVerifiedInAuth || emailVerifiedInFirestore);

      if (!isEmailVerified && isOAuthProvider && isValidEmail) {
        AppLogger.info('Email de proveedor OAuth ($loginMethod) - marcando como verificado automáticamente');
        isEmailVerified = true;

        // Guardar en Firestore que el email está verificado
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .update({
            'email': email,
            'emailVerified': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          AppLogger.info('Email OAuth guardado y marcado como verificado en Firestore');
        } catch (e) {
          AppLogger.error('Error guardando email verificado', e);
        }
      }

      // PASO 4: Actualizar estados en UI
      setState(() {
        // Email
        _existingEmail = isValidEmail ? email : null;
        _needsEmail = !isValidEmail;
        _isEmailVerified = isEmailVerified;
        if (isValidEmail) {
          _emailController.text = email!;
        }

        // Teléfono - si ya está verificado en Firestore, marcarlo
        if (phoneVerifiedInFirestore) {
          _isPhoneVerified = true;
          if (phone != null && phone.isNotEmpty) {
            _phoneController.text = phone;
          }
        } else if (phone != null && phone.isNotEmpty) {
          // Tiene teléfono pero no verificado
          _phoneController.text = phone;
        }
      });

      AppLogger.info('Estado inicial - Email: $_existingEmail (verificado: $_isEmailVerified), '
          'Teléfono: ${_phoneController.text} (verificado: $_isPhoneVerified), needsEmail: $_needsEmail');

      // PASO 5: Determinar paso inicial basado en lo que falta
      // IMPORTANTE: Verificar que realmente tengamos un email válido antes de marcar como completo
      final bool hasValidEmail = _existingEmail != null &&
                                  _existingEmail!.isNotEmpty &&
                                  _existingEmail!.contains('@');

      if (_isPhoneVerified && _isEmailVerified && hasValidEmail) {
        // Ambos verificados Y tenemos email válido, ir a contraseña
        setState(() => _currentStep = 2);
      } else if (_isPhoneVerified && hasValidEmail) {
        // Teléfono verificado y hay email, ir a email verification
        setState(() => _currentStep = 1);
      } else if (_isPhoneVerified) {
        // Teléfono verificado pero NO hay email - ir a paso de email
        setState(() {
          _currentStep = 1;
          _needsEmail = true; // Forzar que pida email
        });
      }
      // Si no, quedarse en paso 0 (teléfono)

    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recuerda completar tu perfil para usar todas las funciones'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: _isLoading && _currentStep == 0
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(ModernTheme.rappiOrange),
                ),
              )
            : Column(
                children: [
                  // Header curvo naranja con height 160
                  _buildCurvedHeader(),

                  // Avatar selector sobre el header (superpuesto con Positioned via Stack)
                  // El Stack se maneja dentro de _buildCurvedHeader

                  // Contenido de pasos con padding horizontal 24
                  Expanded(
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: Theme.of(context).colorScheme.copyWith(
                          primary: ModernTheme.rappiOrange,
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.of(context).viewInsets.bottom + 8),
                        child: Column(
                          children: [
                            // Nombre de la seccion activa
                            _buildSectionHeader(),
                            const SizedBox(height: 16),
                            // Contenido del paso actual
                            _buildCurrentStepContent(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Icono del proveedor
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getProviderIcon(),
              size: 40,
              color: ModernTheme.rappiOrange,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '¡Casi listo!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Completa estos pasos para usar Rappi Team',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getProviderIcon(), size: 16, color: ModernTheme.rappiOrange),
                const SizedBox(width: 6),
                Text(
                  'Login con ${_getProviderName()}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: ModernTheme.rappiOrange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Header curvo naranja con height 160 y avatar superpuesto
  Widget _buildCurvedHeader() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Header naranja con clipPath curvo
        ClipPath(
          clipper: _BottomCurveClipper(),
          child: Container(
            height: 160,
            width: double.infinity,
            color: ModernTheme.rappiOrange,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const Expanded(
                      child: Text(
                        'Completar Perfil',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Avatar selector superpuesto sobre el header (Positioned overlapping)
        Positioned(
          bottom: -36,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: ModernTheme.rappiOrange, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                _getProviderIcon(),
                size: 36,
                color: ModernTheme.rappiOrange,
              ),
            ),
          ),
        ),

        // Espacio para el avatar superpuesto
        const SizedBox(height: 196),
      ],
    );
  }

  // Header de seccion con nombre del proveedor y paso actual
  Widget _buildSectionHeader() {
    final stepLabels = ['Teléfono', 'Email', 'Contraseña'];
    final stepIcons = [Icons.phone, Icons.email, Icons.lock];

    return Column(
      children: [
        const SizedBox(height: 48), // espacio para el avatar superpuesto
        // Nombre del proveedor
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getProviderIcon(), size: 14, color: ModernTheme.rappiOrange),
              const SizedBox(width: 6),
              Text(
                'Login con ${_getProviderName()}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: ModernTheme.rappiOrange,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Mini stepper de pasos
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3 * 2 - 1, (i) {
            if (i.isOdd) {
              return Container(
                width: 32,
                height: 2,
                color: i ~/ 2 < _currentStep
                    ? ModernTheme.rappiOrange
                    : Colors.grey.shade300,
              );
            }
            final idx = i ~/ 2;
            final isActive = idx == _currentStep;
            final isComplete = idx < _currentStep;
            return Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isComplete || isActive
                        ? ModernTheme.rappiOrange
                        : Colors.grey.shade200,
                  ),
                  child: Center(
                    child: isComplete
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : Icon(
                            stepIcons[idx],
                            color: isActive ? Colors.white : Colors.grey.shade400,
                            size: 16,
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stepLabels[idx],
                  style: TextStyle(
                    fontSize: 10,
                    color: isActive ? ModernTheme.rappiOrange : Colors.grey.shade400,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            );
          }),
        ),
        const SizedBox(height: 8),
        // Titulo del paso actual
        Text(
          _currentStep == 0
              ? '¡Casi listo!'
              : _currentStep == 1
                  ? 'Verificar Email'
                  : 'Crear Contraseña',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Completa estos pasos para usar Rappi Team',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Contenido del paso actual (wrapper que llama a los builders de pasos)
  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildPhoneStepWithControls();
      case 1:
        return _buildEmailStepWithControls();
      case 2:
        return _buildPasswordStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPhoneStepWithControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPhoneStep(),
        const SizedBox(height: 16),
        if (_isPhoneVerified)
          _buildNextButton('Siguiente', _onStepContinue)
        else if (_phoneVerificationSkipped)
          _buildNextButton('Continuar sin verificar', _onStepContinue, color: Colors.orange),
      ],
    );
  }

  Widget _buildEmailStepWithControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildEmailStep(),
        const SizedBox(height: 16),
        if (_isEmailVerified) ...[
          _buildNextButton('Siguiente', _onStepContinue),
          const SizedBox(height: 8),
          _buildBackButton('Anterior', _onStepCancel),
        ] else if (_emailVerificationSkipped) ...[
          _buildNextButton('Continuar sin verificar', _onStepContinue, color: Colors.orange),
          const SizedBox(height: 8),
          _buildBackButton('Anterior', _onStepCancel),
        ],
      ],
    );
  }

  Widget _buildNextButton(String label, VoidCallback? onPressed, {Color? color}) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
        label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? ModernTheme.rappiOrange,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildBackButton(String label, VoidCallback? onPressed) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_back, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
    );
  }

  Widget _buildStepControls(ControlsDetails details) {
    // Controles personalizados según el paso
    if (_currentStep == 0) {
      // Paso 1: Teléfono
      if (_isPhoneVerified) {
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: ElevatedButton.icon(
            onPressed: details.onStepContinue,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Siguiente'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.rappiOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        );
      } else if (_phoneVerificationSkipped) {
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: ElevatedButton.icon(
            onPressed: details.onStepContinue,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Continuar sin verificar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    } else if (_currentStep == 1) {
      // Paso 2: Email
      if (_isEmailVerified) {
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: details.onStepCancel,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Anterior'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: details.onStepContinue,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Siguiente'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ModernTheme.rappiOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      } else if (_emailVerificationSkipped) {
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: details.onStepCancel,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Anterior'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: details.onStepContinue,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Continuar sin verificar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    } else {
      // Paso 3: Contraseña (paso final) - Botón para regresar
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: TextButton.icon(
          onPressed: details.onStepCancel,
          icon: const Icon(Icons.arrow_back),
          label: const Text('Paso anterior'),
        ),
      );
    }
  }

  // ============================================================
  // PASO 1: TELÉFONO
  // ============================================================
  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isPhoneVerified) ...[
          // Teléfono verificado
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Teléfono verificado',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      Text(
                        _phoneController.text,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // Campo de teléfono
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            enabled: !_isOTPSent,
            decoration: InputDecoration(
              labelText: 'Número de teléfono',
              hintText: '999 999 999',
              prefixText: '+51 ',
              prefixIcon: const Icon(Icons.phone),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              helperText: 'Ingresa tu número de 9 dígitos',
            ),
          ),

          const SizedBox(height: 16),

          if (!_isOTPSent) ...[
            // Botón enviar código
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _sendOTP,
              icon: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sms),
              label: Text(_isLoading ? 'Enviando...' : 'Enviar código SMS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.rappiOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ] else ...[
            // Campo OTP
            TextFormField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Código de verificación',
                hintText: '123456',
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 12),

            // Botón verificar
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _verifyOTP,
              icon: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_circle),
              label: Text(_isLoading ? 'Verificando...' : 'Verificar código'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.rappiOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),

            const SizedBox(height: 12),

            // Botón reenviar
            TextButton.icon(
              onPressed: _isLoading ? null : () {
                setState(() => _isOTPSent = false);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Cambiar número'),
            ),
          ],

          const SizedBox(height: 16),

          // Opción verificar después
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _skipPhoneVerification,
            icon: const Icon(Icons.schedule),
            label: const Text('Verificar después'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: const BorderSide(color: Colors.orange),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Podrás verificar tu teléfono más tarde desde tu perfil',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  // ============================================================
  // PASO 2: EMAIL
  // ============================================================
  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isEmailVerified) ...[
          // Email verificado
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Email verificado',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      Text(
                        _existingEmail ?? _emailController.text,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else if (_needsEmail) ...[
          // No tiene email - debe ingresar uno
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tu cuenta de ${_getProviderName()} no proporcionó un email. Por favor ingresa uno.',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Correo electrónico',
              hintText: 'tu@email.com',
              prefixIcon: const Icon(Icons.email),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: _isLoading ? null : _saveAndVerifyEmail,
            icon: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.email),
            label: Text(_isLoading ? 'Guardando...' : 'Guardar y verificar email'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.rappiOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ] else ...[
          // Tiene email pero no verificado
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.email, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text(
                      'Tu email',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _existingEmail ?? '',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: _isLoading ? null : _startEmailVerification,
            icon: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.verified_user),
            label: Text(_isLoading ? 'Procesando...' : 'Verificar email'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.rappiOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],

        if (!_isEmailVerified) ...[
          const SizedBox(height: 16),

          OutlinedButton.icon(
            onPressed: _isLoading ? null : _skipEmailVerification,
            icon: const Icon(Icons.schedule),
            label: const Text('Verificar después'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: const BorderSide(color: Colors.orange),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Podrás verificar tu email más tarde desde tu perfil',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  // ============================================================
  // PASO 3: CONTRASEÑA
  // ============================================================
  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Crea una contraseña para poder acceder también con tu email',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),

        const SizedBox(height: 16),

        // Campo contraseña
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Contraseña',
            hintText: 'Mínimo 8 caracteres',
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            helperText: 'Mayúsculas, minúsculas, números y símbolos',
          ),
        ),

        const SizedBox(height: 16),

        // Confirmar contraseña
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            labelText: 'Confirmar contraseña',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),

        const SizedBox(height: 24),

        // Botón completar perfil
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _completeProfile,
          icon: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_circle),
          label: Text(
            _isLoading ? 'Completando perfil...' : 'Completar Perfil',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: ModernTheme.rappiOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),

        const SizedBox(height: 16),

        // Resumen de verificaciones
        _buildVerificationSummary(),
      ],
    );
  }

  Widget _buildVerificationSummary() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estado de verificaciones:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          _buildStatusRow('Teléfono', _isPhoneVerified, _phoneVerificationSkipped),
          const SizedBox(height: 4),
          _buildStatusRow('Email', _isEmailVerified, _emailVerificationSkipped),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, bool verified, bool skipped) {
    IconData icon;
    Color color;
    String status;

    if (verified) {
      icon = Icons.check_circle;
      color = Colors.green;
      status = 'Verificado';
    } else if (skipped) {
      icon = Icons.schedule;
      color = Colors.orange;
      status = 'Pendiente';
    } else {
      icon = Icons.cancel;
      color = Colors.grey;
      status = 'Sin verificar';
    }

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13)),
        const Spacer(),
        Text(status, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ============================================================
  // NAVIGATION
  // ============================================================
  void _onStepContinue() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================
  IconData _getProviderIcon() {
    switch (widget.loginMethod) {
      case 'google':
        return Icons.g_mobiledata;
      case 'facebook':
        return Icons.facebook;
      case 'apple':
        return Icons.apple;
      default:
        return Icons.login;
    }
  }

  String _getProviderName() {
    switch (widget.loginMethod) {
      case 'google':
        return 'Google';
      case 'facebook':
        return 'Facebook';
      case 'apple':
        return 'Apple';
      default:
        return 'Redes Sociales';
    }
  }

  // ============================================================
  // PHONE VERIFICATION LOGIC
  // ============================================================
  Future<void> _sendOTP() async {
    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      _showError('Ingresa tu número de teléfono');
      return;
    }

    // Validar formato
    final cleanValue = phone.replaceAll(' ', '').replaceAll('+', '').replaceAll('51', '');
    if (!RegExp(r'^9\d{8}$').hasMatch(cleanValue)) {
      _showError('Ingresa un número peruano válido (9 dígitos, empieza con 9)');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final result = await authProvider.startPhoneVerification(cleanValue);

      if (!mounted) return;

      if (result) {
        setState(() => _isOTPSent = true);
        _showSuccess('Código enviado. Revisa tus SMS');
      } else {
        _showError(authProvider.errorMessage ?? 'Error al enviar código');
      }
    } catch (e) {
      AppLogger.error('Error enviando OTP', e);
      if (mounted) _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();

    if (otp.isEmpty || otp.length != 6) {
      _showError('Ingresa el código de 6 dígitos');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final result = await authProvider.verifyOTP(otp);

      if (!mounted) return;

      if (result) {
        // GUARDAR INMEDIATAMENTE en Firestore
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          final phone = _phoneController.text.trim().replaceAll(' ', '').replaceAll('+', '').replaceAll('51', '');
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .update({
              'phone': phone,
              'phoneVerified': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            AppLogger.info('Teléfono verificado guardado en Firestore: $phone');
          } catch (e) {
            AppLogger.error('Error guardando teléfono verificado', e);
          }
        }

        setState(() {
          _isPhoneVerified = true;
          _currentStep = 1; // Avanzar al siguiente paso
        });
        _showSuccess('Teléfono verificado correctamente');
      } else {
        _showError(authProvider.errorMessage ?? 'Código incorrecto');
      }
    } catch (e) {
      AppLogger.error('Error verificando OTP', e);
      if (mounted) _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _skipPhoneVerification() {
    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      _showError('Primero ingresa tu número de teléfono');
      return;
    }

    // Validar formato
    final cleanValue = phone.replaceAll(' ', '').replaceAll('+', '').replaceAll('51', '');
    if (!RegExp(r'^9\d{8}$').hasMatch(cleanValue)) {
      _showError('Ingresa un número peruano válido');
      return;
    }

    setState(() {
      _phoneVerificationSkipped = true;
      _currentStep = 1; // Avanzar al siguiente paso
    });

    _showInfo('Podrás verificar tu teléfono después desde tu perfil');
  }

  // ============================================================
  // EMAIL VERIFICATION LOGIC
  // ============================================================
  Future<void> _saveAndVerifyEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showError('Ingresa tu correo electrónico');
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showError('Ingresa un email válido');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Guardar email en Firestore
      await authProvider.updateEmailInFirestore(email);

      setState(() {
        _existingEmail = email;
        _needsEmail = false;
      });

      if (!mounted) return;

      // Iniciar verificación
      await _startEmailVerification();
    } catch (e) {
      AppLogger.error('Error guardando email', e);
      if (mounted) _showError('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startEmailVerification() async {
    setState(() => _isLoading = true);

    try {
      final email = _existingEmail ?? _emailController.text.trim();

      if (email.isEmpty) {
        _showError('No hay email para verificar');
        return;
      }

      // Si es OAuth (Google/Facebook/Apple), verificar directamente sin abrir pantalla
      final String loginMethod = widget.loginMethod.toLowerCase();
      final bool isOAuthProvider = loginMethod == 'google' || loginMethod == 'facebook' || loginMethod == 'apple';

      if (isOAuthProvider) {
        // Marcar como verificado directamente en Firestore
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .update({
            'email': email,
            'emailVerified': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        if (!mounted) return;

        setState(() {
          _existingEmail = email; // Guardar email para uso posterior
          _needsEmail = false;
          _isEmailVerified = true;
          _currentStep = 2; // Avanzar al paso final
        });
        _showSuccess('Email verificado correctamente');
        return;
      }

      // Para otros métodos de login, abrir pantalla de verificación
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => EmailVerificationScreen(
            email: email,
            loginProvider: widget.loginMethod,
          ),
        ),
      );

      if (!mounted) return;

      if (result == true) {
        setState(() {
          _isEmailVerified = true;
          _currentStep = 2; // Avanzar al paso final
        });
        _showSuccess('Email verificado correctamente');
      }
    } catch (e) {
      AppLogger.error('Error verificando email', e);
      if (mounted) _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _skipEmailVerification() {
    // Si necesita email pero no lo ha ingresado
    if (_needsEmail && _emailController.text.trim().isEmpty) {
      _showError('Primero ingresa tu correo electrónico');
      return;
    }

    // Si ingresó email, guardarlo primero
    if (_needsEmail && _emailController.text.trim().isNotEmpty) {
      final email = _emailController.text.trim();
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        _showError('Ingresa un email válido');
        return;
      }

      // Guardar email antes de continuar
      Provider.of<AuthProvider>(context, listen: false).updateEmailInFirestore(email);
      setState(() {
        _existingEmail = email;
        _needsEmail = false;
      });
    }

    setState(() {
      _emailVerificationSkipped = true;
      _currentStep = 2; // Avanzar al paso final
    });

    _showInfo('Podrás verificar tu email después desde tu perfil');
  }

  // ============================================================
  // COMPLETE PROFILE
  // ============================================================
  Future<void> _completeProfile() async {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Validar contraseña
    if (password.isEmpty) {
      _showError('Ingresa una contraseña');
      return;
    }

    if (password.length < 8) {
      _showError('La contraseña debe tener al menos 8 caracteres');
      return;
    }

    if (!password.contains(RegExp(r'[A-Z]'))) {
      _showError('La contraseña debe incluir mayúsculas');
      return;
    }

    if (!password.contains(RegExp(r'[a-z]'))) {
      _showError('La contraseña debe incluir minúsculas');
      return;
    }

    if (!password.contains(RegExp(r'[0-9]'))) {
      _showError('La contraseña debe incluir números');
      return;
    }

    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      _showError('La contraseña debe incluir caracteres especiales');
      return;
    }

    if (password != confirmPassword) {
      _showError('Las contraseñas no coinciden');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final phone = _phoneController.text.trim().replaceAll(' ', '').replaceAll('+', '').replaceAll('51', '');
      final email = _existingEmail ?? _emailController.text.trim();

      // Validar que tengamos un email antes de continuar
      if (email.isEmpty || !email.contains('@')) {
        setState(() {
          _isLoading = false;
          _needsEmail = true;
          _currentStep = 1; // Regresar al paso de email
        });
        _showError('Se requiere un email válido. Por favor ingresa tu email.');
        return;
      }

      AppLogger.info('Completando perfil: phone=$phone, email=$email');

      // 1. Vincular contraseña
      final passwordLinked = await authProvider.linkPasswordToAccount(password, email: email);
      if (!passwordLinked) {
        // Obtener el mensaje de error específico del authProvider
        final errorMsg = authProvider.errorMessage ?? 'No se pudo vincular la contraseña';
        throw Exception(errorMsg);
      }

      // 2. Actualizar teléfono en Firestore
      final bool phoneUpdated;
      if (_isPhoneVerified) {
        phoneUpdated = await authProvider.updatePhoneNumberInFirestore(phone);
      } else {
        phoneUpdated = await authProvider.updatePhoneNumberUnverified(phone);
      }

      if (!phoneUpdated) {
        throw Exception('No se pudo actualizar el teléfono');
      }

      AppLogger.info('Perfil completado exitosamente');

      if (!mounted) return;

      _showSuccess('¡Perfil completado! Redirigiendo...');

      await Future.delayed(const Duration(milliseconds: 1500));

      if (!mounted) return;

      // Navegar a home según tipo de usuario
      final user = authProvider.currentUser!;
      String route;

      if (user.isAdmin) {
        route = '/admin/dashboard';
      } else {
        final mode = user.activeMode;
        route = mode == 'driver' ? '/driver/home' : '/passenger/home';
      }

      AppLogger.info('Navegando a: $route');
      Navigator.pushReplacementNamed(context, route);
    } catch (e) {
      AppLogger.error('Error completando perfil', e);
      if (mounted) _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // SNACKBAR HELPERS
  // ============================================================
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

/// CustomClipper para el header naranja con curva inferior
class _BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 30);
    path.quadraticBezierTo(
      size.width / 2,
      size.height + 20,
      size.width,
      size.height - 30,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
