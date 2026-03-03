import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../core/design/design_system.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../core/widgets/rt_button.dart';
import '../../utils/logger.dart';
import '../../utils/firestore_error_handler.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  // Datos de documentos
  List<DocumentInfo> _documents = [];
  bool _isLoading = true;
  String _overallStatus = 'pending';

  // Instancias de Firebase
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  String? _userId;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
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

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          RtSnackbar.show(context, message: 'Usuario no autenticado. Por favor, inicia sesión.', type: RtSnackbarType.error);
          Navigator.pop(context);
        }
        return;
      }
      _userId = currentUser.uid;

      // Tipos de documentos requeridos con sus categorias
      final requiredDocTypes = {
        'license': {'name': 'Licencia de Conducir', 'description': 'Licencia de conducir profesional vigente', 'category': DocumentCategory.license, 'required': true},
        'id_card': {'name': 'Documento de Identidad', 'description': 'DNI o Pasaporte vigente', 'category': DocumentCategory.identity, 'required': true},
        'vehicle_registration': {'name': 'Tarjeta de Propiedad', 'description': 'Registro vehicular vigente', 'category': DocumentCategory.vehicle, 'required': true},
        'insurance': {'name': 'SOAT', 'description': 'Seguro Obligatorio de Accidentes de Transito', 'category': DocumentCategory.insurance, 'required': true},
        'technical_review': {'name': 'Revisión Técnica', 'description': 'Certificado de revisión técnica vehicular', 'category': DocumentCategory.vehicle, 'required': true},
        'background_check': {'name': 'Antecedentes Policiales', 'description': 'Certificado de antecedentes policiales', 'category': DocumentCategory.background, 'required': true},
        'bank_account': {'name': 'Certificacion Bancaria', 'description': 'Certificado de cuenta bancaria para depositos', 'category': DocumentCategory.financial, 'required': false},
      };

      // Cargar documentos subidos desde la subcoleccion
      final docsSnapshot = await _firestore
          .collection('drivers')
          .doc(_userId)
          .collection('documents')
          .get();

      // Mapear documentos subidos por su ID
      final uploadedDocs = <String, QueryDocumentSnapshot>{};
      for (var doc in docsSnapshot.docs) {
        uploadedDocs[doc.id] = doc;
      }

      // Crear lista de documentos con estado actual
      List<DocumentInfo> loadedDocs = [];
      for (var entry in requiredDocTypes.entries) {
        final docId = entry.key;
        final docInfo = entry.value;

        if (uploadedDocs.containsKey(docId)) {
          final data = uploadedDocs[docId]!.data() as Map<String, dynamic>;

          // Calcular estado basado en fechas y aprobación
          DocumentStatus status = DocumentStatus.pending;
          if (data['status'] != null) {
            switch (data['status']) {
              case 'approved':
                status = DocumentStatus.approved;
                if (data['expiryDate'] != null) {
                  final expiryDate = (data['expiryDate'] as Timestamp).toDate();
                  final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;
                  if (daysUntilExpiry <= 30 && daysUntilExpiry > 0) {
                    status = DocumentStatus.expiring;
                  } else if (daysUntilExpiry <= 0) {
                    status = DocumentStatus.rejected;
                  }
                }
                break;
              case 'pending':
                status = DocumentStatus.pending;
                break;
              case 'rejected':
                status = DocumentStatus.rejected;
                break;
            }
          }

          loadedDocs.add(DocumentInfo(
            id: docId,
            name: docInfo['name'] as String,
            description: docInfo['description'] as String,
            status: status,
            expiryDate: data['expiryDate'] != null ? (data['expiryDate'] as Timestamp).toDate() : null,
            uploadDate: data['uploadDate'] != null ? (data['uploadDate'] as Timestamp).toDate() : null,
            fileUrl: data['fileUrl'] as String?,
            isRequired: docInfo['required'] as bool,
            category: docInfo['category'] as DocumentCategory,
            rejectionReason: data['rejectionReason'] as String?,
          ));
        } else {
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
      AppLogger.error('Error al cargar documentos: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: RtAppBar(
        title: 'Mis Documentos',
        variant: RtAppBarVariant.gradient,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showDocumentInfo,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshDocuments,
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingState() : _buildDocumentsList(),
    );
  }

  Widget _buildLoadingState() {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(RtColors.brand),
          ),
          const SizedBox(height: 16),
          Text(
            'Cargando documentos...',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsList() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildStatusOverview(),
                _buildDocumentsSection(),
                _buildActionsSection(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusOverview() {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - _slideAnimation.value)),
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: _getStatusGradient(),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _getStatusColor().withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getStatusIcon(),
                        color: colorScheme.surface,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getStatusTitle(),
                            style: TextStyle(
                              color: colorScheme.surface,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _getStatusDescription(),
                            style: TextStyle(
                              color: colorScheme.surface.withValues(alpha: 0.7),
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
                const SizedBox(height: 16),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Icon(icon, color: colorScheme.surface.withValues(alpha: 0.7), size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: colorScheme.surface,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: colorScheme.surface.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsSection() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Lista de Documentos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          ..._documents.asMap().entries.map((entry) {
            final index = entry.key;
            final document = entry.value;

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
                  animationStart,
                  animationEnd,
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
                    opacity: animation.value.clamp(0.0, 1.0),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: RtShadow.soft(),
        border: Border.all(
          color: _getDocumentStatusColor(document.status).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _viewDocument(document),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
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
                  const SizedBox(width: 12),
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
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (document.isRequired)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: RtColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Requerido',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: RtColors.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          document.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (document.uploadDate != null) ...[
                      Icon(Icons.upload, size: 14, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                      const SizedBox(width: 4),
                      Text(
                        'Subido: ${_formatDate(document.uploadDate!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                    if (document.expiryDate != null) ...[
                      const SizedBox(width: 16),
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: document.status == DocumentStatus.expiring
                            ? RtColors.warning
                            : colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Vence: ${_formatDate(document.expiryDate!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: document.status == DocumentStatus.expiring
                              ? RtColors.warning
                              : colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ],

              if (document.rejectionReason != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: RtColors.error.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: RtColors.error.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: RtColors.error, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          document.rejectionReason!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: RtColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (document.status == DocumentStatus.missing ||
                      document.status == DocumentStatus.rejected ||
                      document.status == DocumentStatus.expiring)
                    RtButton(
                      label: document.status == DocumentStatus.missing ? 'Subir' : 'Actualizar',
                      icon: Icons.cloud_upload,
                      onPressed: () => _uploadDocument(document),
                      size: RtButtonSize.small,
                      isFullWidth: false,
                    ),
                  if (document.fileUrl != null) ...[
                    const SizedBox(width: 8),
                    RtButton(
                      label: 'Ver',
                      icon: Icons.visibility,
                      onPressed: () => _viewDocument(document),
                      variant: RtButtonVariant.outlined,
                      size: RtButtonSize.small,
                      isFullWidth: false,
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
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          RtButton(
            label: 'Subir Documentos Faltantes',
            icon: Icons.upload_file,
            onPressed: _uploadAllDocuments,
          ),
          const SizedBox(height: 12),
          RtButton(
            label: 'Descargar Lista de Documentos',
            icon: Icons.download,
            onPressed: _downloadTemplate,
            variant: RtButtonVariant.outlined,
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (_overallStatus) {
      case 'approved':
        return RtColors.success;
      case 'pending':
        return RtColors.warning;
      case 'rejected':
      case 'incomplete':
        return RtColors.error;
      case 'expiring':
        return RtColors.warning;
      default:
        return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
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
        return 'Algunos documentos fueron rechazados y necesitan actualizacion';
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
        return RtColors.success;
      case DocumentStatus.pending:
        return RtColors.warning;
      case DocumentStatus.rejected:
        return RtColors.error;
      case DocumentStatus.expiring:
        return RtColors.warning;
      case DocumentStatus.missing:
        return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
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

    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    _getDocumentIcon(document.category),
                    color: RtColors.brand,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      document.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.18)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image,
                      size: 64,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vista previa del documento',
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      '(Simulacion)',
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: RtButton(
                      label: 'Actualizar',
                      icon: Icons.cloud_upload,
                      onPressed: () {
                        Navigator.pop(context);
                        _uploadDocument(document);
                      },
                      variant: RtButtonVariant.outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RtButton(
                      label: 'Descargar',
                      icon: Icons.download,
                      onPressed: () {
                        Navigator.pop(context);
                        _downloadDocument(document);
                      },
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
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Subir ${document.name}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
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
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: RtColors.info.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: RtColors.info,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Cámara'),
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
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: RtColors.brand.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.photo_library,
                          color: RtColors.brand,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Galería'),
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
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: RtColors.warning.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.folder,
                          color: RtColors.warning,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Archivos'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Validacion de imagen: Verifica tamano, dimensiones y formato antes de subir
  /// Retorna null si es válida, o un mensaje de error si no lo es
  Future<String?> _validateDocumentImage(File file) async {
    if (!await file.exists()) {
      return 'El archivo no existe o no se puede acceder';
    }

    final fileSize = await file.length();
    if (fileSize < 50 * 1024) {
      return 'La imagen es demasiado pequeña (mínimo 50KB). Por favor, tome una foto más clara.';
    }

    if (fileSize > 10 * 1024 * 1024) {
      return 'La imagen es demasiado grande (máximo 10MB).';
    }

    final extension = file.path.toLowerCase().split('.').last;
    if (!['jpg', 'jpeg', 'png', 'heic', 'heif'].contains(extension)) {
      return 'Formato de imagen no válido. Use JPG, PNG o HEIC.';
    }

    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        return 'El archivo de imagen esta vacio o corrupto.';
      }

      final isJpeg = bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
      final isPng = bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47;
      final isHeic = bytes.length >= 12 && String.fromCharCodes(bytes.sublist(4, 12)).contains('ftyp');

      if (!isJpeg && !isPng && !isHeic) {
        return 'El archivo no es una imagen válida. Por favor, seleccione una imagen real.';
      }
    } catch (e) {
      return 'No se pudo leer el archivo de imagen.';
    }

    return null;
  }

  Future<void> _pickFromCamera(DocumentInfo document) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      final file = File(image.path);
      final validationError = await _validateDocumentImage(file);
      if (validationError != null) {
        if (mounted) {
          RtSnackbar.show(context, message: validationError, type: RtSnackbarType.error);
        }
        return;
      }

      if (mounted) {
        RtSnackbar.show(context, message: 'Subiendo documento...', type: RtSnackbarType.info);
      }

      final storageRef = _storage
          .ref()
          .child('drivers')
          .child(_userId!)
          .child('documents')
          .child('${document.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      await _firestore
          .collection('drivers')
          .doc(_userId!)
          .collection('documents')
          .doc(document.id)
          .set({
        'name': document.name,
        'description': document.description,
        'status': 'pending',
        'uploadDate': FieldValue.serverTimestamp(),
        'fileUrl': downloadUrl,
        'category': document.category.toString(),
        'isRequired': document.isRequired,
      }, SetOptions(merge: true));

      await _loadDocuments();

      if (mounted) {
        RtSnackbar.show(context, message: 'Documento capturado y subido exitosamente', type: RtSnackbarType.success);
      }
    } catch (e) {
      AppLogger.error('Error al capturar desde cámara: $e');
      if (mounted) {
        RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
      }
    }
  }

  Future<void> _pickFromGallery(DocumentInfo document) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      final file = File(image.path);
      final validationError = await _validateDocumentImage(file);
      if (validationError != null) {
        if (mounted) {
          RtSnackbar.show(context, message: validationError, type: RtSnackbarType.error);
        }
        return;
      }

      if (mounted) {
        RtSnackbar.show(context, message: 'Subiendo documento...', type: RtSnackbarType.info);
      }

      final storageRef = _storage
          .ref()
          .child('drivers')
          .child(_userId!)
          .child('documents')
          .child('${document.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      await _firestore
          .collection('drivers')
          .doc(_userId!)
          .collection('documents')
          .doc(document.id)
          .set({
        'name': document.name,
        'description': document.description,
        'status': 'pending',
        'uploadDate': FieldValue.serverTimestamp(),
        'fileUrl': downloadUrl,
        'category': document.category.toString(),
        'isRequired': document.isRequired,
      }, SetOptions(merge: true));

      await _loadDocuments();

      if (mounted) {
        RtSnackbar.show(context, message: 'Documento seleccionado y subido exitosamente', type: RtSnackbarType.success);
      }
    } catch (e) {
      AppLogger.error('Error al seleccionar desde galería: $e');
      if (mounted) {
        RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
      }
    }
  }

  Future<void> _pickFromFiles(DocumentInfo document) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.first;
      if (pickedFile.path == null) {
        throw Exception('No se pudo acceder al archivo seleccionado');
      }

      if (pickedFile.size > 10 * 1024 * 1024) {
        if (mounted) {
          RtSnackbar.show(context, message: 'El archivo es demasiado grande. Máximo 10MB', type: RtSnackbarType.error);
        }
        return;
      }

      if (mounted) {
        RtSnackbar.show(context, message: 'Subiendo documento...', type: RtSnackbarType.info);
      }

      final file = File(pickedFile.path!);
      final fileExtension = pickedFile.extension ?? 'pdf';
      final storageRef = _storage
          .ref()
          .child('drivers')
          .child(_userId!)
          .child('documents')
          .child('${document.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension');

      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      await _firestore
          .collection('drivers')
          .doc(_userId!)
          .collection('documents')
          .doc(document.id)
          .set({
        'name': document.name,
        'description': document.description,
        'status': 'pending',
        'uploadDate': FieldValue.serverTimestamp(),
        'fileUrl': downloadUrl,
        'fileName': pickedFile.name,
        'fileExtension': fileExtension,
        'fileSize': pickedFile.size,
        'category': document.category.toString(),
        'isRequired': document.isRequired,
      }, SetOptions(merge: true));

      await _loadDocuments();

      if (mounted) {
        RtSnackbar.show(context, message: 'Archivo seleccionado y subido exitosamente', type: RtSnackbarType.success);
      }
    } catch (e) {
      AppLogger.error('Error al seleccionar archivo: $e');
      if (mounted) {
        RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
      }
    }
  }

  Future<void> _downloadDocument(DocumentInfo document) async {
    if (!mounted) return;

    if (document.fileUrl == null) {
      RtSnackbar.show(context, message: 'No hay archivo disponible para descargar', type: RtSnackbarType.error);
      return;
    }

    try {
      RtSnackbar.show(context, message: 'Descargando ${document.name}...', type: RtSnackbarType.info);

      final Uri fileUri = Uri.parse(document.fileUrl!);

      if (!await launchUrl(fileUri, mode: LaunchMode.externalApplication)) {
        throw Exception('No se pudo abrir el documento');
      }

      if (!mounted) return;

      RtSnackbar.show(context, message: 'Documento abierto. Puedes descargarlo desde el visor.', type: RtSnackbarType.success);
    } catch (e) {
      AppLogger.error('Error al abrir documento: $e');
      if (!mounted) return;

      RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
    }
  }

  void _uploadAllDocuments() {
    if (!mounted) return;

    final missingDocs = _documents.where((d) =>
        d.isRequired && (d.status == DocumentStatus.missing || d.status == DocumentStatus.rejected));

    if (missingDocs.isEmpty) {
      RtSnackbar.show(context, message: 'No hay documentos pendientes por subir', type: RtSnackbarType.info);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Subir Documentos Faltantes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Documentos pendientes:'),
            const SizedBox(height: 8),
            ...missingDocs.map((doc) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('* ${doc.name}'),
            )),
          ],
        ),
        actions: [
          RtButton(
            label: 'Cancelar',
            onPressed: () => Navigator.pop(context),
            variant: RtButtonVariant.ghost,
            isFullWidth: false,
          ),
          RtButton(
            label: 'Continuar',
            onPressed: () {
              Navigator.pop(context);
              _bulkUploadDocuments(missingDocs.toList());
            },
            isFullWidth: false,
          ),
        ],
      ),
    );
  }

  void _bulkUploadDocuments(List<DocumentInfo> documents) {
    if (!mounted) return;

    RtSnackbar.show(context, message: 'Iniciando carga masiva de documentos...', type: RtSnackbarType.info);

    for (int i = 0; i < documents.length; i++) {
      Future.delayed(Duration(seconds: i * 2), () {
        if (!mounted) return;
        _uploadDocument(documents[i]);
      });
    }
  }

  Future<void> _downloadTemplate() async {
    if (!mounted) return;

    try {
      RtSnackbar.show(context, message: 'Generando lista de documentos...', type: RtSnackbarType.info);

      final StringBuffer content = StringBuffer();
      content.writeln('===================================');
      content.writeln('    LISTA DE DOCUMENTOS REQUERIDOS');
      content.writeln('         CONDUCTORES RAPITEAM');
      content.writeln('===================================');
      content.writeln('');
      content.writeln('Fecha de generacion: ${DateTime.now().toString().substring(0, 16)}');
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

      content.writeln('===================================');
      content.writeln('INFORMACION IMPORTANTE:');
      content.writeln('');
      content.writeln('* Todos los documentos deben estar vigentes');
      content.writeln('* Las fotos deben ser claras y legibles');
      content.writeln('* Evitar documentos con reflejos o borrosos');
      content.writeln('* Usar buena iluminacion al fotografiar');
      content.writeln('* Actualizar antes de que venzan');
      content.writeln('');
      content.writeln('===================================');
      content.writeln('');
      content.writeln('Para más información, contacta a soporte.');
      content.writeln('');
      content.writeln('RapiTeam - Tu aliado en el camino');
      content.writeln('===================================');

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/documentos_requeridos_rapiteam.txt');
      await file.writeAsString(content.toString());

      if (!mounted) return;

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Lista de Documentos - RapiTeam',
        text: 'Lista de documentos requeridos para conductores de RapiTeam',
      );

      if (!mounted) return;

      RtSnackbar.show(context, message: 'Lista generada. Puedes guardarla en tu dispositivo.', type: RtSnackbarType.success);
    } catch (e) {
      AppLogger.error('Error al generar lista de documentos: $e');
      if (!mounted) return;

      RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
    }
  }

  String _getStatusTextForDownload(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.approved:
        return 'Aprobado';
      case DocumentStatus.pending:
        return 'Pendiente de revisión';
      case DocumentStatus.rejected:
        return 'Rechazado - Requiere actualizacion';
      case DocumentStatus.expiring:
        return 'Por vencer - Actualizar pronto';
      case DocumentStatus.missing:
        return 'Faltante - Debe subirse';
    }
  }

  void _showDocumentInfo() {
    if (!mounted) return;

    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            const Icon(Icons.info, color: RtColors.brand),
            const SizedBox(width: 8),
            const Expanded(
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
              const Text(
                'Estados de Documentos:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildInfoItem(Icons.check_circle, 'Aprobado', 'El documento fue verificado y aceptado', RtColors.success),
              _buildInfoItem(Icons.schedule, 'Pendiente', 'El documento esta siendo revisado', RtColors.warning),
              _buildInfoItem(Icons.error, 'Rechazado', 'El documento fue rechazado y debe ser actualizado', RtColors.error),
              _buildInfoItem(Icons.warning, 'Por vencer', 'El documento esta próximo a vencer', RtColors.warning),
              _buildInfoItem(Icons.description, 'Faltante', 'El documento no ha sido subido', colorScheme.onSurface.withValues(alpha: 0.6)),
              const SizedBox(height: 16),
              const Text(
                'Consejos:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('* Asegurate de que los documentos sean legibles y esten vigentes'),
              const Text('* Usa buena iluminacion al tomar las fotos'),
              const Text('* Evita documentos borrosos o con reflejos'),
              const Text('* Manten tus documentos actualizados'),
            ],
          ),
        ),
        actions: [
          RtButton(
            label: 'Entendido',
            onPressed: () => Navigator.pop(context),
            isFullWidth: false,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String title, String description, Color color) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
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
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
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
    if (!mounted) return;

    setState(() => _isLoading = true);
    _loadDocuments();
  }
}

// Modelos
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
