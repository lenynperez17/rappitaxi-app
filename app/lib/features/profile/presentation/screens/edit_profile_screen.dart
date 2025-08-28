import 'dart:io';
import '../../../../../shared/providers/riverpod_compat.dart';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/oasis_button.dart';
import '../../../../core/widgets/oasis_text_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _imagePicker = ImagePicker();
  
  File? _selectedImage;
  bool _isLoading = false;
  
  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentUserProvider);
    
    return Scaffold(
      // backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Editar perfil'),
        // backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _handleSave,
              child: const Text('Guardar'),
            ),
        ],
      ),
      body: currentUserAsync == null 
        ? const Center(
            child: Text('Usuario no autenticado'),
          )
        : SingleChildScrollView(
            child: FormBuilder(
              key: _formKey,
              child: Column(
                children: [
                  // Foto de perfil
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Stack(
                        children: [
                          Hero(
                            tag: 'profile-photo',
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey[200],
                                border: Border.all(
                                  color: AppTheme.primaryColor.withOpacity(0.3),
                                  width: 3,
                                ),
                              ),
                              child: ClipOval(
                                child: _selectedImage != null
                                    ? Image.file(
                                        _selectedImage!,
                                        fit: BoxFit.cover,
                                      )
                                    : currentUserAsync.photoUrl != null
                                        ? Image.network(
                                            currentUserAsync.photoUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Icon(
                                              Icons.person,
                                              size: 60,
                                              color: Colors.grey,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.person,
                                            size: 60,
                                            color: Colors.grey,
                                          ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: _showImagePickerOptions,
                              ),
                            ),
                          ),
                        ],
                      ).animate().scale(duration: 300.ms),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Información personal
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Información personal',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Nombre
                        OasisTextField(
                          name: 'name',
                          label: 'Nombre completo',
                          prefixIcon: Icons.person_outline,
                          initialValue: currentUserAsync.name,
                          validators: [
                            FormBuilderValidators.required(
                              errorText: 'El nombre es requerido',
                            ),
                            FormBuilderValidators.minLength(
                              3,
                              errorText: 'Mínimo 3 caracteres',
                            ),
                          ],
                        ).animate().fadeIn(delay: 100.ms),
                        
                        const SizedBox(height: 16),
                        
                        // Email (solo lectura)
                        OasisTextField(
                          name: 'email',
                          label: 'Correo electrónico',
                          prefixIcon: Icons.email_outlined,
                          initialValue: currentUserAsync.email,
                          enabled: false,
                        ).animate().fadeIn(delay: 200.ms),
                        
                        const SizedBox(height: 16),
                        
                        // Teléfono
                        OasisTextField(
                          name: 'phone',
                          label: 'Teléfono',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          initialValue: currentUserAsync.phone,
                          validators: [
                            FormBuilderValidators.required(
                              errorText: 'El teléfono es requerido',
                            ),
                            FormBuilderValidators.match(
                              r'^[0-9]{9}$',
                              errorText: 'Ingresa un número válido de 9 dígitos',
                            ),
                          ],
                        ).animate().fadeIn(delay: 300.ms),
                        
                        const SizedBox(height: 8),
                        
                        Text(
                          'Tu número de teléfono es importante para que el conductor pueda contactarte',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Preferencias
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Preferencias',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Idioma
                        FormBuilderDropdown<String>(
                          name: 'language',
                          decoration: InputDecoration(
                            labelText: 'Idioma',
                            prefixIcon: const Icon(Icons.language),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                            ),
                          ),
                          initialValue: 'es',
                          items: const [
                            DropdownMenuItem(
                              value: 'es',
                              child: Text('Español'),
                            ),
                            DropdownMenuItem(
                              value: 'en',
                              child: Text('English'),
                            ),
                            DropdownMenuItem(
                              value: 'pt',
                              child: Text('Português'),
                            ),
                          ],
                        ).animate().fadeIn(delay: 400.ms),
                        
                        const SizedBox(height: 16),
                        
                        // Notificaciones
                        FormBuilderSwitch(
                          name: 'notifications',
                          title: const Text('Notificaciones push'),
                          subtitle: const Text('Recibe notificaciones sobre tus viajes'),
                          initialValue: true,
                          activeColor: AppTheme.primaryColor,
                        ).animate().fadeIn(delay: 500.ms),
                        
                        FormBuilderSwitch(
                          name: 'promotions',
                          title: const Text('Promociones'),
                          subtitle: const Text('Recibe ofertas y descuentos especiales'),
                          initialValue: true,
                          activeColor: AppTheme.primaryColor,
                        ).animate().fadeIn(delay: 600.ms),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
    );
  }
  
  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cambiar foto de perfil',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.primaryColor),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.primaryColor),
              title: const Text('Elegir de la galería'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_selectedImage != null || ref.read(currentUserProvider)?.photoUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Eliminar foto'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedImage = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: ${e.toString()}'),
            // backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
  
  Future<void> _handleSave() async {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      setState(() => _isLoading = true);
      
      try {
        final values = _formKey.currentState!.value;
        
        // TODO: Implementar subida de imagen
        String? photoUrl;
        if (_selectedImage != null) {
          // Subir imagen a Firebase Storage
          // photoUrl = await uploadImage(_selectedImage!);
        }
        
        // Actualizar perfil
        await ref.read(authRepositoryProvider).updateProfile(
          name: values['name'],
          photoUrl: photoUrl,
        );
        
        // Refrescar usuario
        ref.invalidate(currentUserProvider);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Perfil actualizado correctamente'),
              // backgroundColor: AppTheme.successColor,
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al actualizar perfil: ${e.toString()}'),
              // backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }
}