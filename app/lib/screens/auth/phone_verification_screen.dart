import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';

import '../../core/design/rt_colors.dart';
import '../../core/design/rt_tokens.dart';
import '../../core/design/rt_typography.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_button.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../providers/auth_provider.dart';

/// Pantalla de verificación de teléfono con código OTP de 6 dígitos.
class PhoneVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final bool isRegistration;

  const PhoneVerificationScreen({
    super.key,
    required this.phoneNumber,
    this.isRegistration = false,
  });

  @override
  State<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen>
    with SingleTickerProviderStateMixin {
  final _otpController = TextEditingController();
  StreamController<ErrorAnimationType>? _errorController;
  late AnimationController _animationController;

  bool _isLoading = false;
  bool _hasError = false;
  String _currentOTP = '';
  bool _isDisposed = false;

  // Timer de reenvio
  Timer? _timer;
  int _resendTimer = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _errorController = StreamController<ErrorAnimationType>();
    _animationController = AnimationController(
      duration: RtDuration.emphasis,
      vsync: this,
    )..forward();

    _startResendTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPhoneVerification();
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    _timer = null;
    _errorController?.close();
    _errorController = null;
    _otpController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════
  // LOGICA
  // ════════════════════════════════════════════

  void _startResendTimer() {
    _canResend = false;
    _resendTimer = 60;
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed || !mounted) {
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

  Future<void> _startPhoneVerification() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _isLoading = true);

    final success =
        await authProvider.startPhoneVerification(widget.phoneNumber);

    if (!mounted) return;

    if (!success && authProvider.errorMessage != null) {
      RtSnackbar.show(context,
          message: authProvider.errorMessage!, type: RtSnackbarType.error);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _verifyCode() async {
    if (_currentOTP.length != 6) {
      _errorController?.add(ErrorAnimationType.shake);
      RtSnackbar.show(context,
          message: 'Ingresa el código completo de 6 dígitos',
          type: RtSnackbarType.warning);
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
      HapticFeedback.mediumImpact();
      RtSnackbar.show(context,
          message: 'Teléfono verificado exitosamente',
          type: RtSnackbarType.success);

      final user = authProvider.currentUser;

      if (user == null || user.fullName.isEmpty || user.email.isEmpty) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/auth/complete-profile',
          (route) => false,
          arguments: {
            'phoneNumber': widget.phoneNumber,
            'isRegistration': widget.isRegistration,
          },
        );
      } else {
        final targetRoute =
            user.userType == 'driver' ? '/driver/home' : '/passenger/home';
        Navigator.pushNamedAndRemoveUntil(context, targetRoute, (r) => false);
      }
    } else {
      _errorController?.add(ErrorAnimationType.shake);
      HapticFeedback.heavyImpact();
      setState(() {
        _hasError = true;
        _currentOTP = '';
      });
      _otpController.clear();
      RtSnackbar.show(context,
          message: authProvider.errorMessage ?? 'Código inválido',
          type: RtSnackbarType.error);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _resendCode() async {
    if (!_canResend) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _isLoading = true);

    final success = await authProvider.resendOTP();
    if (!mounted) return;

    if (success) {
      _startResendTimer();
      RtSnackbar.show(context,
          message: 'Código reenviado a +51 ${widget.phoneNumber}',
          type: RtSnackbarType.success);
    } else {
      RtSnackbar.show(context,
          message: authProvider.errorMessage ?? 'Error al reenviar código',
          type: RtSnackbarType.error);
    }

    setState(() => _isLoading = false);
  }

  // ════════════════════════════════════════════
  // UI
  // ════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const RtAppBar(variant: RtAppBarVariant.transparent),
      body: SafeArea(
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: _animationController,
            curve: RtCurve.enter,
          ),
          child: SingleChildScrollView(
            padding: RtSpacing.screenAll,
            child: Column(
              children: [
                const SizedBox(height: RtSpacing.xxl),
                _buildIcon(),
                const SizedBox(height: RtSpacing.xxl),
                _buildTitle(),
                const SizedBox(height: RtSpacing.sm),
                _buildSubtitle(),
                const SizedBox(height: RtSpacing.xxxl),
                _buildOTPField(),
                if (_hasError) _buildErrorText(),
                const SizedBox(height: RtSpacing.xxl),
                _buildVerifyButton(),
                const SizedBox(height: RtSpacing.lg),
                _buildResendRow(),
                const SizedBox(height: RtSpacing.xxxl),
                _buildSecurityInfo(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 80,
      height: 80,
      decoration: const BoxDecoration(
        color: RtColors.brandSurface,
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.sms_rounded, size: 40, color: RtColors.brand),
          if (_isLoading)
            const SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: RtColors.brand),
            ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      'Verificación',
      style: RtTypo.headingLarge.copyWith(color: RtColors.neutral900),
    );
  }

  Widget _buildSubtitle() {
    return Column(
      children: [
        Text(
          'Ingresa el código de 6 dígitos enviado a',
          style: RtTypo.bodyMedium.copyWith(color: RtColors.neutral500),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: RtSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: RtSpacing.base, vertical: RtSpacing.xs),
          decoration: BoxDecoration(
            color: RtColors.brandSurface,
            borderRadius: RtRadius.borderFull,
          ),
          child: Text(
            '+51 ${widget.phoneNumber}',
            style: RtTypo.titleLarge
                .copyWith(color: RtColors.brand, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildOTPField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: RtSpacing.lg),
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
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        pinTheme: PinTheme(
          shape: PinCodeFieldShape.box,
          borderRadius: RtRadius.borderMd,
          fieldHeight: 55,
          fieldWidth: 45,
          activeFillColor: RtColors.white,
          inactiveFillColor: RtColors.neutral50,
          selectedFillColor: RtColors.brandSurface,
          activeColor: RtColors.brand,
          inactiveColor: RtColors.neutral200,
          selectedColor: RtColors.brand,
          errorBorderColor: RtColors.error,
        ),
        cursorColor: RtColors.brand,
        textStyle: RtTypo.displaySmall.copyWith(color: RtColors.neutral900),
        onChanged: (value) {
          setState(() {
            _currentOTP = value;
            _hasError = false;
          });
        },
        onCompleted: (_) => _verifyCode(),
      ),
    );
  }

  Widget _buildErrorText() {
    return Padding(
      padding: const EdgeInsets.only(top: RtSpacing.sm),
      child: Text(
        'Código incorrecto. Intenta de nuevo.',
        style: RtTypo.bodySmall.copyWith(color: RtColors.error),
      ),
    );
  }

  Widget _buildVerifyButton() {
    return RtButton(
      label: 'Verificar',
      icon: Icons.check_circle_outline_rounded,
      isLoading: _isLoading,
      onPressed: _isLoading ? null : _verifyCode,
    );
  }

  Widget _buildResendRow() {
    if (!_canResend) {
      return Text(
        'Reenviar código en ${_resendTimer}s',
        style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500),
      );
    }

    return RtButton(
      label: 'Reenviar código',
      variant: RtButtonVariant.ghost,
      size: RtButtonSize.small,
      icon: Icons.refresh_rounded,
      isFullWidth: false,
      onPressed: _isLoading ? null : _resendCode,
    );
  }

  Widget _buildSecurityInfo() {
    return Container(
      padding: RtSpacing.paddingBase,
      decoration: BoxDecoration(
        color: RtColors.infoLight,
        borderRadius: RtRadius.borderMd,
        border: Border.all(color: RtColors.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_rounded,
              color: RtColors.infoDark, size: RtIconSize.md),
          const SizedBox(width: RtSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Verificación segura',
                    style: RtTypo.titleMedium
                        .copyWith(color: RtColors.neutral900)),
                const SizedBox(height: RtSpacing.xs),
                Text(
                  'Este código es único y caduca en 10 minutos. No lo compartas con nadie.',
                  style: RtTypo.bodySmall.copyWith(color: RtColors.neutral600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
