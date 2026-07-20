// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
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
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _contentController.dispose();
    super.dispose();
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
                          onPressed: () {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/driver/register',
                              (route) => false,
                            );
                          },
                          icon: const Icon(Icons.directions_car),
                          label: const Text('Completar registro del vehículo'),
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
