import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/design/rt_colors.dart';
import '../../core/design/rt_gradients.dart';
import '../../core/design/rt_tokens.dart';
import '../../core/design/rt_typography.dart';
import '../../core/widgets/rt_loading_state.dart';
import '../../core/widgets/rt_avatar.dart';
import '../../core/widgets/rt_badge.dart';
import '../../core/widgets/rt_button.dart';
import '../../core/widgets/rt_card.dart';
import '../../core/widgets/rt_list_tile.dart';
import '../../core/widgets/rt_section_header.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../core/widgets/rt_stats_card.dart';
import '../../core/widgets/rt_tab_bar.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/firestore_error_handler.dart';
import '../../utils/logger.dart';
import '../auth/email_verification_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthDateController = TextEditingController();

  bool _isEditing = false;
  File? _imageFile;

  // Preferencias
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _promotionsEnabled = false;
  bool _newsEnabled = false;
  String _defaultPayment = 'cash';

  // Estadísticas del usuario (se cargan de Firebase)
  Map<String, dynamic> _userStats = {
    'totalTrips': 0,
    'totalSpent': 0.0,
    'totalDistance': 0.0,
    'savedPlaces': 0,
    'referrals': 0,
    'memberSince': DateTime.now(),
    'rating': 0.0,
    'level': 'Bronze',
    'points': 0,
  };

  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUserProfile());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  // -- Carga de datos -------------------------------------------------------

  Future<void> _loadUserProfile() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      if (user != null) {
        _nameController.text = user.fullName;
        _emailController.text = user.email;
        _phoneController.text = user.phone;
        _birthDateController.text = user.birthDate ?? '';

        final userStats = {
          'totalTrips': user.totalTrips,
          'totalSpent': user.balance,
          'totalDistance': 0.0,
          'savedPlaces': 0,
          'referrals': 0,
          'memberSince': user.createdAt,
          'rating': user.rating,
          'level': _getUserLevel(user.totalTrips),
          'points': user.totalTrips * 10,
        };

        setState(() {
          _userStats = userStats;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando perfil: $e');
      setState(() => _isLoadingProfile = false);
    }
  }

  String _getUserLevel(int totalTrips) {
    if (totalTrips >= 100) return 'Platinum';
    if (totalTrips >= 50) return 'Gold';
    if (totalTrips >= 20) return 'Silver';
    return 'Bronze';
  }

  // -- Guardar perfil -------------------------------------------------------

  Future<void> _saveProfile() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;
      if (currentUser == null) {
        _showMsg('No hay usuario autenticado', RtSnackbarType.error);
        return;
      }

      _showMsg('Guardando cambios...', RtSnackbarType.info);

      final updates = <String, dynamic>{
        'fullName': _nameController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (_birthDateController.text.isNotEmpty) {
        updates['birthDate'] = _birthDateController.text.trim();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.id)
          .update(updates);

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showMsg(AppLocalizations.of(context)!.profileUpdated, RtSnackbarType.success);
      setState(() => _isEditing = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showMsg(FirestoreErrorHandler.getSpanishMessage(e), RtSnackbarType.error);
    }
  }

  // -- Foto de perfil -------------------------------------------------------

  Future<void> _pickImage() async {
    try {
      final l10n = AppLocalizations.of(context)!;
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: RtRadius.sheetTop,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: RtSpacing.md),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: RtColors.neutral300,
                    borderRadius: RtRadius.borderFull,
                  ),
                ),
                const SizedBox(height: RtSpacing.lg),
                Text(l10n.changeProfilePhoto, style: RtTypo.headingSmall),
                const SizedBox(height: RtSpacing.lg),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: RtColors.brand),
                  title: Text(l10n.takePhoto),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: RtColors.brand),
                  title: Text(l10n.chooseFromGallery),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
                if (_imageFile != null)
                  ListTile(
                    leading: const Icon(Icons.delete, color: RtColors.error),
                    title: Text(l10n.deletePhoto),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _imageFile = null);
                      _showMsg(l10n.profilePhotoDeleted, RtSnackbarType.info);
                    },
                  ),
                const SizedBox(height: RtSpacing.md),
              ],
            ),
          ),
        ),
      );

      if (source == null) return;

      if (source == ImageSource.camera) {
        final perm = await Permission.camera.request();
        if (!perm.isGranted) {
          if (!mounted) return;
          _showMsg(AppLocalizations.of(context)!.permissionsNeeded, RtSnackbarType.error);
          return;
        }
      }

      final image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 90,
      );
      if (image == null || !mounted) return;

      setState(() => _imageFile = File(image.path));
      await _uploadProfilePhoto();
    } catch (e) {
      debugPrint('Error seleccionando imagen: $e');
      if (!mounted) return;
      _showMsg(FirestoreErrorHandler.getSpanishMessage(e), RtSnackbarType.error);
    }
  }

  Future<void> _uploadProfilePhoto() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id;
      if (userId == null || _imageFile == null) return;

      _showMsg('Subiendo foto...', RtSnackbarType.info);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance
          .ref('profile_photos/$userId/profile_$timestamp.jpg');
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'uploadedBy': userId, 'type': 'profile_photo'},
      );
      final upload = await ref.putFile(_imageFile!, metadata);
      final url = await upload.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'profilePhotoUrl': url, 'updatedAt': FieldValue.serverTimestamp()});
      await authProvider.updateProfile({'profilePhotoUrl': url});

      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      _showMsg(AppLocalizations.of(context)!.profilePhotoUpdated, RtSnackbarType.success);
    } catch (e) {
      AppLogger.error('Error subiendo foto: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      _showMsg('Error al subir foto: $e', RtSnackbarType.error);
    }
  }

  // -- Verificación ---------------------------------------------------------

  Future<void> _navigateToEmailVerification(AuthProvider authProvider) async {
    final user = authProvider.currentUser;
    if (user == null || user.email.isEmpty) {
      _showMsg('No hay email registrado', RtSnackbarType.error);
      return;
    }
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EmailVerificationScreen(email: user.email)),
    );
    if (result == true && mounted) {
      await authProvider.refreshUserData();
      if (!mounted) return;
      _showMsg('Email verificado exitosamente', RtSnackbarType.success);
    }
  }

  void _navigateToPhoneVerification() {
    Navigator.of(context).pushNamed('/phone-verification');
  }

  // -- Cambiar contraseña ---------------------------------------------------

  void _showChangePasswordDialog() {
    final currentPwCtrl = TextEditingController();
    final newPwCtrl = TextEditingController();
    final confirmPwCtrl = TextEditingController();
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderXl),
        title: Text(l10n.changePasswordTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPwCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.currentPassword,
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: RtRadius.borderMd),
                ),
              ),
              const SizedBox(height: RtSpacing.base),
              TextField(
                controller: newPwCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.newPassword,
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(borderRadius: RtRadius.borderMd),
                  helperText: 'Min. 8 caracteres, mayúsculas, minúsculas, números y símbolos',
                  helperMaxLines: 2,
                ),
              ),
              const SizedBox(height: RtSpacing.base),
              TextField(
                controller: confirmPwCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.confirmNewPassword,
                  prefixIcon: const Icon(Icons.check_circle_outline),
                  border: OutlineInputBorder(borderRadius: RtRadius.borderMd),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              currentPwCtrl.dispose();
              newPwCtrl.dispose();
              confirmPwCtrl.dispose();
              Navigator.pop(ctx);
            },
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPwCtrl.text != confirmPwCtrl.text) {
                _showMsg('Las contraseñas no coinciden', RtSnackbarType.error);
                return;
              }
              final pw = newPwCtrl.text;
              if (pw.length < 8 ||
                  !pw.contains(RegExp(r'[A-Z]')) ||
                  !pw.contains(RegExp(r'[a-z]')) ||
                  !pw.contains(RegExp(r'[0-9]')) ||
                  !pw.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
                _showMsg(
                  'La contraseña debe tener al menos 8 caracteres con mayúsculas, minúsculas, números y caracteres especiales',
                  RtSnackbarType.error,
                );
                return;
              }
              final authProvider = Provider.of<AuthProvider>(ctx, listen: false);
              final nav = Navigator.of(ctx);
              final msg = l10n.passwordUpdated;
              final success = await authProvider.changePassword(currentPwCtrl.text, newPwCtrl.text);
              currentPwCtrl.dispose();
              newPwCtrl.dispose();
              confirmPwCtrl.dispose();
              nav.pop();
              if (success) {
                _showMsg(msg, RtSnackbarType.success);
              } else {
                _showMsg(authProvider.errorMessage ?? 'Error al cambiar contraseña', RtSnackbarType.error);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: RtColors.brand),
            child: Text(l10n.change),
          ),
        ],
      ),
    );
  }

  // -- Eliminar cuenta ------------------------------------------------------

  void _showDeleteAccountDialog() {
    final pwCtrl = TextEditingController();
    bool obscure = true;
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: RtRadius.borderXl),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: RtColors.error, size: 28),
              const SizedBox(width: RtSpacing.md),
              Expanded(child: Text(l10n.deleteAccountTitle, style: RtTypo.headingSmall)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.deleteAccountConfirmation, style: RtTypo.bodyMedium),
                const SizedBox(height: RtSpacing.base),
                Container(
                  padding: RtSpacing.paddingMd,
                  decoration: BoxDecoration(
                    color: RtColors.errorLight,
                    borderRadius: RtRadius.borderMd,
                    border: Border.all(color: RtColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Esta accion es PERMANENTE',
                          style: RtTypo.titleMedium.copyWith(color: RtColors.error)),
                      const SizedBox(height: RtSpacing.sm),
                      Text(
                        'Se eliminaran:\n'
                        '- Tu perfil y datos personales\n'
                        '- Historial de viajes\n'
                        '- Lugares favoritos\n'
                        '- Métodos de pago guardados\n'
                        '- Fotos y documentos',
                        style: RtTypo.bodySmall.copyWith(color: RtColors.neutral600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: RtSpacing.lg),
                Text('Confirma tu contraseña para continuar:', style: RtTypo.titleMedium),
                const SizedBox(height: RtSpacing.sm),
                TextField(
                  controller: pwCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    hintText: 'Ingresa tu contraseña',
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 20),
                      onPressed: () => setDlgState(() => obscure = !obscure),
                    ),
                    border: OutlineInputBorder(borderRadius: RtRadius.borderMd),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                pwCtrl.dispose();
                Navigator.pop(ctx);
              },
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                final password = pwCtrl.text.trim();
                if (password.isEmpty) {
                  _showMsg('Ingresa tu contraseña', RtSnackbarType.error);
                  return;
                }
                Navigator.pop(ctx);
                pwCtrl.dispose();
                await _deleteAccount(password);
              },
              style: ElevatedButton.styleFrom(backgroundColor: RtColors.error),
              child: Text(l10n.delete),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAccount(String password) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Eliminando cuenta...')],
          ),
        )),
      ),
    );

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userModel = authProvider.currentUser;
      if (userModel == null) throw Exception('No hay usuario autenticado');

      final email = userModel.email;
      if (email.isEmpty) throw Exception('Usuario sin email');

      await authProvider.reauthenticateWithPassword(email, password);

      if (userModel.profilePhotoUrl.isNotEmpty && userModel.profilePhotoUrl.contains('firebase')) {
        try {
          await FirebaseStorage.instance.refFromURL(userModel.profilePhotoUrl).delete();
        } catch (_) {}
      }

      final userId = userModel.id;
      final fs = FirebaseFirestore.instance;
      final batch = fs.batch();
      batch.delete(fs.collection('users').doc(userId));

      for (final sub in ['favorites', 'payment_methods']) {
        final snap = await fs.collection('users').doc(userId).collection(sub).get();
        for (var doc in snap.docs) {
          batch.delete(doc.reference);
        }
      }

      final notiSnap = await fs.collection('notifications').where('userId', isEqualTo: userId).get();
      for (var doc in notiSnap.docs) {
        batch.delete(doc.reference);
      }

      final ridesSnap = await fs.collection('rides').where('passengerId', isEqualTo: userId).get();
      for (var doc in ridesSnap.docs) {
        batch.update(doc.reference, {'passengerDeleted': true, 'passengerName': '[Usuario eliminado]'});
      }

      await batch.commit();
      await authProvider.deleteAccount();

      if (mounted) {
        Navigator.pop(context);
        _showMsg('Cuenta eliminada correctamente', RtSnackbarType.success);
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        String msg = 'Error al eliminar la cuenta';
        if (e.toString().contains('wrong-password')) msg = 'Contraseña incorrecta';
        if (e.toString().contains('requires-recent-login')) msg = 'Por seguridad, inicia sesión nuevamente';
        if (e.toString().contains('network')) msg = 'Error de conexión';
        _showMsg(msg, RtSnackbarType.error);
      }
    }
  }

  // -- Privacidad y datos ---------------------------------------------------

  void _showTermsDialog() {
    final l10n = AppLocalizations.of(context)!;
    _showLegalDialog('Términos y Condiciones', Icons.description, [
      _legalSection('1. Aceptación de Términos', 'Al usar la aplicación RapiTeam, aceptas estos términos y condiciones en su totalidad.'),
      _legalSection('2. Servicios Ofrecidos', 'RapiTeam proporciona una plataforma para conectar pasajeros con conductores profesionales.'),
      _legalSection('3. Responsabilidades del Usuario', '- Proporcionar información precisa\n- Mantener la confidencialidad de tu cuenta\n- Cumplir con todas las leyes aplicables\n- Tratar con respeto a conductores y otros usuarios'),
      _legalSection('4. Pagos y Tarifas', 'Las tarifas se calculan en base a distancia, tiempo y demanda. Los precios mostrados son aproximados.'),
      _legalSection('5. Cancelaciones', 'Puedes cancelar un viaje antes de que el conductor llegue. Cancelaciones tardías pueden incurrir en cargos.'),
    ], l10n);
  }

  void _showPrivacyPolicyDialog() {
    final l10n = AppLocalizations.of(context)!;
    _showLegalDialog('Política de Privacidad', Icons.privacy_tip, [
      _legalSection('1. Información que Recopilamos', '- Nombre, email, teléfono\n- Ubicación en tiempo real\n- Historial de viajes\n- Información de pago'),
      _legalSection('2. Como Usamos Tu Información', '- Proveer y mejorar servicios\n- Conectar pasajeros con conductores\n- Procesar pagos\n- Prevenir fraude'),
      _legalSection('3. Seguridad de Datos', 'Implementamos medidas de seguridad técnicas y organizativas para proteger tu información.'),
      _legalSection('4. Tus Derechos', '- Acceder a tu información\n- Corregir datos inexactos\n- Solicitar eliminacion\n- Exportar tus datos'),
      _legalSection('5. Contacto', 'Email: privacy@rapiteam.app\nTeléfono: +51 (01) 555-0123'),
    ], l10n);
  }

  void _showLegalDialog(String title, IconData icon, List<Widget> sections, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderXl),
        title: Row(
          children: [
            Icon(icon, color: RtColors.brand, size: 20),
            const SizedBox(width: RtSpacing.sm),
            Expanded(child: Text(title, style: RtTypo.headingSmall)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: sections)),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: RtColors.brand),
            child: Text(l10n.understood),
          ),
        ],
      ),
    );
  }

  Widget _legalSection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: RtSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: RtTypo.titleLarge.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: RtSpacing.sm),
          Text(body, style: RtTypo.bodyMedium),
        ],
      ),
    );
  }

  Future<void> _openAppSettings() async {
    try {
      final opened = await openAppSettings();
      if (!opened && mounted) {
        _showMsg('Abre Configuración > Apps > RapiTeam manualmente', RtSnackbarType.warning);
      }
    } catch (e) {
      if (mounted) _showMsg('No se pudo abrir la configuración', RtSnackbarType.error);
    }
  }

  Future<void> _exportUserData() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
      final user = authProvider.currentUser;
      if (user == null) {
        _showMsg(AppLocalizations.of(context)!.userInfoError, RtSnackbarType.error);
        return;
      }

      final userData = {
        'exportDate': DateTime.now().toIso8601String(),
        'personalInfo': {
          'userId': user.id,
          'fullName': user.fullName,
          'email': user.email,
          'phone': user.phone,
          'createdAt': user.createdAt.toIso8601String(),
        },
        'statistics': {
          'totalTrips': user.totalTrips,
          'balance': user.balance,
          'rating': user.rating,
          'level': _getUserLevel(user.totalTrips),
          'points': user.totalTrips * 10,
        },
        'preferences': {
          'notificationsEnabled': _notificationsEnabled,
          'soundEnabled': _soundEnabled,
          'vibrationEnabled': _vibrationEnabled,
          'promotionsEnabled': _promotionsEnabled,
          'newsEnabled': _newsEnabled,
          'defaultPayment': _defaultPayment,
          'language': localeProvider.currentLanguageCode,
        },
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(userData);
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/rapiteam_data_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonString);

      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: RtRadius.borderXl),
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: RtColors.success),
              const SizedBox(width: RtSpacing.md),
              const Text('Datos Exportados'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tus datos han sido exportados exitosamente.'),
              const SizedBox(height: RtSpacing.md),
              Text('Ubicación:', style: RtTypo.titleMedium),
              const SizedBox(height: RtSpacing.xs),
              Container(
                padding: RtSpacing.paddingSm,
                decoration: BoxDecoration(color: RtColors.neutral100, borderRadius: RtRadius.borderSm),
                child: Text(file.path, style: RtTypo.bodySmall.copyWith(fontFamily: 'monospace')),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: RtColors.brand),
              child: Text(l10n.understood),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) _showMsg(FirestoreErrorHandler.getSpanishMessage(e), RtSnackbarType.error);
    }
  }

  void _showMsg(String message, RtSnackbarType type) {
    if (!mounted) return;
    RtSnackbar.show(context, message: message, type: type);
  }

  // =========================================================================
  // BUILD
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(RtSpacing.xl),
          child: const RtLoadingState.profile(),
        ),
      );
    }

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (ctx, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: RtColors.brand,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: RtColors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(_isEditing ? Icons.check_rounded : Icons.edit_rounded, color: RtColors.white),
                onPressed: () {
                  if (_isEditing) {
                    _saveProfile();
                  } else {
                    setState(() => _isEditing = true);
                  }
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(background: _buildProfileHeader()),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              RtTabBar(
                tabs: [
                  AppLocalizations.of(context)!.information,
                  AppLocalizations.of(context)!.statistics,
                  AppLocalizations.of(context)!.preferences,
                ],
                controller: _tabController,
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPersonalInfoTab(),
            _buildStatisticsTab(),
            _buildPreferencesTab(),
          ],
        ),
      ),
    );
  }

  // -- Header hero ----------------------------------------------------------

  Widget _buildProfileHeader() {
    return Container(
      decoration: const BoxDecoration(gradient: RtGradients.brand),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 60),
            // Avatar con overlay de cámara y Hero animation
            Hero(
              tag: 'user-avatar',
              child: Material(
                type: MaterialType.transparency,
                child: Stack(
                  children: [
                    Consumer<AuthProvider>(
                      builder: (ctx, auth, _) {
                        final url = auth.currentUser?.profilePhotoUrl;
                        String? imageUrl;
                        if (_imageFile == null && url != null && url.isNotEmpty) {
                          imageUrl = url;
                        }
                        return Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: RtColors.white, width: 3),
                          ),
                          child: _imageFile != null
                              ? ClipOval(
                                  child: Image.file(_imageFile!, width: 100, height: 100, fit: BoxFit.cover),
                                )
                              : RtAvatar(
                                  imageUrl: imageUrl,
                                  name: _nameController.text,
                                  size: RtAvatarSize.xlarge,
                                ),
                        );
                      },
                    ),
                    if (_isEditing)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: RtColors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, color: RtColors.brand, size: 20),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: RtSpacing.md),
            Text(
              _nameController.text,
              style: RtTypo.displaySmall.copyWith(color: RtColors.white),
            ),
            const SizedBox(height: RtSpacing.xs),
            Text(
              _emailController.text,
              style: RtTypo.bodySmall.copyWith(color: RtColors.white.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: RtSpacing.sm),
            RtBadge(
              label: '${_userStats['level']} - ${_userStats['points']} pts',
              color: RtColors.warning,
              icon: Icons.star_rounded,
            ),
          ],
        ),
      ),
    );
  }

  // -- Tab: Información personal --------------------------------------------

  Widget _buildPersonalInfoTab() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: RtSpacing.screenAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Estadísticas rápidas
          Row(
            children: [
              Expanded(
                child: RtStatsCard(
                  label: l10n.totalTrips,
                  value: '${_userStats['totalTrips']}',
                  icon: Icons.route_rounded,
                  iconColor: RtColors.info,
                ),
              ),
              const SizedBox(width: RtSpacing.md),
              Expanded(
                child: RtStatsCard(
                  label: l10n.totalSpent,
                  value: 'S/. ${(_userStats['totalSpent'] as double).toStringAsFixed(2)}',
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: RtColors.success,
                ),
              ),
              const SizedBox(width: RtSpacing.md),
              Expanded(
                child: RtStatsCard(
                  label: l10n.rating,
                  value: '${_userStats['rating']}',
                  icon: Icons.star_rounded,
                  iconColor: RtColors.warning,
                ),
              ),
            ],
          ),

          const SizedBox(height: RtSpacing.xl),

          // Información personal
          RtSectionHeader(title: l10n.personalInformation),
          const SizedBox(height: RtSpacing.md),
          RtCard(
            child: Column(
              children: [
                _infoTile(l10n.fullName, _nameController.text, Icons.person_rounded),
                _infoTile(l10n.email, _emailController.text, Icons.email_rounded),
                RtListTile(
                  title: l10n.phone,
                  subtitle: _phoneController.text,
                  leadingIcon: Icons.phone_rounded,
                  leadingIconColor: RtColors.brand,
                  showChevron: !_isEditing,
                  onTap: !_isEditing
                      ? () async {
                          final result = await Navigator.pushNamed(
                            context,
                            '/change-phone-number',
                            arguments: _phoneController.text.trim(),
                          );
                          if (result == true && mounted) {
                            await _loadUserProfile();
                            if (!mounted) return;
                            _showMsg('Número actualizado correctamente', RtSnackbarType.success);
                          }
                        }
                      : null,
                ),
                _infoTile(l10n.birthDate, _birthDateController.text.isEmpty ? 'Sin registrar' : _birthDateController.text, Icons.calendar_today_rounded),
              ],
            ),
          ),

          const SizedBox(height: RtSpacing.xl),

          // Verificación
          RtSectionHeader(title: l10n.verification),
          const SizedBox(height: RtSpacing.md),
          RtCard(
            child: Column(
              children: [
                Consumer<AuthProvider>(
                  builder: (ctx, auth, _) => _verificationTile(
                    l10n.emailVerified,
                    auth.emailVerified,
                    Icons.email_rounded,
                    onTap: auth.emailVerified ? null : () => _navigateToEmailVerification(auth),
                  ),
                ),
                Consumer<AuthProvider>(
                  builder: (ctx, auth, _) => _verificationTile(
                    l10n.phoneVerified,
                    auth.phoneVerified,
                    Icons.phone_rounded,
                    onTap: auth.phoneVerified ? null : _navigateToPhoneVerification,
                  ),
                ),
                Consumer<AuthProvider>(
                  builder: (ctx, auth, _) => _verificationTile(
                    l10n.identityDocument,
                    auth.documentVerified,
                    Icons.badge_rounded,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: RtSpacing.xl),

          // Acciones
          if (!_isEditing) ...[
            Consumer<AuthProvider>(
              builder: (ctx, auth, child) {
                if (auth.currentUser?.isDualAccount ?? false) return const SizedBox.shrink();
                return child!;
              },
              child: RtCard(
                onTap: () => Navigator.pushNamed(context, '/shared/upgrade-to-driver'),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: RtColors.brand.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.drive_eta_rounded, color: RtColors.brand),
                    ),
                    const SizedBox(width: RtSpacing.base),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppLocalizations.of(context)!.becomeDriver, style: RtTypo.titleLarge),
                          Text(AppLocalizations.of(context)!.earnMoneyDriving,
                              style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: RtColors.neutral400),
                  ],
                ),
              ),
            ),
            const SizedBox(height: RtSpacing.md),
            RtButton(
              label: AppLocalizations.of(context)!.changePassword,
              onPressed: _showChangePasswordDialog,
              variant: RtButtonVariant.outlined,
              icon: Icons.lock_rounded,
            ),
            const SizedBox(height: RtSpacing.md),
            RtButton(
              label: AppLocalizations.of(context)!.deleteAccount,
              onPressed: _showDeleteAccountDialog,
              variant: RtButtonVariant.danger,
              icon: Icons.delete_forever_rounded,
            ),
          ],

          const SizedBox(height: RtSpacing.xxl),
        ],
      ),
    );
  }

  // -- Tab: Estadísticas ----------------------------------------------------

  Widget _buildStatisticsTab() {
    final l10n = AppLocalizations.of(context)!;
    final memberSince = _userStats['memberSince'] as DateTime;

    return SingleChildScrollView(
      padding: RtSpacing.screenAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RtSectionHeader(title: l10n.yourStatistics),
          const SizedBox(height: RtSpacing.base),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: RtSpacing.md,
            crossAxisSpacing: RtSpacing.md,
            childAspectRatio: 1.0,
            children: [
              RtStatsCard(label: l10n.totalTrips, value: '${_userStats['totalTrips']}', icon: Icons.route_rounded, iconColor: RtColors.info),
              RtStatsCard(label: l10n.totalSpent, value: 'S/. ${(_userStats['totalSpent'] as double).toStringAsFixed(2)}', icon: Icons.account_balance_wallet_rounded, iconColor: RtColors.success),
              RtStatsCard(label: l10n.distance, value: '${(_userStats['totalDistance'] as double).toStringAsFixed(1)} km', icon: Icons.map_rounded, iconColor: RtColors.warning),
              RtStatsCard(label: l10n.rating, value: '${_userStats['rating']}', icon: Icons.star_rounded, iconColor: RtColors.accentAmber),
            ],
          ),
          const SizedBox(height: RtSpacing.xl),

          // Logros
          RtSectionHeader(title: l10n.achievementsUnlocked),
          const SizedBox(height: RtSpacing.md),
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _achievementBadge(l10n.frequentTraveler, Icons.flight_takeoff, true),
                _achievementBadge(l10n.punctual, Icons.access_time, true),
                _achievementBadge(l10n.explorer, Icons.explore, true),
                _achievementBadge(l10n.vip, Icons.workspace_premium, false),
                _achievementBadge(l10n.ambassador, Icons.people, false),
              ],
            ),
          ),

          const SizedBox(height: RtSpacing.xl),

          // Info miembro
          RtCard(
            variant: RtCardVariant.outlined,
            child: Column(
              children: [
                RtListTile(
                  title: l10n.memberSince,
                  subtitle: '${memberSince.day}/${memberSince.month}/${memberSince.year}',
                  leadingIcon: Icons.cake_rounded,
                  leadingIconColor: RtColors.brand,
                ),
                RtListTile(
                  title: l10n.referredFriends,
                  subtitle: '${_userStats['referrals']}',
                  leadingIcon: Icons.people_rounded,
                  leadingIconColor: RtColors.brand,
                ),
              ],
            ),
          ),
          const SizedBox(height: RtSpacing.xxl),
        ],
      ),
    );
  }

  // -- Tab: Preferencias ----------------------------------------------------

  Widget _buildPreferencesTab() {
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: RtSpacing.screenAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Notificaciones
          RtSectionHeader(title: l10n.notifications),
          const SizedBox(height: RtSpacing.md),
          RtCard(
            child: Column(
              children: [
                _switchTile(l10n.pushNotifications, l10n.receiveTripAlerts, Icons.notifications_rounded, _notificationsEnabled, (v) => setState(() => _notificationsEnabled = v)),
                _switchTile(l10n.sound, l10n.activateSounds, Icons.volume_up_rounded, _soundEnabled, (v) => setState(() => _soundEnabled = v)),
                _switchTile(l10n.vibration, l10n.vibrateOnNotifications, Icons.vibration, _vibrationEnabled, (v) => setState(() => _vibrationEnabled = v)),
                _switchTile(l10n.promotions, l10n.receiveOffers, Icons.local_offer_rounded, _promotionsEnabled, (v) => setState(() => _promotionsEnabled = v)),
                _switchTile(l10n.newsTitle, l10n.learnNewFeatures, Icons.new_releases_rounded, _newsEnabled, (v) => setState(() => _newsEnabled = v)),
              ],
            ),
          ),

          const SizedBox(height: RtSpacing.xl),

          // Método de pago predeterminado
          RtSectionHeader(title: l10n.travelPreferences),
          const SizedBox(height: RtSpacing.md),
          RtCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RtListTile(
                  title: l10n.defaultPaymentMethod,
                  leadingIcon: Icons.payment_rounded,
                  leadingIconColor: RtColors.brand,
                ),
                const SizedBox(height: RtSpacing.sm),
                Row(
                  children: [
                    _paymentOption(l10n.cash, 'cash', Icons.money_rounded),
                    const SizedBox(width: RtSpacing.sm),
                    _paymentOption(l10n.card, 'card', Icons.credit_card_rounded),
                    const SizedBox(width: RtSpacing.sm),
                    _paymentOption(l10n.wallet, 'wallet', Icons.account_balance_wallet_rounded),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: RtSpacing.md),

          // Idioma
          Consumer<LocaleProvider>(
            builder: (ctx, localeProvider, _) => RtCard(
              child: RtListTile(
                title: l10n.language,
                leadingIcon: Icons.language_rounded,
                leadingIconColor: RtColors.brand,
                trailing: DropdownButton<String>(
                  value: localeProvider.currentLanguageCode,
                  underline: const SizedBox(),
                  isDense: true,
                  items: [
                    DropdownMenuItem(value: 'es', child: Text(l10n.spanish)),
                    DropdownMenuItem(value: 'en', child: Text(l10n.english)),
                  ],
                  onChanged: (value) async {
                    if (value == null) return;
                    final msg = value == 'es' ? 'Idioma cambiado a Español' : 'Language changed to English';
                    await localeProvider.setLocale(Locale(value));
                    if (mounted) _showMsg(msg, RtSnackbarType.success);
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: RtSpacing.xl),

          // Privacidad
          RtSectionHeader(title: l10n.privacyAndSecurity),
          const SizedBox(height: RtSpacing.md),
          RtCard(
            child: Column(
              children: [
                RtListTile(title: l10n.termsAndConditions, leadingIcon: Icons.description_rounded, showChevron: true, onTap: _showTermsDialog),
                RtListTile(title: l10n.privacyPolicy, leadingIcon: Icons.privacy_tip_rounded, showChevron: true, onTap: _showPrivacyPolicyDialog),
                RtListTile(title: l10n.managePermissions, leadingIcon: Icons.security_rounded, showChevron: true, onTap: _openAppSettings),
                RtListTile(title: l10n.exportMyData, leadingIcon: Icons.download_rounded, showChevron: true, onTap: _exportUserData),
              ],
            ),
          ),

          const SizedBox(height: RtSpacing.xxl),
        ],
      ),
    );
  }

  // -- Widgets helper -------------------------------------------------------

  Widget _infoTile(String title, String subtitle, IconData icon) {
    return RtListTile(
      title: title,
      subtitle: subtitle,
      leadingIcon: icon,
      leadingIconColor: RtColors.brand,
    );
  }

  Widget _verificationTile(String title, bool verified, IconData icon, {VoidCallback? onTap}) {
    return RtListTile(
      title: title,
      subtitle: verified ? null : (onTap != null ? 'Toca para verificar' : null),
      leadingIcon: icon,
      leadingIconColor: verified ? RtColors.success : RtColors.neutral400,
      trailing: Icon(
        verified ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded,
        color: verified ? RtColors.success : RtColors.brand,
        size: verified ? 24 : 18,
      ),
      onTap: verified ? null : onTap,
    );
  }

  Widget _switchTile(String title, String subtitle, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return RtListTile(
      title: title,
      subtitle: subtitle,
      leadingIcon: icon,
      leadingIconColor: RtColors.brand,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: RtColors.brand,
      ),
    );
  }

  Widget _paymentOption(String label, String value, IconData icon) {
    final isSelected = _defaultPayment == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _defaultPayment = value);
          _showMsg('${AppLocalizations.of(context)!.paymentMethodPrefix} $label', RtSnackbarType.success);
        },
        borderRadius: RtRadius.borderSm,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: RtSpacing.sm),
          decoration: BoxDecoration(
            color: isSelected ? RtColors.brand.withValues(alpha: 0.1) : RtColors.transparent,
            borderRadius: RtRadius.borderSm,
            border: Border.all(
              color: isSelected ? RtColors.brand : RtColors.neutral300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? RtColors.brand : RtColors.neutral500, size: 20),
              const SizedBox(height: RtSpacing.xs),
              Text(label, style: RtTypo.labelSmall.copyWith(
                color: isSelected ? RtColors.brand : RtColors.neutral500,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _achievementBadge(String title, IconData icon, bool unlocked) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: RtSpacing.md),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: unlocked ? RtColors.brand : RtColors.neutral300,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: RtColors.white, size: 28),
          ),
          const SizedBox(height: RtSpacing.sm),
          Text(
            title,
            style: RtTypo.labelSmall.copyWith(color: unlocked ? RtColors.neutral900 : RtColors.neutral400),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// Delegate para fijar el TabBar en el scroll
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final RtTabBar _tabBar;
  _TabBarDelegate(this._tabBar);

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}
