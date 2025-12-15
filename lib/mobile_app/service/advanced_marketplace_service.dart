import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'gamification_engine.dart';

class AdvancedMarketplaceService {
  static final AdvancedMarketplaceService _instance =
      AdvancedMarketplaceService._internal();
  factory AdvancedMarketplaceService() => _instance;
  AdvancedMarketplaceService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Marketplace categories
  static const List<String> categories = [
    'Electronics',
    'Furniture',
    'Clothing',
    'Books',
    'Sports Equipment',
    'Home & Garden',
    'Vehicles',
    'Collectibles',
    'Other',
  ];

  // Listing conditions
  static const List<String> conditions = [
    'New',
    'Like New',
    'Good',
    'Fair',
    'Poor',
  ];

  /// Create an advanced marketplace listing
  Future<String?> createListing({
    required String title,
    required String description,
    required double price,
    required String category,
    required String condition,
    required List<String> imageUrls,
    required Position location,
    bool isAuction = false,
    double? startingBid,
    DateTime? auctionEndTime,
    bool allowOffers = true,
    Map<String, dynamic>? specifications,
    List<String>? tags,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final listingId = _firestore.collection('marketplace_listings').doc().id;

      final listingData = {
        'id': listingId,
        'sellerId': user.uid,
        'title': title,
        'description': description,
        'price': price,
        'category': category,
        'condition': condition,
        'imageUrls': imageUrls,
        'location': GeoPoint(location.latitude, location.longitude),
        'isAuction': isAuction,
        'startingBid': startingBid,
        'currentBid': startingBid ?? 0,
        'auctionEndTime': auctionEndTime != null
            ? Timestamp.fromDate(auctionEndTime)
            : null,
        'highestBidderId': null,
        'allowOffers': allowOffers,
        'specifications': specifications,
        'tags': tags ?? [],
        'status': 'active',
        'views': 0,
        'favorites': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('marketplace_listings')
          .doc(listingId)
          .set(listingData);

      // Award gamification points
      try {
        await GamificationEngine().awardPoints(user.uid, 'marketplace_listing');
      } catch (e) {
        debugPrint('Error awarding gamification points: $e');
      }

      return listingId;
    } catch (e) {
      debugPrint('Error creating listing: $e');
      return null;
    }
  }

  /// Place a bid on an auction listing
  Future<bool> placeBid(String listingId, double bidAmount) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final listingRef = _firestore
          .collection('marketplace_listings')
          .doc(listingId);
      final listingDoc = await listingRef.get();

      if (!listingDoc.exists) return false;

      final listing = listingDoc.data()!;
      final currentBid = listing['currentBid'] ?? 0.0;
      final auctionEndTime = listing['auctionEndTime'] as Timestamp?;

      // Validate bid
      if (bidAmount <= currentBid) return false;
      if (auctionEndTime != null &&
          auctionEndTime.toDate().isBefore(DateTime.now()))
        return false;
      if (listing['sellerId'] == user.uid)
        return false; // Can't bid on own listing

      // Update listing with new bid
      await listingRef.update({
        'currentBid': bidAmount,
        'highestBidderId': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Record bid
      await _firestore.collection('marketplace_bids').add({
        'listingId': listingId,
        'bidderId': user.uid,
        'bidAmount': bidAmount,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Notify previous highest bidder if any
      if (listing['highestBidderId'] != null) {
        await _sendBidNotification(
          listing['highestBidderId'],
          listingId,
          'outbid',
        );
      }

      // Notify seller
      await _sendBidNotification(listing['sellerId'], listingId, 'new_bid');

      return true;
    } catch (e) {
      debugPrint('Error placing bid: $e');
      return false;
    }
  }

  /// Make an offer on a listing
  Future<bool> makeOffer(
    String listingId,
    double offerAmount,
    String message,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final offerId = _firestore.collection('marketplace_offers').doc().id;

      await _firestore.collection('marketplace_offers').doc(offerId).set({
        'id': offerId,
        'listingId': listingId,
        'buyerId': user.uid,
        'offerAmount': offerAmount,
        'message': message,
        'status': 'pending', // pending, accepted, rejected, countered
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Notify seller
      final listing = await _firestore
          .collection('marketplace_listings')
          .doc(listingId)
          .get();
      if (listing.exists) {
        await _sendOfferNotification(
          listing['sellerId'],
          listingId,
          'new_offer',
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error making offer: $e');
      return false;
    }
  }

  /// Respond to an offer
  Future<bool> respondToOffer(
    String offerId,
    String response, {
    double? counterOffer,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final offerRef = _firestore.collection('marketplace_offers').doc(offerId);
      final offerDoc = await offerRef.get();

      if (!offerDoc.exists) return false;

      final offer = offerDoc.data()!;
      final listingId = offer['listingId'];

      // Verify user is the seller
      final listing = await _firestore
          .collection('marketplace_listings')
          .doc(listingId)
          .get();
      if (!listing.exists || listing['sellerId'] != user.uid) return false;

      final updateData = {
        'status': response,
        'respondedAt': FieldValue.serverTimestamp(),
      };

      if (response == 'countered' && counterOffer != null) {
        updateData['counterOffer'] = counterOffer;
      }

      await offerRef.update(updateData);

      // Notify buyer
      await _sendOfferNotification(offer['buyerId'], listingId, response);

      return true;
    } catch (e) {
      debugPrint('Error responding to offer: $e');
      return false;
    }
  }

  /// Advanced search for listings
  Future<List<Map<String, dynamic>>> searchListings({
    String? query,
    String? category,
    String? condition,
    double? minPrice,
    double? maxPrice,
    Position? userLocation,
    double? radiusKm,
    String?
    sortBy, // 'price_asc', 'price_desc', 'distance', 'newest', 'popular'
    bool? auctionsOnly,
    List<String>? tags,
  }) async {
    try {
      Query queryRef = _firestore
          .collection('marketplace_listings')
          .where('status', isEqualTo: 'active');

      // Apply filters
      if (category != null && category.isNotEmpty) {
        queryRef = queryRef.where('category', isEqualTo: category);
      }

      if (condition != null && condition.isNotEmpty) {
        queryRef = queryRef.where('condition', isEqualTo: condition);
      }

      if (auctionsOnly == true) {
        queryRef = queryRef.where('isAuction', isEqualTo: true);
      }

      // Get results
      QuerySnapshot snapshot = await queryRef.get();

      List<Map<String, dynamic>> listings = [];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Apply client-side filters
        if (minPrice != null && (data['price'] as double) < minPrice) continue;
        if (maxPrice != null && (data['price'] as double) > maxPrice) continue;

        // Distance filter
        if (userLocation != null && radiusKm != null) {
          final listingLocation = data['location'] as GeoPoint;
          final distance = _calculateDistance(
            userLocation.latitude,
            userLocation.longitude,
            listingLocation.latitude,
            listingLocation.longitude,
          );

          if (distance > radiusKm) continue;
          data['distance'] = distance;
        }

        // Text search
        if (query != null && query.isNotEmpty) {
          final title = data['title'].toString().toLowerCase();
          final description = data['description'].toString().toLowerCase();
          final searchQuery = query.toLowerCase();

          if (!title.contains(searchQuery) &&
              !description.contains(searchQuery)) {
            continue;
          }
        }

        // Tags filter
        if (tags != null && tags.isNotEmpty) {
          final listingTags = List<String>.from(data['tags'] ?? []);
          if (!tags.any((tag) => listingTags.contains(tag))) continue;
        }

        listings.add(data);
      }

      // Sort results
      listings.sort((a, b) {
        switch (sortBy) {
          case 'price_asc':
            return (a['price'] as double).compareTo(b['price'] as double);
          case 'price_desc':
            return (b['price'] as double).compareTo(a['price'] as double);
          case 'distance':
            final aDist = a['distance'] as double?;
            final bDist = b['distance'] as double?;
            if (aDist == null && bDist == null) return 0;
            if (aDist == null) return 1;
            if (bDist == null) return -1;
            return aDist.compareTo(bDist);
          case 'popular':
            return (b['views'] as int).compareTo(a['views'] as int);
          case 'newest':
          default:
            final aTime = a['createdAt'] as Timestamp?;
            final bTime = b['createdAt'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
        }
      });

      return listings;
    } catch (e) {
      debugPrint('Error searching listings: $e');
      return [];
    }
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // km

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) => degrees * pi / 180;

  /// Add listing to favorites
  Future<bool> toggleFavorite(String listingId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final favoriteRef = _firestore
          .collection('user_favorites')
          .doc('${user.uid}_$listingId');

      final favoriteDoc = await favoriteRef.get();

      if (favoriteDoc.exists) {
        // Remove from favorites
        await favoriteRef.delete();

        // Decrement favorite count
        await _firestore
            .collection('marketplace_listings')
            .doc(listingId)
            .update({'favorites': FieldValue.increment(-1)});

        return false; // Not favorited anymore
      } else {
        // Add to favorites
        await favoriteRef.set({
          'userId': user.uid,
          'listingId': listingId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Increment favorite count
        await _firestore
            .collection('marketplace_listings')
            .doc(listingId)
            .update({'favorites': FieldValue.increment(1)});

        return true; // Now favorited
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      return false;
    }
  }

  /// Get user's favorite listings
  Future<List<Map<String, dynamic>>> getFavoriteListings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final favoritesQuery = await _firestore
          .collection('user_favorites')
          .where('userId', isEqualTo: user.uid)
          .get();

      final listingIds = favoritesQuery.docs
          .map((doc) => doc['listingId'] as String)
          .toList();

      if (listingIds.isEmpty) return [];

      final listings = <Map<String, dynamic>>[];

      // Get listings in batches to avoid Firestore limits
      for (int i = 0; i < listingIds.length; i += 10) {
        final batch = listingIds.sublist(
          i,
          i + 10 > listingIds.length ? listingIds.length : i + 10,
        );

        for (final listingId in batch) {
          final listingDoc = await _firestore
              .collection('marketplace_listings')
              .doc(listingId)
              .get();
          if (listingDoc.exists) {
            listings.add(listingDoc.data()!);
          }
        }
      }

      return listings;
    } catch (e) {
      debugPrint('Error getting favorite listings: $e');
      return [];
    }
  }

  /// Submit a review for a completed transaction
  Future<bool> submitReview(
    String transactionId, {
    required int rating,
    String? comment,
    List<String>? photos,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Get transaction details
      final transactionDoc = await _firestore
          .collection('marketplace_transactions')
          .doc(transactionId)
          .get();
      if (!transactionDoc.exists) return false;

      final transaction = transactionDoc.data()!;
      final buyerId = transaction['buyerId'];
      final sellerId = transaction['sellerId'];
      final listingId = transaction['listingId'];

      // Determine if user is buyer or seller
      final isBuyer = buyerId == user.uid;
      final isSeller = sellerId == user.uid;

      if (!isBuyer && !isSeller) return false;

      final reviewId = _firestore.collection('marketplace_reviews').doc().id;

      await _firestore.collection('marketplace_reviews').doc(reviewId).set({
        'id': reviewId,
        'transactionId': transactionId,
        'listingId': listingId,
        'reviewerId': user.uid,
        'revieweeId': isBuyer ? sellerId : buyerId,
        'rating': rating,
        'comment': comment,
        'photos': photos ?? [],
        'reviewType': isBuyer ? 'seller_review' : 'buyer_review',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update average rating for the reviewee
      await _updateUserRating(isBuyer ? sellerId : buyerId);

      return true;
    } catch (e) {
      debugPrint('Error submitting review: $e');
      return false;
    }
  }

  Future<void> _updateUserRating(String userId) async {
    try {
      final reviewsQuery = await _firestore
          .collection('marketplace_reviews')
          .where('revieweeId', isEqualTo: userId)
          .get();

      if (reviewsQuery.docs.isEmpty) return;

      double totalRating = 0;
      for (final doc in reviewsQuery.docs) {
        totalRating += doc['rating'] as int;
      }

      final averageRating = totalRating / reviewsQuery.docs.length;

      await _firestore.collection('users').doc(userId).update({
        'marketplaceRating': averageRating,
        'totalReviews': reviewsQuery.docs.length,
      });
    } catch (e) {
      debugPrint('Error updating user rating: $e');
    }
  }

  /// Get reviews for a user
  Future<List<Map<String, dynamic>>> getUserReviews(
    String userId, {
    int limit = 10,
  }) async {
    try {
      final query = await _firestore
          .collection('marketplace_reviews')
          .where('revieweeId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final reviews = <Map<String, dynamic>>[];

      for (final doc in query.docs) {
        final data = doc.data();

        // Get reviewer info
        final reviewerDoc = await _firestore
            .collection('users')
            .doc(data['reviewerId'])
            .get();
        final reviewerData = reviewerDoc.data();

        reviews.add({
          ...data,
          'reviewerName': reviewerData?['name'] ?? 'Anonymous',
          'reviewerAvatar': reviewerData?['avatarUrl'],
        });
      }

      return reviews;
    } catch (e) {
      debugPrint('Error getting user reviews: $e');
      return [];
    }
  }

  /// Report a listing
  Future<bool> reportListing(
    String listingId,
    String reason,
    String description,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      await _firestore.collection('marketplace_reports').add({
        'listingId': listingId,
        'reporterId': user.uid,
        'reason': reason,
        'description': description,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Error reporting listing: $e');
      return false;
    }
  }

  /// Get marketplace analytics for user
  Future<Map<String, dynamic>> getMarketplaceAnalytics(String userId) async {
    try {
      // Get user's listings
      final listingsQuery = await _firestore
          .collection('marketplace_listings')
          .where('sellerId', isEqualTo: userId)
          .get();

      // Get user's purchases
      final purchasesQuery = await _firestore
          .collection('marketplace_transactions')
          .where('buyerId', isEqualTo: userId)
          .get();

      // Get user's sales
      final salesQuery = await _firestore
          .collection('marketplace_transactions')
          .where('sellerId', isEqualTo: userId)
          .get();

      int totalListings = listingsQuery.docs.length;
      int activeListings = listingsQuery.docs
          .where((doc) => doc['status'] == 'active')
          .length;
      int totalViews = 0;
      int totalFavorites = 0;

      for (final doc in listingsQuery.docs) {
        totalViews += doc['views'] as int? ?? 0;
        totalFavorites += doc['favorites'] as int? ?? 0;
      }

      double totalSalesValue = 0;
      int totalSalesCount = salesQuery.docs.length;

      for (final doc in salesQuery.docs) {
        totalSalesValue += doc['finalPrice'] as double? ?? 0;
      }

      double totalPurchaseValue = 0;
      int totalPurchasesCount = purchasesQuery.docs.length;

      for (final doc in purchasesQuery.docs) {
        totalPurchaseValue += doc['finalPrice'] as double? ?? 0;
      }

      return {
        'totalListings': totalListings,
        'activeListings': activeListings,
        'totalViews': totalViews,
        'totalFavorites': totalFavorites,
        'totalSalesValue': totalSalesValue,
        'totalSalesCount': totalSalesCount,
        'totalPurchaseValue': totalPurchaseValue,
        'totalPurchasesCount': totalPurchasesCount,
        'averageListingViews': totalListings > 0
            ? totalViews / totalListings
            : 0,
        'averageSalePrice': totalSalesCount > 0
            ? totalSalesValue / totalSalesCount
            : 0,
      };
    } catch (e) {
      debugPrint('Error getting marketplace analytics: $e');
      return {};
    }
  }

  Future<void> _sendBidNotification(
    String userId,
    String listingId,
    String type,
  ) async {
    // Implementation would integrate with your notification system
    debugPrint('Sending $type notification to $userId for listing $listingId');
  }

  Future<void> _sendOfferNotification(
    String userId,
    String listingId,
    String type,
  ) async {
    // Implementation would integrate with your notification system
    debugPrint('Sending $type notification to $userId for listing $listingId');
  }

  /// Increment view count for a listing
  Future<void> incrementViewCount(String listingId) async {
    try {
      await _firestore.collection('marketplace_listings').doc(listingId).update(
        {'views': FieldValue.increment(1)},
      );
    } catch (e) {
      debugPrint('Error incrementing view count: $e');
    }
  }
}

// Advanced Marketplace UI Components
class AdvancedSearchFilters extends StatefulWidget {
  final Function(Map<String, dynamic>) onFiltersChanged;

  const AdvancedSearchFilters({super.key, required this.onFiltersChanged});

  @override
  State<AdvancedSearchFilters> createState() => _AdvancedSearchFiltersState();
}

class _AdvancedSearchFiltersState extends State<AdvancedSearchFilters> {
  String? selectedCategory;
  String? selectedCondition;
  double? minPrice;
  double? maxPrice;
  double? radiusKm;
  bool auctionsOnly = false;
  List<String> selectedTags = [];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filters',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Category
          DropdownButtonFormField<String>(
            initialValue: selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            items: AdvancedMarketplaceService.categories.map((category) {
              return DropdownMenuItem(value: category, child: Text(category));
            }).toList(),
            onChanged: (value) {
              setState(() => selectedCategory = value);
              _notifyFiltersChanged();
            },
          ),

          const SizedBox(height: 12),

          // Condition
          DropdownButtonFormField<String>(
            initialValue: selectedCondition,
            decoration: const InputDecoration(
              labelText: 'Condition',
              border: OutlineInputBorder(),
            ),
            items: AdvancedMarketplaceService.conditions.map((condition) {
              return DropdownMenuItem(value: condition, child: Text(condition));
            }).toList(),
            onChanged: (value) {
              setState(() => selectedCondition = value);
              _notifyFiltersChanged();
            },
          ),

          const SizedBox(height: 12),

          // Price Range
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Min Price',
                    border: OutlineInputBorder(),
                    prefixText: '\$',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    minPrice = double.tryParse(value);
                    _notifyFiltersChanged();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Max Price',
                    border: OutlineInputBorder(),
                    prefixText: '\$',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    maxPrice = double.tryParse(value);
                    _notifyFiltersChanged();
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Distance
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Distance (km)',
              border: OutlineInputBorder(),
              hintText: 'Leave empty for no limit',
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              radiusKm = double.tryParse(value);
              _notifyFiltersChanged();
            },
          ),

          const SizedBox(height: 12),

          // Auctions Only
          SwitchListTile(
            title: const Text('Auctions Only'),
            value: auctionsOnly,
            onChanged: (value) {
              setState(() => auctionsOnly = value);
              _notifyFiltersChanged();
            },
          ),

          const SizedBox(height: 16),

          // Apply Filters Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _applyFilters,
              child: const Text('Apply Filters'),
            ),
          ),
        ],
      ),
    );
  }

  void _notifyFiltersChanged() {
    widget.onFiltersChanged({
      'category': selectedCategory,
      'condition': selectedCondition,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'radiusKm': radiusKm,
      'auctionsOnly': auctionsOnly,
      'tags': selectedTags,
    });
  }

  void _applyFilters() {
    _notifyFiltersChanged();
    Navigator.of(context).pop();
  }
}

class ListingCard extends StatelessWidget {
  final Map<String, dynamic> listing;
  final bool isFavorited;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onTap;

  const ListingCard({
    super.key,
    required this.listing,
    required this.isFavorited,
    required this.onFavoriteToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAuction = listing['isAuction'] as bool? ?? false;
    final currentBid = listing['currentBid'] as double? ?? 0;
    final price = listing['price'] as double? ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image:
                      (listing['imageUrls'] as List<dynamic>?)?.isNotEmpty ==
                          true
                      ? DecorationImage(
                          image: NetworkImage(listing['imageUrls'][0]),
                          fit: BoxFit.cover,
                        )
                      : null,
                  color: Colors.grey.shade200,
                ),
                child: (listing['imageUrls'] as List<dynamic>?)?.isEmpty == true
                    ? const Icon(Icons.image, color: Colors.grey)
                    : null,
              ),

              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            listing['title'] ?? '',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            isFavorited
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: isFavorited ? Colors.red : Colors.grey,
                          ),
                          onPressed: onFavoriteToggle,
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Text(
                      listing['description'] ?? '',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Text(
                          isAuction
                              ? 'Current Bid: \$${currentBid.toStringAsFixed(2)}'
                              : '\$${price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade600,
                          ),
                        ),

                        if (isAuction) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'AUCTION',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 4),

                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '2.3 km away', // Would calculate actual distance
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          listing['condition'] ?? '',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;

  const ReviewCard({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: review['reviewerAvatar'] != null
                      ? NetworkImage(review['reviewerAvatar'])
                      : null,
                  child: review['reviewerAvatar'] == null
                      ? Text(
                          (review['reviewerName'] as String?)?.substring(
                                0,
                                1,
                              ) ??
                              '?',
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review['reviewerName'] ?? 'Anonymous',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < (review['rating'] as int? ?? 0)
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 16,
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatTimestamp(review['createdAt'] as Timestamp?),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),

            if (review['comment'] != null &&
                (review['comment'] as String).isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(review['comment']),
            ],

            if ((review['photos'] as List<dynamic>?)?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: (review['photos'] as List).length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 80,
                      height: 80,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(review['photos'][index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final reviewTime = timestamp.toDate();
    final difference = now.difference(reviewTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
