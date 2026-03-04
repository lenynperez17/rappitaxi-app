class ChatMessageModel {
  final String id;
  final String rideId;
  final String senderId;
  final String senderName;
  final String senderRole; // 'driver' o 'passenger'
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String? imageUrl;
  final String? audioUrl;
  final String messageType; // 'text', 'image', 'audio', 'location'
  final double? latitude;
  final double? longitude;

  ChatMessageModel({
    required this.id,
    required this.rideId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.imageUrl,
    this.audioUrl,
    this.messageType = 'text',
    this.latitude,
    this.longitude,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as String? ?? '',
      rideId: json['rideId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderName: json['senderName'] as String? ?? '',
      senderRole: json['senderRole'] as String? ?? '',
      message: json['message'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      isRead: json['isRead'] ?? false,
      imageUrl: json['imageUrl'],
      audioUrl: json['audioUrl'],
      messageType: json['messageType'] ?? 'text',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rideId': rideId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'messageType': messageType,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}