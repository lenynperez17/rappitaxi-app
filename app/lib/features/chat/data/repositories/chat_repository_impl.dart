import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/models/chat_message_model.dart';
import '../../domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  @override
  Stream<List<ChatMessageModel>> getMessagesForRide(String rideId) {
    return _firestore
        .collection('rides')
        .doc(rideId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return ChatMessageModel.fromJson({
          ...data,
          'id': doc.id,
          'timestamp': (data['timestamp'] as Timestamp).toDate().toIso8601String(),
        });
      }).toList();
    });
  }

  @override
  Future<void> sendMessage({
    required String rideId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String message,
  }) async {
    final messageId = _uuid.v4();
    
    await _firestore
        .collection('rides')
        .doc(rideId)
        .collection('messages')
        .doc(messageId)
        .set({
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'messageType': 'text',
    });

    // Actualizar último mensaje en el viaje
    await _firestore.collection('rides').doc(rideId).update({
      'lastMessage': message,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSender': senderRole,
    });
  }

  @override
  Future<void> sendImage({
    required String rideId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String imagePath,
  }) async {
    final messageId = _uuid.v4();
    final file = File(imagePath);
    
    // Subir imagen a Firebase Storage
    final ref = _storage
        .ref()
        .child('chat_images')
        .child(rideId)
        .child('$messageId.jpg');
    
    final uploadTask = await ref.putFile(file);
    final downloadUrl = await uploadTask.ref.getDownloadURL();

    // Guardar mensaje con URL de imagen
    await _firestore
        .collection('rides')
        .doc(rideId)
        .collection('messages')
        .doc(messageId)
        .set({
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'message': 'Imagen enviada',
      'imageUrl': downloadUrl,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'messageType': 'image',
    });

    // Actualizar último mensaje en el viaje
    await _firestore.collection('rides').doc(rideId).update({
      'lastMessage': 'Imagen',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSender': senderRole,
    });
  }

  @override
  Future<void> sendLocation({
    required String rideId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required double latitude,
    required double longitude,
  }) async {
    final messageId = _uuid.v4();
    
    await _firestore
        .collection('rides')
        .doc(rideId)
        .collection('messages')
        .doc(messageId)
        .set({
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'message': 'Ubicación enviada',
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'messageType': 'location',
    });

    // Actualizar último mensaje en el viaje
    await _firestore.collection('rides').doc(rideId).update({
      'lastMessage': 'Ubicación',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSender': senderRole,
    });
  }

  @override
  Future<void> markMessagesAsRead(String rideId, String userId) async {
    final batch = _firestore.batch();
    
    final messagesQuery = await _firestore
        .collection('rides')
        .doc(rideId)
        .collection('messages')
        .where('senderId', isNotEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    for (final doc in messagesQuery.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  @override
  Stream<int> getUnreadMessagesCount(String rideId, String userId) {
    return _firestore
        .collection('rides')
        .doc(rideId)
        .collection('messages')
        .where('senderId', isNotEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}