import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/design/rt_colors.dart';
import '../../core/design/rt_tokens.dart';
import '../../core/design/rt_typography.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_button.dart';
import '../../core/widgets/rt_card.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../core/widgets/rt_text_field.dart';
import '../../utils/firestore_error_handler.dart';
import '../../utils/logger.dart';

// ============================================================
// Pantalla de edicion de perfil
// ============================================================

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userId;

  // Controladores de formulario
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  // FocusNodes para navegación entre campos
  final _nameFocusNode = FocusNode();
  final _lastNameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _emergencyNameFocusNode = FocusNode();
  final _emergencyPhoneFocusNode = FocusNode();

  // Datos del usuario
  String _profileImagePath = '';
  String _birthDate = '';
  String _gender = 'Masculino';
  String _documentType = 'DNI';
  String _documentNumber = '';
  bool _notificationsEnabled = true;
  bool _smsEnabled = false;
  bool _emailPromotions = true;
  bool _locationSharing = true;

  // Estado del formulario
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();

    // Detectar cambios en campos de texto
    final controllers = [
      _nameController,
      _lastNameController,
      _emailController,
      _phoneController,
      _emergencyNameController,
      _emergencyPhoneController,
    ];
    for (final controller in controllers) {
      controller.addListener(_onFieldChanged);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _nameFocusNode.dispose();
    _lastNameFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    _emergencyNameFocusNode.dispose();
    _emergencyPhoneFocusNode.dispose();
    super.dispose();
  }

  void _hideKeyboard() {
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  // ============================================================
  // Carga de datos desde Firebase
  // ============================================================

  Future<void> _loadUserData() async {
    try {
      setState(() => _isLoading = true);

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          RtSnackbar.show(
            context,
            message: 'Usuario no autenticado',
            type: RtSnackbarType.error,
          );
          Navigator.pop(context);
        }
        return;
      }
      _userId = currentUser.uid;

      final userDoc = await _firestore.collection('users').doc(_userId).get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        setState(() {
          _nameController.text = data['firstName'] ?? '';
          _lastNameController.text = data['lastName'] ?? '';
          _emailController.text = data['email'] ?? '';
          _phoneController.text = data['phoneNumber'] ?? '';
          _birthDate = data['birthDate'] ?? '';
          _gender = data['gender'] ?? 'Masculino';
          _documentType = data['documentType'] ?? 'DNI';
          _documentNumber = data['documentNumber'] ?? '';
          _emergencyNameController.text = data['emergencyContactName'] ?? '';
          _emergencyPhoneController.text = data['emergencyContactPhone'] ?? '';
          _profileImagePath = data['profileImage'] ?? '';
          _notificationsEnabled = data['notificationsEnabled'] ?? true;
          _smsEnabled = data['smsEnabled'] ?? false;
          _emailPromotions = data['emailPromotions'] ?? true;
          _locationSharing = data['locationSharing'] ?? true;
        });
      }
    } catch (e) {
      AppLogger.error('Error cargando datos del usuario: $e');
      if (mounted) {
        RtSnackbar.show(
          context,
          message: 'Error al cargar datos del perfil',
          type: RtSnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // Build principal
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final shouldPop = await _onWillPop();
        if (!mounted) return;
        if (shouldPop) navigator.pop();
      },
      child: Scaffold(
        backgroundColor: RtColors.neutral50,
        appBar: RtAppBar(
          title: 'Editar Perfil',
          variant: RtAppBarVariant.gradient,
          actions: [
            if (_hasChanges)
              TextButton(
                onPressed: _isLoading ? null : _saveProfile,
                child: Text(
                  'Guardar',
                  style: RtTypo.labelMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: RtColors.brand),
              )
            : GestureDetector(
                onTap: _hideKeyboard,
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(RtSpacing.base),
                    child: Column(
                      children: [
                        _buildProfileImageSection(),
                        const SizedBox(height: RtSpacing.xxl),
                        _buildPersonalInfoSection(),
                        const SizedBox(height: RtSpacing.xl),
                        _buildContactInfoSection(),
                        const SizedBox(height: RtSpacing.xl),
                        _buildDocumentInfoSection(),
                        const SizedBox(height: RtSpacing.xl),
                        _buildEmergencyContactSection(),
                        const SizedBox(height: RtSpacing.xl),
                        _buildPreferencesSection(),
                        const SizedBox(height: RtSpacing.xxl),
                        _buildSaveButton(),
                        const SizedBox(height: RtSpacing.xxl),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // ============================================================
  // Foto de perfil
  // ============================================================

  Widget _buildProfileImageSection() {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _profileImagePath.isEmpty
                    ? const LinearGradient(
                        colors: [RtColors.brand, RtColors.brandDark],
                      )
                    : null,
                image: _profileImagePath.isNotEmpty
                    ? DecorationImage(
                        image: _profileImagePath.startsWith('http')
                            ? NetworkImage(_profileImagePath) as ImageProvider
                            : FileImage(File(_profileImagePath)),
                        fit: BoxFit.cover,
                      )
                    : null,
                boxShadow: RtShadow.brand(),
              ),
              child: _profileImagePath.isEmpty
                  ? const Icon(Icons.person, size: 60, color: Colors.white)
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _changeProfileImage,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: RtColors.info,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: RtSpacing.base),
        Text(
          'Toca para cambiar foto',
          style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500),
        ),
      ],
    );
  }

  // ============================================================
  // Secciones del formulario
  // ============================================================

  Widget _buildPersonalInfoSection() {
    return _buildSection(
      'Información Personal',
      Icons.person,
      RtColors.info,
      [
        Row(
          children: [
            Expanded(
              child: RtTextField(
                controller: _nameController,
                label: 'Nombres',
                prefixIcon: Icons.person_outline,
                focusNode: _nameFocusNode,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _lastNameFocusNode.requestFocus(),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Ingresa tu nombre';
                  return null;
                },
              ),
            ),
            const SizedBox(width: RtSpacing.base),
            Expanded(
              child: RtTextField(
                controller: _lastNameController,
                label: 'Apellidos',
                prefixIcon: Icons.person_outline,
                focusNode: _lastNameFocusNode,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _emailFocusNode.requestFocus(),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Ingresa tus apellidos';
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: RtSpacing.base),
        GestureDetector(
          onTap: _selectBirthDate,
          child: Container(
            padding: const EdgeInsets.all(RtSpacing.base),
            decoration: BoxDecoration(
              border: Border.all(color: RtColors.neutral300),
              borderRadius: RtRadius.borderMd,
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: RtColors.neutral500),
                const SizedBox(width: RtSpacing.md),
                Expanded(
                  child: Text(
                    _birthDate.isEmpty ? 'Fecha de nacimiento' : _birthDate,
                    style: RtTypo.bodyMedium.copyWith(
                      color: _birthDate.isEmpty
                          ? RtColors.neutral400
                          : RtColors.neutral900,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: RtColors.neutral500),
              ],
            ),
          ),
        ),
        const SizedBox(height: RtSpacing.base),
        DropdownButtonFormField<String>(
          initialValue: _gender,
          decoration: InputDecoration(
            labelText: 'Genero',
            prefixIcon: const Icon(Icons.wc),
            border: OutlineInputBorder(borderRadius: RtRadius.borderMd),
            focusedBorder: OutlineInputBorder(
              borderRadius: RtRadius.borderMd,
              borderSide: const BorderSide(color: RtColors.brand, width: 2),
            ),
          ),
          items: ['Masculino', 'Femenino', 'Otro', 'Prefiero no decir']
              .map((g) => DropdownMenuItem(value: g, child: Text(g)))
              .toList(),
          onChanged: (value) {
            setState(() {
              _gender = value!;
              _hasChanges = true;
            });
          },
        ),
      ],
    );
  }

  Widget _buildContactInfoSection() {
    return _buildSection(
      'Información de Contacto',
      Icons.contact_phone,
      RtColors.brand,
      [
        RtTextField(
          controller: _emailController,
          label: 'Correo electronico',
          prefixIcon: Icons.email_outlined,
          focusNode: _emailFocusNode,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => _phoneFocusNode.requestFocus(),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Ingresa tu email';
            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
              return 'Ingresa un email válido';
            }
            return null;
          },
        ),
        const SizedBox(height: RtSpacing.base),
        // Campo de teléfono con boton para cambiar número
        GestureDetector(
          onTap: () async {
            final result = await Navigator.pushNamed(
              context,
              '/change-phone-number',
              arguments: _phoneController.text.trim(),
            );

            if (result == true && mounted) {
              await _loadUserData();
              if (mounted) {
                RtSnackbar.show(
                  context,
                  message: 'Número actualizado. Recargando perfil...',
                  type: RtSnackbarType.success,
                );
              }
            }
          },
          child: AbsorbPointer(
            child: TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Número de teléfono',
                prefixIcon: const Icon(Icons.phone_outlined),
                suffixIcon: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, color: RtColors.success, size: 20),
                    SizedBox(width: RtSpacing.sm),
                    Icon(Icons.edit, color: RtColors.brand, size: 20),
                    SizedBox(width: RtSpacing.md),
                  ],
                ),
                border: OutlineInputBorder(borderRadius: RtRadius.borderMd),
                focusedBorder: OutlineInputBorder(
                  borderRadius: RtRadius.borderMd,
                  borderSide: const BorderSide(color: RtColors.brand, width: 2),
                ),
                helperText: 'Toca para cambiar tu número de teléfono',
                helperStyle: RtTypo.labelSmall.copyWith(color: RtColors.info),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Ingresa tu teléfono';
                return null;
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentInfoSection() {
    return _buildSection(
      'Documento de Identidad',
      Icons.badge,
      RtColors.accentAmber,
      [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: _documentType,
                decoration: InputDecoration(
                  labelText: 'Tipo',
                  prefixIcon: const Icon(Icons.assignment_ind),
                  border: OutlineInputBorder(borderRadius: RtRadius.borderMd),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: RtRadius.borderMd,
                    borderSide: const BorderSide(color: RtColors.brand, width: 2),
                  ),
                ),
                items: ['DNI', 'Pasaporte', 'Carne de Extranjeria']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _documentType = value!;
                    _hasChanges = true;
                  });
                },
              ),
            ),
            const SizedBox(width: RtSpacing.base),
            Expanded(
              flex: 3,
              child: TextFormField(
                initialValue: _documentNumber,
                decoration: InputDecoration(
                  labelText: 'Número',
                  prefixIcon: const Icon(Icons.numbers),
                  border: OutlineInputBorder(borderRadius: RtRadius.borderMd),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: RtRadius.borderMd,
                    borderSide: const BorderSide(color: RtColors.brand, width: 2),
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Requerido';
                  return null;
                },
                onChanged: (value) {
                  _documentNumber = value;
                  _onFieldChanged();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmergencyContactSection() {
    return _buildSection(
      'Contacto de Emergencia',
      Icons.emergency,
      RtColors.error,
      [
        RtTextField(
          controller: _emergencyNameController,
          label: 'Nombre completo',
          prefixIcon: Icons.person_pin,
          focusNode: _emergencyNameFocusNode,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => _emergencyPhoneFocusNode.requestFocus(),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Ingresa el nombre del contacto';
            }
            return null;
          },
        ),
        const SizedBox(height: RtSpacing.base),
        RtTextField(
          controller: _emergencyPhoneController,
          label: 'Teléfono de emergencia',
          prefixIcon: Icons.phone_in_talk,
          focusNode: _emergencyPhoneFocusNode,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Ingresa el teléfono de emergencia';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPreferencesSection() {
    return _buildSection(
      'Preferencias',
      Icons.settings,
      RtColors.accentPurple,
      [
        _buildSwitchTile(
          'Notificaciones push',
          'Recibir notificaciones en el dispositivo',
          _notificationsEnabled,
          (value) => setState(() {
            _notificationsEnabled = value;
            _hasChanges = true;
          }),
        ),
        _buildSwitchTile(
          'Notificaciones SMS',
          'Recibir actualizaciones por mensaje de texto',
          _smsEnabled,
          (value) => setState(() {
            _smsEnabled = value;
            _hasChanges = true;
          }),
        ),
        _buildSwitchTile(
          'Promociones por email',
          'Recibir ofertas y descuentos por correo',
          _emailPromotions,
          (value) => setState(() {
            _emailPromotions = value;
            _hasChanges = true;
          }),
        ),
        _buildSwitchTile(
          'Compartir ubicación',
          'Permitir compartir ubicación durante viajes',
          _locationSharing,
          (value) => setState(() {
            _locationSharing = value;
            _hasChanges = true;
          }),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title, style: RtTypo.titleSmall),
      subtitle: Text(
        subtitle,
        style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500),
      ),
      value: value,
      onChanged: onChanged,
      activeTrackColor: RtColors.brand,
    );
  }

  // ============================================================
  // Widget de seccion reutilizable
  // ============================================================

  Widget _buildSection(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: RtSpacing.base),
          child: Row(
            children: [
              Icon(icon, color: color, size: RtIconSize.sm),
              const SizedBox(width: RtSpacing.sm),
              Text(
                title,
                style: RtTypo.headingSmall.copyWith(color: color),
              ),
            ],
          ),
        ),
        RtCard(
          child: Padding(
            padding: const EdgeInsets.all(RtSpacing.lg),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // Boton guardar
  // ============================================================

  Widget _buildSaveButton() {
    return RtButton(
      label: 'Guardar Cambios',
      isFullWidth: true,
      isLoading: _isLoading,
      onPressed: _hasChanges ? _saveProfile : null,
    );
  }

  // ============================================================
  // Acciones de imagen
  // ============================================================

  void _changeProfileImage() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(RtSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cambiar foto de perfil',
              style: RtTypo.headingSmall.copyWith(color: RtColors.neutral900),
            ),
            const SizedBox(height: RtSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImageOption(
                  icon: Icons.camera_alt,
                  label: 'Cámara',
                  color: RtColors.info,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromCamera();
                  },
                ),
                _buildImageOption(
                  icon: Icons.photo_library,
                  label: 'Galería',
                  color: RtColors.brand,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                ),
                if (_profileImagePath.isNotEmpty)
                  _buildImageOption(
                    icon: Icons.delete,
                    label: 'Eliminar',
                    color: RtColors.error,
                    onTap: () {
                      Navigator.pop(context);
                      _removeProfileImage();
                    },
                  ),
              ],
            ),
            const SizedBox(height: RtSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildImageOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(RtSpacing.base),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: RtSpacing.sm),
          Text(label, style: RtTypo.bodySmall),
        ],
      ),
    );
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _profileImagePath = image.path;
        _hasChanges = true;
      });

      if (mounted) {
        RtSnackbar.show(
          context,
          message: 'Foto tomada desde la cámara',
          type: RtSnackbarType.info,
        );
      }
    } catch (e) {
      AppLogger.error('Error tomando foto: $e');
      if (mounted) {
        RtSnackbar.show(
          context,
          message: FirestoreErrorHandler.getSpanishMessage(e),
          type: RtSnackbarType.error,
        );
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _profileImagePath = image.path;
        _hasChanges = true;
      });

      if (mounted) {
        RtSnackbar.show(
          context,
          message: 'Imagen seleccionada de la galería',
          type: RtSnackbarType.info,
        );
      }
    } catch (e) {
      AppLogger.error('Error seleccionando imagen: $e');
      if (mounted) {
        RtSnackbar.show(
          context,
          message: FirestoreErrorHandler.getSpanishMessage(e),
          type: RtSnackbarType.error,
        );
      }
    }
  }

  void _removeProfileImage() {
    setState(() {
      _profileImagePath = '';
      _hasChanges = true;
    });

    RtSnackbar.show(
      context,
      message: 'Foto de perfil eliminada',
      type: RtSnackbarType.warning,
    );
  }

  // ============================================================
  // Acciones del formulario
  // ============================================================

  Future<void> _selectBirthDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(1990, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: RtColors.brand),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null && mounted) {
      setState(() {
        _birthDate =
            '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}';
        _hasChanges = true;
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
        title: const Text('Descartar cambios?'),
        content: const Text(
          'Tienes cambios sin guardar. Estás seguro de que quieres salir?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          RtButton(
            label: 'Descartar',
            variant: RtButtonVariant.danger,
            size: RtButtonSize.small,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    return shouldDiscard ?? false;
  }

  // ============================================================
  // Guardar perfil
  // ============================================================

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Subir foto a Firebase Storage si es un archivo local
      String? profileImageUrl = _profileImagePath;

      if (_profileImagePath.isNotEmpty &&
          !_profileImagePath.startsWith('http://') &&
          !_profileImagePath.startsWith('https://')) {
        try {
          final file = File(_profileImagePath);
          if (await file.exists()) {
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final storage = FirebaseStorage.instance;
            final profilePhotoRef =
                storage.ref('profile_photos/$_userId/profile_$timestamp.jpg');

            final metadata = SettableMetadata(
              contentType: 'image/jpeg',
              customMetadata: {
                'uploadedBy': _userId!,
                'type': 'profile_photo',
              },
            );

            final uploadTask = await profilePhotoRef.putFile(file, metadata);
            profileImageUrl = await uploadTask.ref.getDownloadURL();
          }
        } catch (e) {
          AppLogger.error('Error subiendo foto de perfil: $e');
        }
      }

      // Guardar datos en Firestore
      await _firestore.collection('users').doc(_userId).update({
        'firstName': _nameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'birthDate': _birthDate,
        'gender': _gender,
        'documentType': _documentType,
        'documentNumber': _documentNumber,
        'emergencyContactName': _emergencyNameController.text.trim(),
        'emergencyContactPhone': _emergencyPhoneController.text.trim(),
        'profileImage': profileImageUrl,
        'notificationsEnabled': _notificationsEnabled,
        'smsEnabled': _smsEnabled,
        'emailPromotions': _emailPromotions,
        'locationSharing': _locationSharing,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasChanges = false;
        });

        RtSnackbar.show(
          context,
          message: 'Perfil actualizado exitosamente',
          type: RtSnackbarType.success,
        );
      }
    } catch (e) {
      AppLogger.error('Error guardando perfil: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        RtSnackbar.show(
          context,
          message: 'Error al actualizar el perfil',
          type: RtSnackbarType.error,
        );
      }
    }
  }
}
