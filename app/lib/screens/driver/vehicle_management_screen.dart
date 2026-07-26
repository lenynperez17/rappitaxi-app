// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/utils/responsive_bottom_sheet.dart';
import '../../core/extensions/theme_extensions.dart'; // ✅ Extensión para colores que se adaptan al tema
import '../../services/rapi_api_client.dart';
import '../../utils/logger.dart';
import '../../utils/error_messages.dart';

class VehicleManagementScreen extends StatefulWidget {
  const VehicleManagementScreen({super.key});

  @override
  _VehicleManagementScreenState createState() => _VehicleManagementScreenState();
}

class _VehicleManagementScreenState extends State<VehicleManagementScreen> 
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // ✅ Vehicle data - Cargado desde Firebase
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

  // ✅ Documentos reales desde Firebase (inicialmente vacío)
  final List<VehicleDocument> _documents = [];

  // ✅ Registros de mantenimiento reales desde Firebase (inicialmente vacío)
  final List<MaintenanceRecord> _maintenanceRecords = [];

  // ✅ Recordatorios reales desde Firebase (inicialmente vacío)
  final List<Reminder> _reminders = [];

  int _selectedTab = 0;
  bool _isEditing = false;
  // UI: PageController para el carousel de fotos
  final PageController _photoPageController = PageController();
  int _currentPhotoPage = 0;

  // ✅ Loading state
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _fadeController.forward();

    // ✅ Cargar datos del vehículo desde el backend Node
    _loadVehicleDataFromApi();
  }

  // ✅ NUEVO: Cargar datos reales del vehículo desde el backend Node.
  // Toda la información viene del perfil del conductor (auth-scoped via JWT).
  Future<void> _loadVehicleDataFromApi() async {
    setState(() => _isLoading = true);

    try {
      final api = RapiApiClient.instance;

      // ✅ Cargar perfil del conductor (incluye info del vehículo)
      final profileResponse = await api.myDriverProfile();
      final vehicleInfo = (profileResponse['vehicle'] ??
              profileResponse['vehicleInfo'] ??
              profileResponse['driver']?['vehicle'] ??
              <String, dynamic>{}) as Map<String, dynamic>;

      if (vehicleInfo.isNotEmpty) {
        setState(() {
          _vehicleData = {
            'brand': vehicleInfo['brand'] ?? vehicleInfo['make'] ?? '',
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
            // Ronda 251: hay que conservarlo para poder reenviarlo al guardar;
            // sin esto _saveChanges mandaba siempre 'car' y podía cambiar el
            // tipo real del vehículo del conductor.
            'vehicleType': vehicleInfo['vehicleType'] ??
                vehicleInfo['vehicle_type'] ??
                'car',
            'photos': (vehicleInfo['photos'] as List?)?.map((e) => e.toString()).toList() ?? [],
          };
        });
      }

      // ✅ Cargar documentos del vehículo desde el backend
      final documentsResponse = await api.myDocuments();
      final documentsList =
          (documentsResponse['documents'] ?? documentsResponse['items'] ?? []) as List;

      final List<VehicleDocument> loadedDocs = [];
      for (final docRaw in documentsList) {
        final data = docRaw as Map<String, dynamic>;
        // Solo documentos relacionados al vehículo
        final category = (data['category'] ?? '').toString();
        if (category != 'vehicle' && category != '') continue;

        // Ronda 251: el backend envía `expiresAt`, no `expiryDate`.
        final expiryStr = (data['expiresAt'] ??
            data['expiryDate'] ??
            data['expiry_date']) as String?;
        final expiryDate = expiryStr != null ? DateTime.tryParse(expiryStr) : null;
        final issueStr = (data['uploadedAt'] ?? data['uploaded_at']) as String?;
        final issueDate = issueStr != null
            ? DateTime.tryParse(issueStr) ?? DateTime.now()
            : DateTime.now();

        // Calcular estado del documento
        DocumentStatus status = DocumentStatus.pending;
        if (data['status'] == 'approved' || data['status'] == 'verified') {
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

        final docType = (data['type'] ?? data['docType'] ?? '').toString();
        loadedDocs.add(VehicleDocument(
          id: (data['id'] ?? '').toString(),
          type: docType.isNotEmpty ? docType : 'Documento',
          number: (data['documentNumber'] ?? data['number'] ?? 'N/A').toString(),
          issueDate: issueDate,
          expiryDate: expiryDate,
          status: status,
          icon: _getDocumentIcon(docType),
          color: _getDocumentColor(docType),
        ));
      }

      if (!mounted) return;
      setState(() {
        _documents.clear();
        _documents.addAll(loadedDocs);
        _isLoading = false;
      });

      AppLogger.info(
          '✅ Cargados datos del vehículo y ${loadedDocs.length} documentos desde el backend Node');
    } catch (e) {
      AppLogger.error('❌ Error cargando datos del vehículo: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFriendlyError(e, fallback: 'Error cargando datos del vehículo')),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  // ✅ HELPER: Obtener icono según tipo de documento
  IconData _getDocumentIcon(String? type) {
    switch (type) {
      case 'vehicle_registration':
      case 'tarjeta_propiedad':
        return Icons.article;
      case 'insurance':
      case 'soat':
        return Icons.security;
      case 'technical_review':
      case 'revision_tecnica':
        return Icons.build;
      default:
        return Icons.description;
    }
  }

  // ✅ HELPER: Obtener color según tipo de documento
  Color _getDocumentColor(String? type) {
    switch (type) {
      case 'vehicle_registration':
      case 'tarjeta_propiedad':
        return ModernTheme.primaryBlue;
      case 'insurance':
      case 'soat':
        return ModernTheme.success;
      case 'technical_review':
      case 'revision_tecnica':
        return ModernTheme.warning;
      default:
        return Theme.of(context).dividerColor;
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceColor,
      appBar: AppBar(
        backgroundColor: ModernTheme.rappiOrange,
        elevation: 0,
        title: Text(
          'Mi Vehículo',
          style: TextStyle(
            color: context.onPrimaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit, color: context.onPrimaryText),
            onPressed: () {
              setState(() => _isEditing = !_isEditing);
              if (!_isEditing) {
                _saveChanges();
              }
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Column(
              children: [
                // Tab bar
                _buildTabBar(),
                
                // Content
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
      floatingActionButton: _selectedTab > 0 ? FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: ModernTheme.rappiOrange,
        child: Icon(Icons.add, color: context.onPrimaryText),
      ) : null,
    );
  }
  
  Widget _buildTabBar() {
    return Container(
      color: context.surfaceColor,
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
    
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? ModernTheme.rappiOrange : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? ModernTheme.rappiOrange : context.secondaryText,
                size: 20,
              ),
              SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? ModernTheme.rappiOrange : context.secondaryText,
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
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vehicle header card
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [ModernTheme.rappiOrange, ModernTheme.rappiOrange.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: ModernTheme.getCardShadow(context),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.onPrimaryText.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.directions_car,
                        color: context.onPrimaryText,
                        size: 32,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_vehicleData['brand']} ${_vehicleData['model']}',
                            style: TextStyle(
                              color: context.onPrimaryText,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${_vehicleData['year']} • ${_vehicleData['plate']}',
                            style: TextStyle(
                              color: context.onPrimaryText.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.onPrimaryText.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: ModernTheme.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Activo',
                            style: TextStyle(
                              color: context.onPrimaryText,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
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
          
          SizedBox(height: 20),

          // UI: Fotos del vehículo como carousel horizontal (PageView)
          Text(
            'Fotos del Vehículo',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 180,
              child: Stack(
                children: [
                  // PageView carousel
                  PageView.builder(
                    controller: _photoPageController,
                    onPageChanged: (index) => setState(() => _currentPhotoPage = index),
                    itemCount: (_vehicleData['photos'] as List).length + (_isEditing ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isEditing && index == (_vehicleData['photos'] as List).length) {
                        return Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: _buildAddPhotoCard(),
                        );
                      }
                      return SizedBox(
                        width: double.infinity,
                        child: _buildPhotoCard(index),
                      );
                    },
                  ),
                  // Indicador de páginas
                  if ((_vehicleData['photos'] as List).length > 1)
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          (_vehicleData['photos'] as List).length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: _currentPhotoPage == index ? 16 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _currentPhotoPage == index
                                  ? ModernTheme.rappiOrange
                                  : Colors.white.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 24),
          
          // Vehicle details
          Text(
            'Información Detallada',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          _buildDetailCard(),
          
          SizedBox(height: 24),
          
          // Technical specs
          Text(
            'Especificaciones Técnicas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          _buildSpecsCard(),
        ],
      ),
    );
  }
  
  Widget _buildVehicleStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: context.onPrimaryText.withValues(alpha: 0.7), size: 24),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: context.onPrimaryText,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: context.onPrimaryText.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  Widget _buildPhotoCard(int index) {
    return Container(
      width: 160,
      margin: EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(
          image: AssetImage('assets/images/car_placeholder.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: _isEditing ? Align(
        alignment: Alignment.topRight,
        child: Container(
          margin: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ModernTheme.error,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(Icons.close, color: context.onPrimaryText, size: 16),
            onPressed: () {
              // Remove photo
            },
            padding: EdgeInsets.all(4),
          ),
        ),
      ) : null,
    );
  }
  
  Widget _buildAddPhotoCard() {
    return Container(
      width: 160,
      margin: EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ModernTheme.rappiOrange,
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: InkWell(
        onTap: _addPhoto,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo, color: ModernTheme.rappiOrange, size: 32),
            SizedBox(height: 8),
            Text(
              'Agregar Foto',
              style: TextStyle(
                color: ModernTheme.rappiOrange,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.getCardShadow(context),
      ),
      child: Column(
        children: [
          // Ronda 251: cada fila recibe la CLAVE del mapa para poder escribir
          // lo que el conductor teclea. Antes el TextFormField no tenía ni
          // controller ni onChanged: el texto moría en el widget.
          _buildDetailRow('Marca', 'brand', _vehicleData['brand'], Icons.branding_watermark),
          _buildDetailRow('Modelo', 'model', _vehicleData['model'], Icons.model_training),
          _buildDetailRow('Año', 'year', _vehicleData['year'].toString(), Icons.calendar_today),
          _buildDetailRow('Placa', 'plate', _vehicleData['plate'], Icons.badge),
          _buildDetailRow('Color', 'color', _vehicleData['color'], Icons.palette),
          _buildDetailRow('VIN', 'vin', _vehicleData['vin'], Icons.fingerprint),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String fieldKey, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: context.secondaryText, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: context.secondaryText,
              ),
            ),
          ),
          _isEditing ? Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: value,
              keyboardType:
                  fieldKey == 'year' ? TextInputType.number : TextInputType.text,
              textCapitalization: fieldKey == 'plate'
                  ? TextCapitalization.characters
                  : TextCapitalization.words,
              onChanged: (v) {
                // Sin esto el texto tecleado nunca llegaba a _vehicleData.
                _vehicleData[fieldKey] =
                    fieldKey == 'year' ? (int.tryParse(v.trim()) ?? 0) : v.trim();
              },
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ) : Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSpecsCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.getCardShadow(context),
      ),
      child: Column(
        children: [
          _buildSpecRow('Transmisión', _vehicleData['transmission'], Icons.settings),
          _buildSpecRow('Tipo de Combustible', _vehicleData['fuelType'], Icons.local_gas_station),
          _buildSpecRow('Número de Asientos', '${_vehicleData['seats']} pasajeros', Icons.event_seat),
          _buildSpecRow('Kilometraje Actual', '${_vehicleData['mileage']} km', Icons.speed),
        ],
      ),
    );
  }
  
  Widget _buildSpecRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: ModernTheme.rappiOrange, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: context.secondaryText,
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDocuments() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
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

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.getCardShadow(context),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: doc.color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(doc.icon, color: doc.color),
        ),
        title: Text(
          doc.type,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Número: ${doc.number}'),
            if (doc.expiryDate != null)
              Text(
                'Vence: ${_formatDate(doc.expiryDate!)}',
                style: TextStyle(
                  color: isExpired ? ModernTheme.error : 
                         isExpiringSoon ? ModernTheme.warning : 
                         context.secondaryText,
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(doc.status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _getStatusText(doc.status),
                style: TextStyle(
                  color: _getStatusColor(doc.status),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (daysUntilExpiry != null && daysUntilExpiry > 0 && daysUntilExpiry < 30)
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  '$daysUntilExpiry días',
                  style: TextStyle(
                    fontSize: 11,
                    color: ModernTheme.warning,
                  ),
                ),
              ),
          ],
        ),
        onTap: () => _showDocumentDetails(doc),
      ),
    );
  }
  
  Widget _buildMaintenance() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _maintenanceRecords.length,
      itemBuilder: (context, index) {
        final record = _maintenanceRecords[index];
        return _buildMaintenanceCard(record);
      },
    );
  }
  
  Widget _buildMaintenanceCard(MaintenanceRecord record) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.getCardShadow(context),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.all(16),
        childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ModernTheme.primaryBlue.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(record.icon, color: ModernTheme.primaryBlue),
        ),
        title: Text(
          record.type,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          '${_formatDate(record.date)} • ${record.mileage} km',
          style: TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'S/ ${record.cost.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: ModernTheme.rappiOrange,
              ),
            ),
            if (record.nextDue != null)
              Text(
                'Próximo: ${_formatDate(record.nextDue!)}',
                style: TextStyle(
                  fontSize: 11,
                  color: context.secondaryText,
                ),
              ),
          ],
        ),
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildMaintenanceDetail('Taller', record.workshop, Icons.store),
                _buildMaintenanceDetail('Kilometraje', '${record.mileage} km', Icons.speed),
                _buildMaintenanceDetail('Costo', 'S/ ${record.cost.toStringAsFixed(2)}', Icons.account_balance_wallet), // ✅ Cambiado de attach_money ($) a wallet
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
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.secondaryText),
          SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(
              color: context.secondaryText,
              fontSize: 12,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildReminders() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _reminders.length,
      itemBuilder: (context, index) {
        final reminder = _reminders[index];
        return _buildReminderCard(reminder);
      },
    );
  }
  
  Widget _buildReminderCard(Reminder reminder) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: _getPriorityColor(reminder.priority),
            width: 4,
          ),
        ),
        boxShadow: ModernTheme.getCardShadow(context),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _getReminderColor(reminder.type).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getReminderIcon(reminder.type),
            color: _getReminderColor(reminder.type),
          ),
        ),
        title: Text(
          reminder.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reminder.description),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: context.secondaryText),
                SizedBox(width: 4),
                Text(
                  _formatDate(reminder.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.secondaryText,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Text('Editar'),
            ),
            PopupMenuItem(
              value: 'complete',
              child: Text('Marcar como completado'),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text('Eliminar'),
            ),
          ],
          onSelected: (value) {
            // Handle action
          },
        ),
      ),
    );
  }
  
  Color _getStatusColor(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.valid:
        return ModernTheme.success;
      case DocumentStatus.expiringSoon:
        return ModernTheme.warning;
      case DocumentStatus.expired:
        return ModernTheme.error;
      case DocumentStatus.pending:
        return ModernTheme.info;
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
        return ModernTheme.error;
      case Priority.medium:
        return ModernTheme.warning;
      case Priority.low:
        return ModernTheme.info;
    }
  }
  
  Color _getReminderColor(ReminderType type) {
    switch (type) {
      case ReminderType.document:
        return ModernTheme.info;
      case ReminderType.maintenance:
        return ModernTheme.primaryBlue;
      case ReminderType.payment:
        return ModernTheme.rappiOrange;
      case ReminderType.other:
        return Theme.of(context).dividerColor;
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
    // Show photo picker
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Seleccionar foto desde galería'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  /// Ronda 251: este método SOLO mostraba "Cambios guardados exitosamente" —
  /// no llamaba a ningún endpoint. El conductor corregía su placa o su modelo,
  /// leía la confirmación, y al volver a entrar seguía el dato viejo. Ahora
  /// persiste en PUT /api/drivers/me/vehicle y recarga desde el servidor para
  /// que lo que se muestra sea lo que quedó guardado.
  Future<void> _saveChanges() async {
    final plate = (_vehicleData['plate'] ?? '').toString().trim();
    if (plate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('La placa es obligatoria'),
          backgroundColor: ModernTheme.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final year = _vehicleData['year'] is int
          ? _vehicleData['year'] as int
          : int.tryParse(_vehicleData['year'].toString());

      await RapiApiClient.instance.upsertVehicle(
        // El backend valida vehicleType contra un enum; conservamos el que ya
        // tiene el vehículo para no enviar un valor inventado.
        vehicleType: (_vehicleData['vehicleType'] ?? 'car').toString(),
        plate: plate.toUpperCase(),
        make: (_vehicleData['brand'] ?? '').toString().trim().isEmpty
            ? null
            : _vehicleData['brand'].toString().trim(),
        model: (_vehicleData['model'] ?? '').toString().trim().isEmpty
            ? null
            : _vehicleData['model'].toString().trim(),
        color: (_vehicleData['color'] ?? '').toString().trim().isEmpty
            ? null
            : _vehicleData['color'].toString().trim(),
        year: (year != null && year > 1900) ? year : null,
      );

      if (!mounted) return;
      setState(() => _isEditing = false);
      // Recargar del servidor: si el backend normalizó algo (placa en
      // mayúsculas, año fuera de rango), el conductor ve el valor real.
      await _loadVehicleDataFromApi();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Datos del vehículo actualizados'),
          backgroundColor: ModernTheme.success,
        ),
      );
    } catch (e) {
      AppLogger.error('❌ Error guardando vehículo: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFriendlyError(e,
              fallback: 'No se pudieron guardar los datos del vehículo')),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }
  
  void _showDocumentDetails(VehicleDocument doc) {
    showResponsiveBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(doc.icon, color: doc.color, size: 32),
                SizedBox(width: 12),
                Text(
                  doc.type,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            _buildDocumentDetailRow('Número', doc.number),
            _buildDocumentDetailRow('Fecha de emisión', _formatDate(doc.issueDate)),
            if (doc.expiryDate != null)
              _buildDocumentDetailRow('Fecha de vencimiento', _formatDate(doc.expiryDate!)),
            _buildDocumentDetailRow('Estado', _getStatusText(doc.status)),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // Show document
                    },
                    icon: Icon(Icons.visibility),
                    label: Text('Ver Documento'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ModernTheme.primaryBlue,
                      foregroundColor: context.onPrimaryText,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // Update document
                    },
                    icon: Icon(Icons.upload),
                    label: Text('Actualizar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ModernTheme.rappiOrange,
                      foregroundColor: context.onPrimaryText,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDocumentDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.secondaryText,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
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
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text('Formulario para agregar nuevo elemento'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Elemento agregado exitosamente'),
                  backgroundColor: ModernTheme.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.rappiOrange,
            ),
            child: Text('Agregar'),
          ),
        ],
      ),
    );
  }
}

// Models
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