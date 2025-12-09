// ignore_for_file: unused_local_variable

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/mobile_app/provider/provider.dart';
import 'package:flutter_application_1/mobile_app/routes/app_route.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final log = Logger();

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.currentUser?.reload();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _animationController.forward();
    _slideController.forward();

    Future.microtask(() async {
      final provider = Provider.of<UserProvider>(context, listen: false);
      await provider.fetchUserData();

      // Initialize SortScoreProvider to load pickup stats and sort score
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final sortScoreProvider = Provider.of<SortScoreProvider>(
          context,
          listen: false,
        );
        await sortScoreProvider.calculatePickupStats(userId);
        // Removed manual sort score generation since it auto-generates every 5 minutes
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final username = context.watch<UserProvider>().username;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFF2E7D32),
        centerTitle: true,
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF4CAF50)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              //  _buildHeader(),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          _buildUserInfo(user, username),
                          const SizedBox(height: 30),
                          _buildStatsCards(),
                          const SizedBox(height: 20),
                          // Removed the "Generate New Sort Score" button since it auto-generates every 5 minutes
                          _buildMenuSection(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget _buildHeader() {
  //   return FadeTransition(
  //     opacity: _fadeAnimation,
  //     child: Container(
  //       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
  //       child: Row(
  //         mainAxisAlignment: MainAxisAlignment.start,
  //         children: [
  //           Container(
  //             decoration: BoxDecoration(
  //               color: Colors.white.withOpacity(0.2),
  //               borderRadius: BorderRadius.circular(12),
  //             ),
  //             child: IconButton(
  //               onPressed: () => Navigator.pop(context),
  //               icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
  //             ),
  //           ),
  //           const Text(
  //             'My Profile',
  //             style: TextStyle(
  //               color: Colors.white,
  //               fontSize: 22,
  //               fontWeight: FontWeight.bold,
  //               letterSpacing: 0.5,
  //             ),
  //           ),
  //           // Container(
  //           //   decoration: BoxDecoration(
  //           //     color: Colors.white.withOpacity(0.2),
  //           //     borderRadius: BorderRadius.circular(12),
  //           //   ),
  //           //   child: IconButton(
  //           //     onPressed: () {
  //           //       // Settings or more options
  //           //     },
  //           //     icon: const Icon(Icons.more_vert, color: Colors.white),
  //           //   ),
  //           // ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildUserInfo(User? user, String? username) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Profile Picture with Online Status
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: user?.photoURL != null
                    ? ClipOval(
                        child: Image.network(
                          user!.photoURL!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.white,
                              ),
                        ),
                      )
                    : const Icon(Icons.person, size: 60, color: Colors.white),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Username with verified badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                username ?? 'Guest User',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5E20),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Email
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user?.email ?? 'eco.warrior@example.com',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF4CAF50).withOpacity(0.1),
                  const Color(0xFF2E7D32).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: const Color(0xFF4CAF50).withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🌱', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                const Text(
                  'Eco Champion',
                  style: TextStyle(
                    color: Color(0xFF1B5E20),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Level 5',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          Selector<SortScoreProvider, Map<String, dynamic>>(
            selector: (context, provider) => {
              'totalPickups': provider.totalPickups,
              'sortScore': provider.sortScore,
              'isLoading': provider.isLoading,
            },
            builder: (context, data, child) {
              final totalPickups = data['totalPickups'] as int;
              final sortScore = data['sortScore'] as int;
              final isLoading = data['isLoading'] as bool;

              if (isLoading) {
                return Container(
                  padding: const EdgeInsets.all(40),
                  child: const Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF4CAF50),
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Loading stats...',
                          style: TextStyle(
                            color: Color(0xFF1B5E20),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Total Pickups',
                      value: totalPickups.toString(),
                      icon: Icons.local_shipping_rounded,
                      color: const Color(0xFF2196F3),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Sort Score',
                      value: sortScore.toString(),
                      icon: Icons.eco_rounded,
                      color: const Color(0xFF4CAF50),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  final userId = FirebaseAuth.instance.currentUser?.uid;
                  if (userId != null) {
                    final provider = Provider.of<SortScoreProvider>(
                      context,
                      listen: false,
                    );
                    provider.calculatePickupStats(userId);

                    // Show feedback
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Stats refreshed!'),
                        backgroundColor: Colors.blue,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, color: Colors.blue, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Refresh Stats',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildGenerateNewScoreButton() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        onTap: () {
          final userId = FirebaseAuth.instance.currentUser?.uid;
          if (userId != null) {
            final provider = Provider.of<SortScoreProvider>(
              context,
              listen: false,
            );
            // provider.generateRandomSortScore(userId);

            // Show feedback
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('New sort score generated!'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4CAF50).withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Text(
            'Generate New Sort Score',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuSection() {
    final menuItems = [
      // {
      //   'icon': Icons.person_outline_rounded,
      //   'title': 'Edit Profile',
      //   'subtitle': 'Update your personal information',
      //   'color': const Color(0xFF2196F3),
      //   'onTap': () =>
      //       Navigator.pushNamed(context, AppRoutes.userProfileEditPage),
      // },
      {
        'icon': Icons.history_rounded,
        'title': 'Pickup History',
        'subtitle': 'View your past waste collections',
        'color': const Color(0xFF9C27B0),
        'onTap': () {
          Navigator.pushNamed(context, AppRoutes.pickuphistory);
          // Navigate to pickup history
        },
      },
      {
        'icon': Icons.help_outline_rounded,
        'title': 'About Us',
        'subtitle': 'Learn more about SortCycle',
        'color': const Color(0xFF4CAF50),
        'onTap': () => Navigator.pushNamed(context, AppRoutes.aboutus),
      },
      {
        'icon': Icons.settings_outlined,
        'title': 'Settings',
        'subtitle': 'App preferences and privacy',
        'color': const Color(0xFF607D8B),
        'onTap': () {
          // Navigate to settings
          Navigator.pushNamed(context, AppRoutes.userProfileEditPage);
        },
      },
    ];

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Menu',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 16),
          ...menuItems.map(
            (item) => _buildEnhancedMenuTile(
              icon: item['icon'] as IconData,
              title: item['title'] as String,
              subtitle: item['subtitle'] as String,
              color: item['color'] as Color,
              onTap: item['onTap'] as VoidCallback,
            ),
          ),
          const SizedBox(height: 16),
          _buildLogoutTile(),
        ],
      ),
    );
  }

  Widget _buildEnhancedMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Color(0xFF1B5E20),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.arrow_forward_ios, size: 14, color: color),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildLogoutTile() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.withOpacity(0.05), Colors.red.withOpacity(0.02)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.logout_rounded, color: Colors.red, size: 24),
        ),
        title: const Text(
          'Log Out',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.red,
          ),
        ),
        subtitle: const Text(
          'Sign out of your account',
          style: TextStyle(fontSize: 12, color: Colors.red),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: Colors.red,
          ),
        ),
        onTap: () => _showLogoutDialog(),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout, color: Colors.red, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Confirm Logout',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E20),
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of your account?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _handleLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'Log Out',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    try {
      // Show modern loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xFF4CAF50)),
                const SizedBox(height: 16),
                Text(
                  'Logging out...',
                  style: TextStyle(color: Colors.grey[700], fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );

      await FirebaseAuth.instance.signOut();

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        Navigator.pushNamedAndRemoveUntil(context, '/signin', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to log out: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      log.e('Logout error: $e');
    }
  }
}
