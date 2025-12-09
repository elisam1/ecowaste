import 'package:flutter/material.dart';

class CollectorAboutPage extends StatefulWidget {
  const CollectorAboutPage({super.key});

  @override
  State<CollectorAboutPage> createState() => _CollectorAboutPageState();
}

class _CollectorAboutPageState extends State<CollectorAboutPage>
    with TickerProviderStateMixin {
  late AnimationController _headerAnimationController;
  late AnimationController _contentAnimationController;
  late Animation<double> _headerAnimation;
  late Animation<double> _contentAnimation;

  static const String _appName = 'SortCycle Collector';
  static const String _appTagline =
      'Professional Waste Collection & Management';
  static const String _appVersion = '1.0.0';
  static const String _copyrightYear = '2025';
  static const String _teamName = 'SortCycle Team';

  static const String _appDescription =
      'SortCycle Collector is a comprehensive waste management platform designed specifically for professional waste collectors. Connect with customers, manage pickup requests, track collections, and optimize your waste collection routes while contributing to environmental sustainability.';

  static const String _missionStatement =
      'Empowering waste collectors with modern technology to streamline operations, increase efficiency, and build a sustainable waste management ecosystem. Together, we\'re creating cleaner communities and a greener future.';

  static const List<CollectorFeatureItem> _features = [
    CollectorFeatureItem(
      icon: Icons.schedule,
      title: 'Smart Scheduling',
      description:
          'Manage pickup requests and optimize your collection routes efficiently.',
      color: Colors.blue,
    ),
    CollectorFeatureItem(
      icon: Icons.location_on,
      title: 'Route Optimization',
      description: 'Get the most efficient routes to save time and fuel costs.',
      color: Colors.orange,
    ),
    CollectorFeatureItem(
      icon: Icons.people,
      title: 'Customer Management',
      description:
          'Connect with customers and manage their waste collection needs.',
      color: Colors.purple,
    ),
    CollectorFeatureItem(
      icon: Icons.analytics,
      title: 'Collection Analytics',
      description:
          'Track your collections, earnings, and environmental impact.',
      color: Colors.teal,
    ),
    // CollectorFeatureItem(
    //   icon: Icons.payment,
    //   title: 'Digital Payments',
    //   description: 'Secure payment processing and financial tracking.',
    //   color: Colors.indigo,
    // ),
    // CollectorFeatureItem(
    //   icon: Icons.eco,
    //   title: 'Impact Tracking',
    //   description: 'Monitor your contribution to environmental conservation.',
    //   color: Colors.green,
    // ),
  ];

  static const List<BenefitItem> _benefits = [
    BenefitItem(
      icon: Icons.trending_up,
      title: 'Increase Revenue',
      description: 'Optimize routes and manage more customers efficiently.',
    ),
    BenefitItem(
      icon: Icons.access_time,
      title: 'Save Time',
      description: 'Automated scheduling and route planning.',
    ),
    BenefitItem(
      icon: Icons.security,
      title: 'Secure Platform',
      description: 'Safe and reliable payment processing.',
    ),
    BenefitItem(
      icon: Icons.support,
      title: '24/7 Support',
      description: 'Dedicated support team for collectors.',
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
            'About SortCycle Collector',
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
                final value = _headerAnimation.value.clamp(0.0, 1.0);
                return Transform.scale(
                  scale: value,
                  child: Opacity(opacity: value, child: _buildAppHeader()),
                );
              },
            ),
            const SizedBox(height: 40),
            AnimatedBuilder(
              animation: _contentAnimation,
              builder: (context, child) {
                final value = _contentAnimation.value.clamp(0.0, 1.0);
                return Transform.translate(
                  offset: Offset(0, 50 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: Column(
                      children: [
                        _buildWhatIsSection(),
                        const SizedBox(height: 32),
                        _buildFeaturesSection(),
                        const SizedBox(height: 32),
                        _buildBenefitsSection(),
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
        gradient: const LinearGradient(
          colors: [
            Color.fromARGB(255, 144, 241, 149),
            Color.fromARGB(255, 155, 239, 159),
            Color.fromARGB(255, 141, 237, 144),
          ],
          // [Colors.blue.shade50, Colors.blue.shade100],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
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
                colors: [Colors.blue.shade600, Colors.blue.shade700],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color.fromARGB(
                    255,
                    60,
                    232,
                    106,
                  ).withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.local_shipping,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade900],
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
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatIsSection() => _buildSection(
    title: 'Professional Waste Collection Platform',
    icon: Icons.business,
    child: _sectionCard(_appDescription, Colors.indigo),
  );

  Widget _buildFeaturesSection() => _buildSection(
    title: 'Powerful Features',
    icon: Icons.star,
    child: Wrap(
      spacing: 16,
      runSpacing: 16,
      children: List.generate(_features.length, (index) {
        final feature = _features[index];
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 600 + (index * 100)),
          tween: Tween(begin: 0, end: 1),
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: SizedBox(
                  width: (MediaQuery.of(context).size.width - 80) / 2,
                  child: _buildFeatureCard(feature),
                ),
              ),
            );
          },
        );
      }),
    ),
  );

  Widget _buildBenefitsSection() => _buildSection(
    title: 'Why Choose SortCycle?',
    icon: Icons.thumb_up,
    child: Column(
      children: _benefits.asMap().entries.map((entry) {
        final index = entry.key;
        final benefit = entry.value;
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
                  child: _buildBenefitCard(benefit),
                ),
              );
            },
          ),
        );
      }).toList(),
    ),
  );

  Widget _buildMissionSection() => _buildSection(
    title: 'Our Mission',
    icon: Icons.flag,
    child: _sectionCard(_missionStatement, Colors.green),
  );

  Widget _buildFeatureCard(CollectorFeatureItem feature) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [feature.color.shade400, feature.color.shade600],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(feature.icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            feature.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            feature.description,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitCard(BenefitItem benefit) {
    return _sectionCard(
      benefit.description,
      Colors.amber,
      icon: benefit.icon,
      title: benefit.title,
    );
  }

  Widget _sectionCard(
    String text,
    MaterialColor color, {
    IconData? icon,
    String? title,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.shade50, color.shade100]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        children: [
          if (icon != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.shade600,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
          if (icon != null) const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (title != null) const SizedBox(height: 4),
                Text(
                  text,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
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
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.blue.shade700, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
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
          colors: [Colors.grey.shade50, Colors.grey.shade100],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.info_outline, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Text(
                'Professional Waste Collection',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Version $_appVersion',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            '© $_copyrightYear $_teamName',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class CollectorFeatureItem {
  final IconData icon;
  final String title;
  final String description;
  final MaterialColor color;

  const CollectorFeatureItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}

class BenefitItem {
  final IconData icon;
  final String title;
  final String description;

  const BenefitItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}
