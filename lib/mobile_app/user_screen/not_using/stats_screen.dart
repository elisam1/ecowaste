import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/mobile_app/routes/app_route.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _listAnimationController;
  late AnimationController _progressAnimationController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _progressAnimation;

  final Map<String, dynamic> categoryInfo = {
    "Plastic": {
      "color": const Color(0xFF2196F3),
      "icon": Icons.water_drop_rounded,
      "description": "Bottles, containers, packaging",
      "impact": "Takes 450+ years to decompose",
    },
    "Paper": {
      "color": const Color(0xFF8D6E63),
      "icon": Icons.description_rounded,
      "description": "Documents, newspapers, magazines",
      "impact": "Saves 17 trees per ton recycled",
    },
    "Glass": {
      "color": const Color(0xFF4CAF50),
      "icon": Icons.local_drink_rounded,
      "description": "Bottles, jars, containers",
      "impact": "100% recyclable infinitely",
    },
    "Metal": {
      "color": const Color(0xFF607D8B),
      "icon": Icons.hardware_rounded,
      "description": "Cans, foils, containers",
      "impact": "Uses 95% less energy to recycle",
    },
    "Cardboard": {
      "color": const Color(0xFFFF9800),
      "icon": Icons.inventory_2_rounded,
      "description": "Boxes, packaging materials",
      "impact": "Reduces methane emissions",
    },
    // "Organic": {
    //   "color": const Color(0xFF8BC34A),
    //   "icon": Icons.eco_rounded,
    //   "description": "Food waste, compostables",
    //   "impact": "Creates nutrient-rich soil",
    // },
    "Trash": {
      "color": const Color(0xFFE57373),
      "icon": Icons.delete_rounded,
      "description": "Non-recyclable items",
      "impact": "Consider reducing consumption",
    },
  };

  Map<String, int> categoryCounts = {};
  int totalItems = 0;
  int totalCategoriesUsed = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _fetchCategoryCounts();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _listAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeInOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
          ),
        );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutBack),
      ),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _progressAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _listAnimationController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _progressAnimationController.forward();
    });
  }

  Future<void> _fetchCategoryCounts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('classification_results')
          .get();

      Map<String, int> counts = {};

      // Initialize with all possible categories
      for (String category in categoryInfo.keys) {
        counts[category] = 0;
      }

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final label = data['label']?.toString().trim();
        if (label != null) {
          // Try exact match first
          if (counts.containsKey(label)) {
            counts[label] = counts[label]! + 1;
          } else {
            // Try partial matching for variations
            String? matchedCategory = _findMatchingCategory(label);
            if (matchedCategory != null) {
              counts[matchedCategory] = counts[matchedCategory]! + 1;
            }
          }
        }
      }

      setState(() {
        categoryCounts = counts;
        totalItems = counts.values.fold(0, (sum, v) => sum + v);
        totalCategoriesUsed = counts.values.where((count) => count > 0).length;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  String? _findMatchingCategory(String label) {
    final lowerLabel = label.toLowerCase();

    if (lowerLabel.contains('plastic') || lowerLabel.contains('bottle')) {
      return 'Plastic';
    } else if (lowerLabel.contains('paper') ||
        lowerLabel.contains('newspaper')) {
      return 'Paper';
    } else if (lowerLabel.contains('glass') || lowerLabel.contains('jar')) {
      return 'Glass';
    } else if (lowerLabel.contains('metal') ||
        lowerLabel.contains('can') ||
        lowerLabel.contains('aluminum')) {
      return 'Metal';
    } else if (lowerLabel.contains('cardboard') || lowerLabel.contains('box')) {
      return 'Cardboard';
    } else if (lowerLabel.contains('trash') ||
        lowerLabel.contains('food') ||
        lowerLabel.contains('compost')) {
      return 'Trash';
    }

    return 'Trash'; // Default fallback
  }

  @override
  void dispose() {
    _animationController.dispose();
    _listAnimationController.dispose();
    _progressAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FFFE),
      appBar: _buildAppBar(),
      body: isLoading ? _buildLoadingState() : _buildMainContent(),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF26A69A), Color(0xFF42A5F5)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF26A69A).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => Navigator.pushNamed(context, AppRoutes.chatlistpage),
          backgroundColor: Colors.transparent,
          elevation: 0,
          label: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat, color: Colors.white),
              SizedBox(width: 3),
              Text(
                'Chat',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.analytics_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SortCycle Stats',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Environmental Impact',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
      backgroundColor: const Color(0xFF2E7D32),
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2E7D32), Color(0xFF388E3C), Color(0xFF4CAF50)],
          ),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.profile);
            },
            icon: const Icon(
              Icons.person_outline_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading Statistics...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return CustomScrollView(
      slivers: [
        _buildAnimatedHeader(),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
        _buildBreakdownHeader(),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        _buildCategoryList(),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }

  SliverToBoxAdapter _buildAnimatedHeader() {
    return SliverToBoxAdapter(
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF2E7D32),
                        Color(0xFF4CAF50),
                        Color(0xFF66BB6A),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.eco_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Your Impact",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "Making a difference, one item at a time",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                totalItems.toString(),
                                "Items Classified",
                                Icons.inventory_2_rounded,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 50,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            Expanded(
                              child: _buildStatCard(
                                "6",
                                "Categories",
                                Icons.category_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  SliverToBoxAdapter _buildBreakdownHeader() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade100, Colors.blue.shade50],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.pie_chart_rounded,
                color: Colors.blue.shade600,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Category Breakdown",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2E2E2E),
                    ),
                  ),
                  Text(
                    "All waste categories",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverList _buildCategoryList() {
    // Sort categories: items with counts first (descending), then items with 0 counts
    final sortedCategories = categoryCounts.entries.toList()
      ..sort((a, b) {
        if (a.value == 0 && b.value == 0) return 0;
        if (a.value == 0) return 1;
        if (b.value == 0) return -1;
        return b.value.compareTo(a.value);
      });

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final entry = sortedCategories[index];
        final category = entry.key;
        final count = entry.value;
        final info = categoryInfo[category]!;
        final percent = totalItems > 0 ? count / totalItems : 0.0;

        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 600 + index * 100),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: _buildCategoryCard(category, count, info, percent),
              ),
            );
          },
        );
      }, childCount: sortedCategories.length),
    );
  }

  Widget _buildCategoryCard(
    String category,
    int count,
    Map<String, dynamic> info,
    double percent,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        (info['color'] as Color).withOpacity(0.2),
                        (info['color'] as Color).withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(info['icon'], color: info['color'], size: 32),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              category,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 20,
                                color: Color(0xFF2E2E2E),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: (info['color'] as Color).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "${(percent * 100).toStringAsFixed(1)}%",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: info['color'],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        info['description'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "$count items classified",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E2E2E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: percent * _progressAnimation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            info['color'],
                            (info['color'] as Color).withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    color: Colors.green.shade600,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      info['impact'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
