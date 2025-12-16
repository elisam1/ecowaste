import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/mobile_app/provider/notification_provider.dart';
import 'package:flutter_application_1/mobile_app/provider/provider.dart';
import 'package:flutter_application_1/mobile_app/routes/app_route.dart';
import 'package:flutter_application_1/mobile_app/service/offline_persistence_service.dart';
import 'package:flutter_application_1/mobile_app/widget/offline_indicator.dart';
import 'package:provider/provider.dart';

class RedesignedHomePage extends StatefulWidget {
  const RedesignedHomePage({super.key});

  @override
  State<RedesignedHomePage> createState() => _RedesignedHomePageState();
}

class _RedesignedHomePageState extends State<RedesignedHomePage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final sort = Provider.of<SortScoreProvider>(context, listen: false);
        sort.calculatePickupStats(userId);

        final notif = Provider.of<NotificationProvider>(context, listen: false);
        notif.initialize(userId, 'user');
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? 'Welcome';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: FadeTransition(
        opacity: _fadeIn,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: OfflineIndicator()),
            SliverToBoxAdapter(child: _Header(name: name)),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            const SliverToBoxAdapter(child: _ConnectivityBanner()),
            SliverToBoxAdapter(child: const SizedBox(height: 16)),
            SliverToBoxAdapter(child: _PrimaryCtas()),
            SliverToBoxAdapter(child: const SizedBox(height: 8)),
            SliverToBoxAdapter(child: _StatusStrip()),
            SliverToBoxAdapter(child: const SizedBox(height: 12)),
            SliverToBoxAdapter(child: _NextPickupCard()),
            SliverToBoxAdapter(child: const SizedBox(height: 16)),
            SliverToBoxAdapter(child: _ImpactRow()),
            SliverToBoxAdapter(child: const SizedBox(height: 16)),
            SliverToBoxAdapter(child: _GhanaDigitalCentresPromo()),
            SliverToBoxAdapter(child: const SizedBox(height: 16)),
            SliverToBoxAdapter(child: _EcoMarketPromo()),
            SliverToBoxAdapter(child: const SizedBox(height: 16)),
            SliverToBoxAdapter(child: _RecentRequests()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        label: const Text('Notifications'),
        icon: Icon(
          Icons.notifications_outlined,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String name;
  const _Header({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F2A44), Color(0xFF30489C), Color(0xFF4C6FFF)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hi, $name',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Let\'s keep your city clean!',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Consumer<NotificationProvider>(
                      builder: (context, notif, _) {
                        final count = notif.unreadCount;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pushNamed(
                                context,
                                '/user-notifications',
                              ),
                              icon: const Icon(
                                Icons.notifications_outlined,
                                color: Colors.white,
                              ),
                            ),
                            if (count > 0)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade600,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    count > 99 ? '99+' : '$count',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.profile),
                      icon: const Icon(
                        Icons.person_outline,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Selector<SortScoreProvider, Map<String, dynamic>>(
              selector: (context, p) => {
                'totalPickups': p.totalPickups,
                'monthlyPickups': p.monthlyPickups,
                'sortScore': p.sortScore,
              },
              builder: (context, data, _) {
                return Row(
                  children: [
                    _ChipStat(
                      label: 'Total Pickups',
                      value: '${data['totalPickups']}',
                      icon: Icons.done_all_rounded,
                    ),
                    const SizedBox(width: 8),
                    _ChipStat(
                      label: 'This Month',
                      value: '${data['monthlyPickups']}',
                      icon: Icons.calendar_month,
                    ),
                    const SizedBox(width: 8),
                    _ChipStat(
                      label: 'Sort Score',
                      value: '${data['sortScore']}',
                      icon: Icons.stars_rounded,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectivityBanner extends StatelessWidget {
  const _ConnectivityBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: StreamBuilder<ConnectivityResult>(
        stream: Connectivity().onConnectivityChanged,
        builder: (context, snapshot) {
          final status = snapshot.data;
          final isOnline = status != ConnectivityResult.none;
          final color = isOnline ? const Color(0xFF30489C) : Colors.red;
          final text = isOnline
              ? 'Online • Connected'
              : 'Offline • Check your connection';
          final icon = isOnline ? Icons.wifi : Icons.wifi_off;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color.withValues(alpha: 0.9), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!isOnline)
                  TextButton(
                    onPressed: () async {
                      await Connectivity().checkConnectivity();
                    },
                    child: const Text('Retry'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('pickup_requests')
            .where('userId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          final activeCount = snapshot.hasData
              ? snapshot.data!.docs.where((d) {
                  final status = (d.data() as Map<String, dynamic>)['status'];
                  return status == 'in_progress' || status == 'pending';
                }).length
              : 0;

          final message = activeCount > 0
              ? 'You have $activeCount active pickup${activeCount > 1 ? 's' : ''} in progress!'
              : 'Ready to schedule? Tap "Request Pickup" above to get started.';

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  activeCount > 0 ? Icons.local_shipping : Icons.flash_on,
                  color: const Color(0xFF30489C),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ChipStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _ChipStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
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

class _PrimaryCtas extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _BigCta(
              title: 'Request Pickup',
              subtitle: 'Schedule collection',
              icon: Icons.local_shipping_rounded,
              colors: const [Color(0xFF1F7DD4), Color(0xFF4C9BFF)],
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.wastepickupformupdated,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _BigCta(
              title: 'Track',
              subtitle: 'Active request',
              icon: Icons.track_changes_rounded,
              colors: const [Color(0xFF6E3FF2), Color(0xFF9B6BFF)],
              onTap: () async {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid == null) return;
                final snap = await FirebaseFirestore.instance
                    .collection('pickup_requests')
                    .where('userId', isEqualTo: uid)
                    .orderBy('timestamp', descending: true)
                    .limit(10)
                    .get();
                DocumentSnapshot? doc;
                try {
                  doc = snap.docs.firstWhere((d) {
                    final status = d.data()['status'] ?? '';
                    return status == 'in_progress' || status == 'pending';
                  });
                } catch (e) {
                  doc = null;
                }
                if (doc != null) {
                  final id = doc.id;
                  // ignore: use_build_context_synchronously
                  Navigator.pushNamed(
                    context,
                    '/user-tracking',
                    arguments: {'requestId': id, 'userId': uid},
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BigCta extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;
  const _BigCta({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NextPickupCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('pickup_requests')
              .where('userId', isEqualTo: uid)
              .orderBy('timestamp', descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'No active pickup. Schedule one now to get started.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              );
            }

            DocumentSnapshot? active;
            try {
              active = snapshot.data!.docs.firstWhere((d) {
                final data = d.data() as Map<String, dynamic>?;
                final status = data?['status'] as String?;
                return status == 'in_progress' || status == 'pending';
              });
            } catch (e) {
              active = null;
            }

            if (active == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.info_outline,
                          color: Colors.orange.shade600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'No active pickup right now',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Schedule a pickup to see real-time tracking and status updates here.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoutes.wastepickupformupdated,
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Schedule Pickup'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF30489C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            final data = active.data()! as Map<String, dynamic>;
            final status = data['status'] ?? 'pending';
            final address = data['userTown'] ?? 'Unknown';
            return Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.local_shipping,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next Pickup • ${status.toString().toUpperCase()}',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final id = active?.id;
                    if (id != null) {
                      Navigator.pushNamed(
                        context,
                        '/user-tracking',
                        arguments: {'requestId': id, 'userId': uid},
                      );
                    }
                  },
                  child: const Text('Track'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ImpactRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('pickup_requests')
            .where('userId', isEqualTo: uid)
            .where('status', isEqualTo: 'completed')
            .snapshots(),
        builder: (context, snapshot) {
          int completedCount = 0;

          if (snapshot.hasData && snapshot.data != null) {
            // Cache data when available
            final requests = snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return data;
            }).toList();

            completedCount = requests.length;

            // Cache for offline use
            OfflinePersistenceService().cachePickupRequests(requests);
          } else if (snapshot.connectionState == ConnectionState.waiting) {
            // Try to use cached data while loading
            Future(() async {
              final cached = await OfflinePersistenceService()
                  .getCachedPickupRequests();
              if (cached != null) {
                completedCount = cached.length;
              }
            });
          }

          final impact = completedCount * 5; // Assume 5kg per pickup

          return Row(
            children: [
              Expanded(
                child: _MiniCard(
                  color: const Color(0xFFE6EBFF),
                  iconColor: const Color(0xFF30489C),
                  icon: Icons.eco_rounded,
                  title: 'Your Impact',
                  subtitle: '~${impact}kg waste collected',
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Environmental Impact'),
                        content: Text(
                          'You\'ve completed $completedCount pickups!\n\n'
                          'Estimated waste diverted from landfills: ${impact}kg\n\n'
                          'Keep up the great work! Every pickup helps create a cleaner environment.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniCard(
                  color: const Color(0xFFF4E8FF),
                  iconColor: const Color(0xFF6E3FF2),
                  icon: Icons.lightbulb_outline,
                  title: 'Recycling Tip',
                  subtitle: 'Glass is 100% recyclable',
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Recycling Tips'),
                        content: const Text(
                          '♻️ Rinse containers before recycling\n'
                          '♻️ Remove caps and lids\n'
                          '♻️ Flatten cardboard boxes\n'
                          '♻️ Keep plastics separate\n'
                          '♻️ No plastic bags in bins\n\n'
                          'Proper sorting helps maximize recycling!',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Got it'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final Color color;
  final Color iconColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _MiniCard({
    required this.color,
    required this.iconColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GhanaDigitalCentresPromo extends StatefulWidget {
  @override
  State<_GhanaDigitalCentresPromo> createState() =>
      _GhanaDigitalCentresPromoState();
}

class _GhanaDigitalCentresPromoState extends State<_GhanaDigitalCentresPromo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _fadeAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF1F2A44),
                      Color(0xFF30489C),
                      Color(0xFF4C6FFF),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4C6FFF).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
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
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.computer,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ghana Digital Centres',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Empowering Communities',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '🎓 Free Digital Skills Training\n'
                      '💻 Access to Computers & Internet\n'
                      '📱 Technology Education Programs\n'
                      '🌍 Building Digital Ghana Together',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Ghana Digital Centres'),
                                  content: const SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'About the Programme',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        SizedBox(height: 12),
                                        Text(
                                          'Ghana Digital Centres are community-based facilities providing:'
                                          '\n\n• Free access to computers and internet'
                                          '\n• Digital literacy training'
                                          '\n• Skills development programs'
                                          '\n• E-government services'
                                          '\n• Business support and entrepreneurship'
                                          '\n\nThese centres are part of Ghana\'s digital transformation agenda, '
                                          'bridging the digital divide and empowering citizens with technology skills.',
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'Visit your nearest Digital Centre today!',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF30489C),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            icon: const Icon(Icons.info_outline, size: 18),
                            label: const Text('Learn More'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF30489C),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EcoMarketPromo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF7A59), Color(0xFFFFB199)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFA726).withOpacity(0.25),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.shopping_bag_outlined, color: Colors.white),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Explore eco-friendly products in EcoMarket',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.markethomescreen),
              child: const Text('Shop', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentRequests extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
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
                  child: Icon(
                    Icons.history_rounded,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Recent Requests',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B5E20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('pickup_requests')
                  .where('status', isEqualTo: 'completed')
                  .where('userId', isEqualTo: uid)
                  .limit(3)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Text('No completed requests yet.');
                }
                return Column(
                  children: docs.map((doc) {
                    final data = doc.data()! as Map<String, dynamic>;
                    final town = data['userTown'] ?? 'Unknown Town';
                    final collector = data['collectorName'] ?? 'Unknown';
                    return _RecentItem(
                      title: collector,
                      subtitle: town,
                      icon: Icons.check_circle,
                      color: Colors.green,
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _RecentItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
