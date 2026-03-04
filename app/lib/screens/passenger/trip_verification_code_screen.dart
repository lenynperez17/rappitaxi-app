// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart'; // ✅ Extensión para colores que se adaptan al tema
import '../../widgets/common/rappi_app_bar.dart';
import '../../providers/ride_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/trip_model.dart';
import '../../services/emergency_service.dart';
import '../../widgets/verification_code_widget.dart'; // ✅ NUEVO: Widget de verificación mutua

/// Pantalla de verificación mutua para pasajeros
/// Muestra el código del pasajero y permite ingresar el código del conductor
class TripVerificationCodeScreen extends StatefulWidget {
  final TripModel trip;

  const TripVerificationCodeScreen({
    super.key,
    required this.trip,
  });

  @override
  _TripVerificationCodeScreenState createState() => _TripVerificationCodeScreenState();
}

class _TripVerificationCodeScreenState extends State<TripVerificationCodeScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  // ✅ FIX MEMORY LEAK: Guardar referencia al provider y listener
  RideProvider? _rideProvider;
  bool _listenerSetup = false;

  @override
  void initState() {
    super.initState();
    
    // Listener para detectar cuando el código sea verificado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupTripListener();
    });
    
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _slideController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _slideController.forward();
  }
  
  void _setupTripListener() {
    // ✅ FIX MEMORY LEAK: Guardar referencia para poder remover en dispose
    if (_listenerSetup) return; // Evitar setup múltiple
    _rideProvider = Provider.of<RideProvider>(context, listen: false);
    _rideProvider?.addListener(_onTripStatusChanged);
    _listenerSetup = true;
  }
  
  void _onTripStatusChanged() {
    if (!mounted) return;

    final rideProvider = Provider.of<RideProvider>(context, listen: false);
    final currentTrip = rideProvider.currentTrip;

    if (currentTrip != null && currentTrip.id == widget.trip.id) {
      // ✅ NUEVO: Si la verificación mutua está completa, viaje iniciado
      if (currentTrip.status == 'in_progress' && currentTrip.isMutualVerificationComplete) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Verificación mutua completada! Tu viaje ha comenzado.'),
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
  void dispose() {
    // ✅ FIX MEMORY LEAK: Remover listener antes de dispose
    if (_listenerSetup && _rideProvider != null) {
      _rideProvider!.removeListener(_onTripStatusChanged);
      _rideProvider = null;
      _listenerSetup = false;
    }

    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
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
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              // Información del conductor
              _buildDriverInfo(),

              SizedBox(height: 24),

              // Código de verificación GIGANTE centrado
              _buildVerificationCodeDisplay(),

              SizedBox(height: 12),

              // Instrucciones compactas
              Text(
                'Muestra este código al conductor para verificar tu viaje',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 20),

              // ✅ Widget de verificación mutua completo
              VerificationCodeWidget(
                rideId: widget.trip.id,
                isDriver: false, // Es pasajero
              ),

              SizedBox(height: 20),

              // Botón de emergencia
              _buildEmergencyButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// Código de verificación GIGANTE centrado (fontSize 64)
  Widget _buildVerificationCodeDisplay() {
    final code = widget.trip.passengerVerificationCode ?? '----';

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: ModernTheme.rappiOrange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: ModernTheme.rappiOrange.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Tu Código',
                  style: TextStyle(
                    fontSize: 14,
                    color: ModernTheme.rappiOrange,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  code,
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: ModernTheme.rappiOrange,
                    letterSpacing: 8,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDriverInfo() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.getCardShadow(context),
      ),
      child: Row(
        children: [
          // Avatar del conductor
          CircleAvatar(
            radius: 30,
            backgroundColor: ModernTheme.rappiOrange.withValues(alpha: 0.1),
            child: Icon(
              Icons.person,
              size: 32,
              color: ModernTheme.rappiOrange,
            ),
          ),
          SizedBox(width: 16),
          // Info del conductor
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.trip.driverId ?? 'Conductor asignado',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.primaryText,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.amber),
                    SizedBox(width: 4),
                    Text(
                      widget.trip.driverRating?.toStringAsFixed(1) ?? '5.0',
                      style: TextStyle(
                        color: context.secondaryText,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 16),
                    Icon(Icons.directions_car, size: 16, color: context.secondaryText),
                    SizedBox(width: 4),
                    Text(
                      widget.trip.vehicleInfo?['model'] ?? 'Vehículo',
                      style: TextStyle(
                        color: context.secondaryText,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Estado
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'En camino',
              style: TextStyle(
                color: ModernTheme.rappiOrange,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Métodos viejos eliminados - ahora usa VerificationCodeWidget

  Widget _buildEmergencyButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _handleEmergencyPress,
        icon: Icon(Icons.emergency, color: Colors.red),
        label: Text(
          'Emergencia',
          style: TextStyle(color: Colors.red, fontSize: 16),
        ),
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: Colors.red, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _showEmergencyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.emergency, color: Colors.red),
            SizedBox(width: 8),
            Text('Emergencia'),
          ],
        ),
        content: Text(
          '¿Necesitas ayuda de emergencia? Esto notificará a las autoridades y cancelará tu viaje.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: _triggerRealEmergency,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Llamar Emergencia', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
          ),
        ],
      ),
    );
  }

  /// Manejar presión del botón de emergencia
  void _handleEmergencyPress() {
    _showEmergencyDialog();
  }

  /// Activar emergencia real con el EmergencyServiceReal
  Future<void> _triggerRealEmergency() async {
    Navigator.pop(context);
    
    // Mostrar loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.red),
            SizedBox(height: 16),
            Text('🚨 Activando emergencia...', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Notificando autoridades y contactos', textAlign: TextAlign.center),
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

      // Cerrar loading dialog
      if (mounted) Navigator.pop(context);

      if (response.success) {
        // Mostrar confirmación
        _showEmergencySuccessDialog(response);
        
        // Log para auditoría
        debugPrint('SOS activado - Trip: ${widget.trip.id}');
        
      } else {
        _showEmergencyErrorDialog(response.message ?? 'Error desconocido');
      }

    } catch (e) {
      // Cerrar loading dialog si aún está abierto
      if (mounted) Navigator.pop(context);
      
      debugPrint('Error activando SOS: $e');
      _showEmergencyErrorDialog('Error activando emergencia: $e');
    }
  }

  /// Mostrar diálogo de éxito de emergencia
  void _showEmergencySuccessDialog(dynamic response) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('🚨 SOS ACTIVADO'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✅ Emergencia activada exitosamente'),
            SizedBox(height: 8),
            Text('📞 Llamada de emergencia iniciada'),
            SizedBox(height: 8),
            Text('📱 ${response.contactsNotified} contactos notificados'),
            SizedBox(height: 8),
            Text('🎤 Grabación de audio iniciada'),
            SizedBox(height: 8),
            Text('📍 Ubicación enviada a autoridades'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Text(
                'ID de Emergencia: ${response.emergencyId ?? 'N/A'}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Regresar a home con estado de emergencia
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/passenger/home',
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Entendido', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
          ),
        ],
      ),
    );
  }

  /// Mostrar diálogo de error de emergencia
  void _showEmergencyErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.orange, size: 32),
            SizedBox(width: 12),
            Text('Error de Emergencia'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No se pudo activar completamente el SOS:'),
            SizedBox(height: 8),
            Text(
              errorMessage,
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '⚠️ RECOMENDACIÓN: Llame directamente al 911 o 105',
                style: TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}