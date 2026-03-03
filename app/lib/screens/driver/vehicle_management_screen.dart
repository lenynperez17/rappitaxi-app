import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/design/design_system.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_card.dart';
import '../../core/widgets/rt_badge.dart';
import '../../core/widgets/rt_button.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../core/widgets/rt_empty_state.dart';
import '../../utils/logger.dart';
import '../../utils/firestore_error_handler.dart';

class VehicleManagementScreen extends StatefulWidget {
  const VehicleManagementScreen({super.key});

  @override
  State<VehicleManagementScreen> createState() => _VehicleManagementScreenState();
}

class _VehicleManagementScreenState extends State<VehicleManagementScreen>
    with TickerProviderStateMixin {
  // Controladores de animacion
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Datos del vehículo cargados desde Firebase
  Map<String, dynamic> _vehicleData = {
    'brand': '',
    'model': '',
    'year': 0,
    'plate': '',
    'color': '',
    'vin': '',
    'seats': 0,
    'fuelType': '',
    'transmission': '',
    'mileage': 0,
    'status': 'inactive',
    'photos': <String>[],
  };

  // Documentos reales desde Firebase
  final List<VehicleDocument> _documents = [];

  // Registros de mantenimiento reales desde Firebase
  final List<MaintenanceRecord> _maintenanceRecords = [];

  // Recordatorios reales desde Firebase
  final List<Reminder> _reminders = [];

  int _selectedTab = 0;
  bool _isEditing = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _fadeController.forward();
    _loadVehicleDataFromFirebase();
  }

  // Cargar datos reales del vehículo desde Firebase
  Future<void> _loadVehicleDataFromFirebase() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        AppLogger.warning('No hay usuario autenticado en vehicle_management');
        setState(() => _isLoading = false);
        return;
      }

      final driverId = currentUser.uid;

      // Cargar información del vehículo desde el documento del conductor
      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .get();

      if (driverDoc.exists) {
        final driverData = driverDoc.data();
        if (driverData != null && driverData.containsKey('vehicleInfo')) {
          final vehicleInfo = driverData['vehicleInfo'] as Map<String, dynamic>;
          setState(() {
            _vehicleData = {
              'brand': vehicleInfo['brand'] ?? '',
              'model': vehicleInfo['model'] ?? '',
              'year': vehicleInfo['year'] ?? 0,
              'plate': vehicleInfo['plate'] ?? '',
              'color': vehicleInfo['color'] ?? '',
              'vin': vehicleInfo['vin'] ?? '',
              'seats': vehicleInfo['seats'] ?? 0,
              'fuelType': vehicleInfo['fuelType'] ?? 'Gasolina',
              'transmission': vehicleInfo['transmission'] ?? 'Manual',
              'mileage': vehicleInfo['mileage'] ?? 0,
              'status': vehicleInfo['status'] ?? 'active',
              'photos': (vehicleInfo['photos'] as List?)?.map((e) => e.toString()).toList() ?? [],
            };
          });
        }
      }

      // Cargar documentos del vehículo
      final docsSnapshot = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .collection('documents')
          .where('category', isEqualTo: 'vehicle')
          .get();

      final List<VehicleDocument> loadedDocs = [];
      for (var doc in docsSnapshot.docs) {
        final data = doc.data();
        final expiryDate = (data['expiryDate'] as Timestamp?)?.toDate();
        final issueDate = (data['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now();

        // Calcular estado del documento
        DocumentStatus status = DocumentStatus.pending;
        if (data['status'] == 'approved') {
          if (expiryDate != null) {
            final now = DateTime.now();
            final daysUntilExpiry = expiryDate.difference(now).inDays;
            if (daysUntilExpiry < 0) {
              status = DocumentStatus.expired;
            } else if (daysUntilExpiry < 30) {
              status = DocumentStatus.expiringSoon;
            } else {
              status = DocumentStatus.valid;
            }
          } else {
            status = DocumentStatus.valid;
          }
        }

        loadedDocs.add(VehicleDocument(
          id: doc.id,
          type: data['type'] ?? 'Documento',
          number: data['documentNumber'] ?? 'N/A',
          issueDate: issueDate,
          expiryDate: expiryDate,
          status: status,
          icon: _getDocumentIcon(data['type']),
          color: _getDocumentColor(data['type']),
        ));
      }

      setState(() {
        _documents.clear();
        _documents.addAll(loadedDocs);
        _isLoading = false;
      });

      AppLogger.info('Cargados datos del vehículo y ${loadedDocs.length} documentos desde Firebase');
    } catch (e) {
      AppLogger.error('Error cargando datos del vehículo: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        RtSnackbar.show(
          context,
          message: FirestoreErrorHandler.getSpanishMessage(e),
          type: RtSnackbarType.error,
        );
      }
    }
  }

  // Obtener icono según tipo de documento
  IconData _getDocumentIcon(String? type) {
    switch (type) {
      case 'vehicle_registration':
      case 'tarjeta_propiedad':
        return Icons.article;
      case 'insurance':
      case 'soat':
        return Icons.security;
      case 'technical_review':
      case 'revision_técnica':
        return Icons.build;
      default:
        return Icons.description;
    }
  }

  // Obtener color según tipo de documento
  Color _getDocumentColor(String? type) {
    switch (type) {
      case 'vehicle_registration':
      case 'tarjeta_propiedad':
        return RtColors.info;
      case 'insurance':
      case 'soat':
        return RtColors.success;
      case 'technical_review':
      case 'revision_técnica':
        return RtColors.warning;
      default:
        return RtColors.neutral400;
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: RtAppBar(
        title: 'Mi Vehículo',
        variant: RtAppBarVariant.gradient,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit, color: RtColors.white),
            onPressed: () {
              setState(() => _isEditing = !_isEditing);
              if (!_isEditing) {
                _saveChanges();
              }
            },
          ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: RtColors.brand))
        : AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Column(
                  children: [
                    _buildTabBar(),
                    Expanded(
                      child: IndexedStack(
                        index: _selectedTab,
                        children: [
                          _buildVehicleInfo(),
                          _buildDocuments(),
                          _buildMaintenance(),
                          _buildReminders(),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      floatingActionButton: _selectedTab > 0
          ? FloatingActionButton(
              onPressed: _showAddDialog,
              backgroundColor: RtColors.brand,
              child: const Icon(Icons.add, color: RtColors.white),
            )
          : null,
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          _buildTab('Vehículo', Icons.directions_car, 0),
          _buildTab('Documentos', Icons.folder, 1),
          _buildTab('Mantenimiento', Icons.build, 2),
          _buildTab('Recordatorios', Icons.notifications, 3),
        ],
      ),
    );
  }

  Widget _buildTab(String label, IconData icon, int index) {
    final isSelected = _selectedTab == index;
    final secondaryText = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: RtSpacing.base),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? RtColors.brand : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? RtColors.brand : secondaryText,
                size: RtIconSize.sm,
              ),
              const SizedBox(height: RtSpacing.xs),
              Text(
                label,
                style: RtTypo.labelSmall.copyWith(
                  color: isSelected ? RtColors.brand : secondaryText,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleInfo() {
    return SingleChildScrollView(
      padding: RtSpacing.paddingBase,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera del vehículo con gradiente brand
          Container(
            padding: const EdgeInsets.all(RtSpacing.lg),
            decoration: BoxDecoration(
              gradient: RtGradients.brand,
              borderRadius: RtRadius.borderLg,
              boxShadow: RtShadow.soft(),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(RtSpacing.base),
                      decoration: BoxDecoration(
                        color: RtColors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.directions_car,
                        color: RtColors.white,
                        size: RtIconSize.xl,
                      ),
                    ),
                    const SizedBox(width: RtSpacing.base),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_vehicleData['brand']} ${_vehicleData['model']}',
                            style: RtTypo.headingLarge.copyWith(color: RtColors.white),
                          ),
                          Text(
                            '${_vehicleData['year']} - ${_vehicleData['plate']}',
                            style: RtTypo.bodyMedium.copyWith(
                              color: RtColors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    RtBadge(
                      label: 'Activo',
                      color: RtColors.success,
                      variant: RtBadgeVariant.filled,
                    ),
                  ],
                ),
                const SizedBox(height: RtSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildVehicleStat('Kilometraje', '${_vehicleData['mileage']} km', Icons.speed),
                    _buildVehicleStat('Asientos', '${_vehicleData['seats']}', Icons.event_seat),
                    _buildVehicleStat('Combustible', _vehicleData['fuelType'], Icons.local_gas_station),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: RtSpacing.lg),

          // Seccion de fotos
          Text('Fotos del Vehículo', style: RtTypo.headingSmall),
          const SizedBox(height: RtSpacing.md),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _vehicleData['photos'].length + (_isEditing ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isEditing && index == _vehicleData['photos'].length) {
                  return _buildAddPhotoCard();
                }
                return _buildPhotoCard(index);
              },
            ),
          ),

          const SizedBox(height: RtSpacing.xl),

          // Información detallada
          Text('Información Detallada', style: RtTypo.headingSmall),
          const SizedBox(height: RtSpacing.md),
          _buildDetailCard(),

          const SizedBox(height: RtSpacing.xl),

          // Especificaciones técnicas
          Text('Especificaciones Técnicas', style: RtTypo.headingSmall),
          const SizedBox(height: RtSpacing.md),
          _buildSpecsCard(),
        ],
      ),
    );
  }

  Widget _buildVehicleStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: RtColors.white.withValues(alpha: 0.7), size: RtIconSize.md),
        const SizedBox(height: RtSpacing.sm),
        Text(
          value,
          style: RtTypo.titleLarge.copyWith(
            color: RtColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: RtTypo.bodySmall.copyWith(
            color: RtColors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoCard(int index) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: RtSpacing.md),
      decoration: BoxDecoration(
        borderRadius: RtRadius.borderMd,
        image: const DecorationImage(
          image: AssetImage('assets/images/car_placeholder.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: _isEditing
          ? Align(
              alignment: Alignment.topRight,
              child: Container(
                margin: const EdgeInsets.all(RtSpacing.sm),
                decoration: const BoxDecoration(
                  color: RtColors.error,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: RtColors.white, size: 16),
                  onPressed: () {
                    // Eliminar foto
                  },
                  padding: const EdgeInsets.all(RtSpacing.xs),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildAddPhotoCard() {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: RtSpacing.md),
      decoration: BoxDecoration(
        borderRadius: RtRadius.borderMd,
        border: Border.all(color: RtColors.brand, width: 2),
      ),
      child: InkWell(
        onTap: _addPhoto,
        borderRadius: RtRadius.borderMd,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo, color: RtColors.brand, size: RtIconSize.xl),
            const SizedBox(height: RtSpacing.sm),
            Text(
              'Agregar Foto',
              style: RtTypo.bodySmall.copyWith(color: RtColors.brand),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard() {
    return RtCard(
      child: Column(
        children: [
          _buildDetailRow('Marca', _vehicleData['brand'], Icons.branding_watermark),
          _buildDetailRow('Modelo', _vehicleData['model'], Icons.model_training),
          _buildDetailRow('Ano', _vehicleData['year'].toString(), Icons.calendar_today),
          _buildDetailRow('Placa', _vehicleData['plate'], Icons.badge),
          _buildDetailRow('Color', _vehicleData['color'], Icons.palette),
          _buildDetailRow('VIN', _vehicleData['vin'], Icons.fingerprint),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    final secondaryText = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RtSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: secondaryText, size: RtIconSize.sm),
          const SizedBox(width: RtSpacing.md),
          Expanded(
            child: Text(label, style: RtTypo.bodyMedium.copyWith(color: secondaryText)),
          ),
          _isEditing
              ? Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: value,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: RtSpacing.sm, vertical: RtSpacing.xs),
                      border: OutlineInputBorder(borderRadius: RtRadius.borderSm),
                    ),
                  ),
                )
              : Text(value, style: RtTypo.titleMedium),
        ],
      ),
    );
  }

  Widget _buildSpecsCard() {
    return RtCard(
      child: Column(
        children: [
          _buildSpecRow('Transmision', _vehicleData['transmission'], Icons.settings),
          _buildSpecRow('Tipo de Combustible', _vehicleData['fuelType'], Icons.local_gas_station),
          _buildSpecRow('Número de Asientos', '${_vehicleData['seats']} pasajeros', Icons.event_seat),
          _buildSpecRow('Kilometraje Actual', '${_vehicleData['mileage']} km', Icons.speed),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value, IconData icon) {
    final secondaryText = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RtSpacing.sm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(RtSpacing.sm),
            decoration: BoxDecoration(
              color: RtColors.brand.withValues(alpha: 0.1),
              borderRadius: RtRadius.borderSm,
            ),
            child: Icon(icon, color: RtColors.brand, size: RtIconSize.sm),
          ),
          const SizedBox(width: RtSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: RtTypo.bodySmall.copyWith(color: secondaryText)),
                Text(value, style: RtTypo.titleMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocuments() {
    if (_documents.isEmpty) {
      return const RtEmptyState(
        icon: Icons.folder_open,
        title: 'Sin documentos',
        description: 'Agrega los documentos de tu vehículo',
      );
    }

    return ListView.builder(
      padding: RtSpacing.paddingBase,
      itemCount: _documents.length,
      itemBuilder: (context, index) {
        final doc = _documents[index];
        return _buildDocumentCard(doc);
      },
    );
  }

  Widget _buildDocumentCard(VehicleDocument doc) {
    final daysUntilExpiry = doc.expiryDate?.difference(DateTime.now()).inDays;
    final isExpiringSoon = daysUntilExpiry != null && daysUntilExpiry < 30;
    final isExpired = daysUntilExpiry != null && daysUntilExpiry < 0;
    final secondaryText = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return RtCard(
      margin: const EdgeInsets.only(bottom: RtSpacing.md),
      onTap: () => _showDocumentDetails(doc),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(RtSpacing.md),
            decoration: BoxDecoration(
              color: doc.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(doc.icon, color: doc.color),
          ),
          const SizedBox(width: RtSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.type, style: RtTypo.titleLarge),
                Text('Número: ${doc.number}', style: RtTypo.bodySmall.copyWith(color: secondaryText)),
                if (doc.expiryDate != null)
                  Text(
                    'Vence: ${_formatDate(doc.expiryDate!)}',
                    style: RtTypo.bodySmall.copyWith(
                      color: isExpired
                          ? RtColors.error
                          : isExpiringSoon
                              ? RtColors.warning
                              : secondaryText,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RtBadge(
                label: _getStatusText(doc.status),
                color: _getStatusColor(doc.status),
                variant: RtBadgeVariant.subtle,
              ),
              if (daysUntilExpiry != null && daysUntilExpiry > 0 && daysUntilExpiry < 30)
                Padding(
                  padding: const EdgeInsets.only(top: RtSpacing.xs),
                  child: Text(
                    '$daysUntilExpiry días',
                    style: RtTypo.labelSmall.copyWith(color: RtColors.warning),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenance() {
    if (_maintenanceRecords.isEmpty) {
      return const RtEmptyState(
        icon: Icons.build_circle,
        title: 'Sin registros',
        description: 'Registra el mantenimiento de tu vehículo',
      );
    }

    return ListView.builder(
      padding: RtSpacing.paddingBase,
      itemCount: _maintenanceRecords.length,
      itemBuilder: (context, index) {
        final record = _maintenanceRecords[index];
        return _buildMaintenanceCard(record);
      },
    );
  }

  Widget _buildMaintenanceCard(MaintenanceRecord record) {
    final secondaryText = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return Container(
      margin: const EdgeInsets.only(bottom: RtSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: RtRadius.borderLg,
        boxShadow: RtShadow.soft(),
      ),
      child: ExpansionTile(
        tilePadding: RtSpacing.paddingBase,
        childrenPadding: const EdgeInsets.fromLTRB(RtSpacing.base, 0, RtSpacing.base, RtSpacing.base),
        leading: Container(
          padding: const EdgeInsets.all(RtSpacing.md),
          decoration: BoxDecoration(
            color: RtColors.info.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(record.icon, color: RtColors.info),
        ),
        title: Text(record.type, style: RtTypo.titleLarge),
        subtitle: Text(
          '${_formatDate(record.date)} - ${record.mileage} km',
          style: RtTypo.bodySmall.copyWith(color: secondaryText),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'S/. ${record.cost.toStringAsFixed(2)}',
              style: RtTypo.titleMedium.copyWith(color: RtColors.brand, fontWeight: FontWeight.bold),
            ),
            if (record.nextDue != null)
              Text(
                'Proximo: ${_formatDate(record.nextDue!)}',
                style: RtTypo.labelSmall.copyWith(color: secondaryText),
              ),
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(RtSpacing.md),
            decoration: BoxDecoration(
              color: RtColors.neutral100,
              borderRadius: RtRadius.borderMd,
            ),
            child: Column(
              children: [
                _buildMaintenanceDetail('Taller', record.workshop, Icons.store),
                _buildMaintenanceDetail('Kilometraje', '${record.mileage} km', Icons.speed),
                _buildMaintenanceDetail('Costo', 'S/. ${record.cost.toStringAsFixed(2)}', Icons.account_balance_wallet),
                if (record.notes != null)
                  _buildMaintenanceDetail('Notas', record.notes!, Icons.note),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceDetail(String label, String value, IconData icon) {
    final secondaryText = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RtSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: RtIconSize.xs, color: secondaryText),
          const SizedBox(width: RtSpacing.sm),
          Text('$label:', style: RtTypo.bodySmall.copyWith(color: secondaryText)),
          const SizedBox(width: RtSpacing.sm),
          Expanded(
            child: Text(value, style: RtTypo.bodySmall.copyWith(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildReminders() {
    if (_reminders.isEmpty) {
      return const RtEmptyState(
        icon: Icons.notifications_none,
        title: 'Sin recordatorios',
        description: 'Crea recordatorios para tu vehículo',
      );
    }

    return ListView.builder(
      padding: RtSpacing.paddingBase,
      itemCount: _reminders.length,
      itemBuilder: (context, index) {
        final reminder = _reminders[index];
        return _buildReminderCard(reminder);
      },
    );
  }

  Widget _buildReminderCard(Reminder reminder) {
    final secondaryText = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return Container(
      margin: const EdgeInsets.only(bottom: RtSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: RtRadius.borderLg,
        border: Border(
          left: BorderSide(
            color: _getPriorityColor(reminder.priority),
            width: 4,
          ),
        ),
        boxShadow: RtShadow.soft(),
      ),
      child: ListTile(
        contentPadding: RtSpacing.paddingBase,
        leading: Container(
          padding: const EdgeInsets.all(RtSpacing.md),
          decoration: BoxDecoration(
            color: _getReminderColor(reminder.type).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getReminderIcon(reminder.type),
            color: _getReminderColor(reminder.type),
          ),
        ),
        title: Text(reminder.title, style: RtTypo.titleLarge),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reminder.description, style: RtTypo.bodySmall),
            const SizedBox(height: RtSpacing.xs),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: secondaryText),
                const SizedBox(width: RtSpacing.xs),
                Text(
                  _formatDate(reminder.date),
                  style: RtTypo.bodySmall.copyWith(color: secondaryText),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Editar')),
            const PopupMenuItem(value: 'complete', child: Text('Marcar como completado')),
            const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
          ],
          onSelected: (value) {
            // Manejar accion
          },
        ),
      ),
    );
  }

  Color _getStatusColor(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.valid:
        return RtColors.success;
      case DocumentStatus.expiringSoon:
        return RtColors.warning;
      case DocumentStatus.expired:
        return RtColors.error;
      case DocumentStatus.pending:
        return RtColors.info;
    }
  }

  String _getStatusText(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.valid:
        return 'Vigente';
      case DocumentStatus.expiringSoon:
        return 'Por vencer';
      case DocumentStatus.expired:
        return 'Vencido';
      case DocumentStatus.pending:
        return 'Pendiente';
    }
  }

  Color _getPriorityColor(Priority priority) {
    switch (priority) {
      case Priority.high:
        return RtColors.error;
      case Priority.medium:
        return RtColors.warning;
      case Priority.low:
        return RtColors.info;
    }
  }

  Color _getReminderColor(ReminderType type) {
    switch (type) {
      case ReminderType.document:
        return RtColors.info;
      case ReminderType.maintenance:
        return RtColors.info;
      case ReminderType.payment:
        return RtColors.brand;
      case ReminderType.other:
        return RtColors.neutral400;
    }
  }

  IconData _getReminderIcon(ReminderType type) {
    switch (type) {
      case ReminderType.document:
        return Icons.description;
      case ReminderType.maintenance:
        return Icons.build;
      case ReminderType.payment:
        return Icons.payment;
      case ReminderType.other:
        return Icons.info;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _addPhoto() {
    RtSnackbar.show(
      context,
      message: 'Seleccionar foto desde galería',
      type: RtSnackbarType.info,
    );
  }

  void _saveChanges() {
    RtSnackbar.show(
      context,
      message: 'Cambios guardados exitosamente',
      type: RtSnackbarType.success,
    );
  }

  void _showDocumentDetails(VehicleDocument doc) {
    final secondaryText = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(RtSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: RtRadius.sheetTop,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(doc.icon, color: doc.color, size: RtIconSize.xl),
                const SizedBox(width: RtSpacing.md),
                Text(doc.type, style: RtTypo.headingMedium),
              ],
            ),
            const SizedBox(height: RtSpacing.lg),
            _buildDocumentDetailRow('Número', doc.number, secondaryText),
            _buildDocumentDetailRow('Fecha de emision', _formatDate(doc.issueDate), secondaryText),
            if (doc.expiryDate != null)
              _buildDocumentDetailRow('Fecha de vencimiento', _formatDate(doc.expiryDate!), secondaryText),
            _buildDocumentDetailRow('Estado', _getStatusText(doc.status), secondaryText),
            const SizedBox(height: RtSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: RtButton(
                    label: 'Ver Documento',
                    icon: Icons.visibility,
                    variant: RtButtonVariant.secondary,
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(width: RtSpacing.md),
                Expanded(
                  child: RtButton(
                    label: 'Actualizar',
                    icon: Icons.upload,
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentDetailRow(String label, String value, Color secondaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RtSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: RtTypo.bodyMedium.copyWith(color: secondaryColor)),
          Text(value, style: RtTypo.titleMedium),
        ],
      ),
    );
  }

  void _showAddDialog() {
    String title = '';
    switch (_selectedTab) {
      case 1:
        title = 'Agregar Documento';
        break;
      case 2:
        title = 'Registrar Mantenimiento';
        break;
      case 3:
        title = 'Crear Recordatorio';
        break;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: const Text('Formulario para agregar nuevo elemento'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              RtSnackbar.show(
                context,
                message: 'Elemento agregado exitosamente',
                type: RtSnackbarType.success,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: RtColors.brand),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }
}

// Modelos
class VehicleDocument {
  final String id;
  final String type;
  final String number;
  final DateTime issueDate;
  final DateTime? expiryDate;
  final DocumentStatus status;
  final IconData icon;
  final Color color;

  VehicleDocument({
    required this.id,
    required this.type,
    required this.number,
    required this.issueDate,
    this.expiryDate,
    required this.status,
    required this.icon,
    required this.color,
  });
}

enum DocumentStatus { valid, expiringSoon, expired, pending }

class MaintenanceRecord {
  final String id;
  final String type;
  final DateTime date;
  final int mileage;
  final double cost;
  final String workshop;
  final DateTime? nextDue;
  final IconData icon;
  final String? notes;

  MaintenanceRecord({
    required this.id,
    required this.type,
    required this.date,
    required this.mileage,
    required this.cost,
    required this.workshop,
    this.nextDue,
    required this.icon,
    this.notes,
  });
}

class Reminder {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final ReminderType type;
  final Priority priority;

  Reminder({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.type,
    required this.priority,
  });
}

enum ReminderType { document, maintenance, payment, other }
enum Priority { high, medium, low }
