import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/rapi_sse_client.dart';
import '../../utils/logger.dart';

/// Ronda 269: deja la sesión lista tras un login, igual que hace el arranque
/// en frío.
///
/// POR QUÉ EXISTE
/// --------------
/// `main.dart` hace dos cosas al abrir la app con sesión guardada: hidrata
/// `AuthProvider` y arranca el canal de eventos en vivo (SSE). Las pantallas de
/// login y de OTP no hacían ninguna de las dos: llamaban al cliente HTTP,
/// cogían el JSON de la respuesta y navegaban.
///
/// Eso dejaba la app a medio arrancar:
///
///   1. `AuthProvider.currentUser` en null. El menú lateral del pasajero lee de
///      ahí el tipo de cuenta, no lo encontraba, y a un conductor le ofrecía
///      "Empieza a ganar dinero" (que lleva al alta) en vez de "Cambiar a
///      conductor". Al reabrir la app el splash sí hidrataba y el botón
///      aparecía correcto: el clásico "a veces sí, a veces no".
///
///   2. Sin SSE. El pasajero recién logueado no recibía en vivo las ofertas de
///      los conductores ni los cambios de estado del viaje hasta reiniciar.
///
/// Al centralizarlo aquí, cualquier vía de entrada nueva (otro proveedor OAuth,
/// por ejemplo) hereda el comportamiento correcto sin tener que acordarse.
class AuthSessionBootstrap {
  const AuthSessionBootstrap._();

  /// Refresca el usuario desde el backend y abre el canal de eventos.
  ///
  /// Nunca lanza: si el refresco falla (sin red), quien llama sigue adelante
  /// con lo que le devolvió el login. Es preferible entrar con datos algo
  /// incompletos que dejar al usuario atascado en el login tras haberse
  /// autenticado correctamente.
  static Future<void> hydrate(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    try {
      await authProvider.refreshUserData();
    } catch (e) {
      AppLogger.warning('[auth-bootstrap] no se pudo refrescar el perfil: $e');
    }
    try {
      RapiSseClient.instance.start();
    } catch (e) {
      AppLogger.warning('[auth-bootstrap] no se pudo abrir el canal en vivo: $e');
    }
  }
}
