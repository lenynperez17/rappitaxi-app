// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart'; // ✅ Para seleccionar archivos PDF/documentos
import 'package:url_launcher/url_launcher.dart'; // ✅ AGREGADO: Para abrir/descargar documentos
import 'package:share_plus/share_plus.dart'; // ✅ AGREGADO: Para compartir/guardar archivos
import 'package:path_provider/path_provider.dart'; // ✅ AGREGADO: Para obtener directorio temporal
import 'dart:io';
import '../../core/theme/modern_theme.dart';
import '../../core/utils/responsive_bottom_sheet.dart';
import '../../core/extensions/theme_extensions.dart'; // ✅ Extensión para colores que se adaptan al tema
import '../../services/rapi_api_client.dart';

import '../../utils/logger.dart';
import '../../utils/error_messages.dart';
import '../../utils/document_storage_scope.dart';
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  _DocumentsScreenState createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  
  // Documents data
  List<DocumentInfo> _documents = [];
  bool _isLoading = true;
  String _overallStatus = 'pending';

  // API cliente y pickers
  final RapiApiClient _api = RapiApiClient.instance;
  final ImagePicker _picker = ImagePicker();
  
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
    
    _loadDocuments();
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }
  
  Future<void> _loadDocuments() async {
    try {
      setState(() => _isLoading = true);

      // Ronda 232 fix: los IDs deben coincidir con los docTypes reales del
      // backend Node (driver_documents.doc_type CHECK constraint), no con
      // los IDs legacy Firebase (license/id_card/insurance) que jamás
      // matcheaban → 0/7 aprobados aunque hubiera 9 approved en DB.
      // Enum backend: dni_front, dni_back, license_front, license_back,
      // soat, tarjeta_propiedad, ownership, selfie, vehicle_photo, other.
      final requiredDocTypes = {
        'dni_front':          {'name': 'DNI (frente)',                 'description': 'Documento Nacional de Identidad — cara frontal',   'category': DocumentCategory.identity, 'required': true},
        'dni_back':           {'name': 'DNI (reverso)',                'description': 'Documento Nacional de Identidad — cara posterior', 'category': DocumentCategory.identity, 'required': true},
        'license_front':      {'name': 'Licencia (frente)',            'description': 'Licencia de conducir vigente — cara frontal',      'category': DocumentCategory.license,  'required': true},
        'license_back':       {'name': 'Licencia (reverso)',           'description': 'Licencia de conducir vigente — cara posterior',    'category': DocumentCategory.license,  'required': true},
        'soat':               {'name': 'SOAT vigente',                 'description': 'Seguro Obligatorio de Accidentes de Tránsito',     'category': DocumentCategory.insurance,'required': true},
        'tarjeta_propiedad':  {'name': 'Tarjeta de propiedad (frente)','description': 'Registro vehicular — cara frontal',                'category': DocumentCategory.vehicle,  'required': false},
        'ownership':          {'name': 'Tarjeta de propiedad (reverso)','description': 'Registro vehicular — cara posterior',             'category': DocumentCategory.vehicle,  'required': false},
        'selfie':              {'name': 'Selfie del conductor',         'description': 'Foto de rostro para verificación',                 'category': DocumentCategory.identity, 'required': false},
        'vehicle_photo':      {'name': 'Foto del vehículo',            'description': 'Foto del vehículo que usarás',                     'category': DocumentCategory.vehicle,  'required': false},
      };

      // Cargar documentos subidos desde el backend Node
      final resp = await _api.myDocuments();
      final rawList = resp['documents'];

      // Mapear documentos subidos por su docType/id
      final uploadedDocs = <String, Map<String, dynamic>>{};
      if (rawList is List) {
        for (final entry in rawList) {
          if (entry is! Map) continue;
          final map = Map<String, dynamic>.from(entry);
          final type = (map['docType'] ?? map['type'] ?? map['id'])?.toString();
          if (type == null || type.isEmpty) continue;
          uploadedDocs[type] = map;
        }
      }

      // Crear lista de documentos con estado actual
      List<DocumentInfo> loadedDocs = [];
      for (var entry in requiredDocTypes.entries) {
        final docId = entry.key;
        final docInfo = entry.value;

        if (uploadedDocs.containsKey(docId)) {
          final data = uploadedDocs[docId]!;

          DateTime? expiryDate;
          final expiryRaw = data['expiryDate']?.toString();
          if (expiryRaw != null && expiryRaw.isNotEmpty) {
            expiryDate = DateTime.tryParse(expiryRaw);
          }

          DateTime? uploadDate;
          final uploadRaw = (data['uploadedAt'] ?? data['uploadDate'])?.toString();
          if (uploadRaw != null && uploadRaw.isNotEmpty) {
            uploadDate = DateTime.tryParse(uploadRaw);
          }

          // Calcular estado basado en fechas y aprobación
          DocumentStatus status = DocumentStatus.pending;
          final statusStr = data['status']?.toString();
          switch (statusStr) {
            case 'approved':
            case 'verified':
              status = DocumentStatus.approved;
              if (expiryDate != null) {
                final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;
                if (daysUntilExpiry <= 30 && daysUntilExpiry > 0) {
                  status = DocumentStatus.expiring;
                } else if (daysUntilExpiry <= 0) {
                  status = DocumentStatus.rejected;
                }
              }
              break;
            case 'rejected':
              status = DocumentStatus.rejected;
              break;
            case 'pending':
            default:
              status = DocumentStatus.pending;
              break;
          }

          loadedDocs.add(DocumentInfo(
            id: docId,
            name: docInfo['name'] as String,
            description: docInfo['description'] as String,
            status: status,
            expiryDate: expiryDate,
            uploadDate: uploadDate,
            fileUrl: (data['fileUrl'] ?? data['url'])?.toString(),
            isRequired: docInfo['required'] as bool,
            category: docInfo['category'] as DocumentCategory,
            rejectionReason: data['rejectionReason']?.toString(),
          ));
        } else {
          // Documento no existe - marcarlo como faltante
          loadedDocs.add(DocumentInfo(
            id: docId,
            name: docInfo['name'] as String,
            description: docInfo['description'] as String,
            status: DocumentStatus.missing,
            expiryDate: null,
            uploadDate: null,
            fileUrl: null,
            isRequired: docInfo['required'] as bool,
            category: docInfo['category'] as DocumentCategory,
            rejectionReason: null,
          ));
        }
      }

      if (mounted) {
        setState(() {
          _documents = loadedDocs;
          _overallStatus = _calculateOverallStatus();
          _isLoading = false;
        });

        _fadeController.forward();
        _slideController.forward();
      }
    } catch (e) {
      AppLogger.error(userFriendlyError(e, fallback: 'Error al cargar documentos'));
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFriendlyError(e, fallback: 'Error al cargar documentos')),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }
  
  String _calculateOverallStatus() {
    final required = _documents.where((d) => d.isRequired);
    
    if (required.any((d) => d.status == DocumentStatus.rejected)) {
      return 'rejected';
    }
    
    if (required.any((d) => d.status == DocumentStatus.missing)) {
      return 'incomplete';
    }
    
    if (required.any((d) => d.status == DocumentStatus.pending)) {
      return 'pending';
    }
    
    if (required.any((d) => d.status == DocumentStatus.expiring)) {
      return 'expiring';
    }
    
    return 'approved';
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceColor,
      appBar: AppBar(
        backgroundColor: ModernTheme.rappiOrange,
        elevation: 0,
        title: Text(
          'Mis Documentos',
          style: TextStyle(
            color: context.surfaceColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: context.surfaceColor),
            onPressed: _showDocumentInfo,
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: context.surfaceColor),
            onPressed: _refreshDocuments,
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingState() : _buildDocumentsList(),
    );
  }
  
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(ModernTheme.rappiOrange),
          ),
          SizedBox(height: 16),
          Text(
            'Cargando documentos...',
            style: TextStyle(
              color: context.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDocumentsList() {
    // UI: Progress circular de completitud arriba del checklist
    final approvedCount = _documents.where((d) => d.status == DocumentStatus.approved).length;
    final totalCount = _documents.length;
    final completionProgress = totalCount > 0 ? approvedCount / totalCount : 0.0;

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // UI: Progress circular de completitud
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  color: Theme.of(context).colorScheme.surface,
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 72,
                            height: 72,
                            child: CircularProgressIndicator(
                              value: completionProgress,
                              strokeWidth: 7,
                              backgroundColor: ModernTheme.rappiOrange.withValues(alpha: 0.15),
                              valueColor: AlwaysStoppedAnimation<Color>(ModernTheme.rappiOrange),
                            ),
                          ),
                          Text(
                            '${(completionProgress * 100).round()}%',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: context.primaryText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Completitud de documentos',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: context.primaryText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$approvedCount de $totalCount documentos aprobados',
                              style: TextStyle(fontSize: 13, color: context.secondaryText),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: completionProgress,
                                backgroundColor: ModernTheme.rappiOrange.withValues(alpha: 0.15),
                                valueColor: AlwaysStoppedAnimation<Color>(ModernTheme.rappiOrange),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Status overview
                _buildStatusOverview(),

                // Documents list (checklist visual)
                _buildDocumentsSection(),

                // Actions
                _buildActionsSection(),

                SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildStatusOverview() {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - _slideAnimation.value)),
          child: Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: _getStatusGradient(),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _getStatusColor().withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.surfaceColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getStatusIcon(),
                        color: context.surfaceColor,
                        size: 28,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getStatusTitle(),
                            style: TextStyle(
                              color: context.surfaceColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _getStatusDescription(),
                            style: TextStyle(
                              color: context.surfaceColor.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      'Total',
                      '${_documents.length}',
                      Icons.description,
                    ),
                    _buildStatItem(
                      'Aprobados',
                      '${_documents.where((d) => d.status == DocumentStatus.approved).length}',
                      Icons.check_circle,
                    ),
                    _buildStatItem(
                      'Pendientes',
                      '${_documents.where((d) => d.status == DocumentStatus.pending).length}',
                      Icons.schedule,
                    ),
                    _buildStatItem(
                      'Por vencer',
                      '${_documents.where((d) => d.status == DocumentStatus.expiring).length}',
                      Icons.warning,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: context.surfaceColor.withValues(alpha: 0.7), size: 16),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: context.surfaceColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: context.surfaceColor.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  Widget _buildDocumentsSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Lista de Documentos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.primaryText,
              ),
            ),
          ),
          ..._documents.asMap().entries.map((entry) {
            final index = entry.key;
            final document = entry.value;

            // ✅ CORRECCIÓN: Limitar delay para que Interval no exceda 1.0
            // Dividir el rango de animación entre todos los documentos
            final totalDocs = _documents.length;
            final animationStart = (index / totalDocs).clamp(0.0, 0.7);
            final animationEnd = ((index + 1) / totalDocs).clamp(0.0, 1.0);

            final animation = Tween<double>(
              begin: 0,
              end: 1,
            ).animate(
              CurvedAnimation(
                parent: _slideController,
                curve: Interval(
                  animationStart,  // ✅ Garantizado entre 0.0 y 0.7
                  animationEnd,    // ✅ Garantizado entre 0.0 y 1.0
                  curve: Curves.easeOutBack,
                ),
              ),
            );

            return AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(50 * (1 - animation.value.clamp(0.0, 1.0)), 0),
                  child: Opacity(
                    opacity: animation.value.clamp(0.0, 1.0),  // ✅ Garantizar opacity válido
                    child: _buildDocumentCard(document),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }
  
  Widget _buildDocumentCard(DocumentInfo document) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.getCardShadow(context),
        border: Border.all(
          color: _getDocumentStatusColor(document.status).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _viewDocument(document),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getDocumentStatusColor(document.status).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getDocumentIcon(document.category),
                      color: _getDocumentStatusColor(document.status),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                document.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: context.primaryText,
                                ),
                              ),
                            ),
                            if (document.isRequired)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: ModernTheme.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Requerido',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: ModernTheme.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 2),
                        Text(
                          document.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getDocumentStatusColor(document.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getDocumentStatusText(document.status),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getDocumentStatusColor(document.status),
                      ),
                    ),
                  ),
                ],
              ),
              
              if (document.status != DocumentStatus.missing) ...[
                SizedBox(height: 12),
                Row(
                  children: [
                    if (document.uploadDate != null) ...[
                      Icon(Icons.upload, size: 14, color: context.secondaryText),
                      SizedBox(width: 4),
                      Text(
                        'Subido: ${_formatDate(document.uploadDate!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.secondaryText,
                        ),
                      ),
                    ],
                    if (document.expiryDate != null) ...[
                      SizedBox(width: 16),
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: document.status == DocumentStatus.expiring
                            ? ModernTheme.warning
                            : context.secondaryText,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Vence: ${_formatDate(document.expiryDate!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: document.status == DocumentStatus.expiring
                              ? ModernTheme.warning
                              : context.secondaryText,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              
              if (document.rejectionReason != null) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ModernTheme.error.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: ModernTheme.error.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline, color: ModernTheme.error, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          document.rejectionReason!,
                          style: TextStyle(
                            fontSize: 12,
                            color: ModernTheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (document.status == DocumentStatus.missing ||
                      document.status == DocumentStatus.rejected ||
                      document.status == DocumentStatus.expiring)
                    ElevatedButton.icon(
                      onPressed: () => _uploadDocument(document),
                      icon: Icon(Icons.cloud_upload, size: 16),
                      label: Text(
                        document.status == DocumentStatus.missing ? 'Subir' : 'Actualizar',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ModernTheme.rappiOrange,
                        foregroundColor: context.surfaceColor,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  if (document.fileUrl != null) ...[
                    SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _viewDocument(document),
                      icon: Icon(Icons.visibility, size: 16),
                      label: Text('Ver', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ModernTheme.primaryBlue,
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildActionsSection() {
    return Container(
      margin: EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _uploadAllDocuments,
              icon: Icon(Icons.upload_file),
              label: Text('Subir Documentos Faltantes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.rappiOrange,
                foregroundColor: context.surfaceColor,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _downloadTemplate,
              icon: Icon(Icons.download),
              label: Text('Descargar Lista de Documentos'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ModernTheme.primaryBlue,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getStatusColor() {
    switch (_overallStatus) {
      case 'approved':
        return ModernTheme.success;
      case 'pending':
        return ModernTheme.warning;
      case 'rejected':
      case 'incomplete':
        return ModernTheme.error;
      case 'expiring':
        return ModernTheme.warning;
      default:
        return context.secondaryText;
    }
  }
  
  LinearGradient _getStatusGradient() {
    final color = _getStatusColor();
    return LinearGradient(
      colors: [color, color.withValues(alpha: 0.8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
  
  IconData _getStatusIcon() {
    switch (_overallStatus) {
      case 'approved':
        return Icons.check_circle;
      case 'pending':
        return Icons.schedule;
      case 'rejected':
      case 'incomplete':
        return Icons.error;
      case 'expiring':
        return Icons.warning;
      default:
        return Icons.description;
    }
  }
  
  String _getStatusTitle() {
    switch (_overallStatus) {
      case 'approved':
        return 'Documentos Aprobados';
      case 'pending':
        return 'En Revisión';
      case 'rejected':
        return 'Documentos Rechazados';
      case 'incomplete':
        return 'Documentos Incompletos';
      case 'expiring':
        return 'Documentos por Vencer';
      default:
        return 'Estado de Documentos';
    }
  }
  
  String _getStatusDescription() {
    switch (_overallStatus) {
      case 'approved':
        return 'Todos tus documentos están aprobados y vigentes';
      case 'pending':
        return 'Algunos documentos están siendo revisados';
      case 'rejected':
        return 'Algunos documentos fueron rechazados y necesitan actualización';
      case 'incomplete':
        return 'Faltan documentos requeridos por subir';
      case 'expiring':
        return 'Algunos documentos están próximos a vencer';
      default:
        return 'Revisa el estado de tus documentos';
    }
  }
  
  Color _getDocumentStatusColor(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.approved:
        return ModernTheme.success;
      case DocumentStatus.pending:
        return ModernTheme.warning;
      case DocumentStatus.rejected:
        return ModernTheme.error;
      case DocumentStatus.expiring:
        return ModernTheme.warning;
      case DocumentStatus.missing:
        return context.secondaryText;
    }
  }
  
  String _getDocumentStatusText(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.approved:
        return 'Aprobado';
      case DocumentStatus.pending:
        return 'Pendiente';
      case DocumentStatus.rejected:
        return 'Rechazado';
      case DocumentStatus.expiring:
        return 'Por vencer';
      case DocumentStatus.missing:
        return 'Faltante';
    }
  }
  
  IconData _getDocumentIcon(DocumentCategory category) {
    switch (category) {
      case DocumentCategory.license:
        return Icons.drive_eta;
      case DocumentCategory.identity:
        return Icons.badge;
      case DocumentCategory.vehicle:
        return Icons.directions_car;
      case DocumentCategory.insurance:
        return Icons.security;
      case DocumentCategory.background:
        return Icons.verified_user;
      case DocumentCategory.financial:
        return Icons.account_balance;
    }
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  void _viewDocument(DocumentInfo document) {
    if (document.fileUrl == null) {
      _uploadDocument(document);
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    _getDocumentIcon(document.category),
                    color: ModernTheme.rappiOrange,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      document.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close),
                  ),
                ],
              ),
              SizedBox(height: 16),
              // Ronda 238: mostrar imagen real desde el backend con auth
              // header. La URL es relativa /api/media/... y requiere Bearer
              // token porque el scope de la mayoría de docs es privado.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    color: context.surfaceColor,
                    child: (document.fileUrl != null && document.fileUrl!.isNotEmpty)
                        ? Image.network(
                            document.fileUrl!.startsWith('http')
                                ? document.fileUrl!
                                : '${RapiApiClient.baseUrl}${document.fileUrl}',
                            headers: {
                              if (RapiApiClient.instance.currentAccessToken != null)
                                'Authorization': 'Bearer ${RapiApiClient.instance.currentAccessToken}',
                            },
                            fit: BoxFit.contain,
                            loadingBuilder: (ctx, child, progress) {
                              if (progress == null) return child;
                              return SizedBox(
                                height: 200,
                                child: Center(child: CircularProgressIndicator()),
                              );
                            },
                            errorBuilder: (ctx, e, s) => SizedBox(
                              height: 200,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image, size: 48, color: context.secondaryText),
                                  SizedBox(height: 8),
                                  Text('No se pudo cargar la imagen',
                                      style: TextStyle(color: context.secondaryText)),
                                ],
                              ),
                            ),
                          )
                        : SizedBox(
                            height: 200,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image_outlined, size: 48, color: context.secondaryText),
                                SizedBox(height: 8),
                                Text('Sin documento subido',
                                    style: TextStyle(color: context.secondaryText)),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
              SizedBox(height: 16),
              // Ronda 238: botones sin `.icon` para que el texto no se
              // corte en pantallas angostas. El texto queda legible siempre.
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _uploadDocument(document);
                      },
                      child: Text('Reemplazar',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _downloadDocument(document);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ModernTheme.rappiOrange,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Descargar',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _uploadDocument(DocumentInfo document) {
    showResponsiveBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Subir ${document.name}',
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
                    _pickFromCamera(document);
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
                    _pickFromGallery(document);
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
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _pickFromFiles(document);
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ModernTheme.warning.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.folder,
                          color: ModernTheme.warning,
                          size: 32,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('Archivos'),
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
  
  Future<void> _pickFromCamera(DocumentInfo document) async {
    try {
      // ✅ Capturar imagen desde la cámara usando image_picker
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) {
        // Usuario canceló
        return;
      }

      // Mostrar indicador de carga
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: context.surfaceColor)),
                SizedBox(width: 16),
                Text('Subiendo documento...'),
              ],
            ),
            duration: Duration(seconds: 30),
            backgroundColor: ModernTheme.info,
          ),
        );
      }

      // Subir archivo al backend Node y registrar el documento
      final file = File(image.path);
      final uploaded = await _api.uploadFile(file: file, scope: storageScopeForDocType(document.id));
      final fileUrl = uploaded['url']?.toString() ?? '';
      if (fileUrl.isEmpty) {
        throw Exception('El servidor no devolvió URL del archivo');
      }
      await _api.uploadDocument(docType: document.id, fileUrl: fileUrl);

      await _loadDocuments();

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Documento capturado y subido exitosamente'),
            backgroundColor: ModernTheme.success,
          ),
        );
      }
    } catch (e) {
      AppLogger.error(userFriendlyError(e, fallback: 'Error al capturar desde cámara'));
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFriendlyError(e, fallback: 'Error al subir documento')),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }
  
  Future<void> _pickFromGallery(DocumentInfo document) async {
    try {
      // ✅ Seleccionar imagen desde la galería usando image_picker
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) {
        // Usuario canceló
        return;
      }

      // Mostrar indicador de carga
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: context.surfaceColor)),
                SizedBox(width: 16),
                Text('Subiendo documento...'),
              ],
            ),
            duration: Duration(seconds: 30),
            backgroundColor: ModernTheme.info,
          ),
        );
      }

      // Subir archivo al backend Node y registrar el documento
      final file = File(image.path);
      final uploaded = await _api.uploadFile(file: file, scope: storageScopeForDocType(document.id));
      final fileUrl = uploaded['url']?.toString() ?? '';
      if (fileUrl.isEmpty) {
        throw Exception('El servidor no devolvió URL del archivo');
      }
      await _api.uploadDocument(docType: document.id, fileUrl: fileUrl);

      await _loadDocuments();

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Documento seleccionado y subido exitosamente'),
            backgroundColor: ModernTheme.success,
          ),
        );
      }
    } catch (e) {
      AppLogger.error(userFriendlyError(e, fallback: 'Error al seleccionar desde galería'));
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFriendlyError(e, fallback: 'Error al subir documento')),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }
  
  Future<void> _pickFromFiles(DocumentInfo document) async {
    try {
      // ✅ Seleccionar archivo usando file_picker (soporta PDF, imágenes, documentos)
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'], // Permitir PDFs e imágenes
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        // Usuario canceló
        return;
      }

      final pickedFile = result.files.first;
      if (pickedFile.path == null) {
        throw Exception('No se pudo acceder al archivo seleccionado');
      }

      // Validar tamaño del archivo (máximo 10MB)
      if (pickedFile.size > 10 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El archivo es demasiado grande. Máximo 10MB'),
              backgroundColor: ModernTheme.error,
            ),
          );
        }
        return;
      }

      // Mostrar indicador de carga
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: context.surfaceColor)),
                SizedBox(width: 16),
                Text('Subiendo documento...'),
              ],
            ),
            duration: Duration(seconds: 30),
            backgroundColor: ModernTheme.info,
          ),
        );
      }

      // Subir archivo al backend Node y registrar el documento
      final file = File(pickedFile.path!);
      final uploaded = await _api.uploadFile(file: file, scope: storageScopeForDocType(document.id));
      final fileUrl = uploaded['url']?.toString() ?? '';
      if (fileUrl.isEmpty) {
        throw Exception('El servidor no devolvió URL del archivo');
      }
      await _api.uploadDocument(docType: document.id, fileUrl: fileUrl);

      await _loadDocuments();

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Archivo seleccionado y subido exitosamente'),
            backgroundColor: ModernTheme.success,
          ),
        );
      }
    } catch (e) {
      AppLogger.error(userFriendlyError(e, fallback: 'Error al seleccionar archivo'));
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFriendlyError(e, fallback: 'Error al subir documento')),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }
  
  Future<void> _downloadDocument(DocumentInfo document) async {
    // ✅ Verificar que el widget esté montado antes de usar context
    if (!mounted) return;

    if (document.fileUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hay archivo disponible para descargar'),
          backgroundColor: ModernTheme.error,
        ),
      );
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(context.surfaceColor),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text('Descargando ${document.name}...'),
              ),
            ],
          ),
          backgroundColor: ModernTheme.info,
          duration: Duration(seconds: 30),
        ),
      );

      // ✅ IMPLEMENTACIÓN REAL: Descargar el archivo usando url_launcher
      // Esto abrirá el documento en el navegador/visor predeterminado del dispositivo
      final Uri fileUri = Uri.parse(document.fileUrl!);

      // En Android, esto abrirá el archivo en el navegador o app predeterminada
      // El usuario puede elegir descargar desde allí
      if (!await launchUrl(fileUri, mode: LaunchMode.externalApplication)) {
        throw Exception('No se pudo abrir el documento');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: context.surfaceColor),
              SizedBox(width: 12),
              Expanded(
                child: Text('Documento abierto. Puedes descargarlo desde el visor.'),
              ),
            ],
          ),
          backgroundColor: ModernTheme.success,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      AppLogger.error(userFriendlyError(e, fallback: 'Error al abrir documento'));
      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFriendlyError(e, fallback: 'Error al abrir el documento')),
          backgroundColor: ModernTheme.error,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }
  
  void _uploadAllDocuments() {
    // ✅ Verificar que el widget esté montado antes de usar context
    if (!mounted) return;

    final missingDocs = _documents.where((d) =>
        d.isRequired && (d.status == DocumentStatus.missing || d.status == DocumentStatus.rejected));

    if (missingDocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hay documentos pendientes por subir'),
          backgroundColor: ModernTheme.info,
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text('Subir Documentos Faltantes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Documentos pendientes:'),
            SizedBox(height: 8),
            ...missingDocs.map((doc) => Padding(
              padding: EdgeInsets.symmetric(vertical: 2),
              child: Text('• ${doc.name}'),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _bulkUploadDocuments(missingDocs.toList());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.rappiOrange,
            ),
            child: Text('Continuar'),
          ),
        ],
      ),
    );
  }
  
  void _bulkUploadDocuments(List<DocumentInfo> documents) {
    // ✅ Verificar que el widget esté montado antes de usar context
    if (!mounted) return;

    // Simulate bulk upload
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Iniciando carga masiva de documentos...'),
        backgroundColor: ModernTheme.info,
      ),
    );

    // Show upload for each document with a delay
    for (int i = 0; i < documents.length; i++) {
      Future.delayed(Duration(seconds: i * 2), () {
        // ✅ Verificar mounted antes de llamar a _uploadDocument
        if (!mounted) return;
        _uploadDocument(documents[i]);
      });
    }
  }
  
  Future<void> _downloadTemplate() async {
    // ✅ Verificar que el widget esté montado antes de usar context
    if (!mounted) return;

    try {
      // Mostrar indicador de carga
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.surfaceColor,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text('Generando lista de documentos...'),
              ),
            ],
          ),
          backgroundColor: ModernTheme.info,
          duration: Duration(seconds: 3),
        ),
      );

      // Generar contenido de la lista de documentos
      final StringBuffer content = StringBuffer();
      content.writeln('═══════════════════════════════════════════');
      content.writeln('    LISTA DE DOCUMENTOS REQUERIDOS');
      content.writeln('         CONDUCTORES RAPPI TEAM');
      content.writeln('═══════════════════════════════════════════');
      content.writeln('');
      content.writeln('Fecha de generación: ${DateTime.now().toString().substring(0, 16)}');
      content.writeln('');
      content.writeln('DOCUMENTOS OBLIGATORIOS:');
      content.writeln('');

      int index = 1;
      for (var doc in _documents) {
        content.writeln('$index. ${doc.name}');
        content.writeln('   Estado: ${_getStatusTextForDownload(doc.status)}');
        if (doc.expiryDate != null) {
          content.writeln('   Vencimiento: ${doc.expiryDate!.toString().substring(0, 10)}');
        }
        if (doc.uploadDate != null) {
          content.writeln('   Subido: ${doc.uploadDate!.toString().substring(0, 10)}');
        }
        content.writeln('');
        index++;
      }

      content.writeln('═══════════════════════════════════════════');
      content.writeln('INFORMACIÓN IMPORTANTE:');
      content.writeln('');
      content.writeln('• Todos los documentos deben estar vigentes');
      content.writeln('• Las fotos deben ser claras y legibles');
      content.writeln('• Evitar documentos con reflejos o borrosos');
      content.writeln('• Usar buena iluminación al fotografiar');
      content.writeln('• Actualizar antes de que venzan');
      content.writeln('');
      content.writeln('═══════════════════════════════════════════');
      content.writeln('');
      content.writeln('Para más información, contacta a soporte.');
      content.writeln('');
      content.writeln('Rappi Team - Tu aliado en el camino');
      content.writeln('═══════════════════════════════════════════');

      // Crear archivo temporal
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/documentos_requeridos_rappiteam.txt');
      await file.writeAsString(content.toString());

      if (!mounted) return;

      // Compartir/guardar archivo
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Lista de Documentos - Rappi Team',
        text: 'Lista de documentos requeridos para conductores de Rappi Team',
      );

      if (!mounted) return;

      // Limpiar SnackBar anterior
      ScaffoldMessenger.of(context).clearSnackBars();

      // Mostrar confirmación
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: context.surfaceColor),
              SizedBox(width: 12),
              Expanded(
                child: Text('Lista generada. Puedes guardarla en tu dispositivo.'),
              ),
            ],
          ),
          backgroundColor: ModernTheme.success,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      AppLogger.error(userFriendlyError(e, fallback: 'Error al generar lista de documentos'));
      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFriendlyError(e, fallback: 'Error al generar la lista')),
          backgroundColor: ModernTheme.error,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  String _getStatusTextForDownload(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.approved:
        return 'Aprobado ✓';
      case DocumentStatus.pending:
        return 'Pendiente de revisión';
      case DocumentStatus.rejected:
        return 'Rechazado - Requiere actualización';
      case DocumentStatus.expiring:
        return 'Por vencer - Actualizar pronto';
      case DocumentStatus.missing:
        return 'Faltante - Debe subirse';
    }
  }
  
  void _showDocumentInfo() {
    // ✅ Verificar que el widget esté montado antes de usar context
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.info, color: ModernTheme.rappiOrange),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Información de Documentos',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Estados de Documentos:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              _buildInfoItem(Icons.check_circle, 'Aprobado', 'El documento fue verificado y aceptado', ModernTheme.success),
              _buildInfoItem(Icons.schedule, 'Pendiente', 'El documento está siendo revisado', ModernTheme.warning),
              _buildInfoItem(Icons.error, 'Rechazado', 'El documento fue rechazado y debe ser actualizado', ModernTheme.error),
              _buildInfoItem(Icons.warning, 'Por vencer', 'El documento está próximo a vencer', ModernTheme.warning),
              _buildInfoItem(Icons.description, 'Faltante', 'El documento no ha sido subido', context.secondaryText),
              SizedBox(height: 16),
              Text(
                'Consejos:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Asegúrate de que los documentos sean legibles y estén vigentes'),
              Text('• Usa buena iluminación al tomar las fotos'),
              Text('• Evita documentos borrosos o con reflejos'),
              Text('• Mantén tus documentos actualizados'),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.rappiOrange,
            ),
            child: Text('Entendido'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoItem(IconData icon, String title, String description, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
                Text(
                  description,
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
  
  void _refreshDocuments() {
    // ✅ Verificar que el widget esté montado antes de usar setState
    if (!mounted) return;

    setState(() => _isLoading = true);
    _loadDocuments();
  }
}

// Models
class DocumentInfo {
  final String id;
  final String name;
  final String description;
  final DocumentStatus status;
  final DateTime? expiryDate;
  final DateTime? uploadDate;
  final String? fileUrl;
  final bool isRequired;
  final DocumentCategory category;
  final String? rejectionReason;
  
  DocumentInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.status,
    this.expiryDate,
    this.uploadDate,
    this.fileUrl,
    required this.isRequired,
    required this.category,
    this.rejectionReason,
  });
}

enum DocumentStatus {
  approved,
  pending,
  rejected,
  expiring,
  missing,
}

enum DocumentCategory {
  license,
  identity,
  vehicle,
  insurance,
  background,
  financial,
}