import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/logger.dart';

/// Ronda 286 — la única forma de tomar o elegir una foto en toda la app.
///
/// Nació de un fallo real: al registrarse como conductor, en el paso de las
/// fotos de los documentos, "la app se cierra y se vuelve a abrir" y no deja
/// terminar. No es un cierre: en Android, cuando la cámara pasa al frente, el
/// sistema puede **destruir la actividad de la app** para darle memoria a la
/// cámara. Al volver, Flutter arranca de cero y la foto —y todo lo que había
/// en pantalla— desaparece. Cuanta más memoria ocupe la app, antes la mata.
///
/// Había ocho pantallas tomando fotos, cada una a su manera, y ninguna hacía
/// las dos cosas que evitan esto:
///
///  1. **Acotar la foto.** Tres de ellas pedían la foto a resolución completa
///     (`imageQuality` sin `maxWidth`/`maxHeight`): un móvil actual entrega
///     12–50 MP y la app los decodificaba enteros. Siete documentos así
///     convertían a la app en la primera candidata a morir con la cámara
///     abierta. Aquí todas salen a 1920 px como máximo, que para un documento
///     o un rostro sobra.
///  2. **Recuperar la foto tras la muerte.** `image_picker` guarda en el lado
///     nativo el resultado de una toma cuya actividad fue destruida, y lo
///     entrega en [ImagePicker.retrieveLostData]. No se llamaba en ningún
///     sitio. Aquí [recover] lo hace, y además sabe *para qué* era la foto:
///     antes de abrir la cámara se apunta el [target] en preferencias, porque
///     el resultado nativo trae la imagen pero no dice a qué campo iba.
///
/// El [target] lleva prefijo de pantalla (`registration.documents.dni_front`)
/// para que una pantalla solo reclame las fotos que son suyas.
class PhotoPicker {
  PhotoPicker._();

  static final ImagePicker _picker = ImagePicker();

  /// Qué foto se estaba tomando cuando se abrió la cámara. Solo existe entre
  /// que se abre el selector y que devuelve; si sobrevive a un arranque es
  /// que el proceso murió a medias y hay algo que recuperar.
  static const String _pendingKey = 'photo_picker.pending_target';

  /// Lado mayor máximo. Para leer un DNI o reconocer una cara basta de sobra,
  /// y deja la foto en ~500 KB en vez de 5–15 MB.
  static const double _maxSide = 1920;
  static const int _quality = 85;

  /// Toma con la cámara o elige de la galería, acotada y con memoria de para
  /// qué era. Devuelve `null` si la persona canceló.
  static Future<XFile?> pick({
    required ImageSource source,
    required String target,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_pendingKey, target);
    try {
      return await _picker.pickImage(
        source: source,
        maxWidth: _maxSide,
        maxHeight: _maxSide,
        imageQuality: _quality,
        preferredCameraDevice: preferredCameraDevice,
      );
    } finally {
      // Si el proceso muere con la cámara abierta, este `finally` nunca corre
      // y la marca queda: es exactamente la señal que [recover] busca.
      await sp.remove(_pendingKey);
    }
  }

  /// La foto que se perdió si Android mató la app con la cámara abierta.
  ///
  /// Llamar al abrir cada pantalla que toma fotos. Solo devuelve algo si la
  /// toma pendiente era de esta pantalla ([prefix]); si era de otra, se deja
  /// para que la reclame esa. Solo Android: iOS no destruye la app por abrir
  /// la cámara.
  static Future<LostPhoto?> recover({required String prefix}) async {
    if (!Platform.isAndroid) return null;
    try {
      final sp = await SharedPreferences.getInstance();
      final target = sp.getString(_pendingKey);
      if (target == null || !target.startsWith(prefix)) return null;
      await sp.remove(_pendingKey);

      final response = await _picker.retrieveLostData();
      if (response.isEmpty) return null;
      final file = response.file;
      if (file == null) {
        if (response.exception != null) {
          AppLogger.warning(
              'La toma de $target no pudo recuperarse', response.exception);
        }
        return null;
      }
      AppLogger.info('Foto recuperada tras reinicio: $target');
      return LostPhoto(target: target, file: file);
    } catch (e) {
      // Recuperar es un extra; que falle no puede romper la pantalla.
      AppLogger.warning('No se pudo recuperar la foto pendiente', e);
      return null;
    }
  }

  /// Copia [photo] a un sitio que sobrevive a reinicios y limpiezas de caché.
  ///
  /// `image_picker` deja las fotos en la caché de la app, y Android puede
  /// vaciarla cuando anda corto de espacio. Para las fotos de un registro a
  /// medias eso sería perderlas: van al directorio de soporte, con un nombre
  /// fijo por [name] para que repetir una foto sustituya a la anterior.
  static Future<File> keep(XFile photo, String name) async {
    final dir =
        Directory('${(await getApplicationSupportDirectory()).path}/photos');
    await dir.create(recursive: true);
    return File(photo.path).copy('${dir.path}/$name.jpg');
  }

  /// Borra todo lo guardado con [keep]. Se llama al terminar o descartar el
  /// registro: son documentos personales y no deben quedarse en el teléfono.
  static Future<void> discardKept() async {
    try {
      final dir =
          Directory('${(await getApplicationSupportDirectory()).path}/photos');
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      AppLogger.warning('No se pudieron borrar las fotos guardadas', e);
    }
  }
}

/// Una foto rescatada por [PhotoPicker.recover]: la imagen y para qué era.
class LostPhoto {
  final String target;
  final XFile file;

  const LostPhoto({required this.target, required this.file});

  /// El último tramo del [target]: `registration.documents.dni_front` →
  /// `dni_front`. Es lo que cada pantalla usa para colocarla.
  String get name => target.substring(target.lastIndexOf('.') + 1);
}
