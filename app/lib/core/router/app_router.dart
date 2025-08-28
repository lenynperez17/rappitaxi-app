import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Este archivo se mantiene simple sin providers para evitar conflictos
// La lógica de autenticación se maneja en las pantallas individuales

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/ride/presentation/screens/search_destination_screen.dart';
import '../../features/ride/presentation/screens/confirm_ride_screen.dart';
import '../../features/ride/presentation/screens/searching_driver_screen.dart';
import '../../features/ride/presentation/screens/ride_in_progress_screen.dart';
import '../../features/ride/presentation/screens/ride_completed_screen.dart';
import '../../features/ride/presentation/screens/ride_history_screen.dart';
import '../../features/payment/presentation/screens/payment_methods_screen.dart';
import '../../features/payment/presentation/screens/add_payment_method_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/support/presentation/screens/support_screen.dart';
import '../../features/support/presentation/screens/faq_screen.dart';
import '../../features/ride/presentation/screens/ride_details_screen.dart';
import '../../shared/models/location_model.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/main_navigation_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  debugLogDiagnostics: true,
  
  // Error handler
  errorBuilder: (context, state) => ErrorScreen(error: state.error),
  
  // Routes
  routes: [
    // Splash
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    
    // Onboarding
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    
    // Auth routes
    GoRoute(
      path: '/auth',
      redirect: (_, __) => '/auth/login',
      routes: [
        GoRoute(
          path: 'login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: 'register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: 'forgot-password',
          builder: (context, state) => const ForgotPasswordScreen(),
        ),
      ],
    ),
    
    // Main app routes con bottom navigation
    ShellRoute(
      builder: (context, state, child) => MainNavigationScreen(child: child),
      routes: [
        // Home
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        
        // History
        GoRoute(
          path: '/history',
          builder: (context, state) => const RideHistoryScreen(),
        ),
        
        // Profile
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (context, state) => const EditProfileScreen(),
            ),
            GoRoute(
              path: 'payment-methods',
              builder: (context, state) => const PaymentMethodsScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  builder: (context, state) => const AddPaymentMethodScreen(),
                ),
              ],
            ),
            GoRoute(
              path: 'support',
              builder: (context, state) => const SupportScreen(),
              routes: [
                GoRoute(
                  path: 'faq',
                  builder: (context, state) => const FaqScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    
    // Ride routes (fuera del ShellRoute para navegación completa)
    GoRoute(
      path: '/ride/search-destination',
      builder: (context, state) {
        final pickup = state.extra as LocationModel?;
        return SearchDestinationScreen(pickupLocation: pickup);
      },
    ),
    GoRoute(
      path: '/ride/confirm',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        return ConfirmRideScreen(
          pickup: data['pickup'] as LocationModel,
          destination: data['destination'] as LocationModel,
        );
      },
    ),
    GoRoute(
      path: '/ride/searching-driver',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        return SearchingDriverScreen(
          pickup: data['pickup'] as LocationModel,
          destination: data['destination'] as LocationModel,
          vehicleType: data['vehicleType'] as String,
          paymentMethod: data['paymentMethod'] as String,
          estimatedFare: data['estimatedFare'] as double,
        );
      },
    ),
    GoRoute(
      path: '/ride/in-progress',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        return RideInProgressScreen(
          pickup: data['pickup'] as LocationModel,
          destination: data['destination'] as LocationModel,
          vehicleType: data['vehicleType'] as String,
          paymentMethod: data['paymentMethod'] as String,
          fare: data['fare'] as double,
          driver: data['driver'] as Map<String, dynamic>,
        );
      },
    ),
    GoRoute(
      path: '/ride/completed',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        return RideCompletedScreen(
          fare: data['fare'] as double,
          driver: data['driver'] as Map<String, dynamic>,
          pickup: data['pickup'] as LocationModel,
          destination: data['destination'] as LocationModel,
        );
      },
    ),
    GoRoute(
      path: '/ride/details/:id',
      builder: (context, state) {
        final rideId = state.pathParameters['id']!;
        return RideDetailsScreen(rideId: rideId);
      },
    ),
  ],
);

// Error Screen
class ErrorScreen extends StatelessWidget {
  final Exception? error;
  
  const ErrorScreen({super.key, this.error});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Ocurrió un error',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error?.toString() ?? 'Error desconocido',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Ir al inicio'),
            ),
          ],
        ),
      ),
    );
  }
}