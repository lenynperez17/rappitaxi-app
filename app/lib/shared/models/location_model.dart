class LocationModel {
  final double latitude;
  final double longitude;
  final String address;
  final String? placeId;
  final String? name;
  final String? details;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;

  LocationModel({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.placeId,
    this.name,
    this.details,
    this.city,
    this.state,
    this.country,
    this.postalCode,
  });
  
  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      address: json['address'] as String? ?? '',
      placeId: json['placeId'],
      name: json['name'],
      details: json['details'],
      city: json['city'],
      state: json['state'],
      country: json['country'],
      postalCode: json['postalCode'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'placeId': placeId,
      'name': name,
      'details': details,
      'city': city,
      'state': state,
      'country': country,
      'postalCode': postalCode,
    };
  }
}

class RouteModel {
  final LocationModel origin;
  final LocationModel destination;
  final double distanceKm;
  final int durationMinutes;
  final String polyline;
  final List<LocationModel> waypoints;
  final Map<String, dynamic>? bounds;

  RouteModel({
    required this.origin,
    required this.destination,
    required this.distanceKm,
    required this.durationMinutes,
    required this.polyline,
    this.waypoints = const [],
    this.bounds,
  });
  
  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      origin: LocationModel.fromJson(json['origin']),
      destination: LocationModel.fromJson(json['destination']),
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      polyline: json['polyline'] as String? ?? '',
      waypoints: (json['waypoints'] as List<dynamic>?)
          ?.map((e) => LocationModel.fromJson(e))
          .toList() ?? [],
      bounds: json['bounds'] as Map<String, dynamic>?,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'origin': origin.toJson(),
      'destination': destination.toJson(),
      'distanceKm': distanceKm,
      'durationMinutes': durationMinutes,
      'polyline': polyline,
      'waypoints': waypoints.map((e) => e.toJson()).toList(),
      'bounds': bounds,
    };
  }
}