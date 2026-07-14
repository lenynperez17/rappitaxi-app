// ignore_for_file: use_build_context_synchronously
// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart'; // ✅ NUEVO: Para tomar/seleccionar fotos
import 'dart:io';
import '../../core/theme/modern_theme.dart';
import '../../core/utils/responsive_bottom_sheet.dart';
import '../../core/extensions/theme_extensions.dart'; // ✅ Extensión para colores que se adaptan al tema

import '../../providers/auth_provider.dart';
import '../../services/rapi_api_client.dart';
import '../../utils/logger.dart';
import '../../utils/error_messages.dart';
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  _ProfileEditScreenState createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen>
    with TickerProviderStateMixin {
  final RapiApiClient _api = RapiApiClient.instance;
  String? _userId; // Se obtendrá del usuario actual
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emergencyNameController = TextEditingController();
  final TextEditingController _emergencyPhoneController = TextEditingController();

  // ✅ FocusNodes para manejo de teclado y navegación entre campos
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _lastNameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _emergencyNameFocusNode = FocusNode();
  final FocusNode _emergencyPhoneFocusNode = FocusNode();

  // User data
  String _profileImagePath = '';
  String _birthDate = '';
  String _gender = 'Masculino';
  String _documentType = 'DNI';
  String _documentNumber = '';
  bool _notificationsEnabled = true;
  bool _smsEnabled = false;
  bool _emailPromotions = true;
  bool _locationSharing = true;
  
  // Form state
  bool _isLoading = false;
  bool _hasChanges = false;
  
  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    );
    
    _loadUserData();
    _fadeController.forward();
    _slideController.forward();
    
    // Listen for changes
    _nameController.addListener(_onFieldChanged);
    _lastNameController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _emergencyNameController.addListener(_onFieldChanged);
    _emergencyPhoneController.addListener(_onFieldChanged);
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _nameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    // ✅ Dispose de FocusNodes
    _nameFocusNode.dispose();
    _lastNameFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    _emergencyNameFocusNode.dispose();
    _emergencyPhoneFocusNode.dispose();
    super.dispose();
  }

  // ✅ Método helper para ocultar teclado de manera confiable en Android
  void _hideKeyboard() {
    FocusScope.of(context).unfocus(); // Quita el foco
    SystemChannels.textInput.invokeMethod('TextInput.hide'); // Fuerza el ocultamiento en Android
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }
  
  Future<void> _loadUserData() async {
    try {
      setState(() => _isLoading = true);

      // Los datos del usuario vienen del backend Node vía AuthProvider (JWT).
      final authProvider = context.read<AuthProvider>();
      final currentUser = authProvider.currentUser;
      if (currentUser == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Usuario no autenticado'),
              backgroundColor: ModernTheme.error,
            ),
          );
          Navigator.pop(context);
        }
        return;
      }
      _userId = currentUser.id;

      // Los campos guardados como extras (documentType, gender, emergency, etc.)
      // aún no están mapeados en /api/auth/me. Pre-cargamos lo que tengamos
      // y dejamos los adicionales vacíos hasta que el backend los exponga.
      // TODO(node-migration): mapear extras en GET /api/auth/me cuando existan.
      final fullNameParts = currentUser.fullName.trim().split(' ');
      final firstName = fullNameParts.isNotEmpty ? fullNameParts.first : '';
      final lastName = fullNameParts.length > 1
          ? fullNameParts.sublist(1).join(' ')
          : '';

      setState(() {
        _nameController.text = firstName;
        _lastNameController.text = lastName;
        _emailController.text = currentUser.email;
        _phoneController.text = currentUser.phone;
        _birthDate = currentUser.birthDate ?? '';
        _documentNumber = currentUser.identityDocument ?? '';
        _profileImagePath = currentUser.profilePhotoUrl;
      });
    } catch (e) {
      AppLogger.error(userFriendlyError(e, fallback: 'Error cargando datos del usuario'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos del perfil'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (!mounted) return;
        if (shouldPop) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: context.surfaceColor,
        appBar: AppBar(
          backgroundColor: ModernTheme.rappiOrange,
          elevation: 0,
          title: Text(
            'Editar Perfil',
            style: TextStyle(
              color: Theme.of(context).colorScheme.surface,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            if (_hasChanges)
              TextButton(
                onPressed: _isLoading ? null : _saveProfile,
                child: Text(
                  'Guardar',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.surface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        body: AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Form(
                key: _formKey,
                child: GestureDetector(
                  onTap: _hideKeyboard, // ✅ Cierra teclado al tocar fuera (Android compatible)
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
                    child: Column(
                      children: [
                      // Profile image section
                      _buildProfileImageSection(),
                      
                      SizedBox(height: 32),
                      
                      // Personal information
                      _buildPersonalInfoSection(),
                      
                      SizedBox(height: 24),
                      
                      // Contact information
                      _buildContactInfoSection(),
                      
                      SizedBox(height: 24),
                      
                      // Document information
                      _buildDocumentInfoSection(),
                      
                      SizedBox(height: 24),
                      
                      // Emergency contact
                      _buildEmergencyContactSection(),
                      
                      SizedBox(height: 24),
                      
                      // Preferences
                      _buildPreferencesSection(),
                      
                      SizedBox(height: 32),
                      
                      // Save button
                      _buildSaveButton(),
                      
                      SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ), // Scaffold
  ); // PopScope
}
  
  Widget _buildProfileImageSection() {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - _slideAnimation.value)),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _profileImagePath.isEmpty
                          ? LinearGradient(
                              colors: [ModernTheme.rappiOrange, ModernTheme.rappiOrange.withValues(alpha: 0.7)],
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
                      boxShadow: [
                        BoxShadow(
                          color: ModernTheme.rappiOrange.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _profileImagePath.isEmpty
                        ? Icon(
                            Icons.person,
                            size: 60,
                            color: Theme.of(context).colorScheme.surface,
                          )
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
                          color: ModernTheme.primaryBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Theme.of(context).colorScheme.onPrimary, width: 2),
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          color: Theme.of(context).colorScheme.surface,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                'Toca para cambiar foto',
                style: TextStyle(
                  color: context.secondaryText,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildPersonalInfoSection() {
    return _buildSection(
      'Información Personal',
      Icons.person,
      ModernTheme.primaryBlue,
      [
        Row(
          children: [
            Expanded(
              child: _buildTextFormField(
                controller: _nameController,
                label: 'Nombres',
                icon: Icons.person_outline,
                focusNode: _nameFocusNode, // ✅ FocusNode configurado
                textInputAction: TextInputAction.next, // ✅ Botón Next para ir a apellido
                onFieldSubmitted: (_) => _lastNameFocusNode.requestFocus(), // ✅ Avanza al campo de apellido
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa tu nombre';
                  }
                  return null;
                },
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildTextFormField(
                controller: _lastNameController,
                label: 'Apellidos',
                icon: Icons.person_outline,
                focusNode: _lastNameFocusNode, // ✅ FocusNode configurado
                textInputAction: TextInputAction.next, // ✅ Botón Next para ir a email
                onFieldSubmitted: (_) => _emailFocusNode.requestFocus(), // ✅ Avanza al campo de email
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa tus apellidos';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        GestureDetector(
          onTap: _selectBirthDate,
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: context.secondaryText),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _birthDate.isEmpty ? 'Fecha de nacimiento' : _birthDate,
                    style: TextStyle(
                      color: _birthDate.isEmpty ? context.secondaryText : context.primaryText,
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: context.secondaryText),
              ],
            ),
          ),
        ),
        SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _gender,
          decoration: InputDecoration(
            labelText: 'Género',
            prefixIcon: Icon(Icons.wc),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          items: ['Masculino', 'Femenino', 'Otro', 'Prefiero no decir'].map((gender) {
            return DropdownMenuItem(
              value: gender,
              child: Text(gender),
            );
          }).toList(),
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
      ModernTheme.rappiOrange,
      [
        _buildTextFormField(
          controller: _emailController,
          label: 'Correo electrónico',
          icon: Icons.email_outlined,
          focusNode: _emailFocusNode, // ✅ FocusNode configurado
          textInputAction: TextInputAction.next, // ✅ Botón Next para ir a teléfono
          onFieldSubmitted: (_) => _phoneFocusNode.requestFocus(), // ✅ Avanza al campo de teléfono
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Ingresa tu email';
            }
            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
              return 'Ingresa un email válido';
            }
            return null;
          },
        ),
        SizedBox(height: 16),
        // ✅ MODIFICADO: Campo de teléfono con botón para cambiar número
        GestureDetector(
          onTap: () async {
            // Abrir pantalla de cambio de número
            final result = await Navigator.pushNamed(
              context,
              '/change-phone-number',
              arguments: _phoneController.text.trim(),
            );

            // Si se cambió exitosamente, recargar datos
            if (result == true && mounted) {
              await _loadUserData();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Número actualizado. Recargando perfil...'),
                  backgroundColor: ModernTheme.success,
                ),
              );
            }
          },
          child: AbsorbPointer(
            child: TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Número de teléfono',
                prefixIcon: Icon(Icons.phone_outlined),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, color: ModernTheme.success, size: 20),
                    SizedBox(width: 8),
                    Icon(Icons.edit, color: ModernTheme.rappiOrange, size: 20),
                    SizedBox(width: 12),
                  ],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: ModernTheme.rappiOrange, width: 2),
                ),
                helperText: 'Toca para cambiar tu número de teléfono',
                helperStyle: TextStyle(
                  color: ModernTheme.info,
                  fontSize: 12,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa tu teléfono';
                }
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
      Colors.orange,
      [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: _documentType,
                decoration: InputDecoration(
                  labelText: 'Tipo',
                  prefixIcon: Icon(Icons.assignment_ind),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: ['DNI', 'Pasaporte', 'Carné de Extranjería'].map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _documentType = value!;
                    _hasChanges = true;
                  });
                },
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: TextEditingController(text: _documentNumber),
                decoration: InputDecoration(
                  labelText: 'Número',
                  prefixIcon: Icon(Icons.numbers),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Requerido';
                  }
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
      ModernTheme.error,
      [
        _buildTextFormField(
          controller: _emergencyNameController,
          label: 'Nombre completo',
          icon: Icons.person_pin,
          focusNode: _emergencyNameFocusNode, // ✅ FocusNode configurado
          textInputAction: TextInputAction.next, // ✅ Botón Next para ir a teléfono de emergencia
          onFieldSubmitted: (_) => _emergencyPhoneFocusNode.requestFocus(), // ✅ Avanza al teléfono de emergencia
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Ingresa el nombre del contacto';
            }
            return null;
          },
        ),
        SizedBox(height: 16),
        _buildTextFormField(
          controller: _emergencyPhoneController,
          label: 'Teléfono de emergencia',
          icon: Icons.phone_in_talk,
          focusNode: _emergencyPhoneFocusNode, // ✅ FocusNode configurado
          textInputAction: TextInputAction.done, // ✅ Botón Done en teclado (último campo)
          onFieldSubmitted: (_) => FocusScope.of(context).unfocus(), // ✅ Cierra teclado al presionar Done
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
      Colors.purple,
      [
        SwitchListTile(
          title: Text('Notificaciones push'),
          subtitle: Text('Recibir notificaciones en el dispositivo'),
          value: _notificationsEnabled,
          onChanged: (value) {
            setState(() {
              _notificationsEnabled = value;
              _hasChanges = true;
            });
          },
          thumbColor: WidgetStateProperty.all(ModernTheme.rappiOrange),
        ),
        SwitchListTile(
          title: Text('Notificaciones SMS'),
          subtitle: Text('Recibir actualizaciones por mensaje de texto'),
          value: _smsEnabled,
          onChanged: (value) {
            setState(() {
              _smsEnabled = value;
              _hasChanges = true;
            });
          },
          thumbColor: WidgetStateProperty.all(ModernTheme.rappiOrange),
        ),
        SwitchListTile(
          title: Text('Promociones por email'),
          subtitle: Text('Recibir ofertas y descuentos por correo'),
          value: _emailPromotions,
          onChanged: (value) {
            setState(() {
              _emailPromotions = value;
              _hasChanges = true;
            });
          },
          thumbColor: WidgetStateProperty.all(ModernTheme.rappiOrange),
        ),
        SwitchListTile(
          title: Text('Compartir ubicación'),
          subtitle: Text('Permitir compartir ubicación durante viajes'),
          value: _locationSharing,
          onChanged: (value) {
            setState(() {
              _locationSharing = value;
              _hasChanges = true;
            });
          },
          thumbColor: WidgetStateProperty.all(ModernTheme.rappiOrange),
        ),
      ],
    );
  }
  
  Widget _buildSection(String title, IconData icon, Color color, List<Widget> children) {
    // Cards por sección con borderRadius 16, padding 20, borde gris claro
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header de la sección
            Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  SizedBox(width: 10),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
  
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    FocusNode? focusNode, // ✅ FocusNode para navegación
    TextInputAction? textInputAction, // ✅ Acción del teclado (next/done)
    ValueChanged<String>? onFieldSubmitted, // ✅ Callback al presionar Enter/Done
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode, // ✅ FocusNode configurado
      textInputAction: textInputAction, // ✅ Botón del teclado configurado
      onFieldSubmitted: onFieldSubmitted, // ✅ Callback configurado
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ModernTheme.rappiOrange, width: 2),
        ),
      ),
    );
  }
  
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading || !_hasChanges ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: ModernTheme.rappiOrange,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary),
                ),
              )
            : Text(
                'Guardar Cambios',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
  
  void _changeProfileImage() {
    showResponsiveBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cambiar foto de perfil',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromCamera();
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ModernTheme.primaryBlue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          color: ModernTheme.primaryBlue,
                          size: 32,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('Cámara'),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.photo_library,
                          color: ModernTheme.rappiOrange,
                          size: 32,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('Galería'),
                    ],
                  ),
                ),
                if (_profileImagePath.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _removeProfileImage();
                    },
                    child: Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: ModernTheme.error.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.delete,
                            color: ModernTheme.error,
                            size: 32,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text('Eliminar'),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  /// ✅ CORREGIDO: Tomar foto con la cámara real usando image_picker
  Future<void> _pickImageFromCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _profileImagePath = image.path; // Usar ruta real del archivo
        _hasChanges = true;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onPrimary, size: 20),
              SizedBox(width: 12),
              Text('Foto tomada desde la cámara'),
            ],
          ),
          backgroundColor: ModernTheme.info,
        ),
      );
    } catch (e) {
      debugPrint(userFriendlyError(e, fallback: 'Error tomando foto'));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFriendlyError(e, fallback: 'Error al tomar foto')),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  /// ✅ CORREGIDO: Seleccionar imagen de galería real usando image_picker
  Future<void> _pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _profileImagePath = image.path; // Usar ruta real del archivo
        _hasChanges = true;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onPrimary, size: 20),
              SizedBox(width: 12),
              Text('Imagen seleccionada de la galería'),
            ],
          ),
          backgroundColor: ModernTheme.info,
        ),
      );
    } catch (e) {
      debugPrint(userFriendlyError(e, fallback: 'Error seleccionando imagen'));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFriendlyError(e, fallback: 'Error al seleccionar imagen')),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }
  
  void _removeProfileImage() {
    setState(() {
      _profileImagePath = '';
      _hasChanges = true;
    });
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Foto de perfil eliminada'),
        backgroundColor: ModernTheme.warning,
      ),
    );
  }
  
  void _selectBirthDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(1990, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(Duration(days: 365 * 18)), // Minimum 18 years
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: ModernTheme.rappiOrange,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (selectedDate != null && mounted) {
      setState(() {
        _birthDate = '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}';
        _hasChanges = true;
      });
    }
  }
  
  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Descartar cambios?'),
        content: Text('Tienes cambios sin guardar. ¿Estás seguro de que quieres salir?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.error,
            ),
            child: Text('Descartar'),
          ),
        ],
      ),
    );
    
    return shouldDiscard ?? false;
  }
  
  /// Guarda el perfil llamando al backend Node (upload + PATCH /me).
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // PASO 1: subir la foto al bucket via /api/storage/upload si es archivo local.
      String? profileImageUrl = _profileImagePath;
      if (_profileImagePath.isNotEmpty &&
          !_profileImagePath.startsWith('http://') &&
          !_profileImagePath.startsWith('https://')) {
        try {
          final file = File(_profileImagePath);
          if (await file.exists()) {
            AppLogger.debug('Subiendo foto de perfil a backend Node...');
            final uploaded = await _api.uploadFile(file: file, scope: 'avatar');
            profileImageUrl = uploaded['url'] as String? ??
                uploaded['publicUrl'] as String? ??
                profileImageUrl;
            AppLogger.debug('✅ Foto subida: $profileImageUrl');
          }
        } catch (e) {
          AppLogger.error(userFriendlyError(e, fallback: 'Error subiendo foto de perfil'));
          // No fallar el guardado si hay error en la foto
        }
      }

      // PASO 2: persistir los cambios vía AuthProvider (que llama al backend).
      // TODO(node-migration): AuthProvider.updateProfile aún no persiste los
      // extras (gender, documentType, emergency, preferencias). Cuando el
      // backend exponga PATCH /api/auth/me completo, mapear estos campos aquí.
      final authProvider = context.read<AuthProvider>();
      final combinedName = [
        _nameController.text.trim(),
        _lastNameController.text.trim(),
      ].where((p) => p.isNotEmpty).join(' ').trim();

      await authProvider.updateProfile(
        fullName: combinedName.isEmpty ? null : combinedName,
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        profilePhotoUrl: profileImageUrl,
        birthDate: _birthDate.isEmpty ? null : _birthDate,
        identityDocument: _documentNumber.isEmpty ? null : _documentNumber,
        extraFields: {
          'gender': _gender,
          'documentType': _documentType,
          'emergencyContactName': _emergencyNameController.text.trim(),
          'emergencyContactPhone': _emergencyPhoneController.text.trim(),
          'notificationsEnabled': _notificationsEnabled,
          'smsEnabled': _smsEnabled,
          'emailPromotions': _emailPromotions,
          'locationSharing': _locationSharing,
        },
      );
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasChanges = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Perfil actualizado exitosamente'),
            backgroundColor: ModernTheme.success,
            action: SnackBarAction(
              label: 'Ver perfil',
              textColor: Theme.of(context).colorScheme.onPrimary,
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
        );
      }
    } catch (e) {
      AppLogger.error(userFriendlyError(e, fallback: 'Error guardando perfil'));
      if (mounted) {
        setState(() => _isLoading = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar el perfil'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }
}