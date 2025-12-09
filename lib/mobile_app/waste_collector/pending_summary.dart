import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SummaryCardsRow extends StatelessWidget {
  final String collectorId;

  const SummaryCardsRow({super.key, required this.collectorId});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: PendingSummaryCard(collectorId: collectorId)),
        const SizedBox(width: 12),
        Expanded(child: MissedRequestsSummaryCard(collectorId: collectorId)),
      ],
    );
  }
}

class PendingSummaryCard extends StatelessWidget {
  final String collectorId;

  const PendingSummaryCard({super.key, required this.collectorId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pickup_requests')
          .where('collectorId', isEqualTo: collectorId)
          .where(
            'status',
            whereIn: [
              'in_progress',
              'accepted',
              'pending',
              'pending_confirmation',
            ],
          )
          .snapshots(),
      builder: (context, snapshot) {
        String count = '...';
        if (snapshot.hasError) {
          count = 'Err';
        } else if (snapshot.hasData) {
          count = snapshot.data!.docs.length.toString();
        }

        return _buildSummaryCard(
          title: 'Pending',
          count: count,
          icon: Icons.pending_actions,
          color: Colors.orange,
        );
      },
    );
  }
}

class CollectorTotalPickupsText extends StatelessWidget {
  final String collectorId;

  const CollectorTotalPickupsText({super.key, required this.collectorId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pickup_requests')
          .where('collectorId', isEqualTo: collectorId)
          .where('status', isEqualTo: 'completed')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            "Err",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          );
        }
        if (!snapshot.hasData) {
          return const Text(
            "...",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          );
        }

        final total = snapshot.data!.docs.length;
        return Text(
          '$total',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        );
      },
    );
  }
}

class CompletionRateText extends StatelessWidget {
  final String collectorId;
  const CompletionRateText({super.key, required this.collectorId});

  @override
  Widget build(BuildContext context) {
    final pickupsRef = FirebaseFirestore.instance.collection('pickup_requests');

    return StreamBuilder<QuerySnapshot>(
      stream: pickupsRef
          .where('collectorId', isEqualTo: collectorId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            'Err',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Text(
            '...',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          );
        }

        final allPickups = snapshot.data!.docs;
        final total = allPickups.length;
        final completed = allPickups
            .where((doc) => doc['status'] == 'completed')
            .length;

        final percent = total > 0
            ? ((completed / total) * 100).toStringAsFixed(1)
            : '0';

        return Text(
          '$percent%',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        );
      },
    );
  }
}

class MissedRequestsSummaryCard extends StatelessWidget {
  final String collectorId;

  const MissedRequestsSummaryCard({super.key, required this.collectorId});

  @override
  Widget build(BuildContext context) {
    // Get current time
    final now = DateTime.now();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pickup_requests')
          .where('collectorId', isEqualTo: collectorId)
          .where('status', whereIn: ['pending', 'in_progress', 'accepted'])
          .snapshots(),
      builder: (context, snapshot) {
        String count = '...';

        if (snapshot.hasError) {
          count = 'Err';
        } else if (snapshot.hasData) {
          print(
            'DEBUG: Total pending/in_progress/accepted requests found: ${snapshot.data!.docs.length}',
          );

          final missedDocs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final pickupDate = data['pickupDate'];
            
            if (pickupDate is Timestamp) {
              final scheduledDate = pickupDate.toDate();
              
              // Check if the scheduled pickup date has passed (is in the past)
              // and the request is not completed
              final isPastDate = scheduledDate.isBefore(now);
              
              // Don't count as missed if collector has completed but user hasn't confirmed
              // (status would be 'pending_confirmation' which is not in our whereIn clause)
              
              return isPastDate;
            }

            return false;
          }).toList();

          print('DEBUG: Missed requests: ${missedDocs.length}');
          count = missedDocs.length.toString();
        }

        return _buildSummaryCard(
          title: 'Missed Requests',
          count: count,
          icon: Icons.schedule,
          color: Colors.red,
        );
      },
    );
  }
}

// REUSABLE CARD WIDGET
Widget _buildSummaryCard({
  required String title,
  required String count,
  required IconData icon,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          spreadRadius: 1,
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 12),
        Text(
          count,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    ),
  );
}
