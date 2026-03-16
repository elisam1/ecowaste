import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class CollectorLocationService {
  static CollectorLocationService? _instance;
  CollectorLocationService._internal();

  static CollectorLocationService get instance {
    _instance ??= CollectorLocationService._internal();
    return _instance!;
  }

  Timer? _locationTimer;
  String? _currentCollectorId;
  bool _isTracking = false;
  StreamSubscription<Position>? _positionStream;

  /// Start tracking collector location
  /// Call this when collector accepts a pickup request or when status changes to in_progress
  Future<void> startLocationTracking(String collectorId) async {
    if (_isTracking && _currentCollectorId == collectorId) {
      return;
    }

    await stopLocationTracking(); // Stop any existing tracking

    _currentCollectorId = collectorId;
    _isTracking = true;

    try {
      // Check permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      // Start real-time location streaming
      _startLocationStream(collectorId);

      // Also set up periodic updates as backup
      _startPeriodicUpdates(collectorId);
    } catch (e) {
      _isTracking = false;
      _currentCollectorId = null;
      rethrow;
    }
  }

  void _startLocationStream(String collectorId) {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update only if moved 10+ meters
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            _updateCollectorLocation(collectorId, position);
          },
          onError: (error) {},
        );
  }

  void _startPeriodicUpdates(String collectorId) {
    _locationTimer = Timer.periodic(
      const Duration(seconds: 30), // Update every 30 seconds
      (timer) async {
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10),
          );
          _updateCollectorLocation(collectorId, position);
        } catch (e) {
          print('Error getting current position for location tracking: $e');
        }
      },
    );
  }

  Future<void> _updateCollectorLocation(
    String collectorId,
    Position position,
  ) async {
    try {
      // Primary location store used by tracking UIs
      await FirebaseFirestore.instance
          .collection('collector_locations')
          .doc(collectorId)
          .set({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'accuracy': position.accuracy,
            'speed': position.speed,
            'heading': position.heading,
            'timestamp': FieldValue.serverTimestamp(),
            'isActive': true,
          }, SetOptions(merge: true));

      // Mirror basic location into collectors collection for services
      // (for example AdvancedTrackingService and analytics).
      try {
        await FirebaseFirestore.instance
            .collection('collectors')
            .doc(collectorId)
            .update({
              'currentLocation': {
                'latitude': position.latitude,
                'longitude': position.longitude,
                'accuracy': position.accuracy,
                'timestamp': FieldValue.serverTimestamp(),
              },
              'lastLocationUpdate': FieldValue.serverTimestamp(),
            });
      } catch (e) {
        // Ignore mirror failures to avoid breaking live tracking
      }
    } catch (e) {}
  }

  /// Stop location tracking
  /// Call this when all pickup requests are completed or collector goes offline
  Future<void> stopLocationTracking() async {
    if (!_isTracking) return;

    _locationTimer?.cancel();
    _positionStream?.cancel();

    // Mark collector as inactive
    if (_currentCollectorId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('collector_locations')
            .doc(_currentCollectorId!)
            .update({
              'isActive': false,
              'lastActiveAt': FieldValue.serverTimestamp(),
            });
      } catch (e) {}
    }

    // Reset tracking state
    _isTracking = false;
    _currentCollectorId = null;
    _locationTimer = null;
    _positionStream = null;
  }

  /// Check Firestore to determine if there are active pickups that
  /// require location tracking for this collector.
  Future<bool> shouldTrackLocation(String collectorId) async {
    try {
      final activeRequests = await FirebaseFirestore.instance
          .collection('pickup_requests')
          .where('collectorId', isEqualTo: collectorId)
          .where('status', whereIn: ['accepted', 'in_progress'])
          .get();

      return activeRequests.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Start/stop tracking automatically based on active pickup requests.
  Future<void> updateTrackingBasedOnRequests(String collectorId) async {
    final shouldTrack = await shouldTrackLocation(collectorId);

    if (shouldTrack && !_isTracking) {
      await startLocationTracking(collectorId);
    } else if (!shouldTrack &&
        _isTracking &&
        _currentCollectorId == collectorId) {
      await stopLocationTracking();
    }
  }

  /// Expose current tracking status and active collector id.
  bool get isTracking => _isTracking;
  String? get currentCollectorId => _currentCollectorId;

  void dispose() {
    stopLocationTracking();
  }
}
