import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/utils/home_route_resolver.dart';
import '../providers/auth_provider.dart';

/// Ronda 225: helper contra "pantalla negra" al presionar back en pantallas
/// que fueron abiertas con `pushNamedAndRemoveUntil((_)=>false)` — la pila
/// queda vacía y `Navigator.pop` no encuentra ruta previa → screen negro.
///
/// Uso:
///   - En AppBar leading: `onPressed: () => safePopOrHome(context)`
///   - Como onPopInvoked de PopScope: envolver el body con SafePopScope.
///
/// Si el user es pasajero → home passenger. Si es driver → home driver.
/// Cae al login como último recurso.
Future<void> safePopOrHome(BuildContext context, {String fallback = '/passenger/home'}) async {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
    return;
  }
  // Sin ruta previa: navegamos a un destino raíz seguro en vez de dejar
  // el widget colgando sobre un Navigator vacío (pantalla negra).
  navigator.pushNamedAndRemoveUntil(fallback, (_) => false);
}

/// Wrapper que combina PopScope (Android back + iOS swipe) con el safePopOrHome.
/// Envolver el body de las pantallas del wizard de registro y cualquier
/// pantalla que pueda ser abierta con la pila borrada.
class SafePopScope extends StatelessWidget {
  final Widget child;
  final String fallback;

  const SafePopScope({
    super.key,
    required this.child,
    this.fallback = '/passenger/home',
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          // El framework NO pudo hacer pop (canPop=false). Redirigimos a home.
          Navigator.of(context).pushNamedAndRemoveUntil(fallback, (_) => false);
        }
      },
      child: child,
    );
  }
}

/// Ronda 279: como [safePopOrHome], pero el destino de emergencia lo decide el
/// rol de quien está usando la app.
///
/// Las pantallas de `screens/shared/` las abren los dos roles. Con un fallback
/// fijo, un conductor que se quedara sin pila acababa en el home de pasajero.
/// [HomeRouteResolver] ya es la única fuente de verdad para esa decisión —se
/// creó en la ronda 269 justo porque estaba escrita tres veces y no coincidían—
/// así que aquí se reutiliza en vez de volver a decidirlo.
Future<void> safePopOrRoleHome(BuildContext context) async {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
    return;
  }
  final usuario = context.read<AuthProvider>().currentUser;
  final destino = HomeRouteResolver.resolve(usuario);
  navigator.pushNamedAndRemoveUntil(destino, (_) => false);
}

/// Ronda 279: cargador modal que se cierra exactamente una vez.
///
/// El patrón que estaba repartido por la app era este:
///
/// ```dart
/// showDialog(context: context, builder: (_) => CircularProgressIndicator());
/// final r = await algo();
/// if (mounted) Navigator.pop(context);   // cierra "lo que haya encima"
/// ...
/// } catch (e) {
///   if (mounted) Navigator.pop(context); // y aquí otra vez
/// }
/// ```
///
/// Ese `pop` usa el contexto de la PANTALLA, no el del diálogo: retira la ruta
/// que esté encima de la pila, sea cual sea. En `wallet_screen` el retiro
/// cerraba el cargador y, si el servidor devolvía un fallo, lanzaba una
/// excepción: el `catch` cerraba "el cargador" por segunda vez y lo que se
/// llevaba por delante era la billetera. Con la pila corta, eso es la pantalla
/// negra otra vez.
///
/// Esta clase se queda con el contexto del propio diálogo y con un pestillo:
/// el segundo `close()` no hace nada.
///
/// Uso:
/// ```dart
/// final cargador = LoadingDialog.show(context);
/// try {
///   await algo();
/// } finally {
///   cargador.close();
/// }
/// ```
class LoadingDialog {
  BuildContext? _dialogContext;
  bool _closed = false;

  LoadingDialog._();

  /// Abre el cargador sobre [context] y devuelve el manejador para cerrarlo.
  ///
  /// Con [message] se dibuja la tarjeta con texto que ya usaban la billetera y
  /// la recarga de créditos; sin él, solo la rueda. Con [builder] se conserva
  /// tal cual un cargador con diseño propio (la recarga de la billetera tiene
  /// uno con degradado): lo único que cambia es quién lo cierra.
  static LoadingDialog show(
    BuildContext context, {
    Color? color,
    String? message,
    WidgetBuilder? builder,
  }) {
    final loader = LoadingDialog._();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        loader._dialogContext = dialogContext;
        if (builder != null) {
          return PopScope(canPop: false, child: builder(dialogContext));
        }
        final rueda = CircularProgressIndicator(color: color);
        // canPop: false — que el botón atrás no cierre el cargador dejando la
        // operación en curso sin nadie que la esté esperando.
        return PopScope(
          canPop: false,
          child: Center(
            child: message == null
                ? rueda
                : Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(dialogContext).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        rueda,
                        const SizedBox(height: 16),
                        Text(message),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
    return loader;
  }

  /// Cierra el cargador. Llamarlo dos veces es seguro: la segunda no hace nada.
  void close() {
    if (_closed) return;
    _closed = true;
    final ctx = _dialogContext;
    // `ctx.mounted` descarta el caso de que el diálogo ya se haya ido por otro
    // camino. Si es null, el diálogo aún no llegó a construirse: no hay ruta
    // que cerrar.
    if (ctx == null || !ctx.mounted) return;
    Navigator.of(ctx).pop();
  }
}

/// Ronda 279: el atrás en una pantalla RAÍZ (las dos home).
///
/// Aquí estaba la pantalla negra que reportó el dueño. Al cancelar un viaje,
/// `active_trip_screen.dart` hace `pushNamedAndRemoveUntil('/driver/home',
/// (route) => false)`, así que la home queda como ÚNICA ruta de la pila. La
/// home declaraba `PopScope(canPop: !hasActiveTrip)` y, cancelado el viaje,
/// eso vale `true`: al pulsar atrás Flutter retiraba la última ruta y dejaba
/// el Navigator vacío. Un Navigator sin rutas no pinta nada — negro.
///
/// La home del pasajero tenía el defecto contrario, `canPop: false` fijo: el
/// atrás no hacía nada nunca, ni con la app recién abierta.
///
/// Este envoltorio se queda con el control en vez de delegarlo:
///   1. Si [blockWith] devuelve un motivo, no se sale y se explica por qué.
///   2. Si hay una ruta debajo, se retrocede con normalidad.
///   3. Si no la hay, en Android se manda la app a segundo plano —que es lo
///      que el usuario espera del atrás en la pantalla principal— en vez de
///      vaciar la pila. En iOS no se hace nada: no hay botón atrás y Apple
///      desaconseja cerrar la app por código.
class RootBackHandler extends StatelessWidget {
  final Widget child;

  /// Devuelve el motivo por el que ahora mismo no se debe salir (por ejemplo,
  /// un viaje en curso), o `null` si se puede. El mensaje se le muestra al
  /// usuario tal cual.
  final String? Function()? blockWith;

  const RootBackHandler({super.key, required this.child, this.blockWith});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Siempre false: el retroceso lo resolvemos abajo. Dejárselo al framework
      // es justamente lo que vaciaba la pila.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        final motivo = blockWith?.call();
        if (motivo != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(motivo), backgroundColor: Colors.orange),
          );
          return;
        }

        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
          return;
        }

        if (defaultTargetPlatform == TargetPlatform.android) {
          SystemNavigator.pop();
        }
      },
      child: child,
    );
  }
}
