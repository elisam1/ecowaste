import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/mobile_app/constants/app_constants.dart';
import 'package:flutter_application_1/mobile_app/service/logging_service.dart';

/// Result of a rate limit check
class RateLimitResult {
  final bool allowed;
  final int remainingAttempts;
  final DateTime resetTime;
  final String message;

  RateLimitResult({
    required this.allowed,
    required this.remainingAttempts,
    required this.resetTime,
    required this.message,
  });
}

/// Service for rate limiting critical operations
class RateLimitService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Check rate limit for signup attempts
  static Future<RateLimitResult> checkSignupAttempt() async {
    return _checkRateLimit(
      'signup',
      AppConstants.maxSignupAttemptsPerHour,
      60, // 1 hour
    );
  }

  /// Check rate limit for login attempts
  static Future<RateLimitResult> checkLoginAttempt(String email) async {
    return _checkRateLimit(
      'login_$email',
      AppConstants.maxLoginAttemptsPerHour,
      60,
    );
  }

  /// Check rate limit for payment attempts
  static Future<RateLimitResult> checkPaymentAttempt() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return RateLimitResult(
        allowed: false,
        remainingAttempts: 0,
        resetTime: DateTime.now().add(const Duration(hours: 1)),
        message: 'User not authenticated',
      );
    }

    return _checkRateLimit(
      'payment_$userId',
      AppConstants.maxPaymentAttemptsPerHour,
      60,
    );
  }

  /// Check rate limit for marketplace item creation
  static Future<RateLimitResult> checkItemCreation() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return RateLimitResult(
        allowed: false,
        remainingAttempts: 0,
        resetTime: DateTime.now().add(const Duration(hours: 1)),
        message: 'User not authenticated',
      );
    }

    return _checkRateLimit(
      'item_creation_$userId',
      20, // Max 20 items per day
      24 * 60, // 24 hours
    );
  }

  /// Check rate limit for message sending
  static Future<RateLimitResult> checkMessageSending() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return RateLimitResult(
        allowed: false,
        remainingAttempts: 0,
        resetTime: DateTime.now().add(const Duration(minutes: 1)),
        message: 'User not authenticated',
      );
    }

    return _checkRateLimit(
      'messages_$userId',
      60, // Max 60 messages per hour
      60,
    );
  }

  /// Check rate limit for API calls
  static Future<RateLimitResult> checkApiCall(String endpoint) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return RateLimitResult(
        allowed: false,
        remainingAttempts: 0,
        resetTime: DateTime.now().add(const Duration(minutes: 1)),
        message: 'User not authenticated',
      );
    }

    return _checkRateLimit(
      'api_$endpoint',
      100, // Max 100 calls per hour
      60,
    );
  }

  /// Generic rate limit check
  static Future<RateLimitResult> _checkRateLimit(
    String key,
    int maxAttempts,
    int windowMinutes,
  ) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return RateLimitResult(
          allowed: false,
          remainingAttempts: 0,
          resetTime: DateTime.now().add(Duration(minutes: windowMinutes)),
          message: 'Not authenticated',
        );
      }

      final rateLimitRef = _firestore
          .collection('rate_limits')
          .doc('${userId}_$key');

      final docSnapshot = await rateLimitRef.get();
      final now = DateTime.now();

      if (!docSnapshot.exists) {
        // First attempt - create new record
        await rateLimitRef.set({
          'attempts': 1,
          'resetTime': Timestamp.fromDate(
            now.add(Duration(minutes: windowMinutes)),
          ),
          'createdAt': Timestamp.now(),
        });

        LoggingService.logCacheOperation('RATE_LIMIT_NEW', key);

        return RateLimitResult(
          allowed: true,
          remainingAttempts: maxAttempts - 1,
          resetTime: now.add(Duration(minutes: windowMinutes)),
          message: 'Attempt 1 of $maxAttempts',
        );
      }

      final data = docSnapshot.data() as Map<String, dynamic>;
      final resetTime = (data['resetTime'] as Timestamp).toDate();
      final currentAttempts = data['attempts'] as int? ?? 0;

      // Check if window has expired
      if (now.isAfter(resetTime)) {
        // Reset counter
        await rateLimitRef.update({
          'attempts': 1,
          'resetTime': Timestamp.fromDate(
            now.add(Duration(minutes: windowMinutes)),
          ),
        });

        LoggingService.logCacheOperation('RATE_LIMIT_RESET', key);

        return RateLimitResult(
          allowed: true,
          remainingAttempts: maxAttempts - 1,
          resetTime: now.add(Duration(minutes: windowMinutes)),
          message: 'Window reset. Attempt 1 of $maxAttempts',
        );
      }

      // Window still active
      if (currentAttempts >= maxAttempts) {
        LoggingService.warning('Rate limit exceeded for $key');

        return RateLimitResult(
          allowed: false,
          remainingAttempts: 0,
          resetTime: resetTime,
          message:
              'Rate limit exceeded. Try again after ${resetTime.toString()}',
        );
      }

      // Increment attempt
      await rateLimitRef.update({'attempts': currentAttempts + 1});

      LoggingService.logCacheOperation('RATE_LIMIT_CHECK', key);

      return RateLimitResult(
        allowed: true,
        remainingAttempts: maxAttempts - (currentAttempts + 1),
        resetTime: resetTime,
        message: 'Attempt ${currentAttempts + 1} of $maxAttempts',
      );
    } catch (e) {
      LoggingService.error('Error checking rate limit: $e');
      // Allow on error (fail open)
      return RateLimitResult(
        allowed: true,
        remainingAttempts: -1,
        resetTime: DateTime.now(),
        message: 'Error checking rate limit',
      );
    }
  }

  /// Reset rate limit for a user
  static Future<bool> resetRateLimit(String key) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      await _firestore.collection('rate_limits').doc('${userId}_$key').delete();

      LoggingService.success('Rate limit reset for $key');
      return true;
    } catch (e) {
      LoggingService.error('Error resetting rate limit: $e');
      return false;
    }
  }

  /// Get current rate limit status
  static Future<Map<String, dynamic>?> getRateLimitStatus(String key) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final docSnapshot = await _firestore
          .collection('rate_limits')
          .doc('${userId}_$key')
          .get();

      if (!docSnapshot.exists) return null;

      return docSnapshot.data();
    } catch (e) {
      LoggingService.error('Error getting rate limit status: $e');
      return null;
    }
  }

  /// Cleanup expired rate limit records (should be called periodically)
  static Future<int> cleanupExpiredRecords() async {
    try {
      final now = Timestamp.now();
      final snapshot = await _firestore
          .collection('rate_limits')
          .where('resetTime', isLessThan: now)
          .get();

      int count = 0;
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
        count++;
      }

      LoggingService.info('Cleaned up $count expired rate limit records');
      return count;
    } catch (e) {
      LoggingService.error('Error cleaning up rate limits: $e');
      return 0;
    }
  }

  /// Check if user is banned temporarily due to excessive attempts
  static Future<bool> isUserBanned() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final bannedDoc = await _firestore
          .collection('banned_users')
          .doc(userId)
          .get();

      if (!bannedDoc.exists) return false;

      final data = bannedDoc.data() as Map<String, dynamic>;
      final bannedUntil = (data['bannedUntil'] as Timestamp?)?.toDate();

      if (bannedUntil == null) return true;

      // Check if ban has expired
      if (DateTime.now().isAfter(bannedUntil)) {
        // Ban expired, remove record
        await bannedDoc.reference.delete();
        return false;
      }

      return true;
    } catch (e) {
      LoggingService.error('Error checking ban status: $e');
      return false;
    }
  }

  /// Temporarily ban user
  static Future<void> banUserTemporarily(
    String userId,
    Duration duration,
    String reason,
  ) async {
    try {
      await _firestore.collection('banned_users').doc(userId).set({
        'bannedAt': Timestamp.now(),
        'bannedUntil': Timestamp.fromDate(DateTime.now().add(duration)),
        'reason': reason,
      });

      LoggingService.warning('User banned: $userId for $duration');
    } catch (e) {
      LoggingService.error('Error banning user: $e');
    }
  }
}
