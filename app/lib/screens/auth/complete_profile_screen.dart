import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/design/rt_colors.dart';
import '../../core/design/rt_tokens.dart';
import '../../core/design/rt_typography.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_button.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../core/widgets/rt_text_field.dart';
import '../../providers/auth_provider.dart';
import '../../utils/firestore_error_handler.dart';
import '../../utils/logger.dart';

/// Pantalla para completar el perfil después de login social o teléfono.
///
/// Flujo simplificado de 2 pasos:
/// - Si vino de Google (y no tiene teléfono):
///   Paso 0: Pedir teléfono + verificar OTP
///   Paso 1: Pedir nombre completo (si no lo tiene) + seleccionar tipo de cuenta
///
/// - Si vino de Teléfono (y no tiene nombre):
///   Paso 0: Pedir nombre completo + email (opcional)
///   Paso 1: Seleccionar tipo de cuenta (pasajero/conductor)
///
/// Sin paso de contraseña. Sin verificación de email obligatoria.
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
  // Control de pasos
  int _currentStep = 0;

  // Controllers
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  // Estados generales
  bool _isLoading = false;

  // Estados de verificación de teléfono (solo para flujo Google)
  bool _isOTPSent = false;
  bool _isPhoneVerified = false;

  // Estado de nombre (si ya lo tiene de Google)
  bool _hasName = false;

  // Tipo de cuenta seleccionado
  String _selectedAccountType = 'passenger';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // ======================================================
  // INICIALIZACION
  // ======================================================

  /// Carga datos iniciales del usuario desde Firebase Auth y Firestore
  Future<void> _loadInitialData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    setState(() => _isLoading = true);

    try {
      String? phone;
      String? fullName;
      String? email;
      bool phoneVerifiedInFirestore = false;

      // Leer datos de Firestore
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          phone = data['phone'] as String?;
          fullName = data['fullName'] as String?;
          email = data['email'] as String?;
          phoneVerifiedInFirestore = data['phoneVerified'] == true;
        }
      } catch (e) {
        AppLogger.error('Error leyendo Firestore en CompleteProfile', e);
      }

      // Buscar nombre en Firebase Auth si no esta en Firestore
      if (fullName == null || fullName.isEmpty) {
        fullName = currentUser.displayName;
      }
      if (fullName == null || fullName.isEmpty) {
        fullName = authProvider.currentUser?.fullName;
      }

      // Buscar email en Firebase Auth si no esta en Firestore
      if (email == null || email.isEmpty) {
        email = currentUser.email;
      }
      if (email == null || email.isEmpty) {
        for (final provider in currentUser.providerData) {
          if (provider.email != null && provider.email!.isNotEmpty) {
            email = provider.email;
            break;
          }
        }
      }
      if (email == null || email.isEmpty) {
        email = authProvider.currentUser?.email;
      }

      setState(() {
        // Pre-llenar campos con datos existentes
        if (phone != null && phone.isNotEmpty) {
          _phoneController.text = phone;
        }
        if (fullName != null && fullName.isNotEmpty) {
          _nameController.text = fullName;
          _hasName = true;
        }
        if (email != null && email.isNotEmpty) {
          _emailController.text = email;
        }
        if (phoneVerifiedInFirestore) {
          _isPhoneVerified = true;
        }
      });

      // Determinar paso inicial según el método de login
      final isFromGoogle = widget.loginMethod.toLowerCase() == 'google';

      if (isFromGoogle) {
        // Flujo Google: si ya tiene teléfono verificado, ir directo al paso 1
        if (_isPhoneVerified || (phone != null && phone.isNotEmpty)) {
          setState(() => _currentStep = 1);
        }
      } else {
        // Flujo Teléfono: si ya tiene nombre, ir directo al paso 1
        if (_hasName) {
          setState(() => _currentStep = 1);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ======================================================
  // LOGICA DE TELEFONO (para flujo Google)
  // ======================================================

  Future<void> _sendOTP() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showMsg('Ingresa tu número de teléfono', RtSnackbarType.warning);
      return;
    }
    final clean = phone.replaceAll(' ', '').replaceAll('+', '').replaceAll('51', '');
    if (!RegExp(r'^9\d{8}$').hasMatch(clean)) {
      _showMsg('Ingresa un número peruano válido (9 dígitos)', RtSnackbarType.warning);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final result = await authProvider.startPhoneVerification(clean);
      if (!mounted) return;
      if (result) {
        setState(() => _isOTPSent = true);
        _showMsg('Código enviado. Revisa tus SMS', RtSnackbarType.success);
      } else {
        _showMsg(
          authProvider.errorMessage ?? 'Error al enviar código',
          RtSnackbarType.error,
        );
      }
    } catch (e) {
      AppLogger.error('Error enviando OTP', e);
      if (mounted) {
        _showMsg(FirestoreErrorHandler.getSpanishMessage(e), RtSnackbarType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty || otp.length != 6) {
      _showMsg('Ingresa el código de 6 dígitos', RtSnackbarType.warning);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final result = await authProvider.verifyOTP(otp);
      if (!mounted) return;

      if (result) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          final phone = _phoneController.text
              .trim()
              .replaceAll(' ', '')
              .replaceAll('+', '')
              .replaceAll('51', '');
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .update({
              'phone': phone,
              'phoneVerified': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } catch (e) {
            AppLogger.error('Error guardando teléfono verificado', e);
          }
        }
        setState(() {
          _isPhoneVerified = true;
          _currentStep = 1;
        });
        _showMsg('Teléfono verificado correctamente', RtSnackbarType.success);
      } else {
        _showMsg(
          authProvider.errorMessage ?? 'Código incorrecto',
          RtSnackbarType.error,
        );
      }
    } catch (e) {
      AppLogger.error('Error verificando OTP', e);
      if (mounted) {
        _showMsg(FirestoreErrorHandler.getSpanishMessage(e), RtSnackbarType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Omitir verificación de teléfono: guarda el número sin verificar y avanza
  void _skipPhoneVerification() {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showMsg('Primero ingresa tu número de teléfono', RtSnackbarType.warning);
      return;
    }
    final clean = phone.replaceAll(' ', '').replaceAll('+', '').replaceAll('51', '');
    if (!RegExp(r'^9\d{8}$').hasMatch(clean)) {
      _showMsg('Ingresa un número peruano válido', RtSnackbarType.warning);
      return;
    }
    setState(() => _currentStep = 1);
    _showMsg('Podrás verificar tu teléfono desde tu perfil', RtSnackbarType.info);
  }

  // ======================================================
  // COMPLETAR PERFIL (paso final)
  // ======================================================

  /// Guarda todos los datos pendientes y navega al home según tipo de cuenta
  Future<void> _completeProfile() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showMsg('Sesión expirada. Inicia sesión de nuevo.', RtSnackbarType.error);
        setState(() => _isLoading = false);
        return;
      }

      // Recopilar datos a guardar
      final Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
        'userType': _selectedAccountType,
      };

      // Guardar teléfono si se proporciono
      final phone = _phoneController.text
          .trim()
          .replaceAll(' ', '')
          .replaceAll('+', '')
          .replaceAll('51', '');
      if (phone.isNotEmpty) {
        updates['phone'] = phone;
        if (_isPhoneVerified) {
          updates['phoneVerified'] = true;
        }
      }

      // Guardar nombre si se proporciono
      final name = _nameController.text.trim();
      if (name.isNotEmpty) {
        updates['fullName'] = name;
      }

      // Guardar email si se proporciono
      final email = _emailController.text.trim();
      if (email.isNotEmpty && email.contains('@')) {
        updates['email'] = email;
      }

      // Configurar campos especificos de conductor si aplica
      if (_selectedAccountType == 'driver') {
        updates['driverStatus'] = 'pending_documents';
        updates['documentVerified'] = false;
      }

      // Guardar en Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update(updates);

      // Refrescar datos locales del provider
      await authProvider.refreshUserData();

      if (!mounted) return;
      _showMsg('Perfil completado correctamente', RtSnackbarType.success);
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      // Navegar según tipo de cuenta
      final user = authProvider.currentUser;
      String route;
      if (user != null && user.isAdmin) {
        route = '/admin/dashboard';
      } else if (_selectedAccountType == 'driver') {
        route = '/upgrade-to-driver';
      } else {
        route = '/passenger/home';
      }

      Navigator.pushReplacementNamed(context, route);
    } catch (e) {
      AppLogger.error('Error completando perfil', e);
      if (mounted) {
        _showMsg(FirestoreErrorHandler.getSpanishMessage(e), RtSnackbarType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ======================================================
  // HELPERS
  // ======================================================

  void _showMsg(String message, RtSnackbarType type) {
    if (!mounted) return;
    RtSnackbar.show(context, message: message, type: type);
  }

  bool get _isFromGoogle => widget.loginMethod.toLowerCase() == 'google';

  // ======================================================
  // UI PRINCIPAL
  // ======================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          _showMsg(
            'Recuerda completar tu perfil para usar todas las funciones',
            RtSnackbarType.info,
          );
        }
      },
      child: Scaffold(
        appBar: const RtAppBar(
          title: 'Completa tu perfil',
          variant: RtAppBarVariant.transparent,
        ),
        body: _isLoading && _currentStep == 0 && !_isOTPSent
            ? const Center(child: CircularProgressIndicator(color: RtColors.brand))
            : SafeArea(
                child: Column(
                  children: [
                    _buildProgressBar(),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: RtDuration.normal,
                        switchInCurve: RtCurve.enter,
                        switchOutCurve: RtCurve.exit,
                        child: _buildCurrentStep(),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // ======================================================
  // PROGRESS BAR - 2 pasos
  // ======================================================

  Widget _buildProgressBar() {
    final List<String> labels;
    final List<IconData> icons;

    if (_isFromGoogle) {
      labels = ['Teléfono', 'Tipo de cuenta'];
      icons = [Icons.phone_rounded, Icons.person_rounded];
    } else {
      labels = ['Datos personales', 'Tipo de cuenta'];
      icons = [Icons.badge_rounded, Icons.person_rounded];
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RtSpacing.xxl,
        vertical: RtSpacing.base,
      ),
      child: Column(
        children: [
          // Dots y linea
          Row(
            children: [
              _buildDot(0),
              _buildLine(0),
              _buildDot(1),
            ],
          ),
          const SizedBox(height: RtSpacing.sm),
          // Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(2, (i) {
              final isActive = _currentStep >= i;
              return Column(
                children: [
                  Icon(
                    icons[i],
                    size: RtIconSize.xs,
                    color: isActive ? RtColors.brand : RtColors.neutral400,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    labels[i],
                    style: RtTypo.labelSmall.copyWith(
                      color: isActive ? RtColors.neutral900 : RtColors.neutral400,
                    ),
                  ),
                ],
              );
            }),
          ),
          // Badge del método de login
          const SizedBox(height: RtSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: RtSpacing.md,
              vertical: RtSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: RtColors.brandSurface,
              borderRadius: RtRadius.borderFull,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isFromGoogle ? Icons.g_mobiledata : Icons.phone_rounded,
                  size: RtIconSize.xs,
                  color: RtColors.brand,
                ),
                const SizedBox(width: RtSpacing.xs),
                Text(
                  'Login con ${_isFromGoogle ? "Google" : "Teléfono"}',
                  style: RtTypo.labelSmall.copyWith(color: RtColors.brand),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int step) {
    final bool isCompleted = _currentStep > step;
    final bool isActive = _currentStep == step;

    Color bgColor;
    Color iconColor;

    if (isCompleted) {
      bgColor = RtColors.success;
      iconColor = RtColors.white;
    } else if (isActive) {
      bgColor = RtColors.brand;
      iconColor = RtColors.white;
    } else {
      bgColor = RtColors.neutral200;
      iconColor = RtColors.neutral500;
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
      child: Center(
        child: isCompleted
            ? Icon(Icons.check_rounded, size: 16, color: iconColor)
            : Text(
                '${step + 1}',
                style: RtTypo.labelSmall.copyWith(
                  color: iconColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildLine(int step) {
    final bool isCompleted = _currentStep > step;

    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.symmetric(horizontal: RtSpacing.xs),
        decoration: BoxDecoration(
          color: isCompleted ? RtColors.success : RtColors.neutral200,
          borderRadius: RtRadius.borderFull,
        ),
      ),
    );
  }

  // ======================================================
  // CONTENIDO DEL PASO ACTUAL
  // ======================================================

  Widget _buildCurrentStep() {
    if (_isFromGoogle) {
      // Flujo Google: paso 0 = teléfono, paso 1 = nombre + tipo cuenta
      switch (_currentStep) {
        case 0:
          return _buildPhoneStep();
        case 1:
          return _buildAccountTypeStep();
        default:
          return const SizedBox.shrink();
      }
    } else {
      // Flujo Teléfono: paso 0 = nombre + email, paso 1 = tipo cuenta
      switch (_currentStep) {
        case 0:
          return _buildPersonalDataStep();
        case 1:
          return _buildAccountTypeStep();
        default:
          return const SizedBox.shrink();
      }
    }
  }

  // ======================================================
  // PASO TELEFONO (para flujo Google)
  // ======================================================

  Widget _buildPhoneStep() {
    return SingleChildScrollView(
      key: const ValueKey('phone'),
      padding: RtSpacing.screenAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Verifica tu teléfono',
            style: RtTypo.headingMedium.copyWith(color: RtColors.neutral900),
          ),
          const SizedBox(height: RtSpacing.sm),
          Text(
            'Ingresa tu número de celular para recibir un código de verificación por SMS.',
            style: RtTypo.bodyMedium.copyWith(color: RtColors.neutral500),
          ),
          const SizedBox(height: RtSpacing.xl),

          if (_isPhoneVerified)
            _buildVerifiedBanner('Teléfono verificado', _phoneController.text)
          else ...[
            RtTextField(
              controller: _phoneController,
              label: 'Número de teléfono',
              hint: '999 999 999',
              prefixIcon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
              enabled: !_isOTPSent,
              helperText: 'Ingresa tu número peruano de 9 dígitos',
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
            ),
            const SizedBox(height: RtSpacing.base),

            if (!_isOTPSent) ...[
              RtButton(
                label: _isLoading ? 'Enviando...' : 'Enviar código SMS',
                icon: Icons.sms_rounded,
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _sendOTP,
              ),
            ] else ...[
              RtTextField(
                controller: _otpController,
                label: 'Código de verificación',
                hint: '123456',
                prefixIcon: Icons.lock_outline_rounded,
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
              const SizedBox(height: RtSpacing.md),
              RtButton(
                label: _isLoading ? 'Verificando...' : 'Verificar código',
                icon: Icons.check_circle_outline_rounded,
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _verifyOTP,
              ),
              const SizedBox(height: RtSpacing.sm),
              RtButton(
                label: 'Cambiar número',
                variant: RtButtonVariant.ghost,
                icon: Icons.refresh_rounded,
                onPressed: _isLoading
                    ? null
                    : () => setState(() => _isOTPSent = false),
              ),
            ],
            const SizedBox(height: RtSpacing.base),
            RtButton(
              label: 'Verificar después',
              variant: RtButtonVariant.outlined,
              icon: Icons.schedule_rounded,
              onPressed: _isLoading ? null : _skipPhoneVerification,
            ),
            const SizedBox(height: RtSpacing.sm),
            Text(
              'Podrás verificar tu teléfono más tarde desde tu perfil',
              style: RtTypo.bodySmall.copyWith(
                color: RtColors.neutral400,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],

          if (_isPhoneVerified) ...[
            const SizedBox(height: RtSpacing.xl),
            RtButton(
              label: 'Continuar',
              icon: Icons.arrow_forward_rounded,
              onPressed: () => setState(() => _currentStep = 1),
            ),
          ],
        ],
      ),
    );
  }

  // ======================================================
  // PASO DATOS PERSONALES (para flujo Teléfono)
  // ======================================================

  Widget _buildPersonalDataStep() {
    return SingleChildScrollView(
      key: const ValueKey('personal-data'),
      padding: RtSpacing.screenAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Datos personales',
            style: RtTypo.headingMedium.copyWith(color: RtColors.neutral900),
          ),
          const SizedBox(height: RtSpacing.sm),
          Text(
            'Completa tu información para que podamos identificarte.',
            style: RtTypo.bodyMedium.copyWith(color: RtColors.neutral500),
          ),
          const SizedBox(height: RtSpacing.xl),

          // Campo de nombre completo
          RtTextField(
            controller: _nameController,
            label: 'Nombre completo',
            hint: 'Ej: Juan Perez',
            prefixIcon: Icons.person_rounded,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
          ),

          const SizedBox(height: RtSpacing.base),

          // Campo de email (opcional)
          RtTextField(
            controller: _emailController,
            label: 'Correo electronico (opcional)',
            hint: 'tu@email.com',
            prefixIcon: Icons.email_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
          ),

          const SizedBox(height: RtSpacing.sm),
          Text(
            'El email es opcional pero te ayudara a recuperar tu cuenta',
            style: RtTypo.bodySmall.copyWith(
              color: RtColors.neutral400,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: RtSpacing.xl),

          RtButton(
            label: 'Continuar',
            icon: Icons.arrow_forward_rounded,
            onPressed: _isLoading ? null : () {
              // Validar que al menos tenga nombre
              final name = _nameController.text.trim();
              if (name.isEmpty || name.split(' ').length < 2) {
                _showMsg(
                  'Ingresa tu nombre completo (nombre y apellido)',
                  RtSnackbarType.warning,
                );
                return;
              }
              setState(() => _currentStep = 1);
            },
          ),
        ],
      ),
    );
  }

  // ======================================================
  // PASO TIPO DE CUENTA (comun para ambos flujos)
  // ======================================================

  Widget _buildAccountTypeStep() {
    return SingleChildScrollView(
      key: const ValueKey('account-type'),
      padding: RtSpacing.screenAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Si viene de Google y no tiene nombre, pedirlo aqui
          if (_isFromGoogle && !_hasName) ...[
            Text(
              'Tu nombre',
              style: RtTypo.headingMedium.copyWith(color: RtColors.neutral900),
            ),
            const SizedBox(height: RtSpacing.sm),
            RtTextField(
              controller: _nameController,
              label: 'Nombre completo',
              hint: 'Ej: Juan Perez',
              prefixIcon: Icons.person_rounded,
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: RtSpacing.xl),
          ],

          Text(
            'Tipo de cuenta',
            style: RtTypo.headingMedium.copyWith(color: RtColors.neutral900),
          ),
          const SizedBox(height: RtSpacing.sm),
          Text(
            'Selecciona como quieres usar RapiTeam',
            style: RtTypo.bodyMedium.copyWith(color: RtColors.neutral500),
          ),
          const SizedBox(height: RtSpacing.xl),

          // Tarjeta Pasajero
          _buildAccountTypeCard(
            type: 'passenger',
            title: 'Pasajero',
            subtitle: 'Solicita viajes rápidos y seguros',
            icon: Icons.person_rounded,
          ),

          const SizedBox(height: RtSpacing.base),

          // Tarjeta Conductor
          _buildAccountTypeCard(
            type: 'driver',
            title: 'Conductor',
            subtitle: 'Genera ingresos conduciendo con RapiTeam',
            icon: Icons.local_taxi_rounded,
          ),

          const SizedBox(height: RtSpacing.xl),

          RtButton(
            label: _isLoading ? 'Completando perfil...' : 'Completar perfil',
            icon: Icons.check_circle_rounded,
            size: RtButtonSize.large,
            isLoading: _isLoading,
            onPressed: _isLoading ? null : () {
              // Validar nombre si es de Google y no lo tenia
              if (_isFromGoogle && !_hasName) {
                final name = _nameController.text.trim();
                if (name.isEmpty || name.split(' ').length < 2) {
                  _showMsg(
                    'Ingresa tu nombre completo (nombre y apellido)',
                    RtSnackbarType.warning,
                  );
                  return;
                }
              }
              _completeProfile();
            },
          ),

          const SizedBox(height: RtSpacing.base),

          RtButton(
            label: 'Paso anterior',
            variant: RtButtonVariant.ghost,
            icon: Icons.arrow_back_rounded,
            onPressed: () => setState(() => _currentStep = 0),
          ),
        ],
      ),
    );
  }

  /// Tarjeta seleccionable para tipo de cuenta
  Widget _buildAccountTypeCard({
    required String type,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedAccountType == type;

    return GestureDetector(
      onTap: () => setState(() => _selectedAccountType = type),
      child: AnimatedContainer(
        duration: RtDuration.fast,
        padding: RtSpacing.paddingBase,
        decoration: BoxDecoration(
          color: isSelected ? RtColors.brandSurface : RtColors.white,
          borderRadius: RtRadius.borderMd,
          border: Border.all(
            color: isSelected ? RtColors.brand : RtColors.neutral200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? RtColors.brand.withValues(alpha: 0.15)
                    : RtColors.neutral100,
                borderRadius: BorderRadius.circular(RtRadius.sm),
              ),
              child: Icon(
                icon,
                size: RtIconSize.lg,
                color: isSelected ? RtColors.brand : RtColors.neutral500,
              ),
            ),
            const SizedBox(width: RtSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: RtTypo.titleMedium.copyWith(
                      color: isSelected ? RtColors.brand : RtColors.neutral900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: RtTypo.bodySmall.copyWith(
                      color: isSelected ? RtColors.neutral700 : RtColors.neutral500,
                    ),
                  ),
                ],
              ),
            ),
            // Check icon
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: RtColors.brand,
                size: RtIconSize.lg,
              )
            else
              const Icon(
                Icons.radio_button_unchecked_rounded,
                color: RtColors.neutral300,
                size: RtIconSize.lg,
              ),
          ],
        ),
      ),
    );
  }

  // ======================================================
  // WIDGETS COMPARTIDOS
  // ======================================================

  Widget _buildVerifiedBanner(String title, String subtitle) {
    return Container(
      padding: RtSpacing.paddingBase,
      decoration: BoxDecoration(
        color: RtColors.successLight,
        borderRadius: RtRadius.borderMd,
        border: Border.all(color: RtColors.success),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: RtColors.successDark,
            size: RtIconSize.xl,
          ),
          const SizedBox(width: RtSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: RtTypo.titleMedium.copyWith(color: RtColors.successDark),
                ),
                Text(
                  subtitle,
                  style: RtTypo.bodySmall.copyWith(color: RtColors.neutral700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
