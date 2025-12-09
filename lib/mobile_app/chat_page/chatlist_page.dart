import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'chat_page.dart'; // make sure this import path is correct

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('userId', isEqualTo: user?.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          final userChats = userSnapshot.data?.docs ?? [];

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .where('collectorId', isEqualTo: user?.uid)
                .snapshots(),
            builder: (context, collectorSnapshot) {
              final collectorChats = collectorSnapshot.data?.docs ?? [];

              final allChats = [...userChats, ...collectorChats];

              if (allChats.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No chats yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start a conversation to see it here',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: allChats.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, indent: 70),
                itemBuilder: (context, index) {
                  final chatDoc = allChats[index];
                  final chat = chatDoc.data() as Map<String, dynamic>;
                  final isCollector = chat['collectorId'] == user?.uid;

                  final otherName = isCollector
                      ? chat['userName'] ?? 'User'
                      : chat['collectorName'] ?? 'Collector';
                  // ignore: unused_local_variable
                  final otherId = isCollector
                      ? chat['userId']
                      : chat['collectorId'];
                  final unreadCount =
                      chat['unreadCount']?[isCollector
                          ? 'collector'
                          : 'user'] ??
                      0;

                  return Container(
                    color: Colors.white,
                    child: GestureDetector(
                      onLongPress: () {
                        HapticFeedback.mediumImpact();
                        _showChatOptions(context, chatDoc.id, otherName, chat);
                      },
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.green[100],
                          child: Text(
                            _getFirstChar(otherName),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                        title: Text(
                          otherName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            chat['lastMessage'] ?? 'No messages yet',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (chat['lastMessageTime'] != null)
                              Text(
                                _formatTimestamp(chat['lastMessageTime']),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            if (unreadCount > 0)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 20,
                                  minHeight: 20,
                                ),
                                child: Text(
                                  unreadCount > 99
                                      ? '99+'
                                      : unreadCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/chat',
                            arguments: {
                              'collectorId': chat['collectorId'],
                              'collectorName': chat['collectorName'] ?? 'Collector',
                              'requestId': chat['requestId'],
                              'userName': chat['userName'] ?? 'User',
                            },
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // Helper method to safely get first character
  String _getFirstChar(String? text) {
    if (text == null || text.isEmpty) return '?';
    return text.trim()[0].toUpperCase();
  }

  // Show chat options bottom sheet
  void _showChatOptions(
    BuildContext context,
    String chatId,
    String otherName,
    Map<String, dynamic> chatData,
  ) {
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
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Chat with $otherName',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Mute/Unmute option
            ListTile(
              leading: Icon(
                Icons.notifications_off_outlined,
                color: Colors.orange[600],
              ),
              title: const Text('Mute notifications'),
              subtitle: const Text(
                'Stop receiving notifications for this chat',
              ),
              onTap: () {
                Navigator.pop(context);
                _muteChat(context, chatId);
              },
            ),

            // Clear chat option
            ListTile(
              leading: Icon(Icons.clear_all, color: Colors.blue[600]),
              title: const Text('Clear messages'),
              subtitle: const Text('Delete all messages in this chat'),
              onTap: () {
                Navigator.pop(context);
                _showClearChatDialog(context, chatId, otherName);
              },
            ),

            // Delete chat option
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete chat'),
              subtitle: const Text('Remove this chat permanently'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteChatDialog(context, chatId, otherName);
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Show delete confirmation dialog
  void _showDeleteChatDialog(
    BuildContext context,
    String chatId,
    String otherName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Chat?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete your chat with $otherName?'),
            const SizedBox(height: 8),
            const Text(
              'This will permanently delete all messages and cannot be undone.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteChat(context, chatId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Show clear chat confirmation dialog
  void _showClearChatDialog(
    BuildContext context,
    String chatId,
    String otherName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Messages?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to clear all messages with $otherName?',
            ),
            const SizedBox(height: 8),
            const Text(
              'This will delete all messages but keep the chat. This action cannot be undone.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearChatMessages(context, chatId);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  // Delete entire chat
  Future<void> _deleteChat(BuildContext context, String chatId) async {
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('Deleting chat...'),
            ],
          ),
        ),
      );

      // Delete all messages first
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get();

      final batch = FirebaseFirestore.instance.batch();

      // Delete all messages
      for (var doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete the chat document
      batch.delete(FirebaseFirestore.instance.collection('chats').doc(chatId));

      await batch.commit();

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Clear all messages in chat
  Future<void> _clearChatMessages(BuildContext context, String chatId) async {
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('Clearing messages...'),
            ],
          ),
        ),
      );

      // Get all messages
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get();

      final batch = FirebaseFirestore.instance.batch();

      // Delete all messages
      for (var doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Update chat document to reset last message
      batch.update(FirebaseFirestore.instance.collection('chats').doc(chatId), {
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': {'user': 0, 'collector': 0},
      });

      await batch.commit();

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Messages cleared successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear messages: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Mute chat (you can implement this based on your notification system)
  Future<void> _muteChat(BuildContext context, String chatId) async {
    try {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
        'isMuted': true,
        'mutedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat muted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mute chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${date.month}/${date.day}';
      }
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Now';
    }
  }
}
