// ignore_for_file: unused_import

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationProvider extends ChangeNotifier {
  int _unreadCount = 0;
  StreamSubscription<QuerySnapshot>? _notificationStream;
  String? _currentUserId;
  String? _userType; // 'user' or 'collector'

  int get unreadCount => _unreadCount;

  void initialize(String userId, String userType) {
    _currentUserId = userId;
    _userType = userType;
    _startListening();
  }

  void _startListening() {
    if (_currentUserId == null) return;

    // Listen to notifications collection for real-time updates
    _notificationStream = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: _currentUserId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
          _unreadCount = snapshot.docs.length;
          notifyListeners();
        });
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      if (_currentUserId == null) return;

      // Get all unread notifications for the current user
      final unreadNotifications = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: _currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      // Mark all as read in a batch
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  Future<void> createNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': userId,
        'type': type,
        'title': title,
        'message': message,
        'data': data ?? {},
        'isRead': false,
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  @override
  void dispose() {
    _notificationStream?.cancel();
    super.dispose();
  }
}
