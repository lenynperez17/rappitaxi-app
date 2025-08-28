import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../../shared/providers/riverpod_compat.dart';

// Provider para el usuario actual
final userProvider = FutureProvider<UserModel?>((ref) async {
  // Observar el estado de autenticación
  final currentUser = ref.watch(currentUserProvider);
  return currentUser;
});

// Provider para el ID del usuario actual
final userIdProvider = Provider<String?>((ref) {
  final userAsync = ref.watch(userProvider);
  return userAsync.maybeWhen(
    data: (user) => user?.id,
    orElse: () => null,
  );
});

// Provider para el tipo de usuario actual
final userTypeProvider = Provider<String?>((ref) {
  final userAsync = ref.watch(userProvider);
  return userAsync.maybeWhen(
    data: (user) => user?.role,
    orElse: () => null,
  );
});

// Provider para el nombre del usuario actual
final userNameProvider = Provider<String?>((ref) {
  final userAsync = ref.watch(userProvider);
  return userAsync.maybeWhen(
    data: (user) => user?.name,
    orElse: () => null,
  );
});

// Provider para el email del usuario actual
final userEmailProvider = Provider<String?>((ref) {
  final userAsync = ref.watch(userProvider);
  return userAsync.maybeWhen(
    data: (user) => user?.email,
    orElse: () => null,
  );
});

// Provider para verificar si el usuario es conductor
final isDriverProvider = Provider<bool>((ref) {
  final userType = ref.watch(userTypeProvider);
  return userType == 'driver';
});

// Provider para verificar si el usuario es pasajero
final isPassengerProvider = Provider<bool>((ref) {
  final userType = ref.watch(userTypeProvider);
  return userType == 'passenger';
});

// Provider para verificar si el usuario es administrador
final isAdminProvider = Provider<bool>((ref) {
  final userType = ref.watch(userTypeProvider);
  return userType == 'admin';
});