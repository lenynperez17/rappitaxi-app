import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }
  
  Future<void> _initialize() async {
    // Simular carga de recursos
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      // TODO: Verificar si es primera vez
      // Por ahora siempre ir a login
      context.go('/auth/login');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo_rappi_taxi.png',
                  fit: BoxFit.cover,
                ),
              ),
            )
                .animate()
                .scale(duration: 600.ms, curve: Curves.elasticOut),
            
            const SizedBox(height: 24),
            
            // Nombre
            const Text(
              'Rappi Taxi',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            )
                .animate()
                .fadeIn(delay: 300.ms),
            
            const SizedBox(height: 8),
            
            // Tagline
            const Text(
              'Tu viaje seguro y confiable',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            )
                .animate()
                .fadeIn(delay: 500.ms),
            
            const SizedBox(height: 48),
            
            // Loading indicator
            const CircularProgressIndicator(
              color: Colors.white,
            )
                .animate()
                .fadeIn(delay: 700.ms),
          ],
        ),
      ),
    );
  }
}