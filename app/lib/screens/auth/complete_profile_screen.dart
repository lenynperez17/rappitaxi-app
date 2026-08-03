// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';

// Ronda 254: todo el flujo de login estaba con colores FIJOS (Colors.white,
// grey.shadeN, black87), asi que un usuario con tema oscuro veia un login
// blanco puro dentro de una app oscura, con texto negro en los botones
// sociales. Ahora usa los getters adaptativos de AppColors.
import '../../core/constants/app_colors.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/utils/home_route_resolver.dart';
import '../../utils/logger.dart';

/// Pantalla mínima para completar perfil tras login social (Google / Apple).
///
/// Único requisito: número de teléfono. El correo ya viene del proveedor y no
/// se pide contraseña (auth por SMS o OAuth). Si el usuario entra con SMS
/// nunca aterriza aquí porque ya tiene el teléfono desde el OTP.
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
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLoading = false;
  bool _otpSent = false;
  String? _nameError;

  /// Ronda 269: si al usuario le falta el nombre, se le pide aquí.
  ///
  /// Quien entra por SMS no da su nombre en ningún momento del alta, así que el
  /// conductor recibía la solicitud a nombre de "Usuario" y en el perfil salía
  /// vacío. En un servicio donde dos desconocidos comparten coche, saber con
  /// quién vas es lo mínimo — y es lo que pidió el cliente en su informe.
  ///
  /// Se resuelve en esta pantalla y no en una nueva porque ya es "el sitio
  /// donde se completa lo que falta": mismo botón de retroceso, misma
  /// protección contra salirse a medias, y el usuario ve un único trámite en
  /// lugar de dos pantallas encadenadas.
  bool get _needsPhone {
    final user = context.read<AuthProvider>().currentUser;
    return user == null || user.phone.isEmpty;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    // Se exige nombre y apellido: un nombre suelto no identifica a nadie ante
    // el conductor, que es para lo que sirve este dato.
    if (name.length < 3 || !name.contains(' ')) {
      setState(() => _nameError = 'Escribe tu nombre y tu apellido');
      return;
    }
    setState(() { _isLoading = true; _nameError = null; });
    try {
      final auth = context.read<AuthProvider>();
      final ok = await auth.updateProfile(fullName: name);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _isLoading = false;
          _nameError = auth.errorMessage ?? 'No pudimos guardar tu nombre';
        });
        return;
      }
      setState(() => _isLoading = false);
      _continueAfterProfileComplete();
    } catch (e) {
      AppLogger.error('[complete-profile] guardar nombre', e);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _nameError = 'No pudimos guardar tu nombre. Revisa tu conexión.';
      });
    }
  }

  /// Sale de esta pantalla hacia donde corresponda una vez el perfil está
  /// completo. Usa el mismo resolutor que el splash y el login, para no volver
  /// a tener tres criterios distintos de enrutado.
  void _continueAfterProfileComplete() {
    if (!mounted) return;
    final user = context.read<AuthProvider>().currentUser;
    Navigator.of(context).pushNamedAndRemoveUntil(
      HomeRouteResolver.resolve(user),
      (_) => false,
    );
  }

  String get _providerName {
    switch (widget.loginMethod.toLowerCase()) {
      case 'google':
        return 'Google';
      case 'apple':
        return 'Apple';
      case 'facebook':
        return 'Facebook';
      default:
        return 'redes sociales';
    }
  }

  IconData get _providerIcon {
    switch (widget.loginMethod.toLowerCase()) {
      case 'google':
        return Icons.g_mobiledata;
      case 'apple':
        return Icons.apple;
      case 'facebook':
        return Icons.facebook;
      default:
        return Icons.login;
    }
  }

  /// Extrae los 9 dígitos peruanos limpios del input del usuario.
  /// Acepta "999 999 999", "+51 999 999 999", "51999999999", etc.
  String _cleanLocalDigits(String raw) {
    return raw.replaceAll(' ', '').replaceAll('+', '').replaceAll(RegExp(r'^51'), '');
  }

  Future<void> _sendOTP() async {
    final local = _cleanLocalDigits(_phoneController.text.trim());
    if (!RegExp(r'^9\d{8}$').hasMatch(local)) {
      _snack('Ingresa un número peruano válido (9 dígitos, empieza con 9)', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      // Endpoint autenticado — no crea sesión nueva; solo envía OTP para
      // asociarlo al user actual (viene de Google/Apple).
      final ok = await auth.sendPhoneCodeForCurrentUser('+51$local');
      if (!mounted) return;
      if (ok) {
        setState(() => _otpSent = true);
        _snack('Código enviado. Revisa tus SMS');
      } else {
        _snack(auth.errorMessage ?? 'No se pudo enviar el código', isError: true);
      }
    } catch (e) {
      AppLogger.error('sendOTP complete_profile', e);
      if (mounted) _snack('Error enviando código', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyAndFinish() async {
    final otp = _otpController.text.trim();
    if (otp.length < 4) {
      _snack('Ingresa el código completo', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      // Verifica el OTP y actualiza el phone del user actual en un solo paso.
      // No crea sesión nueva, no crea user nuevo — usa el JWT actual.
      final ok = await auth.verifyPhoneCodeForCurrentUser(otp);
      if (!mounted) return;
      if (!ok) {
        _snack(auth.errorMessage ?? 'Código incorrecto', isError: true);
        return;
      }

      final user = auth.currentUser;
      if (user == null) {
        _snack('Sesión perdida, vuelve a iniciar', isError: true);
        return;
      }

      final route = user.isAdmin
          ? '/admin/dashboard'
          : (user.activeMode == 'driver' ? '/driver/home' : '/passenger/home');
      Navigator.of(context).pushReplacementNamed(route);
    } catch (e) {
      AppLogger.error('verifyAndFinish complete_profile', e);
      if (mounted) _snack('Error verificando código', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Ronda 195 UX (Ronda 197 fix): manejar back button.
  // Si estamos en el paso OTP → volver al paso phone (no salir).
  // Si estamos en el paso phone → logout + REEMPLAZAR ruta con /login.
  // Antes: Navigator.pop() a stack vacío (llegamos aquí via
  //   pushReplacementNamed desde splash) → pantalla NEGRA.
  Future<void> _goBackFromPhoneStep() async {
    try {
      final auth = context.read<AuthProvider>();
      await auth.logout();
    } catch (e) {
      AppLogger.error('logout on back from complete_profile', e);
    }
    if (!mounted) return;
    // Reemplazar TODA la pila con /login — evita pantalla negra si
    // llegamos aquí por pushReplacementNamed desde splash o rebuild.
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_otpSent) {
          setState(() => _otpSent = false);
          return;
        }
        await _goBackFromPhoneStep();
      },
      child: Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () async {
              if (_otpSent) {
                setState(() => _otpSent = false);
                return;
              }
              await _goBackFromPhoneStep();
            },
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                _buildHeader(),
                const SizedBox(height: 32),
                // El teléfono manda: sin él no hay cuenta utilizable. Una vez
                // resuelto, si falta el nombre se pide aquí mismo.
                if (_needsPhone)
                  (_otpSent ? _buildOtpStep() : _buildPhoneStep())
                else
                  _buildNameStep(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(_providerIcon, size: 44, color: ModernTheme.rappiOrange),
        ),
        const SizedBox(height: 16),
        const Text(
          'Un paso más',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        Text(
          _needsPhone
              ? 'Iniciaste con $_providerName. Necesitamos tu número para completar tu cuenta.'
              : '¿Cómo te llamas? Tu conductor verá este nombre cuando aceptes un viaje.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context)),
        ),
      ],
    );
  }

  Widget _buildNameStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _isLoading ? null : _saveName(),
          decoration: InputDecoration(
            labelText: 'Nombre y apellido',
            hintText: 'Ej. María Torres',
            errorText: _nameError,
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveName,
          style: ElevatedButton.styleFrom(
            backgroundColor: ModernTheme.rappiOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20, width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Continuar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          enabled: !_isLoading,
          decoration: InputDecoration(
            labelText: 'Número de teléfono',
            hintText: '999 999 999',
            prefixText: '+51 ',
            prefixIcon: const Icon(Icons.phone),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            helperText: 'Ingresa tu número peruano de 9 dígitos',
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _sendOTP,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sms),
            label: Text(_isLoading ? 'Enviando...' : 'Enviar código SMS'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.rappiOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Ingresa el código enviado a +51 ${_cleanLocalDigits(_phoneController.text)}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context)),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: '••••',
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _verifyAndFinish,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle),
            label: Text(_isLoading ? 'Verificando...' : 'Verificar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.rappiOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _isLoading
              ? null
              : () => setState(() {
                    _otpSent = false;
                    _otpController.clear();
                  }),
          child: const Text('Cambiar número'),
        ),
      ],
    );
  }
}
