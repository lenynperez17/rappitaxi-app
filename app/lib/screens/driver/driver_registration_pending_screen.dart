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
    // Si ya vienen datos como argumento, usarlos
    if (widget.applicationData != null) {
      setState(() {
        _applicationData = widget.applicationData;
        _isLoading = false;
      });
      _contentController.forward();
      return;
    }

    // Si no, cargar desde el backend Node.
    try {
      AppLogger.info('Cargando solicitud pendiente desde backend Node');

      // El perfil de driver ya contiene el workType/vehículo y su estado.
      final profile = await RapiApiClient.instance.myDriverProfile();

      if (!mounted) return;
      setState(() {
        _applicationData = profile;
        _isLoading = false;
      });
      _contentController.forward();
    } catch (e) {
      AppLogger.error(userFriendlyError(e, fallback: 'Error cargando solicitud pendiente'));
      if (mounted) {
        setState(() => _isLoading = false);
        _contentController.forward();
      }
    }
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
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
                        status: 'completed',
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
                          backgroundColor: AppColors.rappiRed,
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

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isCompleted
                ? Colors.green.shade50
                : isPending
                    ? Colors.amber.shade50
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
        else
          Icon(Icons.radio_button_unchecked, size: 20, color: Colors.grey.shade400),
      ],
    );
  }
}
