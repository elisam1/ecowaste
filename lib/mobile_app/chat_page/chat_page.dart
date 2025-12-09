import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ChatPage extends StatefulWidget {
  final String collectorName;
  final String collectorId;
  final String requestId;
  final String? userName;

  const ChatPage({
    Key? key,
    required this.collectorName,
    required this.collectorId,
    required this.requestId,
    this.userName,
  }) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

String _getFirstChar(String? text) {
  if (text == null || text.isEmpty) return '?';
  return text.trim()[0].toUpperCase();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final user = FirebaseAuth.instance.currentUser;
  bool isTyping = false;
  String? currentUserType;
  File? _previewImage;
  bool _showQuickActions = false;
  bool _isUploading = false;
  late AnimationController _typingAnimationController;
  late AnimationController _quickActionsController;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _markMessagesAsRead();
    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _quickActionsController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingAnimationController.dispose();
    _quickActionsController.dispose();
    _setTypingStatus(false);
    super.dispose();
  }

  void _initializeChat() async {
    setState(() {
      currentUserType = user?.uid == widget.collectorId ? 'collector' : 'user';
    });

    final chatDoc = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.requestId);
    final docSnapshot = await chatDoc.get();
    if (!docSnapshot.exists) {
      await chatDoc.set({
        'requestId': widget.requestId,
        'userId': currentUserType == 'user' ? user?.uid : null,
        'userName': currentUserType == 'user'
            ? (widget.userName ?? 'User')
            : null,
        'collectorId': widget.collectorId,
        'collectorName': widget.collectorName,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': {'user': 0, 'collector': 0},
        'userTyping': false,
        'collectorTyping': false,
        'lastSeen': {
          'user': FieldValue.serverTimestamp(),
          'collector': FieldValue.serverTimestamp(),
        },
      });
    } else {
      final data = docSnapshot.data()!;
      if (data['userId'] == null && currentUserType == 'user') {
        await chatDoc.update({
          'userId': user?.uid,
          'userName': widget.userName ?? 'User',
        });
      }
    }

    // Update last seen
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.requestId)
        .update({'lastSeen.$currentUserType': FieldValue.serverTimestamp()});
  }

  void _sendMessage(
    String text, {
    MessageType type = MessageType.text,
    String? imageUrl,
  }) async {
    if (text.trim().isEmpty && type == MessageType.text && imageUrl == null)
      return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Add haptic feedback
    HapticFeedback.lightImpact();

    final messageData = {
      'senderId': currentUser.uid,
      'senderName':
          currentUser.displayName ??
          (currentUserType == 'collector'
              ? widget.collectorName
              : (widget.userName ?? 'User')),
      'message': text,
      'imageUrl': imageUrl,
      'timestamp': FieldValue.serverTimestamp(),
      'type': type.name,
      'isFromCollector': currentUserType == 'collector',
      'isRead': false,
      'reactions': {},
    };

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.requestId)
        .collection('messages')
        .add(messageData);

    final otherUserType = currentUserType == 'collector' ? 'user' : 'collector';
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.requestId)
        .update({
          'lastMessage': imageUrl != null ? '📷 Photo' : text,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'unreadCount.$otherUserType': FieldValue.increment(1),
          '${currentUserType}Typing': false,
          'lastSeen.$currentUserType': FieldValue.serverTimestamp(),
        });

    // Create notification for the recipient
    try {
      final recipientId = currentUserType == 'collector' ? user?.uid : widget.collectorId;
      if (recipientId != null) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': recipientId,
          'type': 'new_message',
          'title': '💬 New Message',
          'message': '${currentUserType == 'collector' ? widget.collectorName : (widget.userName ?? 'User')}: ${imageUrl != null ? '📷 Photo' : text}',
          'data': {
            'chatId': widget.requestId,
            'senderId': currentUser.uid,
            'senderName': currentUserType == 'collector' ? widget.collectorName : (widget.userName ?? 'User'),
            'message': text,
            'imageUrl': imageUrl,
            'messageType': type.name,
          },
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error creating chat notification: $e');
    }

    setState(() {
      isTyping = false;
      _previewImage = null;
      _showQuickActions = false;
    });
    _messageController.clear();
    _quickActionsController.reverse();
    _scrollToBottom();
  }

  void _markMessagesAsRead() async {
    final messagesQuery = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.requestId)
        .collection('messages')
        .where('isFromCollector', isEqualTo: currentUserType != 'collector')
        .where('isRead', isEqualTo: false)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in messagesQuery.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.requestId)
        .update({
          'unreadCount.$currentUserType': 0,
          'lastSeen.$currentUserType': FieldValue.serverTimestamp(),
        });

    // Mark corresponding notifications as read
    try {
      final currentUserId = user?.uid;
      if (currentUserId != null) {
        final notificationsQuery = await FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: currentUserId)
            .where('type', isEqualTo: 'new_message')
            .where('data.chatId', isEqualTo: widget.requestId)
            .where('isRead', isEqualTo: false)
            .get();

        final notificationBatch = FirebaseFirestore.instance.batch();
        for (var doc in notificationsQuery.docs) {
          notificationBatch.update(doc.reference, {'isRead': true});
        }
        await notificationBatch.commit();
      }
    } catch (e) {
      print('Error marking notifications as read: $e');
    }
  }

  void _setTypingStatus(bool typing) async {
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.requestId)
        .update({'${currentUserType}Typing': typing});
  }

  Future<void> _pickImage({bool fromCamera = false}) async {
    final pickedFile = await ImagePicker().pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      setState(() => _previewImage = File(pickedFile.path));
    }
  }

  Future<void> _uploadImageAndSend() async {
    if (_previewImage == null) return;

    setState(() => _isUploading = true);

    try {
      final ref = FirebaseStorage.instance.ref().child(
        'chat_images/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await ref.putFile(_previewImage!);
      final imageUrl = await ref.getDownloadURL();
      _sendMessage('', type: MessageType.text, imageUrl: imageUrl);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _deleteMessage(String docId) async {
    HapticFeedback.mediumImpact();
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.requestId)
        .collection('messages')
        .doc(docId)
        .delete();
  }

  void _addReaction(String messageId, String emoji) async {
    final userId = user?.uid;
    if (userId == null) return;

    HapticFeedback.lightImpact();

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.requestId)
        .collection('messages')
        .doc(messageId)
        .update({'reactions.$userId': emoji});
  }

  void _shareLocation() {
    _sendMessage(
      '📍 Location shared\nKumasi, Ashanti Region\nTap to open in maps',
      type: MessageType.location,
    );
  }

  void _schedulePickup() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      final date = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 7)),
      );

      if (date != null) {
        final formattedDate = '${date.day}/${date.month}/${date.year}';
        _sendMessage(
          '⏰ Pickup scheduled for ${time.format(context)} on $formattedDate',
          type: MessageType.schedule,
        );
      }
    }
  }

  void _sendQuickReply(String message) {
    _sendMessage(message);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final otherPersonName = currentUserType == 'collector'
        ? (widget.userName ?? 'User')
        : widget.collectorName;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(otherPersonName),
      body: Column(
        children: [
          if (currentUserType == 'user') _buildQuickReplies(),
          Expanded(child: _buildMessages()),
          _buildTypingIndicator(),
          if (_previewImage != null) _buildImagePreview(),
          if (_showQuickActions) _buildQuickActions(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(String otherPersonName) {
    return AppBar(
      backgroundColor: Colors.green[600],
      foregroundColor: Colors.white,
      elevation: 3,
      shadowColor: Colors.green.withOpacity(0.5),
      title: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white,
                child: Text(
                  _getFirstChar(otherPersonName),
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green[400],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  otherPersonName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                _buildOnlineStatus(),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.call),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('calling feature coming soon!')),
            );
          },
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'location':
                _shareLocation();
                break;
              case 'schedule':
                _schedulePickup();
                break;
              case 'clear':
                _showClearChatDialog();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'location',
              child: Row(
                children: [
                  Icon(Icons.location_on, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Share Location'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'schedule',
              child: Row(
                children: [
                  Icon(Icons.schedule, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Schedule Pickup'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Clear Chat'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOnlineStatus() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.requestId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Text(
            currentUserType == 'collector' ? 'User' : 'Waste Collector',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final otherUserType = currentUserType == 'collector'
            ? 'user'
            : 'collector';
        final isOtherUserTyping = data?['${otherUserType}Typing'] ?? false;

        if (isOtherUserTyping) {
          return const Row(
            children: [
              Text(
                'typing...',
                style: TextStyle(fontSize: 12, color: Colors.lightGreenAccent),
              ),
              SizedBox(width: 4),
              SizedBox(
                width: 8,
                height: 8,
                child: CircularProgressIndicator(
                  strokeWidth: 1,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.lightGreenAccent,
                  ),
                ),
              ),
            ],
          );
        }

        // Show last seen
        final lastSeen = data?['lastSeen']?[otherUserType];
        if (lastSeen != null) {
          final lastSeenTime = (lastSeen as Timestamp).toDate();
          final now = DateTime.now();
          final difference = now.difference(lastSeenTime);

          String status;
          if (difference.inMinutes < 5) {
            status = 'online';
          } else if (difference.inHours < 1) {
            status = 'last seen ${difference.inMinutes}m ago';
          } else if (difference.inDays < 1) {
            status = 'last seen ${difference.inHours}h ago';
          } else {
            status = 'last seen ${difference.inDays}d ago';
          }

          return Text(
            status,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          );
        }

        return Text(
          currentUserType == 'collector' ? 'User' : 'Waste Collector',
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        );
      },
    );
  }

  Widget _buildQuickReplies() {
    final quickReplies = [
      '👋 Hello!',
      '📍 I\'m here',
      '✅ Ready for pickup',
      '⏰ What time?',
      '👍 Thank you!',
    ];

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: quickReplies.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(
                quickReplies[index],
                style: const TextStyle(fontSize: 12),
              ),
              onPressed: () => _sendQuickReply(quickReplies[index]),
              backgroundColor: Colors.white,
              side: BorderSide(color: Colors.green.withOpacity(0.3)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessages() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.requestId)
          .collection('messages')
          .orderBy('timestamp')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.green),
          );
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.green[400],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Start the conversation!',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Send a message to coordinate the pickup',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildMessageBubble(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(String messageId, Map<String, dynamic> data) {
    final isMe = data['senderId'] == user?.uid;
    final isRead = data['isRead'] ?? false;
    final reactions = data['reactions'] as Map<String, dynamic>? ?? {};

    return GestureDetector(
      onLongPress: () => _showMessageOptions(messageId, data, isMe),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.green[100],
                child: Text(
                  _getFirstChar(data['senderName']?.toString()),
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: isMe
                          ? LinearGradient(
                              colors: [Colors.green[400]!, Colors.green[600]!],
                            )
                          : null,
                      color: isMe ? null : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isMe ? 20 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (data['imageUrl'] != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              data['imageUrl'],
                              width: 200,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      width: 200,
                                      height: 150,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  },
                            ),
                          )
                        else
                          Text(
                            data['message']?.toString() ?? '',
                            style: TextStyle(
                              color: isMe ? Colors.white : Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                        if (_getMessageTypeIcon(data['type']) != null) ...[
                          const SizedBox(height: 4),
                          _getMessageTypeIcon(data['type'])!,
                        ],
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTime(data['timestamp']),
                              style: TextStyle(
                                fontSize: 12,
                                color: isMe ? Colors.white70 : Colors.grey[600],
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              Icon(
                                isRead ? Icons.done_all : Icons.done,
                                size: 16,
                                color: isRead
                                    ? Colors.blue[200]
                                    : Colors.white70,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (reactions.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: reactions.entries.map((entry) {
                          return Text(
                            entry.value,
                            style: const TextStyle(fontSize: 16),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.blue[100],
                child: Text(
                  _getFirstChar(data['senderName']?.toString()),
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget? _getMessageTypeIcon(String? type) {
    switch (type) {
      case 'location':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, size: 14, color: Colors.red[300]),
            const SizedBox(width: 4),
            const Text(
              'Location',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        );
      case 'schedule':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, size: 14, color: Colors.orange[300]),
            const SizedBox(width: 4),
            const Text(
              'Scheduled',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        );
      default:
        return null;
    }
  }

  void _showMessageOptions(
    String messageId,
    Map<String, dynamic> data,
    bool isMe,
  ) {
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Message Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['❤️', '👍', '😊', '😢', '😮', '😡']
                  .map(
                    (emoji) => GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _addReaction(messageId, emoji);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Message'),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(messageId);
                },
              ),
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('Copy Text'),
              onTap: () {
                Navigator.pop(context);
                final messageText = data['message']?.toString() ?? '';
                if (messageText.isNotEmpty) {
                  Clipboard.setData(ClipboardData(text: messageText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Text copied to clipboard')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No text to copy')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(String messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Message?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMessage(messageId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showClearChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Chat?'),
        content: const Text(
          'This will delete all messages in this chat. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Clear all messages
              final messages = await FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.requestId)
                  .collection('messages')
                  .get();

              final batch = FirebaseFirestore.instance.batch();
              for (var doc in messages.docs) {
                batch.delete(doc.reference);
              }
              await batch.commit();

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Chat cleared')));
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.requestId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) return const SizedBox.shrink();

        final otherUserType = currentUserType == 'collector'
            ? 'user'
            : 'collector';
        final isTyping = data['${otherUserType}Typing'] ?? false;

        if (!isTyping) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: Colors.green[100],
                child: Text(
                  currentUserType == 'collector'
                      ? _getFirstChar('User')
                      : _getFirstChar(widget.collectorName),
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'typing',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    AnimatedBuilder(
                      animation: _typingAnimationController,
                      builder: (context, child) {
                        return Row(
                          children: List.generate(3, (index) {
                            final animationValue =
                                (_typingAnimationController.value * 3 - index)
                                    .clamp(0.0, 1.0);
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              width: 4,
                              height: 4 + (animationValue * 4),
                              decoration: BoxDecoration(
                                color: Colors.green[400],
                                shape: BoxShape.circle,
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImagePreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _previewImage!,
                  height: 80,
                  width: 80,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => setState(() => _previewImage = null),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Image ready to send',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  'Tap send to share',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          if (_isUploading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(
            CurvedAnimation(
              parent: _quickActionsController,
              curve: Curves.easeOut,
            ),
          ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey[300]!)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _QuickActionButton(
              icon: Icons.location_on,
              label: 'Location',
              color: Colors.red[400]!,
              onTap: () {
                _shareLocation();
                setState(() => _showQuickActions = false);
                _quickActionsController.reverse();
              },
            ),
            _QuickActionButton(
              icon: Icons.schedule,
              label: 'Schedule',
              color: Colors.orange[400]!,
              onTap: () {
                _schedulePickup();
                setState(() => _showQuickActions = false);
                _quickActionsController.reverse();
              },
            ),
            _QuickActionButton(
              icon: Icons.photo_camera,
              label: 'Camera',
              color: Colors.blue[400]!,
              onTap: () {
                _pickImage(fromCamera: true);
                setState(() => _showQuickActions = false);
                _quickActionsController.reverse();
              },
            ),
            _QuickActionButton(
              icon: Icons.photo,
              label: 'Gallery',
              color: Colors.purple[400]!,
              onTap: () {
                _pickImage(fromCamera: false);
                setState(() => _showQuickActions = false);
                _quickActionsController.reverse();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _showQuickActions ? Icons.keyboard_arrow_down : Icons.add,
              color: Colors.green[600],
            ),
            onPressed: () {
              setState(() => _showQuickActions = !_showQuickActions);
              if (_showQuickActions) {
                _quickActionsController.forward();
              } else {
                _quickActionsController.reverse();
              }
            },
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _messageController,
                textInputAction: TextInputAction.send,
                onSubmitted: (val) => _sendMessage(val),
                onChanged: (text) {
                  if (text.isNotEmpty && !isTyping) {
                    setState(() => isTyping = true);
                    _setTypingStatus(true);
                  } else if (text.isEmpty && isTyping) {
                    setState(() => isTyping = false);
                    _setTypingStatus(false);
                  }
                },
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  border: InputBorder.none,
                ),
                maxLines: null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[400]!, Colors.green[600]!],
              ),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _isUploading
                  ? null
                  : () {
                      if (_previewImage != null) {
                        _uploadImageAndSend();
                      } else {
                        _sendMessage(_messageController.text);
                      }
                    },
              icon: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    final date = (timestamp as Timestamp).toDate();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}

enum MessageType { text, location, schedule, confirmation }
