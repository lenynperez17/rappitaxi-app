import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:widget_to_marker/widget_to_marker.dart';

/// Marcadores premium de mapa usando widgets Flutter reales
///
/// Cada marcador es un widget con sombras, bordes, gradientes e imágenes 3D
/// convertido a BitmapDescriptor con widget_to_marker.
class MapMarkerUtils {
  static final Map<String, BitmapDescriptor> _iconCache = {};

  // Colores corporativos
  static const Color _rappiOrange = Color(0xFFE31E24);
  static const Color _googleBlue = Color(0xFF4285F4);

  // Tamaños de renderizado (3x para nitidez HD)
  static const Size _logicalSize = Size(56, 64);
  static const Size _imageSize = Size(168, 192);
  static const Size _squareLogical = Size(56, 56);
  static const Size _squareImage = Size(168, 168);
  static const Size _smallLogical = Size(40, 40);
  static const Size _smallImage = Size(120, 120);

  // ==================== CONDUCTOR ====================

  /// Auto vista aérea en burbuja blanca con glow verde
  static Future<BitmapDescriptor> getCarTopViewIcon({
    String serviceType = 'standard',
  }) async {
    final key = 'car_top_$serviceType';
    if (_iconCache.containsKey(key)) return _iconCache[key]!;

    // TODO: Use glow color based on service type (xl, premium, standard) for marker effects

    final icon = await SizedBox(
      width: 52,
      height: 52,
      child: Image.asset(
        'assets/images/markers/car_top_view.png',
        fit: BoxFit.contain,
      ),
    ).toBitmapDescriptor(
      logicalSize: _squareLogical,
      imageSize: _squareImage,
      waitToRender: const Duration(milliseconds: 500),
    );

    _iconCache[key] = icon;
    return icon;
  }

  // ==================== ORIGEN ====================

  /// Pin verde premium para punto de recogida
  static Future<BitmapDescriptor> getOriginIcon({
    int size = 120,
    Color color = _rappiOrange,
  }) async {
    const key = 'origin';
    if (_iconCache.containsKey(key)) return _iconCache[key]!;

    final icon = await _buildPinMarker(
      color: _rappiOrange,
      icon: Icons.trip_origin,
      iconColor: Colors.white,
    );
    _iconCache[key] = icon;
    return icon;
  }

  // ==================== DESTINO ====================

  /// Diana 3D en tarjeta premium con sombra roja
  static Future<BitmapDescriptor> getDestinationIcon({
    int size = 100,
    Color color = const Color(0xFFE53935),
  }) async {
    const key = 'destination';
    if (_iconCache.containsKey(key)) return _iconCache[key]!;

    final icon = await Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE53935), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE53935).withValues(alpha: 0.35),
                blurRadius: 8,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(3),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/markers/destination_3d.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        // Punta del pin
        CustomPaint(
          size: const Size(14, 10),
          painter: _PinTailPainter(color: const Color(0xFFE53935)),
        ),
      ],
    ).toBitmapDescriptor(
      logicalSize: _logicalSize,
      imageSize: _imageSize,
      waitToRender: const Duration(milliseconds: 500),
    );

    _iconCache[key] = icon;
    return icon;
  }

  // ==================== PASAJERO ====================

  /// Personita azul premium en burbuja con sombra
  static Future<BitmapDescriptor> getPassengerIcon({
    int size = 120,
    Color color = const Color(0xFF1976D2),
  }) async {
    const key = 'passenger';
    if (_iconCache.containsKey(key)) return _iconCache[key]!;

    const passengerBlue = Color(0xFF1976D2);

    final icon = await Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: passengerBlue, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: passengerBlue.withValues(alpha: 0.35),
                blurRadius: 8,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.person,
            color: passengerBlue,
            size: 26,
          ),
        ),
        CustomPaint(
          size: const Size(12, 8),
          painter: _PinTailPainter(color: passengerBlue),
        ),
      ],
    ).toBitmapDescriptor(
      logicalSize: _logicalSize,
      imageSize: _imageSize,
      waitToRender: const Duration(milliseconds: 500),
    );

    _iconCache[key] = icon;
    return icon;
  }

  /// Personita verde esperando taxi con glow verde
  static Future<BitmapDescriptor> getPassengerWaitingIcon({
    int size = 120,
    Color color = _rappiOrange,
  }) async {
    const key = 'passenger_waiting';
    if (_iconCache.containsKey(key)) return _iconCache[key]!;

    final icon = await Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: _rappiOrange, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: _rappiOrange.withValues(alpha: 0.4),
                blurRadius: 10,
                spreadRadius: 3,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.person,
            color: Color(0xFFE31E24),
            size: 26,
          ),
        ),
        CustomPaint(
          size: const Size(12, 8),
          painter: _PinTailPainter(color: _rappiOrange),
        ),
      ],
    ).toBitmapDescriptor(
      logicalSize: _logicalSize,
      imageSize: _imageSize,
      waitToRender: const Duration(milliseconds: 500),
    );

    _iconCache[key] = icon;
    return icon;
  }

  // ==================== UBICACIÓN ACTUAL ====================

  /// Punto azul GPS estilo Google Maps premium
  static Future<BitmapDescriptor> getCurrentLocationIcon({
    double pulsePhase = 0.0,
    int size = 100,
    Color color = _googleBlue,
  }) async {
    const key = 'current_location';
    if (_iconCache.containsKey(key)) return _iconCache[key]!;

    final icon = await Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _googleBlue.withValues(alpha: 0.1),
      ),
      child: Center(
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _googleBlue.withValues(alpha: 0.2),
          ),
          child: Center(
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: _googleBlue.withValues(alpha: 0.4),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: _googleBlue,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ).toBitmapDescriptor(
      logicalSize: _smallLogical,
      imageSize: _smallImage,
    );

    _iconCache[key] = icon;
    return icon;
  }

  // ==================== SOLICITUD DE TAXI ====================

  /// Taxi amarillo 3D frontal en tarjeta premium
  static Future<BitmapDescriptor> getRequestIcon({
    int size = 110,
    Color color = const Color(0xFFFF9800),
  }) async {
    const key = 'request';
    if (_iconCache.containsKey(key)) return _iconCache[key]!;

    final icon = await Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFFF9800),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF9800).withValues(alpha: 0.35),
                blurRadius: 8,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/images/markers/car_3d.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        CustomPaint(
          size: const Size(14, 10),
          painter: _PinTailPainter(color: const Color(0xFFFF9800)),
        ),
      ],
    ).toBitmapDescriptor(
      logicalSize: _logicalSize,
      imageSize: _imageSize,
      waitToRender: const Duration(milliseconds: 500),
    );

    _iconCache[key] = icon;
    return icon;
  }

  // ==================== CONDUCTOR ONLINE/BUSY ====================

  /// Conductor online - auto con glow verde
  static Future<BitmapDescriptor> getDriverOnlineIcon() async {
    const key = 'driver_online';
    if (_iconCache.containsKey(key)) return _iconCache[key]!;

    final icon = await getCarTopViewIcon(serviceType: 'standard');
    _iconCache[key] = icon;
    return icon;
  }

  /// Conductor ocupado - taxi frontal con borde gris
  static Future<BitmapDescriptor> getDriverBusyIcon() async {
    const key = 'driver_busy';
    if (_iconCache.containsKey(key)) return _iconCache[key]!;

    final icon = await Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade400, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: ClipOval(
        child: ColorFiltered(
          colorFilter: const ColorFilter.mode(
            Color(0x40000000),
            BlendMode.darken,
          ),
          child: Image.asset(
            'assets/images/markers/car_3d.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    ).toBitmapDescriptor(
      logicalSize: _squareLogical,
      imageSize: _squareImage,
      waitToRender: const Duration(milliseconds: 500),
    );

    _iconCache[key] = icon;
    return icon;
  }

  // ==================== FAVORITOS ====================

  /// Pin premium con icono Material según tipo
  static Future<BitmapDescriptor> getFavoriteIcon({
    String type = 'default',
    int size = 100,
  }) async {
    final key = 'favorite_$type';
    if (_iconCache.containsKey(key)) return _iconCache[key]!;

    final Color pinColor;
    final IconData pinIcon;
    switch (type) {
      case 'home':
        pinColor = const Color(0xFF4CAF50);
        pinIcon = Icons.home_rounded;
      case 'work':
        pinColor = const Color(0xFF1976D2);
        pinIcon = Icons.work_rounded;
      case 'gym':
        pinColor = const Color(0xFFFF9800);
        pinIcon = Icons.fitness_center_rounded;
      default:
        pinColor = _rappiOrange;
        pinIcon = Icons.star_rounded;
    }

    final icon = await _buildPinMarker(
      color: pinColor,
      icon: pinIcon,
      iconColor: Colors.white,
    );
    _iconCache[key] = icon;
    return icon;
  }

  // ==================== UTILIDADES ====================

  static void clearCache() {
    _iconCache.clear();
  }

  /// Pre-carga todos los iconos para que estén listos al abrir el mapa
  static Future<void> preloadAllIcons() async {
    await Future.wait([
      getCarTopViewIcon(),
      getOriginIcon(),
      getDestinationIcon(),
      getPassengerIcon(),
      getCurrentLocationIcon(),
      getRequestIcon(),
      getDriverOnlineIcon(),
      getDriverBusyIcon(),
      getPassengerWaitingIcon(),
      getFavoriteIcon(type: 'home'),
      getFavoriteIcon(type: 'work'),
    ]);
  }

  // ==================== HELPERS PRIVADOS ====================

  /// Crea un marcador estilo pin con icono Material adentro
  static Future<BitmapDescriptor> _buildPinMarker({
    required Color color,
    required IconData icon,
    required Color iconColor,
  }) async {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(color, Colors.white, 0.2)!,
                color,
                Color.lerp(color, Colors.black, 0.15)!,
              ],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 6,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        CustomPaint(
          size: const Size(12, 8),
          painter: _PinTailPainter(color: color),
        ),
      ],
    ).toBitmapDescriptor(
      logicalSize: _logicalSize,
      imageSize: _imageSize,
    );
  }
}

/// Pinta la punta triangular del pin
class _PinTailPainter extends CustomPainter {
  final Color color;
  _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
