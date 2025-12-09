import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> updateSortScore(String category) async {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId == null) return;

  // Define how much each category is worth
  final points = getPointsForCategory(category);

  final userDoc = FirebaseFirestore.instance.collection('users').doc(userId);

  await FirebaseFirestore.instance.runTransaction((transaction) async {
    final snapshot = await transaction.get(userDoc);
    final currentScore = snapshot.data()?['sortScore'] ?? 0;

    transaction.update(userDoc, {'sortScore': currentScore + points});
  });
}

// Helper method to determine point value

int getPointsForCategory(String category) {
  switch (category.toLowerCase()) {
    case 'plastic':
      return 10;
    case 'glass':
      return 8;
    case 'metal':
      return 7;
    case 'cardboard':
      return 6;
    case 'paper':
      return 5;
    case 'trash':
      return 6;
    default:
      return 0;
  }
}
