import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// }
import 'package:flutter/foundation.dart';
import 'dart:math';

class UserProvider with ChangeNotifier {
  String? _username;
  String? _email;
  String? _phone;

  String? get username => _username;
  String? get email => _email;
  String? get phone => _phone;

  Future<void> fetchUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data();
      if (data != null) {
        _username = doc.data()?['name'];
        _email = doc.data()?['email'];
        _phone = doc.data()?['phone'];
        notifyListeners();
      }
    }
  }
}

class CollectorProvider with ChangeNotifier {
  String? _email;
  String? _phone;
  String? _town;
  String? _username;
  //final bool _isLoading = false;

  String? get email => _email;
  String? get phone => _phone;
  String? get town => _town;
  String? get name => _username;
  //bool get isLoading => _isLoading;

  Future<void> fetchCollectorData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance
          .collection('collectors')
          .doc(uid)
          .get();

      final data = doc.data();
      if (data != null) {
        _email = data['email'];
        _phone = data['phone'];
        _town = data['town'];
        _username = data['name'];
        notifyListeners();
      }
    }
  }
}

class SortScoreProvider with ChangeNotifier {
  int _totalPickups = 0;
  int _monthlyPickups = 0;
  int _rank = 0;
  int _sortScore = 0; // Now represents real recycling points
  double _totalWeightKg = 0.0;
  int _globalRank = 0;
  int _totalUsers = 0;
  bool _isLoading = false;
  StreamSubscription<QuerySnapshot>? _pickupStream;

  int get totalPickups => _totalPickups;
  int get monthlyPickups => _monthlyPickups;
  int get rank => _rank;
  int get sortScore => _sortScore;
  int get globalRank => _globalRank;
  int get totalUsers => _totalUsers;
  double get totalWeightKg => _totalWeightKg;
  bool get isLoading => _isLoading;

  // Points calculation: 10 points per pickup + weight-based bonus
  static const int pointsPerPickup = 10;
  static const int pointsPerKg = 5;

  SortScoreProvider() {
    _initializeData();
  }

  Future<void> _initializeData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await calculatePickupStats(userId);
      await _calculateRecyclingPoints(userId);
      _startListeningToPickups(userId);
    }
  }

  Future<void> _calculateRecyclingPoints(String userId) async {
    try {
      // Get user's completed pickups to calculate real points
      final pickups = await FirebaseFirestore.instance
          .collection('pickup_requests')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .get();

      double totalWeight = 0.0;
      int completedCount = pickups.docs.length;

      // Calculate total weight from pickup data
      for (var doc in pickups.docs) {
        final data = doc.data();
        // Estimate 5kg per pickup if no weight specified
        final weight = (data['estimatedWeight'] as num?)?.toDouble() ?? 5.0;
        totalWeight += weight;
      }

      _totalWeightKg = totalWeight;

      // Calculate points: 10 points per pickup + 5 points per kg
      _sortScore =
          (completedCount * pointsPerPickup) +
          (totalWeight * pointsPerKg).round();

      // Update user document with calculated points
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'sortScore': _sortScore,
        'totalWeightKg': _totalWeightKg,
        'totalPickups': completedCount,
        'lastPointsUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      notifyListeners();
    } catch (e) {
      debugPrint("Error calculating recycling points: $e");
      notifyListeners();
    }
  }

  void _startListeningToPickups(String userId) {
    _pickupStream?.cancel();
    _pickupStream = FirebaseFirestore.instance
        .collection('pickup_requests')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
          _calculatePickupsFromSnapshot(snapshot);
        });
  }

  void _calculatePickupsFromSnapshot(QuerySnapshot snapshot) {
    int completed = 0;
    int completedThisMonth = 0;
    final now = DateTime.now();

    for (var doc in snapshot.docs) {
      final status = doc['status'];
      final timestamp = (doc['createdAt'] as Timestamp?)?.toDate();

      if (status == 'completed' && timestamp != null) {
        completed++;

        if (timestamp.month == now.month && timestamp.year == now.year) {
          completedThisMonth++;
        }
      }
    }

    _totalPickups = completed;
    _monthlyPickups = completedThisMonth;
    notifyListeners();
  }

  Future<void> calculatePickupStats(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final snapshot = await FirebaseFirestore.instance
          .collection('pickup_requests')
          .where('userId', isEqualTo: userId)
          .get();

      _calculatePickupsFromSnapshot(snapshot);
      await _calculateRecyclingPoints(userId);
      await fetchUserRank(userId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint("Error calculating pickups: $e");
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchUserRank(String userId) async {
    try {
      // Get current user's points
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        _rank = 0;
        _globalRank = 0;
        notifyListeners();
        return;
      }

      final userPoints = userDoc.data()?['sortScore'] ?? 0;

      // Get all users with points (for global leaderboard)
      final allUsersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('sortScore', isGreaterThan: 0)
          .get();

      _totalUsers = allUsersQuery.docs.length;

      // Count users with higher points (global rank)
      int usersWithMorePoints = 0;
      for (var doc in allUsersQuery.docs) {
        final points = doc.data()['sortScore'] ?? 0;
        if (points > userPoints) {
          usersWithMorePoints++;
        }
      }

      _globalRank = usersWithMorePoints + 1;
      _rank = _globalRank; // Keep _rank for backward compatibility

      // Cache the result
      await FirebaseFirestore.instance
          .collection('user_stats')
          .doc(userId)
          .set({
            'globalRank': _globalRank,
            'rank': _rank,
            'totalPickups': _totalPickups,
            'sortScore': userPoints,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching global rank: $e");
      _rank = 0;
      _globalRank = 0;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pickupStream?.cancel();
    super.dispose();
  }
}
