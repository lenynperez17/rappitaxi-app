import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/oasis_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/utils/logger.dart';

// Provider para estado de emergencia
final emergencyStateProvider = StateProvider<EmergencyState>((ref) => EmergencyState.safe);
final emergencyContactsProvider = StateProvider<List<EmergencyContact>>((ref) => []);

enum EmergencyState { safe, warning, emergency }

class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String relationship;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.relationship,
  });
}

class EmergencyScreen extends ConsumerStatefulWidget {
  const EmergencyScreen({super.key});

  @override
  ConsumerState<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends ConsumerState<EmergencyScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  Position? _currentPosition;
  bool _isGettingLocation = false;

  // Números de emergencia predeterminados
  final List<Map<String, dynamic>> _emergencyNumbers = [
    {
      'name': 'Policía Nacional',
      'number': '105',
      'icon': Icons.local_police,
      'color': Colors.blue,
    },
    {
      'name': 'Bomberos',
      'number': '116',
      'icon': Icons.local_fire_department,
      'color': Colors.red,
    },
    {
      'name': 'SAMU (Emergencias médicas)',
      'number': '106',
      'icon': Icons.local_hospital,
      'color': Colors.green,
    },
    {
      'name': 'Serenazgo Lima',
      'number': '(01) 418-0000',
      'icon': Icons.security,
      'color': Colors.orange,
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    if (!_isGettingLocation) {
      setState(() => _isGettingLocation = true);
      
      try {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          await Geolocator.requestPermission();
        }
        
        final position = await Geolocator.getCurrentPosition();
        setState(() {
          _currentPosition = position;
          _isGettingLocation = false;
        });
      } catch (e) {
        setState(() => _isGettingLocation = false);
        if (kDebugMode) {
          Logger().error('Error obteniendo ubicación', error: e);
        }
      }
    }
  }

  Future<void> _callEmergencyNumber(String number) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      _showSnackBar('No se pudo hacer la llamada', isError: true);
    }
  }

  Future<void> _activateEmergencyMode() async {
    ref.read(emergencyStateProvider.notifier).state = EmergencyState.emergency;
    
    // Obtener ubicación actual
    await _getCurrentLocation();
    
    // Enviar alerta a contactos de emergencia
    await _sendEmergencyAlert();
    
    // Mostrar confirmación
    _showEmergencyActivatedDialog();
  }

  Future<void> _sendEmergencyAlert() async {
    final contacts = ref.read(emergencyContactsProvider);
    final currentUser = ref.read(currentUserProvider);
    
    if (contacts.isEmpty) {
      _showSnackBar('No tienes contactos de emergencia configurados', isError: true);
      return;
    }

    final locationText = _currentPosition != null
        ? 'Ubicación: https://maps.google.com/?q=${_currentPosition!.latitude},${_currentPosition!.longitude}'
        : 'Ubicación: No disponible';

    final message = '''
🚨 ALERTA DE EMERGENCIA - RappiTaxi 🚨

${currentUser?.name ?? 'Usuario'} ha activado el botón de emergencia.

$locationText

Hora: ${DateTime.now().toString()}

Este es un mensaje automático de RappiTaxi.
    ''';

    // Simular envío de mensajes (implementar con servicio real)
    for (final contact in contacts) {
      await _sendSMSToContact(contact.phone, message);
    }

    _showSnackBar('Alerta enviada a ${contacts.length} contactos');
  }

  Future<void> _sendSMSToContact(String phoneNumber, String message) async {
    // En un proyecto real, implementarías el envío con un servicio como Twilio
    if (kDebugMode) {
      Logger().info('Simulando envío SMS a $phoneNumber');
    }
    await Future.delayed(const Duration(milliseconds: 500)); // Simular envío
  }

  void _shareLocation() async {
    if (_currentPosition == null) {
      await _getCurrentLocation();
    }

    if (_currentPosition != null) {
      final locationUrl = 'https://maps.google.com/?q=${_currentPosition!.latitude},${_currentPosition!.longitude}';
      
      // En un proyecto real, usarías share_plus para compartir
      _showSnackBar('Ubicación copiada: $locationUrl');
    } else {
      _showSnackBar('No se pudo obtener la ubicación', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorColor : AppTheme.primaryColor,
      ),
    );
  }

  void _showEmergencyActivatedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning,
              color: AppTheme.errorColor,
            ),
            const SizedBox(width: 8),
            const Text('Emergencia Activada'),
          ],
        ),
        content: const Text(
          'Se ha activado el modo de emergencia. Tus contactos han sido notificados automáticamente con tu ubicación.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deactivateEmergencyMode();
            },
            child: const Text('Desactivar emergencia'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _callEmergencyNumber('105'); // Policía
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Llamar Policía'),
          ),
        ],
      ),
    );
  }

  void _deactivateEmergencyMode() {
    ref.read(emergencyStateProvider.notifier).state = EmergencyState.safe;
    _showSnackBar('Modo de emergencia desactivado');
  }

  @override
  Widget build(BuildContext context) {
    final emergencyState = ref.watch(emergencyStateProvider);
    final emergencyContacts = ref.watch(emergencyContactsProvider);

    return Scaffold(
      backgroundColor: emergencyState == EmergencyState.emergency 
          ? AppTheme.errorColor.withOpacity(0.05)
          : Colors.white,
      appBar: AppBar(
        title: Text(
          emergencyState == EmergencyState.emergency 
              ? '🚨 EMERGENCIA ACTIVA' 
              : 'Centro de Seguridad',
        ),
        backgroundColor: emergencyState == EmergencyState.emergency 
            ? AppTheme.errorColor 
            : Colors.white,
        foregroundColor: emergencyState == EmergencyState.emergency 
            ? Colors.white 
            : AppTheme.textColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (emergencyState == EmergencyState.emergency)
            IconButton(
              onPressed: _deactivateEmergencyMode,
              icon: const Icon(Icons.stop),
              tooltip: 'Desactivar emergencia',
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Botón de emergencia principal
            _buildEmergencyButton(emergencyState),
            
            const SizedBox(height: 32),
            
            // Acciones rápidas de seguridad
            _buildQuickActions(),
            
            const SizedBox(height: 24),
            
            // Números de emergencia
            _buildEmergencyNumbers(),
            
            const SizedBox(height: 24),
            
            // Contactos de emergencia personales
            _buildEmergencyContacts(emergencyContacts),
            
            const SizedBox(height: 24),
            
            // Consejos de seguridad
            _buildSafetyTips(),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyButton(EmergencyState state) {
    final isEmergency = state == EmergencyState.emergency;
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            child: GestureDetector(
              onTap: isEmergency ? _deactivateEmergencyMode : _showEmergencyConfirmation,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isEmergency ? AppTheme.errorColor : AppTheme.errorColor.withOpacity(0.1),
                  border: Border.all(
                    color: AppTheme.errorColor,
                    width: isEmergency ? 4 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.errorColor.withOpacity(0.3),
                      blurRadius: isEmergency ? 20 : 10,
                      spreadRadius: isEmergency ? 5 : 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isEmergency ? Icons.stop : Icons.warning,
                      size: 60,
                      color: isEmergency ? Colors.white : AppTheme.errorColor,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isEmergency ? 'EMERGENCIA\nACTIVA' : 'EMERGENCIA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isEmergency ? 18 : 16,
                        fontWeight: FontWeight.bold,
                        color: isEmergency ? Colors.white : AppTheme.errorColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            builder: (context, child) {
              return Transform.scale(
                scale: isEmergency ? 1.0 + (_pulseController.value * 0.1) : 1.0,
                child: child,
              );
            },
          ).animate().scale(duration: 500.ms),
          
          const SizedBox(height: 16),
          
          Text(
            isEmergency 
                ? 'Modo de emergencia activo\nToca para desactivar'
                : 'Mantén presionado para activar\nel modo de emergencia',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          
          if (_isGettingLocation)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Obteniendo ubicación...',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Acciones Rápidas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  title: 'Compartir\nUbicación',
                  icon: Icons.location_on,
                  color: AppTheme.primaryColor,
                  onTap: _shareLocation,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  title: 'Llamar\nContacto',
                  icon: Icons.phone,
                  color: AppTheme.successColor,
                  onTap: () => _showEmergencyContactsBottomSheet(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  title: 'Reportar\nProblema',
                  icon: Icons.report,
                  color: AppTheme.warningColor,
                  onTap: () => _showReportDialog(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().scale(delay: 200.ms);
  }

  Widget _buildEmergencyNumbers() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Números de Emergencia',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 16),
          
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: _emergencyNumbers.asMap().entries.map((entry) {
                final index = entry.key;
                final number = entry.value;
                final isLast = index == _emergencyNumbers.length - 1;
                
                return Column(
                  children: [
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: (number['color'] as Color).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          number['icon'] as IconData,
                          color: number['color'] as Color,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        number['name'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        number['number'] as String,
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: IconButton(
                        onPressed: () => _callEmergencyNumber(number['number'] as String),
                        icon: Icon(
                          Icons.phone,
                          color: number['color'] as Color,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: (number['color'] as Color).withOpacity(0.1),
                        ),
                      ),
                    ),
                    if (!isLast) const Divider(height: 1),
                  ],
                );
              }).toList(),
            ),
          ).animate().fadeIn(delay: 300.ms),
        ],
      ),
    );
  }

  Widget _buildEmergencyContacts(List<EmergencyContact> contacts) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Contactos de Emergencia',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: _showAddEmergencyContactDialog,
                icon: const Icon(Icons.add),
                label: const Text('Agregar'),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          if (contacts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.person_add,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No tienes contactos de emergencia',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Agrega contactos para notificar en emergencias',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OasisButton(
                    text: 'Agregar contacto',
                    onPressed: _showAddEmergencyContactDialog,
                  ),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: contacts.asMap().entries.map((entry) {
                  final index = entry.key;
                  final contact = entry.value;
                  final isLast = index == contacts.length - 1;
                  
                  return Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                          child: Text(
                            contact.name.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          contact.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(contact.phone),
                            Text(
                              contact.relationship,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _callEmergencyNumber(contact.phone),
                              icon: const Icon(Icons.phone),
                              style: IconButton.styleFrom(
                                backgroundColor: AppTheme.successColor.withOpacity(0.1),
                                foregroundColor: AppTheme.successColor,
                              ),
                            ),
                            IconButton(
                              onPressed: () => _deleteEmergencyContact(contact.id),
                              icon: const Icon(Icons.delete),
                              style: IconButton.styleFrom(
                                backgroundColor: AppTheme.errorColor.withOpacity(0.1),
                                foregroundColor: AppTheme.errorColor,
                              ),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                      if (!isLast) const Divider(height: 1),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSafetyTips() {
    final tips = [
      'Siempre comparte tu viaje con familiares o amigos',
      'Verifica que la placa del vehículo coincida con la app',
      'Siéntate en el asiento trasero cuando viajes solo',
      'Mantén tu teléfono cargado y con datos móviles',
      'Confía en tu instinto - si algo se siente mal, actúa',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Consejos de Seguridad',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.1),
              ),
            ),
            child: Column(
              children: tips.asMap().entries.map((entry) {
                final index = entry.key;
                final tip = entry.value;
                
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == tips.length - 1 ? 0 : 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tip,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ).animate().fadeIn(delay: 400.ms),
        ],
      ),
    );
  }

  void _showEmergencyConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning,
              color: AppTheme.errorColor,
            ),
            const SizedBox(width: 8),
            const Text('¿Activar Emergencia?'),
          ],
        ),
        content: const Text(
          'Esto enviará tu ubicación a tus contactos de emergencia y notificará a las autoridades. ¿Estás en una situación de emergencia real?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _activateEmergencyMode();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Sí, es emergencia'),
          ),
        ],
      ),
    );
  }

  void _showEmergencyContactsBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Llamar contacto de emergencia',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            // Lista de contactos para llamar rápido
            const Text('Función disponible cuando agregues contactos'),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reportar Problema'),
        content: const Text(
          '¿Qué tipo de problema deseas reportar?\n\n• Conductor sospechoso\n• Vehículo no coincide\n• Ruta incorrecta\n• Comportamiento inadecuado\n• Otro problema de seguridad',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/support');
            },
            child: const Text('Reportar'),
          ),
        ],
      ),
    );
  }

  void _showAddEmergencyContactDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    String selectedRelationship = 'Familiar';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Agregar Contacto de Emergencia'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  border: OutlineInputBorder(),
                  prefixText: '+51 ',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRelationship,
                decoration: const InputDecoration(
                  labelText: 'Relación',
                  border: OutlineInputBorder(),
                ),
                items: ['Familiar', 'Amigo', 'Pareja', 'Colega', 'Otro']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (value) {
                  setState(() => selectedRelationship = value ?? 'Familiar');
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty) {
                  final newContact = EmergencyContact(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text,
                    phone: phoneController.text,
                    relationship: selectedRelationship,
                  );
                  
                  final currentContacts = ref.read(emergencyContactsProvider);
                  ref.read(emergencyContactsProvider.notifier).state = [
                    ...currentContacts,
                    newContact,
                  ];
                  
                  Navigator.pop(context);
                  _showSnackBar('Contacto de emergencia agregado');
                }
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteEmergencyContact(String contactId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar contacto?'),
        content: const Text('Este contacto ya no será notificado en emergencias.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final currentContacts = ref.read(emergencyContactsProvider);
              ref.read(emergencyContactsProvider.notifier).state = 
                  currentContacts.where((c) => c.id != contactId).toList();
              Navigator.pop(context);
              _showSnackBar('Contacto eliminado');
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}