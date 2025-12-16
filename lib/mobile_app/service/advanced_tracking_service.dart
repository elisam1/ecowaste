import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class TrackingUpdate {
  final String pickupId;
  final String status;
  final Position? location;
  final DateTime timestamp;
  final String? estimatedArrival;
  final String? collectorName;
  final String? collectorPhone;
  final double? distance;

  TrackingUpdate({
    required this.pickupId,
    required this.status,
    this.location,
    required this.timestamp,
    this.estimatedArrival,
    this.collectorName,
    this.collectorPhone,
    this.distance,
  });

  Map<String, dynamic> toMap() {
    return {
      'pickupId': pickupId,
      'status': status,
      'location': location != null
          ? {'latitude': location!.latitude, 'longitude': location!.longitude}
          : null,
      'timestamp': timestamp.toIso8601String(),
      'estimatedArrival': estimatedArrival,
      'collectorName': collectorName,
      'collectorPhone': collectorPhone,
      'distance': distance,
    };
  }

  factory TrackingUpdate.fromMap(Map<String, dynamic> map) {
    return TrackingUpdate(
      pickupId: map['pickupId'],
      status: map['status'],
      location: map['location'] != null
          ? Position(
              latitude: map['location']['latitude'],
              longitude: map['location']['longitude'],
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              heading: 0,
              speed: 0,
              speedAccuracy: 0,
              headingAccuracy: 0,
              altitudeAccuracy: 0,
            )
          : null,
      timestamp: DateTime.parse(map['timestamp']),
      estimatedArrival: map['estimatedArrival'],
      collectorName: map['collectorName'],
      collectorPhone: map['collectorPhone'],
      distance: map['distance']?.toDouble(),
    );
  }
}

class AdvancedTrackingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<TrackingUpdate> trackPickupRealTime(String pickupId) async* {
    try {
      // Listen to pickup document changes
      final pickupStream = _firestore
          .collection('pickup_requests')
          .doc(pickupId)
          .snapshots();

      await for (final pickupSnapshot in pickupStream) {
        if (!pickupSnapshot.exists) continue;

        final pickupData = pickupSnapshot.data()!;
        final status = pickupData['status'] as String? ?? 'unknown';

        // Get collector information if assigned
        String? collectorName;
        String? collectorPhone;
        Position? collectorLocation;

        if (pickupData['collectorId'] != null) {
          final collectorDoc = await _firestore
              .collection('collectors')
              .doc(pickupData['collectorId'])
              .get();

          if (collectorDoc.exists) {
            final collectorData = collectorDoc.data()!;
            collectorName =
                collectorData['name'] ?? collectorData['businessName'];
            collectorPhone = collectorData['phone'];

            // Get collector's current location if available
            if (collectorData['currentLocation'] != null) {
              final locationData =
                  collectorData['currentLocation'] as Map<String, dynamic>;
              collectorLocation = Position(
                latitude: locationData['latitude'],
                longitude: locationData['longitude'],
                timestamp: DateTime.now(),
                accuracy: locationData['accuracy'] ?? 0,
                altitude: 0,
                heading: 0,
                speed: 0,
                speedAccuracy: 0,
                headingAccuracy: 0,
                altitudeAccuracy: 0,
              );
            }
          }
        }

        // Calculate ETA if collector is en route
        String? eta;
        double? distance;

        if (status == 'in_progress' &&
            collectorLocation != null &&
            pickupData['location'] != null) {
          final pickupLocation = pickupData['location'] as Map<String, dynamic>;
          final pickupLatLng = Position(
            latitude: pickupLocation['latitude'],
            longitude: pickupLocation['longitude'],
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            headingAccuracy: 0,
            altitudeAccuracy: 0,
          );

          distance = _calculateDistance(collectorLocation, pickupLatLng);
          eta = _calculateETA(distance, status);
        }

        final update = TrackingUpdate(
          pickupId: pickupId,
          status: status,
          location: collectorLocation,
          timestamp: DateTime.now(),
          estimatedArrival: eta,
          collectorName: collectorName,
          collectorPhone: collectorPhone,
          distance: distance,
        );

        yield update;

        // Send notification for status changes
        await _sendStatusNotification(pickupData, status, eta);
      }
    } catch (e) {
      debugPrint('Error tracking pickup: $e');
      yield TrackingUpdate(
        pickupId: pickupId,
        status: 'error',
        timestamp: DateTime.now(),
      );
    }
  }

  Future<void> updateCollectorLocation(
    String collectorId,
    Position position,
  ) async {
    try {
      await _firestore.collection('collectors').doc(collectorId).update({
        'currentLocation': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'timestamp': FieldValue.serverTimestamp(),
        },
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating collector location: $e');
    }
  }

  Future<void> updatePickupStatus(
    String pickupId,
    String newStatus, {
    String? collectorId,
    String? notes,
  }) async {
    try {
      final updateData = {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (collectorId != null) {
        updateData['collectorId'] = collectorId;
      }

      if (notes != null) {
        updateData['statusNotes'] = notes;
      }

      // Add status history
      final historyEntry = {
        'status': newStatus,
        'timestamp': FieldValue.serverTimestamp(),
        'collectorId': collectorId,
        'notes': notes,
      };

      await _firestore.collection('pickup_requests').doc(pickupId).update({
        ...updateData,
        'statusHistory': FieldValue.arrayUnion([historyEntry]),
      });
    } catch (e) {
      debugPrint('Error updating pickup status: $e');
      rethrow;
    }
  }

  Future<List<TrackingUpdate>> getPickupHistory(String pickupId) async {
    try {
      final pickupDoc = await _firestore
          .collection('pickup_requests')
          .doc(pickupId)
          .get();

      if (!pickupDoc.exists) return [];

      final data = pickupDoc.data()!;
      final history = data['statusHistory'] as List<dynamic>? ?? [];

      return history.map((entry) {
        final entryMap = entry as Map<String, dynamic>;
        return TrackingUpdate(
          pickupId: pickupId,
          status: entryMap['status'] ?? 'unknown',
          timestamp: (entryMap['timestamp'] as Timestamp).toDate(),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error getting pickup history: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getPickupAnalytics(String pickupId) async {
    try {
      final history = await getPickupHistory(pickupId);

      if (history.isEmpty) {
        return {
          'totalUpdates': 0,
          'averageTimeBetweenUpdates': 0,
          'statusChanges': [],
        };
      }

      final statusChanges = <String>[];
      var totalTimeBetweenUpdates = 0;
      var updateCount = 0;

      for (var i = 1; i < history.length; i++) {
        final current = history[i];
        final previous = history[i - 1];

        statusChanges.add('${previous.status} → ${current.status}');

        final timeDiff = current.timestamp
            .difference(previous.timestamp)
            .inMinutes;
        totalTimeBetweenUpdates += timeDiff;
        updateCount++;
      }

      return {
        'totalUpdates': history.length,
        'averageTimeBetweenUpdates': updateCount > 0
            ? totalTimeBetweenUpdates / updateCount
            : 0,
        'statusChanges': statusChanges,
        'firstUpdate': history.first.timestamp,
        'lastUpdate': history.last.timestamp,
      };
    } catch (e) {
      debugPrint('Error getting pickup analytics: $e');
      return {};
    }
  }

  Future<void> _sendStatusNotification(
    Map<String, dynamic> pickupData,
    String status,
    String? eta,
  ) async {
    try {
      final userId = pickupData['userId'] as String?;
      if (userId == null) return;

      // Get user's FCM token
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final fcmToken = userData['fcmToken'] as String?;
      if (fcmToken == null) return;

      // Create notification message
      final message = _createStatusMessage(status, pickupData, eta);

      // Send notification (in a real app, you'd use Firebase Cloud Functions)
      await _sendPushNotification(fcmToken, message);
    } catch (e) {
      debugPrint('Error sending status notification: $e');
    }
  }

  Map<String, String> _createStatusMessage(
    String status,
    Map<String, dynamic> pickupData,
    String? eta,
  ) {
    final address = pickupData['address'] ?? 'your location';

    switch (status) {
      case 'scheduled':
        return {
          'title': 'Pickup Scheduled',
          'body': 'Your waste pickup at $address has been scheduled.',
        };
      case 'in_progress':
        return {
          'title': 'Collector En Route',
          'body':
              'Your waste collector is on the way! ${eta != null ? "ETA: $eta" : ""}',
        };
      case 'arrived':
        return {
          'title': 'Collector Arrived',
          'body': 'Your waste collector has arrived at $address.',
        };
      case 'completed':
        return {
          'title': 'Pickup Completed',
          'body': 'Your waste pickup has been completed successfully!',
        };
      case 'cancelled':
        return {
          'title': 'Pickup Cancelled',
          'body': 'Your waste pickup has been cancelled.',
        };
      default:
        return {
          'title': 'Pickup Update',
          'body': 'Your pickup status has been updated to: $status',
        };
    }
  }

  Future<void> _sendPushNotification(
    String token,
    Map<String, String> message,
  ) async {
    // In a real implementation, this would call your backend API
    // For now, we'll just log it
    debugPrint(
      'Sending notification to $token: ${message['title']} - ${message['body']}',
    );
  }

  double _calculateDistance(Position pos1, Position pos2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final lat1Rad = pos1.latitude * (pi / 180);
    final lat2Rad = pos2.latitude * (pi / 180);
    final deltaLatRad = (pos2.latitude - pos1.latitude) * (pi / 180);
    final deltaLngRad = (pos2.longitude - pos1.longitude) * (pi / 180);

    final a =
        sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) *
            cos(lat2Rad) *
            sin(deltaLngRad / 2) *
            sin(deltaLngRad / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c; // Distance in kilometers
  }

  String _calculateETA(double distanceKm, String status) {
    // Estimate time based on distance and status
    // Average speed: 30 km/h in city, 20 km/h for pickup operations
    const double avgSpeedKmh = 25.0;
    final timeHours = distanceKm / avgSpeedKmh;

    if (timeHours < 0.1) {
      return 'Arriving now';
    } else if (timeHours < 1) {
      final minutes = (timeHours * 60).round();
      return '$minutes min';
    } else {
      final hours = timeHours.floor();
      final minutes = ((timeHours - hours) * 60).round();
      return '$hours hr ${minutes > 0 ? "$minutes min" : ""}';
    }
  }

  // Emergency contact feature
  Future<void> sendEmergencyAlert(String pickupId, String alertType) async {
    try {
      final pickupDoc = await _firestore
          .collection('pickup_requests')
          .doc(pickupId)
          .get();
      if (!pickupDoc.exists) return;

      final pickupData = pickupDoc.data()!;
      final userId = pickupData['userId'] as String?;
      final collectorId = pickupData['collectorId'] as String?;

      if (userId != null) {
        // Notify user
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final userToken = userDoc.data()?['fcmToken'];
        if (userToken != null) {
          await _sendPushNotification(userToken, {
            'title': 'Emergency Alert',
            'body':
                'Emergency situation reported for your pickup. Help is on the way.',
          });
        }
      }

      if (collectorId != null) {
        // Notify collector
        final collectorDoc = await _firestore
            .collection('collectors')
            .doc(collectorId)
            .get();
        final collectorToken = collectorDoc.data()?['fcmToken'];
        if (collectorToken != null) {
          await _sendPushNotification(collectorToken, {
            'title': 'Emergency Alert',
            'body': 'Emergency situation reported. Please respond immediately.',
          });
        }
      }

      // Log emergency
      await _firestore.collection('emergencies').add({
        'pickupId': pickupId,
        'alertType': alertType,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': userId,
        'collectorId': collectorId,
        'status': 'active',
      });
    } catch (e) {
      debugPrint('Error sending emergency alert: $e');
    }
  }
}
