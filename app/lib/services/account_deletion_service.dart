/// Helper para invocar la Cloud Function callable `deleteMyAccount`
/// (definida en `functions/src/handlers/AccountDeletionHandler.ts`,
/// región us-central1, 2nd gen).
///
/// La callable hace TODA la limpieza server-side:
///  - Borra el documento `/users/{uid}` y subcolecciones de Firestore
///  - Borra `drivers/{uid}/documents/` (subcolección del conductor)
///  - Borra `wallets/{uid}` (si es conductor)
///  - Borra archivos del usuario en Storage
///  - Registra log en `deletion_logs`
///  - Borra el user de Firebase Auth al final
///
/// Tras una llamada exitosa, la app debe hacer logout local y redirigir a
/// la pantalla de login.
library;

import 'package:cloud_functions/cloud_functions.dart';

class AccountDeletionException implements Exception {
  final String message;
  final String? code;
  AccountDeletionException(this.message, {this.code});

  @override
  String toString() =>
      code != null ? 'AccountDeletionException($code): $message' : message;
}

class AccountDeletionService {
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Invoca la callable `deleteMyAccount`. Lanza [AccountDeletionException]
  /// si algo falla. El caller debe estar autenticado en Firebase Auth.
  static Future<DeleteAccountResult> deleteCurrentUserAccount({
    String? reason,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'deleteMyAccount',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );
      final result = await callable.call<Map<String, dynamic>>({
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });
      final data = result.data;
      return DeleteAccountResult(
        success: data['success'] == true,
        uid: data['uid']?.toString() ?? '',
        firestoreDeleted: data['firestoreDeleted'] == true,
        driversSubcolDeleted: data['driversSubcolDeleted'] == true,
        walletDeleted: data['walletDeleted'] == true,
        storageFilesDeleted: (data['storageFilesDeleted'] as num?)?.toInt() ?? 0,
        errors: (data['errors'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
      );
    } on FirebaseFunctionsException catch (e) {
      throw AccountDeletionException(
        e.message ?? 'No se pudo eliminar la cuenta',
        code: e.code,
      );
    } catch (e) {
      throw AccountDeletionException(
        'Error inesperado al eliminar la cuenta: $e',
      );
    }
  }
}

class DeleteAccountResult {
  final bool success;
  final String uid;
  final bool firestoreDeleted;
  final bool driversSubcolDeleted;
  final bool walletDeleted;
  final int storageFilesDeleted;
  final List<String> errors;

  DeleteAccountResult({
    required this.success,
    required this.uid,
    required this.firestoreDeleted,
    required this.driversSubcolDeleted,
    required this.walletDeleted,
    required this.storageFilesDeleted,
    required this.errors,
  });
}
