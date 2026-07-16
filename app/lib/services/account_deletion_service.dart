/// Helper para invocar la eliminación de cuenta en el backend Node del VPS.
/// Reemplaza la Cloud Function anterior.
///
/// El endpoint POST /api/account/delete hace TODA la limpieza server-side:
///  - Soft-delete del usuario en Postgres (deleted_at, email limpiado)
///  - Revoca sesiones (JWTs y refresh tokens)
///  - Cancela rides pendientes del user
///  - Registra en auth_events
///
/// Tras una llamada exitosa, la app debe hacer logout local (los tokens ya se
/// limpian dentro de RapiApiClient.deleteAccount) y redirigir a login.
library;

import 'rapi_api_client.dart';

class AccountDeletionException implements Exception {
  final String message;
  final String? code;
  AccountDeletionException(this.message, {this.code});

  @override
  String toString() =>
      code != null ? 'AccountDeletionException($code): $message' : message;
}

class AccountDeletionService {
  static final RapiApiClient _api = RapiApiClient.instance;

  static Future<DeleteAccountResult> deleteCurrentUserAccount({
    String? reason,
  }) async {
    try {
      final data = await _api.deleteAccount(reason: reason);
      // Ronda 191 GDPR: NO hardcodear firestoreDeleted:true si el server
      // no lo confirmó. Antes: la UI mostraba "cuenta eliminada" cuando
      // el backend respondía success:false + errors:[] → violation del
      // derecho de supresión (GDPR Art. 17 / Ley 29733 art. 20).
      final success = data['success'] == true;
      final errors = (data['errors'] as List?)
              ?.map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const <String>[];
      if (!success || errors.isNotEmpty) {
        throw AccountDeletionException(
          'Eliminación incompleta: ${errors.isNotEmpty ? errors.join("; ") : "el servidor rechazó la operación"}',
          code: 'PARTIAL_DELETE',
        );
      }
      return DeleteAccountResult(
        success: true,
        uid: data['userId']?.toString() ?? '',
        firestoreDeleted: data['firestoreDeleted'] == true,
        driversSubcolDeleted: data['driversSubcolDeleted'] == true,
        walletDeleted: data['walletDeleted'] == true,
        storageFilesDeleted: (data['storageFilesDeleted'] as num?)?.toInt() ?? 0,
        errors: errors,
      );
    } on RapiApiException catch (e) {
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
