// item_detail_screen.dart (UPDATED WITH SELLER FALLBACK LOGIC)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/mobile_app/ecomarketplace/buyerform.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ItemDetailScreen extends StatefulWidget {
  final String itemId;
  final Map<String, dynamic> itemData;

  const ItemDetailScreen({
    super.key,
    required this.itemId,
    required this.itemData,
  });

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  Map<String, dynamic>? ownerData;
  bool isLoadingOwner = true;
  bool isFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadOwnerData();
    _checkIfFavorite();
  }

  // 🔁 Updated here to try users first, then collectors
  Future<void> _loadOwnerData() async {
    final ownerId = widget.itemData['ownerId'];
    if (ownerId == null) {
      print('Missing ownerId');
      setState(() => isLoadingOwner = false);
      return;
    }

    try {
      // Try users collection first
      DocumentSnapshot<Map<String, dynamic>> ownerDoc = await FirebaseFirestore
          .instance
          .collection('users')
          .doc(ownerId)
          .get();

      if (ownerDoc.exists) {
        setState(() {
          ownerData = ownerDoc.data();
          isLoadingOwner = false;
        });
        return;
      }

      // Try collectors collection if user not found
      ownerDoc = await FirebaseFirestore.instance
          .collection('collectors')
          .doc(ownerId)
          .get();

      if (ownerDoc.exists) {
        setState(() {
          ownerData = ownerDoc.data();
          isLoadingOwner = false;
        });
      } else {
        setState(() => isLoadingOwner = false);
      }
    } catch (e) {
      setState(() => isLoadingOwner = false);
    }
  }

  Future<void> _checkIfFavorite() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final favoriteDoc = await FirebaseFirestore.instance
          .collection('favorites')
          .doc('${userId}_${widget.itemId}')
          .get();

      setState(() {
        isFavorite = favoriteDoc.exists;
      });
    } catch (e) {
      print('Error checking favorite status: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final favoriteRef = FirebaseFirestore.instance
          .collection('favorites')
          .doc('${userId}_${widget.itemId}');

      if (isFavorite) {
        await favoriteRef.delete();
        setState(() => isFavorite = false);
        _showSnackBar('Removed from favorites', Colors.orange);
      } else {
        await favoriteRef.set({
          'userId': userId,
          'itemId': widget.itemId,
          'createdAt': Timestamp.now(),
        });
        setState(() => isFavorite = true);
        _showSnackBar('Added to favorites', Colors.green);
      }
    } catch (e) {
      _showSnackBar('Failed to update favorites', Colors.red);
    }
  }

  Future<void> _buyItem() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final ownerId = widget.itemData['ownerId'];

    if (currentUserId == null) {
      _showSnackBar('Please log in to buy items', Colors.red);
      return;
    }

    if (currentUserId == ownerId) {
      _showSnackBar('You cannot buy your own item', Colors.orange);
      return;
    }

    if (widget.itemData['status'] != 'available') {
      _showSnackBar('This item is no longer available', Colors.red);
      return;
    }

    final result = await Navigator.pushNamed(
      context,
      '/buyer-form',
      arguments: {
        'itemData': widget.itemData,
        'itemId': widget.itemId,
        'sellerId': ownerId,
      },
    );

    if (result == true) {
      _showSnackBar('Purchase completed successfully!', Colors.green);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = currentUser?.uid == widget.itemData['ownerId'];
    final isAvailable = widget.itemData['status'] == 'available';

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: widget.itemData['imageUrl'] ?? '',
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[300],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.image_not_supported, size: 50),
                    ),
                    memCacheWidth: 800,
                    memCacheHeight: 600,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black26],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 100,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(widget.itemData['status']),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getStatusText(widget.itemData['status']),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                onPressed: _toggleFavorite,
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : Colors.grey[600],
                ),
              ),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.itemData['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        widget.itemData['price'] == 0
                            ? 'FREE'
                            : 'GHS ${widget.itemData['price']}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: widget.itemData['price'] == 0
                              ? Colors.green
                              : Colors.blue[700],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildInfoChip(
                        icon: Icons.category,
                        label: widget.itemData['category'] ?? '',
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      _buildInfoChip(
                        icon: Icons.star,
                        label: widget.itemData['condition'] ?? '',
                        color: _getConditionColor(widget.itemData['condition']),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.itemData['location'] ?? '',
                        style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.itemData['description'] ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'Seller',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  if (isLoadingOwner)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (ownerData == null)
                    _buildSellerUnavailable()
                  else
                    _buildSellerCard(),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: isOwner
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 8),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: isAvailable ? _buyItem : null,
                icon: Icon(
                  widget.itemData['price'] == 0
                      ? Icons.volunteer_activism
                      : Icons.shopping_cart,
                ),
                label: Text(
                  isAvailable
                      ? (widget.itemData['price'] == 0
                            ? 'Claim Item'
                            : 'Buy Now')
                      : 'Not Available',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAvailable ? Colors.green : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSellerUnavailable() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.grey,
            child: Icon(Icons.person, color: Colors.white),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seller information unavailable',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 4),
                Text(
                  'Unable to load seller details',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerCard() {
    // Determine if this is a collector or regular user
    // Check if the data came from collectors collection or has collector-specific fields
    final isCollector =
        ownerData?.containsKey('collectorType') == true ||
        ownerData?.containsKey('vehicleNumber') == true ||
        ownerData?.containsKey('vehicleType') == true ||
        ownerData?.containsKey('licensePlate') == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: isCollector ? Colors.blue : Colors.green,
            child: Icon(
              isCollector ? Icons.local_shipping : Icons.person,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      ownerData?['name'] ?? 'Unknown Seller',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isCollector)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Collector',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _getSellerPhone() ?? 'Phone: N/A',
                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
                ),
                if (isCollector && ownerData?['vehicleNumber'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Vehicle: ${ownerData?['vehicleNumber']}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Member since ${_formatDate(ownerData?['createdAt'])}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Color _getConditionColor(String? condition) {
    switch (condition?.toLowerCase()) {
      case 'new':
        return Colors.green;
      case 'like new':
        return Colors.blue;
      case 'used':
        return Colors.red;
      case 'free':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'available':
        return Colors.green;
      case 'sold':
        return Colors.orange;
      case 'reserved':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'available':
        return 'Available';
      case 'sold':
        return 'Sold';
      case 'reserved':
        return 'Reserved';
      default:
        return 'Unknown';
    }
  }

  String? _getSellerPhone() {
    if (ownerData == null) return null;

    // Try different possible phone field names
    final phone =
        ownerData!['phone'] ??
        ownerData!['phoneNumber'] ??
        ownerData!['mobile'] ??
        ownerData!['mobileNumber'] ??
        ownerData!['contact'] ??
        ownerData!['contactNumber'];

    return phone?.toString();
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Recently';
    try {
      final date = (timestamp as Timestamp).toDate();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 365) {
        return '${(difference.inDays / 365).floor()} year${difference.inDays > 730 ? 's' : ''} ago';
      } else if (difference.inDays > 30) {
        return '${(difference.inDays / 30).floor()} month${difference.inDays > 60 ? 's' : ''} ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else {
        return 'Recently';
      }
    } catch (_) {
      return 'Recently';
    }
  }
}
