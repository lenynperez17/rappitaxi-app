// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async' show unawaited;
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/photo_picker.dart';
import '../../core/utils/responsive_bottom_sheet.dart';
import '../../services/driver_registration_draft.dart';
import '../../utils/safe_navigation.dart';

/// Pantalla 2: Datos personales + Selfie
class DriverRegistrationPersonalScreen extends StatefulWidget {
  final String workType;

  const DriverRegistrationPersonalScreen({
    super.key,
    required this.workType,
  });

  @override
  State<DriverRegistrationPersonalScreen> createState() =>
      _DriverRegistrationPersonalScreenState();
}

class _DriverRegistrationPersonalScreenState
    extends State<DriverRegistrationPersonalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _documentController = TextEditingController();
  DateTime? _birthDate;
  File? _selfieImage;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  /// Ronda 286: si hay un alta a medias, se rellena lo que ya se había
  /// escrito y se rescata la selfie que se estuviera tomando cuando Android
  /// mató la app con la cámara abierta. Ver [DriverRegistrationDraft] y
  /// [PhotoPicker].
  Future<void> _restore() async {
    final draft = await DriverRegistrationDraft.load();
    if (draft != null && mounted) {
      final d = draft.data;
      final name = d['fullName'] as String?;
      final document = d['documentNumber'] as String?;
      if (name != null && _nameController.text.isEmpty) {
        _nameController.text = name;
      }
      if (document != null && _documentController.text.isEmpty) {
        _documentController.text = document;
      }
      final birth = DateTime.tryParse((d['birthDate'] as String?) ?? '');
      final selfiePath = d['selfieLocalPath'] as String?;
      final selfie = selfiePath != null ? File(selfiePath) : null;
      setState(() {
        _birthDate ??= birth;
        if (selfie != null && selfie.existsSync()) _selfieImage = selfie;
      });
    }
    final lost = await PhotoPicker.recover(prefix: 'registration.personal.');
    if (lost != null && mounted) await _applySelfie(lost.file);
  }

  /// Guarda la selfie en sitio seguro y la apunta en el borrador al momento,
  /// para que un reinicio en la siguiente foto no se la lleve.
  Future<void> _applySelfie(XFile picked) async {
    final kept = await PhotoPicker.keep(picked, 'selfie');
    if (!mounted) return;
    setState(() => _selfieImage = kept);
    await DriverRegistrationDraft.save(
      step: DriverRegistrationDraft.stepPersonal,
      data: {'workType': widget.workType, 'selfieLocalPath': kept.path},
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _documentController.dispose();
    super.dispose();
  }

  Future<void> _pickSelfie() async {
    final source = await showResponsiveBottomSheet<ImageSource>(
      context: context,
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Elegir de galería'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );

    if (source == null || !mounted) return;

    // Ronda 286: lo escrito hasta ahora se guarda ANTES de abrir la cámara.
    // Es el momento exacto en que Android puede matar la app; si pasa, al
    // volver el nombre y el DNI siguen donde se dejaron.
    await DriverRegistrationDraft.save(
      step: DriverRegistrationDraft.stepPersonal,
      data: {
        'workType': widget.workType,
        if (_nameController.text.isNotEmpty) 'fullName': _nameController.text,
        if (_documentController.text.isNotEmpty)
          'documentNumber': _documentController.text,
        if (_birthDate != null) 'birthDate': _birthDate!.toIso8601String(),
      },
    );
    if (!mounted) return;

    final pickedFile = await PhotoPicker.pick(
      source: source,
      target: 'registration.personal.selfie',
      preferredCameraDevice: CameraDevice.front,
    );

    if (pickedFile != null && mounted) await _applySelfie(pickedFile);
  }

  Future<void> _selectBirthDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1940),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      helpText: 'Selecciona tu fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Seleccionar',
    );

    if (date != null && mounted) {
      setState(() => _birthDate = date);
    }
  }

  bool get _isFormValid {
    return _nameController.text.isNotEmpty &&
        _documentController.text.length >= 8 &&
        _birthDate != null &&
        _selfieImage != null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getSurface(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back, color: AppColors.getTextPrimary(context)),
          onPressed: () => safePopOrHome(context),
        ),
        title: Text(
          'Paso 1 de 4',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.getTextSecondary(context),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tus datos personales',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Necesitamos verificar tu identidad',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
                const SizedBox(height: 32),

                // Foto selfie
                Center(
                  child: GestureDetector(
                    onTap: _pickSelfie,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: AppColors.getInputFill(context),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selfieImage != null
                              ? AppColors.success
                              : AppColors.getBorder(context),
                          width: 3,
                        ),
                        image: _selfieImage != null
                            ? DecorationImage(
                                image: FileImage(_selfieImage!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _selfieImage == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_alt_rounded,
                                  size: 40,
                                  color: AppColors.rappiRed,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tomar selfie',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.rappiRed,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Foto de tu rostro',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Nombre completo
                Text(
                  'Nombre completo',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Ej: Juan Carlos Pérez',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: AppColors.getInputFill(context),
                  ),
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 20),

                // DNI
                Text(
                  'DNI / Documento de identidad',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _documentController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  decoration: InputDecoration(
                    hintText: '12345678',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: AppColors.getInputFill(context),
                  ),
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 20),

                // Fecha de nacimiento
                Text(
                  'Fecha de nacimiento',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _selectBirthDate,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.getInputFill(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.getBorder(context)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          color: AppColors.getTextSecondary(context),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _birthDate != null
                              ? '${_birthDate!.day.toString().padLeft(2, '0')}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.year}'
                              : 'Seleccionar fecha',
                          style: TextStyle(
                            fontSize: 16,
                            color: _birthDate != null
                                ? AppColors.getTextPrimary(context)
                                : AppColors.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Botón Continuar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isFormValid
                        ? () {
                            final data = <String, dynamic>{
                              'workType': widget.workType,
                              'fullName': _nameController.text,
                              'documentNumber': _documentController.text,
                              'birthDate': _birthDate!.toIso8601String(),
                              'selfieLocalPath': _selfieImage!.path,
                            };
                            // Ronda 286: el paso queda guardado antes de
                            // avanzar; si la app muere en el siguiente, esto
                            // no hay que volver a escribirlo.
                            unawaited(DriverRegistrationDraft.save(
                              step: DriverRegistrationDraft.stepVehicle,
                              data: data,
                            ));
                            Navigator.pushNamed(
                              context,
                              '/driver/register/vehicle',
                              arguments: data,
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.rappiRed,
                      disabledBackgroundColor: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Continuar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _isFormValid ? Colors.white : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
