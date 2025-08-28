import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../widgets/oasis_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'Bienvenido a Rappi Taxi',
      description: 'Tu servicio de transporte seguro y confiable en la ciudad.',
      icon: Icons.local_taxi,
    ),
    OnboardingData(
      title: 'Viaja con seguridad',
      description: 'Conductores verificados y seguimiento en tiempo real de tu viaje.',
      icon: Icons.security,
    ),
    OnboardingData(
      title: 'Paga como prefieras',
      description: 'Efectivo, tarjeta o billetera digital. Tú eliges.',
      icon: Icons.payment,
    ),
  ];
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  
  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }
  
  void _skip() {
    context.go('/auth/login');
  }
  
  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _skip();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _skip,
                child: const Text('Omitir'),
              ),
            ),
            
            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index], index);
                },
              ),
            ),
            
            // Indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? AppTheme.primaryColor
                        : AppTheme.primaryColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                )
                    .animate(target: _currentPage == index ? 1 : 0)
                    .scaleX(end: 3, duration: 200.ms),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Next button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: OasisButton(
                text: _currentPage == _pages.length - 1 ? 'Comenzar' : 'Siguiente',
                onPressed: _next,
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPage(OnboardingData data, int index) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              data.icon,
              size: 60,
              color: AppTheme.primaryColor,
            ),
          )
              .animate()
              .scale(
                delay: Duration(milliseconds: index * 100),
                duration: 600.ms,
                curve: Curves.elasticOut,
              ),
          
          const SizedBox(height: 48),
          
          // Title
          Text(
            data.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(delay: Duration(milliseconds: index * 100 + 200)),
          
          const SizedBox(height: 16),
          
          // Description
          Text(
            data.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.textSecondaryColor,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(delay: Duration(milliseconds: index * 100 + 400)),
        ],
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String description;
  final IconData icon;
  
  const OnboardingData({
    required this.title,
    required this.description,
    required this.icon,
  });
}