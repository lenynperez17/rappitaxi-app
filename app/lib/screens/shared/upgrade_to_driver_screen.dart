// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/auth_provider.dart';
import '../../services/rapi_api_client.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive_bottom_sheet.dart';
import '../../widgets/common/rappi_app_bar.dart';

/// Screen for upgrading a passenger to driver (dual-account)
class UpgradeToDriverScreen extends StatefulWidget {
  const UpgradeToDriverScreen({super.key});
  @override
  State<UpgradeToDriverScreen> createState() => _UpgradeToDriverScreenState();
}

class _UpgradeToDriverScreenState extends State<UpgradeToDriverScreen> with SingleTickerProviderStateMixin {
  late AnimationController _contentController;
  final PageController _pageController = PageController();
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  final int _totalSteps = 3;

  final _dniController = TextEditingController();
  final _licenseController = TextEditingController();
  final _plateController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();

  File? _dniPhoto;
  File? _licensePhoto;
  File? _vehiclePhoto;
  File? _criminalRecordPhoto;
  File? _soatPhoto;
  File? _technicalReviewPhoto;
  File? _ownershipPhoto;

  bool _isDniPdf = false;
  bool _isLicensePdf = false;
  bool _isVehiclePdf = false;
  bool _isCriminalRecordPdf = false;
  bool _isSoatPdf = false;
  bool _isTechnicalReviewPdf = false;
  bool _isOwnershipPdf = false;
  bool _isUploading = false;

  @override
  void initState() { super.initState(); _contentController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward(); }

  Widget _animatedSection(Widget child, int index) {
    final delay = (index * 0.15).clamp(0.0, 0.7); final end = (delay + 0.3).clamp(0.0, 1.0);
    final animation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _contentController, curve: Interval(delay, end, curve: Curves.easeOutCubic)));
    return AnimatedBuilder(animation: animation, builder: (context, child) => Transform.translate(offset: Offset(0, 30 * (1 - animation.value)), child: Opacity(opacity: animation.value, child: child)), child: child);
  }

  @override
  void dispose() { _contentController.dispose(); _pageController.dispose(); _dniController.dispose(); _licenseController.dispose(); _plateController.dispose(); _brandController.dispose(); _modelController.dispose(); _yearController.dispose(); _colorController.dispose(); super.dispose(); }

  void _nextStep() { if (_currentStep < _totalSteps - 1 && _validateCurrentStep()) { setState(() { _currentStep++; }); _pageController.animateToPage(_currentStep, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); } }
  void _previousStep() { if (_currentStep > 0) { setState(() { _currentStep--; }); _pageController.animateToPage(_currentStep, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); } }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_dniController.text.isEmpty) { _showError('Por favor ingresa tu numero de documento'); return false; }
        if (_licenseController.text.isEmpty) { _showError('Por favor ingresa tu numero de licencia'); return false; }
        return true;
      case 1:
        if (_plateController.text.isEmpty) { _showError('Por favor ingresa la placa del vehiculo'); return false; }
        if (_brandController.text.isEmpty) { _showError('Por favor ingresa la marca del vehiculo'); return false; }
        if (_modelController.text.isEmpty) { _showError('Por favor ingresa el modelo del vehiculo'); return false; }
        if (_yearController.text.isEmpty) { _showError('Por favor ingresa el ano del vehiculo'); return false; }
        if (_colorController.text.isEmpty) { _showError('Por favor ingresa el color del vehiculo'); return false; }
        return true;
      case 2:
        if (_dniPhoto == null) { _showError('Por favor sube la foto de tu documento'); return false; }
        if (_licensePhoto == null) { _showError('Por favor sube la foto de tu licencia'); return false; }
        if (_vehiclePhoto == null) { _showError('Por favor sube la foto del vehiculo'); return false; }
        if (_criminalRecordPhoto == null) { _showError('Por favor sube tus antecedentes penales'); return false; }
        if (_soatPhoto == null) { _showError('Por favor sube tu SOAT'); return false; }
        if (_technicalReviewPhoto == null) { _showError('Por favor sube tu revision tecnica'); return false; }
        if (_ownershipPhoto == null) { _showError('Por favor sube la tarjeta de propiedad'); return false; }
        return true;
      default: return true;
    }
  }

  void _showError(String message) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating)); }

  Future<void> _submitUpgrade() async {
    if (!_validateCurrentStep()) return;
    setState(() { _isUploading = true; });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final api = RapiApiClient.instance;

      // 1) Actualizar perfil con DNI
      await authProvider.updateProfile(identityDocument: _dniController.text.trim());

      // 2) Crear/actualizar vehículo del conductor
      await api.upsertVehicle(
        vehicleType: 'taxi',
        plate: _plateController.text.trim().toUpperCase(),
        make: _brandController.text.trim(),
        model: _modelController.text.trim(),
        year: int.tryParse(_yearController.text.trim()),
        color: _colorController.text.trim(),
      );

      // 3) Subir cada documento (foto/pdf → fileUrl → uploadDocument)
      final docs = <MapEntry<String, File>>[
        MapEntry('dni_front', _dniPhoto!),
        MapEntry('license_front', _licensePhoto!),
        MapEntry('vehicle_photo', _vehiclePhoto!),
        MapEntry('other', _criminalRecordPhoto!),   // Antecedentes penales
        MapEntry('soat', _soatPhoto!),
        MapEntry('other', _technicalReviewPhoto!),  // Revisión técnica (usa 'other' hasta agregar enum)
        MapEntry('ownership', _ownershipPhoto!),
      ];

      for (final entry in docs) {
        final uploadResp = await api.uploadFile(file: entry.value, scope: 'documents');
        final fileUrl = (uploadResp['url'] ?? uploadResp['fileUrl']) as String?;
        if (fileUrl != null && fileUrl.isNotEmpty) {
          await api.uploadDocument(docType: entry.key, fileUrl: fileUrl);
        }
      }

      // 4) Upgrade a driver (marca al user como dual y refresca perfil)
      final success = await authProvider.upgradeToDriver();
      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registro como conductor exitoso!'), backgroundColor: AppColors.rappiOrange, behavior: SnackBarBehavior.floating));
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/driver/home', (route) => route.isFirst);
      } else { if (!mounted) return; _showError('Error al registrarte como conductor'); }
    } catch (e) { if (!mounted) return; _showError('Error: $e'); }
    finally { if (mounted) { setState(() { _isUploading = false; }); } }
  }

  Future<void> _pickDocument(String type) async {
    try {
      final fileType = await showResponsiveBottomSheet<String>(context: context, builder: (context) => Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Subir $type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
          const SizedBox(height: 8),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text('Puedes subir una foto o un documento PDF', style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context)), textAlign: TextAlign.center)),
          const SizedBox(height: 16),
          ListTile(leading: const Icon(Icons.camera_alt, color: AppColors.rappiOrange), title: Text('Tomar foto'), onTap: () => Navigator.pop(context, 'camera')),
          ListTile(leading: const Icon(Icons.photo_library, color: AppColors.rappiOrange), title: Text('Elegir de galeria'), onTap: () => Navigator.pop(context, 'gallery')),
          ListTile(leading: Icon(Icons.picture_as_pdf, color: AppColors.getTextPrimary(context)), title: Text('Seleccionar PDF'), onTap: () => Navigator.pop(context, 'pdf')),
          const SizedBox(height: 16),
        ]));
      if (fileType == null) return;

      File? selectedFile; bool isPdf = false;
      if (fileType == 'camera' || fileType == 'gallery') {
        final source = fileType == 'camera' ? ImageSource.camera : ImageSource.gallery;
        PermissionStatus permissionStatus;
        if (source == ImageSource.camera) { permissionStatus = await Permission.camera.request(); }
        else { if (await Permission.photos.isGranted || await Permission.photos.isLimited) { permissionStatus = PermissionStatus.granted; } else { permissionStatus = await Permission.photos.request(); if (permissionStatus.isDenied) { permissionStatus = await Permission.storage.request(); } } }
        if (!permissionStatus.isGranted && !permissionStatus.isLimited) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Se necesitan permisos de camara/galeria'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating, action: SnackBarAction(label: 'Configuracion', textColor: Colors.white, onPressed: () => openAppSettings())));
          return;
        }
        final picker = ImagePicker(); final image = await picker.pickImage(source: source, maxWidth: 1920, maxHeight: 1920, imageQuality: 85);
        if (image != null) { selectedFile = File(image.path); isPdf = false; }
      } else if (fileType == 'pdf') {
        PermissionStatus permissionStatus;
        if (await Permission.storage.isGranted) { permissionStatus = PermissionStatus.granted; } else { permissionStatus = await Permission.storage.request(); if (permissionStatus.isDenied) { if (await Permission.photos.isGranted || await Permission.photos.isLimited) { permissionStatus = PermissionStatus.granted; } } }
        if (!permissionStatus.isGranted) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Se necesitan permisos de archivos'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating)); return; }
        final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], allowMultiple: false);
        if (result != null && result.files.isNotEmpty) { selectedFile = File(result.files.first.path!); isPdf = true; }
      }
      if (selectedFile == null) return;
      final fileSize = await selectedFile.length(); const maxSize = 10 * 1024 * 1024;
      if (fileSize > maxSize) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('El archivo es demasiado grande (max 10MB)'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating)); return; }

      final normalizedType = type.toLowerCase().replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i').replaceAll('ó', 'o').replaceAll('ú', 'u');
      setState(() {
        if (normalizedType == 'dni') { _dniPhoto = selectedFile; _isDniPdf = isPdf; }
        else if (normalizedType == 'licencia') { _licensePhoto = selectedFile; _isLicensePdf = isPdf; }
        else if (normalizedType == 'vehiculo') { _vehiclePhoto = selectedFile; _isVehiclePdf = isPdf; }
        else if (normalizedType == 'antecedentes penales') { _criminalRecordPhoto = selectedFile; _isCriminalRecordPdf = isPdf; }
        else if (normalizedType == 'soat') { _soatPhoto = selectedFile; _isSoatPdf = isPdf; }
        else if (normalizedType == 'revision tecnica') { _technicalReviewPhoto = selectedFile; _isTechnicalReviewPdf = isPdf; }
        else if (normalizedType == 'tarjeta de propiedad') { _ownershipPhoto = selectedFile; _isOwnershipPdf = isPdf; }
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.white, size: 20), const SizedBox(width: 12), Expanded(child: Text('$type (${isPdf ? 'PDF' : 'imagen'}) subido correctamente', overflow: TextOverflow.ellipsis, maxLines: 2))]), backgroundColor: AppColors.rappiOrange, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)));
    } catch (e) {
      debugPrint('Error seleccionando documento: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al seleccionar documento: $e'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: RappiAppBar(title: 'Conviertete en Conductor', showBackButton: true),
      body: Column(children: [
        _animatedSection(_buildProgressIndicator(), 0),
        Expanded(child: _animatedSection(PageView(controller: _pageController, physics: const NeverScrollableScrollPhysics(), children: [_buildPersonalInfoStep(), _buildVehicleInfoStep(), _buildDocumentsStep()]), 1)),
        _animatedSection(_buildNavigationButtons(), 2),
      ]),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16), color: AppColors.getSurface(context), child: Row(children: List.generate(_totalSteps, (index) {
      final isCompleted = index < _currentStep; final isCurrent = index == _currentStep;
      return Expanded(child: Row(children: [Expanded(child: Container(height: 4, decoration: BoxDecoration(color: isCompleted || isCurrent ? AppColors.rappiOrange : AppColors.getBorder(context), borderRadius: BorderRadius.circular(2)))), if (index < _totalSteps - 1) const SizedBox(width: 8)]));
    })));
  }

  Widget _buildPersonalInfoStep() {
    return SingleChildScrollView(padding: const EdgeInsets.all(24), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildStepHeader('Paso 1 de 3', 'Informacion Personal', 'Ingresa tus datos de documento y licencia'),
      const SizedBox(height: 32),
      _buildTextField(controller: _dniController, label: 'Numero de Documento (DNI/CE)', hint: 'Ej: 12345678', icon: Icons.badge_outlined, keyboardType: TextInputType.number, maxLength: 8),
      const SizedBox(height: 16),
      _buildTextField(controller: _licenseController, label: 'Numero de Licencia de Conducir', hint: 'Ej: A-12345678', icon: Icons.credit_card),
      const SizedBox(height: 24),
      _buildInfoCard('Por que necesitamos esto?', 'Validamos tu identidad para garantizar la seguridad de todos los usuarios de la plataforma.', Icons.info_outline, AppColors.getTextPrimary(context)),
    ])));
  }

  Widget _buildVehicleInfoStep() {
    return SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildStepHeader('Paso 2 de 3', 'Informacion del Vehiculo', 'Ingresa los datos de tu vehiculo'),
      const SizedBox(height: 32),
      _buildTextField(controller: _plateController, label: 'Placa del Vehiculo', hint: 'Ej: ABC-123', icon: Icons.directions_car, textCapitalization: TextCapitalization.characters),
      const SizedBox(height: 16),
      Row(children: [Expanded(child: _buildTextField(controller: _brandController, label: 'Marca', hint: 'Ej: Toyota', icon: Icons.business)), const SizedBox(width: 12), Expanded(child: _buildTextField(controller: _modelController, label: 'Modelo', hint: 'Ej: Corolla', icon: Icons.car_rental))]),
      const SizedBox(height: 16),
      Row(children: [Expanded(child: _buildTextField(controller: _yearController, label: 'Ano', hint: 'Ej: 2020', icon: Icons.calendar_today, keyboardType: TextInputType.number, maxLength: 4)), const SizedBox(width: 12), Expanded(child: _buildTextField(controller: _colorController, label: 'Color', hint: 'Ej: Blanco', icon: Icons.palette))]),
      const SizedBox(height: 24),
      _buildInfoCard('Requisitos del vehiculo', 'El vehiculo debe tener maximo 15 anos de antiguedad, estar en buen estado y contar con todos los documentos al dia.', Icons.check_circle_outline, AppColors.rappiOrange),
    ]));
  }

  Widget _buildDocumentsStep() {
    return SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildStepHeader('Paso 3 de 3', 'Documentos Requeridos', 'Sube fotos claras de tus documentos'),
      const SizedBox(height: 32),
      _buildDocumentUpload('Documento de Identidad (DNI/CE)', _dniPhoto, () => _pickDocument('DNI'), Icons.badge, _isDniPdf),
      const SizedBox(height: 16),
      _buildDocumentUpload('Licencia de Conducir', _licensePhoto, () => _pickDocument('Licencia'), Icons.credit_card, _isLicensePdf),
      const SizedBox(height: 16),
      _buildDocumentUpload('Foto del Vehiculo', _vehiclePhoto, () => _pickDocument('vehiculo'), Icons.directions_car, _isVehiclePdf),
      const SizedBox(height: 32),
      Text('Documentos Adicionales de Verificacion', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
      const SizedBox(height: 8),
      Text('Estos documentos son obligatorios para completar tu registro como conductor.', style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context))),
      const SizedBox(height: 16),
      _buildDocumentUpload('Antecedentes Penales', _criminalRecordPhoto, () => _pickDocument('Antecedentes Penales'), Icons.shield_outlined, _isCriminalRecordPdf),
      const SizedBox(height: 16),
      _buildDocumentUpload('SOAT (Seguro Obligatorio)', _soatPhoto, () => _pickDocument('SOAT'), Icons.verified_user_outlined, _isSoatPdf),
      const SizedBox(height: 16),
      _buildDocumentUpload('Revision Tecnica', _technicalReviewPhoto, () => _pickDocument('revision tecnica'), Icons.build_circle_outlined, _isTechnicalReviewPdf),
      const SizedBox(height: 16),
      _buildDocumentUpload('Tarjeta de Propiedad', _ownershipPhoto, () => _pickDocument('Tarjeta de Propiedad'), Icons.article_outlined, _isOwnershipPdf),
      const SizedBox(height: 24),
      _buildInfoCard('Consejos para documentos', 'Asegurate de que las fotos sean claras y legibles. Puedes subir imagenes o archivos PDF. Tamano maximo: 10MB por archivo.', Icons.info_outline, AppColors.warning),
    ]));
  }

  Widget _buildStepHeader(String step, String title, String description) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(step, style: const TextStyle(color: AppColors.rappiOrange, fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
      const SizedBox(height: 8),
      Text(description, style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context))),
    ]);
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required String hint, required IconData icon, TextInputType? keyboardType, int? maxLength, TextCapitalization textCapitalization = TextCapitalization.none}) {
    return TextFormField(controller: controller, keyboardType: keyboardType, maxLength: maxLength, textCapitalization: textCapitalization, decoration: InputDecoration(
      labelText: label, hintText: hint, prefixIcon: Icon(icon, color: AppColors.rappiOrange), filled: true, fillColor: AppColors.getSurface(context),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.getBorder(context))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.getBorder(context))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.rappiOrange, width: 2)),
      counterText: '',
    ));
  }

  Widget _buildDocumentUpload(String label, File? file, VoidCallback onTap, IconData icon, bool isPdf) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.getSurface(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: file != null ? AppColors.rappiOrange : AppColors.getBorder(context), width: file != null ? 2 : 1)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: (file != null ? AppColors.rappiOrange : AppColors.getBorder(context)).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(file != null && isPdf ? Icons.picture_as_pdf : icon, color: file != null ? (isPdf ? AppColors.getTextPrimary(context) : AppColors.rappiOrange) : AppColors.getTextSecondary(context), size: 28)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
          const SizedBox(height: 4),
          Text(file != null ? (isPdf ? 'Documento PDF subido ✓' : 'Foto subida ✓') : 'Toca para subir foto o PDF', style: TextStyle(fontSize: 12, color: file != null ? AppColors.rappiOrange : AppColors.getTextSecondary(context))),
        ])),
        Icon(file != null ? Icons.check_circle : Icons.upload, color: file != null ? AppColors.rappiOrange : AppColors.getTextSecondary(context)),
      ]),
    ));
  }

  Widget _buildInfoCard(String title, String message, IconData icon, Color color) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color, size: 24), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)), const SizedBox(height: 4), Text(message, style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(context)))]))]));
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.getSurface(context), boxShadow: [BoxShadow(color: AppColors.getTextPrimary(context).withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))]),
      child: SafeArea(child: Row(children: [
        if (_currentStep > 0) Expanded(child: OutlinedButton(
          onPressed: _isUploading ? null : _previousStep,
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: const BorderSide(color: AppColors.rappiOrange)),
          child: Text('Atras', style: const TextStyle(fontSize: 16, color: AppColors.rappiOrange)),
        )),
        if (_currentStep > 0) const SizedBox(width: 12),
        Expanded(child: ElevatedButton(
          onPressed: _isUploading ? null : _currentStep < _totalSteps - 1 ? _nextStep : _submitUpgrade,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.rappiOrange, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
          child: _isUploading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
              : Text(_currentStep < _totalSteps - 1 ? 'Siguiente' : 'Completar Registro', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        )),
      ])),
    );
  }
}
