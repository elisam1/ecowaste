import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/mobile_app/constants/app_constants.dart';
import 'package:flutter_application_1/mobile_app/model/marketplace_item.dart';
import 'package:flutter_application_1/mobile_app/service/logging_service.dart';

/// Search filters for marketplace items
class MarketplaceSearchFilters {
  final String? searchQuery;
  final String? category;
  final double? minPrice;
  final double? maxPrice;
  final String? condition;
  final List<String>? locations;
  final double? maxDistance; // in km
  final String? sortBy; // 'price', 'newest', 'popular', 'rating'
  final bool? shippingAvailable;
  final DateTime? postedAfter;
  final DateTime? postedBefore;
  final int? minRating;

  MarketplaceSearchFilters({
    this.searchQuery,
    this.category,
    this.minPrice,
    this.maxPrice,
    this.condition,
    this.locations,
    this.maxDistance,
    this.sortBy,
    this.shippingAvailable,
    this.postedAfter,
    this.postedBefore,
    this.minRating,
  });

  bool hasFilters() {
    return searchQuery?.isNotEmpty == true ||
        category != null ||
        minPrice != null ||
        maxPrice != null ||
        condition != null ||
        locations != null ||
        maxDistance != null ||
        shippingAvailable != null ||
        postedAfter != null ||
        postedBefore != null ||
        minRating != null;
  }
}

/// Advanced search service for marketplace
class MarketplaceSearchService {
  static final _firestore = FirebaseFirestore.instance;

  /// Search marketplace items with advanced filters
  static Future<List<MarketplaceItem>> searchItems(
    MarketplaceSearchFilters filters,
  ) async {
    try {
      LoggingService.info('Searching marketplace with filters: $filters');

      Query query = _firestore
          .collection(AppConstants.collectionMarketplaceItems)
          .where('isActive', isEqualTo: true);

      // Category filter
      if (filters.category != null && filters.category != 'All') {
        query = query.where('category', isEqualTo: filters.category);
      }

      // Price range filter
      if (filters.minPrice != null) {
        query = query.where('price', isGreaterThanOrEqualTo: filters.minPrice);
      }
      if (filters.maxPrice != null) {
        query = query.where('price', isLessThanOrEqualTo: filters.maxPrice);
      }

      // Condition filter
      if (filters.condition != null) {
        query = query.where('condition', isEqualTo: filters.condition);
      }

      // Shipping availability filter
      if (filters.shippingAvailable != null) {
        query = query.where(
          'shippingAvailable',
          isEqualTo: filters.shippingAvailable,
        );
      }

      // Date range filter
      if (filters.postedAfter != null) {
        query = query.where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(filters.postedAfter!),
        );
      }
      if (filters.postedBefore != null) {
        query = query.where(
          'createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(filters.postedBefore!),
        );
      }

      // Minimum rating filter
      if (filters.minRating != null) {
        query = query.where(
          'sellerRating',
          isGreaterThanOrEqualTo: filters.minRating,
        );
      }

      // Sorting
      if (filters.sortBy != null) {
        switch (filters.sortBy) {
          case 'price':
            query = query.orderBy('price', descending: false);
            break;
          case 'price_desc':
            query = query.orderBy('price', descending: true);
            break;
          case 'newest':
            query = query.orderBy('createdAt', descending: true);
            break;
          case 'popular':
            query = query.orderBy('viewCount', descending: true);
            break;
          case 'rating':
            query = query.orderBy('sellerRating', descending: true);
            break;
          default:
            query = query.orderBy('createdAt', descending: true);
        }
      } else {
        query = query.orderBy('createdAt', descending: true);
      }

      // Limit results
      query = query.limit(AppConstants.marketplacePageSize);

      final snapshot = await query.get();
      final items = snapshot.docs
          .map((doc) => MarketplaceItem.fromFirestore(doc))
          .toList();

      // Client-side filtering for complex criteria
      List<MarketplaceItem> filtered = items;

      // Search query (full text search on client)
      if (filters.searchQuery?.isNotEmpty == true) {
        final query = filters.searchQuery!.toLowerCase();
        filtered = filtered.where((item) {
          return item.name.toLowerCase().contains(query) ||
              item.description.toLowerCase().contains(query) ||
              item.location.toLowerCase().contains(query) ||
              item.tags.any((tag) => tag.toLowerCase().contains(query));
        }).toList();
      }

      // Location filter
      if (filters.locations != null && filters.locations!.isNotEmpty) {
        filtered = filtered.where((item) {
          return filters.locations!.any(
            (location) =>
                item.location.toLowerCase().contains(location.toLowerCase()),
          );
        }).toList();
      }

      LoggingService.logDatabaseQuery(
        AppConstants.collectionMarketplaceItems,
        resultCount: filtered.length,
      );

      return filtered;
    } catch (e) {
      LoggingService.error('Error searching marketplace: $e');
      return [];
    }
  }

  /// Stream search results (for real-time updates)
  static Stream<List<MarketplaceItem>> streamSearchResults(
    MarketplaceSearchFilters filters,
  ) {
    try {
      Query query = _firestore
          .collection(AppConstants.collectionMarketplaceItems)
          .where('isActive', isEqualTo: true);

      if (filters.category != null && filters.category != 'All') {
        query = query.where('category', isEqualTo: filters.category);
      }

      if (filters.sortBy != null) {
        switch (filters.sortBy) {
          case 'newest':
            query = query.orderBy('createdAt', descending: true);
            break;
          case 'price':
            query = query.orderBy('price', descending: false);
            break;
          case 'popular':
            query = query.orderBy('viewCount', descending: true);
            break;
          default:
            query = query.orderBy('createdAt', descending: true);
        }
      }

      return query
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => MarketplaceItem.fromFirestore(doc))
                .toList();
          })
          .handleError((e) {
            LoggingService.error('Error streaming search results: $e');
          });
    } catch (e) {
      LoggingService.error('Error setting up search stream: $e');
      return Stream.value([]);
    }
  }

  /// Get trending items
  static Future<List<MarketplaceItem>> getTrendingItems({
    int limit = 10,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.collectionMarketplaceItems)
          .where('isActive', isEqualTo: true)
          .orderBy('viewCount', descending: true)
          .orderBy('favoriteCount', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => MarketplaceItem.fromFirestore(doc))
          .toList();
    } catch (e) {
      LoggingService.error('Error getting trending items: $e');
      return [];
    }
  }

  /// Get recently added items
  static Future<List<MarketplaceItem>> getRecentItems({
    int limit = 20,
    int hoursAgo = 24,
  }) async {
    try {
      final cutoffTime = DateTime.now().subtract(Duration(hours: hoursAgo));

      final snapshot = await _firestore
          .collection(AppConstants.collectionMarketplaceItems)
          .where('isActive', isEqualTo: true)
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(cutoffTime),
          )
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => MarketplaceItem.fromFirestore(doc))
          .toList();
    } catch (e) {
      LoggingService.error('Error getting recent items: $e');
      return [];
    }
  }

  /// Get items by seller with rating threshold
  static Future<List<MarketplaceItem>> getSellerItems(
    String sellerId, {
    double minRating = 0,
    int limit = 20,
  }) async {
    try {
      Query query = _firestore
          .collection(AppConstants.collectionMarketplaceItems)
          .where('sellerId', isEqualTo: sellerId)
          .where('isActive', isEqualTo: true);

      if (minRating > 0) {
        query = query.where('sellerRating', isGreaterThanOrEqualTo: minRating);
      }

      query = query.orderBy('createdAt', descending: true).limit(limit);

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => MarketplaceItem.fromFirestore(doc))
          .toList();
    } catch (e) {
      LoggingService.error('Error getting seller items: $e');
      return [];
    }
  }

  /// Increment view count
  static Future<void> incrementViewCount(String itemId) async {
    try {
      await _firestore
          .collection(AppConstants.collectionMarketplaceItems)
          .doc(itemId)
          .update({'viewCount': FieldValue.increment(1)});
    } catch (e) {
      LoggingService.warning('Error incrementing view count: $e');
    }
  }

  /// Get related items (similar category/price range)
  static Future<List<MarketplaceItem>> getRelatedItems(
    MarketplaceItem item, {
    int limit = 10,
  }) async {
    try {
      final filters = MarketplaceSearchFilters(
        category: item.category,
        minPrice: item.price * 0.7,
        maxPrice: item.price * 1.3,
      );

      final results = await searchItems(filters);
      // Exclude the current item
      return results.where((i) => i.id != item.id).take(limit).toList();
    } catch (e) {
      LoggingService.error('Error getting related items: $e');
      return [];
    }
  }

  /// Apply pagination
  static Future<List<MarketplaceItem>> searchWithPagination(
    MarketplaceSearchFilters filters,
    int pageNumber,
  ) async {
    try {
      final pageSize = AppConstants.marketplacePageSize;
      final offset = (pageNumber - 1) * pageSize;

      Query query = _firestore
          .collection(AppConstants.collectionMarketplaceItems)
          .where('isActive', isEqualTo: true);

      if (filters.category != null && filters.category != 'All') {
        query = query.where('category', isEqualTo: filters.category);
      }

      query = query.orderBy('createdAt', descending: true);

      // Note: Firestore offset is expensive, consider using document cursors
      final snapshot = await query.limit(offset + pageSize).get();

      return snapshot.docs
          .skip(offset)
          .take(pageSize)
          .map((doc) => MarketplaceItem.fromFirestore(doc))
          .toList();
    } catch (e) {
      LoggingService.error('Error searching with pagination: $e');
      return [];
    }
  }
}
