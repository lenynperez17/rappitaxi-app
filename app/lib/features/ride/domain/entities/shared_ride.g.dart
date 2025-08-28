// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shared_ride.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SharedRideImpl _$$SharedRideImplFromJson(Map<String, dynamic> json) =>
    _$SharedRideImpl(
      id: json['id'] as String,
      driverId: json['driverId'] as String,
      passengers: (json['passengers'] as List<dynamic>)
          .map((e) => SharedRidePassenger.fromJson(e as Map<String, dynamic>))
          .toList(),
      status: $enumDecode(_$SharedRideStatusEnumMap, json['status']),
      vehicleType: json['vehicleType'] as String,
      maxPassengers: (json['maxPassengers'] as num).toInt(),
      totalDistance: (json['totalDistance'] as num).toDouble(),
      currentDistance: (json['currentDistance'] as num).toDouble(),
      routeSegments: (json['routeSegments'] as List<dynamic>)
          .map((e) => RouteSegment.fromJson(e as Map<String, dynamic>))
          .toList(),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] == null
          ? null
          : DateTime.parse(json['endTime'] as String),
      baseFare: (json['baseFare'] as num).toDouble(),
      passengerFares: (json['passengerFares'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ),
      sharedRideDiscount:
          (json['sharedRideDiscount'] as num?)?.toDouble() ?? 0.7,
      allowNewPassengers: json['allowNewPassengers'] as bool? ?? true,
      maxDetourMinutes: (json['maxDetourMinutes'] as num?)?.toInt() ?? 15,
      currentSegmentId: json['currentSegmentId'] as String?,
      currentLocation: json['currentLocation'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$SharedRideImplToJson(_$SharedRideImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'driverId': instance.driverId,
      'passengers': instance.passengers,
      'status': _$SharedRideStatusEnumMap[instance.status]!,
      'vehicleType': instance.vehicleType,
      'maxPassengers': instance.maxPassengers,
      'totalDistance': instance.totalDistance,
      'currentDistance': instance.currentDistance,
      'routeSegments': instance.routeSegments,
      'startTime': instance.startTime.toIso8601String(),
      'endTime': instance.endTime?.toIso8601String(),
      'baseFare': instance.baseFare,
      'passengerFares': instance.passengerFares,
      'sharedRideDiscount': instance.sharedRideDiscount,
      'allowNewPassengers': instance.allowNewPassengers,
      'maxDetourMinutes': instance.maxDetourMinutes,
      'currentSegmentId': instance.currentSegmentId,
      'currentLocation': instance.currentLocation,
    };

const _$SharedRideStatusEnumMap = {
  SharedRideStatus.waitingPassengers: 'waitingPassengers',
  SharedRideStatus.inProgress: 'inProgress',
  SharedRideStatus.completed: 'completed',
  SharedRideStatus.cancelled: 'cancelled',
};

_$SharedRidePassengerImpl _$$SharedRidePassengerImplFromJson(
        Map<String, dynamic> json) =>
    _$SharedRidePassengerImpl(
      passengerId: json['passengerId'] as String,
      name: json['name'] as String,
      photoUrl: json['photoUrl'] as String,
      rating: (json['rating'] as num).toDouble(),
      pickupLocation: json['pickupLocation'] as Map<String, dynamic>,
      dropoffLocation: json['dropoffLocation'] as Map<String, dynamic>,
      requestTime: DateTime.parse(json['requestTime'] as String),
      pickupTime: json['pickupTime'] == null
          ? null
          : DateTime.parse(json['pickupTime'] as String),
      dropoffTime: json['dropoffTime'] == null
          ? null
          : DateTime.parse(json['dropoffTime'] as String),
      status: $enumDecode(_$PassengerStatusEnumMap, json['status']),
      fare: (json['fare'] as num).toDouble(),
      distance: (json['distance'] as num).toDouble(),
      seatCount: (json['seatCount'] as num).toInt(),
      phoneNumber: json['phoneNumber'] as String?,
      notes: json['notes'] as String?,
      isPriority: json['isPriority'] as bool? ?? false,
    );

Map<String, dynamic> _$$SharedRidePassengerImplToJson(
        _$SharedRidePassengerImpl instance) =>
    <String, dynamic>{
      'passengerId': instance.passengerId,
      'name': instance.name,
      'photoUrl': instance.photoUrl,
      'rating': instance.rating,
      'pickupLocation': instance.pickupLocation,
      'dropoffLocation': instance.dropoffLocation,
      'requestTime': instance.requestTime.toIso8601String(),
      'pickupTime': instance.pickupTime?.toIso8601String(),
      'dropoffTime': instance.dropoffTime?.toIso8601String(),
      'status': _$PassengerStatusEnumMap[instance.status]!,
      'fare': instance.fare,
      'distance': instance.distance,
      'seatCount': instance.seatCount,
      'phoneNumber': instance.phoneNumber,
      'notes': instance.notes,
      'isPriority': instance.isPriority,
    };

const _$PassengerStatusEnumMap = {
  PassengerStatus.pending: 'pending',
  PassengerStatus.confirmed: 'confirmed',
  PassengerStatus.pickedUp: 'pickedUp',
  PassengerStatus.droppedOff: 'droppedOff',
  PassengerStatus.cancelled: 'cancelled',
  PassengerStatus.noShow: 'noShow',
};

_$RouteSegmentImpl _$$RouteSegmentImplFromJson(Map<String, dynamic> json) =>
    _$RouteSegmentImpl(
      id: json['id'] as String,
      passengerId: json['passengerId'] as String,
      type: $enumDecode(_$SegmentTypeEnumMap, json['type']),
      location: json['location'] as Map<String, dynamic>,
      order: (json['order'] as num).toInt(),
      distanceFromPrevious: (json['distanceFromPrevious'] as num).toDouble(),
      estimatedMinutesFromPrevious:
          (json['estimatedMinutesFromPrevious'] as num).toInt(),
      actualArrivalTime: json['actualArrivalTime'] == null
          ? null
          : DateTime.parse(json['actualArrivalTime'] as String),
      isCompleted: json['isCompleted'] as bool? ?? false,
    );

Map<String, dynamic> _$$RouteSegmentImplToJson(_$RouteSegmentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'passengerId': instance.passengerId,
      'type': _$SegmentTypeEnumMap[instance.type]!,
      'location': instance.location,
      'order': instance.order,
      'distanceFromPrevious': instance.distanceFromPrevious,
      'estimatedMinutesFromPrevious': instance.estimatedMinutesFromPrevious,
      'actualArrivalTime': instance.actualArrivalTime?.toIso8601String(),
      'isCompleted': instance.isCompleted,
    };

const _$SegmentTypeEnumMap = {
  SegmentType.pickup: 'pickup',
  SegmentType.dropoff: 'dropoff',
};

_$SharedRideRequestImpl _$$SharedRideRequestImplFromJson(
        Map<String, dynamic> json) =>
    _$SharedRideRequestImpl(
      id: json['id'] as String,
      passengerId: json['passengerId'] as String,
      pickupLocation: json['pickupLocation'] as Map<String, dynamic>,
      dropoffLocation: json['dropoffLocation'] as Map<String, dynamic>,
      requestTime: DateTime.parse(json['requestTime'] as String),
      passengerCount: (json['passengerCount'] as num).toInt(),
      status: $enumDecodeNullable(
              _$SharedRideRequestStatusEnumMap, json['status']) ??
          SharedRideRequestStatus.pending,
      matchedRideId: json['matchedRideId'] as String?,
      estimatedFare: (json['estimatedFare'] as num?)?.toDouble(),
      estimatedWaitTime: (json['estimatedWaitTime'] as num?)?.toDouble(),
      estimatedTravelTime: (json['estimatedTravelTime'] as num?)?.toDouble(),
      maxWaitTimeSeconds: (json['maxWaitTimeSeconds'] as num?)?.toInt() ?? 300,
      maxDetourKm: (json['maxDetourKm'] as num?)?.toDouble() ?? 0.5,
    );

Map<String, dynamic> _$$SharedRideRequestImplToJson(
        _$SharedRideRequestImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'passengerId': instance.passengerId,
      'pickupLocation': instance.pickupLocation,
      'dropoffLocation': instance.dropoffLocation,
      'requestTime': instance.requestTime.toIso8601String(),
      'passengerCount': instance.passengerCount,
      'status': _$SharedRideRequestStatusEnumMap[instance.status]!,
      'matchedRideId': instance.matchedRideId,
      'estimatedFare': instance.estimatedFare,
      'estimatedWaitTime': instance.estimatedWaitTime,
      'estimatedTravelTime': instance.estimatedTravelTime,
      'maxWaitTimeSeconds': instance.maxWaitTimeSeconds,
      'maxDetourKm': instance.maxDetourKm,
    };

const _$SharedRideRequestStatusEnumMap = {
  SharedRideRequestStatus.pending: 'pending',
  SharedRideRequestStatus.matched: 'matched',
  SharedRideRequestStatus.confirmed: 'confirmed',
  SharedRideRequestStatus.rejected: 'rejected',
  SharedRideRequestStatus.expired: 'expired',
  SharedRideRequestStatus.cancelled: 'cancelled',
};

_$SharedRideConfigImpl _$$SharedRideConfigImplFromJson(
        Map<String, dynamic> json) =>
    _$SharedRideConfigImpl(
      enableSharedRides: json['enableSharedRides'] as bool? ?? true,
      maxPassengersPerRide:
          (json['maxPassengersPerRide'] as num?)?.toInt() ?? 4,
      discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0.3,
      driverBonusPercent:
          (json['driverBonusPercent'] as num?)?.toDouble() ?? 0.8,
      maxDetourMinutes: (json['maxDetourMinutes'] as num?)?.toInt() ?? 15,
      maxDetourKm: (json['maxDetourKm'] as num?)?.toDouble() ?? 2.0,
      matchingWindowSeconds:
          (json['matchingWindowSeconds'] as num?)?.toInt() ?? 300,
      allowDynamicRouting: json['allowDynamicRouting'] as bool? ?? true,
      showOtherPassengers: json['showOtherPassengers'] as bool? ?? true,
      allowPassengerChat: json['allowPassengerChat'] as bool? ?? false,
      requireRatingAbove: json['requireRatingAbove'] as bool? ?? true,
      minimumRating: (json['minimumRating'] as num?)?.toDouble() ?? 4.0,
      maxMatchingAttempts: (json['maxMatchingAttempts'] as num?)?.toInt() ?? 10,
    );

Map<String, dynamic> _$$SharedRideConfigImplToJson(
        _$SharedRideConfigImpl instance) =>
    <String, dynamic>{
      'enableSharedRides': instance.enableSharedRides,
      'maxPassengersPerRide': instance.maxPassengersPerRide,
      'discountPercent': instance.discountPercent,
      'driverBonusPercent': instance.driverBonusPercent,
      'maxDetourMinutes': instance.maxDetourMinutes,
      'maxDetourKm': instance.maxDetourKm,
      'matchingWindowSeconds': instance.matchingWindowSeconds,
      'allowDynamicRouting': instance.allowDynamicRouting,
      'showOtherPassengers': instance.showOtherPassengers,
      'allowPassengerChat': instance.allowPassengerChat,
      'requireRatingAbove': instance.requireRatingAbove,
      'minimumRating': instance.minimumRating,
      'maxMatchingAttempts': instance.maxMatchingAttempts,
    };

_$RideMatchingCriteriaImpl _$$RideMatchingCriteriaImplFromJson(
        Map<String, dynamic> json) =>
    _$RideMatchingCriteriaImpl(
      maxDetourPercent: (json['maxDetourPercent'] as num).toDouble(),
      maxWaitTime: (json['maxWaitTime'] as num).toDouble(),
      compatibilityScore: (json['compatibilityScore'] as num).toDouble(),
      sameDirection: json['sameDirection'] as bool,
      overlapPercent: (json['overlapPercent'] as num).toDouble(),
    );

Map<String, dynamic> _$$RideMatchingCriteriaImplToJson(
        _$RideMatchingCriteriaImpl instance) =>
    <String, dynamic>{
      'maxDetourPercent': instance.maxDetourPercent,
      'maxWaitTime': instance.maxWaitTime,
      'compatibilityScore': instance.compatibilityScore,
      'sameDirection': instance.sameDirection,
      'overlapPercent': instance.overlapPercent,
    };
