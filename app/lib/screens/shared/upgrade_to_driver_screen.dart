// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart'; // ✅ NUEVO: Para seleccionar PDFs
import 'package:permission_handler/permission_handler.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart'; // ✅ Extensión para colores que se adaptan al tema
import '../../widgets/common/rappi_app_bar.dart';

/// Pantalla de registro como conductor para usuarios existentes
/// Permite a un pasajero convertirse en conductor (dual-account)
class UpgradeToDriverScreen extends StatefulWidget {
  const UpgradeToDriverScreen({super.key});

  @override
  State<UpgradeToDriverScreen> createState() => _UpgradeToDriverScreenState();
}

class _UpgradeToDriverScreenState extends State<UpgradeToDriverScreen> {
  final PageController _pageController = PageController();
  final _formKey = GlobalKey<FormState>();

  int _currentStep = 0;
  final int _totalSteps = 3;

  // Controladores de formulario
  final _dniController = TextEditingController();
  final _licenseController = TextEditingController();
  final _plateController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();

  // Estado de documentos básicos
  File? _dniPhoto;
  File? _licensePhoto;
  File? _vehiclePhoto;

  // ✅ NUEVO: Documentos adicionales de verificación
  File? _criminalRecordPhoto; // Antecedentes penales
  File? _soatPhoto; // SOAT (Seguro Obligatorio de Accidentes de Tránsito)
  File? _technicalReviewPhoto; // Revisión técnica del vehículo
  File? _ownershipPhoto; // Tarjeta de propiedad del vehículo

  // Indicadores de tipo de archivo (true = PDF, false = imagen)
  bool _isDniPdf = false;
  bool _isLicensePdf = false;
  bool _isVehiclePdf = false;

  // ✅ NUEVO: Indicadores para documentos adicionales
  bool _isCriminalRecordPdf = false;
  bool _isSoatPdf = false;
  bool _isTechnicalReviewPdf = false;
  bool _isOwnershipPdf = false;

  bool _isUploading = false;

  @override
  void dispose() {
    _pageController.dispose();
    _dniController.dispose();
    _licenseController.dispose();
    _plateController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      if (_validateCurrentStep()) {
        setState(() {
          _currentStep++;
        });
        _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        // Validar información personal
        if (_dniController.text.isEmpty) {
          _showError('Por favor ingresa tu número de documento');
          return false;
        }
        if (_licenseController.text.isEmpty) {
          _showError('Por favor ingresa tu número de licencia');
          return false;
        }
        return true;

      case 1:
        // Validar información del vehículo
        if (_plateController.text.isEmpty) {
          _showError('Por favor ingresa la placa del vehículo');
          return false;
        }
        if (_brandController.text.isEmpty) {
          _showError('Por favor ingresa la marca del vehículo');
          return false;
        }
        if (_modelController.text.isEmpty) {
          _showError('Por favor ingresa el modelo del vehículo');
          return false;
        }
        if (_yearController.text.isEmpty) {
          _showError('Por favor ingresa el año del vehículo');
          return false;
        }
        if (_colorController.text.isEmpty) {
          _showError('Por favor ingresa el color del vehículo');
          return false;
        }
        return true;

      case 2:
        // Validar documentos subidos
        if (_dniPhoto == null) {
          _showError('Por favor sube una foto de tu documento');
          return false;
        }
        if (_licensePhoto == null) {
          _showError('Por favor sube una foto de tu licencia');
          return false;
        }
        if (_vehiclePhoto == null) {
          _showError('Por favor sube una foto de tu vehículo');
          return false;
        }
        // ✅ NUEVO: Validar documentos adicionales de verificación
        if (_criminalRecordPhoto == null) {
          _showError('Por favor sube tus antecedentes penales');
          return false;
        }
        if (_soatPhoto == null) {
          _showError('Por favor sube el SOAT del vehículo');
          return false;
        }
        if (_technicalReviewPhoto == null) {
          _showError('Por favor sube la revisión técnica del vehículo');
          return false;
        }
        if (_ownershipPhoto == null) {
          _showError('Por favor sube la tarjeta de propiedad del vehículo');
          return false;
        }
        return true;

      default:
        return true;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ModernTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submitUpgrade() async {
    if (!_validateCurrentStep()) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Preparar datos del conductor
      final driverData = {
        'dni': _dniController.text.trim(),
        'license': _licenseController.text.trim(),
        // ✅ FIX: Usar 'vehicleInfo' (como en UserModel) en lugar de 'vehicle'
        // ✅ TODOS los campos del vehículo en MAYÚSCULAS
        'vehicleInfo': {
          'plate': _plateController.text.trim().toUpperCase(),
          'make': _brandController.text.trim().toUpperCase(),
          'model': _modelController.text.trim().toUpperCase(),
          'year': int.parse(_yearController.text.trim()),
          'color': _colorController.text.trim().toUpperCase(),
          'capacity': 4,
        },
      };

      // Llamar a upgradeToDriver con los documentos (básicos + adicionales)
      final success = await authProvider.upgradeToDriver(
        driverData: driverData,
        dniPhoto: _dniPhoto,
        licensePhoto: _licensePhoto,
        vehiclePhoto: _vehiclePhoto,
        // ✅ NUEVO: Documentos adicionales de verificación
        criminalRecordPhoto: _criminalRecordPhoto,
        soatPhoto: _soatPhoto,
        technicalReviewPhoto: _technicalReviewPhoto,
        ownershipPhoto: _ownershipPhoto,
      );

      if (success) {
        if (!mounted) return;

        // Mostrar mensaje de éxito - documentos enviados para revisión
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Documentos enviados! Nuestro equipo los revisará pronto.'),
            backgroundColor: ModernTheme.rappiOrange,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );

        // Esperar un momento
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;

        // Mostrar diálogo informativo
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: ModernTheme.rappiOrange, size: 28),
                const SizedBox(width: 12),
                const Expanded(child: Text('Solicitud Enviada')),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tus documentos han sido enviados para revisión.',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 12),
                Text(
                  '• Nuestro equipo revisará tu información\n'
                  '• Te notificaremos cuando seas aprobado\n'
                  '• Mientras tanto, puedes usar la app como pasajero',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ModernTheme.rappiOrange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Entendido', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );

        if (!mounted) return;

        // Navegar al home de PASAJERO (no conductor) mientras espera aprobación
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/passenger/home',
          (route) => false,
        );
      } else {
        if (!mounted) return;
        _showError('Error al registrarte como conductor. Intenta nuevamente.');
      }
    } catch (e) {
      if (!mounted) return;
      // Mostrar mensaje más amigable según el tipo de error
      String errorMsg = e.toString();
      if (errorMsg.contains('too-many-requests') || errorMsg.contains('RESOURCE_EXHAUSTED')) {
        _showError('Demasiados intentos. Por favor espera unos minutos e intenta de nuevo.');
      } else if (errorMsg.contains('permission-denied') || errorMsg.contains('PERMISSION_DENIED')) {
        _showError('Error de permisos. Por favor cierra sesión e intenta de nuevo.');
      } else if (errorMsg.contains('network') || errorMsg.contains('UNAVAILABLE')) {
        _showError('Error de conexión. Verifica tu internet e intenta de nuevo.');
      } else {
        _showError('Error al registrarte: ${e.toString().replaceAll('Exception: ', '')}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  /// ✅ IMPLEMENTADO: Seleccionar imagen o PDF para documentos
  Future<void> _pickDocument(String type) async {
    try {
      // Mostrar diálogo para elegir tipo de archivo
      final fileType = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Subir $type',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.primaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Puedes tomar una foto o subir un documento PDF',
                    style: TextStyle(
                      fontSize: 14,
                      color: context.secondaryText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: ModernTheme.rappiOrange),
                  title: const Text('Tomar foto'),
                  onTap: () => Navigator.pop(context, 'camera'),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: ModernTheme.rappiOrange),
                  title: const Text('Elegir foto de galería'),
                  onTap: () => Navigator.pop(context, 'gallery'),
                ),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: ModernTheme.primaryBlue),
                  title: const Text('Seleccionar documento PDF'),
                  onTap: () => Navigator.pop(context, 'pdf'),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      );

      if (fileType == null) return;

      File? selectedFile;
      bool isPdf = false;

      if (fileType == 'camera' || fileType == 'gallery') {
        // Seleccionar imagen con ImagePicker
        final source = fileType == 'camera' ? ImageSource.camera : ImageSource.gallery;

        // Solo pedir permiso de CÁMARA si se usa la cámara
        // Para GALERÍA: Android 13+ usa Photo Picker que NO requiere permisos
        // Photo Picker es una actividad del sistema que maneja los permisos internamente
        if (source == ImageSource.camera) {
          final permissionStatus = await Permission.camera.request();
          if (!permissionStatus.isGranted) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Se necesita permiso de cámara'),
                backgroundColor: ModernTheme.error,
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: 'Abrir configuración',
                  textColor: Theme.of(context).colorScheme.onPrimary,
                  onPressed: () => openAppSettings(),
                ),
              ),
            );
            return;
          }
        }
        // NOTA: Para galería NO pedimos permisos - image_picker usa Photo Picker en Android 13+

        // Seleccionar imagen
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: source,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );

        if (image != null) {
          selectedFile = File(image.path);
          isPdf = false;
        }
      } else if (fileType == 'pdf') {
        // Seleccionar PDF con FilePicker
        // NOTA: FilePicker en Android 13+ usa el Document Picker del sistema
        // que NO requiere permisos de almacenamiento (similar a Photo Picker)
        // Solo intentamos directamente, si falla mostramos error
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          allowMultiple: false,
        );

        if (result != null && result.files.isNotEmpty) {
          selectedFile = File(result.files.first.path!);
          isPdf = true;
        }
      }

      if (selectedFile == null) return;

      // Validar tamaño del archivo (máximo 10MB)
      final fileSize = await selectedFile.length();
      const maxSize = 10 * 1024 * 1024; // 10MB en bytes
      if (fileSize > maxSize) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El archivo es demasiado grande. Máximo 10MB'),
            backgroundColor: ModernTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Actualizar estado según el tipo de documento
      if (!mounted) return;
      setState(() {
        switch (type.toLowerCase()) {
          case 'dni':
            _dniPhoto = selectedFile;
            _isDniPdf = isPdf;
            break;
          case 'licencia':
            _licensePhoto = selectedFile;
            _isLicensePdf = isPdf;
            break;
          case 'vehículo':
            _vehiclePhoto = selectedFile;
            _isVehiclePdf = isPdf;
            break;
          // ✅ NUEVO: Documentos adicionales de verificación
          case 'antecedentes penales':
            _criminalRecordPhoto = selectedFile;
            _isCriminalRecordPdf = isPdf;
            break;
          case 'soat':
            _soatPhoto = selectedFile;
            _isSoatPdf = isPdf;
            break;
          case 'revisión técnica':
            _technicalReviewPhoto = selectedFile;
            _isTechnicalReviewPdf = isPdf;
            break;
          case 'tarjeta de propiedad':
            _ownershipPhoto = selectedFile;
            _isOwnershipPdf = isPdf;
            break;
        }
      });

      // Mostrar confirmación
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onPrimary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$type cargado correctamente (${isPdf ? "PDF" : "Imagen"})',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
          backgroundColor: ModernTheme.rappiOrange,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error seleccionando documento: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar documento: $e'),
          backgroundColor: ModernTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceColor,
      appBar: RappiAppBar(
        title: 'Conviértete en Conductor',
        showBackButton: true,
      ),
      body: Column(
        children: [
          // Indicador de progreso
          _buildProgressIndicator(),

          // Contenido del paso actual
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildPersonalInfoStep(),
                _buildVehicleInfoStep(),
                _buildDocumentsStep(),
              ],
            ),
          ),

          // Botones de navegación
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      color: context.surfaceColor,
      child: Column(
        children: [
          // Barra de progreso lineal
          Row(
            children: List.generate(_totalSteps, (index) {
              final isCompleted = index < _currentStep;
              final isCurrent = index == _currentStep;

              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 4,
                        decoration: BoxDecoration(
                          color: isCompleted || isCurrent
                              ? ModernTheme.rappiOrange
                              : Theme.of(context).dividerColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (index < _totalSteps - 1) const SizedBox(width: 8),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          // Dots indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_totalSteps, (index) {
              final isCurrent = index == _currentStep;
              final isCompleted = index < _currentStep;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isCurrent ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: (isCurrent || isCompleted)
                      ? ModernTheme.rappiOrange
                      : Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeader(
              'PASO 1 DE 3',
              'Información Personal',
              'Ingresa tus datos de identificación y licencia de conducir',
              illustrationIcon: Icons.badge_outlined,
            ),
            const SizedBox(height: 20),

            // Beneficios como tarjetas scrollables horizontalmente
            _buildBenefitsRow(),
            const SizedBox(height: 24),

            _buildTextField(
              controller: _dniController,
              label: 'Número de Documento (DNI/CE)',
              hint: 'Ej: 12345678',
              icon: Icons.badge_outlined,
              keyboardType: TextInputType.number,
              maxLength: 8,
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _licenseController,
              label: 'Número de Licencia de Conducir',
              hint: 'Ej: A-12345678',
              icon: Icons.credit_card,
            ),
            const SizedBox(height: 24),

            _buildInfoCard(
              '¿Por qué necesitamos esta información?',
              'Validamos tu identidad y licencia para garantizar la seguridad de todos los usuarios de Rappi Team.',
              Icons.info_outline,
              ModernTheme.primaryBlue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleInfoStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            'PASO 2 DE 3',
            'Información del Vehículo',
            'Ingresa los datos de tu vehículo',
            illustrationIcon: Icons.directions_car_outlined,
          ),
          const SizedBox(height: 32),

          _buildTextField(
            controller: _plateController,
            label: 'Placa del Vehículo',
            hint: 'Ej: ABC-123',
            icon: Icons.directions_car,
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _brandController,
                  label: 'Marca',
                  hint: 'Ej: Toyota',
                  icon: Icons.business,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _modelController,
                  label: 'Modelo',
                  hint: 'Ej: Corolla',
                  icon: Icons.car_rental,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _yearController,
                  label: 'Año',
                  hint: 'Ej: 2020',
                  icon: Icons.calendar_today,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _colorController,
                  label: 'Color',
                  hint: 'Ej: Negro',
                  icon: Icons.palette,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          _buildInfoCard(
            'Requisitos del vehículo',
            'Tu vehículo debe tener menos de 10 años de antigüedad y estar en buenas condiciones.',
            Icons.check_circle_outline,
            ModernTheme.rappiOrange,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            'PASO 3 DE 3',
            'Documentos Requeridos',
            'Sube fotos claras de tus documentos',
            illustrationIcon: Icons.folder_open_outlined,
          ),
          const SizedBox(height: 32),

          _buildDocumentUpload(
            'Documento de Identidad (DNI/CE)',
            _dniPhoto,
            () => _pickDocument('DNI'),
            Icons.badge,
            _isDniPdf,
          ),
          const SizedBox(height: 16),

          _buildDocumentUpload(
            'Licencia de Conducir',
            _licensePhoto,
            () => _pickDocument('Licencia'),
            Icons.credit_card,
            _isLicensePdf,
          ),
          const SizedBox(height: 16),

          _buildDocumentUpload(
            'Foto del Vehículo',
            _vehiclePhoto,
            () => _pickDocument('Vehículo'),
            Icons.directions_car,
            _isVehiclePdf,
          ),
          const SizedBox(height: 24),

          // ✅ NUEVO: Sección de documentos adicionales de verificación
          Text(
            'Documentos Adicionales de Verificación',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Para garantizar la seguridad de todos, necesitamos los siguientes documentos adicionales:',
            style: TextStyle(
              fontSize: 14,
              color: context.secondaryText,
            ),
          ),
          const SizedBox(height: 16),

          _buildDocumentUpload(
            'Antecedentes Penales',
            _criminalRecordPhoto,
            () => _pickDocument('Antecedentes Penales'),
            Icons.shield_outlined,
            _isCriminalRecordPdf,
          ),
          const SizedBox(height: 16),

          _buildDocumentUpload(
            'SOAT (Seguro Obligatorio)',
            _soatPhoto,
            () => _pickDocument('SOAT'),
            Icons.verified_user_outlined,
            _isSoatPdf,
          ),
          const SizedBox(height: 16),

          _buildDocumentUpload(
            'Revisión Técnica del Vehículo',
            _technicalReviewPhoto,
            () => _pickDocument('Revisión Técnica'),
            Icons.build_circle_outlined,
            _isTechnicalReviewPdf,
          ),
          const SizedBox(height: 16),

          _buildDocumentUpload(
            'Tarjeta de Propiedad del Vehículo',
            _ownershipPhoto,
            () => _pickDocument('Tarjeta de Propiedad'),
            Icons.article_outlined,
            _isOwnershipPdf,
          ),
          const SizedBox(height: 24),

          _buildInfoCard(
            'Consejos para los documentos',
            '• Puedes subir fotos o documentos PDF\n'
            '• Asegúrate de que las fotos sean claras y legibles\n'
            '• Evita reflejos y sombras\n'
            '• Los PDFs no deben superar 10MB\n'
            '• Los documentos serán revisados por nuestro equipo',
            Icons.info_outline,
            ModernTheme.accentYellow,
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsRow() {
    final benefits = [
      {
        'icon': Icons.attach_money,
        'title': 'Ingresos Extras',
        'desc': 'Gana dinero en tu tiempo libre',
        'color': ModernTheme.success,
      },
      {
        'icon': Icons.schedule,
        'title': 'Horario Flexible',
        'desc': 'Tú decides cuándo trabajar',
        'color': ModernTheme.info,
      },
      {
        'icon': Icons.people,
        'title': 'Comunidad',
        'desc': 'Únete a miles de conductores',
        'color': ModernTheme.rappiOrange,
      },
      {
        'icon': Icons.support_agent,
        'title': 'Soporte 24/7',
        'desc': 'Estamos aquí para ayudarte',
        'color': ModernTheme.warning,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Beneficios de ser conductor',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.secondaryText,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: benefits.length,
            itemBuilder: (context, index) {
              final benefit = benefits[index];
              final color = benefit['color'] as Color;
              return Container(
                width: 130,
                margin: EdgeInsets.only(right: index < benefits.length - 1 ? 12 : 0),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(benefit['icon'] as IconData, color: color, size: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      benefit['title'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: context.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      benefit['desc'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        color: context.secondaryText,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStepHeader(String step, String title, String description, {IconData? illustrationIcon}) {
    // Icono por defecto según el paso si no se proporciona
    final icon = illustrationIcon ?? _getStepIcon();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icono ilustrativo grande centrado
        Center(
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ModernTheme.rappiOrange.withValues(alpha: 0.15),
                  ModernTheme.rappiOrange.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 44, color: ModernTheme.rappiOrange),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          step,
          style: const TextStyle(
            color: ModernTheme.rappiOrange,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: context.primaryText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: TextStyle(
            fontSize: 14,
            color: context.secondaryText,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  IconData _getStepIcon() {
    switch (_currentStep) {
      case 0:
        return Icons.badge_outlined;
      case 1:
        return Icons.directions_car_outlined;
      case 2:
        return Icons.folder_open_outlined;
      default:
        return Icons.check_circle_outline;
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: ModernTheme.rappiOrange),
        filled: true,
        fillColor: context.surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ModernTheme.rappiOrange, width: 2),
        ),
        counterText: '',
      ),
    );
  }

  Widget _buildDocumentUpload(
    String label,
    File? file,
    VoidCallback onTap,
    IconData icon,
    bool isPdf,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: file != null ? ModernTheme.rappiOrange : Theme.of(context).dividerColor,
            width: file != null ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (file != null ? ModernTheme.rappiOrange : Theme.of(context).dividerColor)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                // ✅ NUEVO: Mostrar ícono de PDF si es PDF
                file != null && isPdf ? Icons.picture_as_pdf : icon,
                color: file != null
                    ? (isPdf ? ModernTheme.primaryBlue : ModernTheme.rappiOrange)
                    : context.secondaryText,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    // ✅ NUEVO: Mostrar tipo de archivo cargado
                    file != null
                        ? (isPdf ? 'Documento PDF cargado ✓' : 'Foto cargada ✓')
                        : 'Toca para subir foto o PDF',
                    style: TextStyle(
                      fontSize: 12,
                      color: file != null ? ModernTheme.rappiOrange : context.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              file != null ? Icons.check_circle : Icons.upload,
              color: file != null ? ModernTheme.rappiOrange : Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String message, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _isUploading ? null : _previousStep,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: const BorderSide(color: ModernTheme.rappiOrange),
                  ),
                  child: const Text(
                    'Atrás',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: ModernTheme.rappiOrange,
                    ),
                  ),
                ),
              ),
            if (_currentStep > 0)
              const SizedBox(width: 12),
            Expanded(
              flex: _currentStep == 0 ? 1 : 1,
              child: ElevatedButton(
                onPressed: _isUploading
                    ? null
                    : _currentStep < _totalSteps - 1
                        ? _nextStep
                        : _submitUpgrade,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ModernTheme.rappiOrange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isUploading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary),
                        ),
                      )
                    : Text(
                        _currentStep < _totalSteps - 1
                            ? 'Siguiente'
                            : 'Completar Registro',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
