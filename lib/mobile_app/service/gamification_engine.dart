import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class GamificationEngine {
  static final GamificationEngine _instance = GamificationEngine._internal();
  factory GamificationEngine() => _instance;
  GamificationEngine._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Point values for different actions
  static const int pointsWastePickup = 50;
  static const int pointsMarketplaceSale = 25;
  static const int pointsMarketplacePurchase = 10;
  static const int pointsDailyLogin = 5;
  static const int pointsWasteClassification = 2;
  static const int pointsSocialShare = 15;
  static const int pointsReferral = 100;
  static const int pointsStreakBonus = 10;

  // Badge definitions
  static const Map<String, Map<String, dynamic>> badges = {
    'first_pickup': {
      'name': 'First Steps',
      'description': 'Completed your first waste pickup',
      'icon': '🌱',
      'requirement': 1,
      'type': 'pickups',
    },
    'waste_warrior': {
      'name': 'Waste Warrior',
      'description': 'Completed 10 waste pickups',
      'icon': '⚔️',
      'requirement': 10,
      'type': 'pickups',
    },
    'eco_champion': {
      'name': 'Eco Champion',
      'description': 'Completed 50 waste pickups',
      'icon': '👑',
      'requirement': 50,
      'type': 'pickups',
    },
    'market_maker': {
      'name': 'Market Maker',
      'description': 'Sold 5 items on the marketplace',
      'icon': '💰',
      'requirement': 5,
      'type': 'sales',
    },
    'recycling_hero': {
      'name': 'Recycling Hero',
      'description': 'Recycled 100kg of waste',
      'icon': '♻️',
      'requirement': 100,
      'type': 'weight_kg',
    },
    'streak_master': {
      'name': 'Streak Master',
      'description': 'Maintained a 7-day pickup streak',
      'icon': '🔥',
      'requirement': 7,
      'type': 'streak_days',
    },
    'community_helper': {
      'name': 'Community Helper',
      'description': 'Referred 3 friends to the app',
      'icon': '🤝',
      'requirement': 3,
      'type': 'referrals',
    },
  };

  /// Award points for a specific action
  Future<void> awardPoints(
    String userId,
    String action, {
    int? customPoints,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final points = customPoints ?? _getPointsForAction(action);

      // Get user document
      final userRef = _firestore.collection('users').doc(userId);
      final userDoc = await userRef.get();

      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final currentPoints = userData['points'] ?? 0;
      final newPoints = currentPoints + points;

      // Update user points
      await userRef.update({
        'points': newPoints,
        'lastActivity': FieldValue.serverTimestamp(),
      });

      // Log the points transaction
      await _logPointsTransaction(userId, action, points, newPoints, metadata);

      // Check for new badges
      await _checkAndAwardBadges(userId, action, userData);

      // Update leaderboards
      await _updateLeaderboards(userId, newPoints);

      debugPrint('Awarded $points points to user $userId for $action');
    } catch (e) {
      debugPrint('Error awarding points: $e');
    }
  }

  int _getPointsForAction(String action) {
    switch (action) {
      case 'waste_pickup':
        return pointsWastePickup;
      case 'marketplace_sale':
        return pointsMarketplaceSale;
      case 'marketplace_purchase':
        return pointsMarketplacePurchase;
      case 'daily_login':
        return pointsDailyLogin;
      case 'waste_classification':
        return pointsWasteClassification;
      case 'social_share':
        return pointsSocialShare;
      case 'referral':
        return pointsReferral;
      case 'streak_bonus':
        return pointsStreakBonus;
      default:
        return 5; // Default points
    }
  }

  Future<void> _logPointsTransaction(
    String userId,
    String action,
    int points,
    int totalPoints,
    Map<String, dynamic>? metadata,
  ) async {
    await _firestore.collection('points_transactions').add({
      'userId': userId,
      'action': action,
      'points': points,
      'totalPoints': totalPoints,
      'timestamp': FieldValue.serverTimestamp(),
      'metadata': metadata,
    });
  }

  Future<void> _checkAndAwardBadges(
    String userId,
    String action,
    Map<String, dynamic> userData,
  ) async {
    final userRef = _firestore.collection('users').doc(userId);
    final userBadges = List<String>.from(userData['badges'] ?? []);

    for (final badgeEntry in badges.entries) {
      final badgeId = badgeEntry.key;
      final badge = badgeEntry.value;

      // Skip if user already has this badge
      if (userBadges.contains(badgeId)) continue;

      // Check if user meets the requirement
      final requirement = badge['requirement'] as int;
      final type = badge['type'] as String;

      bool meetsRequirement = false;

      switch (type) {
        case 'pickups':
          final pickupCount = userData['totalPickups'] ?? 0;
          meetsRequirement = pickupCount >= requirement;
          break;
        case 'sales':
          final salesCount = userData['totalSales'] ?? 0;
          meetsRequirement = salesCount >= requirement;
          break;
        case 'weight_kg':
          final totalWeight = userData['totalWeightKg'] ?? 0.0;
          meetsRequirement = totalWeight >= requirement;
          break;
        case 'streak_days':
          final currentStreak = userData['currentStreak'] ?? 0;
          meetsRequirement = currentStreak >= requirement;
          break;
        case 'referrals':
          final referralCount = userData['referralCount'] ?? 0;
          meetsRequirement = referralCount >= requirement;
          break;
      }

      if (meetsRequirement) {
        // Award the badge
        userBadges.add(badgeId);
        await userRef.update({
          'badges': userBadges,
          'lastBadgeEarned': badgeId,
          'lastBadgeEarnedAt': FieldValue.serverTimestamp(),
        });

        // Log badge achievement
        await _firestore.collection('badge_achievements').add({
          'userId': userId,
          'badgeId': badgeId,
          'badgeName': badge['name'],
          'timestamp': FieldValue.serverTimestamp(),
        });

        debugPrint('User $userId earned badge: $badgeId');
      }
    }
  }

  Future<void> _updateLeaderboards(String userId, int newPoints) async {
    try {
      // Update global leaderboard
      await _firestore.collection('leaderboards').doc('global').set({
        'users': {
          userId: {
            'points': newPoints,
            'lastUpdated': FieldValue.serverTimestamp(),
          },
        },
      }, SetOptions(merge: true));

      // Update weekly leaderboard
      final weekStart = _getWeekStart();
      final weekKey = DateFormat('yyyy-MM-dd').format(weekStart);

      await _firestore.collection('leaderboards').doc('weekly_$weekKey').set({
        'users': {
          userId: {
            'points': newPoints,
            'lastUpdated': FieldValue.serverTimestamp(),
          },
        },
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating leaderboards: $e');
    }
  }

  DateTime _getWeekStart() {
    final now = DateTime.now();
    final weekday = now.weekday; // 1 = Monday, 7 = Sunday
    final daysToSubtract = weekday - 1; // Monday is start of week
    return DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: daysToSubtract));
  }

  /// Get user's current points and badges
  Future<Map<String, dynamic>> getUserGamificationData(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        return {'points': 0, 'badges': [], 'level': 1, 'nextLevelPoints': 100};
      }

      final userData = userDoc.data()!;
      final points = userData['points'] ?? 0;
      final badges = List<String>.from(userData['badges'] ?? []);

      final level = _calculateLevel(points);
      final nextLevelPoints = _getNextLevelPoints(level);

      return {
        'points': points,
        'badges': badges,
        'level': level,
        'nextLevelPoints': nextLevelPoints,
        'progressToNextLevel': (points / nextLevelPoints * 100).clamp(0, 100),
      };
    } catch (e) {
      debugPrint('Error getting user gamification data: $e');
      return {'points': 0, 'badges': [], 'level': 1, 'nextLevelPoints': 100};
    }
  }

  int _calculateLevel(int points) {
    // Level calculation: Level N requires N * 100 points
    // Level 1: 0-99, Level 2: 100-299, Level 3: 300-599, etc.
    if (points < 100) return 1;

    int level = 1;
    int pointsNeeded = 100;

    while (points >= pointsNeeded) {
      level++;
      pointsNeeded += level * 100;
    }

    return level;
  }

  int _getNextLevelPoints(int currentLevel) {
    int total = 100;
    for (int i = 2; i <= currentLevel + 1; i++) {
      total += i * 100;
    }
    return total;
  }

  /// Get leaderboard data
  Future<List<Map<String, dynamic>>> getLeaderboard({
    String type = 'global',
    int limit = 50,
  }) async {
    try {
      late QuerySnapshot query;

      if (type == 'global') {
        query = await _firestore
            .collection('leaderboards')
            .doc('global')
            .collection('entries')
            .orderBy('points', descending: true)
            .limit(limit)
            .get();
      } else if (type == 'weekly') {
        final weekStart = _getWeekStart();
        final weekKey = DateFormat('yyyy-MM-dd').format(weekStart);

        query = await _firestore
            .collection('leaderboards')
            .doc('weekly_$weekKey')
            .collection('entries')
            .orderBy('points', descending: true)
            .limit(limit)
            .get();
      }

      final leaderboard = <Map<String, dynamic>>[];

      for (final doc in query.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final userId = data['userId'] as String;

        // Get user info
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final userData = userDoc.data();

        leaderboard.add({
          'userId': userId,
          'name': userData?['name'] ?? 'Anonymous',
          'points': data['points'] ?? 0,
          'badges': userData?['badges'] ?? [],
          'level': _calculateLevel(data['points'] ?? 0),
        });
      }

      return leaderboard;
    } catch (e) {
      debugPrint('Error getting leaderboard: $e');
      return [];
    }
  }

  /// Get user's rank on leaderboard
  Future<Map<String, dynamic>> getUserRank(
    String userId, {
    String type = 'global',
  }) async {
    try {
      final leaderboard = await getLeaderboard(type: type, limit: 1000);

      final userIndex = leaderboard.indexWhere(
        (entry) => entry['userId'] == userId,
      );

      if (userIndex == -1) {
        return {
          'rank': null,
          'totalParticipants': leaderboard.length,
          'userPoints': 0,
        };
      }

      return {
        'rank': userIndex + 1,
        'totalParticipants': leaderboard.length,
        'userPoints': leaderboard[userIndex]['points'],
      };
    } catch (e) {
      debugPrint('Error getting user rank: $e');
      return {'rank': null, 'totalParticipants': 0, 'userPoints': 0};
    }
  }

  /// Get recent achievements and points
  Future<List<Map<String, dynamic>>> getRecentActivity(
    String userId, {
    int limit = 10,
  }) async {
    try {
      final query = await _firestore
          .collection('points_transactions')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      final activities = <Map<String, dynamic>>[];

      for (final doc in query.docs) {
        final data = doc.data();
        activities.add({
          'action': data['action'],
          'points': data['points'],
          'timestamp': (data['timestamp'] as Timestamp).toDate(),
          'totalPoints': data['totalPoints'],
        });
      }

      return activities;
    } catch (e) {
      debugPrint('Error getting recent activity: $e');
      return [];
    }
  }

  /// Check and update daily login streak
  Future<void> checkDailyLogin(String userId) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      final userDoc = await userRef.get();

      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final lastLogin = userData['lastLogin'] as Timestamp?;
      final currentStreak = userData['currentStreak'] ?? 0;
      final longestStreak = userData['longestStreak'] ?? 0;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (lastLogin == null) {
        // First login
        await userRef.update({
          'lastLogin': Timestamp.fromDate(today),
          'currentStreak': 1,
          'longestStreak': 1,
        });
        await awardPoints(userId, 'daily_login');
        return;
      }

      final lastLoginDate = DateTime(
        lastLogin.toDate().year,
        lastLogin.toDate().month,
        lastLogin.toDate().day,
      );

      final daysDifference = today.difference(lastLoginDate).inDays;

      if (daysDifference == 1) {
        // Consecutive day
        final newStreak = currentStreak + 1;
        await userRef.update({
          'lastLogin': Timestamp.fromDate(today),
          'currentStreak': newStreak,
          'longestStreak': newStreak > longestStreak
              ? newStreak
              : longestStreak,
        });
        await awardPoints(userId, 'daily_login');

        // Bonus for streak milestones
        if (newStreak % 7 == 0) {
          await awardPoints(
            userId,
            'streak_bonus',
            customPoints: newStreak * 5,
          );
        }
      } else if (daysDifference > 1) {
        // Streak broken
        await userRef.update({
          'lastLogin': Timestamp.fromDate(today),
          'currentStreak': 1,
        });
        await awardPoints(userId, 'daily_login');
      }
      // If daysDifference == 0, already logged in today
    } catch (e) {
      debugPrint('Error checking daily login: $e');
    }
  }

  /// Get available challenges
  Future<List<Map<String, dynamic>>> getAvailableChallenges(
    String userId,
  ) async {
    try {
      final userData = await getUserGamificationData(userId);
      final userPoints = userData['points'] as int;
      final userBadges = List<String>.from(userData['badges']);

      final challenges = [
        {
          'id': 'pickup_challenge',
          'title': 'Pickup Master',
          'description': 'Complete 5 pickups this week',
          'reward': 100,
          'progress': 0, // Would need to calculate from recent pickups
          'total': 5,
          'type': 'weekly',
        },
        {
          'id': 'marketplace_challenge',
          'title': 'Marketplace Mogul',
          'description': 'Sell 3 items on the marketplace',
          'reward': 75,
          'progress': 0, // Would need to calculate from sales
          'total': 3,
          'type': 'monthly',
        },
        {
          'id': 'referral_challenge',
          'title': 'Community Builder',
          'description': 'Refer 2 friends to join EcoWaste',
          'reward': 150,
          'progress': 0, // Would need to calculate from referrals
          'total': 2,
          'type': 'ongoing',
        },
      ];

      return challenges;
    } catch (e) {
      debugPrint('Error getting challenges: $e');
      return [];
    }
  }

  /// Get badge information
  Map<String, dynamic>? getBadgeInfo(String badgeId) {
    return badges[badgeId];
  }

  /// Get all available badges
  Map<String, Map<String, dynamic>> getAllBadges() {
    return badges;
  }
}

// Gamification UI Components
class PointsDisplay extends StatelessWidget {
  final int points;
  final int level;

  const PointsDisplay({super.key, required this.points, required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.stars, color: Colors.green.shade600, size: 20),
          const SizedBox(width: 8),
          Text(
            '$points pts',
            style: TextStyle(
              color: Colors.green.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.shade600,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Lv.$level',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BadgeDisplay extends StatelessWidget {
  final List<String> badgeIds;

  const BadgeDisplay({super.key, required this.badgeIds});

  @override
  Widget build(BuildContext context) {
    if (badgeIds.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: badgeIds.map((badgeId) {
        final badge = GamificationEngine().getBadgeInfo(badgeId);
        if (badge == null) return const SizedBox.shrink();

        return Tooltip(
          message: '${badge['name']}\n${badge['description']}',
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Text(badge['icon'], style: const TextStyle(fontSize: 16)),
          ),
        );
      }).toList(),
    );
  }
}

class LeaderboardWidget extends StatelessWidget {
  final List<Map<String, dynamic>> leaderboard;
  final String? currentUserId;

  const LeaderboardWidget({
    super.key,
    required this.leaderboard,
    this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: leaderboard.length,
      itemBuilder: (context, index) {
        final entry = leaderboard[index];
        final isCurrentUser = entry['userId'] == currentUserId;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isCurrentUser ? Colors.green.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCurrentUser
                  ? Colors.green.shade200
                  : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              // Rank
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _getRankColor(index + 1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry['name'],
                      style: TextStyle(
                        fontWeight: isCurrentUser
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isCurrentUser
                            ? Colors.green.shade800
                            : Colors.black,
                      ),
                    ),
                    Text(
                      'Level ${entry['level']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // Points
              Text(
                '${entry['points']} pts',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey.shade400;
      case 3:
        return Colors.orange.shade300;
      default:
        return Colors.green.shade600;
    }
  }
}
