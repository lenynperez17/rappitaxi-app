/// Pantalla OTP nueva — usa RapiApiClient (backend Node en VPS + Twilio Verify)
/// Reemplaza a phone_verification_screen.dart (que llamaba Firebase Auth y reCAPTCHA).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/modern_theme.dart';
import '../../services/rapi_api_client.dart';
import '../../utils/logger.dart';
import '../../widgets/rappi_spinner.dart';

class RapiOtpScreen extends StatefulWidget {
  final String phoneNumber;
  const RapiOtpScreen({super.key, required this.phoneNumber});

  @override
  State<RapiOtpScreen> createState() => _RapiOtpScreenState();
}

class _RapiOtpScreenState extends State<RapiOtpScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _ctrl.text.trim();
    if (code.length < 4) {
      setState(() => _errorMsg = 'Ingresa el código completo');
      return;
    }
    setState(() { _loading = true; _errorMsg = null; });
    try {
      final data = await RapiApiClient.instance.verifySmsCode(
        phoneNumber: widget.phoneNumber,
        code: code,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Teléfono verificado exitosamente'),
          backgroundColor: ModernTheme.success,
        ),
      );
      // Usuario phone ya tiene teléfono verificado — va directo al home.
      // Completar profile (nombre, email) puede hacerse desde el perfil después.
      final userType = (data['user']?['userType'] as String?) ?? 'passenger';
      final home = userType == 'driver' ? '/driver/home'
                 : userType == 'admin' ? '/admin/dashboard'
                 : '/passenger/home';
      Navigator.of(context).pushNamedAndRemoveUntil(home, (_) => false);
    } on RapiApiException catch (e) {
      final msg = e.code == 'code_expired' ? 'El código expiró. Solicita uno nuevo.'
               : e.code == 'code_incorrect' ? 'Código incorrecto. Verifica e intenta otra vez.'
               : e.message ?? 'Error verificando el código';
      setState(() => _errorMsg = msg);
    } catch (e) {
      AppLogger.error('[otp] verify failed: $e');
      setState(() => _errorMsg = 'No pudimos verificar el código');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() { _loading = true; _errorMsg = null; });
    try {
      await RapiApiClient.instance.sendSmsCode(widget.phoneNumber);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código reenviado')),
      );
    } on RapiApiException catch (e) {
      setState(() => _errorMsg = e.message ?? 'No pudimos reenviar');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verifica tu teléfono'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text('Ingresa el código enviado a',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(widget.phoneNumber,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
              const SizedBox(height: 32),
              TextField(
                controller: _ctrl,
                enabled: !_loading,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: 10),
                decoration: InputDecoration(
                  hintText: '••••',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: ModernTheme.rappiOrange, width: 1.6),
                  ),
                ),
                onSubmitted: (_) => _verify(),
              ),
              if (_errorMsg != null) ...[
                const SizedBox(height: 8),
                Text(_errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 13), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ModernTheme.rappiOrange,
                    disabledBackgroundColor: Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: _loading ? null : _verify,
                  child: _loading
                    ? const RappiSpinner(size: 22, onDark: true)
                    : const Text('Verificar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loading ? null : _resend,
                child: const Text('Reenviar código', style: TextStyle(color: ModernTheme.rappiOrange)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
