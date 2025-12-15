import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'logging_service.dart';
import 'dart:math' as math;

/// Service for geofencing, route optimization, and proximity-based notifications
/// Handles pickup location management, collector proximity, and distance calculations
class LocationOptimizationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Logger removed (not currently used) — use LoggingService for structured logging

  // Geofence radius in meters (default: 500m)
  static const double defaultGeofenceRadius = 500.0;

  // Maximum reasonable distance for pickup (5km)
  static const double maxPickupDistance = 5000.0;

  // Minimum distance to consider for route (50m)
  static const double minRouteDistance = 50.0;

  /// Check if collector is within geofence of pickup location
  /// Returns true if collector's current location is within geofence radius
  static Future<bool> isWithinGeofence(
    String pickupId,
    Position currentPosition, {
    double radiusInMeters = defaultGeofenceRadius,
  }) async {
    try {
      final pickupDoc = await _firestore
          .collection('pickups')
          .doc(pickupId)
          .get();

      if (!pickupDoc.exists) {
        LoggingService.warning('Pickup not found: $pickupId');
        return false;
      }

      final pickupData = pickupDoc.data() as Map<String, dynamic>;
      final GeoPoint pickupLocation = pickupData['location'] as GeoPoint;

      final distance = _calculateDistance(
        currentPosition.latitude,
        currentPosition.longitude,
        pickupLocation.latitude,
        pickupLocation.longitude,
      );

      final isInside = distance <= radiusInMeters;
      LoggingService.info(
        'Geofence check for $pickupId: ${isInside ? "INSIDE" : "OUTSIDE"} '
        '(distance: ${distance.toStringAsFixed(2)}m)',
      );

      return isInside;
    } catch (e) {
      LoggingService.error('Error checking geofence: $e');
      return false;
    }
  }

  /// Find all collectors within range of a pickup location
  /// Useful for auto-assigning tasks to nearest available collectors
  static Future<List<Map<String, dynamic>>> findCollectorsInRange(
    GeoPoint pickupLocation, {
    double radiusInKm = 5.0,
    String? excludeCollectorId,
  }) async {
    try {
      final collectors = <Map<String, dynamic>>[];

      // Fetch all active collectors
      final activeCollectorsQuery = await _firestore
          .collection('collectors')
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in activeCollectorsQuery.docs) {
        final collectorData = doc.data();

        if (excludeCollectorId != null && doc.id == excludeCollectorId) {
          continue;
        }

        final collectorLocation = collectorData['currentLocation'] as GeoPoint?;
        if (collectorLocation == null) continue;

        final distance = _calculateDistance(
          pickupLocation.latitude,
          pickupLocation.longitude,
          collectorLocation.latitude,
          collectorLocation.longitude,
        );

        // Convert to km and check if within range
        if (distance / 1000 <= radiusInKm) {
          collectors.add({
            'collectorId': doc.id,
            'name': collectorData['name'] as String? ?? 'Unknown',
            'distance': distance,
            'distanceKm': distance / 1000,
            'rating': collectorData['rating'] as double? ?? 0.0,
            'location': collectorLocation,
            'phone': collectorData['phone'] as String?,
          });
        }
      }

      // Sort by distance (nearest first)
      collectors.sort(
        (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
      );

      LoggingService.info(
        'Found ${collectors.length} collectors within ${radiusInKm}km of pickup',
      );

      return collectors;
    } catch (e) {
      LoggingService.error('Error finding collectors in range: $e');
      return [];
    }
  }

  /// Calculate optimized route for collector visiting multiple pickups
  /// Returns list of pickup IDs sorted by most efficient route
  static Future<List<String>> optimizeRoute(
    List<String> pickupIds,
    Position currentPosition,
  ) async {
    try {
      if (pickupIds.isEmpty) return [];
      if (pickupIds.length == 1) return pickupIds;

      // Fetch all pickup locations
      final pickupLocations = <String, GeoPoint>{};
      for (final pickupId in pickupIds) {
        final doc = await _firestore.collection('pickups').doc(pickupId).get();
        if (doc.exists) {
          final location = doc.data()?['location'] as GeoPoint?;
          if (location != null) {
            pickupLocations[pickupId] = location;
          }
        }
      }

      if (pickupLocations.isEmpty) return pickupIds;

      // Simple nearest-neighbor algorithm for route optimization
      final optimizedRoute = <String>[];
      var currentLat = currentPosition.latitude;
      var currentLon = currentPosition.longitude;
      final remaining = Set<String>.from(pickupLocations.keys);

      while (remaining.isNotEmpty) {
        var nearestId = remaining.first;
        var minDistance = double.infinity;

        for (final id in remaining) {
          final location = pickupLocations[id]!;
          final distance = _calculateDistance(
            currentLat,
            currentLon,
            location.latitude,
            location.longitude,
          );

          if (distance < minDistance) {
            minDistance = distance;
            nearestId = id;
          }
        }

        optimizedRoute.add(nearestId);
        final nextLocation = pickupLocations[nearestId]!;
        currentLat = nextLocation.latitude;
        currentLon = nextLocation.longitude;
        remaining.remove(nearestId);
      }

      LoggingService.info('Route optimized for ${pickupIds.length} pickups');
      return optimizedRoute;
    } catch (e) {
      LoggingService.error('Error optimizing route: $e');
      return pickupIds;
    }
  }

  /// Calculate distance between two coordinates in meters using Haversine formula
  /// Returns distance in meters
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusM = 6371000.0; // Earth's radius in meters
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusM * c;
  }

  /// Convert degrees to radians
  static double _toRadians(double degrees) {
    return degrees * (3.141592653589793 / 180.0);
  }

  /// Update collector's current location in Firestore
  static Future<bool> updateCollectorLocation(
    String collectorId,
    Position position,
  ) async {
    try {
      await _firestore.collection('collectors').doc(collectorId).update({
        'currentLocation': GeoPoint(position.latitude, position.longitude),
        'lastLocationUpdate': DateTime.now(),
      });

      LoggingService.info(
        'Updated collector $collectorId location: '
        '${position.latitude}, ${position.longitude}',
      );

      return true;
    } catch (e) {
      LoggingService.error('Error updating collector location: $e');
      return false;
    }
  }

  /// Send proximity-based notification when collector enters geofence
  static Future<void> sendProximityNotification(
    String collectorId,
    String pickupId,
    String pickupAddress,
  ) async {
    try {
      // Store notification in Firestore
      await _firestore
          .collection('collectors')
          .doc(collectorId)
          .collection('notifications')
          .add({
            'type': 'proximity_alert',
            'pickupId': pickupId,
            'address': pickupAddress,
            'message': 'You are close to a pickup location at $pickupAddress',
            'timestamp': DateTime.now(),
            'read': false,
          });

      LoggingService.info(
        'Proximity notification sent to collector $collectorId for pickup $pickupId',
      );
    } catch (e) {
      LoggingService.error('Error sending proximity notification: $e');
    }
  }

  /// Calculate ETA (estimated time of arrival) in minutes
  /// Simple calculation: distance / average speed (assuming 30 km/h for urban areas)
  static int calculateETA(double distanceInMeters) {
    const averageSpeedMPerMin = 500.0; // 30 km/h = 500 m/min
    return ((distanceInMeters / averageSpeedMPerMin) + 1).ceil();
  }

  /// Get nearby pickups for current user location
  static Future<List<Map<String, dynamic>>> getNearbyPickups(
    Position userPosition, {
    double radiusInKm = 5.0,
    int limit = 10,
  }) async {
    try {
      final pickups = <Map<String, dynamic>>[];

      // Fetch available pickups
      final pickupsQuery = await _firestore
          .collection('pickups')
          .where('status', isEqualTo: 'pending')
          .limit(limit * 3) // Fetch more to filter by distance
          .get();

      for (final doc in pickupsQuery.docs) {
        final pickupData = doc.data();
        final location = pickupData['location'] as GeoPoint?;

        if (location == null) continue;

        final distance = _calculateDistance(
          userPosition.latitude,
          userPosition.longitude,
          location.latitude,
          location.longitude,
        );

        if (distance / 1000 <= radiusInKm) {
          pickups.add({
            'pickupId': doc.id,
            'address': pickupData['address'] as String? ?? 'Unknown',
            'distance': distance,
            'distanceKm': (distance / 1000).toStringAsFixed(2),
            'eta': calculateETA(distance),
            'reward': pickupData['reward'] as double? ?? 0.0,
            'location': location,
            'timestamp': pickupData['timestamp'],
          });
        }
      }

      // Sort by distance
      pickups.sort(
        (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
      );

      LoggingService.info('Found ${pickups.length} nearby pickups');
      return pickups.take(limit).toList();
    } catch (e) {
      LoggingService.error('Error getting nearby pickups: $e');
      return [];
    }
  }

  /// Stream nearby pickups in real-time as user location changes
  static Stream<List<Map<String, dynamic>>> streamNearbyPickups(
    String userId, {
    double radiusInKm = 5.0,
  }) {
    try {
      return _firestore
          .collection('pickups')
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .asyncMap((snapshot) async {
            final pickups = <Map<String, dynamic>>[];

            // Get current user location
            final userDoc = await _firestore
                .collection('users')
                .doc(userId)
                .get();
            final userLocation = userDoc.data()?['location'] as GeoPoint?;

            if (userLocation == null) return [];

            for (final doc in snapshot.docs) {
              final pickupData = doc.data();
              final location = pickupData['location'] as GeoPoint?;

              if (location == null) continue;

              final distance = _calculateDistance(
                userLocation.latitude,
                userLocation.longitude,
                location.latitude,
                location.longitude,
              );

              if (distance / 1000 <= radiusInKm) {
                pickups.add({
                  'pickupId': doc.id,
                  'address': pickupData['address'] as String? ?? 'Unknown',
                  'distance': distance,
                  'distanceKm': (distance / 1000).toStringAsFixed(2),
                  'eta': calculateETA(distance),
                });
              }
            }

            pickups.sort(
              (a, b) =>
                  (a['distance'] as double).compareTo(b['distance'] as double),
            );
            return pickups;
          });
    } catch (e) {
      LoggingService.error('Error streaming nearby pickups: $e');
      return Stream.value([]);
    }
  }

  /// Check if distance is valid for a pickup
  static bool isValidPickupDistance(double distanceInMeters) {
    return distanceInMeters > minRouteDistance &&
        distanceInMeters <= maxPickupDistance;
  }

  /// Get formatted distance string (1.2 km, 500 m, etc.)
  static String formatDistance(double distanceInMeters) {
    if (distanceInMeters >= 1000) {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceInMeters.toStringAsFixed(0)} m';
  }
}

/// Math helper for trigonometric calculations
abstract class Math {
  static double sin(double radians) {
    return (2 * radians / 3.141592653589793 * (radians % 3.141592653589793) -
            4 *
                (radians % 3.141592653589793) *
                (3.141592653589793 - (radians % 3.141592653589793))) /
        (3.141592653589793 * 3.141592653589793);
  }

  static double cos(double radians) {
    return sin(radians + 3.141592653589793 / 2);
  }

  static double atan2(double y, double x) {
    return (3.141592653589793 / 2) - (x / (x * x + y * y));
  }

  static double sqrt(double value) {
    if (value < 0) return 0;
    if (value == 0) return 0;
    var x = value;
    for (var i = 0; i < 10; i++) {
      x = (x + value / x) / 2;
    }
    return x;
  }
}
