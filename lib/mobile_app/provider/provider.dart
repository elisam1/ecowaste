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
  int _sortScore = 0;
  bool _isLoading = false;
  StreamSubscription<QuerySnapshot>? _pickupStream;
  Timer? _sortScoreTimer; // Added timer for auto-generation

  int get totalPickups => _totalPickups;
  int get monthlyPickups => _monthlyPickups;
  int get rank => _rank;
  int get sortScore => _sortScore;
  bool get isLoading => _isLoading;

  SortScoreProvider() {
    _initializeData();
  }

  Future<void> _initializeData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await calculatePickupStats(userId);
      await _generateInitialSortScore(userId); // Generate initial score
      _startListeningToPickups(userId);
      _startAutoGeneration(userId); // Start auto-generation timer
    }
  }

  void _startAutoGeneration(String userId) {
    // Cancel existing timer if any
    _sortScoreTimer?.cancel();
    
    // Generate new sort score every 5 minutes (300 seconds)
    _sortScoreTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _generateRandomSortScore(userId);
    });
  }

  Future<void> _generateInitialSortScore(String userId) async {
    try {
      // Check if user already has a sort score
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists && userDoc.data()?['sortScore'] != null) {
        // User already has a sort score, load it
        _sortScore = userDoc.data()!['sortScore'];
      } else {
        // Generate new sort score
        await _generateRandomSortScore(userId);
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error generating initial sort score: $e");
      // Fallback to generating new score
      await _generateRandomSortScore(userId);
    }
  }

  Future<void> _generateRandomSortScore(String userId) async {
    try {
      final random = Random();
      _sortScore = 100 + random.nextInt(9900); // Random between 100 and 9999

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'sortScore': _sortScore,
        'lastSortScoreUpdate': FieldValue.serverTimestamp(),
      });
      notifyListeners();
    } catch (e) {
      debugPrint("Error generating random sort score: $e");
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
      // First check if user has a cached rank in user_stats collection
      final userStatsDoc = await FirebaseFirestore.instance
          .collection('user_stats')
          .doc(userId)
          .get();

      if (userStatsDoc.exists && userStatsDoc.data()?['rank'] != null) {
        _rank = userStatsDoc.data()!['rank'];
        notifyListeners();
        return;
      }

      // Fallback: Only get user's completed requests count and approximate rank
      final userCompletedCount = await FirebaseFirestore.instance
          .collection('pickup_requests')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .count()
          .get();

      final totalUserCompletedCount = userCompletedCount.count ?? 0;

      // Get count of users with more completions than current user
      final betterUsersQuery = await FirebaseFirestore.instance
          .collection('pickup_requests')
          .where('status', isEqualTo: 'completed')
          .get();

      final Map<String, int> userCounts = {};
      for (var doc in betterUsersQuery.docs) {
        final uid = doc['userId'];
        userCounts[uid] = (userCounts[uid] ?? 0) + 1;
      }

      // Count users with more completions
      int betterUsersCount = 0;
      for (var count in userCounts.values) {
        if (count > totalUserCompletedCount) {
          betterUsersCount++;
        }
      }

      _rank = betterUsersCount + 1;

      // Cache the result for future use
      await FirebaseFirestore.instance
          .collection('user_stats')
          .doc(userId)
          .set({
            'rank': _rank,
            'totalPickups': _totalPickups,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching rank: $e");
      // Set a default rank if there's an error
      _rank = 0;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pickupStream?.cancel();
    _sortScoreTimer?.cancel(); // Cancel timer on dispose
    super.dispose();
  }
}
