import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for user's wishlist/favorites
class FavoriteItem {
  final String id;
  final String userId;
  final String itemId;
  final String itemName;
  final double itemPrice;
  final String itemImageUrl;
  final String category;
  final String sellerId;
  final DateTime addedAt;
  final String? notes; // User's personal notes about the item
  final bool isNotified; // Whether user wants price drop notifications

  FavoriteItem({
    required this.id,
    required this.userId,
    required this.itemId,
    required this.itemName,
    required this.itemPrice,
    required this.itemImageUrl,
    required this.category,
    required this.sellerId,
    required this.addedAt,
    this.notes,
    this.isNotified = false,
  });

  /// Create from Firestore document
  factory FavoriteItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FavoriteItem(
      id: doc.id,
      userId: data['userId'] ?? '',
      itemId: data['itemId'] ?? '',
      itemName: data['itemName'] ?? '',
      itemPrice: (data['itemPrice'] ?? 0.0).toDouble(),
      itemImageUrl: data['itemImageUrl'] ?? '',
      category: data['category'] ?? '',
      sellerId: data['sellerId'] ?? '',
      addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: data['notes'],
      isNotified: data['isNotified'] ?? false,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'itemId': itemId,
      'itemName': itemName,
      'itemPrice': itemPrice,
      'itemImageUrl': itemImageUrl,
      'category': category,
      'sellerId': sellerId,
      'addedAt': Timestamp.fromDate(addedAt),
      'notes': notes,
      'isNotified': isNotified,
    };
  }

  /// Copy with modifications
  FavoriteItem copyWith({
    String? id,
    String? userId,
    String? itemId,
    String? itemName,
    double? itemPrice,
    String? itemImageUrl,
    String? category,
    String? sellerId,
    DateTime? addedAt,
    String? notes,
    bool? isNotified,
  }) {
    return FavoriteItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      itemPrice: itemPrice ?? this.itemPrice,
      itemImageUrl: itemImageUrl ?? this.itemImageUrl,
      category: category ?? this.category,
      sellerId: sellerId ?? this.sellerId,
      addedAt: addedAt ?? this.addedAt,
      notes: notes ?? this.notes,
      isNotified: isNotified ?? this.isNotified,
    );
  }

  @override
  String toString() {
    return 'FavoriteItem(id: $id, itemId: $itemId, name: $itemName)';
  }
}
