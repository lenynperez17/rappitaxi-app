// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'dart:async';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/animated/modern_animated_widgets.dart';

/// Professional screen for changing phone number with OTP verification
///
/// 2-step flow:
/// 1. Step 1: Enter new phone number
/// 2. Step 2: Verify OTP code sent to the new number
class ChangePhoneNumberScreen extends StatefulWidget {
  final String? currentPhoneNumber;
  const ChangePhoneNumberScreen({super.key, this.currentPhoneNumber});
  @override
  State<ChangePhoneNumberScreen> createState() => _ChangePhoneNumberScreenState();
}

class _ChangePhoneNumberScreenState extends State<ChangePhoneNumberScreen>
    with TickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  StreamController<ErrorAnimationType>? _errorController;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  int _currentStep = 1;
  bool _isLoading = false;
  bool _hasError = false;
  String _currentOTP = "";

  Timer? _timer;
  int _resendTimer = 60;
  bool _canResend = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _errorController = StreamController<ErrorAnimationType>();
    _fadeController = AnimationController(duration: Duration(milliseconds: 800), vsync: this);
    _slideController = AnimationController(duration: Duration(milliseconds: 600), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut));
    _slideAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _slideController, curve: Curves.elasticOut));
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
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
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_isDisposed) { timer.cancel(); return; }
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        if (_resendTimer > 0) { _resendTimer--; }
        else { _canResend = true; timer.cancel(); }
      });
    });
  }

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final newPhoneNumber = _phoneController.text.trim();
    final success = await authProvider.startPhoneNumberChange(newPhoneNumber);
    if (!mounted) return;
    if (success) {
      setState(() { _currentStep = 2; _isLoading = false; });
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 12), Expanded(child: Text('Codigo enviado a $newPhoneNumber'))]),
          backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      _showError(authProvider.errorMessage ?? 'Error al enviar el codigo');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOTP() async {
    if (_currentOTP.length != 6) {
      _errorController!.add(ErrorAnimationType.shake);
      _showError('Ingresa el codigo completo de 6 digitos');
      return;
    }
    setState(() { _isLoading = true; _hasError = false; });
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.verifyPhoneNumberChange(_currentOTP);
    if (!mounted) return;
    if (success) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 12), Text('Numero de telefono actualizado')]), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating),
      );
      await Future.delayed(Duration(seconds: 1));
      if (!mounted) return;
      Navigator.pop(context, true);
    } else {
      HapticFeedback.heavyImpact();
      setState(() { _hasError = true; _currentOTP = ""; _isLoading = false; });
      _otpController.clear();
      _errorController!.add(ErrorAnimationType.shake);
      _showError(authProvider.errorMessage ?? 'Codigo invalido, intenta de nuevo');
    }
  }

  Future<void> _resendOTP() async {
    if (!_canResend) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final newPhoneNumber = _phoneController.text.trim();
    final success = await authProvider.startPhoneNumberChange(newPhoneNumber);
    if (!mounted) return;
    if (success) {
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Codigo reenviado a $newPhoneNumber'), backgroundColor: AppColors.rappiOrange, behavior: SnackBarBehavior.floating));
    } else {
      _showError(authProvider.errorMessage ?? 'Error al reenviar el codigo');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [Icon(Icons.error_outline, color: Colors.white), SizedBox(width: 12), Expanded(child: Text(message))]),
        backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          authProvider.cancelPhoneNumberChange();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent, elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: AppColors.getTextPrimary(context)),
            onPressed: () {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              authProvider.cancelPhoneNumberChange();
              Navigator.pop(context);
            },
          ),
          title: Text('Cambiar Numero de Telefono', style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.bold)),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _slideAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildStepIndicator(),
                    SizedBox(height: 32),
                    if (_currentStep == 1) _buildStep1EnterPhoneNumber()
                    else _buildStep2VerifyOTP(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepCircle(1, isActive: _currentStep == 1, isCompleted: _currentStep > 1),
        Container(width: 80, height: 2, color: _currentStep > 1 ? AppColors.rappiOrange : AppColors.getBorder(context)),
        _buildStepCircle(2, isActive: _currentStep == 2, isCompleted: false),
      ],
    );
  }

  Widget _buildStepCircle(int step, {required bool isActive, required bool isCompleted}) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted ? AppColors.success : isActive ? AppColors.rappiOrange : AppColors.getInputFill(context),
        border: Border.all(color: isActive || isCompleted ? AppColors.rappiOrange : AppColors.getBorder(context), width: 2),
      ),
      child: Center(
        child: isCompleted
            ? Icon(Icons.check, color: Colors.white, size: 20)
            : Text('$step', style: TextStyle(color: isActive ? Colors.white : AppColors.getTextSecondary(context), fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Widget _buildStep1EnterPhoneNumber() {
    return Form(
      key: _formKey,
      child: Column(children: [
        Container(width: 120, height: 120, decoration: BoxDecoration(color: AppColors.rappiOrange.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(Icons.phone_android, size: 60, color: AppColors.rappiOrange)),
        SizedBox(height: 32),
        Text('Nuevo Numero de Telefono', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
        SizedBox(height: 12),
        if (widget.currentPhoneNumber != null)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.info_outline, color: AppColors.info, size: 16), SizedBox(width: 8),
              Text('Numero actual: ${widget.currentPhoneNumber!}', style: TextStyle(fontSize: 14, color: AppColors.info, fontWeight: FontWeight.w500)),
            ]),
          ),
        SizedBox(height: 24),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
          decoration: InputDecoration(
            labelText: 'Nuevo numero de telefono',
            hintText: '9XXXXXXXX',
            prefixIcon: Container(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.phone, color: AppColors.rappiOrange), SizedBox(width: 8),
                Text('+51', style: TextStyle(fontSize: 16, color: AppColors.getTextPrimary(context), fontWeight: FontWeight.w600)),
                SizedBox(width: 4),
                Container(width: 1, height: 24, color: AppColors.getBorder(context)),
              ]),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.rappiOrange, width: 2)),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Ingresa el nuevo numero de telefono';
            if (!RegExp(r'^9[0-9]{8}$').hasMatch(value)) return 'Formato invalido. Debe ser 9XXXXXXXX';
            if (value == widget.currentPhoneNumber) return 'El nuevo numero debe ser diferente';
            return null;
          },
        ),
        SizedBox(height: 32),
        AnimatedPulseButton(text: 'Enviar Codigo de Verificacion', icon: Icons.send, isLoading: _isLoading, onPressed: _isLoading ? null : _sendOTP),
        SizedBox(height: 24),
        _buildSecurityInfo(),
      ]),
    );
  }

  Widget _buildStep2VerifyOTP() {
    return Column(children: [
      Container(
        width: 120, height: 120,
        decoration: BoxDecoration(color: AppColors.rappiOrange.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Stack(alignment: Alignment.center, children: [
          Icon(Icons.verified_user, size: 60, color: AppColors.rappiOrange),
          if (_isLoading) CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.rappiOrange)),
        ]),
      ),
      SizedBox(height: 32),
      Text('Verificar Codigo', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
      SizedBox(height: 12),
      Text('Ingresa el codigo de 6 digitos enviado a', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: AppColors.getTextSecondary(context))),
      SizedBox(height: 8),
      Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: AppColors.rappiOrange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
        child: Text('+51 ${_phoneController.text}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
      ),
      SizedBox(height: 40),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: PinCodeTextField(
          appContext: context, length: 6, controller: _otpController,
          animationType: AnimationType.scale, animationDuration: Duration(milliseconds: 200),
          enableActiveFill: true, errorAnimationController: _errorController,
          keyboardType: TextInputType.number, hapticFeedbackTypes: HapticFeedbackTypes.selection,
          pinTheme: PinTheme(
            shape: PinCodeFieldShape.box, borderRadius: BorderRadius.circular(12),
            fieldHeight: 55, fieldWidth: 45,
            activeFillColor: AppColors.getSurface(context), inactiveFillColor: AppColors.getInputFill(context),
            selectedFillColor: AppColors.rappiOrange.withValues(alpha: 0.1),
            activeColor: AppColors.rappiOrange, inactiveColor: AppColors.getBorder(context),
            selectedColor: AppColors.rappiOrange, errorBorderColor: AppColors.error,
          ),
          cursorColor: AppColors.rappiOrange,
          textStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context)),
          onChanged: (value) { setState(() { _currentOTP = value; _hasError = false; }); },
          onCompleted: (value) { _verifyOTP(); },
        ),
      ),
      if (_hasError) Padding(padding: EdgeInsets.only(top: 8), child: Text('Codigo incorrecto, intenta de nuevo', style: TextStyle(color: AppColors.error, fontSize: 14))),
      SizedBox(height: 32),
      AnimatedPulseButton(text: 'Verificar y Actualizar', icon: Icons.check_circle, isLoading: _isLoading, onPressed: _isLoading ? null : _verifyOTP),
      SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('No recibiste el codigo? ', style: TextStyle(color: AppColors.getTextSecondary(context))),
        if (!_canResend) Text('Reenviar en ${_resendTimer}s', style: TextStyle(color: AppColors.rappiOrange, fontSize: 14, fontWeight: FontWeight.w600))
        else TextButton(onPressed: _isLoading ? null : _resendOTP, child: Text('Reenviar ahora', style: TextStyle(color: AppColors.rappiOrange, fontSize: 14, fontWeight: FontWeight.bold))),
      ]),
      SizedBox(height: 16),
      TextButton.icon(
        onPressed: _isLoading ? null : () { setState(() { _currentStep = 1; _currentOTP = ""; _otpController.clear(); _timer?.cancel(); }); },
        icon: Icon(Icons.edit, size: 16), label: Text('Cambiar numero'),
        style: TextButton.styleFrom(foregroundColor: AppColors.getTextSecondary(context)),
      ),
    ]);
  }

  Widget _buildSecurityInfo() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.info.withValues(alpha: 0.3))),
      child: Row(children: [
        Icon(Icons.security, color: AppColors.info, size: 24), SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Cambio seguro', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
          SizedBox(height: 4),
          Text('Te enviaremos un codigo de verificacion al nuevo numero para confirmar tu identidad.', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 12)),
        ])),
      ]),
    );
  }
}
