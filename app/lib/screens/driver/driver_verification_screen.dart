import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design/design_system.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../providers/ride_provider.dart';
import '../../models/trip_model.dart';
import '../../widgets/verification_code_widget.dart';

/// Pantalla de verificación mutua para conductores
/// Muestra el código del conductor y permite ingresar el código del pasajero
class DriverVerificationScreen extends StatefulWidget {
  final TripModel trip;

  const DriverVerificationScreen({
    super.key,
    required this.trip,
  });

  @override
  State<DriverVerificationScreen> createState() => _DriverVerificationScreenState();
}

class _DriverVerificationScreenState extends State<DriverVerificationScreen> {
  // Flag para prevenir operaciones después de dispose
  bool _isDisposed = false;
  // Guardar referencia al provider para poder remover listener
  RideProvider? _rideProvider;

  @override
  void initState() {
    super.initState();

    // Listener para detectar cuando la verificación mutua este completa
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && mounted) {
        _setupTripListener();
      }
    });
  }

  void _setupTripListener() {
    _rideProvider = Provider.of<RideProvider>(context, listen: false);
    _rideProvider?.addListener(_onTripStatusChanged);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _rideProvider?.removeListener(_onTripStatusChanged);
    super.dispose();
  }

  void _onTripStatusChanged() {
    if (_isDisposed || !mounted) return;

    final rideProvider = Provider.of<RideProvider>(context, listen: false);
    final currentTrip = rideProvider.currentTrip;

    if (currentTrip != null && currentTrip.id == widget.trip.id) {
      // Si la verificación mutua esta completa, viaje iniciado
      if (currentTrip.status == 'in_progress' && currentTrip.isMutualVerificationComplete) {
        Navigator.pop(context);
        RtSnackbar.show(
          context,
          message: 'Verificación mutua completada! El viaje ha comenzado.',
          type: RtSnackbarType.success,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: const RtAppBar(
        title: 'Verificación Mutua',
        variant: RtAppBarVariant.solid,
        showBackButton: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(RtSpacing.lg),
          child: Column(
            children: [
              // Información del pasajero
              _buildPassengerInfo(),

              const SizedBox(height: RtSpacing.lg),

              // Widget de verificación mutua completo
              VerificationCodeWidget(
                rideId: widget.trip.id,
                isDriver: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPassengerInfo() {
    return Container(
      padding: const EdgeInsets.all(RtSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: RtRadius.borderLg,
        boxShadow: RtShadow.soft(),
      ),
      child: Row(
        children: [
          // Avatar del pasajero
          CircleAvatar(
            radius: 30,
            backgroundColor: RtColors.info.withValues(alpha: 0.1),
            child: const Icon(
              Icons.person,
              size: 32,
              color: RtColors.info,
            ),
          ),
          const SizedBox(width: RtSpacing.base),
          // Info del pasajero
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pasajero',
                  style: RtTypo.headingSmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: RtSpacing.xs),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: RtSpacing.xs),
                    Expanded(
                      child: Text(
                        widget.trip.pickupAddress,
                        style: RtTypo.bodySmall.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: RtSpacing.xs),
                Row(
                  children: [
                    Icon(
                      Icons.flag,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: RtSpacing.xs),
                    Expanded(
                      child: Text(
                        widget.trip.destinationAddress,
                        style: RtTypo.bodySmall.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
          // Tarifa
          Column(
            children: [
              Text(
                'S/. ${widget.trip.estimatedFare.toStringAsFixed(2)}',
                style: RtTypo.headingSmall.copyWith(
                  color: RtColors.brand,
                ),
              ),
              Text(
                '${widget.trip.estimatedDistance.toStringAsFixed(1)} km',
                style: RtTypo.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
