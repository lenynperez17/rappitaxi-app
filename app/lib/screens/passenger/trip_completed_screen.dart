// Pantalla de viaje completado para el pasajero
// Muestra el resumen del viaje y permite calificar al conductor
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';

import '../../core/theme/modern_theme.dart';
import '../../models/trip_model.dart';
import '../shared/rating_dialog.dart';

class TripCompletedScreen extends StatefulWidget {
  final String tripId;
  final TripModel? trip;

  const TripCompletedScreen({
    super.key,
    required this.tripId,
    this.trip,
  });

  @override
  State<TripCompletedScreen> createState() => _TripCompletedScreenState();
}

class _TripCompletedScreenState extends State<TripCompletedScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  TripModel? _trip;
  bool _isLoading = true;
  bool _hasRated = false;

  late ConfettiController _confettiController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadTrip();
  }

  void _initAnimations() {
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // Iniciar animaciones después de cargar
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _fadeController.forward();
        _scaleController.forward();
        _confettiController.play();
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _loadTrip() async {
    if (widget.trip != null) {
      setState(() {
        _trip = widget.trip;
        _isLoading = false;
      });
      return;
    }

    try {
      final tripDoc = await _firestore.collection('rides').doc(widget.tripId).get();

      if (tripDoc.exists && mounted) {
        setState(() {
          _trip = TripModel.fromJson({
            'id': tripDoc.id,
            ...tripDoc.data()!,
          });
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showRatingDialog() {
    RatingDialog.show(
      context: context,
      driverName: _trip?.vehicleInfo?['driverName'] ?? 'Conductor',
      driverPhoto: _trip?.vehicleInfo?['driverPhoto'] ?? '',
      tripId: widget.tripId,
      onSubmit: (rating, comment, tags) async {
        // Guardar calificación del pasajero hacia el conductor
        await _firestore.collection('rides').doc(widget.tripId).update({
          'passengerRating': rating,
          'passengerComment': comment,
          'passengerRatingTags': tags,
          'passengerRatedAt': FieldValue.serverTimestamp(),
        });

        // También actualizar el promedio de calificaciones del conductor
        final driverId = _trip?.driverId;
        if (driverId != null && driverId.isNotEmpty) {
          await _updateDriverRating(driverId, rating.toDouble());
        }

        if (mounted) {
          setState(() {
            _hasRated = true;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Gracias por tu calificación!'),
              backgroundColor: ModernTheme.success,
            ),
          );
        }
      },
    );
  }

  Future<void> _updateDriverRating(String driverId, double newRating) async {
    try {
      // Obtener todas las calificaciones del conductor
      final ridesQuery = await _firestore
          .collection('rides')
          .where('driverId', isEqualTo: driverId)
          .where('passengerRating', isGreaterThan: 0)
          .get();

      double totalRating = 0;
      int count = 0;

      for (var doc in ridesQuery.docs) {
        final rating = (doc.data()['passengerRating'] as num?)?.toDouble() ?? 0;
        if (rating > 0) {
          totalRating += rating;
          count++;
        }
      }

      // Incluir la nueva calificación
      totalRating += newRating;
      count++;

      final averageRating = totalRating / count;

      // Actualizar en la colección de conductores
      await _firestore.collection('drivers').doc(driverId).update({
        'rating': averageRating,
        'totalRatings': count,
      });

      // También en users si existe ahí
      await _firestore.collection('users').doc(driverId).update({
        'rating': averageRating,
        'totalRatings': count,
      });
    } catch (e) {
      debugPrint('Error actualizando rating del conductor: $e');
    }
  }

  void _addTip() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildTipSheet(),
    );
  }

  Widget _buildTipSheet() {
    final tipAmounts = [2.0, 5.0, 10.0];
    double? selectedTip;

    return StatefulBuilder(
      builder: (context, setSheetState) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Agregar propina',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '¿Quieres agradecer a tu conductor con una propina?',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: tipAmounts.map((amount) {
                final isSelected = selectedTip == amount;
                return GestureDetector(
                  onTap: () => setSheetState(() => selectedTip = amount),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? ModernTheme.rappiOrange
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? ModernTheme.rappiOrange : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      'S/. ${amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : null,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: selectedTip != null
                    ? () async {
                        Navigator.pop(context);
                        await _processTip(selectedTip!);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ModernTheme.rappiOrange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Agregar propina',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('No, gracias'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processTip(double amount) async {
    try {
      // Guardar la propina en el viaje
      await _firestore.collection('rides').doc(widget.tripId).update({
        'tip': amount,
        'tipAddedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Propina de S/. ${amount.toStringAsFixed(2)} agregada!'),
            backgroundColor: ModernTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al agregar propina: $e'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo con gradiente
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  ModernTheme.rappiOrange,
                  Color(0xFF006400),
                ],
              ),
            ),
          ),

          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: 3.14 / 2, // Hacia abajo
              maxBlastForce: 5,
              minBlastForce: 1,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.1,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
                Colors.yellow,
              ],
            ),
          ),

          // Contenido
          SafeArea(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : FadeTransition(
                    opacity: _fadeAnimation,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const SizedBox(height: 40),

                          // Icono de éxito animado
                          ScaleTransition(
                            scale: _scaleAnimation,
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_circle,
                                  color: ModernTheme.success,
                                  size: 60,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Título
                          const Text(
                            '¡Viaje Completado!',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            'Gracias por viajar con Rappi Team',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),

                          const SizedBox(height: 40),

                          // Tarjeta de resumen
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Precio final
                                Text(
                                  'Total del viaje',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'S/. ${(_trip?.finalFare ?? _trip?.estimatedFare ?? 0).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: ModernTheme.rappiOrange,
                                  ),
                                ),

                                const SizedBox(height: 24),
                                const Divider(),
                                const SizedBox(height: 16),

                                // Detalles del viaje
                                _buildDetailRow(
                                  Icons.location_on,
                                  'Origen',
                                  _trip?.pickupAddress ?? 'No disponible',
                                  ModernTheme.success,
                                ),
                                const SizedBox(height: 12),
                                _buildDetailRow(
                                  Icons.flag,
                                  'Destino',
                                  _trip?.destinationAddress ?? 'No disponible',
                                  ModernTheme.error,
                                ),
                                const SizedBox(height: 12),
                                _buildDetailRow(
                                  Icons.route,
                                  'Distancia',
                                  '${((_trip?.estimatedDistance ?? 0) / 1000).toStringAsFixed(1)} km',
                                  ModernTheme.info,
                                ),
                                const SizedBox(height: 12),
                                _buildDetailRow(
                                  Icons.payments,
                                  'Método de pago',
                                  _getPaymentMethodText(),
                                  ModernTheme.rappiOrange,
                                ),

                                const SizedBox(height: 24),
                                const Divider(),
                                const SizedBox(height: 16),

                                // Info del conductor
                                if (_trip?.vehicleInfo != null) ...[
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 30,
                                        backgroundImage: _trip?.vehicleInfo?['driverPhoto'] != null
                                            ? NetworkImage(_trip!.vehicleInfo!['driverPhoto'])
                                            : null,
                                        child: _trip?.vehicleInfo?['driverPhoto'] == null
                                            ? const Icon(Icons.person, size: 30)
                                            : null,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _trip?.vehicleInfo?['driverName'] ?? 'Conductor',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Row(
                                              children: [
                                                const Icon(Icons.star, size: 16, color: Colors.amber),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${_trip?.vehicleInfo?['driverRating']?.toStringAsFixed(1) ?? '5.0'}',
                                                  style: TextStyle(
                                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              '${_trip?.vehicleInfo?['vehicleModel'] ?? ''} • ${_trip?.vehicleInfo?['vehiclePlate'] ?? ''}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Botones de acción
                          if (!_hasRated) ...[
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _showRatingDialog,
                                icon: const Icon(Icons.star),
                                label: const Text(
                                  'Calificar al conductor',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: ModernTheme.rappiOrange,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _addTip,
                              icon: const Icon(Icons.favorite),
                              label: const Text(
                                'Agregar propina',
                                style: TextStyle(fontSize: 16),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Botón para volver al inicio
                          TextButton(
                            onPressed: () {
                              // ✅ CORREGIDO: Navegar directamente al home del pasajero
                              // en lugar de popUntil que podría saltar al splash
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/passenger/home',
                                (route) => false,
                              );
                            },
                            child: const Text(
                              'Volver al inicio',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color iconColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getPaymentMethodText() {
    final method = _trip?.paymentMethod ?? 'cash';
    switch (method) {
      case 'cash':
        return 'Efectivo';
      case 'wallet':
        return 'Billetera Rappi Team';
      case 'yape_external':
        return 'Yape';
      case 'plin_external':
        return 'Plin';
      default:
        return 'Efectivo';
    }
  }
}
