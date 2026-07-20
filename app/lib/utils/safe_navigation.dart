import 'package:flutter/material.dart';

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
