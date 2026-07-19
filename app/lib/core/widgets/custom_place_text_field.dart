import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../../services/rapi_api_client.dart';
import '../../utils/logger.dart';
import '../../utils/error_messages.dart';

/// ✅ WIDGET CUSTOM: Resuelve problema de borrado del teclado
///
/// Este widget usa flutter_typeahead en lugar de google_places_flutter porque:
/// - flutter_typeahead NO recrea el TextField en cada keystroke
/// - Mantiene el InputConnection estable, permitiendo borrado continuo
/// - Solo actualiza el Overlay de sugerencias sin afectar el TextField
///
/// PROBLEMA RESUELTO:
/// - Antes: GooglePlaceAutoCompleteTextField recreaba el TextField → InputConnection perdido → borrado letra por letra
/// - Ahora: TypeAheadField mantiene TextField estable → InputConnection preservado → borrado continuo ✅
class CustomPlaceTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final String googleApiKey;
  final Function(PlacePrediction) onPlaceSelected;
  final VoidCallback? onTap;

  const CustomPlaceTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.googleApiKey,
    required this.onPlaceSelected,
    this.onTap,
  });

  @override
  State<CustomPlaceTextField> createState() => _CustomPlaceTextFieldState();
}

class _CustomPlaceTextFieldState extends State<CustomPlaceTextField> {
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
  }

  /// ✅ Búsqueda de lugares con debounce para evitar llamadas excesivas al API
  Future<List<PlacePrediction>> _searchPlaces(String query) async {
    // Si el query está vacío, no hacer búsqueda
    if (query.isEmpty) {
      return [];
    }

    try {
      // Usa backend Node en VPS: Google Places (si key/billing OK) → fallback OSM Nominatim.
      final data = await RapiApiClient.instance.mapsAutocomplete(query: query);
      final preds = (data['predictions'] as List?) ?? const [];
      final predictions = preds
          .whereType<Map<String, dynamic>>()
          .map((p) => PlacePrediction(
                placeId: (p['placeId'] as String?) ?? '',
                description: (p['description'] as String?) ?? '',
                mainText: (p['mainText'] as String?) ?? (p['description'] as String?) ?? '',
                secondaryText: (p['secondaryText'] as String?) ?? '',
                lat: (p['lat'] as num?)?.toDouble(),
                lng: (p['lng'] as num?)?.toDouble(),
              ))
          .toList();
      AppLogger.debug('Places (${data['provider']}): ${predictions.length} resultados para "$query"');
      return predictions;
    } catch (e) {
      AppLogger.error(userFriendlyError(e, fallback: 'Error buscando lugares'));
      return [];
    }
  }

  /// Obtener detalles completos del lugar (lat, lng) cuando se selecciona.
  ///
  /// Ronda 216: usa el proxy backend `/api/maps/place-details` (Nominatim +
  /// cascada) en vez de Google Places directo. La versión anterior mandaba la
  /// key móvil (`googleApiKey`) que está restringida a Maps SDK, así que la
  /// llamada devolvía REQUEST_DENIED y esta función retornaba null → el
  /// `onSelected` del TypeAhead no ejecutaba onPlaceSelected → la app se
  /// quedaba con el texto pegado pero SIN pasar a la pantalla de ruta.
  Future<PlaceDetails?> _getPlaceDetails(String placeId) async {
    try {
      final data = await RapiApiClient.instance.mapsPlaceDetails(placeId);
      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) {
        AppLogger.warning('placeDetails devolvió sin lat/lng: $data');
        return null;
      }
      return PlaceDetails(
        formattedAddress: (data['formattedAddress'] as String?) ?? '',
        name: (data['name'] as String?) ?? '',
        lat: lat,
        lng: lng,
      );
    } catch (e) {
      AppLogger.error(userFriendlyError(e, fallback: 'Error obteniendo detalles del lugar'));
      return null;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TypeAheadField<PlacePrediction>(
      controller: widget.controller,

      /// ✅ CLAVE: debounceDuration evita llamadas excesivas al API
      /// Reducido a 500ms para respuesta más rápida (antes 800ms)
      debounceDuration: const Duration(milliseconds: 500),

      /// ✅ suggestionsCallback: se llama para obtener sugerencias
      /// NO recrea el TextField, solo actualiza el Overlay
      suggestionsCallback: (search) async {
        return await _searchPlaces(search);
      },

      /// ✅ itemBuilder: cómo mostrar cada sugerencia
      itemBuilder: (context, PlacePrediction suggestion) {
        final colorScheme = Theme.of(context).colorScheme;
        return ListTile(
          leading: Icon(
            Icons.location_on,
            color: colorScheme.primary,
          ),
          title: Text(
            suggestion.mainText,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            suggestion.secondaryText,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        );
      },

      /// ✅ onSelected: cuando el usuario selecciona una sugerencia
      onSelected: (PlacePrediction suggestion) async {
        // Actualizar el texto del campo
        widget.controller.text = suggestion.description;

        // Ronda 104: si el backend ya devolvió lat/lng (fallback OSM/Nominatim),
        // emitir directo sin llamar a Google Places (que fallaría con
        // INVALID_REQUEST por el placeId de OSM). Antes: user tocaba sugerencia
        // OSM y no pasaba nada porque details=null.
        if (suggestion.lat != null && suggestion.lng != null) {
          widget.onPlaceSelected(suggestion);
          return;
        }

        // Obtener detalles completos (lat, lng)
        final details = await _getPlaceDetails(suggestion.placeId);

        if (details != null) {
          // Crear objeto completo con toda la información
          final completePrediction = PlacePrediction(
            placeId: suggestion.placeId,
            description: suggestion.description,
            mainText: suggestion.mainText,
            secondaryText: suggestion.secondaryText,
            lat: details.lat,
            lng: details.lng,
          );

          // Notificar al padre
          widget.onPlaceSelected(completePrediction);
        }
      },

      /// ✅ builder: el TextField que se muestra (NUNCA se recrea)
      builder: (context, controller, focusNode) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          onTap: widget.onTap,
          decoration: InputDecoration(
            hintText: widget.hintText,
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      controller.clear();
                    },
                  )
                : null,
          ),
          style: const TextStyle(fontSize: 15),
        );
      },

      /// ✅ CRÍTICO: Constraints para el overlay de sugerencias
      /// Asegura que las sugerencias tengan espacio suficiente para mostrarse
      constraints: const BoxConstraints(
        maxHeight: 300, // Altura máxima del overlay
      ),

      /// ✅ Configuración del Overlay de sugerencias
      hideOnEmpty: true,
      hideOnLoading: false,
      hideOnError: false,

      /// ✅ Mensaje cuando no hay resultados
      emptyBuilder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'No se encontraron lugares',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),

      /// ✅ Indicador de carga
      loadingBuilder: (context) => const Padding(
        padding: EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Buscando lugares...'),
          ],
        ),
      ),

      /// ✅ Decoración mejorada del Overlay con sombra más visible
      decorationBuilder: (context, child) {
        final colorScheme = Theme.of(context).colorScheme;
        return Material(
          elevation: 8, // Aumentado de 4 a 8 para mejor visibilidad
          borderRadius: BorderRadius.circular(8),
          color: colorScheme.surface, // Color de superficie adaptable al tema
          shadowColor: colorScheme.shadow.withValues(alpha: 0.3), // ✅ Sombra más visible
          child: child,
        );
      },
    );
  }
}

/// ✅ Modelo de datos para predicciones de Google Places
class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;
  final double? lat;
  final double? lng;

  PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
    this.lat,
    this.lng,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    return PlacePrediction(
      placeId: json['place_id'],
      description: json['description'],
      mainText: json['structured_formatting']['main_text'],
      secondaryText: json['structured_formatting']['secondary_text'] ?? '',
    );
  }
}

/// ✅ Modelo de datos para detalles completos del lugar
class PlaceDetails {
  final double lat;
  final double lng;
  final String formattedAddress;
  final String name;

  PlaceDetails({
    required this.lat,
    required this.lng,
    required this.formattedAddress,
    required this.name,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final location = json['geometry']['location'];
    return PlaceDetails(
      lat: (location['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (location['lng'] as num?)?.toDouble() ?? 0.0,
      formattedAddress: json['formatted_address'] ?? '',
      name: json['name'] ?? '',
    );
  }
}
