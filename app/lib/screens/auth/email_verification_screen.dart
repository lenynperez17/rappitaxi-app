import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/rt_colors.dart';
import '../../core/design/rt_tokens.dart';
import '../../core/design/rt_typography.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_button.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../utils/firestore_error_handler.dart';
import '../../utils/logger.dart';

/// Pantalla de verificación de email.
///
/// Si el usuario inicio con Google, su email ya esta
/// verificado por el proveedor y se marca automáticamente.
/// Solo usa sendEmailVerification() para registro con email/password.
class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String? loginProvider;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    this.loginProvider,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isVerifying = false;
  bool _canResend = false;
  int _resendCountdown = 60;
  Timer? _timer;
  Timer? _verificationTimer;
  bool _isDisposed = false;

  bool _emailSentSuccessfully = false;
  bool _isProviderVerified = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVerification();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    _timer = null;
    _verificationTimer?.cancel();
    _verificationTimer = null;
    super.dispose();
  }

  // ════════════════════════════════════════════
  // LOGICA DE VERIFICACION
  // ════════════════════════════════════════════

  Future<void> _initializeVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _errorMessage = 'No hay usuario autenticado');
      return;
    }

    final provider = widget.loginProvider?.toLowerCase() ?? '';
    final isOAuth =
        provider == 'google';

    AppLogger.debug(
        'Verificación email - Provider: $provider, isOAuth: $isOAuth');

    // CASO 1: Email de proveedor OAuth
    if (isOAuth && widget.email.isNotEmpty) {
      AppLogger.info('Email OAuth - marcando como verificado automáticamente');
      await _markEmailAsVerifiedInFirestore();
      return;
    }

    // CASO 2: Usuario tiene email en Firebase Auth
    if (user.email != null &&
        user.email!.isNotEmpty &&
        user.email!.contains('@')) {
      if (user.emailVerified) {
        AppLogger.info('Email ya verificado en Firebase Auth');
        await _markEmailAsVerifiedInFirestore();
        return;
      }
      await _sendVerificationEmail();
      _startVerificationCheck();
      return;
    }

    // CASO 3: Usuario sin email en Firebase Auth (login con teléfono)
    AppLogger.warning('Sin email en Auth - guardando en Firestore sin verificar');

    if (widget.email.isNotEmpty && widget.email.contains('@')) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'email': widget.email,
          'emailVerified': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        setState(() {
          _errorMessage =
              'Tu email ha sido guardado. La verificación por enlace no esta '
              'disponible para cuentas creadas con teléfono. '
              'Podrás verificarlo más tarde.';
        });
        await Future.delayed(const Duration(seconds: 3));
        if (mounted && !_isDisposed) Navigator.of(context).pop(false);
      } catch (e) {
        AppLogger.error('Error guardando email', e);
        setState(() => _errorMessage = FirestoreErrorHandler.getSpanishMessage(e));
      }
    } else {
      setState(() => _errorMessage = 'Email inválido');
    }
  }

  Future<void> _markEmailAsVerifiedInFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String userType = 'passenger';
    String driverStatus = 'pending_documents';
    bool documentVerified = false;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        userType = data['userType'] ?? 'passenger';
        driverStatus = data['driverStatus'] ?? 'pending_documents';
        documentVerified = data['documentVerified'] ?? false;

        await userDoc.reference.update({
          'email': widget.email,
          'emailVerified': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      setState(() => _isProviderVerified = true);

      if (mounted) {
        RtSnackbar.show(context,
            message: 'Email verificado correctamente',
            type: RtSnackbarType.success);
      }

      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted && !_isDisposed) {
        final route = _resolveRoute(userType, driverStatus, documentVerified);
        final authProvider =
            Provider.of<app_auth.AuthProvider>(context, listen: false);
        final navigator = Navigator.of(context);
        await authProvider.refreshUserData();
        if (mounted && !_isDisposed) {
          navigator.pushNamedAndRemoveUntil(route, (r) => false);
        }
      }
    } catch (e) {
      AppLogger.error('Error marcando email como verificado', e);
      setState(() => _errorMessage = FirestoreErrorHandler.getSpanishMessage(e));
    }
  }

  Future<void> _sendVerificationEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await user.sendEmailVerification();
      setState(() {
        _emailSentSuccessfully = true;
        _errorMessage = null;
      });
      _startResendCountdown();
    } catch (e) {
      AppLogger.error('Error enviando email de verificación', e);
      final errorMsg = e.toString();

      if (errorMsg.contains('too-many-requests')) {
        setState(() {
          _emailSentSuccessfully = true;
          _errorMessage = null;
        });
        if (mounted) {
          RtSnackbar.show(context,
              message: 'El email se enviara cuando Firebase lo permita. '
                  'Puedes reintentar en unos minutos.',
              type: RtSnackbarType.warning);
        }
        _startResendCountdown();
        return;
      }

      setState(() => _errorMessage = errorMsg.contains('missing-email')
          ? 'No hay email asociado a esta cuenta.'
          : errorMsg);
      _startResendCountdown();
    }
  }

  void _startResendCountdown() {
    if (!mounted || _isDisposed) return;
    setState(() {
      _canResend = false;
      _resendCountdown = 60;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed || !mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  void _startVerificationCheck() {
    _verificationTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_isDisposed || !mounted) {
        timer.cancel();
        return;
      }
      await _checkEmailVerified();
    });
  }

  Future<void> _checkEmailVerified() async {
    if (!mounted || _isDisposed) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await user.reload();
    } catch (e) {
      AppLogger.error('Error recargando usuario', e);
      return;
    }

    if (!mounted || _isDisposed) return;
    final updatedUser = FirebaseAuth.instance.currentUser;
    if (!(updatedUser?.emailVerified ?? false)) return;

    _verificationTimer?.cancel();
    _verificationTimer = null;

    String userType = 'passenger';
    String driverStatus = 'pending_documents';
    bool documentVerified = false;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(updatedUser!.uid)
          .get();

      if (userDoc.exists) {
        userType = userDoc.data()?['userType'] ?? 'passenger';
        driverStatus = userDoc.data()?['driverStatus'] ?? 'pending_documents';
        documentVerified = userDoc.data()?['documentVerified'] ?? false;
        await userDoc.reference.update({
          'emailVerified': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      AppLogger.error('Error actualizando Firestore', e);
    }

    if (!mounted) return;

    RtSnackbar.show(context,
        message: 'Email verificado exitosamente',
        type: RtSnackbarType.success);

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted || _isDisposed) return;

    final route = _resolveRoute(userType, driverStatus, documentVerified);

    if (userType == 'driver' && driverStatus == 'pending_approval' && mounted) {
      RtSnackbar.show(context,
          message:
              'Tus documentos están en revisión. Puedes usar la app como pasajero.',
          type: RtSnackbarType.info);
    }

    final authProvider =
        Provider.of<app_auth.AuthProvider>(context, listen: false);
    final navigator = Navigator.of(context);
    await authProvider.refreshUserData();
    if (mounted && !_isDisposed) {
      navigator.pushNamedAndRemoveUntil(route, (r) => false);
    }
  }

  Future<void> _resendVerificationEmail() async {
    setState(() => _isVerifying = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          RtSnackbar.show(context,
              message: 'Sesión expirada. Vuelve a iniciar sesión.',
              type: RtSnackbarType.error);
        }
        return;
      }

      if (user.email != null && user.email!.isNotEmpty) {
        await user.sendEmailVerification();
        if (mounted) {
          RtSnackbar.show(context,
              message: 'Email enviado a ${user.email}',
              type: RtSnackbarType.success);
        }
        _startResendCountdown();
      } else {
        throw Exception('No hay email en Firebase Auth');
      }
    } catch (e) {
      AppLogger.error('Error reenviando email', e);
      if (mounted) {
        RtSnackbar.show(context,
            message: FirestoreErrorHandler.getSpanishMessage(e),
            type: RtSnackbarType.error);
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  String _resolveRoute(
      String userType, String driverStatus, bool documentVerified) {
    if (userType == 'driver') {
      if (documentVerified && driverStatus == 'approved') return '/driver/home';
      if (driverStatus == 'pending_approval') return '/passenger/home';
      return '/upgrade-to-driver';
    }
    if (userType == 'admin') return '/admin/dashboard';
    return '/passenger/home';
  }

  // ════════════════════════════════════════════
  // UI
  // ════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isProviderVerified) return _buildSuccessView();
    return _buildMainView();
  }

  Widget _buildSuccessView() {
    return Scaffold(
      backgroundColor: RtColors.success,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(RtSpacing.xl),
              decoration: const BoxDecoration(
                color: RtColors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: RtColors.success, size: 48),
            ),
            const SizedBox(height: RtSpacing.xl),
            Text('Email verificado',
                style: RtTypo.headingLarge.copyWith(color: RtColors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildMainView() {
    return Scaffold(
      appBar: const RtAppBar(variant: RtAppBarVariant.transparent),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: RtSpacing.screenAll,
          child: Column(
            children: [
              const SizedBox(height: RtSpacing.xxxl),
              _buildIcon(),
              const SizedBox(height: RtSpacing.xxl),
              _buildTitle(),
              const SizedBox(height: RtSpacing.sm),
              _buildSubtitle(),
              const SizedBox(height: RtSpacing.xxxl),
              if (_emailSentSuccessfully) ...[
                _buildPrimaryButton(),
                const SizedBox(height: RtSpacing.md),
                _buildResendButton(),
                const SizedBox(height: RtSpacing.xxl),
                _buildSpamHint(),
              ] else if (_errorMessage == null) ...[
                const CircularProgressIndicator(color: RtColors.brand),
                const SizedBox(height: RtSpacing.base),
                Text('Procesando...',
                    style:
                        RtTypo.bodyMedium.copyWith(color: RtColors.neutral500)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    final bool hasError = _errorMessage != null;
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: hasError ? RtColors.warningLight : RtColors.brandSurface,
        shape: BoxShape.circle,
      ),
      child: Icon(
        hasError ? Icons.warning_rounded : Icons.forward_to_inbox_rounded,
        size: 40,
        color: hasError ? RtColors.warningDark : RtColors.brand,
      ),
    );
  }

  Widget _buildTitle() {
    final bool hasError = _errorMessage != null;
    return Text(
      hasError ? 'Atencion' : 'Verifica tu email',
      style: RtTypo.headingLarge.copyWith(color: RtColors.neutral900),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSubtitle() {
    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: RtSpacing.base),
        child: Text(
          _errorMessage!,
          style: RtTypo.bodyMedium.copyWith(color: RtColors.warningDark),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: [
        Text(
          'Enviamos un enlace de verificación a:',
          style: RtTypo.bodyMedium.copyWith(color: RtColors.neutral500),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: RtSpacing.xs),
        Text(
          widget.email,
          style: RtTypo.titleLarge
              .copyWith(color: RtColors.neutral900, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPrimaryButton() {
    return RtButton(
      label: 'Ya verifique mi email',
      icon: Icons.check_circle_outline_rounded,
      isLoading: _isVerifying,
      onPressed: () async {
        setState(() => _isVerifying = true);
        await _checkEmailVerified();
        if (mounted) setState(() => _isVerifying = false);
      },
    );
  }

  Widget _buildResendButton() {
    final label = _canResend
        ? 'Reenviar email'
        : 'Reenviar en ${_resendCountdown}s';

    return RtButton(
      label: label,
      variant: RtButtonVariant.ghost,
      icon: Icons.refresh_rounded,
      isLoading: _isVerifying,
      onPressed: _canResend ? _resendVerificationEmail : null,
    );
  }

  Widget _buildSpamHint() {
    return Container(
      padding: RtSpacing.paddingBase,
      decoration: BoxDecoration(
        color: RtColors.warningLight,
        borderRadius: RtRadius.borderMd,
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: RtColors.warningDark, size: RtIconSize.sm),
          const SizedBox(width: RtSpacing.sm),
          Expanded(
            child: Text(
              'No ves el email? Revisa tu carpeta de spam',
              style: RtTypo.bodySmall.copyWith(color: RtColors.warningDark),
            ),
          ),
        ],
      ),
    );
  }
}
