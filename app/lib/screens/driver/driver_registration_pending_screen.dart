// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/constants/app_colors.dart';
import '../../services/rapi_api_client.dart';
import '../../utils/logger.dart';
import '../../utils/error_messages.dart';

/// Pantalla 5: Espera de aprobación
class DriverRegistrationPendingScreen extends StatefulWidget {
  final Map<String, dynamic>? applicationData;

  const DriverRegistrationPendingScreen({
    super.key,
    this.applicationData,
  });

  @override
  State<DriverRegistrationPendingScreen> createState() => _DriverRegistrationPendingScreenState();
}

class _DriverRegistrationPendingScreenState extends State<DriverRegistrationPendingScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _applicationData;
  bool _isLoading = true;
  // Ronda 224 (138): distinguir "docs completos" de "docs subidos sin vehículo".
  // Sin este flag el user se queda mirando "solicitud enviada" para siempre
  // aunque falte el vehículo (el admin puede aprobar docs pero el auto-promote
  // a dual jamás dispara sin vehículo → catch-22).
  bool _missingVehicle = false;
  // Ronda 226: refresh en tiempo real cuando el admin apruebe/rechace un doc.
  // Escuchamos push FCM foreground + polling ligero cada 30s + pull-to-refresh.
  StreamSubscription<RemoteMessage>? _fcmSub;
  Timer? _pollTimer;

  late final AnimationController _rotationController;
  late final AnimationController _pulseController;
  late final AnimationController _contentController;

  @override
  void initState() {
    super.initState();

    // Rotacion continua para el icono de reloj de arena
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Pulso para el badge de tiempo estimado
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Controlador del contenido - se dispara cuando carga la data
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _loadApplicationData();

    // Ronda 226: escuchar push del backend cuando el admin revisa un doc
    // (types: document_review, driver_verified, vehicle_updated, admin_upload_document).
    // El backend ya envía sendPush() en /admin/documents/[id] PATCH; acá lo
    // consumimos para refrescar sin que el user tenga que salir y volver.
    _fcmSub = FirebaseMessaging.onMessage.listen((msg) {
      final type = msg.data['type']?.toString() ?? '';
      if (type == 'document_review' ||
          type == 'driver_verified' ||
          type == 'vehicle_updated' ||
          type == 'document_uploaded') {
        AppLogger.info('Push $type recibido → refrescando pending screen');
        _refresh();
      }
    });

    // Polling defensivo cada 30s (por si el push no llega — fcm token vencido,
    // silent mode, etc.). Se para automáticamente cuando la pantalla se cierra.
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _refresh(silent: true);
    });
  }

  @override
  void dispose() {
    _fcmSub?.cancel();
    _pollTimer?.cancel();
    _rotationController.dispose();
    _pulseController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  /// Refresh — usado por push FCM, polling y pull-to-refresh.
  /// silent=true evita el spinner central (para el polling en background).
  Future<void> _refresh({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => _isLoading = true);
    try {
      final api = RapiApiClient.instance;
      final vehicleResp = await api.myVehicle();
      final vehicle = vehicleResp['vehicle'];
      final missingBefore = _missingVehicle;
      _missingVehicle = vehicle == null;

      Map<String, dynamic>? newData;
      try {
        newData = await api.myDriverProfile();
      } catch (_) {
        newData = _applicationData;
      }

      // Si el admin ya aprobó todo y el user quedó como dual → salir a home driver.
      final userType = newData?['user']?['userType']?.toString() ??
          newData?['userType']?.toString();
      if (userType == 'dual' || userType == 'driver') {
        AppLogger.info('Auto-promoted a $userType — saliendo a driver home');
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/driver/home', (_) => false);
        }
        return;
      }

      if (!mounted) return;
      setState(() {
        _applicationData = newData ?? _applicationData;
        _isLoading = false;
      });
      // Si acaba de completarse el vehículo, mostrar snackbar de éxito.
      if (missingBefore && !_missingVehicle && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Vehículo registrado!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      AppLogger.info('refresh error: $e');
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  /// Helper para animacion staggered de secciones
  Widget _animatedSection(Widget child, int index) {
    final double start = (index * 0.12).clamp(0.0, 0.8);
    final double end = (start + 0.4).clamp(0.0, 1.0);
    final animation = CurvedAnimation(
      parent: _contentController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, 30 * (1 - animation.value)),
        child: Opacity(opacity: animation.value, child: child),
      ),
      child: child,
    );
  }

  /// Abre un diálogo inline para registrar el vehículo del driver.
  /// Ronda 225: antes hacíamos `pushNamedAndRemoveUntil('/driver/register')`
  /// que borraba toda la pila de navegación y arrancaba el wizard desde el
  /// paso 1 (cómo quieres trabajar). Peor: la flecha atrás quedaba sin
  /// ruta previa y mostraba pantalla negra. Ahora es un dialog en la misma
  /// pantalla: sin cambios de ruta, sin pantalla negra, sin reingresar datos.
  Future<void> _openVehicleDialog() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _VehicleFormDialog(),
    );
    if (saved == true && mounted) {
      setState(() {
        _missingVehicle = false;
        _isLoading = true;
      });
      await _loadApplicationData();
    }
  }

  /// Cargar datos de la solicitud (desde argumento o desde el backend Node)
  Future<void> _loadApplicationData() async {
    if (widget.applicationData != null) {
      _applicationData = widget.applicationData;
    }

    // Verificar si hay vehículo activo — sin él, aunque el admin apruebe todos
    // los docs, el user_type no pasará a dual y el user queda atrapado.
    try {
      final api = RapiApiClient.instance;
      final vehicleResp = await api.myVehicle();
      final vehicle = vehicleResp['vehicle'];
      _missingVehicle = vehicle == null;
      AppLogger.info('_missingVehicle=$_missingVehicle');
    } catch (e) {
      AppLogger.info('No se pudo verificar vehículo: $e');
      _missingVehicle = true;
    }

    if (_applicationData == null) {
      try {
        AppLogger.info('Cargando solicitud pendiente desde backend Node');
        final profile = await RapiApiClient.instance.myDriverProfile();
        _applicationData = profile;
      } catch (e) {
        AppLogger.info(userFriendlyError(e, fallback: 'myDriverProfile falló'));
        _applicationData = {'status': 'pending'};
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    _contentController.forward();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.getSurface(context),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.rappiRed),
        ),
      );
    }

    final workType = _applicationData?['workType'] ?? 'auto';
    String workTypeLabel;
    IconData workTypeIcon;

    switch (workType) {
      case 'moto':
        workTypeLabel = 'Mototaxi';
        workTypeIcon = Icons.two_wheeler_rounded;
        break;
      case 'courier':
        workTypeLabel = 'Repartidor';
        workTypeIcon = Icons.inventory_2_rounded;
        break;
      default:
        workTypeLabel = 'Conductor';
        workTypeIcon = Icons.directions_car_rounded;
    }

    return Scaffold(
      backgroundColor: AppColors.getSurface(context),
      // Ronda 221 BUG FIX: sin SingleChildScrollView el contenido de esta
      // pantalla (icono + título + subtítulo + badge + card de estado + botón
      // + link soporte) excedía la altura de iPhone SE/8/nuevos con notch →
      // el botón "Volver al inicio" quedaba fuera del viewport y NO se podía
      // scrollear (Column no scrollea). El user quedaba atrapado.
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.rappiRed,
          onRefresh: () => _refresh(),
          child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  64,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              // Icono animado de espera (index 0)
              _animatedSection(
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: RotationTransition(
                    turns: _rotationController,
                    child: Icon(
                      Icons.hourglass_top_rounded,
                      size: 64,
                      color: Colors.amber.shade600,
                    ),
                  ),
                ),
                0,
              ),

              const SizedBox(height: 32),

              // Título (index 1)
              _animatedSection(
                Text(
                  '¡Solicitud enviada!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                1,
              ),

              const SizedBox(height: 16),

              // Subtítulo (index 2)
              _animatedSection(
                Text(
                  'Estamos revisando tus documentos.\nTe notificaremos cuando tu cuenta\ncomo $workTypeLabel esté activa.',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.getTextSecondary(context),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                2,
              ),

              const SizedBox(height: 8),

              // Badge de tiempo estimado con pulso (index 3)
              _animatedSection(
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) => Transform.scale(
                    scale: 0.95 + (_pulseController.value * 0.10),
                    child: child,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 6),
                        Text(
                          'Tiempo estimado: 24-48 horas',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                3,
              ),

              const SizedBox(height: 40),

              // Estado de la solicitud (index 4)
              _animatedSection(
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.getInputFill(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.getBorder(context)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(workTypeIcon, color: AppColors.rappiRed),
                          const SizedBox(width: 12),
                          Text(
                            'Estado de tu solicitud',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextPrimary(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildStatusItem(
                        context,
                        icon: Icons.person,
                        label: 'Datos personales',
                        status: 'completed',
                      ),
                      const SizedBox(height: 12),
                      _buildStatusItem(
                        context,
                        icon: Icons.directions_car,
                        label: 'Información del vehículo',
                        status: _missingVehicle ? 'missing' : 'completed',
                      ),
                      const SizedBox(height: 12),
                      _buildStatusItem(
                        context,
                        icon: Icons.description,
                        label: 'Documentos',
                        status: 'pending',
                      ),
                    ],
                  ),
                ),
                4,
              ),

              const Spacer(),

              // Botón volver al inicio (index 5)
              _animatedSection(
                Column(
                  children: [
                    if (_missingVehicle) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.amber.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Falta registrar tu vehículo para completar la solicitud. Sin esto no podremos activar tu modo conductor.',
                                style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _openVehicleDialog(),
                          icon: const Icon(Icons.directions_car),
                          label: const Text('Registrar vehículo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/passenger/home',
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _missingVehicle ? Colors.grey.shade400 : AppColors.rappiRed,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Volver al inicio',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Link de soporte
                    TextButton.icon(
                      onPressed: () {
                        // Abrir soporte
                        Navigator.pushNamed(context, '/shared/help-center');
                      },
                      icon: Icon(
                        Icons.help_outline,
                        size: 18,
                        color: AppColors.rappiRed,
                      ),
                      label: Text(
                        '¿Tienes dudas? Contacta a soporte',
                        style: TextStyle(
                          color: AppColors.rappiRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                5,
              ),
            ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildStatusItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String status,
  }) {
    final isCompleted = status == 'completed';
    final isPending = status == 'pending';
    final isMissing = status == 'missing';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isCompleted
                ? Colors.green.shade50
                : isPending
                    ? Colors.amber.shade50
                    : isMissing
                        ? Colors.red.shade50
                        : Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 18,
            color: isCompleted
                ? Colors.green.shade600
                : isPending
                    ? Colors.amber.shade600
                    : isMissing
                        ? Colors.red.shade600
                        : Colors.grey.shade400,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.getTextPrimary(context),
            ),
          ),
        ),
        if (isCompleted)
          Icon(Icons.check_circle, size: 20, color: Colors.green.shade600)
        else if (isPending)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber.shade600),
            ),
          )
        else if (isMissing)
          Icon(Icons.error, size: 20, color: Colors.red.shade600)
        else
          Icon(Icons.radio_button_unchecked, size: 20, color: Colors.grey.shade400),
      ],
    );
  }
}

/// Dialog inline para registrar el vehículo del driver. Se abre desde
/// [DriverRegistrationPendingScreen] cuando falta el vehículo (usuarios
/// que enviaron solicitud con el build 136 que rompía upsertVehicle).
class _VehicleFormDialog extends StatefulWidget {
  const _VehicleFormDialog();

  @override
  State<_VehicleFormDialog> createState() => _VehicleFormDialogState();
}

class _VehicleFormDialogState extends State<_VehicleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _plateController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _colorController = TextEditingController();
  final _yearController = TextEditingController();
  String _vehicleType = 'car';
  bool _submitting = false;

  @override
  void dispose() {
    _plateController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await RapiApiClient.instance.upsertVehicle(
        vehicleType: _vehicleType,
        plate: _plateController.text.trim().toUpperCase(),
        make: _brandController.text.trim().isEmpty ? null : _brandController.text.trim(),
        model: _modelController.text.trim().isEmpty ? null : _modelController.text.trim(),
        color: _colorController.text.trim().isEmpty ? null : _colorController.text.trim(),
        year: int.tryParse(_yearController.text.trim()),
      );
      AppLogger.info('upsertVehicle OK desde dialog');
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      AppLogger.error(userFriendlyError(e, fallback: 'Error registrando vehículo'));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFriendlyError(e, fallback: 'Error registrando vehículo')),
          backgroundColor: AppColors.error,
        ),
      );
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.directions_car, color: AppColors.rappiRed),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Registrar vehículo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Completa los datos de tu vehículo para activar tu cuenta de conductor.',
                  style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(context)),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _vehicleType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de vehículo *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'car', child: Text('Auto')),
                    DropdownMenuItem(value: 'moto', child: Text('Moto')),
                    DropdownMenuItem(value: 'moto_taxi', child: Text('Mototaxi')),
                    DropdownMenuItem(value: 'van', child: Text('Van')),
                  ],
                  onChanged: _submitting ? null : (v) {
                    if (v != null) setState(() => _vehicleType = v);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _plateController,
                  enabled: !_submitting,
                  decoration: const InputDecoration(
                    labelText: 'Placa *',
                    hintText: 'ABC-123',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'La placa es obligatoria';
                    if (v.trim().length < 5) return 'Placa muy corta';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _brandController,
                        enabled: !_submitting,
                        decoration: const InputDecoration(
                          labelText: 'Marca',
                          hintText: 'Toyota',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _modelController,
                        enabled: !_submitting,
                        decoration: const InputDecoration(
                          labelText: 'Modelo',
                          hintText: 'Yaris',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _colorController,
                        enabled: !_submitting,
                        decoration: const InputDecoration(
                          labelText: 'Color',
                          hintText: 'Blanco',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _yearController,
                        enabled: !_submitting,
                        decoration: const InputDecoration(
                          labelText: 'Año',
                          hintText: '2020',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final n = int.tryParse(v.trim());
                          if (n == null) return 'Año inválido';
                          if (n < 1950 || n > DateTime.now().year + 1) return 'Fuera de rango';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.rappiRed,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Guardar vehículo',
                            style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
