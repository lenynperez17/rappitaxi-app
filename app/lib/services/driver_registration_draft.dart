import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/photo_picker.dart';
import '../utils/logger.dart';

/// Ronda 286 — el alta de conductor a medias, guardada en el teléfono.
///
/// El registro son cuatro pantallas (tipo → datos personales → vehículo →
/// documentos) que se pasaban los datos en un `Map` de una a otra y en ningún
/// otro sitio. Cuando Android mataba la app con la cámara abierta —ver
/// [PhotoPicker]— ese mapa se evaporaba y el conductor volvía al inicio sin
/// nombre, sin selfie, sin vehículo y sin las fotos que ya había hecho. A la
/// segunda vez, la gente deja de intentarlo.
///
/// Cada paso guarda aquí lo suyo en cuanto lo tiene (una foto nada más
/// tomarla, el formulario al pulsar «Continuar»). Al abrir la app o al entrar
/// al registro, si hay borrador se ofrece continuar por donde iba. Se borra
/// al enviar la solicitud o al elegir empezar de nuevo.
class DriverRegistrationDraft {
  static const String _key = 'driver_registration.draft';

  static const String stepPersonal = 'personal';
  static const String stepVehicle = 'vehicle';
  static const String stepDocuments = 'documents';

  /// Si el borrador se tocó hace menos de esto, el arranque lleva directo a
  /// la pantalla donde estaba: es un reinicio a medias, no un registro
  /// abandonado. Pasado el plazo se pregunta en vez de arrastrar a nadie.
  static const Duration _freshWindow = Duration(minutes: 15);

  final String step;
  final Map<String, dynamic> data;
  final DateTime updatedAt;

  const DriverRegistrationDraft._({
    required this.step,
    required this.data,
    required this.updatedAt,
  });

  bool get isFresh => DateTime.now().difference(updatedAt) < _freshWindow;

  String get route => switch (step) {
        stepPersonal => '/driver/register/personal',
        stepVehicle => '/driver/register/vehicle',
        _ => '/driver/register/documents',
      };

  /// Lo que espera cada ruta en `arguments` (ver `main.dart`): la personal
  /// solo el tipo de trabajo; las otras dos, todo el mapa.
  Map<String, dynamic> get arguments => step == stepPersonal
      ? <String, dynamic>{'workType': data['workType'] ?? 'auto'}
      : Map<String, dynamic>.from(data);

  /// Fotos de documentos ya tomadas: tipo → ruta local.
  Map<String, String> get documents {
    final raw = data['documents'];
    if (raw is! Map) return const {};
    return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
  }

  static Future<DriverRegistrationDraft?> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_key);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return DriverRegistrationDraft._(
        step: json['step'] as String? ?? stepPersonal,
        data: Map<String, dynamic>.from(json['data'] as Map? ?? const {}),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
    } catch (e) {
      AppLogger.warning('Borrador de registro ilegible; se descarta', e);
      return null;
    }
  }

  /// Guarda fusionando con lo que ya había: cada paso aporta sus campos sin
  /// pisar los de los demás, y las fotos de documentos se acumulan.
  static Future<void> save({
    required String step,
    required Map<String, dynamic> data,
  }) async {
    try {
      final previous = await load();
      final merged = <String, dynamic>{...?previous?.data, ...data};
      final previousDocs = previous?.data['documents'];
      final newDocs = data['documents'];
      if (previousDocs is Map && newDocs is Map) {
        merged['documents'] = <String, dynamic>{...previousDocs, ...newDocs};
      }
      final sp = await SharedPreferences.getInstance();
      await sp.setString(
        _key,
        jsonEncode({
          'step': step,
          'data': merged,
          'updatedAt': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      // Guardar el borrador es una red de seguridad; si falla, el registro
      // sigue funcionando como siempre.
      AppLogger.warning('No se pudo guardar el borrador de registro', e);
    }
  }

  /// Apunta una foto de documento recién tomada.
  static Future<void> saveDocument(String type, String path) =>
      save(step: stepDocuments, data: {
        'documents': {type: path},
      });

  /// Se acabó: solicitud enviada o registro descartado. Borra también las
  /// fotos guardadas, que son documentos personales.
  static Future<void> clear() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_key);
    } catch (e) {
      AppLogger.warning('No se pudo borrar el borrador de registro', e);
    }
    await PhotoPicker.discardKept();
  }
}
