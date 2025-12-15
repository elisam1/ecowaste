import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/mobile_app/constants/app_constants.dart';

/// Model for tracking weight and volume of waste pickups
class PickupMeasurement {
  final double weightKg;
  final double volumeM3; // cubic meters
  final String unit; // kg, lbs, m3, etc.
  final DateTime recordedAt;

  PickupMeasurement({
    required this.weightKg,
    required this.volumeM3,
    this.unit = 'kg',
    required this.recordedAt,
  });

  factory PickupMeasurement.fromMap(Map<String, dynamic> map) {
    return PickupMeasurement(
      weightKg: (map['weightKg'] ?? 0.0).toDouble(),
      volumeM3: (map['volumeM3'] ?? 0.0).toDouble(),
      unit: map['unit'] ?? 'kg',
      recordedAt: (map['recordedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'weightKg': weightKg,
      'volumeM3': volumeM3,
      'unit': unit,
      'recordedAt': Timestamp.fromDate(recordedAt),
    };
  }

  bool isValid() {
    return weightKg >= AppConstants.minWeightKg &&
        weightKg <= AppConstants.maxWeightKg &&
        volumeM3 >= AppConstants.minVolumeM3 &&
        volumeM3 <= AppConstants.maxVolumeM3;
  }
}

/// Model for photo verification of completed pickups
class PickupVerification {
  final String id;
  final String pickupRequestId;
  final String collectorId;
  final String userId;
  final List<String> photoUrls; // Before and after photos
  final String photoDescription;
  final PickupMeasurement? measurement;
  final bool verified; // By admin or system
  final String verificationStatus; // pending, verified, rejected
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime? completedAt;
  final Map<String, dynamic>? metadata;

  PickupVerification({
    required this.id,
    required this.pickupRequestId,
    required this.collectorId,
    required this.userId,
    required this.photoUrls,
    this.photoDescription = '',
    this.measurement,
    this.verified = false,
    this.verificationStatus = 'pending',
    this.rejectionReason,
    required this.createdAt,
    this.completedAt,
    this.metadata,
  });

  /// Create from Firestore document
  factory PickupVerification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PickupVerification(
      id: doc.id,
      pickupRequestId: data['pickupRequestId'] ?? '',
      collectorId: data['collectorId'] ?? '',
      userId: data['userId'] ?? '',
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      photoDescription: data['photoDescription'] ?? '',
      measurement: data['measurement'] != null
          ? PickupMeasurement.fromMap(data['measurement'])
          : null,
      verified: data['verified'] ?? false,
      verificationStatus: data['verificationStatus'] ?? 'pending',
      rejectionReason: data['rejectionReason'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      metadata: data['metadata'],
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'pickupRequestId': pickupRequestId,
      'collectorId': collectorId,
      'userId': userId,
      'photoUrls': photoUrls,
      'photoDescription': photoDescription,
      'measurement': measurement?.toMap(),
      'verified': verified,
      'verificationStatus': verificationStatus,
      'rejectionReason': rejectionReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'metadata': metadata,
    };
  }

  /// Validate verification data
  bool isValid() {
    // Must have at least 2 photos
    if (photoUrls.length < 2) return false;

    // Description must be provided
    if (photoDescription.isEmpty) return false;

    // Measurement should be valid if provided
    if (measurement != null && !measurement!.isValid()) return false;

    return true;
  }

  /// Check if verification is complete
  bool isComplete() {
    return verificationStatus == 'verified' && verified;
  }

  /// Get verification progress percentage (0-100)
  int getVerificationProgress() {
    int progress = 0;

    // Photos uploaded
    if (photoUrls.isNotEmpty) progress += 40;

    // Description provided
    if (photoDescription.isNotEmpty) progress += 20;

    // Measurement recorded
    if (measurement != null && measurement!.isValid()) progress += 20;

    // Verified
    if (verified) progress += 20;

    return progress;
  }

  /// Copy with modifications
  PickupVerification copyWith({
    String? id,
    String? pickupRequestId,
    String? collectorId,
    String? userId,
    List<String>? photoUrls,
    String? photoDescription,
    PickupMeasurement? measurement,
    bool? verified,
    String? verificationStatus,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? completedAt,
    Map<String, dynamic>? metadata,
  }) {
    return PickupVerification(
      id: id ?? this.id,
      pickupRequestId: pickupRequestId ?? this.pickupRequestId,
      collectorId: collectorId ?? this.collectorId,
      userId: userId ?? this.userId,
      photoUrls: photoUrls ?? this.photoUrls,
      photoDescription: photoDescription ?? this.photoDescription,
      measurement: measurement ?? this.measurement,
      verified: verified ?? this.verified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'PickupVerification(id: $id, status: $verificationStatus, photos: ${photoUrls.length})';
  }
}
