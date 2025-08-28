import '../../../../shared/models/user_model.dart';

abstract class AuthRepository {
  // Obtener usuario actual
  Future<UserModel?> getCurrentUser();
  
  // Iniciar sesión con email
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  });
  
  // Iniciar sesión con Google
  Future<UserModel> signInWithGoogle();
  
  // Registrarse con email
  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
  });
  
  // Enviar código de verificación por SMS
  Future<void> sendOtpCode(String phoneNumber);
  
  // Verificar código OTP
  Future<void> verifyOtpCode({
    required String verificationId,
    required String code,
  });
  
  // Restablecer contraseña
  Future<void> resetPassword(String email);
  
  // Actualizar perfil
  Future<UserModel> updateProfile({
    String? name,
    String? photoUrl,
  });
  
  // Cerrar sesión
  Future<void> signOut();
  
  // Eliminar cuenta
  Future<void> deleteAccount();
  
  // Stream de cambios en el estado de autenticación
  Stream<UserModel?> get authStateChanges;
}