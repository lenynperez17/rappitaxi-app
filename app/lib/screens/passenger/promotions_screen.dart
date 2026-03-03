import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/design/rt_colors.dart';
import '../../core/design/rt_tokens.dart';
import '../../core/design/rt_typography.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/rt_animated_list_item.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_badge.dart';
import '../../core/widgets/rt_button.dart';
import '../../core/widgets/rt_card.dart';
import '../../core/widgets/rt_empty_state.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../core/widgets/rt_text_field.dart';
import '../../utils/logger.dart';

// ============================================================
// Modelos
// ============================================================

enum PromotionType { percentage, fixed, freeRide, loyalty }

enum PromotionStatus { active, used, expired }

class Promotion {
  final String id;
  final String code;
  final String title;
  final String description;
  final PromotionType type;
  final PromotionStatus status;
  final double value;
  final DateTime validUntil;
  final int? maxUses;
  final int? usedCount;
  final double? minAmount;
  final List<String>? validZones;
  final String imageUrl;
  final Color color;

  Promotion({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    required this.value,
    required this.validUntil,
    this.maxUses,
    this.usedCount,
    this.minAmount,
    this.validZones,
    required this.imageUrl,
    required this.color,
  });

  bool get isValid =>
      status == PromotionStatus.active && validUntil.isAfter(DateTime.now());
  int get remainingUses =>
      maxUses != null ? (maxUses! - (usedCount ?? 0)) : 999;
  int get daysRemaining => validUntil.difference(DateTime.now()).inDays;
}

// ============================================================
// Pantalla principal
// ============================================================

class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _promoCodeController = TextEditingController();

  late TabController _tabController;

  String? _userId;
  bool _isLoading = true;
  List<Promotion> _promotions = [];

  List<Promotion> get _activePromotions =>
      _promotions.where((p) => p.status == PromotionStatus.active).toList();
  List<Promotion> get _usedPromotions =>
      _promotions.where((p) => p.status == PromotionStatus.used).toList();
  List<Promotion> get _expiredPromotions =>
      _promotions.where((p) => p.status == PromotionStatus.expired).toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPromotionsFromFirebase();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _promoCodeController.dispose();
    super.dispose();
  }

  // ============================================================
  // Firebase
  // ============================================================

  Future<void> _loadPromotionsFromFirebase() async {
    try {
      setState(() => _isLoading = true);

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          RtSnackbar.show(context,
              message: 'Usuario no autenticado', type: RtSnackbarType.error);
        }
        return;
      }
      _userId = currentUser.uid;

      final promotionsSnapshot = await _firestore
          .collection('promotions')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      final List<Promotion> loadedPromotions = [];

      for (final doc in promotionsSnapshot.docs) {
        final data = doc.data();

        PromotionType type = PromotionType.percentage;
        if (data['type'] == 'fixed') {
          type = PromotionType.fixed;
        } else if (data['type'] == 'freeRide') {
          type = PromotionType.freeRide;
        } else if (data['type'] == 'loyalty') {
          type = PromotionType.loyalty;
        }

        PromotionStatus status = PromotionStatus.active;
        final validUntil = data['validUntil'] != null
            ? (data['validUntil'] as Timestamp).toDate()
            : DateTime.now().add(const Duration(days: 30));

        final userUsageDoc = await _firestore
            .collection('users')
            .doc(_userId)
            .collection('used_promotions')
            .doc(doc.id)
            .get();

        if (userUsageDoc.exists) {
          final usageData = userUsageDoc.data()!;
          final usedCount = usageData['usedCount'] ?? 0;
          final maxUses = data['maxUses'] ?? 1;
          if (usedCount >= maxUses) status = PromotionStatus.used;
        }

        if (validUntil.isBefore(DateTime.now())) {
          status = PromotionStatus.expired;
        }

        Color color = RtColors.info;
        if (type == PromotionType.fixed) {
          color = RtColors.success;
        } else if (type == PromotionType.freeRide) {
          color = RtColors.warning;
        } else if (type == PromotionType.loyalty) {
          color = RtColors.brand;
        }

        loadedPromotions.add(Promotion(
          id: doc.id,
          code: data['code'] ?? '',
          title: data['title'] ?? 'Promocion',
          description: data['description'] ?? '',
          type: type,
          status: status,
          value: (data['value'] ?? 0).toDouble(),
          validUntil: validUntil,
          maxUses: data['maxUses'],
          usedCount: data['usedCount'] ?? 0,
          minAmount: data['minAmount']?.toDouble(),
          validZones: data['validZones'] != null
              ? List<String>.from(data['validZones'])
              : null,
          imageUrl: data['imageUrl'] ?? 'assets/promo.jpg',
          color: color,
        ));
      }

      setState(() {
        _promotions = loadedPromotions;
        _isLoading = false;
      });

      if (loadedPromotions.isEmpty && mounted) {
        AppLogger.info('No hay promociones disponibles en Firebase');
      }
    } catch (e) {
      AppLogger.error('Error cargando promociones: $e');
      setState(() => _isLoading = false);
      if (!mounted) return;

      final errorStr = e.toString();
      String message;
      RtSnackbarType type;

      if (errorStr.contains('index') || errorStr.contains('FAILED_PRECONDITION')) {
        message = 'Los datos se están preparando. Intenta de nuevo en un momento';
        type = RtSnackbarType.info;
      } else if (errorStr.contains('permission') || errorStr.contains('PERMISSION_DENIED')) {
        message = 'No tienes permisos para ver las promociones';
        type = RtSnackbarType.warning;
      } else if (errorStr.contains('network') || errorStr.contains('unavailable')) {
        message = 'Sin conexión a internet. Verifica tu red';
        type = RtSnackbarType.warning;
      } else {
        message = 'Error al cargar promociones';
        type = RtSnackbarType.error;
      }

      RtSnackbar.show(context, message: message, type: type);
    }
  }

  // ============================================================
  // Helpers
  // ============================================================

  String _getPromotionValue(Promotion promotion) {
    switch (promotion.type) {
      case PromotionType.percentage:
        return '${promotion.value.toInt()}%';
      case PromotionType.fixed:
        return promotion.value.toInt().toCurrency();
      case PromotionType.freeRide:
        return 'GRATIS';
      case PromotionType.loyalty:
        return '${promotion.value.toInt()}%';
    }
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  // ============================================================
  // Acciones
  // ============================================================

  void _applyPromoCode() {
    final code = _promoCodeController.text.trim();
    if (code.isEmpty) return;

    final promotion = _promotions.firstWhere(
      (p) => p.code == code && p.isValid,
      orElse: () => _promotions.first,
    );

    if (promotion.code == code && promotion.isValid) {
      _promoCodeController.clear();
      RtSnackbar.show(context,
          message: 'Código $code aplicado exitosamente!',
          type: RtSnackbarType.success);
    } else {
      RtSnackbar.show(context,
          message: 'Código inválido o expirado', type: RtSnackbarType.error);
    }
  }

  void _usePromotion(Promotion promotion) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: RtRadius.sheetTop),
      builder: (context) => Padding(
        padding: RtSpacing.paddingXl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: RtColors.success, size: 64),
            const SizedBox(height: RtSpacing.base),
            Text('Promocion Activada', style: RtTypo.displaySmall),
            const SizedBox(height: RtSpacing.sm),
            Text(promotion.title,
                style: RtTypo.bodyMedium.copyWith(color: RtColors.neutral500),
                textAlign: TextAlign.center),
            const SizedBox(height: RtSpacing.base),
            Container(
              padding: RtSpacing.paddingBase,
              decoration: BoxDecoration(
                color: RtColors.neutral100,
                borderRadius: RtRadius.borderMd,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Código: ', style: RtTypo.bodyMedium.copyWith(color: RtColors.neutral500)),
                  Text(promotion.code, style: RtTypo.headingSmall),
                ],
              ),
            ),
            const SizedBox(height: RtSpacing.base),
            Text(
              'Se aplicara automáticamente en tu próximo viaje',
              style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: RtSpacing.xl),
            RtButton(
              label: 'Entendido',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showPromotionDetails(Promotion promotion) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: RtColors.white,
              borderRadius: RtRadius.sheetTop,
            ),
            child: ListView(
              controller: scrollController,
              padding: RtSpacing.paddingXl,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: RtSpacing.lg),
                    decoration: BoxDecoration(
                      color: RtColors.neutral300,
                      borderRadius: RtRadius.borderFull,
                    ),
                  ),
                ),
                // Header con gradiente
                Container(
                  padding: RtSpacing.paddingLg,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [promotion.color, promotion.color.withValues(alpha: 0.7)],
                    ),
                    borderRadius: RtRadius.borderLg,
                  ),
                  child: Column(
                    children: [
                      Text(
                        _getPromotionValue(promotion),
                        style: RtTypo.displayLarge.copyWith(color: RtColors.white),
                      ),
                      const SizedBox(height: RtSpacing.sm),
                      Text(
                        promotion.title,
                        style: RtTypo.headingMedium.copyWith(color: RtColors.white),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: RtSpacing.xl),
                Text('Descripción', style: RtTypo.headingSmall),
                const SizedBox(height: RtSpacing.sm),
                Text(promotion.description,
                    style: RtTypo.bodyMedium.copyWith(color: RtColors.neutral500)),
                const SizedBox(height: RtSpacing.xl),
                Text('Términos y Condiciones', style: RtTypo.headingSmall),
                const SizedBox(height: RtSpacing.md),
                _buildTermItem('Valido hasta ${_formatDate(promotion.validUntil)}'),
                if (promotion.maxUses != null)
                  _buildTermItem('Máximo ${promotion.maxUses} usos por usuario'),
                if (promotion.minAmount != null)
                  _buildTermItem('Compra minima de ${promotion.minAmount!.toCurrency()}'),
                if (promotion.validZones != null)
                  _buildTermItem('Valido solo en: ${promotion.validZones!.join(', ')}'),
                _buildTermItem('No acumulable con otras promociones'),
                _buildTermItem('Sujeto a disponibilidad de conductores'),
                const SizedBox(height: RtSpacing.xl),
                RtButton(
                  label: 'Usar Promocion',
                  onPressed: () {
                    Navigator.pop(context);
                    _usePromotion(promotion);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTermItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RtSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 16, color: RtColors.success),
          const SizedBox(width: RtSpacing.sm),
          Expanded(
            child: Text(text,
                style: RtTypo.bodyMedium.copyWith(color: RtColors.neutral500)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RtColors.neutral50,
      appBar: RtAppBar(
        title: 'Promociones y Cupones',
        variant: RtAppBarVariant.gradient,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: RtColors.white,
          labelColor: RtColors.white,
          unselectedLabelColor: RtColors.white.withValues(alpha: 0.7),
          labelStyle: RtTypo.labelLarge,
          tabs: [
            Tab(text: 'Activas (${_activePromotions.length})'),
            Tab(text: 'Usadas (${_usedPromotions.length})'),
            Tab(text: 'Expiradas (${_expiredPromotions.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildPromoCodeInput(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPromotionsList(_activePromotions, PromotionStatus.active),
                _buildPromotionsList(_usedPromotions, PromotionStatus.used),
                _buildPromotionsList(_expiredPromotions, PromotionStatus.expired),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCodeInput() {
    return Container(
      padding: RtSpacing.paddingBase,
      decoration: BoxDecoration(
        color: RtColors.white,
        boxShadow: RtShadow.soft(),
      ),
      child: Row(
        children: [
          Expanded(
            child: RtTextField(
              controller: _promoCodeController,
              hint: 'Ingresa tu código promocional',
              prefixIcon: Icons.local_offer,
              textCapitalization: TextCapitalization.characters,
            ),
          ),
          const SizedBox(width: RtSpacing.md),
          SizedBox(
            width: 100,
            child: RtButton(
              label: 'Aplicar',
              onPressed: _applyPromoCode,
              isFullWidth: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromotionsList(List<Promotion> promotions, PromotionStatus status) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: RtColors.brand),
      );
    }

    if (promotions.isEmpty) {
      return _buildEmptyState(status);
    }

    return ListView.builder(
      padding: RtSpacing.paddingBase,
      itemCount: promotions.length,
      itemBuilder: (context, index) {
        return RtAnimatedListItem(
          index: index,
          child: _buildPromotionCard(promotions[index]),
        );
      },
    );
  }

  Widget _buildPromotionCard(Promotion promotion) {
    final isActive = promotion.status == PromotionStatus.active;
    final isUsed = promotion.status == PromotionStatus.used;
    final isExpired = promotion.status == PromotionStatus.expired;

    return Padding(
      padding: const EdgeInsets.only(bottom: RtSpacing.base),
      child: RtCard(
        padding: EdgeInsets.zero,
        onTap: isActive ? () => _showPromotionDetails(promotion) : null,
        child: Column(
          children: [
            // Header con gradiente
            Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isActive
                      ? [promotion.color, promotion.color.withValues(alpha: 0.7)]
                      : [RtColors.neutral400, RtColors.neutral300],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: RtSpacing.paddingBase,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            RtBadge(
                              label: promotion.code,
                              color: RtColors.white.withValues(alpha: 0.25),
                              variant: RtBadgeVariant.filled,
                            ),
                            if (isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: RtColors.white,
                                  borderRadius: RtRadius.borderFull,
                                ),
                                child: Text(
                                  _getPromotionValue(promotion),
                                  style: RtTypo.titleLarge.copyWith(
                                    color: promotion.color,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          promotion.title,
                          style: RtTypo.headingSmall.copyWith(color: RtColors.white),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Overlay para usadas/expiradas
                  if (isUsed || isExpired)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: RtColors.black.withValues(alpha: 0.5),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12)),
                        ),
                        child: Center(
                          child: Transform.rotate(
                            angle: -0.2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 8),
                              decoration: BoxDecoration(
                                color: isUsed ? RtColors.success : RtColors.error,
                                borderRadius: RtRadius.borderSm,
                              ),
                              child: Text(
                                isUsed ? 'USADO' : 'EXPIRADO',
                                style: RtTypo.headingMedium.copyWith(color: RtColors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Detalles de la promocion
            Padding(
              padding: RtSpacing.paddingBase,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    promotion.description,
                    style: RtTypo.bodyMedium.copyWith(color: RtColors.neutral500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: RtSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 16,
                            color: isActive && promotion.daysRemaining <= 3
                                ? RtColors.warning
                                : RtColors.neutral400,
                          ),
                          const SizedBox(width: RtSpacing.xs),
                          Text(
                            isActive
                                ? (promotion.daysRemaining == 0
                                    ? 'Expira hoy'
                                    : 'Valido por ${promotion.daysRemaining}días')
                                : 'Expirado',
                            style: RtTypo.bodySmall.copyWith(
                              color: isActive && promotion.daysRemaining <= 3
                                  ? RtColors.warning
                                  : RtColors.neutral400,
                            ),
                          ),
                        ],
                      ),
                      if (promotion.maxUses != null && isActive)
                        Text(
                          '${promotion.remainingUses} usos',
                          style: RtTypo.bodySmall.copyWith(color: RtColors.neutral400),
                        ),
                      if (isActive)
                        ElevatedButton(
                          onPressed: () => _usePromotion(promotion),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: promotion.color,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: RtRadius.borderFull),
                          ),
                          child: Text('Usar', style: RtTypo.labelMedium.copyWith(color: RtColors.white)),
                        ),
                    ],
                  ),
                  if (promotion.minAmount != null || promotion.validZones != null) ...[
                    const SizedBox(height: RtSpacing.md),
                    Wrap(
                      spacing: RtSpacing.sm,
                      children: [
                        if (promotion.minAmount != null)
                          RtBadge(
                            label: 'Min. ${promotion.minAmount!.toCurrency()}',
                            icon: Icons.account_balance_wallet,
                            color: RtColors.neutral500,
                            variant: RtBadgeVariant.subtle,
                          ),
                        if (promotion.validZones != null)
                          ...promotion.validZones!.map((zone) => RtBadge(
                                label: zone,
                                icon: Icons.location_on,
                                color: RtColors.neutral500,
                                variant: RtBadgeVariant.subtle,
                              )),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(PromotionStatus status) {
    IconData icon;
    String title;
    String subtitle;

    switch (status) {
      case PromotionStatus.active:
        icon = Icons.local_offer;
        title = 'No hay promociones activas';
        subtitle = 'Vuelve pronto para ver nuevas ofertas';
      case PromotionStatus.used:
        icon = Icons.check_circle;
        title = 'No has usado promociones';
        subtitle = 'Aprovecha las ofertas disponibles';
      case PromotionStatus.expired:
        icon = Icons.timer_off;
        title = 'No hay promociones expiradas';
        subtitle = 'Todas tus promociones están activas';
    }

    return Center(
      child: RtEmptyState(icon: icon, title: title, description: subtitle),
    );
  }
}

// Painter para patron decorativo en cards de promocion
class PromotionPatternPainter extends CustomPainter {
  final Color color;

  const PromotionPatternPainter({super.repaint, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 3; j++) {
        final x = size.width * (i + 1) / 5;
        final y = size.height * (j + 1) / 4;
        canvas.drawCircle(Offset(x, y), 8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Pantalla del programa de fidelidad (conservada por compatibilidad)
class LoyaltyProgramScreen extends StatelessWidget {
  final Map<String, dynamic> loyaltyData;

  const LoyaltyProgramScreen({super.key, required this.loyaltyData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RtColors.neutral50,
      appBar: const RtAppBar(
        title: 'Programa de Fidelidad',
        variant: RtAppBarVariant.gradient,
      ),
      body: SingleChildScrollView(
        padding: RtSpacing.paddingBase,
        child: Column(
          children: [
            Container(
              padding: RtSpacing.paddingXl,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [RtColors.brand, RtColors.brand.withValues(alpha: 0.8)],
                ),
                borderRadius: RtRadius.borderLg,
              ),
              child: Column(
                children: [
                  const Icon(Icons.star, color: RtColors.white, size: 64),
                  const SizedBox(height: RtSpacing.base),
                  Text('Nivel ${loyaltyData['level']}',
                      style: RtTypo.displayMedium.copyWith(color: RtColors.white)),
                  const SizedBox(height: RtSpacing.sm),
                  Text('${loyaltyData['currentPoints']} puntos acumulados',
                      style: RtTypo.bodyLarge.copyWith(color: RtColors.white.withValues(alpha: 0.7))),
                ],
              ),
            ),
            const SizedBox(height: RtSpacing.xl),
            Text('Beneficios de tu nivel', style: RtTypo.headingMedium),
            const SizedBox(height: RtSpacing.base),
            _buildBenefitCard(context, Icons.percent, '15% de descuento',
                'En todos tus viajes'),
            _buildBenefitCard(context, Icons.flash_on, 'Prioridad en horas pico',
                'Conexión más rápida con conductores'),
            _buildBenefitCard(context, Icons.card_giftcard,
                'Promociones exclusivas', 'Acceso anticipado a ofertas'),
            _buildBenefitCard(context, Icons.support_agent,
                'Soporte prioritario', 'Atencion preferencial 24/7'),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitCard(
      BuildContext context, IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: RtSpacing.md),
      child: RtCard(
        child: Row(
          children: [
            Container(
              padding: RtSpacing.paddingMd,
              decoration: BoxDecoration(
                color: RtColors.brand.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: RtColors.brand),
            ),
            const SizedBox(width: RtSpacing.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: RtTypo.titleLarge),
                  Text(subtitle,
                      style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
