import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> with TickerProviderStateMixin {
  late AnimationController _headerController;
  late AnimationController _contentController;
  late AnimationController _floatingController;
  late ScrollController _scrollController;

  double _scrollOffset = 0;

  static const String _appName = 'EcoWaste';
  static const String _appTagline = 'Smart Waste Management for Ghana';
  static const String _appVersion = '1.0.0';
  static const String _copyrightYear = '2025';

  static const String _appDescription =
      'EcoWaste is revolutionizing waste management in Ghana by connecting households with certified waste collectors. Our platform makes it easy to schedule pickups, track collectors in real-time, and contribute to a cleaner environment.';

  static const String _missionStatement =
      'To create a sustainable waste management ecosystem in Ghana, empowering communities to dispose of waste responsibly while providing livelihood opportunities for local collectors.';

  static const String _visionStatement =
      'A cleaner Ghana where every piece of waste is properly managed, recycled, or disposed of, creating healthier communities and a greener future for generations to come.';

  static const List<_FeatureItem> _features = [
    _FeatureItem(
      icon: Icons.local_shipping_rounded,
      title: 'Easy Pickup Scheduling',
      description:
          'Request waste pickups with just a few taps. Choose your preferred date and time.',
      color: Color(0xFF4CAF50),
    ),
    _FeatureItem(
      icon: Icons.location_on_rounded,
      title: 'Real-Time Tracking',
      description:
          'Track your collector\'s location live and get accurate ETAs for pickups.',
      color: Color(0xFF2196F3),
    ),
    _FeatureItem(
      icon: Icons.star_rounded,
      title: 'Collector Ratings',
      description:
          'Rate collectors and help maintain service quality in your community.',
      color: Color(0xFFFF9800),
    ),
    _FeatureItem(
      icon: Icons.eco_rounded,
      title: 'Eco Points & Rewards',
      description: 'Earn points for every pickup and climb the leaderboard.',
      color: Color(0xFF9C27B0),
    ),
    _FeatureItem(
      icon: Icons.shopping_bag_rounded,
      title: 'EcoMarketplace',
      description:
          'Buy and sell recycled items in our sustainable marketplace.',
      color: Color(0xFF00BCD4),
    ),
    _FeatureItem(
      icon: Icons.chat_rounded,
      title: 'In-App Chat',
      description:
          'Communicate directly with collectors for seamless coordination.',
      color: Color(0xFFE91E63),
    ),
  ];

  static const List<_TeamMember> _team = [
    _TeamMember(name: 'Elikem', role: 'Lead Developer', avatar: 'E'),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);

    _headerController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..forward();

    _contentController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _floatingController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 400), () {
      _contentController.forward();
    });
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    _contentController.dispose();
    _floatingController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          _buildAnimatedBackground(),

          // Floating particles
          _buildFloatingParticles(),

          // Main content
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Collapsing header
              _buildSliverAppBar(),

              // Content
              SliverToBoxAdapter(child: _buildContent()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _floatingController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(
                  const Color(0xFF0D3B2E),
                  const Color(0xFF1A5D4A),
                  _floatingController.value,
                )!,
                Color.lerp(
                  const Color(0xFF1A5D4A),
                  const Color(0xFF2E7D5F),
                  _floatingController.value,
                )!,
                Color.lerp(
                  const Color(0xFF2E7D5F),
                  const Color(0xFF1A5D4A),
                  _floatingController.value,
                )!,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingParticles() {
    return AnimatedBuilder(
      animation: _floatingController,
      builder: (context, child) {
        return CustomPaint(
          size: MediaQuery.of(context).size,
          painter: _ParticlePainter(
            animation: _floatingController.value,
            scrollOffset: _scrollOffset,
          ),
        );
      },
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 300,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(background: _buildHeader()),
    );
  }

  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _headerController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 100, 24, 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Animated logo
              Transform.scale(
                scale: Curves.elasticOut.transform(_headerController.value),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
                        blurRadius: 25,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.recycling_rounded,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // App name with shimmer effect
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Colors.white, Color(0xFFE0E0E0), Colors.white],
                ).createShader(bounds),
                child: Text(
                  _appName,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Tagline
              Opacity(
                opacity: _headerController.value.clamp(0.0, 1.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    _appTagline,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    return AnimatedBuilder(
      animation: _contentController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - _contentController.value)),
          child: Opacity(
            opacity: _contentController.value.clamp(0.0, 1.0),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  _buildAboutSection(),
                  const SizedBox(height: 32),
                  _buildFeaturesSection(),
                  const SizedBox(height: 32),
                  _buildMissionVisionSection(),
                  const SizedBox(height: 32),
                  _buildTeamSection(),
                  const SizedBox(height: 32),
                  _buildStatsSection(),
                  const SizedBox(height: 32),
                  _buildContactSection(),
                  const SizedBox(height: 32),
                  _buildFooter(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAboutSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('About EcoWaste', Icons.info_outline_rounded),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade50, Colors.green.shade100],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              children: [
                Text(
                  _appDescription,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.7,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStatChip('🇬🇭', 'Made in Ghana'),
                    const SizedBox(width: 12),
                    _buildStatChip('♻️', 'Eco-Friendly'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String emoji, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Features', Icons.star_rounded),
          const SizedBox(height: 16),
          ..._features.asMap().entries.map((entry) {
            final index = entry.key;
            final feature = entry.value;
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 400 + (index * 100)),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(20 * (1 - value), 0),
                  child: Opacity(
                    opacity: value.clamp(0.0, 1.0),
                    child: _buildFeatureCard(feature),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(_FeatureItem feature) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: feature.color.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: feature.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: feature.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(feature.icon, color: feature.color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  feature.description,
                  style: TextStyle(
                    fontSize: 13,
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

  Widget _buildMissionVisionSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Our Purpose', Icons.flag_rounded),
          const SizedBox(height: 16),

          // Mission
          _buildPurposeCard(
            title: 'Mission',
            content: _missionStatement,
            icon: Icons.rocket_launch_rounded,
            gradient: [const Color(0xFF667EEA), const Color(0xFF764BA2)],
          ),
          const SizedBox(height: 16),

          // Vision
          _buildPurposeCard(
            title: 'Vision',
            content: _visionStatement,
            icon: Icons.visibility_rounded,
            gradient: [const Color(0xFF11998E), const Color(0xFF38EF7D)],
          ),
        ],
      ),
    );
  }

  Widget _buildPurposeCard({
    required String title,
    required String content,
    required IconData icon,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Meet the Team', Icons.people_rounded),
          const SizedBox(height: 16),
          Center(
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: _team.map((member) => _buildTeamCard(member)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard(_TeamMember member) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                member.avatar,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            member.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            member.role,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A5D4A), Color(0xFF2E7D5F)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text(
            'Impact So Far',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('1000+', 'Users', Icons.people_outline),
              _buildStatItem('5000+', 'Pickups', Icons.local_shipping_outlined),
              _buildStatItem('50+', 'Collectors', Icons.person_outline),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildContactSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Get in Touch', Icons.mail_rounded),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _buildContactItem(
                  icon: Icons.email_rounded,
                  title: 'Email',
                  value: 'support@ecowaste.gh',
                  onTap: () => _launchUrl('mailto:support@ecowaste.gh'),
                ),
                const Divider(height: 24),
                _buildContactItem(
                  icon: Icons.language_rounded,
                  title: 'Website',
                  value: 'www.ecowaste.gh',
                  onTap: () => _launchUrl('https://www.ecowaste.gh'),
                ),
                const Divider(height: 24),
                _buildContactItem(
                  icon: Icons.phone_rounded,
                  title: 'Phone',
                  value: '+233 XX XXX XXXX',
                  onTap: () => _launchUrl('tel:+233000000000'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.green.shade700, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url));
    } catch (e) {
      // Handle error
    }
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.green.shade700, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade100, Colors.grey.shade50],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.recycling, color: Colors.green, size: 24),
              const SizedBox(width: 8),
              Text(
                _appName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Version $_appVersion',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            '© $_copyrightYear EcoWaste Ghana',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          Text(
            'Made with 💚 in Ghana',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

// Models
class _FeatureItem {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}

class _TeamMember {
  final String name;
  final String role;
  final String avatar;

  const _TeamMember({
    required this.name,
    required this.role,
    required this.avatar,
  });
}

// Particle Painter
class _ParticlePainter extends CustomPainter {
  final double animation;
  final double scrollOffset;

  _ParticlePainter({required this.animation, required this.scrollOffset});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final random = math.Random(42);

    for (int i = 0; i < 20; i++) {
      final x = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height * 0.5;
      final y =
          (baseY + animation * 50 - scrollOffset * 0.3) % (size.height * 0.5);
      final radius = random.nextDouble() * 3 + 1;
      final opacity = (random.nextDouble() * 0.3 + 0.1) * (1 - animation * 0.5);

      paint.color = Colors.white.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.scrollOffset != scrollOffset;
  }
}
