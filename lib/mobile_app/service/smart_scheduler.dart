import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SmartScheduler {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Analyzes user's pickup history to predict optimal pickup times
  Future<List<DateTime>> predictOptimalPickupTimes(String userId) async {
    try {
      // Get user's pickup history
      final historyQuery = await _firestore
          .collection('pickup_requests')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      if (historyQuery.docs.isEmpty) {
        // Return default times for new users
        return _getDefaultPickupTimes();
      }

      // Analyze patterns from history
      final pickupTimes = historyQuery.docs
          .map((doc) {
            final data = doc.data();
            final createdAt = data['createdAt'] as Timestamp?;
            return createdAt?.toDate();
          })
          .whereType<DateTime>()
          .toList();

      return _analyzePickupPatterns(pickupTimes);
    } catch (e) {
      debugPrint('Error predicting pickup times: $e');
      return _getDefaultPickupTimes();
    }
  }

  /// Suggests optimal pickup times based on various factors
  Future<List<Map<String, dynamic>>> getSmartPickupSuggestions(
    String userId,
    String collectorId,
  ) async {
    try {
      final suggestions = <Map<String, dynamic>>[];

      // Get collector's availability
      final collectorDoc = await _firestore
          .collection('collectors')
          .doc(collectorId)
          .get();

      if (!collectorDoc.exists) {
        return _getDefaultSuggestions();
      }

      final collectorData = collectorDoc.data()!;
      final workingHours =
          collectorData['workingHours'] as Map<String, dynamic>? ?? {};

      // Get current time and next 7 days
      final now = DateTime.now();
      final nextWeek = now.add(const Duration(days: 7));

      for (
        var date = now;
        date.isBefore(nextWeek);
        date = date.add(const Duration(days: 1))
      ) {
        final dayOfWeek = DateFormat('EEEE').format(date).toLowerCase();

        if (workingHours.containsKey(dayOfWeek)) {
          final daySchedule = workingHours[dayOfWeek] as Map<String, dynamic>;
          final isAvailable = daySchedule['available'] as bool? ?? true;

          if (isAvailable) {
            final startTime = _parseTimeString(
              daySchedule['startTime'] ?? '09:00',
            );
            final endTime = _parseTimeString(daySchedule['endTime'] ?? '17:00');

            if (startTime != null && endTime != null) {
              // Create time slots every 2 hours
              var currentSlot = DateTime(
                date.year,
                date.month,
                date.day,
                startTime.hour,
                startTime.minute,
              );

              final endSlot = DateTime(
                date.year,
                date.month,
                date.day,
                endTime.hour,
                endTime.minute,
              );

              while (currentSlot.isBefore(endSlot)) {
                if (currentSlot.isAfter(now)) {
                  final score = await _calculateTimeSlotScore(
                    userId,
                    collectorId,
                    currentSlot,
                  );

                  suggestions.add({
                    'dateTime': currentSlot,
                    'score': score,
                    'reason': _getScoreReason(score),
                    'isPeakTime': _isPeakTime(currentSlot),
                    'weatherFactor': await _getWeatherFactor(currentSlot),
                  });
                }

                currentSlot = currentSlot.add(const Duration(hours: 2));
              }
            }
          }
        }
      }

      // Sort by score (highest first) and return top suggestions
      suggestions.sort(
        (a, b) => (b['score'] as double).compareTo(a['score'] as double),
      );
      return suggestions.take(10).toList();
    } catch (e) {
      debugPrint('Error getting smart suggestions: $e');
      return _getDefaultSuggestions();
    }
  }

  /// Calculates a score for a pickup time slot (0-100)
  Future<double> _calculateTimeSlotScore(
    String userId,
    String collectorId,
    DateTime slotTime,
  ) async {
    double score = 50.0; // Base score

    try {
      // Factor 1: User's historical preferences
      final userPreferenceScore = await _calculateUserPreferenceScore(
        userId,
        slotTime,
      );
      score += userPreferenceScore * 0.3;

      // Factor 2: Collector workload
      final workloadScore = await _calculateWorkloadScore(
        collectorId,
        slotTime,
      );
      score += workloadScore * 0.25;

      // Factor 3: Time of day preference (avoid rush hours)
      final timePreferenceScore = _calculateTimePreferenceScore(slotTime);
      score += timePreferenceScore * 0.2;

      // Factor 4: Weather consideration
      final weatherScore = await _calculateWeatherScore(slotTime);
      score += weatherScore * 0.15;

      // Factor 5: Proximity to other pickups (efficiency)
      final efficiencyScore = await _calculateEfficiencyScore(
        collectorId,
        slotTime,
      );
      score += efficiencyScore * 0.1;

      // Ensure score is within bounds
      return score.clamp(0.0, 100.0);
    } catch (e) {
      debugPrint('Error calculating time slot score: $e');
      return 50.0; // Return neutral score on error
    }
  }

  Future<double> _calculateUserPreferenceScore(
    String userId,
    DateTime slotTime,
  ) async {
    try {
      final historyQuery = await _firestore
          .collection('pickup_requests')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .get();

      if (historyQuery.docs.isEmpty) return 0.0;

      final pickupHours = historyQuery.docs.map((doc) {
        final data = doc.data();
        final createdAt = data['createdAt'] as Timestamp?;
        return createdAt?.toDate().hour ?? 12;
      }).toList();

      final targetHour = slotTime.hour;
      final avgPreferredHour =
          pickupHours.reduce((a, b) => a + b) / pickupHours.length;

      // Score based on how close to preferred hour
      final hourDifference = (targetHour - avgPreferredHour).abs();
      return (20 - hourDifference).clamp(0.0, 20.0);
    } catch (e) {
      return 0.0;
    }
  }

  Future<double> _calculateWorkloadScore(
    String collectorId,
    DateTime slotTime,
  ) async {
    try {
      // Check how many pickups the collector has in this time slot
      final startTime = slotTime;
      final endTime = slotTime.add(const Duration(hours: 2));

      final existingPickups = await _firestore
          .collection('pickup_requests')
          .where('collectorId', isEqualTo: collectorId)
          .where(
            'scheduledTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startTime),
          )
          .where('scheduledTime', isLessThan: Timestamp.fromDate(endTime))
          .where('status', whereIn: ['scheduled', 'in_progress'])
          .get();

      final pickupCount = existingPickups.docs.length;

      // Prefer slots with fewer pickups (max 3 pickups per 2-hour slot)
      if (pickupCount >= 3) return -15.0;
      if (pickupCount >= 2) return -5.0;
      if (pickupCount >= 1) return 5.0;
      return 15.0; // Empty slot preferred
    } catch (e) {
      return 0.0;
    }
  }

  double _calculateTimePreferenceScore(DateTime slotTime) {
    final hour = slotTime.hour;

    // Prefer morning (9-11) and afternoon (14-16) slots
    if ((hour >= 9 && hour <= 11) || (hour >= 14 && hour <= 16)) {
      return 10.0;
    }

    // Avoid rush hours and very early/late times
    if ((hour >= 7 && hour <= 8) || (hour >= 17 && hour <= 19)) {
      return -5.0;
    }

    return 0.0;
  }

  Future<double> _calculateWeatherScore(DateTime slotTime) async {
    // For now, prefer daytime hours (assuming better weather)
    // In a real implementation, integrate with weather API
    final hour = slotTime.hour;
    if (hour >= 8 && hour <= 18) {
      return 5.0;
    }
    return -5.0;
  }

  Future<double> _calculateEfficiencyScore(
    String collectorId,
    DateTime slotTime,
  ) async {
    // Check if there are nearby pickups that could be combined
    // This is a simplified version - in reality would use location data
    return 0.0; // Placeholder
  }

  List<DateTime> _getDefaultPickupTimes() {
    final now = DateTime.now();
    return [
      now.add(const Duration(days: 1, hours: 10)),
      now.add(const Duration(days: 1, hours: 14)),
      now.add(const Duration(days: 2, hours: 10)),
      now.add(const Duration(days: 2, hours: 14)),
      now.add(const Duration(days: 3, hours: 10)),
    ];
  }

  List<Map<String, dynamic>> _getDefaultSuggestions() {
    final now = DateTime.now();
    return [
      {
        'dateTime': now.add(const Duration(days: 1, hours: 10)),
        'score': 75.0,
        'reason': 'Morning slot - good availability',
        'isPeakTime': false,
        'weatherFactor': 'good',
      },
      {
        'dateTime': now.add(const Duration(days: 1, hours: 14)),
        'score': 70.0,
        'reason': 'Afternoon slot - moderate availability',
        'isPeakTime': false,
        'weatherFactor': 'good',
      },
    ];
  }

  List<DateTime> _analyzePickupPatterns(List<DateTime> pickupTimes) {
    if (pickupTimes.isEmpty) return _getDefaultPickupTimes();

    // Find most common day of week and time
    final dayOfWeekCounts = <int, int>{};
    final hourCounts = <int, int>{};

    for (final time in pickupTimes) {
      dayOfWeekCounts[time.weekday] = (dayOfWeekCounts[time.weekday] ?? 0) + 1;
      hourCounts[time.hour] = (hourCounts[time.hour] ?? 0) + 1;
    }

    final preferredDay = dayOfWeekCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    final preferredHour = hourCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    // Generate suggestions based on patterns
    final suggestions = <DateTime>[];
    final now = DateTime.now();

    for (int i = 1; i <= 7; i++) {
      final candidateDate = now.add(Duration(days: i));
      if (candidateDate.weekday == preferredDay) {
        suggestions.add(
          DateTime(
            candidateDate.year,
            candidateDate.month,
            candidateDate.day,
            preferredHour,
            0,
          ),
        );
      }
    }

    return suggestions.take(5).toList();
  }

  TimeOfDay? _parseTimeString(String timeString) {
    try {
      final parts = timeString.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (e) {
      debugPrint('Error parsing time string: $timeString');
    }
    return null;
  }

  String _getScoreReason(double score) {
    if (score >= 80) return 'Excellent choice - optimal time';
    if (score >= 70) return 'Very good - high preference match';
    if (score >= 60) return 'Good - suitable time';
    if (score >= 50) return 'Fair - acceptable time';
    return 'Poor - consider alternative times';
  }

  bool _isPeakTime(DateTime time) {
    final hour = time.hour;
    return (hour >= 17 && hour <= 19) || (hour >= 7 && hour <= 9);
  }

  Future<String> _getWeatherFactor(DateTime time) async {
    // Placeholder - in real implementation, integrate with weather API
    final hour = time.hour;
    if (hour >= 8 && hour <= 18) return 'good';
    return 'fair';
  }
}
