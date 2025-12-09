import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/mobile_app/provider/provider.dart';
import 'package:flutter_application_1/mobile_app/routes/app_route.dart';
import 'package:flutter_application_1/mobile_app/waste_collector/pending_summary.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
//import 'package:logger/web.dart';

class CollectorProfileScreen extends StatefulWidget {
  const CollectorProfileScreen({super.key});

  @override
  State<CollectorProfileScreen> createState() => _CollectorProfileScreenState();
}

class _CollectorProfileScreenState extends State<CollectorProfileScreen> {
  final log = Logger();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => Provider.of<CollectorProvider>(
        context,
        listen: false,
      ).fetchCollectorData(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final collectorProvider = Provider.of<CollectorProvider>(context);
    final collectorId = FirebaseAuth.instance.currentUser!.uid;

    // final username = context.watch<UserProvider>().username;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section with Profile Info
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Header with settings
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          // IconButton(
                          //   onPressed: () {},
                          //   icon: const Icon(
                          //     Icons.settings,
                          //     color: Colors.white,
                          //   ),
                          // ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Profile Picture and Info
                      Row(
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.green[400],
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    onPressed: () {},
                                    icon: const Icon(
                                      Icons.camera_alt,
                                      size: 16,
                                      color: Colors.green,
                                    ),
                                    iconSize: 16,
                                    padding: const EdgeInsets.all(4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      " ${collectorProvider.name ?? 'Guest'}",

                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    // IconButton(
                                    //   onPressed: () {},
                                    //   icon: const Icon(
                                    //     Icons.edit,
                                    //     size: 16,
                                    //     color: Colors.white70,
                                    //   ),
                                    // ),
                                  ],
                                ),
                                const Text(
                                  'Waste Collection Specialist',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.star,
                                      size: 16,
                                      color: Colors.amber,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      '4.8',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      ' • 2 years experience',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Stats Section
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Stats Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          CollectorTotalPickupsText(collectorId: collectorId),

                          'Total Pickups',
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          CompletionRateText(collectorId: collectorId),
                          'Completion Rate',
                          Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Contact Information
                  _buildSectionCard('Contact Information', [
                    _buildContactItem(
                      Icons.phone,
                      'Phone',
                      collectorProvider.phone ?? 'Loading...',
                    ),
                    _buildContactItem(
                      Icons.email,
                      'Email',
                      collectorProvider.email ?? 'Loading...',
                    ),
                    _buildContactItem(
                      Icons.location_on,
                      'Location',
                      collectorProvider.town ?? 'Loading...',
                    ),
                  ]),
                  const SizedBox(height: 16),

                  const SizedBox(height: 16),

                  // Settings Menu
                  _buildSectionCard('Settings', [
                    // _buildSettingsItem(
                    //   Icons.notifications,
                    //   'Notifications',
                    //   () {},
                    // ),
                    _buildSettingsItem(Icons.security, 'Edit Profile', () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.collectorProfileEditPage,
                      );
                    }),
                    _buildSettingsItem(Icons.help, 'Help & Support', () {}),
                    _buildSettingsItem(Icons.info, 'About App', () {
                      Navigator.pushNamed(context, AppRoutes.collectorabout);
                    }),
                  ]),
                  const SizedBox(height: 24),

                  _buildLogoutTile(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutTile() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.logout, color: Colors.red, size: 24),
        ),
        title: const Text(
          'Log Out',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.red,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.red,
        ),
        onTap: () => _showLogoutDialog(),
      ),
    );
  }

  Widget _buildStatCard(Widget valueWidget, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          valueWidget,
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.blue[600]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Confirm Logout',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E7D32),
          ),
        ),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
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
            ),
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
        ),
      );

      await FirebaseAuth.instance.signOut();

      if (mounted) {
        // Close loading dialog
        Navigator.pop(context);

        // Navigate to login - adjust route name as needed
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/signin', // Change this to your actual login route
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        // Close loading dialog if it's showing
        Navigator.pop(context);

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to log out: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      log.e('Logout error: $e'); // For debugging
    }
  }
}
