import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/mobile_app/constants/app_constants.dart';

/// Enhanced marketplace item model with condition rating and shipping methods
class MarketplaceItem {
  final String id;
  final String sellerId;
  final String sellerName;
  final double sellerRating;
  final String name;
  final String description;
  final String category;
  final double price;
  final String condition; // new, like-new, good, fair, poor
  final List<String> imageUrls;
  final String location;
  final bool isActive;
  final List<String>
  shippingMethods; // pickup, delivery, courier, local-meeting
  final bool shippingAvailable;
  final double? shippingCost;
  final int quantity;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int viewCount;
  final int favoriteCount;
  final List<String> tags;
  final Map<String, dynamic>? metadata; // Additional custom fields

  MarketplaceItem({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    this.sellerRating = 0.0,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.condition,
    required this.imageUrls,
    required this.location,
    this.isActive = true,
    required this.shippingMethods,
    this.shippingAvailable = false,
    this.shippingCost,
    this.quantity = 1,
    required this.createdAt,
    required this.updatedAt,
    this.viewCount = 0,
    this.favoriteCount = 0,
    this.tags = const [],
    this.metadata,
  });

  /// Create from Firestore document
  factory MarketplaceItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MarketplaceItem(
      id: doc.id,
      sellerId: data['sellerId'] ?? '',
      sellerName: data['sellerName'] ?? 'Unknown',
      sellerRating: (data['sellerRating'] ?? 0.0).toDouble(),
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      condition: data['condition'] ?? AppConstants.itemConditions.first,
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      location: data['location'] ?? '',
      isActive: data['isActive'] ?? true,
      shippingMethods: List<String>.from(data['shippingMethods'] ?? []),
      shippingAvailable: data['shippingAvailable'] ?? false,
      shippingCost: (data['shippingCost'] as num?)?.toDouble(),
      quantity: data['quantity'] ?? 1,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      viewCount: data['viewCount'] ?? 0,
      favoriteCount: data['favoriteCount'] ?? 0,
      tags: List<String>.from(data['tags'] ?? []),
      metadata: data['metadata'],
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'sellerId': sellerId,
      'sellerName': sellerName,
      'sellerRating': sellerRating,
      'name': name,
      'description': description,
      'category': category,
      'price': price,
      'condition': condition,
      'imageUrls': imageUrls,
      'location': location,
      'isActive': isActive,
      'shippingMethods': shippingMethods,
      'shippingAvailable': shippingAvailable,
      'shippingCost': shippingCost,
      'quantity': quantity,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'viewCount': viewCount,
      'favoriteCount': favoriteCount,
      'tags': tags,
      'metadata': metadata,
    };
  }

  /// Create a copy with modifications
  MarketplaceItem copyWith({
    String? id,
    String? sellerId,
    String? sellerName,
    double? sellerRating,
    String? name,
    String? description,
    String? category,
    double? price,
    String? condition,
    List<String>? imageUrls,
    String? location,
    bool? isActive,
    List<String>? shippingMethods,
    bool? shippingAvailable,
    double? shippingCost,
    int? quantity,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? viewCount,
    int? favoriteCount,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) {
    return MarketplaceItem(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      sellerRating: sellerRating ?? this.sellerRating,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      price: price ?? this.price,
      condition: condition ?? this.condition,
      imageUrls: imageUrls ?? this.imageUrls,
      location: location ?? this.location,
      isActive: isActive ?? this.isActive,
      shippingMethods: shippingMethods ?? this.shippingMethods,
      shippingAvailable: shippingAvailable ?? this.shippingAvailable,
      shippingCost: shippingCost ?? this.shippingCost,
      quantity: quantity ?? this.quantity,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      viewCount: viewCount ?? this.viewCount,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Validate condition value
  static bool isValidCondition(String condition) {
    return AppConstants.itemConditions.contains(condition);
  }

  /// Validate shipping method
  static bool isValidShippingMethod(String method) {
    return AppConstants.shippingMethods.contains(method);
  }

  /// Get condition display name with emoji
  String getConditionDisplay() {
    switch (condition) {
      case 'New':
        return '🆕 New';
      case 'Like New':
        return '✨ Like New';
      case 'Good':
        return '👍 Good';
      case 'Fair':
        return '😐 Fair';
      case 'Poor':
        return '⚠️ Poor';
      default:
        return condition;
    }
  }

  /// Get total price including shipping
  double getTotalPrice() {
    if (shippingAvailable && shippingCost != null) {
      return price + shippingCost!;
    }
    return price;
  }

  /// Check if item is recently posted (within 24 hours)
  bool isRecentlyPosted() {
    return DateTime.now().difference(createdAt).inHours < 24;
  }

  /// Get age of listing in hours
  int getListingAgeHours() {
    return DateTime.now().difference(createdAt).inHours;
  }

  @override
  String toString() {
    return 'MarketplaceItem(id: $id, name: $name, price: \$$price, condition: $condition)';
  }
}
