import 'package:flutter/material.dart';

import '../../../core/design/design_system.dart';
import '../../../core/widgets/rt_button.dart';
import '../driver_profile_screen.dart';

/// Seccion de información del vehículo con modo edicion inline.
/// Muestra marca, modelo, ano, color, placa y capacidad.
class DriverVehicleSection extends StatelessWidget {
  final DriverProfile profile;
  final bool isEditing;
  final GlobalKey<FormState> formKey;
  final TextEditingController makeController;
  final TextEditingController modelController;
  final TextEditingController yearController;
  final TextEditingController colorController;
  final TextEditingController plateController;
  final TextEditingController capacityController;
  final VoidCallback onToggleEdit;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const DriverVehicleSection({
    super.key,
    required this.profile,
    required this.isEditing,
    required this.formKey,
    required this.makeController,
    required this.modelController,
    required this.yearController,
    required this.colorController,
    required this.plateController,
    required this.capacityController,
    required this.onToggleEdit,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return _buildSection(
      context,
      'Información del Vehículo',
      Icons.directions_car,
      RtColors.brand,
      [
        if (isEditing) ...[
          _buildEditForm(context),
        ] else ...[
          _buildInfoRow(context, 'Marca', profile.vehicleInfo.make, Icons.directions_car),
          _buildInfoRow(context, 'Modelo', profile.vehicleInfo.model, Icons.drive_eta),
          _buildInfoRow(context, 'Ano', '${profile.vehicleInfo.year}', Icons.calendar_today),
          _buildInfoRow(context, 'Color', profile.vehicleInfo.color, Icons.palette),
          _buildInfoRow(context, 'Placa', profile.vehicleInfo.plate, Icons.confirmation_number),
          _buildInfoRow(
            context,
            'Capacidad',
            '${profile.vehicleInfo.capacity} pasajeros',
            Icons.people,
          ),
        ],

        // Botones de accion en modo edicion
        if (isEditing) ...[
          const SizedBox(height: RtSpacing.xl),
          _buildActionButtons(),
        ],
      ],
      onEdit: isEditing ? null : onToggleEdit,
    );
  }

  /// Formulario de edicion del vehículo
  Widget _buildEditForm(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          _buildTextFormField(
            context,
            controller: makeController,
            label: 'Marca',
            icon: Icons.business,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa la marca del vehículo';
              }
              return null;
            },
          ),
          const SizedBox(height: RtSpacing.base),
          _buildTextFormField(
            context,
            controller: modelController,
            label: 'Modelo',
            icon: Icons.drive_eta,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa el modelo del vehículo';
              }
              return null;
            },
          ),
          const SizedBox(height: RtSpacing.base),
          _buildTextFormField(
            context,
            controller: yearController,
            label: 'Ano',
            icon: Icons.calendar_today,
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa el ano del vehículo';
              }
              final year = int.tryParse(value);
              if (year == null || year < 1900 || year > DateTime.now().year + 1) {
                return 'Ingresa un ano válido';
              }
              return null;
            },
          ),
          const SizedBox(height: RtSpacing.base),
          _buildTextFormField(
            context,
            controller: colorController,
            label: 'Color',
            icon: Icons.palette,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa el color del vehículo';
              }
              return null;
            },
          ),
          const SizedBox(height: RtSpacing.base),
          _buildTextFormField(
            context,
            controller: plateController,
            label: 'Placa',
            icon: Icons.confirmation_number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa la placa del vehículo';
              }
              return null;
            },
          ),
          const SizedBox(height: RtSpacing.base),
          _buildTextFormField(
            context,
            controller: capacityController,
            label: 'Capacidad de pasajeros',
            icon: Icons.people,
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa la capacidad';
              }
              final capacity = int.tryParse(value);
              if (capacity == null || capacity < 1 || capacity > 50) {
                return 'Ingresa una capacidad válida (1-50)';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  /// Botones cancelar y guardar
  Widget _buildActionButtons() {
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
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
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
