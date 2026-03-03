import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/design/design_system.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_card.dart';
import '../../core/widgets/rt_badge.dart';
import '../../core/widgets/rt_button.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../core/widgets/rt_empty_state.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/price_negotiation_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/price_negotiation_model.dart';
import '../../utils/firestore_error_handler.dart';

/// Pantalla de negociaciones para conductores.
/// Muestra las solicitudes activas donde pueden hacer ofertas.
class DriverNegotiationsScreen extends StatefulWidget {
  const DriverNegotiationsScreen({super.key});

  @override
  State<DriverNegotiationsScreen> createState() => _DriverNegotiationsScreenState();
}

class _DriverNegotiationsScreenState extends State<DriverNegotiationsScreen> {
  // Timer para actualizar el cronometro cada segundo
  Timer? _countdownTimer;

  // Stream de negociaciones en tiempo real
  StreamSubscription<QuerySnapshot>? _negotiationsSubscription;
  List<PriceNegotiation> _negotiations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _startCountdownTimer();
    _listenToNegotiations();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _negotiationsSubscription?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          // Forzar rebuild para actualizar el cronometro
        });
      }
    });
  }

  void _listenToNegotiations() {
    _negotiationsSubscription = FirebaseFirestore.instance
        .collection('negotiations')
        .where('status', whereIn: ['waiting', 'negotiating'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      final now = DateTime.now();
      final negotiations = snapshot.docs
          .map((doc) {
            try {
              final data = doc.data();

              DateTime expiresAt;
              final expiresAtRaw = data['expiresAt'];
              if (expiresAtRaw is Timestamp) {
                expiresAt = expiresAtRaw.toDate();
              } else if (expiresAtRaw is String) {
                expiresAt = DateTime.parse(expiresAtRaw);
              } else {
                expiresAt = now;
              }

              if (now.isAfter(expiresAt)) return null;

              return PriceNegotiation(
                id: doc.id,
                passengerId: data['passengerId'] ?? '',
                passengerName: data['passengerName'] ?? 'Usuario',
                passengerPhoto: data['passengerPhoto'] ?? '',
                passengerRating: (data['passengerRating'] ?? 5.0).toDouble(),
                pickup: LocationPoint(
                  latitude: (data['pickup']?['latitude'] ?? 0.0).toDouble(),
                  longitude: (data['pickup']?['longitude'] ?? 0.0).toDouble(),
                  address: data['pickup']?['address'] ?? '',
                  reference: data['pickup']?['reference'],
                ),
                destination: LocationPoint(
                  latitude: (data['destination']?['latitude'] ?? 0.0).toDouble(),
                  longitude: (data['destination']?['longitude'] ?? 0.0).toDouble(),
                  address: data['destination']?['address'] ?? '',
                  reference: data['destination']?['reference'],
                ),
                suggestedPrice: (data['suggestedPrice'] ?? 0.0).toDouble(),
                offeredPrice: (data['offeredPrice'] ?? 0.0).toDouble(),
                distance: (data['distance'] ?? 0.0).toDouble(),
                estimatedTime: data['estimatedTime'] ?? 0,
                createdAt: _parseDateTime(data['createdAt'], now),
                expiresAt: expiresAt,
                status: _parseStatus(data['status']),
                driverOffers: [],
                paymentMethod: _parsePaymentMethod(data['paymentMethod']),
                notes: data['notes'],
              );
            } catch (e) {
              debugPrint('Error parsing negotiation: $e');
              return null;
            }
          })
          .whereType<PriceNegotiation>()
          .toList();

      setState(() {
        _negotiations = negotiations;
        _isLoading = false;
      });
    }, onError: (e) {
      debugPrint('Error listening to negotiations: $e');
      setState(() => _isLoading = false);
    });
  }

  DateTime _parseDateTime(dynamic value, DateTime defaultValue) {
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is String) {
      return DateTime.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  NegotiationStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'waiting':
        return NegotiationStatus.waiting;
      case 'negotiating':
        return NegotiationStatus.negotiating;
      case 'accepted':
        return NegotiationStatus.accepted;
      case 'completed':
        return NegotiationStatus.completed;
      case 'cancelled':
        return NegotiationStatus.cancelled;
      case 'expired':
        return NegotiationStatus.expired;
      default:
        return NegotiationStatus.waiting;
    }
  }

  PaymentMethod _parsePaymentMethod(String? method) {
    switch (method?.toLowerCase()) {
      case 'card':
        return PaymentMethod.card;
      case 'wallet':
        return PaymentMethod.wallet;
      default:
        return PaymentMethod.cash;
    }
  }

  Future<void> _refreshNegotiations() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: RtAppBar(
        title: 'Solicitudes de Viaje',
        variant: RtAppBarVariant.gradient,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: RtColors.white),
            onPressed: _refreshNegotiations,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(RtColors.brand),
              ),
            )
          : _negotiations.isEmpty
              ? const RtEmptyState(
                  icon: Icons.search_off,
                  title: 'No hay solicitudes activas',
                  description: 'Las nuevas solicitudes aparecerán aquí',
                )
              : RefreshIndicator(
                  color: RtColors.brand,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  onRefresh: _refreshNegotiations,
                  child: ListView.builder(
                    padding: RtSpacing.paddingBase,
                    itemCount: _negotiations.length,
                    itemBuilder: (context, index) {
                      return _buildNegotiationCard(_negotiations[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildNegotiationCard(PriceNegotiation negotiation) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentDriverId = authProvider.currentUser?.id ?? '';
    final secondaryText = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    // Verificar si el conductor ya hizo una oferta
    final hasOffer = negotiation.driverOffers.any((offer) => offer.driverId == currentDriverId);

    return RtCard(
      margin: const EdgeInsets.only(bottom: RtSpacing.base),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Header con info del pasajero
          Container(
            padding: RtSpacing.paddingBase,
            decoration: BoxDecoration(
              color: RtColors.brand.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(RtRadius.md)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: RtColors.brandSurface,
                  backgroundImage: negotiation.passengerPhoto.isNotEmpty
                      ? NetworkImage(negotiation.passengerPhoto)
                      : null,
                  child: negotiation.passengerPhoto.isEmpty
                      ? const Icon(Icons.person, color: RtColors.brand)
                      : null,
                ),
                const SizedBox(width: RtSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        negotiation.passengerName,
                        style: RtTypo.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Icon(Icons.star, size: RtIconSize.xs, color: RtColors.warning),
                          const SizedBox(width: RtSpacing.xs),
                          Text(
                            negotiation.passengerRating.toStringAsFixed(1),
                            style: RtTypo.bodySmall.copyWith(color: secondaryText),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildTimer(negotiation),
              ],
            ),
          ),

          // Detalles del viaje
          Padding(
            padding: RtSpacing.paddingBase,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Origen
                _buildLocationRow(
                  icon: Icons.radio_button_checked,
                  color: RtColors.success,
                  label: 'Origen',
                  address: negotiation.pickup.address,
                  secondaryText: secondaryText,
                ),
                const SizedBox(height: RtSpacing.md),

                // Destino
                _buildLocationRow(
                  icon: Icons.location_on,
                  color: RtColors.error,
                  label: 'Destino',
                  address: negotiation.destination.address,
                  secondaryText: secondaryText,
                ),
                const SizedBox(height: RtSpacing.base),

                // Info del viaje
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoChip(
                        icon: Icons.route,
                        label: '${negotiation.distance.toStringAsFixed(1)} km',
                        secondaryText: secondaryText,
                      ),
                    ),
                    const SizedBox(width: RtSpacing.sm),
                    Expanded(
                      child: _buildInfoChip(
                        icon: Icons.schedule,
                        label: '${negotiation.estimatedTime} min',
                        secondaryText: secondaryText,
                      ),
                    ),
                    const SizedBox(width: RtSpacing.sm),
                    Expanded(
                      child: _buildInfoChip(
                        icon: Icons.payments,
                        label: _getPaymentMethodText(negotiation.paymentMethod),
                        secondaryText: secondaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: RtSpacing.base),

                // Precio ofrecido por el pasajero
                Container(
                  padding: const EdgeInsets.all(RtSpacing.md),
                  decoration: BoxDecoration(
                    color: RtColors.brand.withValues(alpha: 0.08),
                    borderRadius: RtRadius.borderMd,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Precio ofrecido:', style: RtTypo.titleMedium),
                      Text(
                        negotiation.offeredPrice.toCurrency(),
                        style: RtTypo.headingMedium.copyWith(color: RtColors.brand),
                      ),
                    ],
                  ),
                ),

                if (negotiation.notes != null && negotiation.notes!.isNotEmpty) ...[
                  const SizedBox(height: RtSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(RtSpacing.md),
                    decoration: BoxDecoration(
                      color: RtColors.neutral100,
                      borderRadius: RtRadius.borderMd,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.notes, size: RtIconSize.xs, color: secondaryText),
                        const SizedBox(width: RtSpacing.sm),
                        Expanded(
                          child: Text(
                            negotiation.notes!,
                            style: RtTypo.bodySmall.copyWith(color: secondaryText),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: RtSpacing.base),

                // Boton de accion
                if (!hasOffer)
                  RtButton(
                    label: 'Hacer una oferta',
                    onPressed: () => _showOfferDialog(negotiation),
                    size: RtButtonSize.large,
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(RtSpacing.md),
                    decoration: BoxDecoration(
                      color: RtColors.success.withValues(alpha: 0.1),
                      borderRadius: RtRadius.borderMd,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle, color: RtColors.success),
                        const SizedBox(width: RtSpacing.sm),
                        Text(
                          'Ya realizaste una oferta',
                          style: RtTypo.titleMedium.copyWith(color: RtColors.success, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimer(PriceNegotiation negotiation) {
    final remaining = negotiation.timeRemaining;

    if (remaining.isNegative || remaining.inSeconds <= 0) {
      return RtBadge(
        label: 'Expirado',
        color: RtColors.error,
        icon: Icons.timer_off,
      );
    }

    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: RtSpacing.md, vertical: RtSpacing.sm),
      decoration: BoxDecoration(
        color: minutes < 2 ? RtColors.error : RtColors.warning,
        borderRadius: RtRadius.borderFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, size: RtIconSize.xs, color: RtColors.white),
          const SizedBox(width: RtSpacing.xs),
          Text(
            '$minutes:${seconds.toString().padLeft(2, '0')}',
            style: RtTypo.labelMedium.copyWith(color: RtColors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color color,
    required String label,
    required String address,
    required Color secondaryText,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: RtIconSize.sm),
        const SizedBox(width: RtSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: RtTypo.labelSmall.copyWith(color: secondaryText, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(address, style: RtTypo.titleMedium),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label, required Color secondaryText}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: RtSpacing.sm, vertical: RtSpacing.sm),
      decoration: BoxDecoration(
        color: RtColors.neutral100,
        borderRadius: RtRadius.borderSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: RtIconSize.xs, color: secondaryText),
          const SizedBox(width: RtSpacing.xs),
          Flexible(
            child: Text(
              label,
              style: RtTypo.labelSmall.copyWith(color: secondaryText, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _getPaymentMethodText(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Efectivo';
      case PaymentMethod.card:
        return 'Tarjeta';
      case PaymentMethod.wallet:
        return 'Wallet';
    }
  }

  void _showOfferDialog(PriceNegotiation negotiation) {
    final priceController = TextEditingController(
      text: negotiation.offeredPrice.toStringAsFixed(2),
    );
    final secondaryText = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
        title: Text('Hacer una oferta', style: RtTypo.headingSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Precio sugerido: ${negotiation.suggestedPrice.toCurrency()}',
              style: RtTypo.bodyMedium.copyWith(color: secondaryText),
            ),
            Text(
              'Precio del pasajero: ${negotiation.offeredPrice.toCurrency()}',
              style: RtTypo.titleMedium,
            ),
            const SizedBox(height: RtSpacing.base),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Tu precio',
                prefixText: '${AppConstants.currencySymbol} ',
                border: OutlineInputBorder(borderRadius: RtRadius.borderSm),
              ),
            ),
            const SizedBox(height: RtSpacing.sm),
            Text(
              'Ingresa el precio al que estas dispuesto a aceptar este viaje',
              style: RtTypo.bodySmall.copyWith(color: secondaryText),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final price = double.tryParse(priceController.text);
              if (price == null || price <= 0) {
                if (dialogContext.mounted) {
                  RtSnackbar.show(dialogContext, message: 'Ingresa un precio válido', type: RtSnackbarType.warning);
                }
                return;
              }

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }

              if (!context.mounted) return;

              final provider = Provider.of<PriceNegotiationProvider>(
                context,
                listen: false,
              );
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              try {
                final error = await provider.makeDriverOffer(negotiation.id, price);

                if (mounted) {
                  if (error != null) {
                    RtSnackbar.show(context, message: error, type: RtSnackbarType.error);
                    if (error.contains('Saldo')) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(error),
                          backgroundColor: RtColors.error,
                          duration: const Duration(seconds: 5),
                          action: SnackBarAction(
                            label: 'Recargar',
                            textColor: RtColors.white,
                            onPressed: () {
                              Navigator.pushNamed(context, '/driver/wallet');
                            },
                          ),
                        ),
                      );
                    }
                  } else {
                    RtSnackbar.show(context, message: 'Oferta enviada exitosamente', type: RtSnackbarType.success);
                  }
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
            },
            style: ElevatedButton.styleFrom(backgroundColor: RtColors.brand),
            child: const Text('Enviar oferta'),
          ),
        ],
      ),
    );
  }
}
