// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive_bottom_sheet.dart';
import '../../providers/auth_provider.dart';
import '../../services/rapi_api_client.dart';
import '../../utils/logger.dart';

/// Pantalla 4: Subir documentos
class DriverRegistrationDocumentsScreen extends StatefulWidget {
  final Map<String, dynamic> registrationData;

  const DriverRegistrationDocumentsScreen({
    super.key,
    required this.registrationData,
  });

  @override
  State<DriverRegistrationDocumentsScreen> createState() => _DriverRegistrationDocumentsScreenState();
}

class _DriverRegistrationDocumentsScreenState extends State<DriverRegistrationDocumentsScreen> {
  final _picker = ImagePicker();
  bool _isLoading = false;

  // Documentos
  File? _licenseFront;
  File? _licenseBack;
  File? _dniFront;
  File? _dniBack;
  File? _propertyCardFront;
  File? _propertyCardBack;
  File? _soat;

  Future<void> _pickDocument(String type) async {
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

    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );

    if (pickedFile != null && mounted) {
      setState(() {
        switch (type) {
          case 'license_front':
            _licenseFront = File(pickedFile.path);
            break;
          case 'license_back':
            _licenseBack = File(pickedFile.path);
            break;
          case 'dni_front':
            _dniFront = File(pickedFile.path);
            break;
          case 'dni_back':
            _dniBack = File(pickedFile.path);
            break;
          case 'property_front':
            _propertyCardFront = File(pickedFile.path);
            break;
          case 'property_back':
            _propertyCardBack = File(pickedFile.path);
            break;
          case 'soat':
            _soat = File(pickedFile.path);
            break;
        }
      });
    }
  }

  bool get _isFormValid {
    final isCourier = (widget.registrationData['workType'] as String? ?? 'driver') == 'courier';
    // Courier no requiere licencia de conducir
    final licenseValid = isCourier || (_licenseFront != null && _licenseBack != null);
    return licenseValid &&
        _dniFront != null &&
        _dniBack != null &&
        _propertyCardFront != null &&
        _soat != null;
  }

  Future<void> _submitApplication() async {
    if (!_isFormValid) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id;
      final userName = authProvider.currentUser?.displayName ?? '';

      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      AppLogger.info('Subiendo documentos al backend Node...');

      // Subir imágenes al backend Node (storage propio del VPS).
      final selfieUrl = widget.registrationData['selfieLocalPath'] != null
          ? await _uploadImage(File(widget.registrationData['selfieLocalPath']), 'selfie')
          : null;
      final vehiclePhotoUrl = widget.registrationData['vehiclePhotoLocalPath'] != null
          ? await _uploadImage(File(widget.registrationData['vehiclePhotoLocalPath']), 'vehicle_photo')
          : null;
      final licenseFrontUrl = _licenseFront != null
          ? await _uploadImage(_licenseFront!, 'license_front')
          : null;
      final licenseBackUrl = _licenseBack != null
          ? await _uploadImage(_licenseBack!, 'license_back')
          : null;
      final dniFrontUrl = await _uploadImage(_dniFront!, 'dni_front');
      final dniBackUrl = await _uploadImage(_dniBack!, 'dni_back');
      final propertyCardFrontUrl = await _uploadImage(_propertyCardFront!, 'property_front');
      final propertyCardBackUrl = _propertyCardBack != null
          ? await _uploadImage(_propertyCardBack!, 'property_back')
          : null;
      final soatUrl = await _uploadImage(_soat!, 'soat');

      final api = RapiApiClient.instance;

      // 1) Registrar/actualizar el vehículo del driver.
      try {
        await api.upsertVehicle(
          vehicleType: (widget.registrationData['workType'] ?? 'auto') as String,
          plate: (widget.registrationData['vehiclePlate'] ?? '') as String,
          make: widget.registrationData['vehicleBrand'] as String?,
          model: widget.registrationData['vehicleModel'] as String?,
          color: widget.registrationData['vehicleColor'] as String?,
          year: int.tryParse('${widget.registrationData['vehicleYear'] ?? ''}'),
        );
      } catch (e) {
        AppLogger.warning('upsertVehicle falló: $e');
      }

      // 2) Registrar cada documento subido en /api/drivers/me/documents.
      final docs = <String, String?>{
        'license_front': licenseFrontUrl,
        'license_back': licenseBackUrl,
        'dni_front': dniFrontUrl,
        'dni_back': dniBackUrl,
        'property_front': propertyCardFrontUrl,
        'property_back': propertyCardBackUrl,
        'soat': soatUrl,
        'selfie': selfieUrl,
        'vehicle_photo': vehiclePhotoUrl,
      };
      for (final entry in docs.entries) {
        final url = entry.value;
        if (url == null || url.isEmpty) continue;
        try {
          await api.uploadDocument(docType: entry.key, fileUrl: url);
        } catch (e) {
          AppLogger.warning('uploadDocument ${entry.key} falló: $e');
        }
      }

      AppLogger.info('Solicitud de conductor enviada al backend Node');

      if (!mounted) return;

      // Crear mapa limpio para navegación.
      final navData = {
        'workType': widget.registrationData['workType'],
        'status': 'pending',
        'userName': userName,
      };

      // Navegar a pantalla de espera
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/driver/register/pending',
        (route) => false,
        arguments: navData,
      );
    } catch (e) {
      AppLogger.error('Error enviando solicitud: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar solicitud: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Sube una imagen al backend Node (/api/storage/upload) con el scope indicado
  /// y retorna la URL pública/firmada devuelta por el servidor.
  Future<String> _uploadImage(File file, String scope) async {
    try {
      final res = await RapiApiClient.instance.uploadFile(
        file: file,
        scope: 'driver_$scope',
      );
      final url = (res['url'] ?? res['downloadUrl'] ?? '') as String;
      if (url.isEmpty) {
        throw StateError('El backend no devolvió URL para $scope');
      }
      return url;
    } catch (e) {
      AppLogger.error('Error subiendo imagen $scope: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final workType = widget.registrationData['workType'] as String? ?? 'driver';
    final isCourier = workType == 'courier';

    return Scaffold(
      backgroundColor: AppColors.getSurface(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.getTextPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Paso 3 de 4',
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sube tus documentos',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Necesitamos verificar tu documentación',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.getTextSecondary(context),
                ),
              ),
              const SizedBox(height: 32),

              // Licencia de conducir
              if (!isCourier) ...[
                _buildDocumentSection(
                  title: 'Licencia de conducir',
                  icon: Icons.credit_card,
                  frontFile: _licenseFront,
                  backFile: _licenseBack,
                  onPickFront: () => _pickDocument('license_front'),
                  onPickBack: () => _pickDocument('license_back'),
                ),
                const SizedBox(height: 24),
              ],

              // DNI
              _buildDocumentSection(
                title: 'DNI / Documento de identidad',
                icon: Icons.badge,
                frontFile: _dniFront,
                backFile: _dniBack,
                onPickFront: () => _pickDocument('dni_front'),
                onPickBack: () => _pickDocument('dni_back'),
              ),
              const SizedBox(height: 24),

              // Tarjeta de propiedad
              _buildDocumentSection(
                title: isCourier ? 'Documento del vehículo' : 'Tarjeta de propiedad',
                icon: Icons.description,
                frontFile: _propertyCardFront,
                backFile: _propertyCardBack,
                onPickFront: () => _pickDocument('property_front'),
                onPickBack: () => _pickDocument('property_back'),
                backOptional: true,
              ),
              const SizedBox(height: 24),

              // SOAT
              _buildSingleDocumentSection(
                title: 'SOAT vigente',
                icon: Icons.security,
                file: _soat,
                onPick: () => _pickDocument('soat'),
              ),

              const SizedBox(height: 24),

              // Nota informativa
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Asegúrate que las fotos sean legibles y estén actualizadas.',
                        style: TextStyle(
                          color: Colors.amber.shade800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Botón Enviar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isFormValid && !_isLoading ? _submitApplication : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.rappiRed,
                    disabledBackgroundColor: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Enviar solicitud',
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
    );
  }

  Widget _buildDocumentSection({
    required String title,
    required IconData icon,
    required File? frontFile,
    required File? backFile,
    required VoidCallback onPickFront,
    required VoidCallback onPickBack,
    bool backOptional = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.rappiRed, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextPrimary(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildDocumentPicker(
                label: 'Frente',
                file: frontFile,
                onPick: onPickFront,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDocumentPicker(
                label: backOptional ? 'Reverso (opc.)' : 'Reverso',
                file: backFile,
                onPick: onPickBack,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSingleDocumentSection({
    required String title,
    required IconData icon,
    required File? file,
    required VoidCallback onPick,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.rappiRed, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextPrimary(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildDocumentPicker(
          label: 'Documento',
          file: file,
          onPick: onPick,
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _buildDocumentPicker({
    required String label,
    required File? file,
    required VoidCallback onPick,
    bool fullWidth = false,
  }) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 100,
        width: fullWidth ? double.infinity : null,
        decoration: BoxDecoration(
          color: AppColors.getInputFill(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: file != null ? AppColors.success : AppColors.getBorder(context),
            width: file != null ? 2 : 1,
          ),
          image: file != null
              ? DecorationImage(
                  image: FileImage(file),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: file == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 28,
                    color: AppColors.rappiRed,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
              )
            : Align(
                alignment: Alignment.topRight,
                child: Container(
                  margin: const EdgeInsets.all(4),
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
      ),
    );
  }
}
