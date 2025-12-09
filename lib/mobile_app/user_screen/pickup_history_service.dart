// import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/mobile_app/chat_page/chat_page.dart';
import 'package:intl/intl.dart';

class PickupHistoryScreen extends StatefulWidget {
  final String userId;

  const PickupHistoryScreen({super.key, required this.userId});

  @override
  State<PickupHistoryScreen> createState() => _PickupHistoryScreenState();
}

class _PickupHistoryScreenState extends State<PickupHistoryScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FFFE),
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Pickup History',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2E7D32), Color(0xFF388E3C)],
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('pickup_requests')
            .where('userId', isEqualTo: widget.userId)
            .where('status', isEqualTo: 'completed')
            .orderBy('userConfirmedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Oops! Something went wrong',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please check your connection and try again',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.red.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: FadeTransition(
                opacity: _animationController,
                child: Container(
                  margin: const EdgeInsets.all(32),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.shade100,
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.history_outlined,
                          size: 64,
                          color: Colors.greenAccent,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No pickup history yet',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your completed pickup requests will appear here.\nOnce you have completed pickups, you can view and manage them.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final requests = snapshot.data!.docs;

          return AnimatedList(
            padding: const EdgeInsets.all(16),
            initialItemCount: requests.length,
            itemBuilder: (context, index, animation) {
              if (index >= requests.length) return const SizedBox.shrink();

              final request = requests[index];
              final data = request.data() as Map<String, dynamic>;

              return SlideTransition(
                position: animation.drive(
                  Tween(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeOutCubic)),
                ),
                child: HistoryCard(
                  requestId: request.id,
                  requestData: data,
                  onDelete: () => _deleteHistoryItem(request.id),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _deleteHistoryItem(String requestId) async {
    try {
      // Show confirmation dialog
      bool? shouldDelete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red.shade600),
              const SizedBox(width: 8),
              const Text('Delete History'),
            ],
          ),
          content: const Text(
            'Are you sure you want to delete this history item? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Yes, Delete'),
            ),
          ],
        ),
      );

      if (shouldDelete == true) {
        await _firestore.collection('pickup_requests').doc(requestId).delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('History item deleted successfully'),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Failed to delete history item: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }
}

class HistoryCard extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> requestData;
  final VoidCallback onDelete;

  const HistoryCard({
    super.key,
    required this.requestId,
    required this.requestData,
    required this.onDelete,
  });

  @override
  State<HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<HistoryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pickupDate = (widget.requestData['pickupDate'] as Timestamp).toDate();
    final completedAt = widget.requestData['updatedAt'] != null
        ? (widget.requestData['updatedAt'] as Timestamp).toDate()
        : pickupDate;
    final collectorId = widget.requestData['collectorId'] as String?;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _isPressed
                    ? Colors.green.shade200
                    : Colors.grey.shade200,
                blurRadius: _isPressed ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: _isPressed ? Colors.green.shade300 : Colors.transparent,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row with Status and Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green.shade100, Colors.green.shade50],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.green.shade800.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: Colors.green.shade800,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'COMPLETED',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.green.shade800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_available,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM dd, yyyy').format(completedAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Original Pickup Details
                _buildInfoRow(
                  Icons.access_time_rounded,
                  'Original Pickup Time',
                  DateFormat('MMM dd, yyyy - hh:mm a').format(pickupDate),
                  Colors.blue.shade600,
                ),

                const SizedBox(height: 12),

                _buildInfoRow(
                  Icons.location_on_rounded,
                  'Location',
                  '${widget.requestData['userTown']}',
                  Colors.red.shade600,
                ),

                const SizedBox(height: 12),

                _buildInfoRow(
                  Icons.event_available,
                  'Completed On',
                  DateFormat('MMM dd, yyyy - hh:mm a').format(completedAt),
                  Colors.green.shade600,
                ),

                const SizedBox(height: 16),

                // Collector Info (if assigned)
                if (collectorId != null)
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('collectors')
                        .doc(collectorId)
                        .get(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final collectorData =
                            snapshot.data!.data() as Map<String, dynamic>;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.purple.shade200),
                          ),
                          child: _buildInfoRow(
                            Icons.person_rounded,
                            'Collector',
                            '${collectorData['name']} - ${collectorData['phone']}',
                            Colors.purple.shade600,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Chat button (only if collector is assigned and not cancelled)
                    if (collectorId != null && widget.requestData['status'] != 'cancelled')
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              '/chat',
                              arguments: {
                                'collectorId': collectorId,
                                'collectorName':
                                    widget.requestData['collectorName'] ??
                                    'Collector',
                                'requestId': widget.requestId,
                                'userName':
                                    widget.requestData['userName'] ?? 'User',
                              },
                            );
                          },
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          label: const Text('Chat'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 2,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    // View Details button
                    // Expanded(
                    //   child: OutlinedButton.icon(
                    //     onPressed: () => _showHistoryDetails(context),
                    //     icon: const Icon(Icons.info_outline, size: 18),
                    //     label: const Text('Details'),
                    //     style: OutlinedButton.styleFrom(
                    //       foregroundColor: Colors.blue.shade600,
                    //       side: BorderSide(color: Colors.blue.shade300),
                    //       shape: RoundedRectangleBorder(
                    //         borderRadius: BorderRadius.circular(10),
                    //       ),
                    //       padding: const EdgeInsets.symmetric(vertical: 12),
                    //     ),
                    //   ),
                    // ),
                    const SizedBox(width: 12),

                    // Delete button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onDelete,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade600,
                          side: BorderSide(color: Colors.red.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    Color iconColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showHistoryDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.green.shade50],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.history_rounded,
                      color: Colors.green.shade600,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'History Details',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.green.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Request ID', widget.requestId),
                    _buildDetailRow(
                      'Name',
                      widget.requestData['userName'] ?? 'N/A',
                    ),
                    _buildDetailRow(
                      'Phone',
                      widget.requestData['userPhone'] ?? 'N/A',
                    ),
                    _buildDetailRow(
                      'Town',
                      widget.requestData['userTown'] ?? 'N/A',
                    ),
                    _buildDetailRow(
                      'Status',
                      widget.requestData['status'] ?? 'N/A',
                    ),
                    _buildDetailRow(
                      'Original Request Date',
                      widget.requestData['createdAt'] != null
                          ? DateFormat('MMM dd, yyyy - hh:mm a').format(
                              (widget.requestData['createdAt'] as Timestamp)
                                  .toDate(),
                            )
                          : 'N/A',
                    ),
                    _buildDetailRow(
                      'Scheduled Pickup',
                      widget.requestData['pickupDate'] != null
                          ? DateFormat('MMM dd, yyyy - hh:mm a').format(
                              (widget.requestData['pickupDate'] as Timestamp)
                                  .toDate(),
                            )
                          : 'N/A',
                    ),
                    if (widget.requestData['updatedAt'] != null)
                      _buildDetailRow(
                        'Completed At',
                        DateFormat('MMM dd, yyyy - hh:mm a').format(
                          (widget.requestData['updatedAt'] as Timestamp)
                              .toDate(),
                        ),
                      ),
                    if (widget.requestData['collectorName'] != null)
                      _buildDetailRow(
                        'Completed By',
                        widget.requestData['collectorName'],
                      ),
                    if (widget.requestData['wasteCategories'] != null)
                      _buildDetailRow(
                        'Waste Categories',
                        List<String>.from(
                          widget.requestData['wasteCategories'] ?? [],
                        ).join(', '),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:intl/intl.dart';

// class HistoryScreen extends StatelessWidget {
//   final String userId;

//   const HistoryScreen({super.key, required this.userId});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF8FFFE),
//       appBar: AppBar(
//         title: const Text('Completed History'),
//         centerTitle: true,
//         backgroundColor: const Color(0xFF2E7D32),
//         foregroundColor: Colors.white,
//       ),
//       body: StreamBuilder<QuerySnapshot>(
//         stream: FirebaseFirestore.instance
//             .collection('pickup_requests')
//             .where('userId', isEqualTo: userId)
//             .where('status', isEqualTo: 'completed')
//             .orderBy('updatedAt', descending: true)
//             .snapshots(),
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(
//               child: CircularProgressIndicator(
//                 valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
//               ),
//             );
//           }

//           if (snapshot.hasError) {
//             return Center(
//               child: Text(
//                 'Error loading history: ${snapshot.error}',
//                 style: const TextStyle(color: Colors.red),
//               ),
//             );
//           }

//           if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//             return const Center(
//               child: Text(
//                 'No completed pickups yet.',
//                 style: TextStyle(fontSize: 16),
//               ),
//             );
//           }

//           final historyDocs = snapshot.data!.docs;

//           return ListView.builder(
//             padding: const EdgeInsets.all(16),
//             itemCount: historyDocs.length,
//             itemBuilder: (context, index) {
//               final data = historyDocs[index].data() as Map<String, dynamic>;
//               final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();

//               return Container(
//                 margin: const EdgeInsets.only(bottom: 16),
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: Colors.green.shade50,
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(color: Colors.green.shade200),
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Row(
//                       children: [
//                         Icon(Icons.check_circle, color: Colors.green),
//                         SizedBox(width: 8),
//                         Text(
//                           'Pickup Completed',
//                           style: TextStyle(
//                             fontWeight: FontWeight.bold,
//                             color: Colors.green,
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 8),
//                     Text('Request ID: ${historyDocs[index].id}'),
//                     if (updatedAt != null)
//                       Text(
//                         'Completed On: ${DateFormat('MMM dd, yyyy – hh:mm a').format(updatedAt)}',
//                       ),
//                     const SizedBox(height: 8),
//                     Text('Location: ${data['userTown'] ?? 'Unknown'}'),
//                     Text('Collector: ${data['collectorName'] ?? 'N/A'}'),
//                     const SizedBox(height: 8),
//                     Text(
//                       'Waste Categories: ${List<String>.from(data['wasteCategories'] ?? []).join(', ')}',
//                     ),
//                   ],
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }
