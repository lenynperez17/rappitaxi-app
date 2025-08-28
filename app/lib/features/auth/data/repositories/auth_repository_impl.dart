import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/crash_reporting_service.dart';
import '../../../../core/services/token_service.dart';
import 'package:rappitaxi_app/shared/utils/logger.dart';
import '../../../../shared/models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final Ref _ref;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;
  
  AuthRepositoryImpl(this._ref)
      : _auth = FirebaseAuth.instance,
        _firestore = FirebaseFirestore.instance,
        _googleSignIn = GoogleSignIn();
  
  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) return null;
      
      final doc = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();
      
      if (!doc.exists) return null;
      
      final data = doc.data()!;
      return UserModel(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        name: data['name'] ?? '',
        phone: data['phone'] ?? '',
        photoUrl: data['photoUrl'],
        role: data['userType'] ?? 'passenger',
        isActive: data['isActive'] ?? true,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      );
    } catch (e) {
      _ref.read(crashReportingServiceProvider).recordError(
        e,
        StackTrace.current,
        reason: 'Error getting current user',
      );
      return null;
    }
  }
  
  @override
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      Logger.info('Attempting email login for: $email');
      
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final user = credential.user!;
      
      // Get user data from Firestore
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!doc.exists) {
        // Create user document if it doesn't exist
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'name': user.displayName ?? 'Usuario',
          'userType': 'passenger',
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      final data = doc.data() ?? {};
      
      // Save token
      await TokenService().saveToken(await user.getIdToken() ?? '');
      
      // Track analytics
      _ref.read(analyticsServiceProvider).logLogin(method: 'email');
      
      Logger.info('Login successful for user: ${user.uid}');
      
      return UserModel(
        id: user.uid,
        email: user.email ?? '',
        name: data['name'] ?? user.displayName ?? 'Usuario',
        phone: data['phone'] ?? '',
        photoUrl: data['photoUrl'] ?? user.photoURL,
        role: data['userType'] ?? 'passenger',
        isActive: data['isActive'] ?? true,
      );
    } on FirebaseAuthException catch (e) {
      Logger.error('Firebase Auth error', e.toString());
      throw _handleFirebaseAuthError(e);
    } catch (e) {
      Logger.error('Login failed', e.toString());
      _ref.read(crashReportingServiceProvider).recordError(
        e,
        StackTrace.current,
        reason: 'Email login failed',
      );
      rethrow;
    }
  }
  
  @override
  Future<UserModel> loginWithGoogle() async {
    try {
      Logger.info('Attempting Google sign in');
      
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        throw Exception('Google sign in was cancelled');
      }
      
      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;
      
      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user!;
      
      // Check if user exists in Firestore
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!doc.exists) {
        // Create user document
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'name': user.displayName ?? googleUser.displayName,
          'photoUrl': user.photoURL ?? googleUser.photoUrl,
          'userType': 'passenger',
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      final data = doc.data() ?? {};
      
      // Save token
      await TokenService().saveToken(await user.getIdToken() ?? '');
      
      // Track analytics
      _ref.read(analyticsServiceProvider).logLogin(method: 'google');
      
      Logger.info('Google login successful');
      
      return UserModel(
        id: user.uid,
        email: user.email ?? googleUser.email,
        name: data['name'] ?? user.displayName ?? googleUser.displayName ?? 'Usuario',
        phone: data['phone'] ?? '',
        photoUrl: data['photoUrl'] ?? user.photoURL ?? googleUser.photoUrl,
        role: data['userType'] ?? 'passenger',
        isActive: data['isActive'] ?? true,
      );
    } catch (e) {
      Logger.error('Google login failed', e.toString());
      _ref.read(crashReportingServiceProvider).recordError(
        e,
        StackTrace.current,
        reason: 'Google login failed',
      );
      rethrow;
    }
  }
  
  @override
  Future<UserModel> loginWithFacebook() async {
    // TODO: Implement Facebook login
    throw UnimplementedError('Facebook login not implemented yet');
  }
  
  @override
  Future<UserModel> loginWithApple() async {
    // TODO: Implement Apple login
    throw UnimplementedError('Apple login not implemented yet');
  }
  
  @override
  Future<UserModel> loginWithPhone({
    required String phoneNumber,
    required String verificationCode,
  }) async {
    // TODO: Implement phone login
    throw UnimplementedError('Phone login not implemented yet');
  }
  
  @override
  Future<void> sendPhoneVerification({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(String) onAutoVerified,
    required Function(String) onError,
  }) async {
    try {
      Logger.info('Sending phone verification for: $phoneNumber');
      
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification
          final userCredential = await _auth.signInWithCredential(credential);
          onAutoVerified(userCredential.user!.uid);
        },
        verificationFailed: (FirebaseAuthException e) {
          Logger.error('Phone verification failed', e.toString());
          onError(e.message ?? 'Verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          Logger.info('Verification code sent');
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Auto retrieval timeout
        },
      );
    } on FirebaseAuthException catch (e) {
      Logger.error('Firebase Auth error', e.toString());
      onError(e.message ?? 'Verification failed');
      throw _handleFirebaseAuthError(e);
    } catch (e) {
      Logger.error('Phone verification failed', e.toString());
      onError(e.toString());
      _ref.read(crashReportingServiceProvider).recordError(
        e,
        StackTrace.current,
        reason: 'Phone verification failed',
      );
      rethrow;
    }
  }
  
  @override
  Future<UserModel> verifyPhoneCode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      Logger.info('Verifying phone code');
      
      // Create a PhoneAuthCredential with the code
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      
      // Sign in with the credential
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user!;
      
      // Check if user exists in Firestore
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!doc.exists) {
        // Create user document
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'phone': user.phoneNumber,
          'userType': 'passenger',
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      final data = doc.data() ?? {};
      
      // Save token
      await TokenService().saveToken(await user.getIdToken() ?? '');
      
      Logger.info('Phone verification successful');
      
      return UserModel(
        id: user.uid,
        email: data['email'] ?? '',
        phone: user.phoneNumber ?? '',
        name: data['name'] ?? 'Usuario',
        role: data['userType'] ?? 'passenger',
        isActive: data['isActive'] ?? true,
      );
    } on FirebaseAuthException catch (e) {
      Logger.error('Firebase Auth error', e.toString());
      throw _handleFirebaseAuthError(e);
    } catch (e) {
      Logger.error('Phone verification failed', e.toString());
      _ref.read(crashReportingServiceProvider).recordError(
        e,
        StackTrace.current,
        reason: 'Phone code verification failed',
      );
      rethrow;
    }
  }
  
  @override
  Future<UserModel> registerWithEmail({
    required String email,
    required String password,
    required String name,
    required String userType,
    String? phone,
  }) async {
    try {
      Logger.info('Attempting registration for: $email');
      
      // Create user in Firebase Auth
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final user = credential.user!;
      
      // Update display name
      await user.updateDisplayName(name);
      
      // Create user document in Firestore
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'name': name,
        'phone': phone,
        'userType': userType,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // If user is a driver, create driver document
      if (userType == 'driver') {
        await _firestore.collection('drivers').doc(user.uid).set({
          'uid': user.uid,
          'name': name,
          'email': email,
          'phone': phone,
          'status': 'offline',
          'isAvailable': false,
          'isApproved': false,
          'rating': 5.0,
          'totalRides': 0,
          'earnings': 0.0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      // Save token
      await TokenService().saveToken(await user.getIdToken() ?? '');
      
      // Track analytics
      _ref.read(analyticsServiceProvider).logSignUp(method: 'email');
      
      Logger.info('Registration successful for user: ${user.uid}');
      
      return UserModel(
        id: user.uid,
        email: email,
        name: name,
        phone: phone ?? '',
        role: userType,
        isActive: true,
        createdAt: DateTime.now(),
      );
    } on FirebaseAuthException catch (e) {
      Logger.error('Firebase Auth error', e.toString());
      throw _handleFirebaseAuthError(e);
    } catch (e) {
      Logger.error('Registration failed', e.toString());
      _ref.read(crashReportingServiceProvider).recordError(
        e,
        StackTrace.current,
        reason: 'Email registration failed',
      );
      rethrow;
    }
  }
  
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      Logger.info('Sending password reset email to: $email');
      
      await _auth.sendPasswordResetEmail(email: email);
      
      Logger.info('Password reset email sent successfully');
    } on FirebaseAuthException catch (e) {
      Logger.error('Firebase Auth error', e.toString());
      throw _handleFirebaseAuthError(e);
    } catch (e) {
      Logger.error('Password reset failed', e.toString());
      _ref.read(crashReportingServiceProvider).recordError(
        e,
        StackTrace.current,
        reason: 'Password reset failed',
      );
      rethrow;
    }
  }
  
  @override
  Future<void> logout() async {
    try {
      Logger.info('Logging out user: ${_auth.currentUser?.uid}');
      
      // Sign out from Firebase
      await _auth.signOut();
      
      // Sign out from Google
      await _googleSignIn.signOut();
      
      // Clear token
      await TokenService().deleteToken();
      
      // Track analytics
      _ref.read(analyticsServiceProvider).logLogout();
      
      Logger.info('Logout successful');
    } catch (e) {
      Logger.error('Logout failed', e.toString());
      _ref.read(crashReportingServiceProvider).recordError(
        e,
        StackTrace.current,
        reason: 'Logout failed',
      );
      rethrow;
    }
  }
  
  @override
  Future<void> updateUserProfile({
    required String uid,
    String? name,
    String? phone,
    String? photoUrl,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      Logger.info('Updating user profile for: $uid');
      
      final updates = <String, dynamic>{};
      
      if (name != null) updates['name'] = name;
      if (phone != null) updates['phone'] = phone;
      if (photoUrl != null) updates['photoUrl'] = photoUrl;
      if (additionalData != null) updates.addAll(additionalData);
      
      if (updates.isNotEmpty) {
        updates['updatedAt'] = FieldValue.serverTimestamp();
        
        await _firestore
            .collection('users')
            .doc(uid)
            .update(updates);
      }
      
      Logger.info('Profile updated successfully');
    } catch (e) {
      Logger.error('Profile update failed', e.toString());
      _ref.read(crashReportingServiceProvider).recordError(
        e,
        StackTrace.current,
        reason: 'Profile update failed',
      );
      rethrow;
    }
  }
  
  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      Logger.info('Changing password for user: ${_auth.currentUser?.uid}');
      
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');
      
      // Reauthenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      
      await user.reauthenticateWithCredential(credential);
      
      // Update password
      await user.updatePassword(newPassword);
      
      Logger.info('Password changed successfully');
    } on FirebaseAuthException catch (e) {
      Logger.error('Firebase Auth error', e.toString());
      throw _handleFirebaseAuthError(e);
    } catch (e) {
      Logger.error('Password change failed', e.toString());
      _ref.read(crashReportingServiceProvider).recordError(
        e,
        StackTrace.current,
        reason: 'Password change failed',
      );
      rethrow;
    }
  }
  
  Future<void> deleteAccountOld() async {
    try {
      Logger.info('Deleting account for user: ${_auth.currentUser?.uid}');
      
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');
      
      // Delete user data from Firestore
      await _firestore.collection('users').doc(user.uid).delete();
      
      // Delete user from Firebase Auth
      await user.delete();
      
      // Clear token
      await TokenService().deleteToken();
      
      Logger.info('Account deleted successfully');
    } catch (e) {
      Logger.error('Account deletion failed', e.toString());
      _ref.read(crashReportingServiceProvider).recordError(
        e,
        StackTrace.current,
        reason: 'Account deletion failed',
      );
      rethrow;
    }
  }
  
  Stream<UserModel?> get authStateChanges {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;
      
      final doc = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();
      
      if (!doc.exists) return null;
      
      final data = doc.data()!;
      return UserModel(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        name: data['name'] ?? '',
        phone: data['phone'] ?? '',
        photoUrl: data['photoUrl'],
        role: data['userType'] ?? 'passenger',
        isActive: data['isActive'] ?? true,
      );
    });
  }
  
  Future<bool> checkEmailExists(String email) async {
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      return methods.isNotEmpty;
    } catch (e) {
      Logger.error('Email check failed', e.toString());
      return false;
    }
  }
  
  @override
  Future<void> reauthenticateWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      Logger.info('Reauthenticating user with email: $email');
      
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');
      
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      
      await user.reauthenticateWithCredential(credential);
      
      Logger.info('Reauthentication successful');
    } on FirebaseAuthException catch (e) {
      Logger.error('Firebase Auth error', e.toString());
      throw _handleFirebaseAuthError(e);
    } catch (e) {
      Logger.error('Reauthentication failed', e.toString());
      _ref.read(crashReportingServiceProvider).recordError(
        e,
        StackTrace.current,
        reason: 'Email reauthentication failed',
      );
      rethrow;
    }
  }
  
  // Métodos faltantes para cumplir con la interfaz
  @override
  Future<UserModel> signInWithGoogle() => loginWithGoogle();
  
  @override
  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) => registerWithEmail(
    email: email,
    password: password,
    name: name,
    phone: phone,
    userType: 'passenger',
  );
  
  @override
  Future<void> sendOtpCode(String phoneNumber) => sendPhoneVerification(
    phoneNumber: phoneNumber,
    onCodeSent: (verificationId) {},
    onAutoVerified: (credential) {},
    onError: (error) {},
  );
  
  @override
  Future<void> verifyOtpCode({
    required String verificationId,
    required String code,
  }) async {
    await verifyPhoneCode(
      verificationId: verificationId,
      smsCode: code,
    );
  }
  
  @override
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      Logger.info('Password reset email sent to: $email');
    } catch (e) {
      Logger.error('Password reset failed', e.toString());
      throw e;
    }
  }
  
  @override
  Future<UserModel> updateProfile({
    String? name,
    String? photoUrl,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception('User not authenticated');
    
    await updateUserProfile(
      uid: currentUserId,
      name: name,
      photoUrl: photoUrl,
    );
    final user = await getCurrentUser();
    if (user == null) throw Exception('User not found after update');
    return user;
  }
  
  @override
  Future<void> signOut() => logout();
  
  @override
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');
      
      // Delete user data from Firestore
      await _firestore.collection('users').doc(user.uid).delete();
      
      // Delete the Firebase Auth account
      await user.delete();
      
      Logger.info('Account deleted successfully');
    } catch (e) {
      Logger.error('Delete account failed', e.toString());
      throw e;
    }
  }
  
  String _handleFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No se encontró una cuenta con este correo electrónico';
      case 'wrong-password':
        return 'Contraseña incorrecta';
      case 'email-already-in-use':
        return 'Este correo electrónico ya está registrado';
      case 'invalid-email':
        return 'Correo electrónico inválido';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres';
      case 'network-request-failed':
        return 'Error de conexión. Verifica tu internet';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta más tarde';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada';
      default:
        return e.message ?? 'Error de autenticación';
    }
  }
}