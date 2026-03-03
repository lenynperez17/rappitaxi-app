import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../../core/design/design_system.dart';
import '../../core/widgets/rt_avatar.dart';
import '../../core/widgets/rt_button.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../models/trip_model.dart';
import '../../utils/firestore_error_handler.dart';
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
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    _fadeController = AnimationController(
      duration: RtDuration.emphasis,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: RtCurve.emphasis),
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: RtCurve.bounce),
    );

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
      final tripDoc = await _firestore
          .collection('rides')
          .doc(widget.tripId)
          .get();

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
        setState(() => _isLoading = false);
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
        await _firestore.collection('rides').doc(widget.tripId).update({
          'passengerRating': rating,
          'passengerComment': comment,
          'passengerRatingTags': tags,
          'passengerRatedAt': FieldValue.serverTimestamp(),
        });

        final driverId = _trip?.driverId;
        if (driverId != null && driverId.isNotEmpty) {
          await _updateDriverRating(driverId, rating.toDouble());
        }

        if (mounted) {
          setState(() => _hasRated = true);
          RtSnackbar.show(
            context,
            message: 'Gracias por tu calificación!',
            type: RtSnackbarType.success,
          );
        }
      },
    );
  }

  Future<void> _updateDriverRating(String driverId, double newRating) async {
    try {
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

      totalRating += newRating;
      count++;

      final averageRating = totalRating / count;

      await _firestore.collection('drivers').doc(driverId).update({
        'rating': averageRating,
        'totalRatings': count,
      });

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
      shape: RoundedRectangleBorder(borderRadius: RtRadius.sheetTop),
      builder: (context) => _buildTipSheet(),
    );
  }

  Widget _buildTipSheet() {
    final tipAmounts = [2.0, 5.0, 10.0];
    double? selectedTip;

    return StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: const EdgeInsets.all(RtSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Agregar propina', style: RtTypo.headingMedium),
            const SizedBox(height: RtSpacing.sm),
            Text(
              'Quieres agradecer a tu conductor con una propina?',
              style: RtTypo.bodyMedium.copyWith(color: RtColors.neutral500),
            ),
            const SizedBox(height: RtSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: tipAmounts.map((amount) {
                final isSelected = selectedTip == amount;
                return GestureDetector(
                  onTap: () => setSheetState(() => selectedTip = amount),
                  child: AnimatedContainer(
                    duration: RtDuration.fast,
                    padding: const EdgeInsets.symmetric(
                      horizontal: RtSpacing.xl,
                      vertical: RtSpacing.base,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? RtColors.brand : RtColors.neutral100,
                      borderRadius: RtRadius.borderLg,
                      border: Border.all(
                        color: isSelected ? RtColors.brand : RtColors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      'S/. ${amount.toStringAsFixed(0)}',
                      style: RtTypo.headingSmall.copyWith(
                        color: isSelected ? RtColors.white : RtColors.neutral900,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: RtSpacing.xl),
            RtButton(
              label: 'Agregar propina',
              onPressed: selectedTip != null
                  ? () async {
                      Navigator.pop(context);
                      await _processTip(selectedTip!);
                    }
                  : null,
              size: RtButtonSize.large,
            ),
            const SizedBox(height: RtSpacing.md),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'No, gracias',
                  style: RtTypo.labelLarge.copyWith(color: RtColors.neutral500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processTip(double amount) async {
    try {
      await _firestore.collection('rides').doc(widget.tripId).update({
        'tip': amount,
        'tipAddedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        RtSnackbar.show(
          context,
          message: 'Propina de S/. ${amount.toStringAsFixed(2)} agregada!',
          type: RtSnackbarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        RtSnackbar.show(
          context,
          message: FirestoreErrorHandler.getSpanishMessage(e),
          type: RtSnackbarType.error,
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
                colors: [RtColors.brand, RtColors.brandDark],
              ),
            ),
          ),

          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: 3.14 / 2,
              maxBlastForce: 5,
              minBlastForce: 1,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.1,
              shouldLoop: false,
              colors: const [
                RtColors.success,
                RtColors.info,
                RtColors.brandLight,
                RtColors.warning,
                RtColors.accentPurple,
                RtColors.accentAmber,
              ],
            ),
          ),

          // Contenido
          SafeArea(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: RtColors.white),
                  )
                : FadeTransition(
                    opacity: _fadeAnimation,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(RtSpacing.xl),
                      child: Column(
                        children: [
                          const SizedBox(height: 40),

                          // Icono de éxito animado
                          ScaleTransition(
                            scale: _scaleAnimation,
                            child: Container(
                              padding: const EdgeInsets.all(RtSpacing.xl),
                              decoration: BoxDecoration(
                                color: RtColors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(RtSpacing.lg),
                                decoration: const BoxDecoration(
                                  color: RtColors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_circle,
                                  color: RtColors.success,
                                  size: 60,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: RtSpacing.xxl),

                          // Titulo
                          Text(
                            'Viaje Completado!',
                            style: RtTypo.displayMedium.copyWith(
                              color: RtColors.white,
                            ),
                          ),

                          const SizedBox(height: RtSpacing.sm),

                          Text(
                            'Gracias por viajar con RapiTeam',
                            style: RtTypo.bodyLarge.copyWith(
                              color: RtColors.white.withValues(alpha: 0.9),
                            ),
                          ),

                          const SizedBox(height: RtSpacing.xxxl),

                          // Tarjeta de resumen
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(RtSpacing.xl),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: RtRadius.borderXl,
                              boxShadow: RtShadow.strong(),
                            ),
                            child: Column(
                              children: [
                                // Precio final
                                Text(
                                  'Total del viaje',
                                  style: RtTypo.bodyMedium.copyWith(
                                    color: RtColors.neutral500,
                                  ),
                                ),
                                const SizedBox(height: RtSpacing.sm),
                                Text(
                                  'S/. ${(_trip?.finalFare ?? _trip?.estimatedFare ?? 0).toStringAsFixed(2)}',
                                  style: RtTypo.displayLarge.copyWith(
                                    color: RtColors.brand,
                                    fontSize: 40,
                                  ),
                                ),

                                const SizedBox(height: RtSpacing.xl),
                                const Divider(),
                                const SizedBox(height: RtSpacing.base),

                                // Detalles del viaje
                                _buildDetailRow(
                                  Icons.location_on,
                                  'Origen',
                                  _trip?.pickupAddress ?? 'No disponible',
                                  RtColors.success,
                                ),
                                const SizedBox(height: RtSpacing.md),
                                _buildDetailRow(
                                  Icons.flag,
                                  'Destino',
                                  _trip?.destinationAddress ?? 'No disponible',
                                  RtColors.error,
                                ),
                                const SizedBox(height: RtSpacing.md),
                                _buildDetailRow(
                                  Icons.route,
                                  'Distancia',
                                  '${((_trip?.estimatedDistance ?? 0) / 1000).toStringAsFixed(1)} km',
                                  RtColors.info,
                                ),
                                const SizedBox(height: RtSpacing.md),
                                _buildDetailRow(
                                  Icons.payments,
                                  'Método de pago',
                                  _getPaymentMethodText(),
                                  RtColors.brand,
                                ),

                                const SizedBox(height: RtSpacing.xl),
                                const Divider(),
                                const SizedBox(height: RtSpacing.base),

                                // Info del conductor
                                if (_trip?.vehicleInfo != null) ...[
                                  Row(
                                    children: [
                                      RtAvatar(
                                        imageUrl: _trip?.vehicleInfo?['driverPhoto'],
                                        name: _trip?.vehicleInfo?['driverName'] ?? 'Conductor',
                                        size: RtAvatarSize.large,
                                      ),
                                      const SizedBox(width: RtSpacing.base),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _trip?.vehicleInfo?['driverName'] ?? 'Conductor',
                                              style: RtTypo.headingSmall,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.star,
                                                  size: RtIconSize.xs,
                                                  color: RtColors.warning,
                                                ),
                                                const SizedBox(width: RtSpacing.xs),
                                                Text(
                                                  '${_trip?.vehicleInfo?['driverRating']?.toStringAsFixed(1) ?? '5.0'}',
                                                  style: RtTypo.bodyMedium.copyWith(
                                                    color: RtColors.neutral500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              '${_trip?.vehicleInfo?['vehicleModel'] ?? ''} - ${_trip?.vehicleInfo?['vehiclePlate'] ?? ''}',
                                              style: RtTypo.bodySmall.copyWith(
                                                color: RtColors.neutral500,
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

                          const SizedBox(height: RtSpacing.xl),

                          // Botones de accion
                          if (!_hasRated) ...[
                            RtButton(
                              label: 'Calificar al conductor',
                              icon: Icons.star,
                              onPressed: _showRatingDialog,
                              variant: RtButtonVariant.secondary,
                              size: RtButtonSize.large,
                            ),
                            const SizedBox(height: RtSpacing.md),
                          ],

                          RtButton(
                            label: 'Agregar propina',
                            icon: Icons.favorite,
                            onPressed: _addTip,
                            variant: RtButtonVariant.outlined,
                            size: RtButtonSize.large,
                          ),

                          const SizedBox(height: RtSpacing.xl),

                          // Boton para volver al inicio
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/passenger/home',
                                (route) => false,
                              );
                            },
                            child: Text(
                              'Volver al inicio',
                              style: RtTypo.titleLarge.copyWith(
                                color: RtColors.white,
                                decoration: TextDecoration.underline,
                                decorationColor: RtColors.white,
                              ),
                            ),
                          ),

                          const SizedBox(height: RtSpacing.lg),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    Color iconColor,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(RtSpacing.sm),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: RtRadius.borderSm,
          ),
          child: Icon(icon, size: RtIconSize.sm, color: iconColor),
        ),
        const SizedBox(width: RtSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: RtTypo.labelSmall.copyWith(color: RtColors.neutral500),
              ),
              Text(
                value,
                style: RtTypo.titleMedium,
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
        return 'Billetera RapiTeam';
      case 'yape_external':
        return 'Yape';
      case 'plin_external':
        return 'Plin';
      default:
        return 'Efectivo';
    }
  }
}
