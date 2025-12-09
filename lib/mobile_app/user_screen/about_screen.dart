import 'package:flutter/material.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> with TickerProviderStateMixin {
  late AnimationController _headerAnimationController;
  late AnimationController _contentAnimationController;
  late Animation<double> _headerAnimation;
  late Animation<double> _contentAnimation;

  static const String _appName = 'SortCycle';
  static const String _appTagline =
      'Waste Classification & Environmental Awareness';
  static const String _appVersion = '1.0.0';
  static const String _copyrightYear = '2025';
  static const String _teamName = 'SortCycle Team';

  static const String _appDescription =
      'SortCycle is an intelligent waste classification app that helps users sort waste into six categories: plastic, metal, glass, cardboard, paper, and trash. The app uses machine learning to identify waste items and provide helpful information about how to recycle them properly.';

  static const String _missionStatement =
      'SortCycle aims to raise environmental awareness and promote responsible waste disposal through technology. Every correct classification and recycling action helps build a cleaner and more sustainable future.';

  static const List<FeatureItem> _features = [
    // FeatureItem(
    //   icon: Icons.camera_alt,
    //   title: 'Smart Classification',
    //   description: 'Classify waste instantly using your camera or gallery.',
    // ),
    FeatureItem(
      icon: Icons.tips_and_updates,
      title: 'Recycling Tips',
      description: 'Receive tailored recycling tips for each item.',
    ),
    // FeatureItem(
    //   icon: Icons.eco,
    //   title: 'Environmental Impact',
    //   description: 'Understand the environmental impact of each item.',
    // ),
    FeatureItem(
      icon: Icons.local_shipping,
      title: 'Pickup Tracking',
      description: 'Request and track pickups from local collectors.',
    ),
    FeatureItem(
      icon: Icons.analytics,
      title: 'Activity Stats',
      description: 'View detailed stats about your recycling activity.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _contentAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _headerAnimation = CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOutBack,
    );
    _contentAnimation = CurvedAnimation(
      parent: _contentAnimationController,
      curve: Curves.easeOutCubic,
    );

    _headerAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _contentAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _contentAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2E7D32), Color(0xFF388E3C), Color(0xFF4CAF50)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildCustomAppBar(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'About SortCycle',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            AnimatedBuilder(
              animation: _headerAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _headerAnimation.value,
                  child: Opacity(
                    opacity: _headerAnimation.value.clamp(0.0, 1.0),
                    child: _buildAppHeader(),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            AnimatedBuilder(
              animation: _contentAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 50 * (1 - _contentAnimation.value)),
                  child: Opacity(
                    opacity: _contentAnimation.value.clamp(0.0, 1.0),
                    child: Column(
                      children: [
                        _buildWhatIsSection(),
                        const SizedBox(height: 32),
                        _buildFeaturesSection(),
                        const SizedBox(height: 32),
                        _buildMissionSection(),
                        const SizedBox(height: 40),
                        _buildFooter(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppHeader() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green.shade50, Colors.green.shade100],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.green.shade600, Colors.green.shade700],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(Icons.recycling, size: 60, color: Colors.white),
          ),
          const SizedBox(height: 20),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [Colors.green.shade700, Colors.green.shade900],
            ).createShader(bounds),
            child: const Text(
              _appName,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _appTagline,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.green.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatIsSection() {
    return _buildSection(
      title: 'What is $_appName?',
      icon: Icons.help_outline,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade50, Colors.blue.shade100],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.shade200, width: 1),
        ),
        child: Text(
          _appDescription,
          style: TextStyle(
            fontSize: 16,
            height: 1.6,
            color: Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesSection() {
    return _buildSection(
      title: 'Amazing Features',
      icon: Icons.star,
      child: Column(
        children: _features.asMap().entries.map((entry) {
          final index = entry.key;
          final feature = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 600 + (index * 100)),
              tween: Tween(begin: 0, end: 1),
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(30 * (1 - value), 0),
                  child: Opacity(
                    opacity: value.clamp(0.0, 1.0),
                    child: _buildFeatureCard(feature),
                  ),
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFeatureCard(FeatureItem feature) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.green.shade400, Colors.green.shade600],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(feature.icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  feature.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionSection() {
    return _buildSection(
      title: 'Our Mission',
      icon: Icons.flag,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.green.shade50, Colors.green.shade100],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.shade200, width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade600,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.eco, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                _missionStatement,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.green.shade700, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        child,
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey.shade50, Colors.grey.shade100],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Version $_appVersion',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '© $_copyrightYear $_teamName',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class FeatureItem {
  final IconData icon;
  final String title;
  final String description;

  const FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}
