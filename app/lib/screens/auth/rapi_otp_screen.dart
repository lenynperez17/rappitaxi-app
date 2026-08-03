/// Pantalla OTP nueva — usa RapiApiClient (backend Node en VPS + Twilio Verify)
/// Reemplaza a phone_verification_screen.dart (que llamaba Firebase Auth y reCAPTCHA).
library;

import 'package:flutter/material.dart';

// Ronda 254: todo el flujo de login estaba con colores FIJOS (Colors.white,
// grey.shadeN, black87), asi que un usuario con tema oscuro veia un login
// blanco puro dentro de una app oscura, con texto negro en los botones
// sociales. Ahora usa los getters adaptativos de AppColors.
import '../../core/constants/app_colors.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';

import '../../core/theme/modern_theme.dart';
import '../../core/utils/auth_session_bootstrap.dart';
import '../../core/utils/home_route_resolver.dart';
import '../../providers/auth_provider.dart';
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
      // Ronda 269: dejar la sesión lista antes de navegar (hidrata
      // AuthProvider y abre el canal en vivo). Antes se navegaba con el JSON
      // de la respuesta y el provider quedaba vacío: el menú del pasajero no
      // sabía que la cuenta era de conductor y ofrecía darse de alta a quien
      // ya lo estaba.
      await AuthSessionBootstrap.hydrate(context);
      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();

      // Si falta algún dato obligatorio del perfil (nombre, teléfono), se pide
      // ahora y no se le deja entrar a medias.
      if (authProvider.needsProfileCompletion()) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          HomeRouteResolver.completeProfile,
          (_) => false,
          arguments: {'loginMethod': 'sms'},
        );
        return;
      }

      final user = authProvider.currentUser;
      final home = user != null
          ? HomeRouteResolver.resolve(user)
          : HomeRouteResolver.resolveFromJson(data['user'] as Map<String, dynamic>?);
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
        backgroundColor: AppColors.getBackground(context),
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
                style: TextStyle(fontSize: 16, color: AppColors.getTextSecondary(context)),
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
                  fillColor: AppColors.getInputFill(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.getBorder(context)),
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
                    disabledBackgroundColor: AppColors.getBorder(context),
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
