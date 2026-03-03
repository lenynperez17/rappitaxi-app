import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/design_system.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_badge.dart';
import '../../core/widgets/rt_button.dart';
import '../../core/widgets/rt_card.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../models/trip_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ride_provider.dart';
import '../../services/emergency_service.dart';
import '../../utils/firestore_error_handler.dart';
import '../../widgets/verification_code_widget.dart';

/// Pantalla de verificación mutua para pasajeros
/// Muestra el código del pasajero y permite ingresar el código del conductor
class TripVerificationCodeScreen extends StatefulWidget {
  final TripModel trip;

  const TripVerificationCodeScreen({
    super.key,
    required this.trip,
  });

  @override
  State<TripVerificationCodeScreen> createState() =>
      _TripVerificationCodeScreenState();
}

class _TripVerificationCodeScreenState extends State<TripVerificationCodeScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();

    // Listener para detectar cuando el código sea verificado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupTripListener();
    });

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _slideController = AnimationController(
      duration: RtDuration.emphasis,
      vsync: this,
    );

    _slideController.forward();
  }

  void _setupTripListener() {
    final rideProvider = Provider.of<RideProvider>(context, listen: false);
    rideProvider.addListener(_onTripStatusChanged);
  }

  void _onTripStatusChanged() {
    if (!mounted) return;

    final rideProvider = Provider.of<RideProvider>(context, listen: false);
    final currentTrip = rideProvider.currentTrip;

    if (currentTrip != null && currentTrip.id == widget.trip.id) {
      if (currentTrip.status == 'in_progress' &&
          currentTrip.isMutualVerificationComplete) {
        Navigator.pop(context);
        RtSnackbar.show(
          context,
          message: 'Verificación mutua completada! Tu viaje ha comenzado.',
          type: RtSnackbarType.success,
        );
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? RtColors.neutral950 : RtColors.neutral50,
      appBar: const RtAppBar(
        title: 'Verificación Mutua',
        variant: RtAppBarVariant.solid,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(RtSpacing.lg),
          child: Column(
            children: [
              // Información del conductor
              _buildDriverInfo(),

              const SizedBox(height: RtSpacing.lg),

              // Widget de verificación mutua completo
              VerificationCodeWidget(
                rideId: widget.trip.id,
                isDriver: false,
              ),

              const SizedBox(height: RtSpacing.lg),

              // Boton de emergencia
              _buildEmergencyButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDriverInfo() {
    return RtCard(
      variant: RtCardVariant.elevated,
      padding: const EdgeInsets.all(RtSpacing.lg),
      child: Row(
        children: [
          // Avatar del conductor
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: RtColors.brand.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              size: 32,
              color: RtColors.brand,
            ),
          ),
          const SizedBox(width: RtSpacing.base),

          // Info del conductor
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.trip.driverId ?? 'Conductor asignado',
                  style: RtTypo.headingSmall,
                ),
                const SizedBox(height: RtSpacing.xs),
                Row(
                  children: [
                    const Icon(
                      Icons.star,
                      size: RtIconSize.xs,
                      color: RtColors.warning,
                    ),
                    const SizedBox(width: RtSpacing.xs),
                    Text(
                      widget.trip.driverRating?.toStringAsFixed(1) ?? '5.0',
                      style: RtTypo.bodyMedium.copyWith(
                        color: RtColors.neutral500,
                      ),
                    ),
                    const SizedBox(width: RtSpacing.base),
                    Icon(
                      Icons.directions_car,
                      size: RtIconSize.xs,
                      color: RtColors.neutral500,
                    ),
                    const SizedBox(width: RtSpacing.xs),
                    Flexible(
                      child: Text(
                        widget.trip.vehicleInfo?['model'] ?? 'Vehículo',
                        style: RtTypo.bodyMedium.copyWith(
                          color: RtColors.neutral500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Estado
          RtBadge(
            label: 'En camino',
            color: RtColors.brand,
            variant: RtBadgeVariant.subtle,
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyButton() {
    return RtButton(
      label: 'Emergencia',
      icon: Icons.emergency,
      onPressed: _handleEmergencyPress,
      variant: RtButtonVariant.danger,
      size: RtButtonSize.large,
    );
  }

  void _showEmergencyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
        title: Row(
          children: [
            const Icon(Icons.emergency, color: RtColors.error),
            const SizedBox(width: RtSpacing.sm),
            Text('Emergencia', style: RtTypo.headingMedium),
          ],
        ),
        content: Text(
          'Necesitas ayuda de emergencia? Esto notificara a las autoridades y cancelara tu viaje.',
          style: RtTypo.bodyMedium.copyWith(color: RtColors.neutral600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: RtTypo.labelLarge.copyWith(color: RtColors.neutral600),
            ),
          ),
          RtButton(
            label: 'Llamar Emergencia',
            onPressed: _triggerRealEmergency,
            variant: RtButtonVariant.danger,
            size: RtButtonSize.small,
            isFullWidth: false,
          ),
        ],
      ),
    );
  }

  void _handleEmergencyPress() {
    _showEmergencyDialog();
  }

  /// Activar emergencia real con el EmergencyService
  Future<void> _triggerRealEmergency() async {
    Navigator.pop(context);

    // Mostrar loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: RtColors.error),
            const SizedBox(height: RtSpacing.base),
            Text(
              'Activando emergencia...',
              style: RtTypo.titleLarge.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: RtSpacing.sm),
            Text(
              'Notificando autoridades y contactos',
              style: RtTypo.bodyMedium.copyWith(color: RtColors.neutral500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    try {
      final emergencyService = EmergencyService();
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      final response = await emergencyService.triggerSOS(
        userId: currentUser?.id ?? '',
        userType: currentUser?.userType ?? 'passenger',
      );

      if (mounted) Navigator.pop(context);

      if (response.success) {
        _showEmergencySuccessDialog(response);
        debugPrint('SOS activado - Trip: ${widget.trip.id}');
      } else {
        _showEmergencyErrorDialog(response.message ?? 'Error desconocido');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint('Error activando SOS: $e');
      _showEmergencyErrorDialog(FirestoreErrorHandler.getSpanishMessage(e));
    }
  }

  /// Mostrar dialogo de éxito de emergencia
  void _showEmergencySuccessDialog(dynamic response) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: RtColors.success, size: 32),
            const SizedBox(width: RtSpacing.md),
            Text('SOS ACTIVADO', style: RtTypo.headingMedium),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Emergencia activada exitosamente', style: RtTypo.bodyMedium),
            const SizedBox(height: RtSpacing.sm),
            Text('Llamada de emergencia iniciada', style: RtTypo.bodyMedium),
            const SizedBox(height: RtSpacing.sm),
            Text(
              '${response.contactsNotified} contactos notificados',
              style: RtTypo.bodyMedium,
            ),
            const SizedBox(height: RtSpacing.sm),
            Text('Grabacion de audio iniciada', style: RtTypo.bodyMedium),
            const SizedBox(height: RtSpacing.sm),
            Text('Ubicación enviada a autoridades', style: RtTypo.bodyMedium),
            const SizedBox(height: RtSpacing.base),
            Container(
              padding: RtSpacing.paddingMd,
              decoration: BoxDecoration(
                color: RtColors.errorLight,
                borderRadius: RtRadius.borderSm,
                border: Border.all(color: RtColors.error),
              ),
              child: Text(
                'ID de Emergencia: ${response.emergencyId ?? 'N/A'}',
                style: RtTypo.labelMedium.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  color: RtColors.errorDark,
                ),
              ),
            ),
          ],
        ),
        actions: [
          RtButton(
            label: 'Entendido',
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/passenger/home',
                (route) => false,
              );
            },
            size: RtButtonSize.small,
            isFullWidth: false,
          ),
        ],
      ),
    );
  }

  /// Mostrar dialogo de error de emergencia
  void _showEmergencyErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
        title: Row(
          children: [
            const Icon(Icons.error, color: RtColors.warning, size: 32),
            const SizedBox(width: RtSpacing.md),
            Text('Error de Emergencia', style: RtTypo.headingMedium),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No se pudo activar completamente el SOS:',
              style: RtTypo.bodyMedium,
            ),
            const SizedBox(height: RtSpacing.sm),
            Text(
              errorMessage,
              style: RtTypo.bodySmall.copyWith(color: RtColors.error),
            ),
            const SizedBox(height: RtSpacing.base),
            Container(
              padding: RtSpacing.paddingMd,
              decoration: BoxDecoration(
                color: RtColors.warningLight,
                borderRadius: RtRadius.borderSm,
              ),
              child: Text(
                'RECOMENDACION: Llame directamente al 911 o 105',
                style: RtTypo.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: RtColors.warningDark,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cerrar',
              style: RtTypo.labelLarge.copyWith(color: RtColors.neutral600),
            ),
          ),
        ],
      ),
    );
  }
}
