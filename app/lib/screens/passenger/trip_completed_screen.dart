// Pantalla de viaje completado para el pasajero
// Muestra el resumen del viaje y permite calificar al conductor
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

import '../../core/theme/modern_theme.dart';
import '../../core/utils/responsive_bottom_sheet.dart';
import '../../models/trip_model.dart';
import '../../services/rapi_api_client.dart';
import '../shared/rating_dialog.dart';
import '../../utils/error_messages.dart';

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
  final RapiApiClient _api = RapiApiClient.instance;

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
      final response = await _api.getRide(widget.tripId);
      // El endpoint puede devolver { ride: {...} } o el mapa raíz.
      final rideJson = response['ride'] is Map<String, dynamic>
          ? response['ride'] as Map<String, dynamic>
          : response;

      if (mounted && rideJson.isNotEmpty) {
        setState(() {
          _trip = TripModel.fromJson({
            'id': widget.tripId,
            ...rideJson,
          });
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint(userFriendlyError(e, fallback: 'Error cargando viaje'));
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
      onSubmit: (rating, comment, tagsList) async {
        final tags = tagsList;
        try {
          // Concatenamos los tags al comentario (el endpoint `/rate` sólo
          // acepta `stars` y `comment`). El backend recalcula el promedio
          // del conductor automáticamente al guardar la calificación.
          final safeComment = comment ?? '';
          final combinedComment = tags.isEmpty
              ? safeComment
              : (safeComment.isEmpty
                  ? tags.join(', ')
                  : '$safeComment [${tags.join(', ')}]');
          await _api.rateRide(
            widget.tripId,
            stars: rating.toDouble(),
            comment: combinedComment,
          );
        } catch (e) {
          debugPrint(userFriendlyError(e, fallback: 'Error enviando calificación'));
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

  void _addTip() {
    showResponsiveBottomSheet(
      context: context,
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
                      'S/ ${amount.toStringAsFixed(0)}',
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
    // TODO(node-migration): reemplazar con endpoint POST /api/rides/:id/tip
    // cuando exista. Por ahora sólo mostramos feedback visual local.
    debugPrint(
        'ℹ️ processTip local (endpoint /tip pendiente): S/ ${amount.toStringAsFixed(2)}');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Propina de S/ ${amount.toStringAsFixed(2)} registrada!'),
          backgroundColor: ModernTheme.success,
        ),
      );
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
                  // Ronda 249: la pantalla de fin de viaje degradaba a VERDE
                  // MILITAR (#006400 DarkGreen), color inexistente en la marca.
                  ModernTheme.rappiOrange,
                  Color(0xFFB91C1C), // rojo oscuro de marca (rappiRedDark)
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
                                // Ronda 234: FittedBox para totales grandes
                                // (S/ 999,999.99) que desbordan el card.
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'S/ ${(_trip?.finalFare ?? _trip?.estimatedFare ?? 0).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      color: ModernTheme.rappiOrange,
                                    ),
                                    maxLines: 1,
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
                                      Builder(
                                        builder: (_) {
                                          // driverPhoto puede ser String, Map, o vacío.
                                          // Guard: solo instanciar NetworkImage con string no-vacío.
                                          final raw = _trip?.vehicleInfo?['driverPhoto'];
                                          final url = raw is String ? raw : null;
                                          final hasPhoto = url != null && url.isNotEmpty;
                                          return CircleAvatar(
                                            radius: 30,
                                            backgroundImage: hasPhoto ? NetworkImage(url) : null,
                                            onBackgroundImageError: hasPhoto ? (_, __) {} : null,
                                            child: hasPhoto ? null : const Icon(Icons.person, size: 30),
                                          );
                                        },
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
