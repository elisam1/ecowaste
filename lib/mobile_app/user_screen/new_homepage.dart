// ignore_for_file: unused_import, duplicate_ignore

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/mobile_app/provider/provider.dart';
import 'package:flutter_application_1/mobile_app/provider/notification_provider.dart';
//import 'package:flutter_application_1/mobile_app/provider/sort_score_provider.dart';
import 'package:flutter_application_1/mobile_app/routes/app_route.dart';
// ignore: unused_import
import 'package:flutter_application_1/mobile_app/user_screen/user_tracking_collector.dart';
import 'package:flutter_application_1/mobile_app/user_screen/notification_page.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  String? userRequestId;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutQuart),
        );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _slideController.forward();
    _fadeController.forward();

    // Fetch sortScore after init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final provider = Provider.of<SortScoreProvider>(context, listen: false);
        provider.calculatePickupStats(userId);

        // Initialize notification provider for user
        final notificationProvider = Provider.of<NotificationProvider>(
          context,
          listen: false,
        );
        notificationProvider.initialize(userId, 'user');
      }
    });
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      FirebaseFirestore.instance
          .collection('pickup_requests')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get()
          .then((snapshot) {
            if (snapshot.docs.isNotEmpty) {
              setState(() {
                userRequestId = snapshot.docs.first.id;
              });
            }
          });
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //final rank = context.watch<SortScoreProvider>().rank;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Dynamic App Bar
          SliverAppBar(
            automaticallyImplyLeading: false,
            expandedHeight: 100,
            floating: false,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.fromARGB(255, 47, 143, 84),
                      Color.fromARGB(255, 48, 226, 140),
                      Color.fromARGB(255, 32, 102, 95),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'SortCycle',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.recycling_rounded,
                                  color: Colors.white70,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Waste pickup made easy',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            // Notification Bell with Badge
                            Consumer<NotificationProvider>(
                              builder: (context, notificationProvider, child) {
                                return Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: IconButton(
                                        onPressed: () {
                                          Navigator.pushNamed(
                                            context,
                                            '/user-notifications',
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.notifications_outlined,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    if (notificationProvider.unreadCount > 0)
                                      Positioned(
                                        right: 8,
                                        top: 8,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 16,
                                            minHeight: 16,
                                          ),
                                          child: Center(
                                            child: Text(
                                              notificationProvider.unreadCount >
                                                      99
                                                  ? '99+'
                                                  : notificationProvider
                                                        .unreadCount
                                                        .toString(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            // Profile Avatar
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.profile,
                                ),
                                icon: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Main Content
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SortScore Dashboard Card
                      Selector<SortScoreProvider, Map<String, dynamic>>(
                        selector: (context, provider) => {
                          'totalPickups': provider.totalPickups,
                          'monthlyPickups': provider.monthlyPickups,
                          'rank': provider.rank,
                          'sortScore': provider.sortScore,
                          'isLoading': provider.isLoading,
                        },
                        builder: (context, data, child) {
                          return _buildSortScoreCard(data);
                        },
                      ),

                      const SizedBox(height: 24),

                      // Quick Actions focused on pickup
                      _buildQuickActions(),
                      const SizedBox(height: 24),

                      // Recent Pickup Requests
                      _buildRecentPickups(),
                      //const SizedBox(height: 24),

                      // Community Leaderboard
                      // _buildCommunitySection(),
                      const SizedBox(height: 24),

                      // Pickup Tips & Guidelines
                      _buildPickupGuidelines(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      // Floating Action Button for Quick Chat
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

  Widget _buildSortScoreCard(Map<String, dynamic> data) {
    final totalPickups = data['totalPickups'] as int;
    final monthlyPickups = data['monthlyPickups'] as int;
    final rank = data['rank'] as int;
    final sortScore = data['sortScore'] as int;
    final isLoading = data['isLoading'] as bool;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your total pickup',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              totalPickups.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Show a refresh button if data is 0
                            if (totalPickups == 0 &&
                                monthlyPickups == 0 &&
                                rank == 0)
                              GestureDetector(
                                onTap: () {
                                  final userId =
                                      FirebaseAuth.instance.currentUser?.uid;
                                  if (userId != null) {
                                    final provider =
                                        Provider.of<SortScoreProvider>(
                                          context,
                                          listen: false,
                                        );
                                    provider.calculatePickupStats(userId);
                                    // provider.generateRandomSortScore(userId);
                                  }
                                },
                                child: const Icon(
                                  Icons.refresh,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // Column(
                        //   crossAxisAlignment: CrossAxisAlignment.end,
                        //   children: [
                        //     const Text(
                        //       'Sort Score',
                        //       style: TextStyle(
                        //         color: Colors.white70,
                        //         fontSize: 16,
                        //         fontWeight: FontWeight.w500,
                        //       ),
                        //     ),
                        //     const SizedBox(height: 4),
                        //     Text(
                        //       sortScore.toString(),
                        //       style: const TextStyle(
                        //         color: Colors.white,
                        //         fontSize: 32,
                        //         fontWeight: FontWeight.bold,
                        //       ),
                        //     ),
                        //   ],
                        // ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.eco_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildScoreMetric(
                      'Sort Score',
                      '$sortScore',
                      Icons.stars_rounded,
                    ),
                    const SizedBox(width: 24),
                    _buildScoreMetric(
                      'This Month',
                      '$monthlyPickups',
                      Icons.calendar_month_rounded,
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildScoreMetric(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ...existing code...
  Widget _buildQuickActions() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      // Show a message if no user is logged in
      return const Center(child: Text('No user logged in'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.2,
          children: [
            _buildActionCard(
              'Request Pickup',
              'Schedule waste collection',
              Icons.local_shipping_rounded,
              [const Color(0xFF1976D2), const Color(0xFF2196F3)],
              AppRoutes.wastepickupformupdated,
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('pickup_requests')
                  .where('userId', isEqualTo: currentUserId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildActionCard(
                    'Track Requests',
                    'No active pickups',
                    Icons.track_changes_rounded,
                    [const Color(0xFF9E9E9E), const Color(0xFFBDBDBD)],
                    '',
                    onTap: null,
                  );
                }

                // Find the first 'in_progress' request if any
                QueryDocumentSnapshot? inProgressRequest;
                for (var doc in snapshot.data!.docs) {
                  if (doc.get('status') == 'in_progress') {
                    inProgressRequest = doc;
                    break;
                  }
                }

                final hasInProgress = inProgressRequest != null;

                return _buildActionCard(
                  'Track Requests',
                  hasInProgress
                      ? 'Monitor pickup status'
                      : 'No pickup in progress',
                  Icons.track_changes_rounded,
                  hasInProgress
                      ? [const Color(0xFF388E3C), const Color(0xFF4CAF50)]
                      : [const Color(0xFF9E9E9E), const Color(0xFFBDBDBD)],
                  '',
                  onTap: hasInProgress
                      ? () {
                          Navigator.pushNamed(
                            context,
                            '/user-tracking',
                            arguments: {
                              'requestId': inProgressRequest!.id,
                              'userId': currentUserId,
                            },
                          );
                        }
                      : null,
                );
              },
            ),
            _buildActionCard(
              'Pickup History',
              'View past collections',
              Icons.history_rounded,
              [const Color(0xFF7B1FA2), const Color(0xFF9C27B0)],
              AppRoutes.pickuphistory,
            ),
            _buildActionCard(
              'EcoMarket',
              'explore eco-friendly products',
              Icons.shopping_bag_outlined,
              [const Color(0xFFFF8F00), const Color(0xFFFFC107)],
              AppRoutes.markethomescreen,
            ),
          ],
        ),
      ],
    );
  }
  // ...existing code...

  Widget _buildActionCard(
    String title,
    String subtitle,
    IconData icon,
    List<Color> colors,
    String route, {
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap:
              onTap ??
              () {
                if (route.isNotEmpty) {
                  Navigator.pushNamed(context, route);
                }
              },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 32),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentPickups() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      return const Text('User not logged in');
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.history_rounded,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Recent Requests',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('pickup_requests')
                .where('status', isEqualTo: 'completed')
                .where('userId', isEqualTo: currentUserId)
                .orderBy('updatedAt', descending: true) // Use updatedAt to sort
                .limit(3)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.docs.isEmpty) {
                return const Text('No completed requests yet.');
              }

              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final data = doc.data()! as Map<String, dynamic>;

                  final collector =
                      data['collectorName'] ?? 'Unknown Collector';

                  final userTown = data['userTown'] ?? 'Unknown Town';
                  final Timestamp? updatedTimestamp = data['updatedAt'];
                  String timeAgo = 'unknown time';

                  if (updatedTimestamp != null) {
                    final updatedDate = updatedTimestamp.toDate();
                    timeAgo = _formatTimeAgo(updatedDate);
                  }

                  return _buildPickupItem(
                    collector,
                    userTown,
                    'Completed • $timeAgo',
                    Icons.check_circle,
                    Colors.green,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // Helper to format "time ago" string
  String _formatTimeAgo(DateTime dateTime) {
    final Duration diff = DateTime.now().difference(dateTime);
    if (diff.inDays >= 1) {
      return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    } else if (diff.inHours >= 1) {
      return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    } else if (diff.inMinutes >= 1) {
      return '${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'just now';
    }
  }

  Widget _buildPickupItem(
    String collector,
    String userTown,
    String status,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  collector,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                Text(
                  userTown,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
        ],
      ),
    );
  }

  Widget _buildPickupGuidelines() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
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
                child: Icon(
                  Icons.info_outline_rounded,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Pickup Guidelines',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5E20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildGuidelineItem(
            'Prepare your waste',
            'Sort items into categories: recyclables, organic, electronic, hazardous.',
            Icons.sort_rounded,
          ),
          _buildGuidelineItem(
            'Schedule in advance',
            'Book pickups at least 24 hours ahead for better availability.',
            Icons.schedule_rounded,
          ),
          _buildGuidelineItem(
            'Be available',
            'Stay accessible during the scheduled pickup window.',
            Icons.person_pin_circle_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelineItem(String title, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF26A69A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: const Color(0xFF26A69A), size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
