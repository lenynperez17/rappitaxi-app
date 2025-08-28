import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/oasis_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// Models para referidos y promociones
class ReferralData {
  final String userId;
  final String referralCode;
  final int totalReferrals;
  final double totalEarnings;
  final List<ReferralInvite> invites;
  final List<Promotion> activePromotions;

  ReferralData({
    required this.userId,
    required this.referralCode,
    required this.totalReferrals,
    required this.totalEarnings,
    required this.invites,
    required this.activePromotions,
  });
}

class ReferralInvite {
  final String id;
  final String name;
  final String phone;
  final DateTime inviteDate;
  final ReferralStatus status;
  final double earnings;

  ReferralInvite({
    required this.id,
    required this.name,
    required this.phone,
    required this.inviteDate,
    required this.status,
    required this.earnings,
  });
}

class Promotion {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final DateTime expiryDate;
  final String promoCode;
  final double discount;
  final PromotionType type;
  final bool isActive;

  Promotion({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.expiryDate,
    required this.promoCode,
    required this.discount,
    required this.type,
    required this.isActive,
  });
}

enum ReferralStatus { pending, completed, expired }
enum PromotionType { discount, freeRide, cashback, referralBonus }

// Providers
final referralDataProvider = StateProvider<ReferralData?>((ref) => null);

class ReferralsScreen extends ConsumerStatefulWidget {
  const ReferralsScreen({super.key});

  @override
  ConsumerState<ReferralsScreen> createState() => _ReferralsScreenState();
}

class _ReferralsScreenState extends ConsumerState<ReferralsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _phoneController = TextEditingController();

  // Datos simulados para demo
  late ReferralData _mockReferralData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeMockData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _initializeMockData() {
    final currentUser = ref.read(currentUserProvider);
    _mockReferralData = ReferralData(
      userId: currentUser?.id ?? 'user_123',
      referralCode: 'TAXI${currentUser?.name?.substring(0, 3)?.toUpperCase() ?? 'USR'}2024',
      totalReferrals: 8,
      totalEarnings: 120.50,
      invites: [
        ReferralInvite(
          id: '1',
          name: 'María González',
          phone: '+51 987 654 321',
          inviteDate: DateTime.now().subtract(const Duration(days: 5)),
          status: ReferralStatus.completed,
          earnings: 25.0,
        ),
        ReferralInvite(
          id: '2',
          name: 'Carlos Pérez',
          phone: '+51 987 654 322',
          inviteDate: DateTime.now().subtract(const Duration(days: 3)),
          status: ReferralStatus.pending,
          earnings: 0.0,
        ),
        ReferralInvite(
          id: '3',
          name: 'Ana Rodriguez',
          phone: '+51 987 654 323',
          inviteDate: DateTime.now().subtract(const Duration(days: 1)),
          status: ReferralStatus.completed,
          earnings: 25.0,
        ),
      ],
      activePromotions: [
        Promotion(
          id: '1',
          title: '¡Primera viaje GRATIS!',
          description: 'Nuevo usuario obtiene su primer viaje completamente gratis hasta S/20',
          imageUrl: '',
          expiryDate: DateTime.now().add(const Duration(days: 30)),
          promoCode: 'PRIMEROVIAJE',
          discount: 20.0,
          type: PromotionType.freeRide,
          isActive: true,
        ),
        Promotion(
          id: '2',
          title: 'Descuento del 50%',
          description: 'Obtén 50% de descuento en tu próximo viaje',
          imageUrl: '',
          expiryDate: DateTime.now().add(const Duration(days: 15)),
          promoCode: 'DESCUENTO50',
          discount: 50.0,
          type: PromotionType.discount,
          isActive: true,
        ),
        Promotion(
          id: '3',
          title: 'Cashback S/15',
          description: 'Recibe S/15 de vuelta por cada amigo que complete 3 viajes',
          imageUrl: '',
          expiryDate: DateTime.now().add(const Duration(days: 45)),
          promoCode: 'CASHBACK15',
          discount: 15.0,
          type: PromotionType.cashback,
          isActive: true,
        ),
      ],
    );
    
    ref.read(referralDataProvider.notifier).state = _mockReferralData;
  }

  void _copyReferralCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Código copiado: $code'),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareReferralCode(String code) {
    final message = '''
¡Únete a RappiTaxi con mi código! 🚕

Usa mi código de invitación: $code

✅ Tu primer viaje GRATIS (hasta S/20)
✅ Servicio confiable 24/7
✅ Los mejores conductores

Descarga la app: https://rappitaxi.app/download
    ''';

    // En un proyecto real usarías share_plus
    _copyReferralCode(message);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mensaje de invitación copiado'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  void _inviteFriend() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildInviteFriendBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final referralData = ref.watch(referralDataProvider) ?? _mockReferralData;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Invita y Gana'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.card_giftcard), text: 'Referir'),
            Tab(icon: Icon(Icons.people), text: 'Mis Invitados'),
            Tab(icon: Icon(Icons.local_offer), text: 'Promociones'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReferralTab(referralData),
          _buildInvitesTab(referralData),
          _buildPromotionsTab(referralData),
        ],
      ),
    );
  }

  Widget _buildReferralTab(ReferralData referralData) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header con estadísticas
          _buildReferralHeader(referralData),
          
          const SizedBox(height: 24),
          
          // Código de referido
          _buildReferralCodeSection(referralData.referralCode),
          
          const SizedBox(height: 24),
          
          // QR Code
          _buildQRSection(referralData.referralCode),
          
          const SizedBox(height: 24),
          
          // Cómo funciona
          _buildHowItWorksSection(),
          
          const SizedBox(height: 24),
          
          // Botones de acción
          _buildActionButtons(referralData.referralCode),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildReferralHeader(ReferralData referralData) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.monetization_on,
                  color: AppTheme.primaryColor,
                  size: 30,
                ),
              ),
              
              const SizedBox(width: 16),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '¡Invita amigos y gana!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'S/25 por cada amigo que se una',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Amigos invitados',
                  referralData.totalReferrals.toString(),
                  Icons.people,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Total ganado',
                  'S/ ${referralData.totalEarnings.toStringAsFixed(2)}',
                  Icons.account_balance_wallet,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.1, end: 0);
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReferralCodeSection(String referralCode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tu código de invitación',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 12),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        referralCode,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Comparte este código con tus amigos',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _copyReferralCode(referralCode),
                  icon: const Icon(Icons.copy),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.2, end: 0),
        ],
      ),
    );
  }

  Widget _buildQRSection(String referralCode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const Text(
            'Código QR',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                QrImageView(
                  data: referralCode,
                  version: QrVersions.auto,
                  size: 150,
                  foregroundColor: AppTheme.primaryColor,
                ),
                const SizedBox(height: 12),
                Text(
                  'Escanea para usar mi código',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 400.ms).scale(),
        ],
      ),
    );
  }

  Widget _buildHowItWorksSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¿Cómo funciona?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildHowItWorksStep(
                  1,
                  'Comparte tu código',
                  'Envía tu código o QR a amigos y familia',
                  Icons.share,
                  AppTheme.primaryColor,
                ),
                _buildHowItWorksStep(
                  2,
                  'Tu amigo se registra',
                  'Se registra con tu código y toma su primer viaje',
                  Icons.person_add,
                  AppTheme.successColor,
                ),
                _buildHowItWorksStep(
                  3,
                  '¡Ambos ganan!',
                  'Recibes S/25 y tu amigo viaja gratis',
                  Icons.celebration,
                  AppTheme.earningsColor,
                  isLast: true,
                ),
              ],
            ),
          ).animate().fadeIn(delay: 600.ms),
        ],
      ),
    );
  }

  Widget _buildHowItWorksStep(
    int step,
    String title,
    String description,
    IconData icon,
    Color color, {
    bool isLast = false,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: step <= 2
                    ? Text(
                        step.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      )
                    : Icon(
                        icon,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
            
            const SizedBox(width: 16),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!isLast) ...[
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.only(left: 20),
            width: 2,
            height: 20,
            color: color.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildActionButtons(String referralCode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          OasisButton(
            text: 'Invitar amigos',
            onPressed: _inviteFriend,
            icon: const Icon(Icons.person_add),
          ).animate().fadeIn(delay: 800.ms),
          
          const SizedBox(height: 12),
          
          OasisButton(
            text: 'Compartir código',
            onPressed: () => _shareReferralCode(referralCode),
            isOutlined: true,
            icon: const Icon(Icons.share),
          ).animate().fadeIn(delay: 900.ms),
        ],
      ),
    );
  }

  Widget _buildInvitesTab(ReferralData referralData) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mis invitaciones (${referralData.invites.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: _inviteFriend,
                icon: const Icon(Icons.add),
                label: const Text('Invitar'),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Expanded(
            child: referralData.invites.isEmpty
                ? _buildEmptyInvites()
                : ListView.builder(
                    itemCount: referralData.invites.length,
                    itemBuilder: (context, index) {
                      final invite = referralData.invites[index];
                      return _buildInviteCard(invite);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyInvites() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No has invitado a nadie aún',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '¡Invita a tus amigos y empieza a ganar!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          OasisButton(
            text: 'Invitar amigos',
            onPressed: _inviteFriend,
          ),
        ],
      ),
    );
  }

  Widget _buildInviteCard(ReferralInvite invite) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: _getStatusColor(invite.status).withOpacity(0.1),
            child: Text(
              invite.name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: _getStatusColor(invite.status),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  invite.phone,
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(invite.inviteDate),
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(invite.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getStatusText(invite.status),
                  style: TextStyle(
                    color: _getStatusColor(invite.status),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (invite.status == ReferralStatus.completed) ...[
                const SizedBox(height: 8),
                Text(
                  'S/ ${invite.earnings.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppTheme.earningsColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPromotionsTab(ReferralData referralData) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Promociones activas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 16),
          
          Expanded(
            child: ListView.builder(
              itemCount: referralData.activePromotions.length,
              itemBuilder: (context, index) {
                final promotion = referralData.activePromotions[index];
                return _buildPromotionCard(promotion);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromotionCard(Promotion promotion) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: _getPromotionGradient(promotion.type),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getPromotionIcon(promotion.type),
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            promotion.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Código: ${promotion.promoCode}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                Text(
                  promotion.description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Expira: ${_formatDate(promotion.expiryDate)}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _copyReferralCode(promotion.promoCode),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: const Text(
                        'Copiar código',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 100 * referralData.activePromotions.indexOf(promotion)));
  }

  Widget _buildInviteFriendBottomSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            const SizedBox(height: 20),
            
            const Text(
              'Invitar amigo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 20),
            
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Número de teléfono',
                hintText: '+51 987 654 321',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            Row(
              children: [
                Expanded(
                  child: OasisButton(
                    text: 'Enviar invitación',
                    onPressed: () {
                      if (_phoneController.text.isNotEmpty) {
                        Navigator.pop(context);
                        _sendInvitation(_phoneController.text);
                        _phoneController.clear();
                      }
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _sendInvitation(String phoneNumber) {
    // Simular envío de invitación
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invitación enviada a $phoneNumber'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
    
    // En un proyecto real, aquí llamarías al backend
    // await _referralService.sendInvitation(phoneNumber);
  }

  Color _getStatusColor(ReferralStatus status) {
    switch (status) {
      case ReferralStatus.pending:
        return AppTheme.warningColor;
      case ReferralStatus.completed:
        return AppTheme.successColor;
      case ReferralStatus.expired:
        return AppTheme.errorColor;
    }
  }

  String _getStatusText(ReferralStatus status) {
    switch (status) {
      case ReferralStatus.pending:
        return 'Pendiente';
      case ReferralStatus.completed:
        return 'Completado';
      case ReferralStatus.expired:
        return 'Expirado';
    }
  }

  LinearGradient _getPromotionGradient(PromotionType type) {
    switch (type) {
      case PromotionType.freeRide:
        return LinearGradient(
          colors: [AppTheme.successColor, AppTheme.successColor.withOpacity(0.8)],
        );
      case PromotionType.discount:
        return LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.8)],
        );
      case PromotionType.cashback:
        return LinearGradient(
          colors: [AppTheme.earningsColor, AppTheme.earningsColor.withOpacity(0.8)],
        );
      case PromotionType.referralBonus:
        return LinearGradient(
          colors: [AppTheme.accentColor, AppTheme.accentColor.withOpacity(0.8)],
        );
    }
  }

  IconData _getPromotionIcon(PromotionType type) {
    switch (type) {
      case PromotionType.freeRide:
        return Icons.directions_car;
      case PromotionType.discount:
        return Icons.local_offer;
      case PromotionType.cashback:
        return Icons.account_balance_wallet;
      case PromotionType.referralBonus:
        return Icons.card_giftcard;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Hoy';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}