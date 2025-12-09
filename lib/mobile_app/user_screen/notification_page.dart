import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class UserNotificationPage extends StatefulWidget {
  const UserNotificationPage({super.key});

  @override
  State<UserNotificationPage> createState() => _UserNotificationPageState();
}

class _UserNotificationPageState extends State<UserNotificationPage> {
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: const Text(
              'Mark All Read',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ll see notifications here when they arrive',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification =
                  notifications[index].data() as Map<String, dynamic>;
              final notificationId = notifications[index].id;
              final isRead = notification['isRead'] ?? false;
              final type = notification['type'] ?? '';
              final title = notification['title'] ?? '';
              final message = notification['message'] ?? '';
              final createdAt = notification['createdAt'] as Timestamp?;
              final data = notification['data'] as Map<String, dynamic>?;

              return _buildNotificationCard(
                notification,
                notificationId,
                isRead,
                createdAt,
                type,
                data,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(
    Map<String, dynamic> notification,
    String notificationId,
    bool isRead,
    Timestamp? createdAt,
    String type,
    Map<String, dynamic>? data,
  ) {
    final timeAgo = createdAt != null
        ? _getTimeAgo(createdAt.toDate())
        : 'Unknown time';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRead ? Colors.grey.shade200 : Colors.blue.shade200,
          width: isRead ? 1 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    notification['title'] ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                      color: isRead ? Colors.grey.shade700 : Colors.black87,
                    ),
                  ),
                ),
                Row(
                  children: [
                    if (!isRead)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'NEW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _deleteNotification(notificationId),
                      icon: Icon(
                        Icons.delete_outline,
                        color: Colors.red.shade400,
                        size: 20,
                      ),
                      tooltip: 'Delete notification',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              notification['message'] ?? '',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),

            // Special handling for pickup confirmation notifications
            if (type == 'pickup_status_update' &&
                data?['status'] == 'pending_confirmation')
              _buildConfirmationSection(notification, notificationId),

            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  timeAgo,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                if (!isRead)
                  TextButton(
                    onPressed: () => _markAsRead(notificationId),
                    child: const Text(
                      'Mark Read',
                      style: TextStyle(color: Colors.blue, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationSection(
    Map<String, dynamic> notification,
    String notificationId,
  ) {
    final data = notification['data'] ?? {};
    final totalAmount = data['totalAmount'] ?? 0.0;
    final binCount = data['binCount'] ?? 0;
    final collectorName = data['collectorName'] ?? 'Unknown Collector';

    // Check if the pickup request is already completed or has an issue reported
    final isCompleted =
        data['status'] == 'completed' || data['status'] == 'issue_reported';
    final isRead = notification['isRead'] ?? false;
    final shouldDisableButtons = isRead || isCompleted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: shouldDisableButtons
            ? (data['status'] == 'completed'
                  ? Colors.green.shade50
                  : Colors.red.shade50)
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: shouldDisableButtons
              ? (data['status'] == 'completed'
                    ? Colors.green.shade200
                    : Colors.red.shade200)
              : Colors.orange.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                shouldDisableButtons
                    ? (data['status'] == 'completed'
                          ? Icons.check_circle
                          : Icons.error)
                    : Icons.payment,
                color: shouldDisableButtons
                    ? (data['status'] == 'completed'
                          ? Colors.green.shade600
                          : Colors.red.shade600)
                    : Colors.orange.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                shouldDisableButtons
                    ? (data['status'] == 'completed'
                          ? 'Payment Released'
                          : 'Issue Reported')
                    : 'Payment Pending Release',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: shouldDisableButtons
                      ? (data['status'] == 'completed'
                            ? Colors.green.shade700
                            : Colors.red.shade700)
                      : Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Amount: GH₵ ${totalAmount.toStringAsFixed(2)} (${binCount} bin${binCount > 1 ? 's' : ''})',
            style: TextStyle(
              fontSize: 13,
              color: shouldDisableButtons
                  ? (data['status'] == 'completed'
                        ? Colors.green.shade700
                        : Colors.red.shade700)
                  : Colors.orange.shade700,
            ),
          ),
          Text(
            'Collector: $collectorName',
            style: TextStyle(
              fontSize: 13,
              color: shouldDisableButtons
                  ? (data['status'] == 'completed'
                        ? Colors.green.shade700
                        : Colors.red.shade700)
                  : Colors.orange.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: shouldDisableButtons
                      ? null
                      : () => _confirmPickupCompletion(notificationId, data),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: shouldDisableButtons
                        ? Colors.grey.shade500
                        : Colors.green.shade600,
                    side: BorderSide(
                      color: shouldDisableButtons
                          ? Colors.grey.shade400
                          : Colors.green.shade600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    shouldDisableButtons
                        ? (data['status'] == 'completed'
                              ? 'Payment Confirmed'
                              : 'Issue Reported')
                        : 'Confirm Completion',
                    style: TextStyle(
                      color: shouldDisableButtons
                          ? Colors.grey.shade500
                          : Colors.green.shade600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: shouldDisableButtons
                      ? null
                      : () => _reportIssue(notificationId, data),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: shouldDisableButtons
                        ? Colors.grey.shade500
                        : Colors.red.shade600,
                    side: BorderSide(
                      color: shouldDisableButtons
                          ? Colors.grey.shade400
                          : Colors.red.shade600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    shouldDisableButtons ? 'Action Completed' : 'Report Issue',
                    style: TextStyle(
                      color: shouldDisableButtons
                          ? Colors.grey.shade500
                          : Colors.red.shade600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmPickupCompletion(
    String notificationId,
    Map<String, dynamic> data,
  ) async {
    final pickupRequestId = data['pickupRequestId'];
    if (pickupRequestId == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Pickup Completion'),
        content: Text(
          'Are you sure you want to confirm that ${data['collectorName']} has completed your waste pickup?\n\n'
          'This will release the payment of GH₵ ${data['totalAmount'].toStringAsFixed(2)} to the collector.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Update pickup request status to completed
        await FirebaseFirestore.instance
            .collection('pickup_requests')
            .doc(pickupRequestId)
            .update({
              'status': 'completed',
              'userConfirmedAt': FieldValue.serverTimestamp(),
              'paymentReleased': true,
              'paymentReleasedAt': FieldValue.serverTimestamp(),
            });

        // Mark notification as read
        await _markAsRead(notificationId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Pickup confirmed! Payment of GH₵ ${data['totalAmount'].toStringAsFixed(2)} has been released to ${data['collectorName']}',
              ),
              backgroundColor: Colors.green.shade600,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error confirming pickup: ${e.toString()}'),
              backgroundColor: Colors.red.shade600,
            ),
          );
        }
      }
    }
  }

  Future<void> _reportIssue(
    String notificationId,
    Map<String, dynamic> data,
  ) async {
    final pickupRequestId = data['pickupRequestId'];
    if (pickupRequestId == null) return;

    // Show issue reporting dialog
    String? selectedIssueType;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Issue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('What issue did you encounter with this pickup?'),
            const SizedBox(height: 16),
            ...['waste_not_collected', 'poor_service', 'other'].map((
              issueType,
            ) {
              return RadioListTile<String>(
                title: Text(
                  issueType
                      .replaceAll('_', ' ')
                      .replaceAll('poor', 'Poor')
                      .replaceAll('not', 'Not')
                      .replaceAll('other', 'Other'),
                ),
                value: issueType,
                groupValue: selectedIssueType,
                onChanged: (value) {
                  setState(() {
                    selectedIssueType = value;
                  });
                },
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: selectedIssueType == null
                ? null
                : () => Navigator.pop(context, selectedIssueType),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Report'),
          ),
        ],
      ),
    );

    if (selectedIssueType != null) {
      try {
        // Update pickup request status to issue_reported
        await FirebaseFirestore.instance
            .collection('pickup_requests')
            .doc(pickupRequestId)
            .update({
              'status': 'issue_reported',
              'issueType': selectedIssueType,
              'issueReportedAt': FieldValue.serverTimestamp(),
            });

        // Mark notification as read
        await _markAsRead(notificationId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Issue reported. We will investigate and contact you soon.',
              ),
              backgroundColor: Colors.orange.shade600,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error reporting issue: ${e.toString()}'),
              backgroundColor: Colors.red.shade600,
            ),
          );
        }
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final unreadNotifications = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('All notifications marked as read'),
            backgroundColor: Colors.green.shade600,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error marking notifications as read: ${e.toString()}',
            ),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notification'),
        content: const Text(
          'Are you sure you want to delete this notification? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(notificationId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting notification: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
