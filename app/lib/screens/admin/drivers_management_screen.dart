import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/design/design_system.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_button.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../utils/firestore_error_handler.dart';

class DriversManagementScreen extends StatefulWidget {
  const DriversManagementScreen({super.key});

  @override
  State<DriversManagementScreen> createState() => _DriversManagementScreenState();
}

class _DriversManagementScreenState extends State<DriversManagementScreen>
    with TickerProviderStateMixin {
  late AnimationController _listController;
  late AnimationController _statsController;
  late TabController _tabController;
  
  String _searchQuery = '';
  String _selectedStatus = 'all';
  String _sortBy = 'name';
  
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // ✅ Lista de conductores desde Firebase (sin datos mock)
  List<Driver> _drivers = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _statsController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _tabController = TabController(length: 4, vsync: this);
    
    _listController.forward();
    _statsController.forward();
    
    // Cargar conductores desde Firebase
    _loadDriversFromFirebase();
  }
  
  Future<void> _loadDriversFromFirebase() async {
    try {
      setState(() {
        _isLoading = true;
      });

      debugPrint('🚗 Cargando conductores desde Firebase...');

      // ✅ CORREGIDO: Buscar conductores (driver O dual) - FORZAR lectura desde servidor
      QuerySnapshot driversSnapshot;
      try {
        // Intentar primero con whereIn para userType 'driver' O 'dual'
        // GetOptions.source = Source.server para forzar lectura desde servidor (no caché)
        driversSnapshot = await _firestore
            .collection('users')
            .where('userType', whereIn: ['driver', 'dual'])
            .orderBy('createdAt', descending: true)
            .get(const GetOptions(source: Source.server))
            .timeout(Duration(seconds: 15));
        debugPrint('✅ Query con userType exitosa (desde servidor)');
      } catch (e) {
        debugPrint('⚠️ Query con userType falló, intentando con availableRoles: $e');
        // Si falla, intentar con array-contains
        driversSnapshot = await _firestore
            .collection('users')
            .where('availableRoles', arrayContains: 'driver')
            .get(const GetOptions(source: Source.server))
            .timeout(Duration(seconds: 15));
      }

      debugPrint('✅ Conductores encontrados: ${driversSnapshot.docs.length}');

      List<Driver> loadedDrivers = [];

      for (var doc in driversSnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) {
            debugPrint('⚠️ Conductor ${doc.id} sin datos');
            continue;
          }
        
        // ✅ CORREGIDO: Obtener vehículo del conductor desde vehicleInfo (objeto anidado)
        Vehicle vehicle;
        final vehicleInfo = data['vehicleInfo'];
        if (vehicleInfo != null && vehicleInfo is Map) {
          final vData = Map<String, dynamic>.from(vehicleInfo);
          vehicle = Vehicle(
            brand: vData['make'] ?? vData['brand'] ?? 'Sin marca',
            model: vData['model'] ?? 'Sin modelo',
            year: vData['year'] ?? DateTime.now().year,
            plate: vData['plate'] ?? 'XXX-000',
            color: vData['color'] ?? 'Sin color',
          );
          debugPrint('🚗 Vehículo cargado: ${vehicle.brand} ${vehicle.model} - ${vehicle.plate}');
        } else {
          // Si no hay vehicleInfo, usar valores por defecto
          vehicle = Vehicle(
            brand: 'Por registrar',
            model: 'Por registrar',
            year: DateTime.now().year,
            plate: 'XXX-000',
            color: 'Por registrar',
          );
          debugPrint('⚠️ Sin información de vehículo para conductor');
        }
        
        // ✅ CORREGIDO: Obtener documentos del conductor desde el objeto 'documents'
        List<Document> documents = [];

        // Los documentos están dentro del campo 'documents' como un Map
        // Manejar diferentes tipos de datos que puede devolver Firestore
        Map<String, dynamic> docsData = {};
        final rawDocs = data['documents'];
        if (rawDocs != null) {
          if (rawDocs is Map) {
            docsData = Map<String, dynamic>.from(rawDocs);
          }
        }

        // DEBUG: Ver qué datos tiene el conductor
        debugPrint('=== CONDUCTOR DEBUG START ===');
        debugPrint('CONDUCTOR NOMBRE: ${data['fullName']}');
        debugPrint('DOCUMENTS RAW TYPE: ${rawDocs?.runtimeType}');
        debugPrint('DOCUMENTS RAW: $rawDocs');
        debugPrint('DOCS DATA: $docsData');
        debugPrint('DOCS DATA KEYS: ${docsData.keys.toList()}');
        debugPrint('=== CONDUCTOR DEBUG END ===');

        // CORREGIDO: Agregar cada documento con su URL y log para debug
        // ✅ FIX 2026-01-05: Si conductor está verificado, documentos también están verificados
        final bool isDriverVerified = data['isVerified'] == true;

        void addDoc(String type, String key) {
          final url = docsData[key]?.toString();
          final hasUrl = url != null && url.isNotEmpty;
          // Si el conductor está verificado, los documentos están verificados
          // Usar 'verified' para consistencia con el switch case
          final docStatus = hasUrl
              ? (isDriverVerified ? 'verified' : 'pending')
              : 'missing';
          debugPrint('DOC $type: hasUrl=$hasUrl, key=$key, status=$docStatus');
          if (hasUrl) {
            debugPrint('  URL FOUND: ${url.substring(0, url.length > 80 ? 80 : url.length)}...');
          }
          documents.add(Document(
            type: type,
            status: docStatus,
            url: url,
          ));
        }

        addDoc('DNI / Identidad', 'dniPhoto');
        addDoc('Licencia de Conducir', 'licensePhoto');
        addDoc('Foto del Vehículo', 'vehiclePhoto');
        addDoc('SOAT', 'soatPhoto');
        addDoc('Antecedentes Penales', 'criminalRecordPhoto');
        addDoc('Revisión Técnica', 'technicalReviewPhoto');
        addDoc('Tarjeta de Propiedad', 'ownershipPhoto');

        debugPrint('TOTAL DOCS: ${documents.length}, WITH URL: ${documents.where((d) => d.url != null && d.url!.isNotEmpty).length}');
        
          // ✅ CORREGIDO: Usar datos del modelo si están disponibles
          int totalTrips = data['totalTrips'] ?? 0;
          double totalEarnings = (data['totalEarnings'] ?? 0.0).toDouble();
          double totalCommission = 0.0;
          DateTime? lastTripDate;

          // ✅ CORREGIDO: Si no tiene totalTrips en el modelo, intentar obtenerlos de rides
          if (totalTrips == 0 || totalEarnings == 0) {
            try {
              final tripsSnapshot = await _firestore
                  .collection('rides')
                  .where('driverId', isEqualTo: doc.id)
                  .where('status', isEqualTo: 'completed')
                  .orderBy('completedAt', descending: true)
                  .limit(100)
                  .get()
                  .timeout(Duration(seconds: 3));

              totalTrips = tripsSnapshot.docs.length;

              for (var tripDoc in tripsSnapshot.docs) {
                try {
                  final tripData = tripDoc.data();
                  if (tripData['finalFare'] != null) {
                    double fare = (tripData['finalFare'] as num).toDouble();
                    totalEarnings += fare;

                    // Calcular comisión si está disponible
                    if (tripData['platformCommission'] != null) {
                      totalCommission += (tripData['platformCommission'] as num).toDouble();
                    } else {
                      totalCommission += fare * 0.20; // 20% por defecto
                    }
                  }
                } catch (e) {
                  debugPrint('⚠️ Error procesando trip: $e');
                }
              }

              if (tripsSnapshot.docs.isNotEmpty) {
                try {
                  lastTripDate = (tripsSnapshot.docs.first.data()['completedAt'] as Timestamp?)?.toDate();
                } catch (e) {
                  debugPrint('⚠️ Error obteniendo lastTripDate: $e');
                }
              }
            } catch (e) {
              debugPrint('⚠️ No se pudo obtener trips para conductor ${doc.id}: $e');
            }
          }
        
        // Determinar estado del conductor
        // ✅ FIX 2026-01-05: Considerar isVerified == null como pendiente
        debugPrint('🔍 ESTADO CONDUCTOR ${data['fullName']}: isSuspended=${data['isSuspended']}, isActive=${data['isActive']}, isVerified=${data['isVerified']}');
        DriverStatus status;
        if (data['isSuspended'] == true) {
          status = DriverStatus.suspended;
          debugPrint('   → STATUS: suspended');
        } else if (data['isActive'] == false) {
          status = DriverStatus.inactive;
          debugPrint('   → STATUS: inactive');
        } else if (data['isVerified'] != true) {
          // ✅ FIX: Si isVerified es false O null, el conductor está pendiente
          status = DriverStatus.pending;
          debugPrint('   → STATUS: pending (isVerified != true)');
        } else {
          status = DriverStatus.active;
          debugPrint('   → STATUS: active');
        }
        
          loadedDrivers.add(Driver(
            id: doc.id,
            name: data['displayName'] ?? data['fullName'] ?? 'Sin nombre',
            email: data['email'] ?? 'sin@email.com',
            phone: data['phoneNumber'] ?? data['phone'] ?? 'Sin teléfono',
            photo: data['photoURL'] ?? data['profilePhotoUrl'] ?? '',
            license: data['license'] ?? data['licenseNumber'] ?? 'Sin licencia',
            status: status,
            rating: (data['rating'] ?? 5.0).toDouble(),
            totalTrips: totalTrips,
            joinDate: data['createdAt'] != null
                ? (data['createdAt'] as Timestamp).toDate()
                : DateTime.now(),
            vehicle: vehicle,
            documents: documents,
            earnings: totalEarnings,
            commission: totalCommission,
            lastTrip: lastTripDate,
          ));

          debugPrint('✅ Conductor procesado: ${data['fullName'] ?? 'Sin nombre'}');
        } catch (e) {
          debugPrint('⚠️ Error procesando conductor ${doc.id}: $e');
          continue;
        }
      }

      debugPrint('✅ Total conductores procesados: ${loadedDrivers.length}');

      if (mounted) {
        setState(() {
          _drivers = loadedDrivers;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error crítico cargando conductores: $e');
      debugPrint('📍 Stack: $stackTrace');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
      }
    }
  }
  
  List<Driver> get _filteredDrivers {
    var filtered = _drivers;
    
    // Filtrar por búsqueda
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((driver) {
        return driver.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               driver.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               driver.phone.contains(_searchQuery) ||
               driver.vehicle.plate.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
    
    // Filtrar por estado
    if (_selectedStatus != 'all') {
      filtered = filtered.where((driver) {
        return driver.status.toString().split('.').last == _selectedStatus;
      }).toList();
    }
    
    // Ordenar
    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'name':
          return a.name.compareTo(b.name);
        case 'rating':
          return b.rating.compareTo(a.rating);
        case 'trips':
          return b.totalTrips.compareTo(a.totalTrips);
        case 'earnings':
          return b.earnings.compareTo(a.earnings);
        default:
          return 0;
      }
    });
    
    return filtered;
  }
  
  Map<String, dynamic> get _statistics {
    final activeDrivers = _drivers.where((d) => d.status == DriverStatus.active).length;
    final pendingDrivers = _drivers.where((d) => d.status == DriverStatus.pending).length;
    final totalEarnings = _drivers.fold<double>(0, (total, d) => total + d.earnings);
    final totalCommission = _drivers.fold<double>(0, (total, d) => total + d.commission);
    
    return {
      'total': _drivers.length,
      'active': activeDrivers,
      'pending': pendingDrivers,
      'earnings': totalEarnings,
      'commission': totalCommission,
    };
  }
  
  
  @override
  void dispose() {
    _listController.dispose();
    _statsController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final stats = _statistics;
    
    return Scaffold(
      backgroundColor: RtColors.neutral50,
      appBar: RtAppBar(
        title: 'Gestión de Conductores',
        variant: RtAppBarVariant.gradient,
        actions: [
          IconButton(
            icon: Icon(Icons.person_add, color: Theme.of(context).colorScheme.onPrimary),
            tooltip: 'Agregar Conductor',
            onPressed: _addNewDriver,
          ),
          IconButton(
            icon: Icon(Icons.filter_list, color: Theme.of(context).colorScheme.onPrimary),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: Icon(Icons.download, color: Theme.of(context).colorScheme.onPrimary),
            onPressed: _exportData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: RtColors.brand,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Cargando conductores...',
                    style: TextStyle(
                      color: RtColors.neutral500,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadDriversFromFirebase,
              color: RtColors.brand,
              backgroundColor: Theme.of(context).colorScheme.surface,
              child: Column(
        children: [
          // Estadísticas
          AnimatedBuilder(
            animation: _statsController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, -50 * (1 - _statsController.value)),
                child: Opacity(
                  opacity: _statsController.value,
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          RtColors.brand,
                          RtColors.brand.withBlue(30),
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatCard('Total', '${stats['total']}', Icons.group),
                        _buildStatCard('Activos', '${stats['active']}', Icons.check_circle),
                        _buildStatCard('Pendientes', '${stats['pending']}', Icons.pending),
                        _buildStatCard(
                          'Ganancias',
                          'S/. ${(stats['earnings'] / 1000).toStringAsFixed(1)}K',
                          Icons.account_balance_wallet,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          
          // Barra de búsqueda
          Container(
            padding: EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre, email, teléfono o placa...',
                      prefixIcon: Icon(Icons.search, color: RtColors.brand),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: RtColors.neutral50,
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),
                SizedBox(width: 12),
                PopupMenuButton<String>(
                  icon: Icon(Icons.sort, color: RtColors.brand),
                  onSelected: (value) {
                    setState(() => _sortBy = value);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'name', child: Text('Nombre')),
                    PopupMenuItem(value: 'rating', child: Text('Calificación')),
                    PopupMenuItem(value: 'trips', child: Text('Viajes')),
                    PopupMenuItem(value: 'earnings', child: Text('Ganancias')),
                  ],
                ),
              ],
            ),
          ),
          
          // Tabs de estado
          Container(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: RtColors.brand,
              unselectedLabelColor: RtColors.neutral500,
              indicatorColor: RtColors.brand,
              onTap: (index) {
                setState(() {
                  switch (index) {
                    case 0:
                      _selectedStatus = 'all';
                      break;
                    case 1:
                      _selectedStatus = 'active';
                      break;
                    case 2:
                      _selectedStatus = 'pending';
                      break;
                    case 3:
                      _selectedStatus = 'inactive';
                      break;
                  }
                });
              },
              tabs: [
                Tab(text: 'Todos'),
                Tab(text: 'Activos'),
                Tab(text: 'Pendientes'),
                Tab(text: 'Inactivos'),
              ],
            ),
          ),
          
          // Lista de conductores
          Expanded(
            child: AnimatedBuilder(
              animation: _listController,
              builder: (context, child) {
                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _filteredDrivers.length,
                  itemBuilder: (context, index) {
                    final driver = _filteredDrivers[index];
                    final delay = index * 0.1;
                    final animation = Tween<double>(
                      begin: 0,
                      end: 1,
                    ).animate(
                      CurvedAnimation(
                        parent: _listController,
                        curve: Interval(
                          delay,
                          delay + 0.5,
                          curve: Curves.easeOutBack,
                        ),
                      ),
                    );
                    
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(50 * (1 - animation.value), 0),
                          child: Opacity(
                            opacity: animation.value,
                            child: _buildDriverCard(driver),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
            ),
    );
  }
  
  Widget _buildStatCard(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.onPrimary, size: 20),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.70),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  Widget _buildDriverCard(Driver driver) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: RtShadow.soft(),
      ),
      child: InkWell(
        onTap: () => _showDriverDetails(driver),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // Header con foto y estado
              Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: NetworkImage(driver.photo),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: _getStatusColor(driver.status),
                            shape: BoxShape.circle,
                            border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          driver.email,
                          style: TextStyle(
                            fontSize: 12,
                            color: RtColors.neutral500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          driver.phone,
                          style: TextStyle(
                            fontSize: 12,
                            color: RtColors.neutral500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(driver.status),
                ],
              ),
              
              SizedBox(height: 16),
              
              // Información del vehículo
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: RtColors.neutral50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.directions_car, color: RtColors.neutral500, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${driver.vehicle.brand.toUpperCase()} ${driver.vehicle.model.toUpperCase()} ${driver.vehicle.year}',
                        style: TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        driver.vehicle.plate.toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 12),
              
              // Estadísticas
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniStat(Icons.star, driver.rating.toString(), 'Rating', Colors.amber),
                  _buildMiniStat(Icons.route, driver.totalTrips.toString(), 'Viajes', RtColors.info),
                  _buildMiniStat(Icons.account_balance_wallet, 'S/.${(driver.earnings / 1000).toStringAsFixed(1)}K', 'Ganancias', RtColors.success),
                  if (driver.lastTrip != null)
                    _buildMiniStat(Icons.access_time, _formatLastTrip(driver.lastTrip!), 'Último', RtColors.info),
                ],
              ),
              
              SizedBox(height: 12),
              
              // Documentos
              _buildDocumentsRow(driver.documents),
              
              SizedBox(height: 12),
              
              // Acciones
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (driver.status == DriverStatus.pending) ...[
                    RtButton(
                      label: 'Rechazar',
                      icon: Icons.close,
                      variant: RtButtonVariant.danger,
                      isFullWidth: false,
                      size: RtButtonSize.small,
                      onPressed: () => _rejectDriver(driver),
                    ),
                    SizedBox(width: 8),
                    RtButton(
                      label: 'Aprobar',
                      icon: Icons.check,
                      isFullWidth: false,
                      size: RtButtonSize.small,
                      onPressed: () => _approveDriver(driver),
                    ),
                  ] else if (driver.status == DriverStatus.active) ...[
                    RtButton(
                      label: 'Suspender',
                      icon: Icons.block,
                      variant: RtButtonVariant.outlined,
                      isFullWidth: false,
                      size: RtButtonSize.small,
                      onPressed: () => _suspendDriver(driver),
                    ),
                  ] else if (driver.status == DriverStatus.suspended) ...[
                    RtButton(
                      label: 'Activar',
                      icon: Icons.check_circle,
                      isFullWidth: false,
                      size: RtButtonSize.small,
                      onPressed: () => _activateDriver(driver),
                    ),
                  ],
                  IconButton(
                    icon: Icon(Icons.more_vert),
                    onPressed: () => _showDriverOptions(driver),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatusBadge(DriverStatus status) {
    String text;
    Color color;
    
    switch (status) {
      case DriverStatus.active:
        text = 'Activo';
        color = RtColors.success;
        break;
      case DriverStatus.inactive:
        text = 'Inactivo';
        color = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54);
        break;
      case DriverStatus.pending:
        text = 'Pendiente';
        color = RtColors.warning;
        break;
      case DriverStatus.suspended:
        text = 'Suspendido';
        color = RtColors.error;
        break;
    }
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  Widget _buildMiniStat(IconData icon, String value, String label, Color color) {
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              SizedBox(width: 2),
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: RtColors.neutral500,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
  
  Widget _buildDocumentsRow(List<Document> documents) {
    return Row(
      children: [
        Icon(Icons.description, size: 16, color: RtColors.neutral500),
        SizedBox(width: 8),
        Text(
          'Documentos:',
          style: TextStyle(
            fontSize: 12,
            color: RtColors.neutral500,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Row(
            children: documents.map((doc) {
              Color color;
              IconData icon;
              
              switch (doc.status) {
                case 'verified':
                case 'approved':  // ✅ FIX: También reconocer 'approved'
                  color = RtColors.success;
                  icon = Icons.check_circle;
                  break;
                case 'pending':
                  color = RtColors.warning;
                  icon = Icons.pending;
                  break;
                case 'expired':
                  color = RtColors.error;
                  icon = Icons.error;
                  break;
                case 'rejected':
                  color = RtColors.error;
                  icon = Icons.cancel;
                  break;
                case 'missing':
                  color = RtColors.neutral500;
                  icon = Icons.cloud_off;
                  break;
                default:
                  color = RtColors.neutral500;
                  icon = Icons.help;
              }
              
              return Padding(
                padding: EdgeInsets.only(right: 8),
                child: Tooltip(
                  message: '${doc.type}: ${doc.status}',
                  child: Icon(icon, size: 20, color: color),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
  
  Color _getStatusColor(DriverStatus status) {
    switch (status) {
      case DriverStatus.active:
        return RtColors.success;
      case DriverStatus.inactive:
        return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54);
      case DriverStatus.pending:
        return RtColors.warning;
      case DriverStatus.suspended:
        return RtColors.error;
    }
  }
  
  String _formatLastTrip(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else {
      return '${difference.inDays}d';
    }
  }
  
  void _showDriverDetails(Driver driver) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DriverDetailsModal(driver: driver),
    );
  }
  
  void _showDriverOptions(Driver driver) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit),
              title: Text('Editar información'),
              onTap: () {
                Navigator.pop(context);
                _editDriver(driver);
              },
            ),
            ListTile(
              leading: Icon(Icons.history),
              title: Text('Ver historial'),
              onTap: () {
                Navigator.pop(context);
                _showDriverHistory(driver);
              },
            ),
            ListTile(
              leading: Icon(Icons.message),
              title: Text('Enviar mensaje'),
              onTap: () {
                Navigator.pop(context);
                _sendMessage(driver);
              },
            ),
            // ✅ OPCIÓN PARA PRUEBAS: Resetear a pendiente
            ListTile(
              leading: Icon(Icons.restart_alt, color: RtColors.warning),
              title: Text('Resetear a pendiente'),
              subtitle: Text('Para pruebas de aprobación'),
              onTap: () {
                Navigator.pop(context);
                _resetToPending(driver);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: RtColors.error),
              title: Text('Eliminar conductor', style: TextStyle(color: RtColors.error)),
              onTap: () {
                Navigator.pop(context);
                _deleteDriver(driver);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ✅ NUEVO: Resetear conductor a estado pendiente (para pruebas)
  Future<void> _resetToPending(Driver driver) async {
    try {
      // Actualizar colección 'users'
      await _firestore.collection('users').doc(driver.id).update({
        'isVerified': false,
        'driverStatus': 'pending_approval',
        'documentVerified': false,
        'approvedAt': FieldValue.delete(),
        'approvedBy': FieldValue.delete(),
      });

      // Actualizar colección 'drivers' si existe
      await _firestore.collection('drivers').doc(driver.id).set({
        'isVerified': false,
        'verificationStatus': 'pending',
        'isActive': false,
      }, SetOptions(merge: true));

      debugPrint('✅ Conductor ${driver.name} reseteado a pendiente');

      if (!mounted) return;
      RtSnackbar.show(context, message: 'Conductor reseteado a pendiente', type: RtSnackbarType.success);

      _loadDriversFromFirebase();
    } catch (e) {
      debugPrint('Error reseteando: $e');
      if (!mounted) return;
      RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
    }
  }

  // Aprobar conductor con todos los campos necesarios
  // ✅ FIX 2026-01-05: Actualizar AMBAS colecciones (users Y drivers)
  Future<void> _approveDriver(Driver driver) async {
    try {
      // 1. Actualizar colección 'users' - datos principales del usuario
      await _firestore.collection('users').doc(driver.id).update({
        'status': 'active',
        'isActive': true,
        'isVerified': true,
        'documentVerified': true,
        'driverStatus': 'approved',
        'userType': 'dual', // Permitir usar app como conductor Y pasajero
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': 'admin',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. ✅ FIX: Actualizar colección 'drivers' - DocumentProvider lee de aquí
      await _firestore.collection('drivers').doc(driver.id).set({
        'isVerified': true,
        'verificationStatus': 'approved',
        'verificationDate': FieldValue.serverTimestamp(),
        'isActive': true,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': 'admin',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ Conductor ${driver.name} aprobado en users Y drivers');

      // Actualizar localmente
      if (!mounted) return;
      setState(() {
        driver.status = DriverStatus.active;
      });

      if (!mounted) return;
      RtSnackbar.show(context, message: 'Conductor ${driver.name} aprobado exitosamente', type: RtSnackbarType.success);

      _loadDriversFromFirebase();
    } catch (e) {
      if (!mounted) return;
      RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
    }
  }
  
  // ✅ IMPLEMENTADO: Rechazar conductor con actualización a Firebase
  void _rejectDriver(Driver driver) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Rechazar Conductor'),
        content: TextField(
          controller: reasonController,
          decoration: InputDecoration(
            labelText: 'Motivo del rechazo',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          maxLines: 3,
        ),
        actions: [
          RtButton(
            label: 'Cancelar',
            variant: RtButtonVariant.ghost,
            isFullWidth: false,
            onPressed: () => Navigator.pop(context),
          ),
          RtButton(
            label: 'Rechazar',
            variant: RtButtonVariant.danger,
            isFullWidth: false,
            onPressed: () async {
              final reason = reasonController.text.trim();
              Navigator.of(context).pop();

              try {
                await _firestore.collection('users').doc(driver.id).update({
                  'status': 'inactive',
                  'driverStatus': 'rejected',
                  'rejectionReason': reason.isEmpty ? 'No especificado' : reason,
                  'rejectedAt': FieldValue.serverTimestamp(),
                  'rejectedBy': 'admin',
                });

                if (!mounted) return;

                setState(() {
                  driver.status = DriverStatus.inactive;
                });

                RtSnackbar.show(this.context, message: 'Conductor rechazado', type: RtSnackbarType.error);

                _loadDriversFromFirebase();
              } catch (e) {
                if (!mounted) return;

                RtSnackbar.show(this.context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
              }
            },
          ),
        ],
      ),
    );
  }
  
  void _suspendDriver(Driver driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Suspender Conductor'),
        content: Text('¿Estás seguro de que deseas suspender a este conductor?'),
        actions: [
          RtButton(
            label: 'Cancelar',
            variant: RtButtonVariant.ghost,
            isFullWidth: false,
            onPressed: () => Navigator.pop(context),
          ),
          RtButton(
            label: 'Suspender',
            isFullWidth: false,
            onPressed: () async {
              Navigator.of(context).pop();

              try {
                await _firestore.collection('users').doc(driver.id).update({
                  'isSuspended': true,
                  'isActive': false,
                  'suspendedAt': FieldValue.serverTimestamp(),
                });

                if (!mounted) return;

                RtSnackbar.show(this.context, message: 'Conductor suspendido correctamente', type: RtSnackbarType.warning);

                _loadDriversFromFirebase();
              } catch (e) {
                if (!mounted) return;
                RtSnackbar.show(this.context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
              }
            },
          ),
        ],
      ),
    );
  }
  
  void _activateDriver(Driver driver) async {
    try {
      await _firestore.collection('users').doc(driver.id).update({
        'isSuspended': false,
        'isActive': true,
        'isVerified': true,
        'activatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      RtSnackbar.show(context, message: 'Conductor activado correctamente', type: RtSnackbarType.success);

      _loadDriversFromFirebase();
    } catch (e) {
      if (!mounted) return;
      RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
    }
  }
  
  // ✅ IMPLEMENTADO: Editar conductor
  void _editDriver(Driver driver) {
    final TextEditingController nameController = TextEditingController(text: driver.name);
    final TextEditingController emailController = TextEditingController(text: driver.email);
    final TextEditingController phoneController = TextEditingController(text: driver.phone);
    final TextEditingController licenseController = TextEditingController(text: driver.license);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Editar Conductor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nombre completo',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: 'Teléfono',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 12),
              TextField(
                controller: licenseController,
                decoration: InputDecoration(
                  labelText: 'Licencia',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.badge),
                ),
              ),
            ],
          ),
        ),
        actions: [
          RtButton(
            label: 'Cancelar',
            variant: RtButtonVariant.ghost,
            isFullWidth: false,
            onPressed: () => Navigator.pop(context),
          ),
          RtButton(
            label: 'Guardar',
            isFullWidth: false,
            onPressed: () async {
              final name = nameController.text.trim();
              final email = emailController.text.trim();
              final phone = phoneController.text.trim();
              final license = licenseController.text.trim();

              if (name.isEmpty || email.isEmpty || phone.isEmpty) {
                RtSnackbar.show(context, message: 'Por favor completa todos los campos obligatorios', type: RtSnackbarType.error);
                return;
              }

              Navigator.of(context).pop();

              try {
                await _firestore.collection('users').doc(driver.id).update({
                  'fullName': name,
                  'email': email,
                  'phone': phone,
                  'license': license,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                if (!mounted) return;

                RtSnackbar.show(this.context, message: 'Conductor actualizado exitosamente', type: RtSnackbarType.success);

                _loadDriversFromFirebase();
              } catch (e) {
                if (!mounted) return;

                RtSnackbar.show(this.context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
              }
            },
          ),
        ],
      ),
    );
  }

  // ✅ IMPLEMENTADO: Mostrar historial de viajes del conductor
  Future<void> _showDriverHistory(Driver driver) async {
    try {
      // ✅ CORREGIDO: Obtener viajes del conductor desde Firebase (rides)
      final tripsSnapshot = await _firestore
          .collection('rides')
          .where('driverId', isEqualTo: driver.id)
          .orderBy('requestedAt', descending: true)
          .limit(50)
          .get();

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: RtColors.brand,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.history, color: Theme.of(context).colorScheme.onPrimary),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Historial de ${driver.name}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onPrimary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                if (tripsSnapshot.docs.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
                          SizedBox(height: 16),
                          Text(
                            'No hay viajes registrados',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      controller: controller,
                      itemCount: tripsSnapshot.docs.length,
                      itemBuilder: (context, index) {
                        final tripData = tripsSnapshot.docs[index].data();
                        final tripDate = (tripData['requestedAt'] as Timestamp).toDate();
                        final fare = (tripData['finalFare'] ?? tripData['estimatedFare'] ?? 0.0).toDouble();
                        final status = tripData['status'] ?? 'unknown';

                        return Card(
                          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getTripStatusColor(status),
                              child: Icon(
                                _getTripStatusIcon(status),
                                color: Theme.of(context).colorScheme.onPrimary,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              '${tripData['pickupAddress'] ?? 'Origen'} → ${tripData['destinationAddress'] ?? 'Destino'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${tripDate.day}/${tripDate.month}/${tripDate.year} - ${tripDate.hour}:${tripDate.minute.toString().padLeft(2, '0')}',
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'S/. ${fare.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: RtColors.brand,
                                  ),
                                ),
                                Text(
                                  _getTripStatusLabel(status),
                                  style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
      }
    }
  }

  // Helpers para el historial de viajes
  Color _getTripStatusColor(String status) {
    switch (status) {
      case 'completed':
        return RtColors.success;
      case 'cancelled':
        return RtColors.error;
      case 'in_progress':
        return RtColors.info;
      default:
        return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54);
    }
  }

  IconData _getTripStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      case 'in_progress':
        return Icons.access_time;
      default:
        return Icons.help_outline;
    }
  }

  String _getTripStatusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'Completado';
      case 'cancelled':
        return 'Cancelado';
      case 'in_progress':
        return 'En progreso';
      default:
        return 'Desconocido';
    }
  }
  
  // ✅ IMPLEMENTADO: Enviar mensaje al conductor
  void _sendMessage(Driver driver) {
    final TextEditingController messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.message, color: RtColors.brand),
            SizedBox(width: 12),
            Text('Enviar Mensaje'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Para: ${driver.name}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 16),
            TextField(
              controller: messageController,
              decoration: InputDecoration(
                labelText: 'Mensaje',
                hintText: 'Escribe tu mensaje aquí...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: Icon(Icons.edit),
              ),
              maxLines: 5,
              maxLength: 500,
            ),
          ],
        ),
        actions: [
          RtButton(
            label: 'Cancelar',
            variant: RtButtonVariant.ghost,
            isFullWidth: false,
            onPressed: () => Navigator.pop(context),
          ),
          RtButton(
            label: 'Enviar',
            isFullWidth: false,
            onPressed: () async {
              final message = messageController.text.trim();
              final navigator = Navigator.of(context);

              if (message.isEmpty) {
                RtSnackbar.show(context, message: 'Por favor escribe un mensaje', type: RtSnackbarType.error);
                return;
              }

              navigator.pop();

              try {
                // Crear notificación en Firebase
                await _firestore.collection('notifications').add({
                  'userId': driver.id,
                  'title': 'Mensaje del Administrador',
                  'message': message,
                  'type': 'admin_message',
                  'isRead': false,
                  'createdAt': FieldValue.serverTimestamp(),
                  'sentBy': 'admin',
                });

                if (!mounted) return;

                RtSnackbar.show(this.context, message: 'Mensaje enviado a ${driver.name}', type: RtSnackbarType.success);
              } catch (e) {
                if (!mounted) return;

                RtSnackbar.show(this.context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
              }
            },
          ),
        ],
      ),
    );
  }
  
  void _deleteDriver(Driver driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Eliminar Conductor'),
        content: Text('Esta acción no se puede deshacer. ¿Estás seguro?'),
        actions: [
          RtButton(
            label: 'Cancelar',
            variant: RtButtonVariant.ghost,
            isFullWidth: false,
            onPressed: () => Navigator.pop(context),
          ),
          RtButton(
            label: 'Eliminar',
            variant: RtButtonVariant.danger,
            isFullWidth: false,
            onPressed: () async {
              Navigator.of(context).pop();

              try {
                // Eliminar de Firebase
                await _firestore.collection('users').doc(driver.id).delete();

                // También eliminar el vehículo asociado si existe
                final vehicleSnapshot = await _firestore
                    .collection('vehicles')
                    .where('driverId', isEqualTo: driver.id)
                    .get();

                for (var doc in vehicleSnapshot.docs) {
                  await doc.reference.delete();
                }

                if (!mounted) return;

                RtSnackbar.show(this.context, message: 'Conductor eliminado correctamente', type: RtSnackbarType.warning);

                // Recargar conductores
                _loadDriversFromFirebase();
              } catch (e) {
                if (!mounted) return;
                RtSnackbar.show(this.context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
              }
            },
          ),
        ],
      ),
    );
  }
  
  // ✅ IMPLEMENTADO: Agregar nuevo conductor
  void _addNewDriver() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController licenseController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Agregar Nuevo Conductor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nombre completo *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: 'Teléfono *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 12),
              TextField(
                controller: licenseController,
                decoration: InputDecoration(
                  labelText: 'Licencia *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.badge),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: 'Contraseña *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          RtButton(
            label: 'Cancelar',
            variant: RtButtonVariant.ghost,
            isFullWidth: false,
            onPressed: () => Navigator.pop(context),
          ),
          RtButton(
            label: 'Agregar',
            isFullWidth: false,
            onPressed: () async {
              final name = nameController.text.trim();
              final email = emailController.text.trim();
              final phone = phoneController.text.trim();
              final license = licenseController.text.trim();
              final password = passwordController.text.trim();
              final navigator = Navigator.of(context);

              if (name.isEmpty || email.isEmpty || phone.isEmpty || license.isEmpty || password.isEmpty) {
                RtSnackbar.show(context, message: 'Por favor completa todos los campos', type: RtSnackbarType.error);
                return;
              }

              if (password.length < 6) {
                RtSnackbar.show(context, message: 'La contraseña debe tener al menos 6 caracteres', type: RtSnackbarType.error);
                return;
              }

              navigator.pop();

              try {
                // 1. Crear usuario en Firebase Auth
                // NOTA: Esto cerrará la sesión del admin actual (limitación de Firebase Auth)
                // En producción, esto debería hacerse mediante Cloud Functions
                final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                  email: email,
                  password: password,
                );

                final newUserId = userCredential.user!.uid;

                // 2. Crear documento en Firestore con el UID de Auth
                await _firestore.collection('users').doc(newUserId).set({
                  'id': newUserId,
                  'fullName': name,
                  'email': email,
                  'phone': phone,
                  'license': license,
                  'userType': 'driver',
                  'role': 'driver',
                  'status': 'active',
                  'driverStatus': 'pending_approval',
                  'isActive': true,
                  'isVerified': false,
                  'emailVerified': false,
                  'phoneVerified': false,
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                  'rating': 5.0,
                  'totalTrips': 0,
                  'totalEarnings': 0.0,
                  'balance': 0.0,
                  'currentMode': 'driver',
                });

                // 3. Crear documento en colección drivers también
                await _firestore.collection('drivers').doc(newUserId).set({
                  'userId': newUserId,
                  'email': email,
                  'fullName': name,
                  'phone': phone,
                  'license': license,
                  'isVerified': false,
                  'verificationStatus': 'pending',
                  'isActive': true,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                // 4. Cerrar sesión del nuevo usuario y restaurar el admin
                await FirebaseAuth.instance.signOut();

                // 5. Re-autenticar como admin (el admin deberá volver a iniciar sesión)
                // Nota: En producción usar Cloud Functions para evitar esto

                if (!mounted) return;

                RtSnackbar.show(this.context, message: 'Conductor creado: $email. Nota: Debes volver a iniciar sesión como admin', type: RtSnackbarType.success);

                // Recargar lista
                _loadDriversFromFirebase();
              } on FirebaseAuthException catch (e) {
                if (!mounted) return;

                String errorMsg = 'Error al crear conductor';
                if (e.code == 'email-already-in-use') {
                  errorMsg = 'El email ya está registrado';
                } else if (e.code == 'invalid-email') {
                  errorMsg = 'Email inválido';
                } else if (e.code == 'weak-password') {
                  errorMsg = 'La contraseña es muy débil';
                }

                RtSnackbar.show(this.context, message: errorMsg, type: RtSnackbarType.error);
              } catch (e) {
                if (!mounted) return;

                RtSnackbar.show(this.context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
              }
            },
          ),
        ],
      ),
    );
  }

  // ✅ IMPLEMENTADO: Filtros avanzados para conductores
  void _showFilterDialog() {
    double minRating = 0.0;
    double maxRating = 5.0;
    int minTrips = 0;
    int maxTrips = 1000;
    bool onlyAvailable = false;
    bool onlyVerified = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.filter_list, color: RtColors.brand),
              SizedBox(width: 12),
              Text('Filtros Avanzados'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rating mínimo: ${minRating.toStringAsFixed(1)} ⭐',
                  style: TextStyle(fontWeight: FontWeight.bold)),
                Slider(
                  value: minRating,
                  min: 0.0,
                  max: 5.0,
                  divisions: 50,
                  label: minRating.toStringAsFixed(1),
                  onChanged: (value) {
                    setDialogState(() {
                      minRating = value;
                      if (minRating > maxRating) maxRating = minRating;
                    });
                  },
                ),
                SizedBox(height: 16),
                Text('Viajes mínimos: $minTrips',
                  style: TextStyle(fontWeight: FontWeight.bold)),
                Slider(
                  value: minTrips.toDouble(),
                  min: 0,
                  max: 1000,
                  divisions: 100,
                  label: minTrips.toString(),
                  onChanged: (value) {
                    setDialogState(() {
                      minTrips = value.toInt();
                      if (minTrips > maxTrips) maxTrips = minTrips;
                    });
                  },
                ),
                SizedBox(height: 16),
                CheckboxListTile(
                  title: Text('Solo disponibles'),
                  subtitle: Text('Mostrar solo conductores actualmente disponibles'),
                  value: onlyAvailable,
                  onChanged: (value) {
                    setDialogState(() => onlyAvailable = value ?? false);
                  },
                  activeColor: RtColors.brand,
                ),
                CheckboxListTile(
                  title: Text('Solo verificados'),
                  subtitle: Text('Mostrar solo conductores con documentos verificados'),
                  value: onlyVerified,
                  onChanged: (value) {
                    setDialogState(() => onlyVerified = value ?? false);
                  },
                  activeColor: RtColors.brand,
                ),
              ],
            ),
          ),
          actions: [
            RtButton(
              label: 'Limpiar',
              variant: RtButtonVariant.ghost,
              isFullWidth: false,
              onPressed: () {
                Navigator.pop(context);
                // Resetear filtros - recargar todos los conductores
                _loadDriversFromFirebase();
              },
            ),
            RtButton(
              label: 'Aplicar',
              isFullWidth: false,
              onPressed: () {
                Navigator.pop(context);
                // Aplicar filtros
                final List<Driver> filtered = _drivers.where((driver) {
                  bool meetsRating = driver.rating >= minRating;
                  bool meetsTrips = driver.totalTrips >= minTrips;
                  bool meetsAvailability = !onlyAvailable; // Nota: Driver no tiene isAvailable, usar estado
                  bool meetsVerification = !onlyVerified || (driver.status == DriverStatus.active);

                  return meetsRating && meetsTrips && meetsAvailability && meetsVerification;
                }).toList();

                setState(() {
                  _drivers = filtered;
                });

                RtSnackbar.show(this.context, message: 'Filtros aplicados: ${filtered.length} conductores', type: RtSnackbarType.success);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ✅ IMPLEMENTADO: Exportar datos de conductores a CSV
  Future<void> _exportData() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Exportando datos...'),
            ],
          ),
        ),
      );

      // Preparar datos CSV
      final List<List<dynamic>> csvData = [
        ['ID', 'Nombre', 'Email', 'Teléfono', 'Licencia', 'Estado', 'Rating', 'Viajes', 'Fecha Registro'],
        ..._drivers.map((driver) => [
              driver.id,
              driver.name,
              driver.email,
              driver.phone,
              driver.license,
              driver.status.toString().split('.').last,
              driver.rating,
              driver.totalTrips, // ✅ CORREGIDO: usar totalTrips en vez de trips
              driver.joinDate,
            ]),
      ];

      final csvString = const ListToCsvConverter().convert(csvData);
      final output = await getTemporaryDirectory();
      final now = DateTime.now();
      final file = File('${output.path}/conductores_${now.millisecondsSinceEpoch}.csv');
      await file.writeAsBytes(csvString.codeUnits);

      if (!mounted) return;

      Navigator.pop(context); // Cerrar diálogo de progreso

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Listado de Conductores - RapiTeam',
      );

      if (!mounted) return;

      RtSnackbar.show(context, message: 'Datos exportados exitosamente', type: RtSnackbarType.success);
    } catch (e) {
      if (!mounted) return;

      Navigator.pop(context); // Cerrar diálogo si hay error

      if (!mounted) return;

      RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
    }
  }
}

// Modal de detalles del conductor
class DriverDetailsModal extends StatefulWidget {
  final Driver driver;

  const DriverDetailsModal({super.key, required this.driver});

  @override
  State<DriverDetailsModal> createState() => _DriverDetailsModalState();
}

class _DriverDetailsModalState extends State<DriverDetailsModal> {
  Driver get driver => widget.driver;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: RtGradients.brand,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: NetworkImage(driver.photo),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver.name,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        driver.email,
                        style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.70)),
                      ),
                      Text(
                        driver.phone,
                        style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.70)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Información del vehículo
                  _buildSection(
                    'Vehículo',
                    Icons.directions_car,
                    [
                      _buildInfoRow('Marca', driver.vehicle.brand.toUpperCase()),
                      _buildInfoRow('Modelo', driver.vehicle.model.toUpperCase()),
                      _buildInfoRow('Año', driver.vehicle.year.toString()),
                      _buildInfoRow('Placa', driver.vehicle.plate.toUpperCase()),
                      _buildInfoRow('Color', driver.vehicle.color.toUpperCase()),
                    ],
                  ),
                  
                  SizedBox(height: 20),
                  
                  // Documentos
                  _buildSection(
                    'Documentos',
                    Icons.description,
                    driver.documents.map((doc) {
                      return _buildDocumentRow(doc);
                    }).toList(),
                  ),
                  
                  SizedBox(height: 20),
                  
                  // Estadísticas
                  _buildSection(
                    'Estadísticas',
                    Icons.bar_chart,
                    [
                      _buildInfoRow('Calificación', '${driver.rating} ⭐'),
                      _buildInfoRow('Viajes totales', driver.totalTrips.toString()),
                      _buildInfoRow('Ganancias', 'S/. ${driver.earnings.toStringAsFixed(2)}'),
                      _buildInfoRow('Comisión', 'S/. ${driver.commission.toStringAsFixed(2)}'),
                      _buildInfoRow('Fecha de registro', 
                        '${driver.joinDate.day}/${driver.joinDate.month}/${driver.joinDate.year}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: RtColors.brand),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: RtColors.neutral50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: RtColors.neutral500)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
  
  Widget _buildDocumentRow(Document doc) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (doc.status) {
      case 'verified':
      case 'approved':  // ✅ FIX: También aceptar 'approved'
        statusColor = RtColors.success;
        statusText = 'Aprobado';
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = RtColors.warning;
        statusText = 'Pendiente';
        statusIcon = Icons.hourglass_empty;
        break;
      case 'expired':
        statusColor = RtColors.error;
        statusText = 'Expirado';
        statusIcon = Icons.timer_off;
        break;
      case 'rejected':
        statusColor = RtColors.error;
        statusText = 'Rechazado';
        statusIcon = Icons.cancel;
        break;
      case 'missing':
        statusColor = RtColors.neutral500;
        statusText = 'No subido';
        statusIcon = Icons.cloud_off;
        break;
      default:
        statusColor = RtColors.neutral500;
        statusText = 'Desconocido';
        statusIcon = Icons.help_outline;
    }

    final hasUrl = doc.url != null && doc.url!.isNotEmpty;

    // 🔍 DEBUG: Log en momento de renderizar
    debugPrint('🖼️ RENDER DOC: ${doc.type} - status: ${doc.status} - hasUrl: $hasUrl - url: ${doc.url?.substring(0, (doc.url?.length ?? 0) > 50 ? 50 : (doc.url?.length ?? 0))}');

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(statusIcon, size: 18, color: statusColor),
          SizedBox(width: 8),
          Expanded(
            child: Text(doc.type, style: TextStyle(fontSize: 13)),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 8),
          // ✅ Botón para ver documento
          if (hasUrl)
            IconButton(
              icon: Icon(Icons.visibility, color: RtColors.info, size: 20),
              tooltip: 'Ver documento',
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => _showDocumentViewer(doc),
            )
          else
            Icon(Icons.visibility_off, color: Colors.grey.shade300, size: 20),
        ],
      ),
    );
  }

  // ✅ NUEVO: Mostrar visor de documento
  void _showDocumentViewer(Document doc) {
    if (doc.url == null || doc.url!.isEmpty) return;

    final isPdf = doc.url!.toLowerCase().contains('.pdf');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // Cabecera
              Row(
                children: [
                  Icon(isPdf ? Icons.picture_as_pdf : Icons.image, color: RtColors.info),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      doc.type,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Divider(),
              // Contenido
              Expanded(
                child: isPdf
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.picture_as_pdf, size: 80, color: Colors.red),
                            SizedBox(height: 16),
                            Text('Documento PDF', style: TextStyle(fontSize: 16)),
                            SizedBox(height: 8),
                            RtButton(
                              label: 'Abrir en navegador',
                              icon: Icons.open_in_new,
                              isFullWidth: false,
                              onPressed: () async {
                                final url = Uri.parse(doc.url!);
                                try {
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(url, mode: LaunchMode.externalApplication);
                                  } else {
                                    if (context.mounted) {
                                      RtSnackbar.show(context, message: 'No se pudo abrir el documento', type: RtSnackbarType.error);
                                    }
                                  }
                                } catch (e) {
                                  debugPrint('Error abriendo PDF: $e');
                                  if (context.mounted) {
                                    RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: InteractiveViewer(
                          panEnabled: true,
                          minScale: 0.5,
                          maxScale: 4,
                          child: Image.network(
                            doc.url!,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image, size: 60, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text('Error al cargar imagen'),
                                    SizedBox(height: 8),
                                    Text(
                                      doc.url!,
                                      style: TextStyle(fontSize: 10, color: Colors.grey),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              );
                            },
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
}

// Modelos
enum DriverStatus { active, inactive, pending, suspended }

class Driver {
  String id;
  String name;
  String email;
  String phone;
  String photo;
  String license; // ✅ AGREGADO: campo license
  DriverStatus status;
  double rating;
  int totalTrips;
  DateTime joinDate;
  Vehicle vehicle;
  List<Document> documents;
  double earnings;
  double commission;
  DateTime? lastTrip;

  // ✅ Alias para compatibilidad
  int get trips => totalTrips;

  Driver({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.photo,
    required this.license,
    required this.status,
    required this.rating,
    required this.totalTrips,
    required this.joinDate,
    required this.vehicle,
    required this.documents,
    required this.earnings,
    required this.commission,
    this.lastTrip,
  });
}

class Vehicle {
  String brand;
  String model;
  int year;
  String plate;
  String color;
  
  Vehicle({
    required this.brand,
    required this.model,
    required this.year,
    required this.plate,
    required this.color,
  });
}

class Document {
  String type;
  String status;
  DateTime? expiry;
  String? url; // URL del documento en Firebase Storage

  Document({
    required this.type,
    required this.status,
    this.expiry,
    this.url,
  });
}