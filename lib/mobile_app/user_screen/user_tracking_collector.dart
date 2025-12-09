import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'dart:math' as math;
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class UserCollectorTrackingScreen extends StatefulWidget {
  final String requestId;
  final String userId;
  const UserCollectorTrackingScreen({
    required this.requestId,
    required this.userId,
    super.key,
  });

  @override
  State<UserCollectorTrackingScreen> createState() =>
      _UserCollectorTrackingScreenState();
}

class _UserCollectorTrackingScreenState
    extends State<UserCollectorTrackingScreen> {
  late GoogleMapController _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _userLocation;
  LatLng? _collectorLocation;
  bool _isLoading = true;
  String? _errorMessage;
  String? _collectorName;
  String? _collectorPhone;
  String _requestStatus = 'in_progress';
  double? _estimatedDistance;
  String? _estimatedTime;
  Timer? _locationUpdateTimer;
  StreamSubscription<DocumentSnapshot>? _requestStatusListener;
  StreamSubscription<DocumentSnapshot>? _collectorLocationListener;
  final log = Logger();

  // Add your Google Maps API key here
  static const String _googleMapsApiKey =
      'AIzaSyDfV-BwmObibrIHDQB4cRuE53BDvspD9Aw';

  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  Future<void> _initializeTracking() async {
    try {
      await _loadRequestDetails();
      await _startLocationTracking();
      _listenToRequestStatusChanges();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize tracking: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRequestDetails() async {
    try {
      // Get pickup request details
      final requestDoc = await FirebaseFirestore.instance
          .collection('pickup_requests')
          .doc(widget.requestId)
          .get();

      if (!requestDoc.exists) {
        throw Exception('Pickup request not found');
      }

      final requestData = requestDoc.data()!;
      final collectorId = requestData['collectorId'];

      if (collectorId == null) {
        throw Exception('No collector assigned to this request');
      }

      // Get collector details
      final collectorDoc = await FirebaseFirestore.instance
          .collection('collectors')
          .doc(collectorId)
          .get();

      if (!collectorDoc.exists) {
        throw Exception('Collector information not found');
      }

      final collectorData = collectorDoc.data()!;

      // Get user location from request
      final userLatitude = requestData['userLatitude'];
      final userLongitude = requestData['userLongitude'];

      if (userLatitude != null && userLongitude != null) {
        _userLocation = LatLng(
          userLatitude is double
              ? userLatitude
              : double.parse(userLatitude.toString()),
          userLongitude is double
              ? userLongitude
              : double.parse(userLongitude.toString()),
        );
      }

      setState(() {
        _collectorName = collectorData['name'] ?? 'Waste Collector';
        _collectorPhone = collectorData['phone'];
        _requestStatus = requestData['status'] ?? 'in_progress';
      });

      // Add user location marker
      if (_userLocation != null) {
        _addUserMarker();
      }

      log.i('Request details loaded successfully');
    } catch (e) {
      log.e('Failed to load request details: $e');
      //throw Exception('Failed to load request details: $e');
    }
  }

  void _addUserMarker() {
    setState(() {
      _markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: _userLocation!,
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'Pickup point',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    });
  }

  Future<void> _startLocationTracking() async {
    try {
      // Get initial collector location and start listening for updates
      await _updateCollectorLocation();
      _startCollectorLocationListener();

      // Set up periodic location updates
      _locationUpdateTimer = Timer.periodic(
        const Duration(seconds: 10),
        (timer) => _updateCollectorLocation(),
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      throw Exception('Failed to start location tracking: $e');
    }
  }

  void _startCollectorLocationListener() {
    // Get collector ID from the request
    FirebaseFirestore.instance
        .collection('pickup_requests')
        .doc(widget.requestId)
        .get()
        .then((doc) {
          if (doc.exists) {
            final collectorId = doc.data()?['collectorId'];
            if (collectorId != null) {
              // Listen to collector's location updates in real-time
              _collectorLocationListener = FirebaseFirestore.instance
                  .collection('collector_locations')
                  .doc(collectorId)
                  .snapshots()
                  .listen((doc) {
                    if (doc.exists && mounted) {
                      final data = doc.data();
                      if (data != null) {
                        _updateCollectorMarkerFromData(data);
                      }
                    }
                  });
            }
          }
        });
  }

  Future<void> _updateCollectorLocation() async {
    try {
      // Get collector ID from the request
      final requestDoc = await FirebaseFirestore.instance
          .collection('pickup_requests')
          .doc(widget.requestId)
          .get();

      if (!requestDoc.exists) return;

      final collectorId = requestDoc.data()?['collectorId'];
      if (collectorId == null) return;

      // Get collector's current location
      final locationDoc = await FirebaseFirestore.instance
          .collection('collector_locations')
          .doc(collectorId)
          .get();

      if (locationDoc.exists) {
        final locationData = locationDoc.data()!;
        _updateCollectorMarkerFromData(locationData);
      }
    } catch (e) {
      log.e('Error updating collector location: $e');
    }
  }

  void _updateCollectorMarkerFromData(Map<String, dynamic> locationData) {
    final latitude = locationData['latitude'];
    final longitude = locationData['longitude'];
    final timestamp = locationData['timestamp'] as Timestamp?;

    if (latitude != null && longitude != null) {
      final newCollectorLocation = LatLng(
        latitude is double ? latitude : double.parse(latitude.toString()),
        longitude is double ? longitude : double.parse(longitude.toString()),
      );

      // Check if location has changed significantly
      if (_collectorLocation == null ||
          Geolocator.distanceBetween(
                _collectorLocation!.latitude,
                _collectorLocation!.longitude,
                newCollectorLocation.latitude,
                newCollectorLocation.longitude,
              ) >
              10) {
        // Only update if moved more than 10 meters
        _collectorLocation = newCollectorLocation;
        _updateCollectorMarker();
        _calculateRoute();

        // Show last update time
        if (timestamp != null && mounted) {
          final lastUpdate = timestamp.toDate();
          final now = DateTime.now();
          final difference = now.difference(lastUpdate);

          String updateText;
          if (difference.inMinutes < 1) {
            updateText = 'Just now';
          } else if (difference.inMinutes < 60) {
            updateText = '${difference.inMinutes}m ago';
          } else {
            updateText = '${difference.inHours}h ago';
          }

          if (mounted) {
            setState(() {
              // Update UI with last seen time if needed
            });
          }
        }
      }
    }
  }

  void _updateCollectorMarker() {
    if (_collectorLocation == null) return;

    setState(() {
      // Remove old collector marker
      _markers.removeWhere((m) => m.markerId.value == 'collector');

      // Add new collector marker
      _markers.add(
        Marker(
          markerId: const MarkerId('collector'),
          position: _collectorLocation!,
          infoWindow: InfoWindow(
            title: _collectorName ?? 'Waste Collector',
            snippet: 'On the way to you',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    });
  }

  Future<void> _calculateRoute() async {
    if (_userLocation == null || _collectorLocation == null) return;

    // Calculate straight-line distance
    final distance = Geolocator.distanceBetween(
      _collectorLocation!.latitude,
      _collectorLocation!.longitude,
      _userLocation!.latitude,
      _userLocation!.longitude,
    );

    setState(() {
      _estimatedDistance = distance;
    });

    // Get route if API key is configured
    if (_googleMapsApiKey != 'YOUR_GOOGLE_MAPS_API_KEY') {
      await _getDirectionsRoute();
    } else {
      _createSimpleRoute();
    }
  }

  Future<void> _getDirectionsRoute() async {
    if (_collectorLocation == null || _userLocation == null) return;

    try {
      final String url =
          'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${_collectorLocation!.latitude},${_collectorLocation!.longitude}&'
          'destination=${_userLocation!.latitude},${_userLocation!.longitude}&'
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
          final distanceValue =
              route['legs'][0]['distance']['value']; // in meters

          setState(() {
            _estimatedDistance = distanceValue.toDouble();
            _estimatedTime = duration;
          });

          _createRoutePolyline(routeCoords);
        } else {
          _createSimpleRoute();
        }
      } else {
        _createSimpleRoute();
      }
    } catch (e) {
      log.e('Error getting directions: $e');
      _createSimpleRoute();
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

  void _createRoutePolyline(List<LatLng> routeCoords) {
    setState(() {
      _polylines.clear();
    });

    final Polyline route = Polyline(
      polylineId: const PolylineId('collector_route'),
      points: routeCoords,
      color: Colors.blue,
      width: 5,
      patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
    );

    setState(() {
      _polylines.add(route);
    });

    // Fit route in view
    _fitMarkersInView();
  }

  void _createSimpleRoute() {
    if (_collectorLocation == null || _userLocation == null) return;

    final List<LatLng> routePoints = [_collectorLocation!, _userLocation!];

    final Polyline route = Polyline(
      polylineId: const PolylineId('collector_route'),
      points: routePoints,
      color: Colors.blue,
      width: 4,
      patterns: [PatternItem.dash(15), PatternItem.gap(8)],
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
    );

    setState(() {
      _polylines.clear();
      _polylines.add(route);
    });

    _fitMarkersInView();
  }

  void _fitMarkersInView() {
    if (_markers.length < 2) return;

    double minLat = _markers.first.position.latitude;
    double maxLat = _markers.first.position.latitude;
    double minLng = _markers.first.position.longitude;
    double maxLng = _markers.first.position.longitude;

    for (final marker in _markers) {
      minLat = math.min(minLat, marker.position.latitude);
      maxLat = math.max(maxLat, marker.position.latitude);
      minLng = math.min(minLng, marker.position.longitude);
      maxLng = math.max(maxLng, marker.position.longitude);
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
  }

  void _listenToRequestStatusChanges() {
    _requestStatusListener = FirebaseFirestore.instance
        .collection('pickup_requests')
        .doc(widget.requestId)
        .snapshots()
        .listen((doc) {
          if (doc.exists && mounted) {
            final newStatus = doc.data()?['status'];
            if (newStatus != _requestStatus) {
              setState(() {
                _requestStatus = newStatus ?? 'unknown';
              });

              // Show status change notification
              _showStatusChangeDialog(newStatus);

              // Stop tracking if completed
              if (newStatus == 'completed') {
                _stopTracking();
              }
            }
          }
        });
  }

  void _showStatusChangeDialog(String newStatus) {
    String title;
    String message;
    Color color;

    switch (newStatus) {
      case 'completed':
        title = 'Pickup Completed!';
        message = 'Your waste has been successfully collected. Thank you!';
        color = Colors.green;
        break;
      case 'cancelled':
        title = 'Pickup Cancelled';
        message = 'The pickup request has been cancelled.';
        color = Colors.red;
        break;
      default:
        title = 'Status Updated';
        message = 'Pickup status changed to: $newStatus';
        color = Colors.blue;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              newStatus == 'completed'
                  ? Icons.check_circle
                  : newStatus == 'cancelled'
                  ? Icons.cancel
                  : Icons.info,
              color: color,
            ),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (newStatus == 'completed' || newStatus == 'cancelled') {
                Navigator.pop(context); // Go back to previous screen
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _stopTracking() {
    _locationUpdateTimer?.cancel();
    _requestStatusListener?.cancel();
    _collectorLocationListener?.cancel();
  }

  void _callCollector() async {
    if (_collectorPhone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Collector phone number not available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final url = 'tel:$_collectorPhone';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not make phone call'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getStatusColor() {
    switch (_requestStatus) {
      case 'in_progress':
        return 'blue';
      case 'completed':
        return 'green';
      case 'cancelled':
        return 'red';
      default:
        return 'grey';
    }
  }

  Color _getStatusColorValue() {
    switch (_requestStatus) {
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'in_progress':
        return 'On the way';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status.replaceAll('_', ' ').toUpperCase();
    }
  }

  @override
  void dispose() {
    _stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Collector'),
        backgroundColor: _getStatusColorValue(),
        foregroundColor: Colors.white,
        actions: [
          if (_collectorPhone != null)
            IconButton(
              icon: const Icon(Icons.phone),
              onPressed: _callCollector,
              tooltip: 'Call collector',
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
                  Text('Loading tracking data...'),
                ],
              ),
            )
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _errorMessage = null;
                        _isLoading = true;
                      });
                      _initializeTracking();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _userLocation ?? const LatLng(6.6730, -1.5715),
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
                  zoomControlsEnabled: true,
                  compassEnabled: true,
                  mapToolbarEnabled: false,
                ),
                // Status and info card
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Card(
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _getStatusColorValue(),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatStatus(_requestStatus),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              if (_collectorPhone != null)
                                IconButton(
                                  icon: const Icon(Icons.phone),
                                  onPressed: _callCollector,
                                  tooltip: 'Call collector',
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.person,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(_collectorName ?? 'Unknown Collector'),
                            ],
                          ),
                          if (_estimatedDistance != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.straighten,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Distance: ${(_estimatedDistance! / 1000).toStringAsFixed(2)} km',
                                ),
                              ],
                            ),
                          ],
                          if (_estimatedTime != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text('Estimated time: $_estimatedTime'),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                // Location update indicator
                if (_collectorLocation != null)
                  Positioned(
                    bottom: 100,
                    right: 16,
                    child: Card(
                      color: Colors.green.shade100,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Colors.green,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Live tracking',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
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
          if (_markers.isNotEmpty)
            FloatingActionButton(
              heroTag: "fit",
              mini: true,
              onPressed: _fitMarkersInView,
              child: const Icon(Icons.fit_screen),
            ),
          const SizedBox(height: 8),
          if (_userLocation != null)
            FloatingActionButton(
              heroTag: "center",
              onPressed: () {
                _mapController.animateCamera(
                  CameraUpdate.newLatLngZoom(_userLocation!, 16),
                );
              },
              child: const Icon(Icons.my_location),
            ),
        ],
      ),
    );
  }
}
