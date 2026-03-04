class DriverModel {
  final String id;
  final String name;
  final String phone;
  final String? photoUrl;
  final double rating;
  final int totalRides;
  final VehicleModel vehicle;
  final bool isOnline;
  final bool isAvailable;
  final LocationData? currentLocation;
  final List<String> languages;
  final DateTime? memberSince;

  DriverModel({
    required this.id,
    required this.name,
    required this.phone,
    this.photoUrl,
    required this.rating,
    required this.totalRides,
    required this.vehicle,
    required this.isOnline,
    required this.isAvailable,
    this.currentLocation,
    this.languages = const [],
    this.memberSince,
  });
  
  factory DriverModel.fromJson(Map<String, dynamic> json) {
    return DriverModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      photoUrl: json['photoUrl'],
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalRides: (json['totalRides'] as num?)?.toInt() ?? 0,
      vehicle: VehicleModel.fromJson(json['vehicle']),
      isOnline: json['isOnline'] as bool? ?? false,
      isAvailable: json['isAvailable'] as bool? ?? false,
      currentLocation: json['currentLocation'] != null
          ? LocationData.fromJson(json['currentLocation'])
          : null,
      languages: (json['languages'] as List<dynamic>?)?.cast<String>() ?? [],
      memberSince: json['memberSince'] != null
          ? DateTime.parse(json['memberSince'])
          : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'photoUrl': photoUrl,
      'rating': rating,
      'totalRides': totalRides,
      'vehicle': vehicle.toJson(),
      'isOnline': isOnline,
      'isAvailable': isAvailable,
      'currentLocation': currentLocation?.toJson(),
      'languages': languages,
      'memberSince': memberSince?.toIso8601String(),
    };
  }
}

class VehicleModel {
  final String brand;
  final String model;
  final int year;
  final String plate;
  final String color;
  final String type; // standard, premium, xl
  final int capacity;
  final String? photoUrl;

  VehicleModel({
    required this.brand,
    required this.model,
    required this.year,
    required this.plate,
    required this.color,
    this.type = 'standard',
    this.capacity = 4,
    this.photoUrl,
  });
  
  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      brand: json['brand'] as String? ?? '',
      model: json['model'] as String? ?? '',
      year: (json['year'] as num?)?.toInt() ?? 0,
      plate: json['plate'] as String? ?? '',
      color: json['color'] as String? ?? '',
      type: json['type'] ?? 'standard',
      capacity: json['capacity'] ?? 4,
      photoUrl: json['photoUrl'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'brand': brand,
      'model': model,
      'year': year,
      'plate': plate,
      'color': color,
      'type': type,
      'capacity': capacity,
      'photoUrl': photoUrl,
    };
  }
}

class LocationData {
  final double latitude;
  final double longitude;
  final double? heading;
  final double? speed;
  final DateTime? lastUpdate;

  LocationData({
    required this.latitude,
    required this.longitude,
    this.heading,
    this.speed,
    this.lastUpdate,
  });
  
  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      heading: (json['heading'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      lastUpdate: json['lastUpdate'] != null
          ? DateTime.parse(json['lastUpdate'])
          : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading,
      'speed': speed,
      'lastUpdate': lastUpdate?.toIso8601String(),
    };
  }
}