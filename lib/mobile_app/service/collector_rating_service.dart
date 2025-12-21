import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CollectorRating {
  final String id;
  final String collectorId;
  final String userId;
  final String requestId;
  final int rating; // 1-5 stars
  final String? comment;
  final DateTime createdAt;
  final Map<String, int> categories; // punctuality, professionalism, handling

  CollectorRating({
    required this.id,
    required this.collectorId,
    required this.userId,
    required this.requestId,
    required this.rating,
    this.comment,
    required this.createdAt,
    required this.categories,
  });

  factory CollectorRating.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CollectorRating(
      id: doc.id,
      collectorId: data['collectorId'] ?? '',
      userId: data['userId'] ?? '',
      requestId: data['requestId'] ?? '',
      rating: data['rating'] ?? 0,
      comment: data['comment'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      categories: Map<String, int>.from(data['categories'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'collectorId': collectorId,
      'userId': userId,
      'requestId': requestId,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'categories': categories,
    };
  }
}

class CollectorRatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Submit a rating for a collector
  Future<void> submitRating({
    required String collectorId,
    required String userId,
    required String requestId,
    required int rating,
    required Map<String, int> categories,
    String? comment,
  }) async {
    try {
      // Check if user already rated this request
      final existingRating = await _firestore
          .collection('collector_ratings')
          .where('requestId', isEqualTo: requestId)
          .where('userId', isEqualTo: userId)
          .get();

      if (existingRating.docs.isNotEmpty) {
        throw Exception('You have already rated this pickup');
      }

      // Add the rating
      final ratingData = {
        'collectorId': collectorId,
        'userId': userId,
        'requestId': requestId,
        'rating': rating,
        'comment': comment,
        'categories': categories,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('collector_ratings').add(ratingData);

      // Update collector's average rating
      await _updateCollectorAverageRating(collectorId);

      debugPrint('Rating submitted successfully');
    } catch (e) {
      debugPrint('Error submitting rating: $e');
      rethrow;
    }
  }

  /// Update collector's average rating
  Future<void> _updateCollectorAverageRating(String collectorId) async {
    try {
      final ratings = await _firestore
          .collection('collector_ratings')
          .where('collectorId', isEqualTo: collectorId)
          .get();

      if (ratings.docs.isEmpty) return;

      double totalRating = 0;
      int count = ratings.docs.length;

      Map<String, double> categoryTotals = {
        'punctuality': 0,
        'professionalism': 0,
        'handling': 0,
      };

      for (var doc in ratings.docs) {
        final data = doc.data();
        totalRating += (data['rating'] ?? 0);

        final categories = data['categories'] as Map<String, dynamic>?;
        if (categories != null) {
          categoryTotals['punctuality'] =
              (categoryTotals['punctuality'] ?? 0) +
              (categories['punctuality'] ?? 0);
          categoryTotals['professionalism'] =
              (categoryTotals['professionalism'] ?? 0) +
              (categories['professionalism'] ?? 0);
          categoryTotals['handling'] =
              (categoryTotals['handling'] ?? 0) + (categories['handling'] ?? 0);
        }
      }

      final averageRating = totalRating / count;

      final categoryAverages = {
        'punctuality': categoryTotals['punctuality']! / count,
        'professionalism': categoryTotals['professionalism']! / count,
        'handling': categoryTotals['handling']! / count,
      };

      // Update collector document
      await _firestore.collection('collectors').doc(collectorId).set({
        'averageRating': averageRating,
        'totalRatings': count,
        'categoryRatings': categoryAverages,
        'lastRatingUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('Updated collector average rating: $averageRating');
    } catch (e) {
      debugPrint('Error updating average rating: $e');
    }
  }

  /// Get collector's ratings
  Future<List<CollectorRating>> getCollectorRatings(
    String collectorId, {
    int limit = 10,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('collector_ratings')
          .where('collectorId', isEqualTo: collectorId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => CollectorRating.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error fetching ratings: $e');
      return [];
    }
  }

  /// Get collector's rating summary
  Future<Map<String, dynamic>> getCollectorRatingSummary(
    String collectorId,
  ) async {
    try {
      final collectorDoc = await _firestore
          .collection('collectors')
          .doc(collectorId)
          .get();

      if (!collectorDoc.exists) {
        return {'averageRating': 0.0, 'totalRatings': 0, 'categoryRatings': {}};
      }

      final data = collectorDoc.data()!;
      return {
        'averageRating': data['averageRating'] ?? 0.0,
        'totalRatings': data['totalRatings'] ?? 0,
        'categoryRatings': data['categoryRatings'] ?? {},
      };
    } catch (e) {
      debugPrint('Error fetching rating summary: $e');
      return {'averageRating': 0.0, 'totalRatings': 0, 'categoryRatings': {}};
    }
  }

  /// Check if user has rated a specific pickup
  Future<bool> hasUserRatedPickup(String userId, String requestId) async {
    try {
      final snapshot = await _firestore
          .collection('collector_ratings')
          .where('userId', isEqualTo: userId)
          .where('requestId', isEqualTo: requestId)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking rating status: $e');
      return false;
    }
  }
}
