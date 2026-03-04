import 'package:flutter/material.dart';
// ignore_for_file: library_private_types_in_public_api
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'dart:async';
import '../../core/theme/modern_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/animated/modern_animated_widgets.dart';

/// Pantalla de Verificación de Teléfono con OTP Profesional
class PhoneVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final bool isRegistration;
  
  const PhoneVerificationScreen({
    super.key,
    required this.phoneNumber,
    this.isRegistration = false,
  });

  @override
  State<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> 
    with TickerProviderStateMixin {
  final _otpController = TextEditingController();
  StreamController<ErrorAnimationType>? _errorController;
  
  late AnimationController _animationController;
  late AnimationController _timerAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
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
    
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    
    _timerAnimationController = AnimationController(
      duration: Duration(seconds: 60),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _animationController.forward();
    _startResendTimer();
    
    // Iniciar verificación
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPhoneVerification();
    });
  }
  
  @override
  void dispose() {
    // ✅ Marcar como disposed ANTES de cancelar recursos
    _isDisposed = true;

    // Cancelar timer INMEDIATAMENTE para prevenir callbacks pendientes
    _timer?.cancel();
    _timer = null;

    // Cerrar y limpiar todos los recursos
    _errorController?.close();
    _errorController = null;

    _otpController.dispose();
    _animationController.dispose();
    _timerAnimationController.dispose();

    super.dispose();
  }
  
  void _startResendTimer() {
    _canResend = false;
    _resendTimer = 60;
    _timer?.cancel();

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      // ✅ TRIPLE VERIFICACIÓN para prevenir setState después de dispose
      // 1. Verificar flag de disposed
      if (_isDisposed) {
        timer.cancel();
        return;
      }

      // 2. Verificar si el widget sigue montado
      if (!mounted) {
        timer.cancel();
        return;
      }

      // 3. Solo ahora es seguro llamar a setState
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
  
  Future<void> _startPhoneVerification() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    setState(() => _isLoading = true);
    
    final success = await authProvider.startPhoneVerification(widget.phoneNumber);
    
    if (!mounted) return;
    
    if (!success && authProvider.errorMessage != null) {
      _showError(authProvider.errorMessage!);
    }
    
    setState(() => _isLoading = false);
  }
  
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
    final success = await authProvider.verifyOTP(_currentOTP);
    
    if (!mounted) return;
    
    if (success) {
      // Animación de éxito
      HapticFeedback.mediumImpact();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Theme.of(context).colorScheme.surface),
              SizedBox(width: 12),
              Text("Teléfono verificado exitosamente"),
            ],
          ),
          backgroundColor: ModernTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      
      // Navegar según el contexto
      // ✅ CORREGIDO: Usar /passenger/home en lugar de /welcome (ruta inexistente)
      // El registro siempre empieza como pasajero, luego puede cambiar a conductor
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/passenger/home',
        (route) => false,
      );
    } else {
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
  
  Future<void> _resendOTP() async {
    if (!_canResend) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    setState(() => _isLoading = true);
    
    final success = await authProvider.resendOTP();
    
    if (!mounted) return;
    
    if (success) {
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Código reenviado a +51 ${widget.phoneNumber}"),
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
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.surface),
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: ModernTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          // Padding horizontal de 32 para layout mas espacioso
          padding: EdgeInsets.fromLTRB(32, 16, 32, MediaQuery.of(context).viewInsets.bottom + 16),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),

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
                          Icons.phone_android,
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

                  const SizedBox(height: 32),

                  // Titulo
                  Text(
                    'Verificación de Teléfono',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: ModernTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  // Subtitulo
                  Text(
                    'Ingresa el código de 6 dígitos\nenviado al',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: ModernTheme.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Numero de telefono
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '+51 ${widget.phoneNumber}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: ModernTheme.rappiOrange,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Campo OTP mas grande: height 64, width 56, spacing 16
                  PinCodeTextField(
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
                      borderRadius: BorderRadius.circular(14),
                      // Campos OTP mas grandes
                      fieldHeight: 64,
                      fieldWidth: 56,
                      activeFillColor: Theme.of(context).colorScheme.surface,
                      inactiveFillColor: ModernTheme.backgroundLight,
                      selectedFillColor: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                      activeColor: ModernTheme.rappiOrange,
                      inactiveColor: ModernTheme.borderColor,
                      selectedColor: ModernTheme.rappiOrange,
                      errorBorderColor: ModernTheme.error,
                    ),
                    // Spacing entre campos: 16 (via mainAxisAlignment del Row interno)
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    cursorColor: ModernTheme.rappiOrange,
                    textStyle: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: ModernTheme.textPrimary,
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

                  if (_hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'Código incorrecto. Intenta de nuevo.',
                        style: TextStyle(
                          color: ModernTheme.error,
                          fontSize: 14,
                        ),
                      ),
                    ),

                  const SizedBox(height: 36),

                  // Boton verificar
                  AnimatedPulseButton(
                    text: 'Verificar Código',
                    icon: Icons.check_circle,
                    isLoading: _isLoading,
                    onPressed: _isLoading ? null : _verifyOTP,
                  ),

                  const SizedBox(height: 32),

                  // Timer circular + reenviar
                  _buildTimerWidget(),

                  const SizedBox(height: 36),

                  // Informacion de seguridad
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ModernTheme.info.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: ModernTheme.info.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.security,
                          color: ModernTheme.info,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Verificación Segura',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: ModernTheme.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Este código es único y caduca en 10 minutos. No lo compartas con nadie.',
                                style: TextStyle(
                                  color: ModernTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Timer circular en vez de texto plano
  Widget _buildTimerWidget() {
    return Column(
      children: [
        if (!_canResend) ...[
          // Circulo con progreso del timer
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  value: _resendTimer / 60.0,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(ModernTheme.rappiOrange),
                  strokeWidth: 4,
                ),
              ),
              Text(
                '${_resendTimer}s',
                style: TextStyle(
                  color: ModernTheme.rappiOrange,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '¿No recibiste el código?',
            style: TextStyle(
              color: ModernTheme.textSecondary,
              fontSize: 13,
            ),
          ),
        ] else ...[
          Container(
            decoration: BoxDecoration(
              color: ModernTheme.rappiOrange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextButton.icon(
              onPressed: _isLoading ? null : _resendOTP,
              icon: Icon(Icons.refresh, color: ModernTheme.rappiOrange, size: 18),
              label: Text(
                'Reenviar código ahora',
                style: TextStyle(
                  color: ModernTheme.rappiOrange,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}