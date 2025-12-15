import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for tracking read receipts on messages
class ReadReceipt {
  final String userId;
  final DateTime readAt;
  final String userType; // 'user' or 'collector'

  ReadReceipt({
    required this.userId,
    required this.readAt,
    required this.userType,
  });

  factory ReadReceipt.fromMap(Map<String, dynamic> map) {
    return ReadReceipt(
      userId: map['userId'] ?? '',
      readAt: (map['readAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userType: map['userType'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'readAt': Timestamp.fromDate(readAt),
      'userType': userType,
    };
  }
}

/// Enhanced chat message model with read receipts and timestamps
class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String senderType; // 'user' or 'collector'
  final String senderName;
  final String? senderAvatarUrl;
  final String text;
  final DateTime sentAt;
  final DateTime? editedAt;
  final bool isEdited;
  final List<String>? imageUrls;
  final List<String>? attachmentUrls;
  final List<ReadReceipt> readBy; // Who has read this message
  final bool isDeleted;
  final String? deletedReason;
  final String? replyToMessageId; // For threaded conversations
  final Map<String, dynamic>? metadata;

  ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderType,
    required this.senderName,
    this.senderAvatarUrl,
    required this.text,
    required this.sentAt,
    this.editedAt,
    this.isEdited = false,
    this.imageUrls,
    this.attachmentUrls,
    this.readBy = const [],
    this.isDeleted = false,
    this.deletedReason,
    this.replyToMessageId,
    this.metadata,
  });

  /// Create from Firestore document
  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final readByList =
        (data['readBy'] as List<dynamic>?)
            ?.map((item) => ReadReceipt.fromMap(item as Map<String, dynamic>))
            .toList() ??
        [];

    return ChatMessage(
      id: doc.id,
      chatId: data['chatId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderType: data['senderType'] ?? 'user',
      senderName: data['senderName'] ?? 'Unknown',
      senderAvatarUrl: data['senderAvatarUrl'],
      text: data['text'] ?? '',
      sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      editedAt: (data['editedAt'] as Timestamp?)?.toDate(),
      isEdited: data['isEdited'] ?? false,
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      attachmentUrls: List<String>.from(data['attachmentUrls'] ?? []),
      readBy: readByList,
      isDeleted: data['isDeleted'] ?? false,
      deletedReason: data['deletedReason'],
      replyToMessageId: data['replyToMessageId'],
      metadata: data['metadata'],
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'senderType': senderType,
      'senderName': senderName,
      'senderAvatarUrl': senderAvatarUrl,
      'text': text,
      'sentAt': Timestamp.fromDate(sentAt),
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'isEdited': isEdited,
      'imageUrls': imageUrls,
      'attachmentUrls': attachmentUrls,
      'readBy': readBy.map((r) => r.toMap()).toList(),
      'isDeleted': isDeleted,
      'deletedReason': deletedReason,
      'replyToMessageId': replyToMessageId,
      'metadata': metadata,
    };
  }

  /// Check if message is read by specific user
  bool isReadByUser(String userId) {
    return readBy.any((receipt) => receipt.userId == userId);
  }

  /// Get time message was read by user (null if not read)
  DateTime? getReadTimeByUser(String userId) {
    final receipt = readBy.firstWhere(
      (r) => r.userId == userId,
      orElse: () =>
          ReadReceipt(userId: '', readAt: DateTime.now(), userType: ''),
    );
    return receipt.userId.isEmpty ? null : receipt.readAt;
  }

  /// Get message age in seconds
  int getAgeInSeconds() {
    return DateTime.now().difference(sentAt).inSeconds;
  }

  /// Check if message is recent (within last minute)
  bool isRecent() {
    return getAgeInSeconds() < 60;
  }

  /// Format sent time
  String getFormattedTime() {
    final now = DateTime.now();
    final diff = now.difference(sentAt);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';

    return '${diff.inDays}d ago';
  }

  /// Check if can be edited (only within 5 minutes)
  bool canBeEdited() {
    return getAgeInSeconds() < 300 && !isDeleted;
  }

  /// Check if can be deleted
  bool canBeDeleted() {
    return !isDeleted; // Always allow deletion
  }

  /// Get read receipt count
  int getReadCount() {
    return readBy.length;
  }

  /// Has attachments
  bool hasAttachments() {
    return (imageUrls?.isNotEmpty ?? false) ||
        (attachmentUrls?.isNotEmpty ?? false);
  }

  /// Copy with modifications
  ChatMessage copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? senderType,
    String? senderName,
    String? senderAvatarUrl,
    String? text,
    DateTime? sentAt,
    DateTime? editedAt,
    bool? isEdited,
    List<String>? imageUrls,
    List<String>? attachmentUrls,
    List<ReadReceipt>? readBy,
    bool? isDeleted,
    String? deletedReason,
    String? replyToMessageId,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderType: senderType ?? this.senderType,
      senderName: senderName ?? this.senderName,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
      text: text ?? this.text,
      sentAt: sentAt ?? this.sentAt,
      editedAt: editedAt ?? this.editedAt,
      isEdited: isEdited ?? this.isEdited,
      imageUrls: imageUrls ?? this.imageUrls,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      readBy: readBy ?? this.readBy,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedReason: deletedReason ?? this.deletedReason,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'ChatMessage(id: $id, sender: $senderName, text: ${text.length} chars)';
  }
}
