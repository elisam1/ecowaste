// home_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/mobile_app/ecomarketplace/add_items.dart';
import 'package:flutter_application_1/mobile_app/ecomarketplace/itemdetails.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'my_listing_page.dart';

class MarketHomeScreen extends StatefulWidget {
  const MarketHomeScreen({super.key});

  @override
  State<MarketHomeScreen> createState() => _MarketHomeScreen();
}

class _MarketHomeScreen extends State<MarketHomeScreen> {
  String searchQuery = '';
  String selectedCategory = 'All';

  final List<Map<String, dynamic>> categories = [
    {'name': 'All', 'icon': Icons.apps, 'color': Colors.blue},
    {'name': 'Furniture', 'icon': Icons.chair, 'color': Colors.brown},
    {'name': 'Electronics', 'icon': Icons.devices, 'color': Colors.orange},
    {'name': 'Plastic', 'icon': Icons.eco, 'color': Colors.green},
    {'name': 'Metal', 'icon': Icons.hardware, 'color': Colors.grey},
    {'name': 'Books', 'icon': Icons.book, 'color': Colors.purple},
    {'name': 'Clothing', 'icon': Icons.checkroom, 'color': Colors.pink},
    {'name': 'Tools', 'icon': Icons.build, 'color': Colors.red},
    {'name': 'Sports', 'icon': Icons.sports_soccer, 'color': Colors.indigo},
    {'name': 'Home', 'icon': Icons.home_filled, 'color': Colors.teal},
    {'name': 'Other', 'icon': Icons.more_horiz, 'color': Colors.amber},
  ];

  Stream<QuerySnapshot> _getItemsStream() {
    Query query = FirebaseFirestore.instance
        .collection('marketplace_items')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true);

    if (selectedCategory != 'All') {
      query = query.where('category', isEqualTo: selectedCategory);
    }

    return query.snapshots();
  }

  List<DocumentSnapshot> _filterItems(List<DocumentSnapshot> items) {
    if (searchQuery.isEmpty) return items;

    return items.where((item) {
      final data = item.data() as Map<String, dynamic>;
      final name = (data['name'] ?? '').toString().toLowerCase();
      final description = (data['description'] ?? '').toString().toLowerCase();
      final location = (data['location'] ?? '').toString().toLowerCase();
      final query = searchQuery.toLowerCase();

      return name.contains(query) ||
          description.contains(query) ||
          location.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 250, 250, 250),
      appBar: AppBar(
        centerTitle: true,
        //automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: const Color.fromARGB(255, 34, 125, 69),
        foregroundColor: const Color.fromARGB(221, 250, 249, 249),
        title: const Text(
          'EcoMarketplace',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'add_item') {
                Navigator.pushNamed(context, '/add-item');
              } else if (value == 'my_listings') {
                Navigator.pushNamed(context, '/my-listings');
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'add_item',
                child: Row(
                  children: [
                    Icon(Icons.add, color: Colors.green),
                    SizedBox(width: 12),
                    Text('Add Item'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'my_listings',
                child: Row(
                  children: [
                    Icon(Icons.list, color: Colors.blue),
                    SizedBox(width: 12),
                    Text('My Listings'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Header section with search
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Find sustainable items',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search for items...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                ),
              ],
            ),
          ),

          // Categories section
          Container(
            color: Colors.white,
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = selectedCategory == category['name'];

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedCategory = category['name'];
                    });
                  },
                  child: Container(
                    width: 80,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? category['color'] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: category['color'].withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          category['icon'],
                          color: isSelected ? Colors.white : Colors.grey[600],
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          category['name'],
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[600],
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Items section
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getItemsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Something went wrong',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                final allItems = snapshot.data?.docs ?? [];
                final filteredItems = _filterItems(allItems);

                if (filteredItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.eco_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          searchQuery.isNotEmpty || selectedCategory != 'All'
                              ? 'No items found'
                              : 'No items available yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          searchQuery.isNotEmpty || selectedCategory != 'All'
                              ? 'Try adjusting your search or filters'
                              : 'Be the first to add an item!',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.75,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final item = filteredItems[index];
                          final data = item.data() as Map<String, dynamic>;

                          return _buildItemCard(data, item.id);
                        }, childCount: filteredItems.length),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> data, String itemId) {
    final categoryData = categories.firstWhere(
      (cat) => cat['name'] == data['category'],
      orElse: () => categories.last, // Default to 'Other'
    );

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/item-detail',
          arguments: {
            'itemId': itemId,
            'itemData': data,
          },
        );
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with category badge
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: data['imageUrl'] ?? '',
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_not_supported,
                              color: Colors.grey[400],
                              size: 32,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'No Image',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      memCacheWidth: 300,
                      memCacheHeight: 200,
                    ),
                  ),

                  // Category badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: categoryData['color'],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            categoryData['icon'],
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            data['category'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Price badge
                  if (data['price'] == 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'FREE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Item details
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['name'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Condition and location
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: _getConditionColor(
                              data['condition'],
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            data['condition'] ?? '',
                            style: TextStyle(
                              color: _getConditionColor(data['condition']),
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.location_on,
                          size: 10,
                          color: Colors.grey[500],
                        ),
                        Expanded(
                          child: Text(
                            data['location'] ?? '',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 9,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Price
                    Text(
                      data['price'] == 0
                          ? 'Free'
                          : 'GHS ${data['price'].toString()}',
                      style: TextStyle(
                        color: data['price'] == 0
                            ? Colors.green
                            : Colors.blue[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getConditionColor(String? condition) {
    switch (condition?.toLowerCase()) {
      case 'new':
        return Colors.green;
      case 'like new':
        return Colors.blue;
      case 'good':
        return Colors.orange;
      case 'fair':
        return Colors.red;
      case 'free':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
