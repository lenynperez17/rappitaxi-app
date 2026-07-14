/// Modo tour interactivo de desarrollo — navega + ejerce interacciones reales
/// (taps, scroll) via `WidgetsBinding.instance.handlePointerEvent()`, que es
/// el mismo pipeline que usa `flutter_test`. Los eventos SÍ atraviesan el
/// GestureBinding y llegan a los widgets como taps de usuario.
///
/// Los pasos emiten prints con marcadores `SCREENSHOT_MARKER:<tag>` que el
/// bash loop externo detecta para tomar `xcrun simctl io screenshot`.
library;

import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Tipos de acción ───────────────────────────────────────────────────────

sealed class TourAction { const TourAction(); }

/// Espera N milisegundos (para dejar renderizar animaciones).
class Wait extends TourAction {
  final int ms;
  const Wait(this.ms);
}

/// Tap en coordenadas lógicas (puntos, iPhone 16 Pro es 402x874).
class Tap extends TourAction {
  final double x, y;
  final String? note;
  const Tap(this.x, this.y, {this.note});
}

/// Long-press en coordenadas.
class LongPress extends TourAction {
  final double x, y;
  final int ms;
  const LongPress(this.x, this.y, {this.ms = 700});
}

/// Scroll vertical desde (x, yStart) hasta (x, yEnd) en ms.
class Scroll extends TourAction {
  final double x, yStart, yEnd;
  final int ms;
  const Scroll({required this.x, required this.yStart, required this.yEnd, this.ms = 400});
}

/// Emite marcador para que el bash externo capture screenshot.
class Snap extends TourAction {
  final String tag;
  const Snap(this.tag);
}

/// Escribe texto en el TextField enfocado. Requires que un Tap previo haya
/// enfocado un TextField. Usa TextInput channel de Flutter.
class TypeText extends TourAction {
  final String text;
  const TypeText(this.text);
}

/// Navega a una ruta (con args). También emite Snap del render inicial.
class Nav extends TourAction {
  final String route;
  final Map<String, dynamic>? args;
  final String? label;
  const Nav(this.route, {this.args, this.label});
}

/// Pop back (equivalente a botón atrás).
class Back extends TourAction {
  const Back();
}

// ─── Flujo ─────────────────────────────────────────────────────────────────

class TourFlow {
  final String id;
  final String title;
  final List<TourAction> steps;
  const TourFlow(this.id, this.title, this.steps);
}

// ─── Catálogo de flujos ────────────────────────────────────────────────────
// iPhone 16 Pro logical resolution: 402 x 874 points.

const List<TourFlow> kTourFlows = [
  // Pasajero
  TourFlow('01-passenger-home', 'Home Pasajero', [
    Nav('/passenger/home', label: 'Home pasajero'),
    Wait(2500),
    Snap('01a-home'),
    Tap(35, 122, note: 'Menú hamburger'),
    Wait(1200),
    Snap('01b-drawer'),
    Tap(360, 400, note: 'Fuera del drawer'),
    Wait(600),
    Tap(200, 700, note: 'Fuera del drawer 2'),
    Wait(800),
    Snap('01c-home-drawer-cerrado'),
  ]),

  TourFlow('02-passenger-trip-history', 'Historial de Viajes', [
    Nav('/passenger/trip-history', label: 'Historial'),
    Wait(2500),
    Snap('02a-historial'),
    Scroll(x: 200, yStart: 700, yEnd: 300, ms: 500),
    Wait(600),
    Snap('02b-historial-scrolled'),
    Tap(160, 405, note: 'Filtro Completados'),
    Wait(800),
    Snap('02c-filtro-completados'),
    Tap(70, 405, note: 'Filtro Todos'),
    Wait(600),
    Snap('02d-filtro-todos'),
  ]),

  TourFlow('03-passenger-payment-methods', 'Métodos de Pago', [
    Nav('/passenger/payment-methods', label: 'Métodos de pago'),
    Wait(2500),
    Snap('03a-metodos'),
    Tap(200, 700, note: 'Efectivo card'),
    Wait(800),
    Snap('03b-metodo-selected'),
    Tap(200, 795, note: 'Tab Historial (arriba)'),
    Wait(800),
    Snap('03c-historial-tab'),
  ]),

  TourFlow('04-passenger-favorites', 'Favoritos', [
    Nav('/passenger/favorites', label: 'Favoritos'),
    Wait(2500),
    Snap('04a-favoritos'),
    Scroll(x: 200, yStart: 700, yEnd: 300, ms: 400),
    Wait(500),
    Snap('04b-favoritos-scrolled'),
  ]),

  TourFlow('05-passenger-promotions', 'Promociones', [
    Nav('/passenger/promotions', label: 'Promociones'),
    Wait(2500),
    Snap('05a-promociones'),
    Scroll(x: 200, yStart: 700, yEnd: 300, ms: 400),
    Wait(500),
    Snap('05b-promociones-scrolled'),
  ]),

  TourFlow('06-passenger-profile', 'Perfil Pasajero', [
    Nav('/passenger/profile', label: 'Perfil'),
    Wait(2500),
    Snap('06a-perfil'),
    Scroll(x: 200, yStart: 700, yEnd: 300, ms: 400),
    Wait(500),
    Snap('06b-perfil-scrolled'),
  ]),

  TourFlow('07-passenger-profile-edit', 'Editar Perfil', [
    Nav('/passenger/profile-edit', label: 'Editar perfil'),
    Wait(2500),
    Snap('07a-editar-perfil'),
    Scroll(x: 200, yStart: 700, yEnd: 300, ms: 400),
    Wait(500),
    Snap('07b-editar-perfil-scrolled'),
  ]),

  TourFlow('08-passenger-negotiations', 'Negociaciones Pasajero', [
    Nav('/passenger/negotiations', label: 'Negociaciones'),
    Wait(2500),
    Snap('08a-negotiations'),
  ]),

  TourFlow('09-passenger-vale-input', 'Ingresar Vale', [
    Nav('/passenger/vale-input', label: 'Vale'),
    Wait(2500),
    Snap('09a-vale-input'),
    Tap(200, 400, note: 'Input vale'),
    Wait(500),
    Snap('09b-input-focused'),
  ]),

  // Driver
  TourFlow('10-driver-home', 'Home Conductor', [
    Nav('/driver/home', label: 'Home conductor'),
    Wait(3000),
    Snap('10a-home-driver'),
    Scroll(x: 200, yStart: 700, yEnd: 300, ms: 400),
    Wait(500),
    Snap('10b-home-driver-scrolled'),
  ]),

  TourFlow('11-driver-profile', 'Perfil Conductor', [
    Nav('/driver/profile', label: 'Perfil driver'),
    Wait(2500),
    Snap('11a-perfil-driver'),
    Scroll(x: 200, yStart: 700, yEnd: 300, ms: 400),
    Wait(500),
    Snap('11b-perfil-driver-scrolled'),
  ]),

  TourFlow('12-driver-wallet', 'Wallet Conductor', [
    Nav('/driver/wallet', label: 'Wallet'),
    Wait(2500),
    Snap('12a-wallet'),
    Scroll(x: 200, yStart: 700, yEnd: 300, ms: 400),
    Wait(500),
    Snap('12b-wallet-scrolled'),
  ]),

  TourFlow('13-driver-recharge', 'Recarga Conductor', [
    Nav('/driver/recharge', label: 'Recarga'),
    Wait(2500),
    Snap('13a-recharge'),
    Tap(80, 400, note: 'Método efectivo/yape'),
    Wait(600),
    Snap('13b-recharge-method'),
    Scroll(x: 200, yStart: 700, yEnd: 300, ms: 400),
    Wait(500),
    Snap('13c-recharge-scrolled'),
  ]),

  TourFlow('14-driver-metrics', 'Métricas Conductor', [
    Nav('/driver/metrics', label: 'Métricas'),
    Wait(2500),
    Snap('14a-metricas'),
    Scroll(x: 200, yStart: 700, yEnd: 300, ms: 400),
    Wait(500),
    Snap('14b-metricas-scrolled'),
  ]),

  TourFlow('15-driver-communication', 'Comunicación', [
    Nav('/driver/communication', label: 'Comunicación'),
    Wait(2500),
    Snap('15a-communication'),
    Scroll(x: 200, yStart: 700, yEnd: 300, ms: 400),
    Wait(500),
    Snap('15b-communication-scrolled'),
  ]),

  TourFlow('16-driver-documents', 'Documentos Conductor', [
    Nav('/driver/documents', label: 'Documentos'),
    Wait(2500),
    Snap('16a-documents'),
    Scroll(x: 200, yStart: 700, yEnd: 300, ms: 400),
    Wait(500),
    Snap('16b-documents-scrolled'),
  ]),

  TourFlow('17-driver-vehicle', 'Vehículo Conductor', [
    Nav('/driver/vehicle-management', label: 'Vehículo'),
    Wait(2500),
    Snap('17a-vehicle'),
    Scroll(x: 200, yStart: 700, yEnd: 300, ms: 400),
    Wait(500),
    Snap('17b-vehicle-scrolled'),
  ]),

  TourFlow('18-driver-transactions', 'Transacciones', [
    Nav('/driver/transactions-history', label: 'Transacciones'),
    Wait(2500),
    Snap('18a-transactions'),
    Scroll(x: 200, yStart: 700, yEnd: 300, ms: 400),
    Wait(500),
    Snap('18b-transactions-scrolled'),
  ]),

  TourFlow('19-driver-earnings-details', 'Detalle Ganancias', [
    Nav('/driver/earnings-details', label: 'Ganancias'),
    Wait(2500),
    Snap('19a-earnings'),
    Scroll(x: 200, yStart: 700, yEnd: 300, ms: 400),
    Wait(500),
    Snap('19b-earnings-scrolled'),
  ]),

  TourFlow('20-driver-settings', 'Configuración Driver', [
    Nav('/driver/settings', label: 'Settings driver'),
    Wait(2500),
    Snap('20a-settings-driver'),
    Scroll(x: 200, yStart: 700, yEnd: 300, ms: 400),
    Wait(500),
    Snap('20b-settings-driver-scrolled'),
  ]),

  TourFlow('21-driver-security', 'Seguridad Driver', [
    Nav('/driver/security', label: 'Seguridad'),
    Wait(2500),
    Snap('21a-security'),
    Scroll(x: 200, yStart: 700, yEnd: 300, ms: 400),
    Wait(500),
    Snap('21b-security-scrolled'),
  ]),

  TourFlow('22-driver-ride-config', 'Config Ride', [
    Nav('/driver/ride-config', label: 'Ride config'),
    Wait(2500),
    Snap('22a-ride-config'),
    Scroll(x: 200, yStart: 700, yEnd: 300, ms: 400),
    Wait(500),
    Snap('22b-ride-config-scrolled'),
  ]),

  TourFlow('23-driver-notifications', 'Notificaciones Driver', [
    Nav('/driver/notifications', label: 'Notifs driver'),
    Wait(2500),
    Snap('23a-notifs-driver'),
  ]),

  TourFlow('24-driver-negotiations', 'Negociaciones Driver', [
    Nav('/driver/negotiations', label: 'Negos driver'),
    Wait(2500),
    Snap('24a-negos-driver'),
  ]),

  TourFlow('25-driver-registration-type', 'Registro Tipo', [
    Nav('/driver/registration-type', label: 'Registro tipo'),
    Wait(2500),
    Snap('25a-registration-type'),
    Tap(200, 380, note: 'Card full time'),
    Wait(700),
    Snap('25b-registration-type-selected'),
  ]),

  TourFlow('26-shared-upgrade', 'Ser Conductor', [
    Nav('/shared/upgrade-to-driver', label: 'Upgrade'),
    Wait(2500),
    Snap('26a-upgrade'),
    Scroll(x: 200, yStart: 700, yEnd: 300, ms: 400),
    Wait(500),
    Snap('26b-upgrade-scrolled'),
  ]),

  TourFlow('27-shared-notifications', 'Notificaciones', [
    Nav('/shared/notifications', label: 'Notifs shared'),
    Wait(2500),
    Snap('27a-notifs'),
    Scroll(x: 200, yStart: 700, yEnd: 300, ms: 400),
    Wait(500),
    Snap('27b-notifs-scrolled'),
  ]),

  TourFlow('28-shared-help', 'Centro de Ayuda', [
    Nav('/shared/help-center', label: 'Ayuda'),
    Wait(2500),
    Snap('28a-help'),
    Scroll(x: 200, yStart: 700, yEnd: 300, ms: 400),
    Wait(500),
    Snap('28b-help-scrolled'),
  ]),

  TourFlow('29-shared-support', 'Soporte', [
    Nav('/shared/support', label: 'Soporte'),
    Wait(2500),
    Snap('29a-support'),
    Scroll(x: 200, yStart: 700, yEnd: 300, ms: 400),
    Wait(500),
    Snap('29b-support-scrolled'),
  ]),

  TourFlow('30-shared-about', 'Acerca de', [
    Nav('/shared/about', label: 'About'),
    Wait(2500),
    Snap('30a-about'),
    Scroll(x: 200, yStart: 700, yEnd: 300, ms: 400),
    Wait(500),
    Snap('30b-about-scrolled'),
  ]),

  TourFlow('31-shared-settings', 'Configuración', [
    Nav('/shared/settings', label: 'Settings'),
    Wait(2500),
    Snap('31a-settings'),
    Scroll(x: 200, yStart: 700, yEnd: 300, ms: 400),
    Wait(500),
    Snap('31b-settings-scrolled'),
  ]),

  TourFlow('32-map-picker', 'Selector Mapa', [
    Nav('/map-picker', label: 'Map picker'),
    Wait(2500),
    Snap('32a-map-picker'),
  ]),

  TourFlow('33-login', 'Login Pantalla', [
    Nav('/login', label: 'Login'),
    Wait(2500),
    Snap('33a-login'),
    Tap(200, 305, note: 'Input teléfono'),
    Wait(700),
    Snap('33b-input-focused'),
    Tap(200, 800, note: 'Botón Google'),
    Wait(600),
    Snap('33c-oauth-tap'),
    Back(),
    Wait(800),
    Snap('33d-back-to-login'),
  ]),

  TourFlow('34-maintenance', 'Mantenimiento', [
    Nav('/maintenance', label: 'Mantenimiento'),
    Wait(2500),
    Snap('34a-maintenance'),
  ]),
];

// ─── Orchestrator ──────────────────────────────────────────────────────────

class DevTourOrchestrator {
  final NavigatorState navigator;
  final List<TourFlow> flows;
  int _pointer = 3001;

  DevTourOrchestrator({
    required this.navigator,
    this.flows = kTourFlows,
  });

  Future<void> start() async {
    debugPrint('TOUR_START:${flows.length}');
    for (int i = 0; i < flows.length; i++) {
      final flow = flows[i];
      debugPrint('TOUR_FLOW_START:${i + 1}/${flows.length}:${flow.id}:${flow.title}');
      await _runFlow(flow);
      debugPrint('TOUR_FLOW_END:${flow.id}');
    }
    debugPrint('TOUR_END');
  }

  Future<void> _runFlow(TourFlow flow) async {
    for (final step in flow.steps) {
      try {
        await _dispatch(step);
      } catch (e, st) {
        debugPrint('TOUR_STEP_ERROR:${flow.id}:$e\n$st');
      }
    }
  }

  Future<void> _dispatch(TourAction step) async {
    switch (step) {
      case Nav(:final route, :final args):
        try {
          navigator.pushReplacementNamed(route, arguments: args);
        } catch (e) {
          debugPrint('TOUR: nav to $route failed: $e');
        }
        break;
      case Wait(:final ms):
        await Future.delayed(Duration(milliseconds: ms));
        break;
      case Snap(:final tag):
        debugPrint('SCREENSHOT_MARKER:$tag');
        await Future.delayed(const Duration(milliseconds: 900));
        break;
      case Tap(:final x, :final y):
        await _simulateTap(x, y);
        break;
      case LongPress(:final x, :final y, :final ms):
        await _simulateLongPress(x, y, ms);
        break;
      case Scroll(:final x, :final yStart, :final yEnd, :final ms):
        await _simulateScroll(x, yStart, yEnd, ms);
        break;
      case TypeText(:final text):
        await _simulateTyping(text);
        break;
      case Back():
        try {
          if (navigator.canPop()) navigator.pop();
        } catch (_) {}
        break;
    }
  }

  Future<void> _simulateTap(double x, double y) async {
    final pointer = _pointer++;
    final pos = Offset(x, y);
    final downTime = Duration(microseconds: DateTime.now().microsecondsSinceEpoch);
    _dispatchPointer(PointerAddedEvent(pointer: pointer, position: pos, timeStamp: downTime));
    _dispatchPointer(PointerDownEvent(pointer: pointer, position: pos, timeStamp: downTime, buttons: kPrimaryButton));
    await Future.delayed(const Duration(milliseconds: 80));
    final upTime = Duration(microseconds: DateTime.now().microsecondsSinceEpoch);
    _dispatchPointer(PointerUpEvent(pointer: pointer, position: pos, timeStamp: upTime));
    _dispatchPointer(PointerRemovedEvent(pointer: pointer, position: pos, timeStamp: upTime));
    await Future.delayed(const Duration(milliseconds: 250));
  }

  Future<void> _simulateLongPress(double x, double y, int ms) async {
    final pointer = _pointer++;
    final pos = Offset(x, y);
    final downTime = Duration(microseconds: DateTime.now().microsecondsSinceEpoch);
    _dispatchPointer(PointerAddedEvent(pointer: pointer, position: pos, timeStamp: downTime));
    _dispatchPointer(PointerDownEvent(pointer: pointer, position: pos, timeStamp: downTime, buttons: kPrimaryButton));
    await Future.delayed(Duration(milliseconds: ms));
    final upTime = Duration(microseconds: DateTime.now().microsecondsSinceEpoch);
    _dispatchPointer(PointerUpEvent(pointer: pointer, position: pos, timeStamp: upTime));
    _dispatchPointer(PointerRemovedEvent(pointer: pointer, position: pos, timeStamp: upTime));
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _simulateScroll(double x, double yStart, double yEnd, int ms) async {
    final pointer = _pointer++;
    final startTime = Duration(microseconds: DateTime.now().microsecondsSinceEpoch);
    final startPos = Offset(x, yStart);

    _dispatchPointer(PointerAddedEvent(pointer: pointer, position: startPos, timeStamp: startTime));
    _dispatchPointer(PointerDownEvent(pointer: pointer, position: startPos, timeStamp: startTime, buttons: kPrimaryButton));

    const steps = 20;
    for (int i = 1; i <= steps; i++) {
      final t = i / steps;
      final currentY = yStart + (yEnd - yStart) * t;
      final currentPos = Offset(x, currentY);
      await Future.delayed(Duration(milliseconds: ms ~/ steps));
      final now = Duration(microseconds: DateTime.now().microsecondsSinceEpoch);
      _dispatchPointer(PointerMoveEvent(pointer: pointer, position: currentPos, timeStamp: now, buttons: kPrimaryButton));
    }

    final upTime = Duration(microseconds: DateTime.now().microsecondsSinceEpoch);
    final endPos = Offset(x, yEnd);
    _dispatchPointer(PointerUpEvent(pointer: pointer, position: endPos, timeStamp: upTime));
    _dispatchPointer(PointerRemovedEvent(pointer: pointer, position: endPos, timeStamp: upTime));
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _simulateTyping(String text) async {
    // Best-effort: envía al canal de texto de Flutter.
    // Requiere que un TextField esté enfocado antes.
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      try {
        await SystemChannels.textInput.invokeMethod(
          'TextInputClient.updateEditingState',
          {'text': text.substring(0, i + 1)},
        );
      } catch (_) {
        // Ignora — el TextInputClient puede no estar disponible.
      }
      await Future.delayed(const Duration(milliseconds: 60));
      // Ignore unused warning
      if (char.isEmpty) {}
    }
    await Future.delayed(const Duration(milliseconds: 300));
  }

  void _dispatchPointer(PointerEvent event) {
    try {
      GestureBinding.instance.handlePointerEvent(event);
    } catch (e) {
      debugPrint('TOUR pointer dispatch error: $e');
    }
  }

  void dispose() {}
}

// ─── Compatibilidad con versión previa ────────────────────────────────────
// Estas constantes las sigue usando `modern_splash_screen.dart` para el print
// de status. Mantenemos los nombres para no romper el import.

class TourStop {
  final String label;
  final String route;
  final Map<String, dynamic>? args;
  const TourStop(this.label, this.route, {this.args});
}

const List<TourStop> kTourStops = [
  TourStop('interactivo', '/passenger/home'),
];
