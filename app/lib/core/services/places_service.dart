import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config/app_config.dart';
import '../utils/logger.dart';

class PlacesSuggestion {
  final String placeId;
  final String description;
  final String? mainText;
  final String? secondaryText;

  PlacesSuggestion({
    required this.placeId,
    required this.description,
    this.mainText,
    this.secondaryText,
  });

  factory PlacesSuggestion.fromJson(Map<String, dynamic> json) {
    return PlacesSuggestion(
      placeId: (json['place_id'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      mainText: json['structured_formatting']?['main_text'],
      secondaryText: json['structured_formatting']?['secondary_text'],
    );
  }
}

class PlaceDetails {
  final String placeId;
  final String name;
  final String formattedAddress;
  final double latitude;
  final double longitude;

  PlaceDetails({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'];
    final location = geometry['location'];
    
    return PlaceDetails(
      placeId: (json['place_id'] as String?) ?? '',
      name: (json['name'] ?? json['formatted_address'])?.toString() ?? '',
      formattedAddress: (json['formatted_address'] as String?) ?? '',
      latitude: (location['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (location['lng'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PlacesService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';
  static const String _proxyUrl = 'http://localhost:3001/api';
  
  // Buscar sugerencias de lugares
  static Future<List<PlacesSuggestion>> searchPlaces(String query) async {
    if (query.isEmpty) return [];
    
    // Para web, usar proxy server
    if (kIsWeb) {
      try {
        final url = Uri.parse(
          '$_proxyUrl/places/autocomplete'
          '?input=${Uri.encodeComponent(query)}'
          '&language=es'
          '&components=country:pe'
        );

        Logger.info('Searching places via proxy: $query');
        
        final response = await http.get(url);
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          
          if (data['status'] == 'OK') {
            final predictions = data['predictions'] as List;
            Logger.info('Found ${predictions.length} suggestions via proxy');
            return predictions
                .map((prediction) => PlacesSuggestion.fromJson(prediction))
                .toList();
          } else {
            Logger.warning('Proxy Places API error: ${data['status']}');
            return [];
          }
        } else {
          Logger.error('Proxy HTTP error: ${response.statusCode}');
          return [];
        }
      } catch (e, stackTrace) {
        Logger.error('Error using proxy Places service', e, stackTrace);
        return [];
      }
    }
    
    // Usar HTTP API para móviles
    try {
      final url = Uri.parse(
        '$_baseUrl/place/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&key=${AppConfig.googleMapsApiKey}'
        '&language=es'
        '&components=country:pe'
      );

      Logger.info('Searching places: $query');
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
          return predictions
              .map((prediction) => PlacesSuggestion.fromJson(prediction))
              .toList();
        } else {
          Logger.warning('Places API error: ${data['status']}');
          return [];
        }
      } else {
        Logger.error('HTTP error: ${response.statusCode}');
        return [];
      }
    } catch (e, stackTrace) {
      Logger.error('Error searching places', e, stackTrace);
      return [];
    }
  }

  // Obtener detalles de un lugar específico
  static Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    // Para web, usar proxy server
    if (kIsWeb) {
      try {
        final url = Uri.parse(
          '$_proxyUrl/places/details'
          '?place_id=$placeId'
          '&language=es'
          '&fields=place_id,name,formatted_address,geometry'
        );

        Logger.info('Getting place details via proxy: $placeId');
        
        final response = await http.get(url);
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          
          if (data['status'] == 'OK') {
            Logger.info('Got place details via proxy');
            return PlaceDetails.fromJson(data['result']);
          } else {
            Logger.warning('Proxy Place details API error: ${data['status']}');
            return null;
          }
        } else {
          Logger.error('Proxy HTTP error: ${response.statusCode}');
          return null;
        }
      } catch (e, stackTrace) {
        Logger.error('Error using proxy Place details service', e, stackTrace);
        return null;
      }
    }
    
    // Usar HTTP API para móviles
    try {
      final url = Uri.parse(
        '$_baseUrl/place/details/json'
        '?place_id=$placeId'
        '&key=${AppConfig.googleMapsApiKey}'
        '&language=es'
        '&fields=place_id,name,formatted_address,geometry'
      );

      Logger.info('Getting place details: $placeId');
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          return PlaceDetails.fromJson(data['result']);
        } else {
          Logger.warning('Place details API error: ${data['status']}');
          return null;
        }
      } else {
        Logger.error('HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      Logger.error('Error getting place details', e, stackTrace);
      return null;
    }
  }

  // Geocodificación inversa (coordenadas a dirección)
  static Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/geocode/json'
        '?latlng=$latitude,$longitude'
        '&key=${AppConfig.googleMapsApiKey}'
        '&language=es'
      );

      Logger.info('Reverse geocoding: $latitude, $longitude');
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          return data['results'][0]['formatted_address'] as String?;
        } else {
          Logger.warning('Geocoding API error: ${data['status']}');
          return null;
        }
      } else {
        Logger.error('HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      Logger.error('Error in reverse geocoding', e, stackTrace);
      return null;
    }
  }

  // Geocodificación directa (dirección a coordenadas)
  static Future<PlaceDetails?> getCoordinatesFromAddress(String address) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/geocode/json'
        '?address=${Uri.encodeComponent(address)}'
        '&key=${AppConfig.googleMapsApiKey}'
        '&language=es'
        '&components=country:pe'
      );

      Logger.info('Geocoding address: $address');
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final result = data['results'][0];
          return PlaceDetails.fromJson(result);
        } else {
          Logger.warning('Geocoding API error: ${data['status']}');
          return null;
        }
      } else {
        Logger.error('HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      Logger.error('Error geocoding address', e, stackTrace);
      return null;
    }
  }
}