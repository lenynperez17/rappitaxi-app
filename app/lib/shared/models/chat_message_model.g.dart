// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChatMessageModelImpl _$$ChatMessageModelImplFromJson(
        Map<String, dynamic> json) =>
    _$ChatMessageModelImpl(
      id: json['id'] as String,
      rideId: json['rideId'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      senderRole: json['senderRole'] as String,
      message: json['message'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['isRead'] as bool? ?? false,
      imageUrl: json['imageUrl'] as String?,
      audioUrl: json['audioUrl'] as String?,
      messageType: json['messageType'] as String? ?? 'text',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$$ChatMessageModelImplToJson(
        _$ChatMessageModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'rideId': instance.rideId,
      'senderId': instance.senderId,
      'senderName': instance.senderName,
      'senderRole': instance.senderRole,
      'message': instance.message,
      'timestamp': instance.timestamp.toIso8601String(),
      'isRead': instance.isRead,
      'imageUrl': instance.imageUrl,
      'audioUrl': instance.audioUrl,
      'messageType': instance.messageType,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
    };
