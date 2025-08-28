import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/oasis_button.dart';
import '../../../../shared/models/location_model.dart';

class RideCompletedScreen extends ConsumerStatefulWidget {
  final double fare;
  final Map<String, dynamic> driver;
  final LocationModel pickup;
  final LocationModel destination;
  
  const RideCompletedScreen({
    super.key,
    required this.fare,
    required this.driver,
    required this.pickup,
    required this.destination,
  });
  
  @override
  ConsumerState<RideCompletedScreen> createState() => _RideCompletedScreenState();
}

class _RideCompletedScreenState extends ConsumerState<RideCompletedScreen> {
  double _rating = 5.0;
  final _tipController = TextEditingController();
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  
  final List<String> _tipOptions = ['0', '2', '5', '10'];
  String? _selectedTip;
  
  @override
  void dispose() {
    _tipController.dispose();
    _commentController.dispose();
    super.dispose();
  }
  
  double get _totalAmount {
    final tip = double.tryParse(_selectedTip ?? '0') ?? 0;
    return widget.fare + tip;
  }
  
  Future<void> _submitRating() async {
    setState(() => _isSubmitting = true);
    
    // Simular envío de calificación
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Gracias por tu calificación!'),
          // backgroundColor: AppTheme.successColor,
        ),
      );
      
      // Navegar a home
      context.go('/home');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icono de éxito
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 48,
                    color: AppTheme.successColor,
                  ),
                )
                    .animate()
                    .scale(duration: 600.ms, curve: Curves.elasticOut),
                
                const SizedBox(height: 24),
                
                // Título
                Text(
                  '¡Viaje completado!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                )
                    .animate()
                    .fadeIn(delay: 300.ms),
                
                const SizedBox(height: 32),
                
                // Resumen del viaje
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      // Tarifa
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Tarifa del viaje',
                            style: TextStyle(fontSize: 16),
                          ),
                          Text(
                            'S/ ${widget.fare.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      
                      if (_selectedTip != null && _selectedTip != '0') ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Propina',
                              style: TextStyle(fontSize: 16),
                            ),
                            Text(
                              'S/ ${_selectedTip}',
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'S/ ${_totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(delay: 400.ms),
                
                const SizedBox(height: 32),
                
                // Calificar conductor
                Text(
                  '¿Cómo fue tu viaje con ${widget.driver['name'].split(' ')[0]}?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                // Rating stars
                Center(
                  child: RatingBar.builder(
                    initialRating: _rating,
                    minRating: 1,
                    direction: Axis.horizontal,
                    allowHalfRating: true,
                    itemCount: 5,
                    itemSize: 40,
                    itemPadding: const EdgeInsets.symmetric(horizontal: 4),
                    itemBuilder: (context, _) => const Icon(
                      Icons.star,
                      color: Colors.amber,
                    ),
                    onRatingUpdate: (rating) {
                      setState(() => _rating = rating);
                    },
                  ),
                )
                    .animate()
                    .fadeIn(delay: 500.ms),
                
                const SizedBox(height: 24),
                
                // Propina
                Text(
                  'Añadir propina (opcional)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                Wrap(
                  spacing: 12,
                  children: _tipOptions.map((tip) {
                    final isSelected = _selectedTip == tip;
                    return ChoiceChip(
                      label: Text(tip == '0' ? 'Sin propina' : 'S/ $tip'),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedTip = selected ? tip : null;
                        });
                      },
                      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: isSelected ? AppTheme.primaryColor : AppTheme.textColor,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                )
                    .animate()
                    .fadeIn(delay: 600.ms),
                
                const SizedBox(height: 24),
                
                // Comentario
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Comparte tu experiencia (opcional)',
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
                )
                    .animate()
                    .fadeIn(delay: 700.ms),
                
                const SizedBox(height: 32),
                
                // Botón de enviar
                OasisButton(
                  text: 'Enviar calificación',
                  onPressed: _isSubmitting ? () {} : () => _submitRating(),
                  isLoading: _isSubmitting,
                )
                    .animate()
                    .fadeIn(delay: 800.ms)
                    .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
                
                const SizedBox(height: 12),
                
                // Botón de omitir
                TextButton(
                  onPressed: _isSubmitting ? null : () => context.go('/home'),
                  child: const Text('Omitir'),
                )
                    .animate()
                    .fadeIn(delay: 900.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}