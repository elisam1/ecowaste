import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/mobile_app/constants/app_constants.dart';
import 'package:flutter_application_1/mobile_app/model/chat_message.dart';
import 'package:flutter_application_1/mobile_app/service/logging_service.dart';

/// Service for managing chat message read receipts
class ReadReceiptService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Mark message as read
  static Future<bool> markMessageAsRead(
    String chatId,
    String messageId, {
    required String userType, // 'user' or 'collector'
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        LoggingService.error('Cannot mark as read: User not authenticated');
        return false;
      }

      final messageRef = _firestore
          .collection(AppConstants.collectionChats)
          .doc(chatId)
          .collection(AppConstants.collectionMessages)
          .doc(messageId);

      final messageDoc = await messageRef.get();
      if (!messageDoc.exists) {
        LoggingService.warning('Message not found: $messageId');
        return false;
      }

      final message = ChatMessage.fromFirestore(messageDoc);

      // Check if already read by this user
      if (message.isReadByUser(userId)) {
        LoggingService.info('Message already read by user: $userId');
        return true;
      }

      // Add read receipt
      final updatedReadBy = [...message.readBy];
      updatedReadBy.add(
        ReadReceipt(userId: userId, readAt: DateTime.now(), userType: userType),
      );

      await messageRef.update({
        'readBy': updatedReadBy.map((r) => r.toMap()).toList(),
      });

      LoggingService.logCacheOperation('READ_RECEIPT', messageId);
      return true;
    } catch (e) {
      LoggingService.error('Error marking message as read: $e');
      return false;
    }
  }

  /// Mark all messages in chat as read
  static Future<bool> markChatAsRead(
    String chatId, {
    required String userType,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final messagesSnapshot = await _firestore
          .collection(AppConstants.collectionChats)
          .doc(chatId)
          .collection(AppConstants.collectionMessages)
          .where(
            'readBy',
            arrayContains: {'userId': userId},
            isNotEqualTo: null,
          )
          .get();

      int markedCount = 0;
      for (final doc in messagesSnapshot.docs) {
        final message = ChatMessage.fromFirestore(doc);

        if (!message.isReadByUser(userId)) {
          final updatedReadBy = [...message.readBy];
          updatedReadBy.add(
            ReadReceipt(
              userId: userId,
              readAt: DateTime.now(),
              userType: userType,
            ),
          );

          await doc.reference.update({
            'readBy': updatedReadBy.map((r) => r.toMap()).toList(),
          });

          markedCount++;
        }
      }

      LoggingService.success('Marked $markedCount messages as read in chat');
      return true;
    } catch (e) {
      LoggingService.error('Error marking chat as read: $e');
      return false;
    }
  }

  /// Get unread message count
  static Future<int> getUnreadMessageCount(String chatId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return 0;

      final snapshot = await _firestore
          .collection(AppConstants.collectionChats)
          .doc(chatId)
          .collection(AppConstants.collectionMessages)
          .get();

      int unreadCount = 0;
      for (final doc in snapshot.docs) {
        final message = ChatMessage.fromFirestore(doc);
        if (!message.isReadByUser(userId)) {
          unreadCount++;
        }
      }

      return unreadCount;
    } catch (e) {
      LoggingService.error('Error getting unread count: $e');
      return 0;
    }
  }

  /// Stream unread messages
  static Stream<List<ChatMessage>> streamUnreadMessages(String chatId) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection(AppConstants.collectionChats)
        .doc(chatId)
        .collection(AppConstants.collectionMessages)
        .orderBy('sentAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ChatMessage.fromFirestore(doc))
              .where((msg) => !msg.isReadByUser(userId))
              .toList();
        });
  }

  /// Get read receipt details for a message
  static Future<List<ReadReceipt>> getReadReceipts(
    String chatId,
    String messageId,
  ) async {
    try {
      final messageRef = _firestore
          .collection(AppConstants.collectionChats)
          .doc(chatId)
          .collection(AppConstants.collectionMessages)
          .doc(messageId);

      final messageDoc = await messageRef.get();
      if (!messageDoc.exists) return [];

      final message = ChatMessage.fromFirestore(messageDoc);
      return message.readBy;
    } catch (e) {
      LoggingService.error('Error getting read receipts: $e');
      return [];
    }
  }

  /// Get last read message timestamp for user
  static Future<DateTime?> getLastReadTime(String chatId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.collectionChats)
          .doc(chatId)
          .collection(AppConstants.collectionMessages)
          .orderBy('sentAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final message = ChatMessage.fromFirestore(snapshot.docs.first);
      return message.getReadTimeByUser(userId);
    } catch (e) {
      LoggingService.error('Error getting last read time: $e');
      return null;
    }
  }

  /// Delete message (soft delete)
  static Future<bool> deleteMessage(
    String chatId,
    String messageId,
    String reason,
  ) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      await _firestore
          .collection(AppConstants.collectionChats)
          .doc(chatId)
          .collection(AppConstants.collectionMessages)
          .doc(messageId)
          .update({
            'isDeleted': true,
            'deletedReason': reason,
            'text': '[Message deleted]',
          });

      LoggingService.success('Message deleted: $messageId');
      return true;
    } catch (e) {
      LoggingService.error('Error deleting message: $e');
      return false;
    }
  }

  /// Edit message
  static Future<bool> editMessage(
    String chatId,
    String messageId,
    String newText,
  ) async {
    try {
      final messageRef = _firestore
          .collection(AppConstants.collectionChats)
          .doc(chatId)
          .collection(AppConstants.collectionMessages)
          .doc(messageId);

      final messageDoc = await messageRef.get();
      if (!messageDoc.exists) return false;

      final message = ChatMessage.fromFirestore(messageDoc);

      // Check if can be edited
      if (!message.canBeEdited()) {
        LoggingService.warning('Message cannot be edited: too old');
        return false;
      }

      // Validate text length
      if (newText.length > AppConstants.maxMessageLength) {
        LoggingService.warning('Message text exceeds maximum length');
        return false;
      }

      await messageRef.update({
        'text': newText,
        'editedAt': Timestamp.now(),
        'isEdited': true,
      });

      LoggingService.success('Message edited: $messageId');
      return true;
    } catch (e) {
      LoggingService.error('Error editing message: $e');
      return false;
    }
  }

  /// Get message read percentage
  static Future<double> getMessageReadPercentage(
    String chatId,
    String messageId,
  ) async {
    try {
      final receipts = await getReadReceipts(chatId, messageId);
      if (receipts.isEmpty) return 0;

      // Assuming max 2 participants in chat (user and collector)
      return (receipts.length / 2) * 100;
    } catch (e) {
      LoggingService.error('Error getting read percentage: $e');
      return 0;
    }
  }

  /// Stream message read status
  static Stream<ChatMessage?> streamMessageReadStatus(
    String chatId,
    String messageId,
  ) {
    return _firestore
        .collection(AppConstants.collectionChats)
        .doc(chatId)
        .collection(AppConstants.collectionMessages)
        .doc(messageId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return ChatMessage.fromFirestore(doc);
        });
  }
}
