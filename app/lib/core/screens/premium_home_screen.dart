import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';

class PremiumHomeScreen extends StatefulWidget {
  const PremiumHomeScreen({super.key});

  @override
  State<PremiumHomeScreen> createState() => _PremiumHomeScreenState();
}

class _PremiumHomeScreenState extends State<PremiumHomeScreen> 
    with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late AnimationController _cardController;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _cardAnimation;
  
  int _selectedRole = 0;
  PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    _cardController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _backgroundAnimation = Tween<double>(
      begin: 0,
      end: 2,
    ).animate(_backgroundController);
    
    _cardAnimation = CurvedAnimation(
      parent: _cardController,
      curve: Curves.elasticOut,
    );
    
    // Iniciar animación de entrada
    Future.delayed(const Duration(milliseconds: 500), () {
      _cardController.forward();
    });
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _cardController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF6366F1),
              const Color(0xFF8B5CF6),
              const Color(0xFFEC4899),
              const Color(0xFFF59E0B),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Fondo animado con partículas
            _buildAnimatedBackground(),
            
            // Contenido principal
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 40),
                  _buildRoleSelector(),
                  const SizedBox(height: 32),
                  Expanded(
                    child: _buildRoleInterfaces(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _backgroundAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(
                  const Color(0xFF6366F1),
                  const Color(0xFF8B5CF6),
                  (_backgroundAnimation.value % 1),
                )!,
                Color.lerp(
                  const Color(0xFF8B5CF6),
                  const Color(0xFFEC4899),
                  (_backgroundAnimation.value % 1),
                )!,
                Color.lerp(
                  const Color(0xFFEC4899),
                  const Color(0xFFF59E0B),
                  (_backgroundAnimation.value % 1),
                )!,
              ],
            ),
          ),
          child: Stack(
            children: [
              // Partículas flotantes
              ...List.generate(15, (index) => _buildFloatingParticle(index)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFloatingParticle(int index) {
    final delay = index * 100;
    final duration = 3000 + (index * 200);
    
    return Positioned(
      left: (index * 50.0) % (MediaQuery.of(context).size.width - 20),
      top: (index * 80.0) % (MediaQuery.of(context).size.height - 100),
      child: Container(
        width: 4 + (index % 8).toDouble(),
        height: 4 + (index % 8).toDouble(),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
      )
          .animate(onPlay: (controller) => controller.repeat())
          .fadeIn(duration: Duration(milliseconds: duration))
          .moveY(
            begin: 0,
            end: -100,
            duration: Duration(milliseconds: duration),
          )
          .fadeOut(
            delay: Duration(milliseconds: duration - 500),
            duration: const Duration(milliseconds: 500),
          ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          // Logo con animación
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.local_taxi,
              color: Color(0xFF6366F1),
              size: 32,
            ),
          )
              .animate()
              .scale(delay: 200.ms, duration: 600.ms, curve: Curves.elasticOut)
              .rotate(delay: 400.ms, duration: 800.ms),
          
          const SizedBox(width: 20),
          
          // Título con animación
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RappiTaxi',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.3),
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 800.ms)
                    .slideX(begin: -0.3, delay: 300.ms, duration: 800.ms),
                
                Text(
                  'Transporte Premium',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 500.ms, duration: 800.ms)
                    .slideX(begin: -0.3, delay: 500.ms, duration: 800.ms),
              ],
            ),
          ),
          
          // Botón de notificaciones
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: IconButton(
              onPressed: () => _onNotificationTap(),
              icon: const Icon(
                Icons.notifications_outlined,
                color: Colors.white,
                size: 24,
              ),
            ),
          )
              .animate()
              .scale(delay: 600.ms, duration: 600.ms, curve: Curves.elasticOut),
        ],
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildRoleTab(0, '👤', 'Pasajero'),
          _buildRoleTab(1, '🚗', 'Conductor'),
          _buildRoleTab(2, '👨‍💼', 'Admin'),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 700.ms, duration: 800.ms)
        .slideY(begin: 0.3, delay: 700.ms, duration: 800.ms);
  }

  Widget _buildRoleTab(int index, String emoji, String label) {
    final isSelected = _selectedRole == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectRole(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected 
                ? Colors.white 
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected 
                      ? const Color(0xFF6366F1) 
                      : Colors.white.withOpacity(0.8),
                  fontWeight: isSelected 
                      ? FontWeight.bold 
                      : FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleInterfaces() {
    return AnimatedBuilder(
      animation: _cardAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _cardAnimation.value,
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _selectedRole = index;
              });
            },
            children: [
              _buildPassengerInterface(),
              _buildDriverInterface(),
              _buildAdminInterface(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPassengerInterface() {
    return Container(
      margin: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildPremiumCard(
              title: '¿A dónde quieres ir?',
              subtitle: 'Solicita tu viaje ahora',
              icon: Icons.search_outlined,
              gradient: [
                const Color(0xFF10B981),
                const Color(0xFF059669),
              ],
              onTap: () => _onSearchDestination(),
            ),
            
            const SizedBox(height: 20),
            
            _buildQuickAccessGrid([
              _buildQuickAccessCard('🏠', 'A casa', 'Av. Los Olivos 123'),
              _buildQuickAccessCard('💼', 'Al trabajo', 'Centro Empresarial'),
              _buildQuickAccessCard('✈️', 'Aeropuerto', 'Jorge Chávez'),
              _buildQuickAccessCard('🛍️', 'Mall', 'Jockey Plaza'),
            ]),
            
            const SizedBox(height: 20),
            
            _buildPremiumCard(
              title: 'Historial de viajes',
              subtitle: 'Ver todos tus viajes anteriores',
              icon: Icons.history_outlined,
              gradient: [
                const Color(0xFF8B5CF6),
                const Color(0xFF7C3AED),
              ],
              onTap: () => _onViewHistory(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverInterface() {
    return Container(
      margin: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildPremiumCard(
              title: 'Estado: EN LÍNEA',
              subtitle: 'Tiempo activo: 4h 32min',
              icon: Icons.radio_button_checked,
              gradient: [
                const Color(0xFF10B981),
                const Color(0xFF059669),
              ],
              onTap: () => _toggleDriverStatus(),
            ),
            
            const SizedBox(height: 20),
            
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'S/. 127.50',
                    'Hoy ganado',
                    Icons.monetization_on,
                    const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    '12',
                    'Viajes',
                    Icons.local_taxi,
                    const Color(0xFF6366F1),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            _buildPremiumCard(
              title: 'Solicitudes de viaje',
              subtitle: 'María González - S/. 15.40',
              icon: Icons.notifications_active,
              gradient: [
                const Color(0xFFEC4899),
                const Color(0xFFDB2777),
              ],
              onTap: () => _onViewRideRequest(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminInterface() {
    return Container(
      margin: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    '247',
                    'Viajes Activos',
                    Icons.local_taxi,
                    const Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    '89',
                    'Conductores',
                    Icons.person,
                    const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'S/. 12.4K',
                    'Ingresos Hoy',
                    Icons.monetization_on,
                    const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    '1,234',
                    'Usuarios',
                    Icons.people,
                    const Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            _buildPremiumCard(
              title: 'Dashboard Analytics',
              subtitle: 'Ver reportes completos',
              icon: Icons.analytics_outlined,
              gradient: [
                const Color(0xFF6366F1),
                const Color(0xFF4F46E5),
              ],
              onTap: () => _onViewAnalytics(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.8),
              size: 16,
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (800 + (_selectedRole * 100)).ms, duration: 600.ms)
        .slideY(begin: 0.3, delay: (800 + (_selectedRole * 100)).ms, duration: 600.ms);
  }

  Widget _buildQuickAccessGrid(List<Widget> children) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: children,
    );
  }

  Widget _buildQuickAccessCard(String emoji, String title, String subtitle) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 28,
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _selectRole(int index) {
    setState(() {
      _selectedRole = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    HapticFeedback.lightImpact();
  }

  void _onNotificationTap() {
    HapticFeedback.lightImpact();
    // TODO: Abrir notificaciones
  }

  void _onSearchDestination() {
    HapticFeedback.lightImpact();
    // TODO: Navegar a búsqueda de destino
  }

  void _onViewHistory() {
    HapticFeedback.lightImpact();
    // TODO: Navegar a historial
  }

  void _toggleDriverStatus() {
    HapticFeedback.lightImpact();
    // TODO: Cambiar estado del conductor
  }

  void _onViewRideRequest() {
    HapticFeedback.lightImpact();
    // TODO: Ver solicitud de viaje
  }

  void _onViewAnalytics() {
    HapticFeedback.lightImpact();
    // TODO: Ver analytics
  }
}