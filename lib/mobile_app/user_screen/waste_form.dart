// Enhanced Beautiful WastePickupFormUpdated with Today/Schedule Options
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/mobile_app/user_screen/user_request_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'dart:math'; // Added for Random

class WastePickupFormUpdated extends StatefulWidget {
  final String userId;

  const WastePickupFormUpdated({super.key, required this.userId});

  @override
  State<WastePickupFormUpdated> createState() => _WastePickupFormUpdatedState();
}

class _WastePickupFormUpdatedState extends State<WastePickupFormUpdated>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _townController = TextEditingController();

  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // Location variables
  Position? _currentPosition;
  bool _isLocationLoading = false;
  String _locationStatus = "Location not set";

  // Date and time variables
  bool _isPickupToday = true; // New: Track if pickup is today or scheduled
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  final Set<String> _selectedCategories = <String>{};

  // Collectors
  List<Map<String, dynamic>> _nearbyCollectors = [];
  String? _selectedCollectorId;
  bool _isLoadingCollectors = false;

  // NEW: Payment and bin selection variables
  int _selectedBinCount = 1;
  bool _isPaymentCompleted = false;
  static const double _pricePerBin = 20.0; // $20 per bin
  static const int _maxBinCount = 10; // Maximum number of bins allowed

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    // Start animations
    _slideController.forward();
    _fadeController.forward();

    _townController.addListener(() {
      final town = _townController.text.trim();
      if (town.isNotEmpty && town.length >= 3) {
        _debounceFetch(town);
      }
    });
  }

  // Debounce helper
  Timer? _debounce;
  void _debounceFetch(String town) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchNearbyCollectors();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _townController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // Date and time selection methods
  Future<void> _selectDate() async {
    HapticFeedback.lightImpact();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().add(
        const Duration(days: 1),
      ), // Start from tomorrow
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green.shade600,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    HapticFeedback.lightImpact();

    // For today, check current time and set minimum time
    TimeOfDay initialTime;
    if (_isPickupToday) {
      final now = DateTime.now();
      final currentTime = TimeOfDay.fromDateTime(now);
      final currentMinutes = currentTime.hour * 60 + currentTime.minute;

      // If it's past 4 PM, don't allow today pickup
      if (currentMinutes >= 16 * 60) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text(
              'It\'s too late for today\'s pickup. Please schedule for tomorrow.',
            ),
          ),
        );
        return;
      }

      // Set initial time to at least 1 hour from now, but not past 5 PM
      final oneHourLater = now.add(const Duration(hours: 1));
      initialTime = TimeOfDay.fromDateTime(oneHourLater);
    } else {
      initialTime = _selectedTime ?? const TimeOfDay(hour: 9, minute: 0);
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green.shade600,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedTime) {
      final int pickedMinutes = picked.hour * 60 + picked.minute;
      const int minMinutes = 9 * 60; // 9:00 AM
      const int maxMinutes = 17 * 60; // 5:00 PM

      if (_isPickupToday) {
        // For today, ensure time is at least 30 minutes from now
        final now = DateTime.now();
        final minTimeToday = now.add(const Duration(minutes: 30));
        final minTimeTodayMinutes =
            minTimeToday.hour * 60 + minTimeToday.minute;

        if (pickedMinutes < minTimeTodayMinutes || pickedMinutes > maxMinutes) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text(
                'For today\'s pickup, please select a time at least 30 minutes from now and before 5:00 PM\nCurrent time: ${TimeOfDay.fromDateTime(now).format(context)}',
              ),
            ),
          );
          return;
        }
      } else {
        // For scheduled pickup, check normal business hours
        if (pickedMinutes < minMinutes || pickedMinutes > maxMinutes) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.red,
              content: Text('Please select a time between 9:00 AM and 5:00 PM'),
            ),
          );
          return;
        }
      }

      setState(() {
        _selectedTime = picked;
      });
    }
  }

  // Get Current Location
  Future<void> _getCurrentLocation() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isLocationLoading = true;
      _locationStatus = "Getting location...";
    });

    try {
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

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _locationStatus = "📍 Location captured successfully";
        _isLocationLoading = false;
      });
    } catch (e) {
      setState(() {
        _locationStatus = "❌ Error: ${e.toString()}";
        _isLocationLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to get location: ${e.toString()}'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _fetchNearbyCollectors() async {
    setState(() {
      _isLoadingCollectors = true;
      _nearbyCollectors.clear();
      _selectedCollectorId = null;
    });

    try {
      String userTown = _townController.text.trim().toLowerCase();

      if (userTown.isEmpty) {
        throw Exception('Please enter your town to fetch collectors.');
      }

      QuerySnapshot collectorsSnapshot = await FirebaseFirestore.instance
          .collection('collectors')
          .where('isActive', isEqualTo: true)
          .where('town', isEqualTo: userTown)
          .get();

      List<Map<String, dynamic>> townCollectors = collectorsSnapshot.docs.map((
        doc,
      ) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Collector',
          'phone': data['phone'] ?? '',
          'town': data['town'],
        };
      }).toList();

      setState(() {
        _nearbyCollectors = townCollectors;
        _isLoadingCollectors = false;
      });

      // Auto-select a random collector if available
      if (_nearbyCollectors.isNotEmpty) {
        // Randomly select a collector instead of always picking the first one
        final random = Random();
        final randomIndex = random.nextInt(_nearbyCollectors.length);
        final selectedCollector = _nearbyCollectors[randomIndex];
        
        setState(() {
          _selectedCollectorId = selectedCollector['id'];
        });
        _showSnackBar(
          'Collector randomly selected: ${selectedCollector['name']}',
          Colors.green.shade600,
        );
      } else {
        _showSnackBar(
          'No active collectors found in your town. Your request will be queued and assigned when a collector becomes available.',
          Colors.orange.shade600,
        );
      }
    } catch (e) {
      setState(() {
        _isLoadingCollectors = false;
      });
      _showSnackBar(
        'Failed to fetch collectors: ${e.toString()}',
        Colors.red.shade600,
      );
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _submitPickupRequest() async {
    HapticFeedback.mediumImpact();

    if (!_formKey.currentState!.validate()) return;

    // Validation for scheduled pickup
    if (!_isPickupToday) {
      if (_selectedDate == null) {
        _showErrorSnackBar('Please select a pickup date');
        return;
      }
      if (_selectedTime == null) {
        _showErrorSnackBar('Please select a pickup time');
        return;
      }
    } else {
      // For today pickup, time is required
      if (_selectedTime == null) {
        _showErrorSnackBar('Please select a pickup time for today');
        return;
      }
    }

    if (_currentPosition == null) {
      _showErrorSnackBar('Please set your location first');
      return;
    }

    // Collector selection is now optional - will be auto-assigned if available
    // _selectedCollectorId can be null if no collectors are available

    try {
      _showLoadingDialog();

      // Fetch user info from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (!userDoc.exists) {
        Navigator.of(context).pop();
        _showErrorSnackBar('User data not found');
        return;
      }

      final userData = userDoc.data()!;
      final userName = userData['name'] ?? 'Unknown';
      final userPhone = userData['phone'] ?? '';

      // Calculate pickup date time
      DateTime pickupDateTime;
      if (_isPickupToday) {
        final today = DateTime.now();
        pickupDateTime = DateTime(
          today.year,
          today.month,
          today.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );
      } else {
        pickupDateTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );
      }

      // Prepare collector data
      String? collectorId = _selectedCollectorId;
      String? collectorName;

      if (_selectedCollectorId != null) {
        final selectedCollector = _nearbyCollectors.firstWhere(
          (collector) => collector['id'] == _selectedCollectorId,
          orElse: () => {},
        );
        collectorName = selectedCollector['name'] ?? 'Unknown Collector';
      }

      // Save pickup request
      final pickupRequestRef = await FirebaseFirestore.instance
          .collection('pickup_requests')
          .add({
            'userId': widget.userId,
            'userName': userName,
            'userPhone': userPhone,
            'userTown': _townController.text.trim().toLowerCase(),
            'userLatitude': _currentPosition!.latitude,
            'userLongitude': _currentPosition!.longitude,
            'collectorId': collectorId ?? '', // Empty string if no collector
            'collectorName':
                collectorName ?? '', // Empty string if no collector
            'pickupDate': Timestamp.fromDate(pickupDateTime),
            'isPickupToday':
                _isPickupToday, // Track if it was scheduled for today
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
            // NEW: Payment and bin information
            'binCount': _selectedBinCount,
            'pricePerBin': _pricePerBin,
            'totalAmount': _selectedBinCount * _pricePerBin,
            'paymentStatus': 'paid',
            'paymentHeld': true, // Payment is held until completion
            'paymentReleased': false, // Payment not yet released to collector
          });

      // Create notification for the collector if one is selected
      if (collectorId != null && collectorId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance.collection('notifications').add({
            'userId': collectorId,
            'type': 'new_pickup_request',
            'title': '🗑️ New Pickup Request',
            'message':
                '${userName} has requested a pickup in ${_townController.text.trim()}',
            'data': {
              'pickupRequestId': pickupRequestRef.id,
              'userId': widget.userId,
              'userName': userName,
              'userPhone': userPhone,
              'userTown': _townController.text.trim(),
              'pickupDate': Timestamp.fromDate(pickupDateTime),
              'status': 'pending',
            },
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          print('Error creating pickup request notification: $e');
        }
      }

      Navigator.of(context).pop();
      _showSuccessDialog();
    } catch (e) {
      Navigator.of(context).pop();
      _showErrorSnackBar('Failed to submit request: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // NEW: Handle submit with payment
  Future<void> _handleSubmitWithPayment() async {
    HapticFeedback.mediumImpact();

    // First validate the form
    if (!_formKey.currentState!.validate()) return;

    // Validation for scheduled pickup
    if (!_isPickupToday) {
      if (_selectedDate == null) {
        _showErrorSnackBar('Please select a pickup date');
        return;
      }
      if (_selectedTime == null) {
        _showErrorSnackBar('Please select a pickup time');
        return;
      }
    } else {
      // For today pickup, time is required
      if (_selectedTime == null) {
        _showErrorSnackBar('Please select a pickup time for today');
        return;
      }
    }

    if (_currentPosition == null) {
      _showErrorSnackBar('Please set your location first');
      return;
    }

    // Now process payment
    await _simulatePayment();
  }

  // NEW: Payment simulation method
  Future<void> _simulatePayment() async {
    HapticFeedback.mediumImpact();

    // Show payment processing dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.orange.shade600,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Processing Payment...",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                "Simulating payment processing",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );

    // Simulate payment processing delay
    await Future.delayed(const Duration(seconds: 2));

    // Close loading dialog
    Navigator.of(context).pop();

    // Show payment success dialog
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 48,
                  color: Colors.green.shade600,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Payment Successful!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E2E2E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your payment of \$${(_selectedBinCount * _pricePerBin).toStringAsFixed(2)} has been processed successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                'Payment will be held and released to the collector upon request completion.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    setState(() {
                      _isPaymentCompleted = true;
                    });

                    // Automatically submit the request after payment
                    await _submitPickupRequest();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.green.shade600,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Submitting your request...",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                "This won't take long",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog() {
    final bool hasCollector = _selectedCollectorId != null;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: hasCollector
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasCollector ? Icons.check_circle : Icons.schedule,
                  size: 48,
                  color: hasCollector
                      ? Colors.green.shade600
                      : Colors.orange.shade600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                hasCollector ? 'Success!' : 'Request Queued!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: hasCollector
                      ? Colors.green.shade800
                      : Colors.orange.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hasCollector
                    ? 'Your pickup request has been submitted successfully and assigned to a collector. You can track its status in the requests tab.'
                    : 'Your pickup request has been queued successfully. It will be automatically assigned to a collector when one becomes available in your area.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _resetForm();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('OK'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _resetForm();
                        Navigator.of(context).pushNamed(
                          '/user-requests',
                          arguments: {'userId': widget.userId},
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasCollector
                            ? Colors.green.shade600
                            : Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('View Requests'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _resetForm() {
    setState(() {
      _townController.clear();
      _selectedCategories.clear();
      _currentPosition = null;
      _locationStatus = "Location not set";
      _nearbyCollectors.clear();
      _selectedCollectorId = null;
      _isPickupToday = true;
      _selectedDate = null;
      _selectedTime = null;
      // NEW: Reset payment variables
      _selectedBinCount = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // Beautiful App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Request Pickup',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.green.shade600, Colors.green.shade800],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -50,
                      top: -50,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 20,
                      bottom: 20,
                      child: Icon(
                        Icons.recycling,
                        size: 40,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
          ),

          // Form Content
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // User Information Card
                          _buildAnimatedCard(
                            delay: 0,
                            child: _buildUserInfoSection(),
                          ),
                          const SizedBox(height: 16),

                          // NEW: Pickup Type Selection Card
                          _buildAnimatedCard(
                            delay: 200,
                            child: _buildPickupTypeSection(),
                          ),
                          const SizedBox(height: 16),

                          // Schedule Card (Updated)
                          _buildAnimatedCard(
                            delay: 500,
                            child: _buildScheduleSection(),
                          ),
                          const SizedBox(height: 16),
                          // NEW: Bin Selection and Payment Card
                          _buildAnimatedCard(
                            delay: 300,
                            child: _buildBinSelectionAndPaymentSection(),
                          ),

                          const SizedBox(height: 16),

                          // Location Card
                          _buildAnimatedCard(
                            delay: 700,
                            child: _buildLocationSection(),
                          ),

                          const SizedBox(height: 16),

                          // Collector Selection Card
                          _buildAnimatedCard(
                            delay: 900,
                            child: _buildCollectorSection(),
                          ),

                          const SizedBox(height: 32),

                          // Submit Button
                          _buildAnimatedCard(
                            delay: 1100,
                            child: _buildSubmitButton(),
                          ),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedCard({required Widget child, required int delay}) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600 + delay),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: child,
    );
  }

  Widget _buildUserInfoSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person,
                  color: Colors.blue.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Your Information',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E2E2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStyledTextField(
            controller: _townController,
            label: 'Town/City',
            icon: Icons.location_city_outlined,
            hint: 'Enter your town or city',
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your town or city';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  // NEW: Pickup Type Selection Section
  Widget _buildPickupTypeSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.today,
                  color: Colors.indigo.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'When do you need pickup?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E2E2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Choose if you want pickup today or schedule for later',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _isPickupToday = true;
                      _selectedDate =
                          null; // Clear scheduled date when switching to today
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _isPickupToday
                          ? Colors.indigo.shade50
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isPickupToday
                            ? Colors.indigo.shade600
                            : Colors.grey.shade300,
                        width: _isPickupToday ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.today,
                          size: 32,
                          color: _isPickupToday
                              ? Colors.indigo.shade600
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Today',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _isPickupToday
                                ? Colors.indigo.shade700
                                : Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Same-day pickup',
                          style: TextStyle(
                            fontSize: 12,
                            color: _isPickupToday
                                ? Colors.indigo.shade600
                                : Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _isPickupToday = false;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: !_isPickupToday
                          ? Colors.indigo.shade50
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: !_isPickupToday
                            ? Colors.indigo.shade600
                            : Colors.grey.shade300,
                        width: !_isPickupToday ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 32,
                          color: !_isPickupToday
                              ? Colors.indigo.shade600
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Schedule',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: !_isPickupToday
                                ? Colors.indigo.shade700
                                : Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pick date & time',
                          style: TextStyle(
                            fontSize: 12,
                            color: !_isPickupToday
                                ? Colors.indigo.shade600
                                : Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green.shade600, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _buildScheduleSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isPickupToday ? Icons.access_time : Icons.schedule,
                  color: Colors.orange.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                _isPickupToday ? 'Pick Time for Today' : 'Schedule Pickup',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E2E2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isPickupToday
                ? 'Select what time you want pickup today'
                : 'Choose when you want your waste to be collected',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),

          if (_isPickupToday) ...[
            // Show only time selector for today
            _buildScheduleButton(
              icon: Icons.access_time,
              label: _selectedTime == null
                  ? 'Select Time for Today'
                  : 'Today at ${_selectedTime!.format(context)}',
              onTap: _selectTime,
              isSelected: _selectedTime != null,
              fullWidth: true,
            ),
          ] else ...[
            // Show both date and time selectors for scheduled pickup
            Row(
              children: [
                Expanded(
                  child: _buildScheduleButton(
                    icon: Icons.calendar_today,
                    label: _selectedDate == null
                        ? 'Select Date'
                        : DateFormat('MMM dd, yyyy').format(_selectedDate!),
                    onTap: _selectDate,
                    isSelected: _selectedDate != null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildScheduleButton(
                    icon: Icons.access_time,
                    label: _selectedTime == null
                        ? 'Select Time'
                        : _selectedTime!.format(context),
                    onTap: _selectTime,
                    isSelected: _selectedTime != null,
                  ),
                ),
              ],
            ),
          ],

          // Show helpful info
          if (_isPickupToday) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, size: 16, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pickup must be at least 30 minutes from now and before 5:00 PM',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScheduleButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isSelected,
    bool fullWidth = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.green.shade600 : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: fullWidth
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: isSelected
                        ? Colors.green.shade600
                        : Colors.grey.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.green.shade600
                          : Colors.grey.shade700,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  Icon(
                    icon,
                    color: isSelected
                        ? Colors.green.shade600
                        : Colors.grey.shade600,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.green.shade600
                          : Colors.grey.shade700,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.location_on,
                  color: Colors.red.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Your Location',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E2E2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'We need your location to find nearby collectors',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _currentPosition != null
                  ? Colors.green.shade50
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _currentPosition != null
                    ? Colors.green.shade300
                    : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _currentPosition != null
                      ? Icons.check_circle
                      : Icons.location_off,
                  color: _currentPosition != null
                      ? Colors.green.shade600
                      : Colors.grey.shade600,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _locationStatus,
                    style: TextStyle(
                      color: _currentPosition != null
                          ? Colors.green.shade700
                          : Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLocationLoading ? null : _getCurrentLocation,
              icon: _isLocationLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.my_location),
              label: Text(
                _isLocationLoading
                    ? 'Getting Location...'
                    : 'Get Current Location',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectorSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person_search,
                  color: Colors.purple.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Collector Assignment',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E2E2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Collectors will be automatically assigned based on availability',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          if (_isLoadingCollectors)
            Container(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.purple.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Finding collectors in your area...',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_nearbyCollectors.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.schedule, size: 48, color: Colors.orange.shade600),
                  const SizedBox(height: 16),
                  Text(
                    'No Active Collectors Available',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your request will be queued and automatically assigned when a collector becomes available in your area.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.orange.shade700,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Request will be queued',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: _nearbyCollectors.asMap().entries.map((entry) {
                  final index = entry.key;
                  final collector = entry.value;
                  final isSelected = _selectedCollectorId == collector['id'];
                  final isLast = index == _nearbyCollectors.length - 1;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedCollectorId = collector['id'];
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.purple.shade50
                            : Colors.transparent,
                        borderRadius: BorderRadius.vertical(
                          top: index == 0
                              ? const Radius.circular(12)
                              : Radius.zero,
                          bottom: isLast
                              ? const Radius.circular(12)
                              : Radius.zero,
                        ),
                        border: isSelected
                            ? Border.all(
                                color: Colors.purple.shade600,
                                width: 2,
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.purple.shade600
                                  : Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.person,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey.shade600,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  collector['name'] ?? 'Unknown Collector',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.purple.shade800
                                        : Colors.grey.shade800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  collector['phone'] ?? 'No phone',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isSelected
                                        ? Colors.purple.shade600
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade600,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          if (_nearbyCollectors.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Collector automatically selected. You can change the selection if needed.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBinSelectionAndPaymentSection() {
    final totalCost = _selectedBinCount * _pricePerBin;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.delete_sweep,
                  color: Colors.orange.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Bin Selection',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E2E2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Bin Selection
          Text(
            'How many bins need to be emptied?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),

          // Bin Counter
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Decrease Button
                GestureDetector(
                  onTap: () {
                    if (_selectedBinCount > 1) {
                      setState(() {
                        _selectedBinCount--;
                      });
                    }
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _selectedBinCount > 1
                          ? Colors.orange.shade600
                          : Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.remove,
                      color: _selectedBinCount > 1
                          ? Colors.white
                          : Colors.grey.shade500,
                      size: 24,
                    ),
                  ),
                ),

                const SizedBox(width: 24),

                // Bin Count Display
                Column(
                  children: [
                    Text(
                      '$_selectedBinCount',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    Text(
                      'Bin${_selectedBinCount > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.orange.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 24),

                // Increase Button
                GestureDetector(
                  onTap: () {
                    if (_selectedBinCount < _maxBinCount) {
                      setState(() {
                        _selectedBinCount++;
                      });
                    }
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _selectedBinCount < _maxBinCount
                          ? Colors.orange.shade600
                          : Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add,
                      color: _selectedBinCount < _maxBinCount
                          ? Colors.white
                          : Colors.grey.shade500,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Cost Display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Cost',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      '\$${totalCost.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Rate: \$${_pricePerBin.toStringAsFixed(2)} per bin',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    Text(
                      '${_selectedBinCount} × \$${_pricePerBin.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final totalCost = _selectedBinCount * _pricePerBin;

    return Container(
      width: double.infinity,
      height: 70,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [Colors.green.shade600, Colors.green.shade700],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade600.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _handleSubmitWithPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.send, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Text(
                  _isPickupToday
                      ? 'Request Pickup Today'
                      : 'Schedule Pickup Request',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Pay \$${totalCost.toStringAsFixed(2)} • ${_selectedBinCount} bin${_selectedBinCount > 1 ? 's' : ''}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
