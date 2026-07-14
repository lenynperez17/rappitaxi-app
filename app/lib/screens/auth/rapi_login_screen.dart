/// Pantalla de login (nueva) — 4 métodos únicos:
///   1. Teléfono (Twilio Verify vía backend Node)
///   2. Google Sign-In
///   3. Apple Sign-In (iOS solamente)
///   4. Passkey (WebAuthn — TODO en un release posterior)
///
/// Reemplaza a `modern_login_screen.dart` (que usaba email+password + Firebase).
/// Coordina con `RapiApiClient` para hablar al backend en el VPS.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/theme/modern_theme.dart';
import '../../services/rapi_api_client.dart';
import '../../utils/logger.dart';
import 'rapi_otp_screen.dart';

class RapiLoginScreen extends StatefulWidget {
  const RapiLoginScreen({super.key});

  @override
  State<RapiLoginScreen> createState() => _RapiLoginScreenState();
}

class _RapiLoginScreenState extends State<RapiLoginScreen> {
  final _phoneCtrl = TextEditingController();
  bool _loading = false;
  String? _errorMsg;

  static const String _peruDialCode = '+51';

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  String get _phoneE164 {
    final raw = _phoneCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    return raw.startsWith(_peruDialCode) ? raw : '$_peruDialCode$raw';
  }

  bool get _phoneLooksValid {
    final raw = _phoneCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    return raw.length == 9;
  }

  Future<void> _handleSendCode() async {
    if (!_phoneLooksValid) {
      setState(() => _errorMsg = 'Ingresa un número de 9 dígitos');
      return;
    }
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      await RapiApiClient.instance.sendSmsCode(_phoneE164);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RapiOtpScreen(phoneNumber: _phoneE164),
      ));
    } on RapiApiException catch (e) {
      setState(() => _errorMsg = e.message ?? 'Error enviando código');
    } catch (e) {
      AppLogger.error('[login] send SMS failed: $e');
      setState(() => _errorMsg = 'No pudimos enviar el código. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      // google_sign_in v7 API — usa instance singleton + authenticate()
      final gsi = GoogleSignIn.instance;
      await gsi.initialize();
      final acct = await gsi.authenticate();
      final auth = acct.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        throw const RapiApiException(500, 'no_id_token', 'Google no devolvió id_token');
      }
      final data = await RapiApiClient.instance.loginWithGoogleIdToken(idToken);
      _goHome(data, loginMethod: 'google');
    } on RapiApiException catch (e) {
      setState(() => _errorMsg = e.message ?? 'Error con Google');
    } catch (e) {
      AppLogger.error('[login] Google sign-in failed: $e');
      setState(() => _errorMsg = 'No pudimos iniciar sesión con Google');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final idToken = credential.identityToken;
      if (idToken == null) {
        throw const RapiApiException(500, 'no_identity_token');
      }
      final fullName = [credential.givenName, credential.familyName]
          .where((s) => s != null && s.isNotEmpty)
          .join(' ');
      final data = await RapiApiClient.instance.loginWithAppleIdentityToken(
        identityToken: idToken,
        fullName: fullName.isEmpty ? null : fullName,
      );
      _goHome(data, loginMethod: 'apple');
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        // usuario canceló — no mostrar error
      } else {
        setState(() => _errorMsg = 'No pudimos iniciar sesión con Apple');
      }
    } on RapiApiException catch (e) {
      setState(() => _errorMsg = e.message ?? 'Error con Apple');
    } catch (e) {
      AppLogger.error('[login] Apple sign-in failed: $e');
      setState(() => _errorMsg = 'No pudimos iniciar sesión con Apple');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handlePasskey() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      final auth = PasskeyAuthenticator();
      // 1) Pedir challenge al server
      final beginResp = await RapiApiClient.instance.passkeyAuthenticateBegin();
      final options = beginResp['options'] as Map<String, dynamic>;
      // 2) Invocar autenticador nativo
      final assertion = await auth.authenticate(
        AuthenticateRequestType.fromJson(options),
      );
      // 3) Enviar assertion al server para verificar
      final finish = await RapiApiClient.instance.passkeyAuthenticateFinish({
        'id': assertion.id,
        'rawId': assertion.rawId,
        'type': 'public-key',
        'response': {
          'clientDataJSON': assertion.clientDataJSON,
          'authenticatorData': assertion.authenticatorData,
          'signature': assertion.signature,
          'userHandle': assertion.userHandle,
        },
      });
      _goHome(finish, loginMethod: 'passkey');
    } on RapiApiException catch (e) {
      setState(() => _errorMsg = e.message ?? 'Error con llave de acceso');
    } catch (e) {
      AppLogger.error('[login] Passkey failed: $e');
      setState(() => _errorMsg = 'No pudimos autenticar con llave de acceso');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goHome(Map<String, dynamic> data, {String loginMethod = 'sms'}) {
    final userType = (data['user']?['userType'] as String?) ?? 'passenger';
    final phone = (data['user']?['phone'] as String?) ?? '';
    if (!mounted) return;
    // Solo va a completar perfil si falta el teléfono. Login SMS ya lo tiene.
    if (phone.isEmpty) {
      Navigator.of(context).pushReplacementNamed(
        '/auth/complete-profile',
        arguments: {'loginMethod': loginMethod},
      );
      return;
    }
    switch (userType) {
      case 'driver':
        Navigator.of(context).pushReplacementNamed('/driver/home');
        break;
      case 'admin':
        Navigator.of(context).pushReplacementNamed('/admin/dashboard');
        break;
      default:
        Navigator.of(context).pushReplacementNamed('/passenger/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(builder: (ctx, cons) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: cons.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  _buildLogo(),
                  const SizedBox(height: 16),
                  const Text(
                    'Bienvenido',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ingresa a tu cuenta de Rapi Team',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 32),

                  _buildPhoneField(),
                  const SizedBox(height: 12),
                  _buildContinueButton(),

                  if (_errorMsg != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMsg!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 24),
                  _buildDivider('o continúa con'),
                  const SizedBox(height: 20),

                  _socialButton(
                    icon: 'assets/icons/google.png',
                    label: 'Google',
                    onTap: _loading ? null : _handleGoogleSignIn,
                  ),
                  const SizedBox(height: 12),
                  if (Platform.isIOS)
                    _socialButton(
                      icon: null,
                      iconWidget: const Icon(Icons.apple, size: 22, color: Colors.black),
                      label: 'Apple',
                      onTap: _loading ? null : _handleAppleSignIn,
                    ),
                  if (Platform.isIOS) const SizedBox(height: 12),
                  _socialButton(
                    icon: null,
                    iconWidget: const Icon(Icons.key, size: 22, color: Colors.black87),
                    label: 'Llave de acceso',
                    onTap: _loading ? null : _handlePasskey,
                  ),

                  const SizedBox(height: 32),
                  _buildLegalFooter(),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: Image.asset(
        'assets/images/logo.png',
        width: 88,
        height: 88,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.local_taxi,
          size: 72,
          color: ModernTheme.rappiOrange,
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return TextField(
      controller: _phoneCtrl,
      keyboardType: TextInputType.phone,
      enabled: !_loading,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(9),
      ],
      decoration: InputDecoration(
        prefixIcon: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Center(widthFactor: 0, child: Text('+51', style: TextStyle(fontSize: 16))),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 60, minHeight: 24),
        hintText: '999 888 777',
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ModernTheme.rappiOrange, width: 1.6),
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: ModernTheme.rappiOrange,
          disabledBackgroundColor: Colors.grey.shade300,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        onPressed: _loading ? null : _handleSendCode,
        child: _loading
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text('Continuar con teléfono',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildDivider(String label) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  Widget _socialButton({
    required String? icon,
    Widget? iconWidget,
    required String label,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          foregroundColor: Colors.black87,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconWidget != null) iconWidget
            else if (icon != null)
              Image.asset(icon, width: 22, height: 22,
                errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 24, color: Colors.blueAccent))
            else
              const SizedBox.shrink(),
            const SizedBox(width: 12),
            Text(label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalFooter() {
    return Text.rich(
      TextSpan(
        text: 'Al continuar aceptas los ',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        children: const [
          TextSpan(
            text: 'Términos y Condiciones',
            style: TextStyle(color: ModernTheme.rappiOrange, fontWeight: FontWeight.w600),
          ),
          TextSpan(text: ' y la '),
          TextSpan(
            text: 'Política de Privacidad',
            style: TextStyle(color: ModernTheme.rappiOrange, fontWeight: FontWeight.w600),
          ),
          TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
