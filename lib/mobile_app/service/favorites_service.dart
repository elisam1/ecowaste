import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/mobile_app/constants/app_constants.dart';
import 'package:flutter_application_1/mobile_app/model/favorite_item.dart';
import 'package:flutter_application_1/mobile_app/service/logging_service.dart';

/// Service for managing user's wishlist and favorites
class FavoritesService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Add item to favorites
  static Future<bool> addToFavorites({
    required String itemId,
    required String itemName,
    required double itemPrice,
    required String itemImageUrl,
    required String category,
    required String sellerId,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        LoggingService.error('Cannot add to favorites: User not authenticated');
        return false;
      }

      // Check if already favorited
      final existing = await _firestore
          .collection(AppConstants.collectionUsers)
          .doc(userId)
          .collection('favorites')
          .where('itemId', isEqualTo: itemId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        LoggingService.info('Item already in favorites');
        return false;
      }

      final favorite = FavoriteItem(
        id: _firestore.collection('_').doc().id, // Generate ID
        userId: userId,
        itemId: itemId,
        itemName: itemName,
        itemPrice: itemPrice,
        itemImageUrl: itemImageUrl,
        category: category,
        sellerId: sellerId,
        addedAt: DateTime.now(),
      );

      await _firestore
          .collection(AppConstants.collectionUsers)
          .doc(userId)
          .collection('favorites')
          .doc(favorite.id)
          .set(favorite.toFirestore());

      // Increment favorite count on item
      await _incrementItemFavoriteCount(itemId);

      LoggingService.success('Item added to favorites: $itemName');
      return true;
    } catch (e) {
      LoggingService.error('Error adding to favorites: $e');
      return false;
    }
  }

  /// Remove item from favorites
  static Future<bool> removeFromFavorites(String itemId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final snapshot = await _firestore
          .collection(AppConstants.collectionUsers)
          .doc(userId)
          .collection('favorites')
          .where('itemId', isEqualTo: itemId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return false;

      await _firestore
          .collection(AppConstants.collectionUsers)
          .doc(userId)
          .collection('favorites')
          .doc(snapshot.docs.first.id)
          .delete();

      // Decrement favorite count on item
      await _decrementItemFavoriteCount(itemId);

      LoggingService.success('Item removed from favorites: $itemId');
      return true;
    } catch (e) {
      LoggingService.error('Error removing from favorites: $e');
      return false;
    }
  }

  /// Check if item is favorited
  static Future<bool> isFavorited(String itemId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final snapshot = await _firestore
          .collection(AppConstants.collectionUsers)
          .doc(userId)
          .collection('favorites')
          .where('itemId', isEqualTo: itemId)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      LoggingService.error('Error checking favorite status: $e');
      return false;
    }
  }

  /// Get all favorites for current user
  static Stream<List<FavoriteItem>> getFavorites() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      LoggingService.error('Cannot get favorites: User not authenticated');
      return Stream.value([]);
    }

    return _firestore
        .collection(AppConstants.collectionUsers)
        .doc(userId)
        .collection('favorites')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => FavoriteItem.fromFirestore(doc))
              .toList();
        })
        .handleError((e) {
          LoggingService.error('Error fetching favorites: $e');
        });
  }

  /// Get favorites by category
  static Stream<List<FavoriteItem>> getFavoritesByCategory(String category) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection(AppConstants.collectionUsers)
        .doc(userId)
        .collection('favorites')
        .where('category', isEqualTo: category)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => FavoriteItem.fromFirestore(doc))
              .toList();
        });
  }

  /// Get count of favorites
  static Future<int> getFavoritesCount() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return 0;

      final snapshot = await _firestore
          .collection(AppConstants.collectionUsers)
          .doc(userId)
          .collection('favorites')
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      LoggingService.error('Error getting favorites count: $e');
      return 0;
    }
  }

  /// Update favorite item notes
  static Future<bool> updateNotes(String favoriteId, String notes) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      await _firestore
          .collection(AppConstants.collectionUsers)
          .doc(userId)
          .collection('favorites')
          .doc(favoriteId)
          .update({'notes': notes});

      LoggingService.success('Favorite notes updated');
      return true;
    } catch (e) {
      LoggingService.error('Error updating favorite notes: $e');
      return false;
    }
  }

  /// Toggle price drop notification
  static Future<bool> togglePriceNotification(String favoriteId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final doc = await _firestore
          .collection(AppConstants.collectionUsers)
          .doc(userId)
          .collection('favorites')
          .doc(favoriteId)
          .get();

      if (!doc.exists) return false;

      final current = doc['isNotified'] ?? false;
      await doc.reference.update({'isNotified': !current});

      LoggingService.success('Price notification toggled: ${!current}');
      return true;
    } catch (e) {
      LoggingService.error('Error toggling price notification: $e');
      return false;
    }
  }

  /// Clear all favorites
  static Future<bool> clearAllFavorites() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final snapshot = await _firestore
          .collection(AppConstants.collectionUsers)
          .doc(userId)
          .collection('favorites')
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }

      LoggingService.success('All favorites cleared');
      return true;
    } catch (e) {
      LoggingService.error('Error clearing favorites: $e');
      return false;
    }
  }

  /// Get favorites with items from specific seller
  static Stream<List<FavoriteItem>> getFavoritesBySeller(String sellerId) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection(AppConstants.collectionUsers)
        .doc(userId)
        .collection('favorites')
        .where('sellerId', isEqualTo: sellerId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => FavoriteItem.fromFirestore(doc))
              .toList();
        });
  }

  /// Helper: Increment item favorite count
  static Future<void> _incrementItemFavoriteCount(String itemId) async {
    try {
      await _firestore
          .collection(AppConstants.collectionMarketplaceItems)
          .doc(itemId)
          .update({'favoriteCount': FieldValue.increment(1)});
    } catch (e) {
      LoggingService.warning('Error incrementing favorite count: $e');
    }
  }

  /// Helper: Decrement item favorite count
  static Future<void> _decrementItemFavoriteCount(String itemId) async {
    try {
      await _firestore
          .collection(AppConstants.collectionMarketplaceItems)
          .doc(itemId)
          .update({'favoriteCount': FieldValue.increment(-1)});
    } catch (e) {
      LoggingService.warning('Error decrementing favorite count: $e');
    }
  }
}
