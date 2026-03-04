// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'dart:async';
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart'; // ✅ Extensión para colores que se adaptan al tema
import '../../providers/auth_provider.dart';
import '../../widgets/animated/modern_animated_widgets.dart';

/// Pantalla profesional para cambiar el número de teléfono con verificación OTP
///
/// Flujo de 2 pasos:
/// 1. Paso 1: Ingresar nuevo número de teléfono
/// 2. Paso 2: Verificar código OTP enviado al nuevo número
///
/// Características de seguridad:
/// - Validación de formato peruano (9XXXXXXXX)
/// - Verificación que el número no esté registrado por otra cuenta
/// - Código OTP de 6 dígitos
/// - Timer de 60 segundos para reenvío
/// - Actualización en Firebase Auth Y Firestore
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

  // Timer para reenvío
  Timer? _timer;
  int _resendTimer = 60;
  bool _canResend = false;

  // ✅ Flag para prevenir setState después de dispose
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _errorController = StreamController<ErrorAnimationType>();

    _fadeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: Duration(milliseconds: 800),
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
    // ✅ Marcar como disposed ANTES de cancelar recursos
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

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      // ✅ Verificación triple para prevenir setState después de dispose
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: context.onPrimaryText),
              SizedBox(width: 12),
              Expanded(
                child: Text('Código enviado a +51 $newPhoneNumber'),
              ),
            ],
          ),
          backgroundColor: ModernTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
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
      // ✅ Número actualizado exitosamente
      HapticFeedback.mediumImpact();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: context.onPrimaryText),
              SizedBox(width: 12),
              Text("Número de teléfono actualizado exitosamente"),
            ],
          ),
          backgroundColor: ModernTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      // Volver a la pantalla anterior después de 1 segundo
      await Future.delayed(Duration(seconds: 1));
      if (!mounted) return;
      Navigator.pop(context, true); // Retornar true para indicar éxito

    } else {
      // ❌ Error al verificar OTP
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Código reenviado a +51 $newPhoneNumber"),
          backgroundColor: ModernTheme.rappiOrange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } else {
      _showError(authProvider.errorMessage ?? "Error al reenviar código");
    }

    setState(() => _isLoading = false);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: context.onPrimaryText),
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
        backgroundColor: ModernTheme.rappiOrange.withValues(alpha: 0.06),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: context.primaryText),
            onPressed: () {
              final authProvider =
                  Provider.of<AuthProvider>(context, listen: false);
              authProvider.cancelPhoneNumberChange();
              Navigator.pop(context);
            },
          ),
          title: Text(
            'Cambiar Número de Teléfono',
            style: TextStyle(
              color: context.primaryText,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 16),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _slideAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Indicador de paso actual
                    _buildStepIndicator(),

                    const SizedBox(height: 24),

                    // Card flotante centrada con borderRadius 24 y elevation 4
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: _currentStep == 1
                            ? _buildStep1EnterPhoneNumber()
                            : _buildStep2VerifyOTP(),
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

  /// Indicador visual del paso actual (1 o 2)
  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepCircle(1, isActive: _currentStep == 1, isCompleted: _currentStep > 1),
        Container(
          width: 80,
          height: 2,
          color: _currentStep > 1 ? ModernTheme.rappiOrange : ModernTheme.borderColor,
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
            ? ModernTheme.success
            : isActive
                ? ModernTheme.rappiOrange
                : Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: isActive || isCompleted ? ModernTheme.rappiOrange : ModernTheme.borderColor,
          width: 2,
        ),
      ),
      child: Center(
        child: isCompleted
            ? Icon(Icons.check, color: context.onPrimaryText, size: 20)
            : Text(
                '$step',
                style: TextStyle(
                  color: isActive ? context.onPrimaryText : context.secondaryText,
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
              color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.phone_android,
              size: 60,
              color: ModernTheme.rappiOrange,
            ),
          ),

          SizedBox(height: 32),

          // Título
          Text(
            'Nuevo Número de Teléfono',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: context.primaryText,
            ),
          ),

          SizedBox(height: 12),

          // Subtítulo con número actual (si existe)
          if (widget.currentPhoneNumber != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: ModernTheme.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, color: ModernTheme.info, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Número actual: +51 ${widget.currentPhoneNumber}',
                    style: TextStyle(
                      fontSize: 14,
                      color: ModernTheme.info,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(height: 32),

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
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.phone, color: ModernTheme.rappiOrange),
                    SizedBox(width: 8),
                    Text(
                      '+51',
                      style: TextStyle(
                        fontSize: 16,
                        color: context.primaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 4),
                    Container(
                      width: 1,
                      height: 24,
                      color: ModernTheme.borderColor,
                    ),
                  ],
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: ModernTheme.rappiOrange, width: 2),
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

          SizedBox(height: 32),

          // Botón continuar
          AnimatedPulseButton(
            text: 'Enviar Código de Verificación',
            icon: Icons.send,
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _sendOTP,
          ),

          SizedBox(height: 24),

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
            color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.verified_user,
                size: 60,
                color: ModernTheme.rappiOrange,
              ),
              if (_isLoading)
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    ModernTheme.rappiOrange,
                  ),
                ),
            ],
          ),
        ),

        SizedBox(height: 32),

        // Título
        Text(
          'Verificar Código',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: context.primaryText,
          ),
        ),

        SizedBox(height: 12),

        // Subtítulo
        Text(
          'Ingresa el código de 6 dígitos\nenviado al',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: context.secondaryText,
          ),
        ),

        SizedBox(height: 8),

        // Número de teléfono
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '+51 ${_phoneController.text}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: ModernTheme.rappiOrange,
            ),
          ),
        ),

        SizedBox(height: 40),

        // Campo OTP
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: PinCodeTextField(
            appContext: context,
            length: 6,
            controller: _otpController,
            animationType: AnimationType.scale,
            animationDuration: Duration(milliseconds: 200),
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
              selectedFillColor: ModernTheme.rappiOrange.withValues(alpha: 0.1),
              activeColor: ModernTheme.rappiOrange,
              inactiveColor: ModernTheme.borderColor,
              selectedColor: ModernTheme.rappiOrange,
              errorBorderColor: ModernTheme.error,
            ),
            cursorColor: ModernTheme.rappiOrange,
            textStyle: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: context.primaryText,
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
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Código incorrecto. Intenta de nuevo.',
              style: TextStyle(
                color: ModernTheme.error,
                fontSize: 14,
              ),
            ),
          ),

        SizedBox(height: 32),

        // Botón verificar
        AnimatedPulseButton(
          text: 'Verificar y Actualizar',
          icon: Icons.check_circle,
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _verifyOTP,
        ),

        SizedBox(height: 24),

        // Timer y reenviar
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '¿No recibiste el código? ',
              style: TextStyle(
                color: context.secondaryText,
                fontSize: 14,
              ),
            ),
            if (!_canResend)
              Text(
                'Reenviar en ${_resendTimer}s',
                style: TextStyle(
                  color: ModernTheme.rappiOrange,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              TextButton(
                onPressed: _isLoading ? null : _resendOTP,
                child: Text(
                  'Reenviar ahora',
                  style: TextStyle(
                    color: ModernTheme.rappiOrange,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),

        SizedBox(height: 24),

        // Botón volver al paso 1
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
          icon: Icon(Icons.edit, size: 16),
          label: Text('Cambiar número'),
          style: TextButton.styleFrom(
            foregroundColor: context.secondaryText,
          ),
        ),
      ],
    );
  }

  /// Widget de información de seguridad
  Widget _buildSecurityInfo() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ModernTheme.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ModernTheme.info.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.security,
            color: ModernTheme.info,
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cambio Seguro',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: context.primaryText,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Recibirás un código de verificación en tu nuevo número. El cambio se aplicará solo después de verificar el código.',
                  style: TextStyle(
                    color: context.secondaryText,
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
