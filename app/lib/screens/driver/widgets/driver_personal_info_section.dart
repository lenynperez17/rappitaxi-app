import 'package:flutter/material.dart';

import '../../../core/design/design_system.dart';
import '../../../core/widgets/rt_button.dart';
import '../driver_profile_screen.dart';

/// Seccion de información personal del conductor con modo edicion inline.
/// Incluye nombre, teléfono, email, bio y contacto de emergencia.
class DriverPersonalInfoSection extends StatelessWidget {
  final DriverProfile profile;
  final bool isEditing;
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController bioController;
  final TextEditingController emergencyContactController;
  final TextEditingController emergencyPhoneController;
  final VoidCallback onToggleEdit;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const DriverPersonalInfoSection({
    super.key,
    required this.profile,
    required this.isEditing,
    required this.formKey,
    required this.nameController,
    required this.phoneController,
    required this.emailController,
    required this.bioController,
    required this.emergencyContactController,
    required this.emergencyPhoneController,
    required this.onToggleEdit,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return _buildSection(
      context,
      'Información Personal',
      Icons.person,
      RtColors.info,
      [
        if (isEditing) ...[
          _buildEditForm(context),
        ] else ...[
          _buildInfoRow(context, 'Nombre', profile.name, Icons.person),
          _buildInfoRow(context, 'Teléfono', profile.phone, Icons.phone),
          _buildInfoRow(context, 'Email', profile.email, Icons.email),
          if (profile.bio.isNotEmpty)
            _buildInfoRow(context, 'Bio', profile.bio, Icons.description),
        ],
        const SizedBox(height: RtSpacing.lg),

        // Contacto de emergencia
        Text(
          'Contacto de Emergencia',
          style: RtTypo.titleLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: RtColors.error,
          ),
        ),
        const SizedBox(height: RtSpacing.md),

        if (isEditing) ...[
          _buildEmergencyEditFields(context),
        ] else ...[
          _buildInfoRow(context, 'Nombre', profile.emergencyContact.name, Icons.emergency),
          _buildInfoRow(context, 'Teléfono', profile.emergencyContact.phone, Icons.phone_in_talk),
          _buildInfoRow(context, 'Relacion', profile.emergencyContact.relationship, Icons.family_restroom),
        ],

        // Botones de accion en modo edicion
        if (isEditing) ...[
          const SizedBox(height: RtSpacing.xl),
          _buildActionButtons(context),
        ],
      ],
      onEdit: isEditing ? null : onToggleEdit,
    );
  }

  /// Formulario de edicion de datos personales
  Widget _buildEditForm(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          _buildTextFormField(
            context,
            controller: nameController,
            label: 'Nombre completo',
            icon: Icons.person,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa tu nombre completo';
              }
              return null;
            },
          ),
          const SizedBox(height: RtSpacing.base),
          _buildTextFormField(
            context,
            controller: phoneController,
            label: 'Teléfono',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa tu teléfono';
              }
              return null;
            },
          ),
          const SizedBox(height: RtSpacing.base),
          _buildTextFormField(
            context,
            controller: emailController,
            label: 'Correo electronico',
            icon: Icons.email,
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
          const SizedBox(height: RtSpacing.base),
          _buildTextFormField(
            context,
            controller: bioController,
            label: 'Descripción personal',
            icon: Icons.description,
            maxLines: 3,
            validator: (value) {
              if (value != null && value.length > 200) {
                return 'Máximo 200 caracteres';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  /// Campos de edicion del contacto de emergencia
  Widget _buildEmergencyEditFields(BuildContext context) {
    return Column(
      children: [
        _buildTextFormField(
          context,
          controller: emergencyContactController,
          label: 'Nombre del contacto',
          icon: Icons.emergency,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Ingresa el nombre del contacto';
            }
            return null;
          },
        ),
        const SizedBox(height: RtSpacing.base),
        _buildTextFormField(
          context,
          controller: emergencyPhoneController,
          label: 'Teléfono de emergencia',
          icon: Icons.phone_in_talk,
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

  /// Botones cancelar y guardar
  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: RtButton(
            label: 'Cancelar',
            onPressed: onCancel,
            variant: RtButtonVariant.outlined,
            icon: Icons.cancel,
            size: RtButtonSize.medium,
          ),
        ),
        const SizedBox(width: RtSpacing.md),
        Expanded(
          child: RtButton(
            label: 'Guardar',
            onPressed: onSave,
            variant: RtButtonVariant.primary,
            icon: Icons.save,
            size: RtButtonSize.medium,
          ),
        ),
      ],
    );
  }

  /// Fila de información: icono, etiqueta y valor
  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RtSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: RtColors.neutral500),
          const SizedBox(width: RtSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: RtTypo.bodySmall.copyWith(
                    color: RtColors.neutral500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: RtTypo.bodyMedium.copyWith(
                    color: RtColors.neutral900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Campo de texto con estilo del design system
  Widget _buildTextFormField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: RtRadius.borderMd,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: RtRadius.borderMd,
          borderSide: const BorderSide(color: RtColors.brand, width: 2),
        ),
      ),
    );
  }

  /// Contenedor de seccion con titulo, icono y boton de editar
  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    List<Widget> children, {
    VoidCallback? onEdit,
  }) {
    return Container(
      margin: RtSpacing.paddingBase,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: RtRadius.borderLg,
        boxShadow: RtShadow.soft(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: RtSpacing.paddingBase,
            child: Row(
              children: [
                Icon(icon, color: color, size: RtIconSize.sm),
                const SizedBox(width: RtSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: RtTypo.headingSmall.copyWith(color: color),
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    icon: Icon(Icons.edit, color: color, size: RtIconSize.sm),
                    onPressed: onEdit,
                    tooltip: 'Editar',
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              RtSpacing.base, 0, RtSpacing.base, RtSpacing.base,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
