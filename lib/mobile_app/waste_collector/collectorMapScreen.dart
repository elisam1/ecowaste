// import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

// Shared collector location tracking service
import 'collector_location_service.dart';
import 'package:flutter_application_1/mobile_app/constants/app_colors.dart';

class CollectorMapScreen extends StatefulWidget {
  final String collectorId;
  const CollectorMapScreen({required this.collectorId, super.key});

  @override
  State<CollectorMapScreen> createState() => _CollectorMapScreenState();
}

class _CollectorMapScreenState extends State<CollectorMapScreen>
    with WidgetsBindingObserver {
  late GoogleMapController _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng _initialPosition = const LatLng(6.6730, -1.5715); // Default to KNUST
  bool _isLoading = true;
  String? _errorMessage;
  String? _nearestLocationId;
  double? _nearestDistance;
  Timer? _refreshTimer;
  StreamSubscription<QuerySnapshot>? _requestsListener;
  String? _activeRequestId;
  Map<String, dynamic>? _activeRequestData;
  bool _hasAnyRequests = false;

  // Add your Google Maps API key here
  static const String _googleMapsApiKey =
      'AIzaSyDfV-BwmObibrIHDQB4cRuE53BDvspD9Aw';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeMap();
    _startLocationService();
    _setupRealtimeUpdates();
  }

  // Enhanced initialization with real-time updates
  Future<void> _initializeMap() async {
    try {
      await Future.wait([_getCurrentLocation(), _loadAcceptedRequests()]);
      await _drawRouteToNearestLocation();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load map data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Start location tracking service
  Future<void> _startLocationService() async {
    try {
      final locationService = CollectorLocationService.instance;

      // Check if we should be tracking based on active requests
      final shouldTrack = await locationService.shouldTrackLocation(
        widget.collectorId,
      );

      if (shouldTrack) {
        await locationService.startLocationTracking(widget.collectorId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location tracking started for active pickups'),
              backgroundColor: AppColors.danger,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location tracking error: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _startLocationService,
            ),
          ),
        );
      }
    }
  }

  // Setup real-time listeners for pickup requests
  void _setupRealtimeUpdates() {
    // Listen to pickup request changes in real-time
    _requestsListener = FirebaseFirestore.instance
        .collection('pickup_requests')
        .where('status', whereIn: ['in_progress', 'accepted'])
        .where('collectorId', isEqualTo: widget.collectorId)
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            _handleRequestUpdates(snapshot);
          }
        }, onError: (error) {});

    // Periodic refresh for location updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (mounted) {
        _refreshCurrentLocation();
      }
    });
  }

  void _handleRequestUpdates(QuerySnapshot snapshot) async {
    Set<Marker> newRequestMarkers = {};
    _markers.removeWhere((m) => m.markerId.value != 'collector');

    Map<String, dynamic>? activeData;
    String? activeId;

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final userLatitude = data['userLatitude'];
      final userLongitude = data['userLongitude'];

      if (userLatitude == null || userLongitude == null) continue;

      try {
        double lat = userLatitude is double
            ? userLatitude
            : double.parse(userLatitude.toString());
        double lng = userLongitude is double
            ? userLongitude
            : double.parse(userLongitude.toString());

        if (lat.abs() > 90 || lng.abs() > 180) continue;

        // Check if pickup is scheduled for today
        final isTodayPickup = _isPickupToday(data['pickupDate']);
        final pickupDateText = _formatPickupDate(data['pickupDate']);

        // Track first in-progress request as the "active job"
        if (data['status'] == 'in_progress' && activeId == null) {
          activeId = doc.id;
          activeData = data;
        }

        // Determine marker color based on status and date
        BitmapDescriptor markerIcon;
        if (isTodayPickup) {
          // Today's pickups get priority colors
          markerIcon = data['status'] == 'in_progress'
              ? BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed,
                ) // Red for urgent today pickups
              : BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueYellow,
                ); // Yellow for today's accepted pickups
        } else {
          // Future pickups get standard colors
          markerIcon = data['status'] == 'in_progress'
              ? BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueOrange,
                )
              : BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                );
        }

        final marker = Marker(
          markerId: MarkerId(doc.id),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: data['userName'] ?? 'Pickup Request',
            snippet: isTodayPickup
                ? '🔥 TODAY: ${_formatWasteCategories(data['wasteCategories'])} - $pickupDateText'
                : '📅 ${_formatWasteCategories(data['wasteCategories'])} - $pickupDateText',
          ),
          icon: markerIcon,
          onTap: () => _showRequestDetails(doc.id, data),
        );

        newRequestMarkers.add(marker);
      } catch (e) {
        continue;
      }
    }

    setState(() {
      _markers = {..._markers, ...newRequestMarkers};
      _activeRequestId = activeId;
      _activeRequestData = activeData;
      _hasAnyRequests = snapshot.docs.isNotEmpty;
    });

    // Recalculate nearest location
    await _drawRouteToNearestLocation();
  }

  Future<void> _refreshCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      );

      // Only update if significantly moved
      final distance = Geolocator.distanceBetween(
        _initialPosition.latitude,
        _initialPosition.longitude,
        position.latitude,
        position.longitude,
      );

      if (distance > 50) {
        // 50 meters threshold
        setState(() {
          _initialPosition = LatLng(position.latitude, position.longitude);
        });
        _updateCollectorMarker();
        await _drawRouteToNearestLocation();
      }
    } catch (e) {}
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Location services are disabled. Please enable location services.',
              ),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => Geolocator.openLocationSettings(),
              ),
            ),
          );
        }
        _addCollectorMarker();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Location permissions are permanently denied. Please enable in app settings.',
              ),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => Geolocator.openAppSettings(),
              ),
            ),
          );
        }
        _addCollectorMarker();
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Getting your location...'),
              ],
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }

      Position? lastPosition;
      try {
        lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          setState(() {
            _initialPosition = LatLng(
              lastPosition!.latitude,
              lastPosition.longitude,
            );
          });
          _addCollectorMarker();
        }
      } catch (e) {}

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );

      if (position.latitude == 0.0 && position.longitude == 0.0) {
        throw Exception('Invalid location coordinates received');
      }

      setState(() {
        _initialPosition = LatLng(position.latitude, position.longitude);
      });

      _addCollectorMarker();

      if (lastPosition == null ||
          Geolocator.distanceBetween(
                lastPosition.latitude,
                lastPosition.longitude,
                position.latitude,
                position.longitude,
              ) >
              100) {
        _mapController.animateCamera(
          CameraUpdate.newLatLngZoom(_initialPosition, 16),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location updated (±${position.accuracy.toInt()}m accuracy)',
            ),
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location error: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _getCurrentLocation,
            ),
          ),
        );
      }
      _addCollectorMarker();
    }
  }

  void _addCollectorMarker() {
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'collector');
      _markers.add(
        Marker(
          markerId: const MarkerId('collector'),
          position: _initialPosition,
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'Waste Collector',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    });
  }

  void _updateCollectorMarker() {
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'collector');
      _markers.add(
        Marker(
          markerId: const MarkerId('collector'),
          position: _initialPosition,
          infoWindow: const InfoWindow(
            title: 'Your Location (Updated)',
            snippet: 'Waste Collector',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    });
  }

  Future<void> _loadAcceptedRequests() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('pickup_requests')
          .where('status', whereIn: ['in_progress', 'accepted'])
          .where('collectorId', isEqualTo: widget.collectorId)
          .get();

      if (snapshot.docs.isEmpty) {
        return;
      }

      Set<Marker> requestMarkers = {};
      int validRequests = 0;
      int invalidRequests = 0;
      _markers.removeWhere((m) => m.markerId.value != 'collector');
      Map<String, dynamic>? activeData;
      String? activeId;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final userLatitude = data['userLatitude'];
        final userLongitude = data['userLongitude'];

        if (userLatitude == null || userLongitude == null) {
          invalidRequests++;
          continue;
        }

        double lat, lng;
        try {
          lat = userLatitude is double
              ? userLatitude
              : double.parse(userLatitude.toString());
          lng = userLongitude is double
              ? userLongitude
              : double.parse(userLongitude.toString());

          if (lat.abs() > 90 || lng.abs() > 180) {
            invalidRequests++;
            continue;
          }

          validRequests++;
        } catch (e) {
          invalidRequests++;
          continue;
        }

        // Check if pickup is scheduled for today
        final isTodayPickup = _isPickupToday(data['pickupDate']);
        final pickupDateText = _formatPickupDate(data['pickupDate']);

        // Track first in-progress request as the "active job"
        if (data['status'] == 'in_progress' && activeId == null) {
          activeId = doc.id;
          activeData = data;
        }

        // Determine marker color based on status and date
        BitmapDescriptor markerIcon;
        if (isTodayPickup) {
          // Today's pickups get priority colors
          markerIcon = data['status'] == 'in_progress'
              ? BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed,
                ) // Red for urgent today pickups
              : BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueYellow,
                ); // Yellow for today's accepted pickups
        } else {
          // Future pickups get standard colors
          markerIcon = data['status'] == 'in_progress'
              ? BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueOrange,
                )
              : BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                );
        }

        final marker = Marker(
          markerId: MarkerId(doc.id),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: data['userName'] ?? 'Pickup Request',
            snippet: isTodayPickup
                ? '🔥 TODAY: ${_formatWasteCategories(data['wasteCategories'])} - $pickupDateText'
                : '📅 ${_formatWasteCategories(data['wasteCategories'])} - $pickupDateText',
          ),
          icon: markerIcon,
          onTap: () => _showRequestDetails(doc.id, data),
        );

        requestMarkers.add(marker);
      }

      setState(() {
        _markers = {..._markers, ...requestMarkers};
        _activeRequestId = activeId;
        _activeRequestData = activeData;
        _hasAnyRequests = requestMarkers.isNotEmpty;
      });

      if (mounted) {
        String message = 'Loaded $validRequests pickup requests';
        if (invalidRequests > 0) {
          message += ' ($invalidRequests requests have invalid location data)';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: invalidRequests > 0
                ? Colors.orange
                : AppColors.danger,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      if (requestMarkers.isNotEmpty && mounted) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) _fitMarkersInView();
        });
      }
    } catch (e) {
      throw Exception('Failed to load pickup requests: $e');
    }
  }

  Future<void> _drawRouteToNearestLocation() async {
    if (_markers.length <= 1) return;

    double nearestDistance = double.infinity;
    LatLng? nearestLocation;
    String? nearestLocationId;
    String? nearestLocationName;

    for (final marker in _markers) {
      if (marker.markerId.value == 'collector') continue;

      final distance = Geolocator.distanceBetween(
        _initialPosition.latitude,
        _initialPosition.longitude,
        marker.position.latitude,
        marker.position.longitude,
      );

      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestLocation = marker.position;
        nearestLocationId = marker.markerId.value;
        nearestLocationName = marker.infoWindow.title;
      }
    }

    if (nearestLocation != null && nearestLocationId != null) {
      _nearestLocationId = nearestLocationId;
      _nearestDistance = nearestDistance;

      await _getDirectionsRoute(_initialPosition, nearestLocation);
      _highlightNearestMarker(nearestLocationId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Route to nearest pickup: ${nearestLocationName ?? 'Unknown'} '
              '(${(nearestDistance / 1000).toStringAsFixed(2)} km away)',
            ),
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Navigate',
              onPressed: () => _navigateToNearestLocation(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _getDirectionsRoute(LatLng origin, LatLng destination) async {
    if (_googleMapsApiKey == 'AIzaSyDfV-BwmObibrIHDQB4cRuE53BDvspD9Aw') {
      _createSimpleRoute(origin, destination);
      return;
    }

    try {
      final String url =
          'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${origin.latitude},${origin.longitude}&'
          'destination=${destination.latitude},${destination.longitude}&'
          'mode=driving&'
          'key=$_googleMapsApiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final polylinePoints = route['overview_polyline']['points'];
          final List<LatLng> routeCoords = _decodePolyline(polylinePoints);

          final duration = route['legs'][0]['duration']['text'];
          final distance = route['legs'][0]['distance']['text'];

          _createRoutePolyline(routeCoords, duration, distance);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Route loaded: $distance, $duration'),
                backgroundColor: AppColors.danger,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          _createSimpleRoute(origin, destination);
        }
      } else {
        _createSimpleRoute(origin, destination);
      }
    } catch (e) {
      _createSimpleRoute(origin, destination);
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  void _createRoutePolyline(
    List<LatLng> routeCoords,
    String duration,
    String distance,
  ) {
    setState(() {
      _polylines.clear();
    });

    final Polyline route = Polyline(
      polylineId: const PolylineId('nearest_route'),
      points: routeCoords,
      color: AppColors.danger,
      width: 6,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
      jointType: JointType.round,
    );

    final Polyline routeBackground = Polyline(
      polylineId: const PolylineId('nearest_route_bg'),
      points: routeCoords,
      color: Colors.white,
      width: 8,
    );

    setState(() {
      _polylines.addAll([routeBackground, route]);
    });

    if (routeCoords.isNotEmpty) {
      _fitRouteInView(routeCoords);
    }
  }

  void _createSimpleRoute(LatLng start, LatLng end) {
    final List<LatLng> routePoints = [start, end];

    final Polyline route = Polyline(
      polylineId: const PolylineId('nearest_route'),
      points: routePoints,
      color: AppColors.danger,
      width: 5,
      patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
    );

    final Polyline routeBackground = Polyline(
      polylineId: const PolylineId('nearest_route_bg'),
      points: routePoints,
      color: Colors.white,
      width: 7,
    );

    setState(() {
      _polylines.clear();
      _polylines.addAll([routeBackground, route]);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Using direct route (configure API key for road routing)',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _fitRouteInView(List<LatLng> routeCoords) {
    if (routeCoords.isEmpty) return;

    double minLat = routeCoords.first.latitude;
    double maxLat = routeCoords.first.latitude;
    double minLng = routeCoords.first.longitude;
    double maxLng = routeCoords.first.longitude;

    for (final point in routeCoords) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
  }

  void _highlightNearestMarker(String markerId) {
    setState(() {
      _markers = _markers.map((marker) {
        if (marker.markerId.value == markerId) {
          return marker.copyWith(
            iconParam: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange,
            ),
            infoWindowParam: marker.infoWindow.copyWith(
              snippetParam: '${marker.infoWindow.snippet} - NEAREST',
            ),
          );
        }
        return marker;
      }).toSet();
    });
  }

  void _navigateToNearestLocation() async {
    if (_nearestLocationId == null) return;

    final nearestMarker = _markers.firstWhere(
      (marker) => marker.markerId.value == _nearestLocationId,
    );

    final lat = nearestMarker.position.latitude;
    final lng = nearestMarker.position.longitude;
    final name = nearestMarker.infoWindow.title ?? 'Nearest Pickup';

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.near_me, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Navigate to Nearest: $name',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Distance: ${(_nearestDistance! / 1000).toStringAsFixed(2)} km',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _openInGoogleMaps(lat, lng, name),
                  icon: const Icon(Icons.map),
                  label: const Text('Google Maps'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _openInWaze(lat, lng),
                  icon: const Icon(Icons.navigation),
                  label: const Text('Waze'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRequestDetails(String requestId, Map<String, dynamic> data) {
    final isNearest = requestId == _nearestLocationId;

    showBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isNearest) ...[
                  const Icon(Icons.near_me, color: Colors.orange),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    data['userName'] ?? 'Pickup Request',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                // Status indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: data['status'] == 'in_progress'
                        ? Colors.orange.withValues(alpha: 0.2)
                        : AppColors.danger.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    data['status'] == 'in_progress'
                        ? 'IN PROGRESS'
                        : 'ACCEPTED',
                    style: TextStyle(
                      color: data['status'] == 'in_progress'
                          ? Colors.orange
                          : AppColors.danger,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            if (isNearest) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'NEAREST LOCATION (${(_nearestDistance! / 1000).toStringAsFixed(2)} km)',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Priority indicator for today's pickups
            if (_isPickupToday(data['pickupDate'])) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red, width: 2),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.priority_high,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '🔥 PRIORITY: TODAY\'S PICKUP',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            _buildDetailRow(
              Icons.delete_outline,
              'Waste',
              _formatWasteCategories(data['wasteCategories']),
            ),
            _buildDetailRow(
              Icons.location_on,
              'Location',
              data['userTown'] ?? 'Not specified',
            ),
            _buildDetailRow(
              Icons.phone,
              'Contact',
              data['userPhone'] ?? 'Not provided',
            ),
            _buildDetailRow(
              Icons.schedule,
              'Pickup',
              _formatPickupDate(data['pickupDate']),
            ),
            if (data['specialInstructions'] != null &&
                data['specialInstructions'].toString().isNotEmpty)
              _buildDetailRow(
                Icons.note,
                'Instructions',
                data['specialInstructions'],
              ),
            const SizedBox(height: 16),
            // Action buttons based on current status
            if (data['status'] == 'accepted')
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToLocation(requestId, data),
                      icon: const Icon(Icons.directions),
                      label: const Text('Navigate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger.withValues(
                          alpha: 0.1,
                        ),
                        foregroundColor: AppColors.danger,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _markAsInProgress(requestId),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Pickup'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              )
            else if (data['status'] == 'in_progress')
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToLocation(requestId, data),
                      icon: const Icon(Icons.directions),
                      label: const Text('Navigate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _markAsCompleted(requestId),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Complete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }

  String _formatWasteCategories(dynamic categories) {
    if (categories == null) return 'Unknown';

    if (categories is List) {
      return categories.join(', ');
    }

    try {
      final String str = categories.toString();
      return str
          .replaceAll('[', '')
          .replaceAll(']', '')
          .split(',')
          .map((e) => e.trim())
          .join(', ');
    } catch (e) {
      return categories.toString();
    }
  }

  String _formatPickupDate(dynamic timestamp) {
    if (timestamp == null) return 'Not scheduled';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final pickupDay = DateTime(date.year, date.month, date.day);

      if (pickupDay == today) {
        return 'Today at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else if (pickupDay == today.add(const Duration(days: 1))) {
        return 'Tomorrow at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else {
        return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      }
    }
    return timestamp.toString();
  }

  // Helper function to check if pickup is scheduled for today
  bool _isPickupToday(dynamic timestamp) {
    if (timestamp == null) return false;
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final pickupDay = DateTime(date.year, date.month, date.day);
      return pickupDay == today;
    }
    return false;
  }

  void _navigateToLocation(String requestId, Map<String, dynamic> data) async {
    Navigator.pop(context);

    final userLatitude = data['userLatitude'];
    final userLongitude = data['userLongitude'];

    if (userLatitude == null || userLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location data not available for navigation'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    double lat, lng;
    try {
      lat = userLatitude is double
          ? userLatitude
          : double.parse(userLatitude.toString());
      lng = userLongitude is double
          ? userLongitude
          : double.parse(userLongitude.toString());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid location coordinates'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final String name = data['userName'] ?? 'Pickup Location';

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Navigate to $name',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.map, color: AppColors.danger),
              title: const Text('Google Maps'),
              subtitle: const Text('Open in Google Maps app'),
              onTap: () => _openInGoogleMaps(lat, lng, name),
            ),
            ListTile(
              leading: Icon(Icons.navigation, color: AppColors.danger),
              title: const Text('Waze'),
              subtitle: const Text('Open in Waze app'),
              onTap: () => _openInWaze(lat, lng),
            ),
            ListTile(
              leading: const Icon(Icons.directions, color: Colors.orange),
              title: const Text('Apple Maps'),
              subtitle: const Text('Open in Apple Maps (iOS only)'),
              onTap: () => _openInAppleMaps(lat, lng, name),
            ),
            ListTile(
              leading: const Icon(Icons.route, color: Colors.purple),
              title: const Text('Show Route on Map'),
              subtitle: const Text('Display route in this app'),
              onTap: () => _showRouteOnMap(lat, lng),
            ),
          ],
        ),
      ),
    );
  }

  void _openInGoogleMaps(double lat, double lng, String name) async {
    Navigator.pop(context);
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    _openUrl(url);
  }

  void _openInWaze(double lat, double lng) async {
    Navigator.pop(context);
    final url = 'https://waze.com/ul?ll=$lat,$lng&navigate=yes';
    _openUrl(url);
  }

  void _openInAppleMaps(double lat, double lng, String name) async {
    Navigator.pop(context);
    final url = 'https://maps.apple.com/?daddr=$lat,$lng&dirflg=d';
    _openUrl(url);
  }

  void _showRouteOnMap(double lat, double lng) async {
    Navigator.pop(context);

    await _getDirectionsRoute(_initialPosition, LatLng(lat, lng));

    final distance = Geolocator.distanceBetween(
      _initialPosition.latitude,
      _initialPosition.longitude,
      lat,
      lng,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Route shown. Distance: ${(distance / 1000).toStringAsFixed(2)} km',
        ),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not launch URL')));
    }
  }

  // Enhanced method with location service integration
  Future<void> _markAsInProgress(String requestId) async {
    try {
      Navigator.pop(context);

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await FirebaseFirestore.instance
          .collection('pickup_requests')
          .doc(requestId)
          .update({
            'status': 'in_progress',
            'startedAt': FieldValue.serverTimestamp(),
          });

      // Ensure location tracking is active when pickup starts
      final locationService = CollectorLocationService.instance;
      if (!locationService.isTracking) {
        await locationService.startLocationTracking(widget.collectorId);
      }
      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.location_on, color: Colors.white),
                SizedBox(width: 8),
                Text('Pickup started! Location tracking is now active.'),
              ],
            ),
            backgroundColor: AppColors.danger,
            duration: Duration(seconds: 4),
          ),
        );
        if (!mounted) return;
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating pickup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Enhanced method with location service integration
  Future<void> _markAsCompleted(String requestId) async {
    try {
      Navigator.pop(context);

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.danger),
              const SizedBox(width: 8),
              const Text('Mark as Completed'),
            ],
          ),
          content: const Text(
            'Are you sure you want to mark this pickup as completed? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              child: const Text('Complete'),
            ),
          ],
        ),
      );
      if (!mounted) return;

      if (confirmed == true) {
        // Show loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );

        await FirebaseFirestore.instance
            .collection('pickup_requests')
            .doc(requestId)
            .update({
              // Move into pending_confirmation so user can confirm
              // completion and release payment, matching the main
              // collector workflow in pickup.dart.
              'status': 'pending_confirmation',
              'completedAt': FieldValue.serverTimestamp(),
            });

        // Notify the user to confirm completion (same pattern as
        // _updateRequestStatus in pickup.dart for pending_confirmation).
        try {
          final requestDoc = await FirebaseFirestore.instance
              .collection('pickup_requests')
              .doc(requestId)
              .get();

          if (requestDoc.exists) {
            final requestData = requestDoc.data()!;
            final userId = requestData['userId'];

            if (userId != null) {
              final collectorName =
                  requestData['collectorName'] as String? ?? 'Collector';

              const String title = '🔍 Confirm Pickup Completion';
              final String message =
                  '$collectorName has marked your pickup as completed. Please confirm to release payment.';

              await FirebaseFirestore.instance.collection('notifications').add({
                'userId': userId,
                'type': 'pickup_status_update',
                'title': title,
                'message': message,
                'data': {
                  'pickupRequestId': requestId,
                  'collectorId': widget.collectorId,
                  'collectorName': collectorName,
                  'status': 'pending_confirmation',
                  'userTown': requestData['userTown'],
                  'pickupDate': requestData['pickupDate'],
                  'totalAmount': requestData['totalAmount'],
                  'binCount': requestData['binCount'],
                },
                'isRead': false,
                'createdAt': FieldValue.serverTimestamp(),
              });
            }
          }
        } catch (e) {
          // Best-effort: failures here should not block completion
        }

        // Remove marker from map
        setState(() {
          _markers.removeWhere((marker) => marker.markerId.value == requestId);
        });

        // If this was the nearest location, recalculate route to next nearest
        if (requestId == _nearestLocationId) {
          await _drawRouteToNearestLocation();
        }

        // Check if we should stop location tracking
        final locationService = CollectorLocationService.instance;
        await locationService.updateTrackingBasedOnRequests(widget.collectorId);

        if (mounted) {
          // Close loading dialog
          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text(
                    'Pickup marked as completed. Awaiting user confirmation.',
                  ),
                  const Spacer(),
                  if (!locationService.isTracking)
                    const Text(
                      'Tracking stopped',
                      style: TextStyle(fontSize: 12),
                    ),
                ],
              ),
              backgroundColor: AppColors.danger,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing pickup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _fitMarkersInView() {
    if (_markers.length <= 1) return;

    final bounds = _calculateBounds(_markers);
    _mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
  }

  LatLngBounds _calculateBounds(Set<Marker> markers) {
    double minLat = markers.first.position.latitude;
    double maxLat = markers.first.position.latitude;
    double minLng = markers.first.position.longitude;
    double maxLng = markers.first.position.longitude;

    for (final marker in markers) {
      minLat = math.min(minLat, marker.position.latitude);
      maxLat = math.max(maxLat, marker.position.latitude);
      minLng = math.min(minLng, marker.position.longitude);
      maxLng = math.max(maxLng, marker.position.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  // App lifecycle methods to handle location tracking
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final locationService = CollectorLocationService.instance;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // Keep tracking in background for active pickups
        break;
      case AppLifecycleState.resumed:
        // Restart tracking if needed when app comes back
        _restartLocationTrackingIfNeeded();
        break;
      case AppLifecycleState.detached:
        // App is closing, clean up
        locationService.dispose();
        break;
      case AppLifecycleState.hidden:
        // App is hidden but still running
        break;
    }
  }

  Future<void> _restartLocationTrackingIfNeeded() async {
    final locationService = CollectorLocationService.instance;
    final shouldTrack = await locationService.shouldTrackLocation(
      widget.collectorId,
    );

    if (shouldTrack && !locationService.isTracking) {
      await locationService.startLocationTracking(widget.collectorId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.location_on, color: Colors.white),
                SizedBox(width: 8),
                Text('Location tracking resumed'),
              ],
            ),
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Helper method to get location tracking status as a stream
  Stream<bool> _getLocationTrackingStatus() {
    return Stream.periodic(const Duration(seconds: 2), (_) {
      final locationService = CollectorLocationService.instance;
      return locationService.isTracking &&
          locationService.currentCollectorId == widget.collectorId;
    }).distinct();
  }

  void _showApiKeyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Google Maps API Setup'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('To enable road-following routes, you need to:'),
            SizedBox(height: 8),
            Text('1. Get a Google Maps API key'),
            Text('2. Enable Directions API'),
            Text('3. Replace the API key in the code'),
            SizedBox(height: 8),
            Text(
              'Without API key, the app will show direct line routes.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _openUrl(
                'https://developers.google.com/maps/documentation/directions/get-api-key',
              );
            },
            child: const Text('Get API Key'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Pickup Routes'),
            const SizedBox(width: 8),
            // Enhanced location tracking indicator
            StreamBuilder<bool>(
              stream: _getLocationTrackingStatus(),
              builder: (context, snapshot) {
                final isTracking = snapshot.data ?? false;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isTracking
                        ? AppColors.danger.withValues(alpha: 0.12)
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isTracking
                        ? [
                            BoxShadow(
                              color: AppColors.danger.withValues(alpha: 0.3),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isTracking ? Icons.location_on : Icons.location_off,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isTracking ? 'LIVE' : 'OFF',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        backgroundColor: AppColors.danger,
        foregroundColor: Colors.white,
        actions: [
          if (_nearestLocationId != null)
            IconButton(
              icon: const Icon(Icons.near_me),
              tooltip: 'Navigate to nearest',
              onPressed: _navigateToNearestLocation,
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'refresh':
                  _refreshData();
                  break;
                case 'center':
                  _centerOnCollector();
                  break;
                case 'toggle_tracking':
                  _toggleLocationTracking();
                  break;
                case 'api_key':
                  _showApiKeyDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Refresh Data'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'center',
                child: Row(
                  children: [
                    Icon(Icons.my_location),
                    SizedBox(width: 8),
                    Text('Center on Me'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'toggle_tracking',
                child: Row(
                  children: [
                    StreamBuilder<bool>(
                      stream: _getLocationTrackingStatus(),
                      builder: (context, snapshot) {
                        final isTracking = snapshot.data ?? false;
                        return Icon(
                          isTracking ? Icons.location_off : Icons.location_on,
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    StreamBuilder<bool>(
                      stream: _getLocationTrackingStatus(),
                      builder: (context, snapshot) {
                        final isTracking = snapshot.data ?? false;
                        return Text(
                          isTracking ? 'Stop Tracking' : 'Start Tracking',
                        );
                      },
                    ),
                  ],
                ),
              ),
              if (_googleMapsApiKey ==
                  'AIzaSyDfV-BwmObibrIHDQB4cRuE53BDvspD9Aw')
                const PopupMenuItem(
                  value: 'api_key',
                  child: Row(
                    children: [
                      Icon(Icons.settings),
                      SizedBox(width: 8),
                      Text('Setup API Key'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading map data...'),
                  SizedBox(height: 8),
                  Text(
                    'Initializing location tracking...',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            )
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _refreshData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Go Back'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _initialPosition,
                    zoom: 14,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    if (_markers.length > 1) {
                      Future.delayed(const Duration(milliseconds: 500), () {
                        _fitMarkersInView();
                      });
                    }
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  compassEnabled: true,
                  mapToolbarEnabled: true,
                ),

                // Map Legend - Color coding for pickup dates
                Positioned(
                  top: 16,
                  left: 16,
                  child: Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Pickup Priority',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Today - In Progress',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.yellow,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Today - Accepted',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Future - In Progress',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: const BoxDecoration(
                                  color: AppColors.danger,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Future - Accepted',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Today's Pickup Summary
                Positioned(
                  top: 16,
                  right: 16,
                  child: Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('pickup_requests')
                            .where(
                              'status',
                              whereIn: ['in_progress', 'accepted'],
                            )
                            .where('collectorId', isEqualTo: widget.collectorId)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const SizedBox(
                              width: 120,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }

                          int todayPickups = 0;
                          int futurePickups = 0;

                          for (var doc in snapshot.data!.docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            if (_isPickupToday(data['pickupDate'])) {
                              todayPickups++;
                            } else {
                              futurePickups++;
                            }
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Today\'s Schedule',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.red),
                                    ),
                                    child: Text(
                                      '$todayPickups Today',
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.danger.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.danger),
                                    ),
                                    child: Text(
                                      '$futurePickups Future',
                                      style: const TextStyle(
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // Enhanced nearest location info card
                if (_nearestLocationId != null && _nearestDistance != null)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Card(
                      elevation: 8,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.near_me,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Next Pickup',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '${(_nearestDistance! / 1000).toStringAsFixed(2)} km away',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.directions),
                              onPressed: _navigateToNearestLocation,
                              tooltip: 'Navigate',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.blue.withValues(
                                  alpha: 0.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Empty state overlay when there are no pickup markers
                if (!_hasAnyRequests)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.map_outlined,
                                size: 32,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'No active pickups on your route yet',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'New accepted or in-progress jobs will appear here automatically.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // Enhanced location tracking status card
                Positioned(
                  bottom: 160,
                  right: 16,
                  child: StreamBuilder<bool>(
                    stream: _getLocationTrackingStatus(),
                    builder: (context, snapshot) {
                      final isTracking = snapshot.data ?? false;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        child: Card(
                          elevation: isTracking ? 8 : 4,
                          color: isTracking
                              ? AppColors.danger.withValues(alpha: 0.08)
                              : Colors.grey.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isTracking
                                        ? AppColors.danger
                                        : Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isTracking
                                        ? Icons.location_on
                                        : Icons.location_off,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isTracking
                                      ? 'Tracking\nActive'
                                      : 'Tracking\nInactive',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isTracking
                                        ? AppColors.danger
                                        : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (isTracking) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: AppColors.danger,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.danger.withValues(
                                            alpha: 0.5,
                                          ),
                                          blurRadius: 4,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Active job bottom card for the current in-progress pickup
                if (_activeRequestId != null && _activeRequestData != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Card(
                      elevation: 10,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.danger,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.directions_bus,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _activeRequestData!['userTown'] ??
                                        'Active pickup',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatPickupDate(
                                      _activeRequestData!['pickupDate'],
                                    ),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatWasteCategories(
                                      _activeRequestData!['wasteCategories'],
                                    ),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        (_activeRequestData!['status'] ==
                                            'in_progress')
                                        ? AppColors.danger.withValues(
                                            alpha: 0.15,
                                          )
                                        : Colors.orange.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    (_activeRequestData!['status'] ==
                                            'in_progress')
                                        ? 'IN PROGRESS'
                                        : 'ACCEPTED',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          _activeRequestData!['status'] ==
                                              'in_progress'
                                          ? AppColors.danger
                                          : Colors.orange,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        _showRequestDetails(
                                          _activeRequestId!,
                                          _activeRequestData!,
                                        );
                                      },
                                      child: const Text('Details'),
                                    ),
                                    const SizedBox(width: 4),
                                    ElevatedButton(
                                      onPressed: () {
                                        _navigateToLocation(
                                          _activeRequestId!,
                                          _activeRequestData!,
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.danger,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Navigate'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Request count indicator
                Positioned(
                  top: 80,
                  right: 16,
                  child: Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.assignment,
                            size: 16,
                            color: AppColors.danger,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_markers.length - 1} pickups',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // API Key configuration notice
                if (_googleMapsApiKey ==
                    'AIzaSyDfV-BwmObibrIHDQB4cRuE53BDvspD9Aw')
                  Positioned(
                    bottom: 220,
                    left: 16,
                    right: 80,
                    child: Card(
                      color: Colors.orange.shade100,
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.warning, color: Colors.orange),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Configure Google Maps API key for road routing',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            TextButton(
                              onPressed: () => _showApiKeyDialog(),
                              child: const Text('Setup'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Quick navigate to nearest
          if (_nearestLocationId != null)
            FloatingActionButton(
              heroTag: "navigate",
              mini: true,
              backgroundColor: Colors.orange,
              onPressed: _navigateToNearestLocation,
              tooltip: 'Navigate to nearest pickup',
              child: const Icon(Icons.navigation, color: Colors.white),
            ),
          const SizedBox(height: 8),

          // Center on collector location
          FloatingActionButton(
            heroTag: "center",
            mini: true,
            onPressed: _centerOnCollector,
            tooltip: 'Center on my location',
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 8),

          // Toggle location tracking
          StreamBuilder<bool>(
            stream: _getLocationTrackingStatus(),
            builder: (context, snapshot) {
              final isTracking = snapshot.data ?? false;
              return FloatingActionButton(
                heroTag: "tracking",
                mini: true,
                backgroundColor: isTracking
                    ? AppColors.danger
                    : Colors.grey.shade400,
                onPressed: _toggleLocationTracking,
                tooltip: isTracking
                    ? 'Stop location tracking'
                    : 'Start location tracking',
                child: Icon(
                  isTracking ? Icons.location_off : Icons.location_on,
                  color: Colors.white,
                ),
              );
            },
          ),
          const SizedBox(height: 8),

          // Main refresh button
          FloatingActionButton(
            heroTag: "refresh",
            onPressed: _refreshData,
            tooltip: 'Refresh data',
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  // Additional helper methods

  void _refreshData() {
    setState(() {
      _markers.clear();
      _polylines.clear();
      _isLoading = true;
      _errorMessage = null;
      _nearestLocationId = null;
      _nearestDistance = null;
    });
    _initializeMap();
  }

  void _centerOnCollector() {
    _mapController.animateCamera(
      CameraUpdate.newLatLngZoom(_initialPosition, 16),
    );
  }

  void _toggleLocationTracking() async {
    final locationService = CollectorLocationService.instance;

    try {
      if (locationService.isTracking) {
        // Stop tracking
        await locationService.stopLocationTracking();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.location_off, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Location tracking stopped'),
                ],
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        // Start tracking
        await locationService.startLocationTracking(widget.collectorId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.location_on, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Location tracking started'),
                ],
              ),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error toggling location tracking: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // Clean up timers and listeners
    _refreshTimer?.cancel();
    _requestsListener?.cancel();

    // Only stop tracking if no other active pickups
    final locationService = CollectorLocationService.instance;
    locationService.updateTrackingBasedOnRequests(widget.collectorId);

    super.dispose();
  }
}
