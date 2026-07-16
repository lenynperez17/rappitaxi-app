/// Cliente SSE (Server-Sent Events) para eventos en tiempo real del backend.
/// -----------------------------------------------------------------------------
/// Reemplaza el patrón Firestore `snapshots()` con un único stream de eventos
/// tipados. El backend Node emite:
///   - notification    → nueva notificación (in-app)
///   - ride_update     → cambio de estado de viaje
///   - new_message     → mensaje de chat recibido
///   - driver_location → ubicación en tiempo real del conductor del viaje activo
///   - negotiation     → nueva contraoferta / oferta aceptada
///
/// Uso típico en un provider:
///   final sse = RapiSseClient.instance;
///   sse.rideUpdates.listen((json) => setState(...));
///   sse.start();  // idempotente
///
/// Se reconecta automáticamente si se cae (backoff exponencial 1s → 30s).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import 'rapi_api_client.dart';

/// Representa un evento SSE parseado.
class SseEvent {
  final String event;
  final Map<String, dynamic> data;
  const SseEvent(this.event, this.data);
}

class RapiSseClient {
  RapiSseClient._();
  static final RapiSseClient instance = RapiSseClient._();

  final _notificationsCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _rideUpdatesCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _newMessagesCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _driverLocationCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _negotiationCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _connectedCtrl = StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get notifications => _notificationsCtrl.stream;
  Stream<Map<String, dynamic>> get rideUpdates => _rideUpdatesCtrl.stream;
  Stream<Map<String, dynamic>> get newMessages => _newMessagesCtrl.stream;
  Stream<Map<String, dynamic>> get driverLocations => _driverLocationCtrl.stream;
  Stream<Map<String, dynamic>> get negotiations => _negotiationCtrl.stream;
  Stream<bool> get connected => _connectedCtrl.stream;

  http.Client? _client;
  StreamSubscription<String>? _sub;
  Timer? _reconnectTimer;
  int _backoffSec = 1;
  bool _running = false;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  /// Arranca el stream. Idempotente: llamar varias veces no crea múltiples.
  void start() {
    if (_running) return;
    _running = true;
    _connect();
  }

  /// Detiene el stream. Llamar en logout.
  Future<void> stop() async {
    _running = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _sub?.cancel();
    _sub = null;
    _client?.close();
    _client = null;
    _updateConnected(false);
  }

  Future<void> dispose() async {
    await stop();
    await _notificationsCtrl.close();
    await _rideUpdatesCtrl.close();
    await _newMessagesCtrl.close();
    await _driverLocationCtrl.close();
    await _negotiationCtrl.close();
    await _connectedCtrl.close();
  }

  void _updateConnected(bool value) {
    if (_isConnected == value) return;
    _isConnected = value;
    if (!_connectedCtrl.isClosed) _connectedCtrl.add(value);
  }

  Future<void> _connect() async {
    if (!_running) return;
    if (!RapiApiClient.instance.isSignedIn) {
      _scheduleReconnect();
      return;
    }

    // Pedir ticket SSE de un solo uso — evita exponer el JWT en la URL.
    String urlString;
    try {
      urlString = await RapiApiClient.instance.getSseStreamUrl();
    } catch (_) {
      _scheduleReconnect();
      return;
    }
    final url = Uri.parse(urlString);
    _client?.close();
    _client = http.Client();

    try {
      final req = http.Request('GET', url);
      req.headers['Accept'] = 'text/event-stream';
      req.headers['Cache-Control'] = 'no-cache';

      final resp = await _client!.send(req);
      if (resp.statusCode != 200) {
        // Token inválido: intentar refresh. Si el refresh falla (sesión
        // revocada), NO seguir reconectando en loop — el guard de auth de
        // la UI debe hacerse cargo del logout.
        if (resp.statusCode == 401) {
          final refreshed = await RapiApiClient.instance.refreshAccessToken();
          if (!refreshed) {
            debugPrint('[SSE] Refresh fallido tras 401 — deteniendo reconnect');
            _updateConnected(false);
            // Ronda 92: resetear _running para que un futuro start() (tras
            // re-login sin reiniciar la app) pueda reconectar. Sin esto,
            // SSE quedaba muerto permanentemente y no llegaban ride_update
            // ni new_message ni notifications hasta reinicio total.
            _running = false;
            _reconnectTimer?.cancel();
            _reconnectTimer = null;
            return;
          }
        }
        _scheduleReconnect();
        return;
      }

      _backoffSec = 1;
      _updateConnected(true);

      // El body es un stream de bytes → decodificar como texto UTF-8 línea por línea
      final lines = resp.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      String currentEvent = 'message';
      final buffer = StringBuffer();

      _sub = lines.listen(
        (line) {
          if (line.isEmpty) {
            // Fin de un evento — flush
            if (buffer.isNotEmpty) {
              _dispatch(currentEvent, buffer.toString());
              buffer.clear();
              currentEvent = 'message';
            }
            return;
          }
          if (line.startsWith(':')) {
            // comentario/ping → ignorar (mantiene conexión viva)
            return;
          }
          if (line.startsWith('event:')) {
            currentEvent = line.substring(6).trim();
            return;
          }
          if (line.startsWith('data:')) {
            if (buffer.isNotEmpty) buffer.write('\n');
            buffer.write(line.substring(5).trim());
            return;
          }
          // otras líneas (id:, retry:) las ignoramos
        },
        onError: (_) {
          _updateConnected(false);
          _scheduleReconnect();
        },
        onDone: () {
          _updateConnected(false);
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _updateConnected(false);
      _scheduleReconnect();
    }
  }

  void _dispatch(String event, String data) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) return;
      switch (event) {
        case 'notification':
          if (!_notificationsCtrl.isClosed) _notificationsCtrl.add(json);
          break;
        case 'ride_update':
          if (!_rideUpdatesCtrl.isClosed) _rideUpdatesCtrl.add(json);
          break;
        case 'new_message':
          if (!_newMessagesCtrl.isClosed) _newMessagesCtrl.add(json);
          break;
        case 'driver_location':
          if (!_driverLocationCtrl.isClosed) _driverLocationCtrl.add(json);
          break;
        case 'negotiation':
          if (!_negotiationCtrl.isClosed) _negotiationCtrl.add(json);
          break;
        case 'session_revoked':
          // Ronda 170: backend (events/stream.ts Ronda 144) emite este evento
          // cuando el user hace logout desde otro device o su session fue
          // revocada por admin. Detener el stream inmediatamente para no
          // reintentar reconexión infinita — el próximo cold-start pedirá
          // login. Sin este handler, el cliente entraba en loop de
          // reconexión con backoff hasta agotar sesión secundaria.
          debugPrint('[sse] session revoked by server; stopping');
          _running = false;
          _reconnectTimer?.cancel();
          _sub?.cancel();
          if (!_connectedCtrl.isClosed) _connectedCtrl.add(false);
          break;
        default:
          // Evento desconocido — ignorar por forward compatibility
          break;
      }
    } catch (_) {
      // Datos mal formados — ignorar
    }
  }

  void _scheduleReconnect() {
    if (!_running) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _backoffSec), () {
      if (!_running) return;
      _connect();
    });
    // Backoff exponencial: 1s, 2s, 4s, 8s, 16s, 30s (tope)
    _backoffSec = (_backoffSec * 2).clamp(1, 30);
  }
}
