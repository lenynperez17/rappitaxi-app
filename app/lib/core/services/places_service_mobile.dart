// Stub para compilación móvil - el servicio HTTP se usará en su lugar

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
}

class PlacesServiceWeb {
  static Future<List<PlacesSuggestion>> searchPlaces(String query) async {
    return [];
  }

  static Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    return null;
  }

  static Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    return null;
  }

  static Future<PlaceDetails?> getCoordinatesFromAddress(String address) async {
    return null;
  }
}