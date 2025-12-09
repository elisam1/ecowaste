import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class AccessRouteScreen extends StatefulWidget {
  const AccessRouteScreen({Key? key}) : super(key: key);

  @override
  State<AccessRouteScreen> createState() => _AccessRouteScreenState();
}

class _AccessRouteScreenState extends State<AccessRouteScreen> {
  GoogleMapController? _mapController;
  LatLng _defaultCenter = const LatLng(5.5600, -0.2050); // Accra, Ghana
  LatLng? _collectorLocation;

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  Future<void> _fetchCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();

    if (!serviceEnabled || permission == LocationPermission.deniedForever) {
      // Show an error or prompt user to enable location
      return;
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _collectorLocation = LatLng(position.latitude, position.longitude);
      });
      _mapController?.animateCamera(CameraUpdate.newLatLng(_collectorLocation!));
    } catch (e) {
      print("Error fetching location: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialPosition = _collectorLocation ?? _defaultCenter;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Access Route"),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: initialPosition,
          zoom: 11.0, // Region-level zoom (e.g. Greater Accra)
        ),
        onMapCreated: (controller) {
          _mapController = controller;
        },
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
    );
  }
}
