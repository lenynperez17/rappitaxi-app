import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../shared/models/location_model.dart';

part 'ride_request.freezed.dart';
part 'ride_request.g.dart';

@freezed
class RideRequest with _$RideRequest {
  const factory RideRequest({
    required String id,
    required String passengerId,
    required String passengerName,
    required String passengerPhone,
    String? passengerPhoto,
    required double passengerRating,
    required LocationModel pickup,
    required LocationModel destination,
    required double estimatedFare,
    required double estimatedDistance, // en km
    required int estimatedDuration, // en minutos
    required String vehicleType,
    required String paymentMethod,
    required DateTime requestedAt,
    required int timeoutSeconds, // tiempo para responder
    Map<String, dynamic>? metadata,
  }) = _RideRequest;
  
  factory RideRequest.fromJson(Map<String, dynamic> json) =>
      _$RideRequestFromJson(json);
}