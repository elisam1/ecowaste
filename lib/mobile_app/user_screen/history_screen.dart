import 'package:flutter/material.dart';
import 'package:flutter_application_1/mobile_app/constants/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pickup History'),
        backgroundColor: AppColors.navy,
      ),
      backgroundColor: AppColors.background,
      body: uid == null
          ? const Center(child: Text('Not logged in'))
          : Padding(
              padding: const EdgeInsets.all(20),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('pickup_requests')
                    .where('userId', isEqualTo: uid)
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: \\${snapshot.error}'));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(child: Text('No pickup history yet.'));
                  }
                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, idx) {
                      final data = docs[idx].data() as Map<String, dynamic>;
                      final status = data['status'] ?? 'unknown';
                      final address = data['userTown'] ?? 'Unknown';
                      final date = (data['timestamp'] as Timestamp?)?.toDate();
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          leading: Icon(
                            status == 'completed'
                                ? Icons.check_circle
                                : Icons.local_shipping,
                            color: status == 'completed'
                                ? AppColors.success
                                : AppColors.blue,
                          ),
                          title: Text(address),
                          subtitle: Text(
                            date != null
                                ? '${date.day}/${date.month}/${date.year} - ${status.toString().toUpperCase()}'
                                : status.toString().toUpperCase(),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
    );
  }
}
