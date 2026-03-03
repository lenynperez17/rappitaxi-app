import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'dart:async';
import '../../core/design/design_system.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../providers/auth_provider.dart';
import '../../core/widgets/rt_animated_widgets.dart';

/// Pantalla profesional para cambiar el número de teléfono con verificación OTP
///
/// Flujo de 2 pasos:
/// 1. Paso 1: Ingresar nuevo número de teléfono
/// 2. Paso 2: Verificar código OTP enviado al nuevo número
///
/// Caracteristicas de seguridad:
/// - Validacion de formato peruano (9XXXXXXXX)
/// - Verificación que el número no este registrado por otra cuenta
/// - Código OTP de 6 dígitos
/// - Timer de 60 segundos para reenvio
/// - Actualizacion en Firebase Auth Y Firestore
class ChangePhoneNumberScreen extends StatefulWidget {
  final String? currentPhoneNumber; // Número actual del usuario (opcional)

  const ChangePhoneNumberScreen({
    super.key,
    this.currentPhoneNumber,
  });

  @override
  State<ChangePhoneNumberScreen> createState() => _ChangePhoneNumberScreenState();
}

class _ChangePhoneNumberScreenState extends State<ChangePhoneNumberScreen>
    with TickerProviderStateMixin {

  // Controllers
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  StreamController<ErrorAnimationType>? _errorController;

  // Animations
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  // State
  int _currentStep = 1; // 1 = Ingresar número, 2 = Verificar OTP
  bool _isLoading = false;
  bool _hasError = false;
  String _currentOTP = "";

  // Timer para reenvio
  Timer? _timer;
  int _resendTimer = 60;
  bool _canResend = false;

  // Flag para prevenir setState después de dispose
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _errorController = StreamController<ErrorAnimationType>();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
    );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    // Marcar como disposed ANTES de cancelar recursos
    _isDisposed = true;

    _timer?.cancel();
    _timer = null;

    _errorController?.close();
    _errorController = null;

    _phoneController.dispose();
    _otpController.dispose();
    _fadeController.dispose();
    _slideController.dispose();

    super.dispose();
  }

  void _startResendTimer() {
    _canResend = false;
    _resendTimer = 60;
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Verificación triple para prevenir setState después de dispose
      if (_isDisposed) {
        timer.cancel();
        return;
      }

      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_resendTimer > 0) {
          _resendTimer--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  /// PASO 1: Enviar código OTP al nuevo número
  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final newPhoneNumber = _phoneController.text.trim();

    final success = await authProvider.startPhoneNumberChange(newPhoneNumber);

    if (!mounted) return;

    if (success) {
      // OTP enviado exitosamente, avanzar al paso 2
      setState(() {
        _currentStep = 2;
        _isLoading = false;
      });

      _startResendTimer();

      RtSnackbar.show(context, message: 'Código enviado a +51 $newPhoneNumber', type: RtSnackbarType.success);
    } else {
      // Error al enviar OTP
      _showError(authProvider.errorMessage ?? 'Error al enviar código');
      setState(() => _isLoading = false);
    }
  }

  /// PASO 2: Verificar código OTP y actualizar número
  Future<void> _verifyOTP() async {
    if (_currentOTP.length != 6) {
      _errorController!.add(ErrorAnimationType.shake);
      _showError("Por favor ingresa el código completo de 6 dígitos");
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.verifyPhoneNumberChange(_currentOTP);

    if (!mounted) return;

    if (success) {
      // Número actualizado exitosamente
      HapticFeedback.mediumImpact();

      RtSnackbar.show(context, message: 'Número de teléfono actualizado exitosamente', type: RtSnackbarType.success);

      // Volver a la pantalla anterior después de 1 segundo
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      Navigator.pop(context, true); // Retornar true para indicar exito

    } else {
      // Error al verificar OTP
      _errorController!.add(ErrorAnimationType.shake);
      HapticFeedback.heavyImpact();

      setState(() {
        _hasError = true;
        _currentOTP = "";
      });

      _otpController.clear();

      _showError(authProvider.errorMessage ?? "Código inválido. Intenta de nuevo.");
    }

    setState(() => _isLoading = false);
  }

  /// Reenviar código OTP
  Future<void> _resendOTP() async {
    if (!_canResend) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final newPhoneNumber = _phoneController.text.trim();

    final success = await authProvider.startPhoneNumberChange(newPhoneNumber);

    if (!mounted) return;

    if (success) {
      _startResendTimer();
      RtSnackbar.show(context, message: 'Código reenviado a +51 $newPhoneNumber', type: RtSnackbarType.info);
    } else {
      _showError(authProvider.errorMessage ?? "Error al reenviar código");
    }

    setState(() => _isLoading = false);
  }

  void _showError(String message) {
    if (!mounted) return;
    RtSnackbar.show(context, message: message, type: RtSnackbarType.error);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) {
          // Cancelar el proceso de cambio de número al salir
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          authProvider.cancelPhoneNumberChange();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: RtAppBar(
          title: 'Cambiar Número de Teléfono',
          variant: RtAppBarVariant.gradient,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: RtColors.white),
            onPressed: () {
              // Cancelar proceso y volver
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              authProvider.cancelPhoneNumberChange();
              Navigator.pop(context);
            },
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _slideAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Indicador de paso actual
                    _buildStepIndicator(),

                    const SizedBox(height: 32),

                    // Contenido según el paso actual
                    if (_currentStep == 1)
                      _buildStep1EnterPhoneNumber()
                    else
                      _buildStep2VerifyOTP(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Indicador visual del paso actual (1 o 2)
  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepCircle(1, isActive: _currentStep == 1, isCompleted: _currentStep > 1),
        Container(
          width: 80,
          height: 2,
          color: _currentStep > 1 ? RtColors.brand : RtColors.neutral200,
        ),
        _buildStepCircle(2, isActive: _currentStep == 2, isCompleted: false),
      ],
    );
  }

  Widget _buildStepCircle(int step, {required bool isActive, required bool isCompleted}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted
            ? RtColors.success
            : isActive
                ? RtColors.brand
                : Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: isActive || isCompleted ? RtColors.brand : RtColors.neutral200,
          width: 2,
        ),
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check, color: RtColors.white, size: 20)
            : Text(
                '$step',
                style: TextStyle(
                  color: isActive
                      ? RtColors.white
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }

  /// PASO 1: Formulario para ingresar el nuevo número de teléfono
  Widget _buildStep1EnterPhoneNumber() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Icono animado
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: RtColors.brand.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.phone_android,
              size: 60,
              color: RtColors.brand,
            ),
          ),

          const SizedBox(height: 32),

          // Titulo
          Text(
            'Nuevo Número de Teléfono',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 12),

          // Subtitulo con número actual (si existe)
          if (widget.currentPhoneNumber != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: RtColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline, color: RtColors.info, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Número actual: +51 ${widget.currentPhoneNumber}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: RtColors.info,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 32),

          // Campo de número de teléfono
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(9),
            ],
            decoration: InputDecoration(
              labelText: 'Nuevo número de teléfono',
              hintText: '9XXXXXXXX',
              prefixIcon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.phone, color: RtColors.brand),
                    const SizedBox(width: 8),
                    Text(
                      '+51',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 1,
                      height: 24,
                      color: RtColors.neutral200,
                    ),
                  ],
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: RtColors.brand, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa tu nuevo número de teléfono';
              }
              if (!RegExp(r'^9[0-9]{8}$').hasMatch(value)) {
                return 'Formato inválido. Debe ser 9XXXXXXXX';
              }
              if (value == widget.currentPhoneNumber) {
                return 'El nuevo número debe ser diferente al actual';
              }
              return null;
            },
          ),

          const SizedBox(height: 32),

          // Boton continuar
          AnimatedPulseButton(
            text: 'Enviar Código de Verificación',
            icon: Icons.send,
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _sendOTP,
          ),

          const SizedBox(height: 24),

          // Información de seguridad
          _buildSecurityInfo(),
        ],
      ),
    );
  }

  /// PASO 2: Formulario para verificar el código OTP
  Widget _buildStep2VerifyOTP() {
    return Column(
      children: [
        // Icono animado
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: RtColors.brand.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.verified_user,
                size: 60,
                color: RtColors.brand,
              ),
              if (_isLoading)
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    RtColors.brand,
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Titulo
        Text(
          'Verificar Código',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),

        const SizedBox(height: 12),

        // Subtitulo
        Text(
          'Ingresa el código de 6 dígitos\nenviado al',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),

        const SizedBox(height: 8),

        // Número de teléfono
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: RtColors.brand.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '+51 ${_phoneController.text}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: RtColors.brand,
            ),
          ),
        ),

        const SizedBox(height: 40),

        // Campo OTP
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: PinCodeTextField(
            appContext: context,
            length: 6,
            controller: _otpController,
            animationType: AnimationType.scale,
            animationDuration: const Duration(milliseconds: 200),
            enableActiveFill: true,
            errorAnimationController: _errorController,
            keyboardType: TextInputType.number,
            hapticFeedbackTypes: HapticFeedbackTypes.selection,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            pinTheme: PinTheme(
              shape: PinCodeFieldShape.box,
              borderRadius: BorderRadius.circular(12),
              fieldHeight: 55,
              fieldWidth: 45,
              activeFillColor: Theme.of(context).colorScheme.surface,
              inactiveFillColor: Theme.of(context).colorScheme.surface,
              selectedFillColor: RtColors.brand.withValues(alpha: 0.1),
              activeColor: RtColors.brand,
              inactiveColor: RtColors.neutral200,
              selectedColor: RtColors.brand,
              errorBorderColor: RtColors.error,
            ),
            cursorColor: RtColors.brand,
            textStyle: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onChanged: (value) {
              setState(() {
                _currentOTP = value;
                _hasError = false;
              });
            },
            onCompleted: (value) {
              _verifyOTP();
            },
          ),
        ),

        if (_hasError)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Código incorrecto. Intenta de nuevo.',
              style: TextStyle(
                color: RtColors.error,
                fontSize: 14,
              ),
            ),
          ),

        const SizedBox(height: 32),

        // Boton verificar
        AnimatedPulseButton(
          text: 'Verificar y Actualizar',
          icon: Icons.check_circle,
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _verifyOTP,
        ),

        const SizedBox(height: 24),

        // Timer y reenviar
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No recibiste el código? ',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            if (!_canResend)
              Text(
                'Reenviar en ${_resendTimer}s',
                style: const TextStyle(
                  color: RtColors.brand,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              TextButton(
                onPressed: _isLoading ? null : _resendOTP,
                child: const Text(
                  'Reenviar ahora',
                  style: TextStyle(
                    color: RtColors.brand,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 24),

        // Boton volver al paso 1
        TextButton.icon(
          onPressed: _isLoading
              ? null
              : () {
                  setState(() {
                    _currentStep = 1;
                    _currentOTP = "";
                    _otpController.clear();
                    _timer?.cancel();
                  });
                },
          icon: const Icon(Icons.edit, size: 16),
          label: const Text('Cambiar número'),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  /// Widget de información de seguridad
  Widget _buildSecurityInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RtColors.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: RtColors.info.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.security,
            color: RtColors.info,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cambio Seguro',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Recibirás un código de verificación en tu nuevo número. El cambio se aplicara solo después de verificar el código.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
