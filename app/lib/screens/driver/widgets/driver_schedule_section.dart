import 'package:flutter/material.dart';

import '../../../core/design/design_system.dart';
import '../../../core/widgets/rt_button.dart';
import '../driver_profile_screen.dart';
import '../documents_screen.dart';
import '../earnings_withdrawal_screen.dart';

/// Seccion de preferencias de trabajo del conductor con modo edicion inline.
/// Incluye mascotas, fumar, musica, idiomas, distancia y zonas.
class DriverPreferencesSection extends StatelessWidget {
  final DriverProfile profile;
  final bool isEditing;
  final GlobalKey<FormState> formKey;
  final bool acceptPets;
  final bool acceptSmoking;
  final String musicPreference;
  final List<String> languages;
  final double maxTripDistance;
  final List<String> preferredZones;
  final VoidCallback onToggleEdit;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final ValueChanged<bool> onAcceptPetsChanged;
  final ValueChanged<bool> onAcceptSmokingChanged;
  final ValueChanged<String> onMusicPreferenceChanged;
  final ValueChanged<List<String>> onLanguagesChanged;
  final ValueChanged<double> onMaxTripDistanceChanged;
  final ValueChanged<List<String>> onPreferredZonesChanged;

  const DriverPreferencesSection({
    super.key,
    required this.profile,
    required this.isEditing,
    required this.formKey,
    required this.acceptPets,
    required this.acceptSmoking,
    required this.musicPreference,
    required this.languages,
    required this.maxTripDistance,
    required this.preferredZones,
    required this.onToggleEdit,
    required this.onSave,
    required this.onCancel,
    required this.onAcceptPetsChanged,
    required this.onAcceptSmokingChanged,
    required this.onMusicPreferenceChanged,
    required this.onLanguagesChanged,
    required this.onMaxTripDistanceChanged,
    required this.onPreferredZonesChanged,
  });

  static const Color _sectionColor = RtColors.accentPurple;

  @override
  Widget build(BuildContext context) {
    return _buildSection(
      context,
      'Preferencias de Trabajo',
      Icons.settings,
      _sectionColor,
      [
        if (isEditing) ...[
          _buildEditForm(context),
        ] else ...[
          _buildPreferenceRow('Acepta mascotas', profile.preferences.acceptPets),
          _buildPreferenceRow('Permite fumar', profile.preferences.acceptSmoking),
          _buildInfoRow(
            'Musica preferida',
            profile.preferences.musicPreference,
            Icons.music_note,
          ),
          _buildInfoRow(
            'Idiomas',
            profile.preferences.languages.join(', '),
            Icons.language,
          ),
          _buildInfoRow(
            'Distancia maxima',
            '${profile.preferences.maxTripDistance} km',
            Icons.straighten,
          ),
          const SizedBox(height: RtSpacing.md),
          Text(
            'Zonas preferidas:',
            style: RtTypo.titleMedium.copyWith(
              fontWeight: FontWeight.w500,
              color: RtColors.neutral900,
            ),
          ),
          const SizedBox(height: RtSpacing.sm),
          Wrap(
            spacing: RtSpacing.sm,
            runSpacing: RtSpacing.xs,
            children: profile.preferences.preferredZones.map((zone) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: RtSpacing.sm,
                  vertical: RtSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: _sectionColor.withValues(alpha: 0.1),
                  borderRadius: RtRadius.borderSm,
                ),
                child: Text(
                  zone,
                  style: RtTypo.bodySmall.copyWith(color: _sectionColor),
                ),
              );
            }).toList(),
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

  /// Formulario de edicion de preferencias
  Widget _buildEditForm(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Acepta mascotas
          SwitchListTile(
            title: const Text('Acepta mascotas'),
            subtitle: const Text('Permitir pasajeros con mascotas'),
            value: acceptPets,
            activeTrackColor: _sectionColor.withValues(alpha: 0.4),
            thumbColor: WidgetStatePropertyAll(
              acceptPets ? _sectionColor : RtColors.neutral400,
            ),
            onChanged: (value) => onAcceptPetsChanged(value),
          ),
          const SizedBox(height: RtSpacing.sm),

          // Acepta fumadores
          SwitchListTile(
            title: const Text('Permite fumar'),
            subtitle: const Text('Permitir pasajeros que fuman'),
            value: acceptSmoking,
            activeTrackColor: _sectionColor.withValues(alpha: 0.4),
            thumbColor: WidgetStatePropertyAll(
              acceptSmoking ? _sectionColor : RtColors.neutral400,
            ),
            onChanged: (value) => onAcceptSmokingChanged(value),
          ),
          const SizedBox(height: RtSpacing.base),

          // Musica preferida
          DropdownButtonFormField<String>(
            initialValue: musicPreference,
            decoration: InputDecoration(
              labelText: 'Musica preferida',
              prefixIcon: const Icon(Icons.music_note, color: _sectionColor),
              border: OutlineInputBorder(borderRadius: RtRadius.borderMd),
            ),
            items: const [
              'Ninguna', 'Pop', 'Rock', 'Clasica', 'Reggaeton',
              'Salsa', 'Electronica', 'Jazz',
            ].map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (String? newValue) {
              onMusicPreferenceChanged(newValue ?? 'Ninguna');
            },
          ),
          const SizedBox(height: RtSpacing.base),

          // Idiomas
          Text(
            'Idiomas que hablas',
            style: RtTypo.titleLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: RtColors.neutral900,
            ),
          ),
          const SizedBox(height: RtSpacing.sm),
          Wrap(
            spacing: RtSpacing.sm,
            runSpacing: RtSpacing.sm,
            children: [
              'Español', 'Inglés', 'Francés', 'Alemán', 'Italiano', 'Portugués',
            ].map((String language) {
              final isSelected = languages.contains(language);
              return FilterChip(
                label: Text(language),
                selected: isSelected,
                onSelected: (bool selected) {
                  final updatedLanguages = List<String>.from(languages);
                  if (selected) {
                    updatedLanguages.add(language);
                  } else {
                    if (updatedLanguages.length > 1) {
                      updatedLanguages.remove(language);
                    }
                  }
                  onLanguagesChanged(updatedLanguages);
                },
                selectedColor: _sectionColor.withValues(alpha: 0.2),
                checkmarkColor: _sectionColor,
              );
            }).toList(),
          ),
          const SizedBox(height: RtSpacing.base),

          // Distancia maxima
          Text(
            'Distancia maxima de viaje: ${maxTripDistance.toStringAsFixed(0)} km',
            style: RtTypo.titleLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: RtColors.neutral900,
            ),
          ),
          const SizedBox(height: RtSpacing.sm),
          Slider(
            value: maxTripDistance,
            min: 5,
            max: 100,
            divisions: 19,
            label: '${maxTripDistance.toStringAsFixed(0)} km',
            activeColor: _sectionColor,
            onChanged: (double value) => onMaxTripDistanceChanged(value),
          ),
          const SizedBox(height: RtSpacing.base),

          // Zonas preferidas
          Text(
            'Zonas preferidas',
            style: RtTypo.titleLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: RtColors.neutral900,
            ),
          ),
          const SizedBox(height: RtSpacing.sm),
          Wrap(
            spacing: RtSpacing.sm,
            runSpacing: RtSpacing.sm,
            children: [
              'Centro', 'Norte', 'Sur', 'Este', 'Oeste',
              'Aeropuerto', 'Zona Industrial', 'Zona Comercial',
            ].map((String zone) {
              final isSelected = preferredZones.contains(zone);
              return FilterChip(
                label: Text(zone),
                selected: isSelected,
                onSelected: (bool selected) {
                  final updatedZones = List<String>.from(preferredZones);
                  if (selected) {
                    updatedZones.add(zone);
                  } else {
                    updatedZones.remove(zone);
                  }
                  onPreferredZonesChanged(updatedZones);
                },
                selectedColor: _sectionColor.withValues(alpha: 0.2),
                checkmarkColor: _sectionColor,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Fila de preferencia booleana con icono de estado
  Widget _buildPreferenceRow(String label, bool value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RtSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: RtTypo.bodyMedium.copyWith(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: RtSpacing.sm),
          Icon(
            value ? Icons.check_circle : Icons.cancel,
            color: value ? RtColors.success : RtColors.error,
            size: RtIconSize.sm,
          ),
        ],
      ),
    );
  }

  /// Fila de información con icono
  Widget _buildInfoRow(String label, String value, IconData icon) {
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

  /// Contenedor de seccion reutilizable
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

/// Seccion de horario de trabajo del conductor con modo edicion inline.
/// Muestra los 7 días de la semana con hora de inicio y fin.
class DriverWorkScheduleSection extends StatelessWidget {
  final DriverProfile profile;
  final bool isEditing;
  final GlobalKey<FormState> formKey;
  final Map<String, Map<String, dynamic>> weekSchedule;
  final VoidCallback onToggleEdit;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final void Function(String day, String field, dynamic value) onScheduleChanged;

  static const Color _sectionColor = RtColors.warning;

  const DriverWorkScheduleSection({
    super.key,
    required this.profile,
    required this.isEditing,
    required this.formKey,
    required this.weekSchedule,
    required this.onToggleEdit,
    required this.onSave,
    required this.onCancel,
    required this.onScheduleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _buildSection(
      context,
      'Horario de Trabajo',
      Icons.schedule,
      _sectionColor,
      [
        if (isEditing) ...[
          _buildEditForm(context),
        ] else ...[
          _buildScheduleRow(context, 'Lunes', profile.workSchedule.mondayStart, profile.workSchedule.mondayEnd),
          _buildScheduleRow(context, 'Martes', profile.workSchedule.tuesdayStart, profile.workSchedule.tuesdayEnd),
          _buildScheduleRow(context, 'Miércoles', profile.workSchedule.wednesdayStart, profile.workSchedule.wednesdayEnd),
          _buildScheduleRow(context, 'Jueves', profile.workSchedule.thursdayStart, profile.workSchedule.thursdayEnd),
          _buildScheduleRow(context, 'Viernes', profile.workSchedule.fridayStart, profile.workSchedule.fridayEnd),
          _buildScheduleRow(context, 'Sábado', profile.workSchedule.saturdayStart, profile.workSchedule.saturdayEnd),
          _buildScheduleRow(context, 'Domingo', profile.workSchedule.sundayStart, profile.workSchedule.sundayEnd),
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

  /// Formulario de edicion con time pickers
  Widget _buildEditForm(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: weekSchedule.entries.map((entry) {
          final day = entry.key;
          final dayData = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: RtSpacing.md),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: RtRadius.borderMd,
              boxShadow: RtShadow.soft(),
            ),
            child: Padding(
              padding: RtSpacing.paddingMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fila:día + switch activo/inactivo
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        day,
                        style: RtTypo.titleLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Switch(
                        value: dayData['active'] as bool,
                        activeTrackColor: _sectionColor.withValues(alpha: 0.4),
                        thumbColor: WidgetStatePropertyAll(
                          (dayData['active'] as bool)
                              ? _sectionColor
                              : RtColors.neutral400,
                        ),
                        onChanged: (value) {
                          onScheduleChanged(day, 'active', value);
                        },
                      ),
                    ],
                  ),

                  if (dayData['active'] as bool) ...[
                    const SizedBox(height: RtSpacing.sm),
                    Row(
                      children: [
                        // Hora de inicio
                        Expanded(
                          child: _buildTimePicker(
                            context,
                            day: day,
                            field: 'start',
                            time: dayData['start'] as TimeOfDay,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: RtSpacing.sm),
                          child: Icon(Icons.arrow_forward, size: 16),
                        ),
                        // Hora de fin
                        Expanded(
                          child: _buildTimePicker(
                            context,
                            day: day,
                            field: 'end',
                            time: dayData['end'] as TimeOfDay,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Selector de hora reutilizable
  Widget _buildTimePicker(
    BuildContext context, {
    required String day,
    required String field,
    required TimeOfDay time,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: _sectionColor,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          onScheduleChanged(day, field, picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: RtSpacing.md,
          horizontal: RtSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: RtColors.neutral300),
          borderRadius: RtRadius.borderSm,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.access_time, size: 16, color: _sectionColor),
            const SizedBox(width: RtSpacing.sm),
            Text(
              time.format(context),
              style: RtTypo.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  /// Fila de horario en modo vista
  Widget _buildScheduleRow(
    BuildContext context,
    String day,
    String startTime,
    String endTime,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RtSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              day,
              style: RtTypo.bodyMedium.copyWith(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: RtSpacing.sm),
          Flexible(
            flex: 3,
            child: Text(
              '$startTime - $endTime',
              style: RtTypo.bodyMedium.copyWith(color: RtColors.neutral500),
              overflow: TextOverflow.ellipsis,
            ),
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

  /// Contenedor de seccion reutilizable
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

/// Seccion de logros y reconocimientos del conductor.
class DriverAchievementsSection extends StatelessWidget {
  final DriverProfile profile;

  const DriverAchievementsSection({
    super.key,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    if (profile.achievements.isEmpty) return const SizedBox.shrink();

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
                const Icon(Icons.emoji_events, color: RtColors.warning, size: RtIconSize.sm),
                const SizedBox(width: RtSpacing.sm),
                Text(
                  'Logros y Reconocimientos',
                  style: RtTypo.headingSmall.copyWith(color: RtColors.warning),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              RtSpacing.base, 0, RtSpacing.base, RtSpacing.base,
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: RtSpacing.md,
                mainAxisSpacing: RtSpacing.md,
                childAspectRatio: 1.2,
              ),
              itemCount: profile.achievements.length,
              itemBuilder: (context, index) {
                return _buildAchievementCard(context, profile.achievements[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Card individual de logro
  Widget _buildAchievementCard(BuildContext context, Achievement achievement) {
    return Container(
      padding: RtSpacing.paddingMd,
      decoration: BoxDecoration(
        color: RtColors.warning.withValues(alpha: 0.05),
        borderRadius: RtRadius.borderMd,
        border: Border.all(color: RtColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: RtSpacing.paddingSm,
            decoration: BoxDecoration(
              color: RtColors.warning.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events,
              color: RtColors.warning,
              size: RtIconSize.md,
            ),
          ),
          const SizedBox(height: RtSpacing.sm),
          Text(
            achievement.name,
            style: RtTypo.labelSmall.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: RtSpacing.xs),
          Text(
            achievement.description,
            style: RtTypo.bodySmall.copyWith(
              fontSize: 10,
              color: RtColors.neutral500,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Seccion de documentos subidos por el conductor.
class DriverDocumentsSection extends StatelessWidget {
  final Map<String, String> documents;

  const DriverDocumentsSection({
    super.key,
    required this.documents,
  });

  /// Mapeo de claves de documento a etiquetas legibles
  static const Map<String, String> _documentLabels = {
    'dniPhoto': 'Documento de Identidad',
    'licensePhoto': 'Licencia de Conducir',
    'vehiclePhoto': 'Foto del Vehículo',
    'criminalRecordPhoto': 'Antecedentes Penales',
    'soatPhoto': 'SOAT',
    'technicalReviewPhoto': 'Revisión Técnica',
    'ownershipPhoto': 'Tarjeta de Propiedad',
  };

  /// Mapeo de claves de documento a iconos
  static const Map<String, IconData> _documentIcons = {
    'dniPhoto': Icons.badge,
    'licensePhoto': Icons.credit_card,
    'vehiclePhoto': Icons.directions_car,
    'criminalRecordPhoto': Icons.shield_outlined,
    'soatPhoto': Icons.verified_user_outlined,
    'technicalReviewPhoto': Icons.build_circle_outlined,
    'ownershipPhoto': Icons.article_outlined,
  };

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) return const SizedBox.shrink();

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
                const Icon(
                  Icons.folder_outlined,
                  color: RtColors.warning,
                  size: RtIconSize.sm,
                ),
                const SizedBox(width: RtSpacing.sm),
                Expanded(
                  child: Text(
                    'Documentos Subidos',
                    style: RtTypo.headingSmall.copyWith(color: RtColors.warning),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.edit,
                    color: RtColors.warning,
                    size: RtIconSize.sm,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DocumentsScreen(),
                      ),
                    );
                  },
                  tooltip: 'Editar documentos',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              RtSpacing.base, 0, RtSpacing.base, RtSpacing.base,
            ),
            child: Column(
              children: documents.entries.map((entry) {
                final label = _documentLabels[entry.key] ?? entry.key;
                final icon = _documentIcons[entry.key] ?? Icons.insert_drive_file;
                final hasDocument = entry.value.isNotEmpty;

                return _buildDocumentRow(context, label, icon, hasDocument, entry);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Fila individual de documento
  Widget _buildDocumentRow(
    BuildContext context,
    String label,
    IconData icon,
    bool hasDocument,
    MapEntry<String, String> entry,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RtSpacing.sm),
      child: Row(
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
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Icon(
                      hasDocument ? Icons.check_circle : Icons.cancel,
                      size: 14,
                      color: hasDocument ? RtColors.success : RtColors.error,
                    ),
                    const SizedBox(width: RtSpacing.xs),
                    Flexible(
                      child: Text(
                        hasDocument ? 'Subido' : 'No subido',
                        style: RtTypo.bodyMedium.copyWith(
                          color: hasDocument ? RtColors.success : RtColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (hasDocument)
            SizedBox(
              width: 48,
              child: IconButton(
                icon: const Icon(Icons.visibility, color: RtColors.info, size: RtIconSize.sm),
                onPressed: () => _viewDocument(context, entry.key, entry.value),
                tooltip: 'Ver documento',
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    );
  }

  /// Dialogo para ver la URL del documento
  void _viewDocument(BuildContext context, String documentType, String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ver Documento'),
        content: Text('URL del documento:\n\n$url'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

/// Seccion de métodos de retiro del conductor.
/// Muestra opciones de cuenta bancaria, tarjeta de débito y efectivo.
class DriverWithdrawalMethodsSection extends StatelessWidget {
  final DriverProfile? profile;
  final void Function(String method) onConfigureMethod;

  const DriverWithdrawalMethodsSection({
    super.key,
    required this.profile,
    required this.onConfigureMethod,
  });

  @override
  Widget build(BuildContext context) {
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
                const Icon(
                  Icons.account_balance_wallet,
                  color: RtColors.info,
                  size: RtIconSize.sm,
                ),
                const SizedBox(width: RtSpacing.sm),
                Expanded(
                  child: Text(
                    'Métodos de Retiro',
                    style: RtTypo.headingSmall.copyWith(color: RtColors.info),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: RtColors.info, size: RtIconSize.sm),
                  onPressed: () {
                    final userId = profile?.id;
                    if (userId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EarningsWithdrawalScreen(driverId: userId),
                        ),
                      );
                    }
                  },
                  tooltip: 'Configurar retiros',
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
              children: [
                Text(
                  'Configura tus métodos de retiro para recibir tus ganancias',
                  style: RtTypo.bodyMedium.copyWith(color: RtColors.neutral500),
                ),
                const SizedBox(height: RtSpacing.base),

                _buildPaymentMethodCard(
                  context,
                  'Cuenta Bancaria',
                  'Retiros en 1-2 días hábiles',
                  Icons.account_balance,
                  RtColors.success,
                  () => onConfigureMethod('bank'),
                ),
                const SizedBox(height: RtSpacing.md),
                _buildPaymentMethodCard(
                  context,
                  'Tarjeta de Débito',
                  'Retiros instantaneos',
                  Icons.credit_card,
                  RtColors.warning,
                  () => onConfigureMethod('card'),
                ),
                const SizedBox(height: RtSpacing.md),
                _buildPaymentMethodCard(
                  context,
                  'Efectivo en Oficina',
                  'Retiro inmediato en nuestras oficinas',
                  Icons.store,
                  RtColors.info,
                  () => onConfigureMethod('cash'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Card de método de pago
  Widget _buildPaymentMethodCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: RtRadius.borderMd,
      child: Container(
        padding: RtSpacing.paddingBase,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: RtRadius.borderMd,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: RtSpacing.paddingMd,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: RtIconSize.md),
            ),
            const SizedBox(width: RtSpacing.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: RtTypo.titleLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: RtColors.neutral900,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: RtSpacing.xs),
                  Text(
                    description,
                    style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }
}
