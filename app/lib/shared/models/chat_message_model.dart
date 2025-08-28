import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_message_model.freezed.dart';
part 'chat_message_model.g.dart';

@freezed
class ChatMessageModel with _$ChatMessageModel {
  const factory ChatMessageModel({
    required String id,
    required String rideId,
    required String senderId,
    required String senderName,
    required String senderRole, // 'driver' o 'passenger'
    required String message,
    required DateTime timestamp,
    @Default(false) bool isRead,
    String? imageUrl,
    String? audioUrl,
    @Default('text') String messageType, // 'text', 'image', 'audio', 'location'
    double? latitude,
    double? longitude,
  }) = _ChatMessageModel;

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageModelFromJson(json);
}