import 'package:flutter/material.dart';
// ignore_for_file: library_private_types_in_public_api
import 'package:flutter/services.dart';
import 'dart:async';
import '../../services/emergency_service.dart';
import '../../services/firebase_service.dart';
import '../../widgets/loading_overlay.dart';
import '../../core/theme/modern_theme.dart';

/// PANTALLA DE EMERGENCIA SOS - RAPPI TEAM
/// =======================================
/// 
/// Funcionalidades críticas:
/// 🚨 Botón de pánico grande y visible
/// 📞 Llamada automática al 911
/// 📱 Notificación a contactos de emergencia
/// 🎙️ Grabación de audio automática
/// 📍 Compartir ubicación en tiempo real
/// 📳 Vibración continua y alertas visuales
/// ❌ Cancelación de emergencia (solo falsa alarma)
/// 📋 Historial de emergencias
class EmergencySOSScreen extends StatefulWidget {
  final String userId;
  final String userType; // 'passenger' o 'driver'
  final String? rideId;

  const EmergencySOSScreen({
    super.key,
    required this.userId,
    required this.userType,
    this.rideId,
  });

  @override
  State<EmergencySOSScreen> createState() => _EmergencySOSScreenState();
}

class _EmergencySOSScreenState extends State<EmergencySOSScreen>
    with TickerProviderStateMixin {
  final EmergencyService _emergencyService = EmergencyService();
  final FirebaseService _firebaseService = FirebaseService();

  bool _isLoading = false;
  bool _emergencyActive = false;
  Timer? _vibrationTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _warningController;
  late Animation<Color?> _warningAnimation;

  List<EmergencyType> _emergencyTypes = [];
  EmergencyType? _selectedEmergencyType;
  List<EmergencyContact> _emergencyContacts = [];
  List<EmergencyHistory> _emergencyHistory = [];

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _setupAnimations();
    _loadEmergencyData();
  }

  @override
  void dispose() {
    _vibrationTimer?.cancel();
    _pulseController.dispose();
    _warningController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    // Animación de pulso para el botón SOS
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Animación de advertencia para el fondo
    _warningController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _warningAnimation = ColorTween(
      begin: Colors.transparent,
      end: ModernTheme.error.withValues(alpha: 0.3),
    ).animate(_warningController);
  }

  Future<void> _initializeServices() async {
    await _emergencyService.initialize();
    
    if (!mounted) return;
    setState(() {
      _emergencyActive = _emergencyService.isEmergencyActive;
    });

    if (_emergencyActive) {
      _startEmergencyAnimation();
    }
  }

  Future<void> _loadEmergencyData() async {
    setState(() => _isLoading = true);

    try {
      // Cargar tipos de emergencia
      _emergencyTypes = EmergencyService.getEmergencyTypes();
      _selectedEmergencyType = _emergencyTypes.first;

      // Cargar contactos de emergencia
      _emergencyContacts = await _emergencyService.getEmergencyContacts(widget.userId);

      // Cargar historial de emergencias
      _emergencyHistory = await _emergencyService.getUserEmergencyHistory(widget.userId);

    } catch (e) {
      _showErrorSnackBar('Error cargando datos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ============================================================================
  // FUNCIONES DE EMERGENCIA PRINCIPAL
  // ============================================================================

  Future<void> _triggerSOS() async {
    // Confirmación antes de activar SOS
    final confirmed = await _showSOSConfirmation();
    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      final result = await _emergencyService.triggerSOS(
        userId: widget.userId,
        userType: widget.userType,
        rideId: widget.rideId,
        emergencyType: _selectedEmergencyType?.id,
        notes: 'Emergencia activada desde la aplicación Rappi Team',
      );

      if (result.success) {
        setState(() {
          _emergencyActive = true;
        });

        _startEmergencyAnimation();
        _startContinuousVibration();

        _showSuccessDialog(
          title: '🚨 SOS ACTIVADO',
          message: result.message ?? 'Servicios de emergencia contactados',
        );

        await _firebaseService.analytics.logEvent(
          name: 'emergency_sos_triggered_from_screen',
          parameters: {
            'user_id': widget.userId,
            'user_type': widget.userType,
            'emergency_type': _selectedEmergencyType?.id ?? 'sos_panic',
            'ride_id': widget.rideId ?? '',
          },
        );
      } else {
        _showErrorSnackBar(result.error ?? 'Error activando SOS');
      }
    } catch (e) {
      _showErrorSnackBar('Error activando SOS: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelEmergency() async {
    final confirmed = await _showCancelConfirmation();
    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      final success = await _emergencyService.cancelEmergency(
        userId: widget.userId,
        reason: 'Cancelado por el usuario - Falsa alarma',
      );

      if (success) {
        setState(() {
          _emergencyActive = false;
        });

        _stopEmergencyAnimation();
        _stopContinuousVibration();

        _showSuccessDialog(
          title: '✅ EMERGENCIA CANCELADA',
          message: 'La emergencia ha sido cancelada exitosamente',
        );

        await _loadEmergencyData(); // Recargar historial
      } else {
        _showErrorSnackBar('Error cancelando emergencia');
      }
    } catch (e) {
      _showErrorSnackBar('Error cancelando emergencia: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ============================================================================
  // FUNCIONES DE ANIMACIÓN Y EFECTOS
  // ============================================================================

  void _startEmergencyAnimation() {
    _pulseController.repeat(reverse: true);
    _warningController.repeat(reverse: true);
  }

  void _stopEmergencyAnimation() {
    _pulseController.stop();
    _warningController.stop();
    _warningController.reset();
  }

  void _startContinuousVibration() {
    _vibrationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      HapticFeedback.heavyImpact();
    });
  }

  void _stopContinuousVibration() {
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
  }

  // ============================================================================
  // DIÁLOGOS DE CONFIRMACIÓN
  // ============================================================================

  Future<bool> _showSOSConfirmation() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Text('🚨 CONFIRMAR SOS'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Estás seguro que quieres activar la emergencia SOS?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            const Text(
              'Esto hará lo siguiente:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• 📞 Llamada automática al 911'),
                Text('• 📱 SMS a tus contactos de emergencia'),
                Text('• 🎙️ Iniciar grabación de audio'),
                Text('• 📍 Compartir ubicación en tiempo real'),
                Text('• 🔔 Alertar a Rappi Team Central'),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Text(
                '⚠️ Solo usar en emergencias reales. Uso indebido puede tener consecuencias legales.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: const Text('SÍ, ACTIVAR SOS'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<bool> _showCancelConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Emergencia'),
        content: const Text(
          '¿Estás seguro que quieres cancelar la emergencia activa?\n\n'
          'Solo cancela si es una falsa alarma.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('NO'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: const Text('SÍ, CANCELAR'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSuccessDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ENTENDIDO'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ============================================================================
  // UI - BUILD METHODS
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _emergencyActive ? Colors.red.shade900 : Colors.white,
      appBar: AppBar(
        title: const Text(
          '🚨 EMERGENCIA SOS',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _emergencyActive ? Colors.red.shade700 : Colors.blue.shade600,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
      ),
      body: AnimatedBuilder(
        animation: _warningAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              color: _warningAnimation.value,
            ),
            child: LoadingOverlay(
              isLoading: _isLoading,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (_emergencyActive) _buildActiveEmergencyCard(),
                    if (!_emergencyActive) ...[
                      // Layout: botón SOS gigante centrado con opciones alrededor
                      _buildSOSCenteredLayout(),
                    ],
                    const SizedBox(height: 24),
                    _buildEmergencyHistoryCard(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Layout principal: botón SOS ENORME centrado (180x180) con opciones alrededor
  Widget _buildSOSCenteredLayout() {
    return Column(
      children: [
        const SizedBox(height: 24),

        // Botón SOS gigante centrado
        Center(child: _buildSOSButton()),

        const SizedBox(height: 32),

        // Opciones de emergencia alrededor (tipo chip horizontal)
        _buildEmergencyTypeSelector(),

        const SizedBox(height: 24),

        // Contactos de emergencia
        _buildEmergencyContactsCard(),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSOSButton() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.red.shade400,
                  Colors.red.shade600,
                  Colors.red.shade800,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.5),
                  blurRadius: 30,
                  spreadRadius: 8,
                ),
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.2),
                  blurRadius: 60,
                  spreadRadius: 20,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(90),
                onTap: _isLoading ? null : _triggerSOS,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.emergency,
                        color: Theme.of(context).colorScheme.surface,
                        size: 80,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'SOS',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.surface,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'TOCA PARA ACTIVAR',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.surface,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveEmergencyCard() {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.emergency,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              '🚨 EMERGENCIA ACTIVA',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Los servicios de emergencia han sido contactados.\n'
              'Tus contactos de emergencia han sido notificados.\n'
              'Se está compartiendo tu ubicación en tiempo real.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Icon(Icons.phone, color: Colors.green, size: 32),
                    Text('911\nLlamado', textAlign: TextAlign.center),
                  ],
                ),
                Column(
                  children: [
                    Icon(Icons.contacts, color: Colors.blue, size: 32),
                    Text('Contactos\nNotificados', textAlign: TextAlign.center),
                  ],
                ),
                Column(
                  children: [
                    Icon(Icons.location_on, color: Colors.red, size: 32),
                    Text('Ubicación\nCompartida', textAlign: TextAlign.center),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _cancelEmergency,
                icon: const Icon(Icons.cancel),
                label: const Text('CANCELAR EMERGENCIA (Solo Falsa Alarma)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyTypeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tipo de Emergencia',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emergencyTypes.map((type) {
                final isSelected = _selectedEmergencyType?.id == type.id;
                return FilterChip(
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedEmergencyType = type;
                    });
                  },
                  label: Text('${type.icon} ${type.name}'),
                  backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                  selectedColor: Colors.red.shade100,
                  checkmarkColor: Colors.red,
                );
              }).toList(),
            ),
            if (_selectedEmergencyType != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _selectedEmergencyType!.description,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyContactsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Contactos de Emergencia',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () {
                    // Navegar a configurar contactos
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_emergencyContacts.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No tienes contactos de emergencia configurados. '
                        'Es muy importante agregar al menos 3 contactos.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: _emergencyContacts.take(3).map((contact) {
                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person),
                    ),
                    title: Text(
                      contact.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${contact.relationship} • ${contact.phoneNumber}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.phone, color: Colors.green),
                    dense: true,
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyHistoryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Historial de Emergencias',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_emergencyHistory.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No hay emergencias previas',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            else
              Column(
                children: _emergencyHistory.take(3).map((emergency) {
                  IconData statusIcon;
                  Color statusColor;
                  
                  switch (emergency.status) {
                    case 'resolved':
                      statusIcon = Icons.check_circle;
                      statusColor = Colors.green;
                      break;
                    case 'cancelled':
                      statusIcon = Icons.cancel;
                      statusColor = Colors.orange;
                      break;
                    default:
                      statusIcon = Icons.warning;
                      statusColor = Colors.red;
                  }

                  return ListTile(
                    leading: Icon(statusIcon, color: statusColor),
                    title: Text(_getEmergencyTypeName(emergency.type)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          emergency.location,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${emergency.createdAt.day}/${emergency.createdAt.month}/${emergency.createdAt.year} '
                          '${emergency.createdAt.hour}:${emergency.createdAt.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    dense: true,
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  String _getEmergencyTypeName(String type) {
    final emergencyType = _emergencyTypes.firstWhere(
      (t) => t.id == type,
      orElse: () => EmergencyType(
        id: 'unknown', 
        name: 'Emergencia', 
        description: '', 
        icon: '🚨', 
        priority: 'medium'
      ),
    );
    return '${emergencyType.icon} ${emergencyType.name}';
  }
}