import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Simplificado sin Riverpod para evitar conflictos
// La lógica de roles se manejará en las pantallas individuales

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/driver/presentation/screens/driver_home_screen.dart';
import '../../features/driver/presentation/screens/driver_earnings_screen.dart';
import '../../features/driver/presentation/screens/driver_profile_screen.dart';
import '../../features/driver/presentation/screens/driver_navigation_screen.dart' as driver_gps;
import '../../shared/models/ride_model.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentation/screens/admin_drivers_screen.dart';
import '../../features/admin/presentation/screens/admin_passengers_screen.dart';
import '../../features/admin/presentation/screens/admin_reports_screen.dart';
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
import '../../features/chat/presentation/screens/chat_screen_wrapper.dart';
import '../../features/support/presentation/screens/support_screen.dart';
import '../../features/support/presentation/screens/faq_screen.dart';
import '../../features/ride/presentation/screens/ride_details_screen.dart';
import '../../features/ride/presentation/screens/premium_price_negotiation_screen.dart';
import '../../shared/models/location_model.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/main_navigation_screen.dart';
import '../screens/driver_navigation_screen.dart';
import '../screens/admin_navigation_screen.dart';

final GoRouter roleBasedRouter = GoRouter(
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
    
    // Passenger routes con bottom navigation
    ShellRoute(
      builder: (context, state, child) => MainNavigationScreen(child: child),
      routes: [
        GoRoute(
          path: '/passenger/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/passenger/history',
          builder: (context, state) => const RideHistoryScreen(),
        ),
        GoRoute(
          path: '/passenger/profile',
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
    
    // Driver routes con bottom navigation
    ShellRoute(
      builder: (context, state, child) => DriverNavigationScreen(child: child),
      routes: [
        GoRoute(
          path: '/driver/home',
          builder: (context, state) => const DriverHomeScreen(),
        ),
        GoRoute(
          path: '/driver/earnings',
          builder: (context, state) => const DriverEarningsScreen(),
        ),
        GoRoute(
          path: '/driver/profile',
          builder: (context, state) => const DriverProfileScreen(),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (context, state) => const EditProfileScreen(),
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
        GoRoute(
          path: '/driver/navigation',
          builder: (context, state) {
            final ride = state.extra as RideModel?;
            if (ride == null) {
              // Si no hay ride, redirigir a home
              return const DriverHomeScreen();
            }
            return driver_gps.DriverNavigationScreen(ride: ride);
          },
        ),
      ],
    ),
    
    // Admin routes con bottom navigation
    ShellRoute(
      builder: (context, state, child) => AdminNavigationScreen(child: child),
      routes: [
        GoRoute(
          path: '/admin/dashboard',
          builder: (context, state) => const AdminDashboardScreen(),
        ),
        GoRoute(
          path: '/admin/drivers',
          builder: (context, state) => const AdminDriversScreen(),
        ),
        GoRoute(
          path: '/admin/passengers',
          builder: (context, state) => const AdminPassengersScreen(),
        ),
        GoRoute(
          path: '/admin/reports',
          builder: (context, state) => const AdminReportsScreen(),
        ),
      ],
    ),
    
    // Ride routes (compartidos entre passenger y driver)
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
    GoRoute(
      path: '/ride/negotiate-price',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        return PremiumPriceNegotiationScreen(
          pickup: data['pickup'] as LocationModel,
          destination: data['destination'] as LocationModel,
          suggestedPrice: data['suggestedPrice'] as double,
          rideRequestId: data['rideRequestId'] as String,
        );
      },
    ),
    
    // Chat route
    GoRoute(
      path: '/chat/:rideId',
      builder: (context, state) {
        final rideId = state.pathParameters['rideId']!;
        final extra = state.extra as Map<String, dynamic>?;
        return ChatScreenWrapper(
          rideId: rideId,
          otherUserId: extra?['otherUserId'] ?? '',
          otherUserName: extra?['otherUserName'] ?? '',
        );
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
              onPressed: () => context.go('/passenger/home'),
              child: const Text('Ir al inicio'),
            ),
          ],
        ),
      ),
    );
  }
}