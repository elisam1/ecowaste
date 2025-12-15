import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/mobile_app/service/gamification_engine.dart';
import 'package:flutter_application_1/mobile_app/service/sustainability_analytics_service.dart';
import 'package:flutter_application_1/mobile_app/routes/app_route.dart';

class AdvancedFeaturesDashboard extends StatefulWidget {
  const AdvancedFeaturesDashboard({super.key});

  @override
  State<AdvancedFeaturesDashboard> createState() =>
      _AdvancedFeaturesDashboardState();
}

class _AdvancedFeaturesDashboardState extends State<AdvancedFeaturesDashboard> {
  final String? userId = FirebaseAuth.instance.currentUser?.uid;

  Map<String, dynamic> _gamificationData = {};
  Map<String, dynamic> _environmentalImpact = {};
  Map<String, dynamic> _goals = {};
  List<Map<String, dynamic>> _recommendations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (userId == null) return;

    try {
      final gamificationData = await GamificationEngine()
          .getUserGamificationData(userId!);
      final environmentalImpact = await SustainabilityAnalyticsService()
          .calculateUserEnvironmentalImpact(userId!);
      final goals = await SustainabilityAnalyticsService()
          .getSustainabilityGoals(userId!);
      final recommendations = await SustainabilityAnalyticsService()
          .getPersonalizedRecommendations(userId!);

      setState(() {
        _gamificationData = gamificationData;
        _environmentalImpact = environmentalImpact;
        _goals = goals;
        _recommendations = recommendations;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Features'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gamification Section
            _buildSectionHeader('🏆 Gamification', Icons.stars),
            PointsDisplay(
              points: _gamificationData['points'] ?? 0,
              level: _gamificationData['level'] ?? 1,
            ),
            const SizedBox(height: 16),

            // Badge Display
            BadgeDisplay(
              badgeIds: List<String>.from(_gamificationData['badges'] ?? []),
            ),
            const SizedBox(height: 24),

            // Environmental Impact Section
            _buildSectionHeader('🌱 Environmental Impact', Icons.eco),
            EnvironmentalImpactCard(impact: _environmentalImpact),
            const SizedBox(height: 24),

            // Sustainability Goals Section
            _buildSectionHeader('🎯 Monthly Goals', Icons.track_changes),
            SustainabilityGoalsWidget(goalsData: _goals),
            const SizedBox(height: 24),

            // Recommendations Section
            if (_recommendations.isNotEmpty) ...[
              _buildSectionHeader('💡 Recommendations', Icons.lightbulb),
              RecommendationsWidget(recommendations: _recommendations),
              const SizedBox(height: 24),
            ],

            // Quick Actions Section
            _buildSectionHeader('⚡ Quick Actions', Icons.flash_on),
            _buildQuickActions(),
            const SizedBox(height: 24),

            // Advanced Marketplace Preview
            _buildSectionHeader('🛒 Advanced Marketplace', Icons.shopping_bag),
            _buildMarketplacePreview(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 24, color: Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _buildActionCard(
          'View Leaderboard',
          Icons.leaderboard,
          () => Navigator.pushNamed(context, AppRoutes.leaderboard),
        ),
        _buildActionCard(
          'Marketplace',
          Icons.shopping_cart,
          () => Navigator.pushNamed(context, AppRoutes.markethomescreen),
        ),
        _buildActionCard(
          'Pickup History',
          Icons.history,
          () => Navigator.pushNamed(context, AppRoutes.pickuphistory),
        ),
        _buildActionCard(
          'Settings',
          Icons.settings,
          () => Navigator.pushNamed(context, AppRoutes.settings),
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: Theme.of(context).primaryColor),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarketplacePreview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enhanced Marketplace Features',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildFeatureItem('Auctions & Bidding', 'Place bids on items'),
            _buildFeatureItem(
              'Advanced Search',
              'Filter by location, price, condition',
            ),
            _buildFeatureItem('Offers System', 'Make and respond to offers'),
            _buildFeatureItem('Reviews & Ratings', 'Rate your transactions'),
            _buildFeatureItem('Favorites', 'Save items for later'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.markethomescreen),
                child: const Text('Explore Marketplace'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
