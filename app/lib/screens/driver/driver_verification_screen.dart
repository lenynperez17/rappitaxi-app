// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart'; // ✅ Extensión para colores que se adaptan al tema
import '../../widgets/common/rappi_app_bar.dart';
import '../../providers/ride_provider.dart';
import '../../models/trip_model.dart';
import '../../widgets/verification_code_widget.dart'; // ✅ NUEVO: Widget de verificación mutua

/// Pantalla de verificación mutua para conductores
/// Muestra el código del conductor y permite ingresar el código del pasajero
class DriverVerificationScreen extends StatefulWidget {
  final TripModel trip;

  const DriverVerificationScreen({
    super.key,
    required this.trip,
  });

  @override
  _DriverVerificationScreenState createState() => _DriverVerificationScreenState();
}

class _DriverVerificationScreenState extends State<DriverVerificationScreen> {
  // ✅ Flag para prevenir operaciones después de dispose
  bool _isDisposed = false;
  // ✅ Guardar referencia al provider para poder remover listener
  RideProvider? _rideProvider;

  @override
  void initState() {
    super.initState();

    // Listener para detectar cuando la verificación mutua esté completa
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
    // ✅ Remover listener para evitar memory leaks
    _rideProvider?.removeListener(_onTripStatusChanged);
    super.dispose();
  }

  void _onTripStatusChanged() {
    if (_isDisposed || !mounted) return;

    final rideProvider = Provider.of<RideProvider>(context, listen: false);
    final currentTrip = rideProvider.currentTrip;

    if (currentTrip != null && currentTrip.id == widget.trip.id) {
      // ✅ Si la verificación mutua está completa, viaje iniciado
      if (currentTrip.status == 'in_progress' && currentTrip.isMutualVerificationComplete) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Verificación mutua completada! El viaje ha comenzado.'),
            backgroundColor: ModernTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceColor,
      appBar: RappiAppBar(
        title: 'Verificación Mutua',
        showBackButton: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Información del pasajero
              _buildPassengerInfo(),

              const SizedBox(height: 24),

              // UI: Instrucciones paso a paso visuales con números
              _buildStepByStepInstructions(),

              const SizedBox(height: 20),

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
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.getCardShadow(context),
      ),
      child: Row(
        children: [
          // Avatar del pasajero
          CircleAvatar(
            radius: 30,
            backgroundColor: ModernTheme.primaryBlue.withValues(alpha: 0.1),
            child: Icon(
              Icons.person,
              size: 32,
              color: ModernTheme.primaryBlue,
            ),
          ),
          SizedBox(width: 16),
          // Info del pasajero
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pasajero',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.primaryText,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: context.secondaryText),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.trip.pickupAddress,
                        style: TextStyle(
                          color: context.secondaryText,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.flag, size: 16, color: context.secondaryText),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.trip.destinationAddress,
                        style: TextStyle(
                          color: context.secondaryText,
                          fontSize: 14,
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ModernTheme.rappiOrange,
                ),
              ),
              Text(
                '${widget.trip.estimatedDistance.toStringAsFixed(1)} km',
                style: TextStyle(
                  color: context.secondaryText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // UI: Instrucciones paso a paso con numeros
  Widget _buildStepByStepInstructions() {
    final steps = [
      {'num': '1', 'title': 'Muestra tu codigo', 'desc': 'Ensenale al pasajero el codigo QR o el numero de 4 digitos'},
      {'num': '2', 'title': 'Pasajero confirma', 'desc': 'El pasajero escanea tu codigo o ingresa el numero'},
      {'num': '3', 'title': 'Tu confirmas', 'desc': 'Ingresa el codigo del pasajero para finalizar la verificacion'},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Como funciona',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: context.primaryText,
          ),
        ),
        const SizedBox(height: 12),
        ...steps.asMap().entries.map((entry) {
          final step = entry.value;
          final isLast = entry.key == steps.length - 1;
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Columna de numeros y linea conectora
                Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: ModernTheme.rappiOrange,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          step['num']!,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: ModernTheme.rappiOrange.withValues(alpha: 0.25),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                // Texto del paso
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text(step['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(step['desc']!, style: TextStyle(fontSize: 12, color: context.secondaryText)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ✅ Métodos obsoletos eliminados - ahora usa VerificationCodeWidget
}