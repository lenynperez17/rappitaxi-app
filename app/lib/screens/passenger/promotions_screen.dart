// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart'; // ✅ Extensión para colores que se adaptan al tema
import '../../core/utils/currency_formatter.dart';

import '../../utils/logger.dart';
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

  bool get isValid => status == PromotionStatus.active && validUntil.isAfter(DateTime.now());
  int get remainingUses => maxUses != null ? (maxUses! - (usedCount ?? 0)) : 999;
  int get daysRemaining => validUntil.difference(DateTime.now()).inDays;
}

class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});

  @override
  _PromotionsScreenState createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userId; // Se obtendrá del usuario actual
  bool _isLoading = true;

  late TabController _tabController;
  late AnimationController _listAnimationController;
  late AnimationController _headerAnimationController;

  final TextEditingController _promoCodeController = TextEditingController();

  // ✅ CORREGIDO: Suscripción a stream para sincronización en tiempo real
  StreamSubscription<QuerySnapshot>? _promotionsSubscription;

  // Lista de promociones desde Firebase
  List<Promotion> _promotions = [];
  
  // Loyalty program data
  final Map<String, dynamic> _loyaltyData = {
    'currentPoints': 750,
    'nextRewardPoints': 1000,
    'level': 'Gold',
    'totalTrips': 45,
    'savedAmount': 234.50,
  };
  
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
    _listAnimationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    _headerAnimationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    )..forward();
    
    _loadPromotionsFromFirebase();
  }
  
  // ✅ CORREGIDO: Usar stream en lugar de get() para sincronización en tiempo real
  void _loadPromotionsFromFirebase() {
    try {
      setState(() => _isLoading = true);

      // Obtener el ID del usuario autenticado desde Firebase Auth
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Usuario no autenticado'),
              backgroundColor: ModernTheme.error,
            ),
          );
        }
        return;
      }
      _userId = currentUser.uid;

      // ✅ CORREGIDO: Usar snapshots() para sincronización en tiempo real
      // Cuando admin crea una promoción, aparece automáticamente aquí
      _promotionsSubscription = _firestore
          .collection('promotions')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(100) // Requerido por firestore.rules
          .snapshots()
          .listen(
        (promotionsSnapshot) async {
          await _processPromotionsSnapshot(promotionsSnapshot);
        },
        onError: (e) {
          AppLogger.error('Error en stream de promociones: $e');
          if (mounted) {
            setState(() => _isLoading = false);
            _showErrorSnackBar(e);
          }
        },
      );
    } catch (e) {
      AppLogger.error('Error configurando stream de promociones: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ✅ NUEVO: Procesar snapshot de promociones (extraído para reutilizar)
  Future<void> _processPromotionsSnapshot(QuerySnapshot promotionsSnapshot) async {
    try {
      List<Promotion> loadedPromotions = [];

      for (var doc in promotionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Determinar el tipo de promocion
        PromotionType type = PromotionType.percentage;
        if (data['type'] == 'fixed') {
          type = PromotionType.fixed;
        } else if (data['type'] == 'freeRide') {
          type = PromotionType.freeRide;
        } else if (data['type'] == 'loyalty') {
          type = PromotionType.loyalty;
        }

        // Determinar el estado de la promoción
        PromotionStatus status = PromotionStatus.active;
        final validUntil = data['validUntil'] != null
            ? (data['validUntil'] as Timestamp).toDate()
            : DateTime.now().add(Duration(days: 30));

        // Verificar si el usuario ya usó esta promoción
        final userUsageDoc = await _firestore
            .collection('users')
            .doc(_userId)
            .collection('used_promotions')
            .doc(doc.id)
            .get();

        if (userUsageDoc.exists) {
          final usageData = userUsageDoc.data()!;
          final usedCount = usageData['usedCount'] ?? 0;
          final maxUses = data['maxUses'] ?? 100;

          if (usedCount >= maxUses) {
            status = PromotionStatus.used;
          }
        }

        if (validUntil.isBefore(DateTime.now())) {
          status = PromotionStatus.expired;
        }

        // Determinar el color basado en el tipo
        Color color = ModernTheme.primaryBlue;
        if (type == PromotionType.fixed) {
          color = ModernTheme.success;
        } else if (type == PromotionType.freeRide) {
          color = ModernTheme.warning;
        } else if (type == PromotionType.loyalty) {
          color = ModernTheme.rappiOrange;
        }

        loadedPromotions.add(Promotion(
          id: doc.id,
          code: data['code'] ?? '',
          title: data['title'] ?? 'Promoción',
          description: data['description'] ?? '',
          type: type,
          status: status,
          value: (data['value'] ?? data['discount'] ?? 0).toDouble(),
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

      // Actualizar estado
      if (mounted) {
        setState(() {
          _promotions = loadedPromotions;
          _isLoading = false;
        });
      }

      if (loadedPromotions.isEmpty) {
        AppLogger.info('No hay promociones disponibles en Firebase');
      } else {
        AppLogger.info('✅ ${loadedPromotions.length} promociones cargadas en tiempo real');
      }
    } catch (e) {
      AppLogger.error('Error procesando promociones: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar(e);
      }
    }
  }

  // ✅ NUEVO: Helper para mostrar errores
  void _showErrorSnackBar(dynamic e) {
    if (!mounted) return;

    final errorMessage = e.toString().contains('index') ||
            e.toString().contains('FAILED_PRECONDITION')
        ? 'Configurando base de datos. Intenta de nuevo en un momento'
        : e.toString().contains('permission') ||
                e.toString().contains('PERMISSION_DENIED')
            ? 'No tienes permisos para ver las promociones'
            : 'Error al conectar con el servidor. Verifica tu conexión';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: ModernTheme.error,
        duration: Duration(seconds: 4),
      ),
    );
  }
  
  
  @override
  void dispose() {
    // ✅ CORREGIDO: Cancelar suscripción al stream para evitar memory leaks
    _promotionsSubscription?.cancel();
    _tabController.dispose();
    _listAnimationController.dispose();
    _headerAnimationController.dispose();
    _promoCodeController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceColor,
      appBar: AppBar(
        backgroundColor: ModernTheme.rappiOrange,
        title: Text(
          'Promociones y Cupones',
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        // ✅ COMENTADO: Loyalty program hasta que se implementen datos reales
        // actions: [
        //   IconButton(
        //     icon: Icon(Icons.XXX, color: Theme.of(context).colorScheme.onPrimary),
        //     onPressed: _showLoyaltyProgram,
        //   ),
        // ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Container(
            color: ModernTheme.rappiOrange,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Theme.of(context).colorScheme.onPrimary,
              labelColor: Theme.of(context).colorScheme.onPrimary,
              unselectedLabelColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
              tabs: [
                Tab(text: 'Activas (${_activePromotions.length})'),
                Tab(text: 'Usadas (${_usedPromotions.length})'),
                Tab(text: 'Expiradas (${_expiredPromotions.length})'),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Promo code input
          _buildPromoCodeInput(),
          
          // Tab content
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
    // El TextField se pasa como child para que AnimatedBuilder no lo reconstruya
    // en cada frame ni cuando setState del stream de promociones se ejecuta
    final textFieldRow = Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _promoCodeController,
              decoration: InputDecoration(
                hintText: 'Ingresa tu código promocional',
                prefixIcon: Icon(Icons.local_offer, color: ModernTheme.rappiOrange),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: ModernTheme.rappiOrange, width: 2),
                ),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ),
          SizedBox(width: 12),
          ElevatedButton(
            onPressed: _applyPromoCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.rappiOrange,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Aplicar'),
          ),
        ],
      ),
    );

    return AnimatedBuilder(
      animation: _headerAnimationController,
      child: textFieldRow,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -50 * (1 - _headerAnimationController.value)),
          child: Opacity(
            opacity: _headerAnimationController.value,
            child: child,
          ),
        );
      },
    );
  }
  
  Widget _buildPromotionsList(List<Promotion> promotions, PromotionStatus status) {
    if (promotions.isEmpty) {
      return _buildEmptyState(status);
    }

    // Carousel horizontal con PageView
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: PageController(viewportFraction: 0.88),
            itemCount: promotions.length,
            itemBuilder: (context, index) {
              final promotion = promotions[index];
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: _buildPromotionCard(promotion),
              );
            },
          ),
        ),
        // Indicador de página
        Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(promotions.length, (i) {
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 3),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ModernTheme.rappiOrange.withValues(alpha: 0.4),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
  
  Widget _buildLoyaltyCard() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [ModernTheme.rappiOrange, ModernTheme.rappiOrange.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ModernTheme.rappiOrange.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: InkWell(
        onTap: _showLoyaltyProgram,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Programa de Fidelidad',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.surface,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Nivel ${_loyaltyData['level']}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.surface,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.star,
                      color: Theme.of(context).colorScheme.surface,
                      size: 32,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              
              // Points progress
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_loyaltyData['currentPoints']} pts',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.surface,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_loyaltyData['nextRewardPoints']} pts',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _loyaltyData['currentPoints'] / _loyaltyData['nextRewardPoints'],
                    backgroundColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Te faltan ${_loyaltyData['nextRewardPoints'] - _loyaltyData['currentPoints']} puntos para tu próxima recompensa',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 16),
              
              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLoyaltyStat('Viajes', '${_loyaltyData['totalTrips']}'),
                  Container(width: 1, height: 30, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.24)),
                  _buildLoyaltyStat('Ahorrado', CurrencyFormatter.formatCurrency((_loyaltyData['savedAmount'] as num).toDouble())),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildLoyaltyStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.surface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  Widget _buildPromotionCard(Promotion promotion) {
    final isActive = promotion.status == PromotionStatus.active;
    final isExpired = promotion.status == PromotionStatus.expired;
    final isUsed = promotion.status == PromotionStatus.used;

    return Container(
      // margin eliminado - el carousel ya maneja el espaciado
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: ModernTheme.getCardShadow(context),
        border: Border.all(
          color: isActive ? promotion.color.withValues(alpha: 0.3) : Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
          width: isActive ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: isActive ? () => _showPromotionDetails(promotion) : null,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Promotion image/header
            Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isActive 
                    ? [promotion.color, promotion.color.withValues(alpha: 0.7)]
                    : [Theme.of(context).colorScheme.onSurface.withOpacity(0.6), Theme.of(context).colorScheme.onSurface.withOpacity(0.4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Stack(
                children: [
                  // Pattern decoration
                  Positioned.fill(
                    child: CustomPaint(
                      painter: PromotionPatternPainter(
                        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  
                  // Content
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                promotion.code,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.surface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (isActive)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _getPromotionValue(promotion),
                                  style: TextStyle(
                                    color: promotion.color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          promotion.title,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.surface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  // Status overlay
                  if (isUsed || isExpired)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: Center(
                          child: Transform.rotate(
                            angle: -0.2,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              decoration: BoxDecoration(
                                color: isUsed ? ModernTheme.success : ModernTheme.error,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isUsed ? 'USADO' : 'EXPIRADO',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.surface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Promotion details
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    promotion.description,
                    style: TextStyle(
                      color: context.secondaryText,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 12),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Validity
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 16,
                            color: isActive 
                              ? (promotion.daysRemaining <= 3 ? ModernTheme.warning : context.secondaryText)
                              : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                          SizedBox(width: 4),
                          Text(
                            isActive
                              ? (promotion.daysRemaining == 0 
                                  ? 'Expira hoy'
                                  : 'Válido por ${promotion.daysRemaining} días')
                              : 'Expirado',
                            style: TextStyle(
                              color: isActive
                                ? (promotion.daysRemaining <= 3 ? ModernTheme.warning : context.secondaryText)
                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      
                      // Uses remaining
                      if (promotion.maxUses != null && isActive)
                        Row(
                          children: [
                            Icon(
                              Icons.confirmation_number,
                              size: 16,
                              color: context.secondaryText,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '${promotion.remainingUses} usos',
                              style: TextStyle(
                                color: context.secondaryText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      
                      // Action button
                      if (isActive)
                        ElevatedButton(
                          onPressed: () => _usePromotion(promotion),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: promotion.color,
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            'Usar',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                  
                  // Conditions
                  if (promotion.minAmount != null || promotion.validZones != null) ...[
                    SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (promotion.minAmount != null)
                          _buildConditionChip(
                            Icons.account_balance_wallet, // ✅ Cambiado de attach_money ($) a wallet
                            'Mín. ${promotion.minAmount!.toCurrency()}',
                          ),
                        if (promotion.validZones != null)
                          ...(promotion.validZones!.map((zone) => 
                            _buildConditionChip(Icons.location_on, zone))),
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
  
  Widget _buildConditionChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: context.secondaryText),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: context.secondaryText,
              fontSize: 11,
            ),
          ),
        ],
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
        break;
      case PromotionStatus.used:
        icon = Icons.check_circle;
        title = 'No has usado promociones';
        subtitle = 'Aprovecha las ofertas disponibles';
        break;
      case PromotionStatus.expired:
        icon = Icons.timer_off;
        title = 'No hay promociones expiradas';
        subtitle = 'Todas tus promociones están activas';
        break;
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.secondaryText,
            ),
          ),
          SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: context.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
  
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
  
  void _applyPromoCode() {
    final code = _promoCodeController.text.trim();
    if (code.isEmpty) return;

    // Buscar promoción por código (sin fallback que crashee)
    Promotion? promotion;
    try {
      promotion = _promotions.firstWhere(
        (p) => p.code.toUpperCase() == code.toUpperCase() && p.isValid,
      );
    } catch (_) {
      promotion = null;
    }

    if (promotion != null) {
      _promoCodeController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Código $code aplicado exitosamente!'),
          backgroundColor: ModernTheme.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Código inválido o expirado'),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }
  
  void _usePromotion(Promotion promotion) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              color: ModernTheme.success,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'Promoción Activada',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              promotion.title,
              style: TextStyle(
                fontSize: 16,
                color: context.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Código: ',
                    style: TextStyle(color: context.secondaryText),
                  ),
                  Text(
                    promotion.code,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Se aplicará automáticamente en tu próximo viaje',
              style: TextStyle(
                color: context.secondaryText,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.rappiOrange,
                minimumSize: Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Entendido'),
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
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.all(24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                
                // Header
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [promotion.color, promotion.color.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _getPromotionValue(promotion),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.surface,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        promotion.title,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.surface,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 24),
                
                // Description
                Text(
                  'Descripción',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  promotion.description,
                  style: TextStyle(
                    color: context.secondaryText,
                    fontSize: 14,
                  ),
                ),
                
                SizedBox(height: 24),
                
                // Terms and conditions
                Text(
                  'Términos y Condiciones',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                
                _buildTermItem('Válido hasta ${_formatDate(promotion.validUntil)}'),
                if (promotion.maxUses != null)
                  _buildTermItem('Máximo ${promotion.maxUses} usos por usuario'),
                if (promotion.minAmount != null)
                  _buildTermItem('Compra mínima de ${promotion.minAmount!.toCurrency()}'),
                if (promotion.validZones != null)
                  _buildTermItem('Válido solo en: ${promotion.validZones!.join(', ')}'),
                _buildTermItem('No acumulable con otras promociones'),
                _buildTermItem('Sujeto a disponibilidad de conductores'),
                
                SizedBox(height: 24),
                
                // Use button
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _usePromotion(promotion);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: promotion.color,
                    minimumSize: Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Usar Promoción'),
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
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 16, color: ModernTheme.success),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: context.secondaryText,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showLoyaltyProgram() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoyaltyProgramScreen(loyaltyData: _loyaltyData),
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Loyalty program screen
class LoyaltyProgramScreen extends StatelessWidget {
  final Map<String, dynamic> loyaltyData;
  
  const LoyaltyProgramScreen({super.key, required this.loyaltyData});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceColor,
      appBar: AppBar(
        backgroundColor: ModernTheme.rappiOrange,
        title: Text(
          'Programa de Fidelidad',
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Level card
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [ModernTheme.rappiOrange, ModernTheme.rappiOrange.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.star,
                    color: Theme.of(context).colorScheme.surface,
                    size: 64,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Nivel ${loyaltyData['level']}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.surface,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${loyaltyData['currentPoints']} puntos acumulados',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 24),
            
            // Benefits
            Text(
              'Beneficios de tu nivel',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            
            _buildBenefitCard(context,
              Icons.percent,
              '15% de descuento',
              'En todos tus viajes',
            ),
            _buildBenefitCard(context,
              Icons.flash_on,
              'Prioridad en horas pico',
              'Conexión más rápida con conductores',
            ),
            _buildBenefitCard(context,
              Icons.card_giftcard,
              'Promociones exclusivas',
              'Acceso anticipado a ofertas',
            ),
            _buildBenefitCard(context,
              Icons.support_agent,
              'Soporte prioritario',
              'Atención preferencial 24/7',
            ),
            
            SizedBox(height: 24),
            
            // How it works
            Text(
              'Cómo funciona',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            
            _buildHowItWorksItem(context,
              '1',
              'Acumula puntos',
              'Gana 10 puntos por cada S/ 1 gastado',
            ),
            _buildHowItWorksItem(context,
              '2',
              'Sube de nivel',
              'Alcanza nuevos niveles con más puntos',
            ),
            _buildHowItWorksItem(context,
              '3',
              'Disfruta beneficios',
              'Mejores descuentos y ventajas exclusivas',
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBenefitCard(BuildContext context, IconData icon, String title, String subtitle) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.getCardShadow(context),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: ModernTheme.rappiOrange),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: context.secondaryText,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHowItWorksItem(BuildContext context, String number, String title, String subtitle) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: ModernTheme.rappiOrange,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.surface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: context.secondaryText,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for promotion pattern
class PromotionPatternPainter extends CustomPainter {
  final Color color;
  
  const PromotionPatternPainter({super.repaint, required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    // Draw circles pattern
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