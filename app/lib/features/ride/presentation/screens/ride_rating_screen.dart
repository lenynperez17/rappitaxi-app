import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/oasis_button.dart';
import '../../../../shared/models/location_model.dart';
import '../../../../shared/utils/logger.dart';

class RideRatingScreen extends ConsumerStatefulWidget {
  final double fare;
  final Map<String, dynamic> driver;
  final LocationModel pickup;
  final LocationModel destination;

  const RideRatingScreen({
    super.key,
    required this.fare,
    required this.driver,
    required this.pickup,
    required this.destination,
  });

  @override
  ConsumerState<RideRatingScreen> createState() => _RideRatingScreenState();
}

class _RideRatingScreenState extends ConsumerState<RideRatingScreen> {
  int _driverRating = 0;
  int _serviceRating = 0;
  int _vehicleRating = 0;
  
  final _commentController = TextEditingController();
  final _tipController = TextEditingController();
  
  bool _wouldRecommend = false;
  List<String> _selectedTags = [];
  double _selectedTip = 0.0;
  
  // Tags predefinidos para feedback rápido
  final List<String> _positiveTags = [
    'Puntual', 'Amable', 'Buen conductor', 'Auto limpio', 'Música agradable',
    'Conversación amena', 'Manejo seguro', 'Conoce la ciudad', 'Profesional'
  ];
  
  final List<String> _negativeTags = [
    'Llegó tarde', 'Poco amable', 'Manejo brusco', 'Auto sucio', 'Música alta',
    'Conversación incómoda', 'No siguió ruta', 'Teléfono al manejar', 'Impuntual'
  ];

  @override
  void dispose() {
    _commentController.dispose();
    _tipController.dispose();
    super.dispose();
  }

  void _submitRating() async {
    if (_driverRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor califica a tu conductor'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Aquí implementarías el envío del rating al backend
    // await _submitRatingToBackend();

    // Mostrar mensaje de agradecimiento
    _showThankYouDialog();
  }

  void _submitRatingToBackend() async {
    // TODO: Implementar envío al backend
    final ratingData = {
      'rideId': 'ride_${DateTime.now().millisecondsSinceEpoch}',
      'driverId': widget.driver['id'] ?? 'driver_123',
      'driverRating': _driverRating,
      'serviceRating': _serviceRating,
      'vehicleRating': _vehicleRating,
      'comment': _commentController.text,
      'tags': _selectedTags,
      'wouldRecommend': _wouldRecommend,
      'tip': _selectedTip,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    // Simular envío
    await Future.delayed(const Duration(seconds: 1));
    if (kDebugMode) {
      Logger().info('Rating enviado', additionalData: ratingData);
    }
  }

  void _showThankYouDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: AppTheme.successColor,
              size: 60,
            ).animate().scale(duration: 500.ms),
            const SizedBox(height: 16),
            Text(
              '¡Gracias por tu calificación!',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tu opinión nos ayuda a mejorar el servicio',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OasisButton(
              text: 'Continuar',
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/home');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header con información del viaje
            _buildTripSummary(),
            
            // Contenido principal scrolleable
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Calificación del conductor
                    _buildDriverRating(),
                    
                    const SizedBox(height: 24),
                    
                    // Calificaciones adicionales
                    _buildAdditionalRatings(),
                    
                    const SizedBox(height: 24),
                    
                    // Tags de feedback rápido
                    _buildFeedbackTags(),
                    
                    const SizedBox(height: 24),
                    
                    // Comentarios
                    _buildCommentSection(),
                    
                    const SizedBox(height: 24),
                    
                    // Recomendación
                    _buildRecommendationSection(),
                    
                    const SizedBox(height: 24),
                    
                    // Propina
                    _buildTipSection(),
                  ],
                ),
              ),
            ),
            
            // Botón de envío
            Padding(
              padding: const EdgeInsets.all(20),
              child: OasisButton(
                text: 'Enviar calificación',
                onPressed: _submitRating,
              ).animate().fadeIn().scale(delay: 800.ms),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            Colors.white,
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '¡Viaje completado!',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => context.go('/home'),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Información del conductor
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppTheme.primaryColor,
                child: Text(
                  widget.driver['name']?.split(' ')[0][0]?.toUpperCase() ?? 'C',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.driver['name'] ?? 'Conductor',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.driver['vehicle'] ?? 'Vehículo',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    Text(
                      'Total: S/ ${widget.fare.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.2, end: 0);
  }

  Widget _buildDriverRating() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '¿Cómo estuvo tu experiencia con tu conductor?',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 16),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (index) {
            final rating = index + 1;
            return GestureDetector(
              onTap: () => setState(() => _driverRating = rating),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.star,
                  size: 40,
                  color: rating <= _driverRating
                      ? Colors.amber
                      : Colors.grey.shade300,
                ),
              ).animate().scale(delay: Duration(milliseconds: 100 * index)),
            );
          }),
        ),
        
        const SizedBox(height: 8),
        
        if (_driverRating > 0)
          Center(
            child: Text(
              _getRatingText(_driverRating),
              style: TextStyle(
                color: _getRatingColor(_driverRating),
                fontWeight: FontWeight.w600,
              ),
            ).animate().fadeIn().slideY(begin: 0.2, end: 0),
          ),
      ],
    );
  }

  Widget _buildAdditionalRatings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Califica aspectos específicos',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Calificación del servicio
        _buildRatingRow(
          'Servicio al cliente',
          Icons.support_agent,
          _serviceRating,
          (rating) => setState(() => _serviceRating = rating),
        ),
        
        const SizedBox(height: 12),
        
        // Calificación del vehículo
        _buildRatingRow(
          'Estado del vehículo',
          Icons.directions_car,
          _vehicleRating,
          (rating) => setState(() => _vehicleRating = rating),
        ),
      ],
    );
  }

  Widget _buildRatingRow(String title, IconData icon, int currentRating, Function(int) onRatingChanged) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppTheme.primaryColor,
          size: 20,
        ),
        
        const SizedBox(width: 12),
        
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        
        Row(
          children: List.generate(5, (index) {
            final rating = index + 1;
            return GestureDetector(
              onTap: () => onRatingChanged(rating),
              child: Icon(
                Icons.star,
                size: 24,
                color: rating <= currentRating
                    ? Colors.amber
                    : Colors.grey.shade300,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildFeedbackTags() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cuéntanos más (opcional)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Tags positivos (si rating >= 4)
        if (_driverRating >= 4) ...[
          Text(
            '¿Qué te gustó?',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppTheme.successColor,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _positiveTags.map((tag) {
              final isSelected = _selectedTags.contains(tag);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedTags.remove(tag);
                    } else {
                      _selectedTags.add(tag);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.successColor.withOpacity(0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.successColor
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? AppTheme.successColor
                          : AppTheme.textColor,
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        
        // Tags negativos (si rating <= 3)
        if (_driverRating > 0 && _driverRating <= 3) ...[
          Text(
            '¿Qué se puede mejorar?',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppTheme.warningColor,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _negativeTags.map((tag) {
              final isSelected = _selectedTags.contains(tag);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedTags.remove(tag);
                    } else {
                      _selectedTags.add(tag);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.warningColor.withOpacity(0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.warningColor
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? AppTheme.warningColor
                          : AppTheme.textColor,
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildCommentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comentarios adicionales',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _commentController,
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: 'Escribe aquí cualquier comentario adicional sobre tu viaje...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primaryColor),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
        ).animate().fadeIn(delay: 600.ms),
      ],
    );
  }

  Widget _buildRecommendationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recomendación',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 16),
        
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: CheckboxListTile(
            value: _wouldRecommend,
            onChanged: (value) => setState(() => _wouldRecommend = value ?? false),
            title: const Text('Recomendaría este conductor a otros usuarios'),
            subtitle: Text(
              'Ayudanos a destacar a los mejores conductores',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryColor,
              ),
            ),
            activeColor: AppTheme.primaryColor,
          ),
        ).animate().fadeIn(delay: 700.ms),
      ],
    );
  }

  Widget _buildTipSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Propina (opcional)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 8),
        
        Text(
          'Reconoce un excelente servicio',
          style: TextStyle(
            color: AppTheme.textSecondaryColor,
            fontSize: 14,
          ),
        ),
        
        const SizedBox(height: 16),
        
        Row(
          children: [
            _buildTipOption(2.0),
            const SizedBox(width: 8),
            _buildTipOption(5.0),
            const SizedBox(width: 8),
            _buildTipOption(10.0),
            const SizedBox(width: 8),
            Expanded(child: _buildCustomTipOption()),
          ],
        ),
        
        if (_selectedTip > 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Total con propina: S/ ${(widget.fare + _selectedTip).toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ).animate().fadeIn(),
          ),
      ],
    );
  }

  Widget _buildTipOption(double amount) {
    final isSelected = _selectedTip == amount;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedTip = isSelected ? 0.0 : amount),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : Colors.grey.shade300,
          ),
        ),
        child: Text(
          'S/ ${amount.toStringAsFixed(0)}',
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomTipOption() {
    return TextFormField(
      controller: _tipController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        hintText: 'Otro',
        prefixText: 'S/ ',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      onChanged: (value) {
        final customTip = double.tryParse(value) ?? 0.0;
        if (customTip > 0) {
          setState(() => _selectedTip = customTip);
        } else if (value.isEmpty) {
          setState(() => _selectedTip = 0.0);
        }
      },
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Muy malo';
      case 2:
        return 'Malo';
      case 3:
        return 'Regular';
      case 4:
        return 'Bueno';
      case 5:
        return 'Excelente';
      default:
        return '';
    }
  }

  Color _getRatingColor(int rating) {
    if (rating <= 2) return AppTheme.errorColor;
    if (rating == 3) return AppTheme.warningColor;
    return AppTheme.successColor;
  }
}