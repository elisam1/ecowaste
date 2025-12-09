// ==========================================
// buyer_form_screen.dart (Enhanced Firebase Integration with Mobile Money Only)
// ==========================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BuyerFormScreen extends StatefulWidget {
  final Map<String, dynamic> itemData;
  final String itemId;
  final String sellerId;

  const BuyerFormScreen({
    super.key,
    required this.itemData,
    required this.itemId,
    required this.sellerId,
  });

  @override
  State<BuyerFormScreen> createState() => _BuyerFormScreenState();
}

class _BuyerFormScreenState extends State<BuyerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _momoNumberController = TextEditingController();

  String _selectedPaymentMethod = 'mobile_money';
  bool _isLoading = false;
  bool _agreedToTerms = false;
  Map<String, dynamic>? _sellerData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSellerData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _momoNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Try users collection first
      DocumentSnapshot<Map<String, dynamic>> userDoc = await FirebaseFirestore
          .instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        _nameController.text = userData['name'] ?? '';
        _phoneController.text = userData['phone'] ?? '';
        _locationController.text = userData['location'] ?? '';
        return;
      }

      // Try collectors collection if not found in users
      userDoc = await FirebaseFirestore.instance
          .collection('collectors')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final collectorData = userDoc.data()!;
        _nameController.text = collectorData['name'] ?? '';
        _phoneController.text = collectorData['phone'] ?? '';
        _locationController.text = collectorData['location'] ?? '';
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadSellerData() async {
    try {
      // Try to get seller data from users collection first
      DocumentSnapshot<Map<String, dynamic>> sellerDoc = await FirebaseFirestore
          .instance
          .collection('users')
          .doc(widget.sellerId)
          .get();

      if (!sellerDoc.exists) {
        // Try collectors collection if not found in users
        sellerDoc = await FirebaseFirestore.instance
            .collection('collectors')
            .doc(widget.sellerId)
            .get();
      }

      if (sellerDoc.exists) {
        setState(() {
          _sellerData = sellerDoc.data();
        });
      }
    } catch (e) {
      print('Error loading seller data: $e');
    }
  }

  Future<void> _processPurchase() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_agreedToTerms) {
      _showSnackBar('Please agree to the terms and conditions', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      final purchaseId = FirebaseFirestore.instance
          .collection('purchases')
          .doc()
          .id;
      final isFreeItem = widget.itemData['price'] == 0;

      // Get current timestamp
      final timestamp = Timestamp.now();

      // Create comprehensive purchase record
      final purchaseData = {
        'purchaseId': purchaseId,
        'itemId': widget.itemId,
        'buyerId': currentUserId,
        'sellerId': widget.sellerId,

        // Item details
        'itemDetails': {
          'name': widget.itemData['name'],
          'imageUrl': widget.itemData['imageUrl'],
          'price': widget.itemData['price'],
          'category': widget.itemData['category'],
          'condition': widget.itemData['condition'],
          'description': widget.itemData['description'],
        },

        // Purchase status
        'status': isFreeItem ? 'claimed' : 'pending_payment',
        'paymentStatus': isFreeItem ? 'not_required' : 'pending',
        'createdAt': timestamp,
        'updatedAt': timestamp,

        // Buyer information
        'buyerInfo': {
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'location': _locationController.text.trim(),
          'email': FirebaseAuth.instance.currentUser?.email ?? '',
        },

        // Payment information
        'paymentMethod': isFreeItem ? 'free' : 'mobile_money',
        'paymentDetails': isFreeItem ? {} : _getPaymentDetails(),

        // Transaction details
        'transactionDetails': {
          'amount': widget.itemData['price'],
          'currency': 'GHS',
          'processingFee': _calculateProcessingFee(widget.itemData['price']),
          'totalAmount':
              widget.itemData['price'] +
              _calculateProcessingFee(widget.itemData['price']),
        },

        // Delivery/Pickup information
        'deliveryInfo': {
          'method': 'pickup', // Default to pickup
          'address': _locationController.text.trim(),
          'status': 'pending',
          'scheduledDate': null,
        },

        // Communication
        'notes': '',
        'communicationLog': [],
      };

      // Create purchase record
      await FirebaseFirestore.instance
          .collection('purchases')
          .doc(purchaseId)
          .set(purchaseData);

      // Update item status
      await FirebaseFirestore.instance
          .collection('marketplace_items')
          .doc(widget.itemId)
          .update({
            'status': isFreeItem ? 'claimed' : 'sold',
            'buyerId': currentUserId,
            'soldAt': timestamp,
            'purchaseId': purchaseId,
            'updatedAt': timestamp,
          });

      // Update user profile with latest info (try users first, then collectors)
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .update({
              'name': _nameController.text.trim(),
              'phone': _phoneController.text.trim(),
              'location': _locationController.text.trim(),
              'lastUpdated': timestamp,
            });
      } catch (e) {
        // If user not found, try collectors collection
        await FirebaseFirestore.instance
            .collection('collectors')
            .doc(currentUserId)
            .update({
              'name': _nameController.text.trim(),
              'phone': _phoneController.text.trim(),
              'location': _locationController.text.trim(),
              'lastUpdated': timestamp,
            });
      }

      // Create notification for seller
      await _createSellerNotification(currentUserId, purchaseId, isFreeItem);

      // Update user purchase history
      await _updateUserPurchaseHistory(currentUserId, purchaseId);

      // Send confirmation notification to buyer
      await _createBuyerNotification(currentUserId, purchaseId, isFreeItem);

      // For paid items, simulate payment processing
      if (!isFreeItem) {
        await _processPayment(purchaseId);
      }

      _showSnackBar(
        isFreeItem
            ? 'Item claimed successfully! The seller will contact you shortly.'
            : 'Purchase initiated! You will receive payment confirmation shortly.',
        Colors.green,
      );

      // Return success to previous screen
      Navigator.pop(context, true);
    } catch (e) {
      print('Error processing purchase: $e');
      _showSnackBar(
        'Failed to complete purchase. Please try again.',
        Colors.red,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  double _calculateProcessingFee(num price) {
    // Calculate 2% processing fee with minimum of 1 GHS
    final fee = price * 0.02;
    return fee < 1.0 ? 1.0 : fee;
  }

  Future<void> _processPayment(String purchaseId) async {
    try {
      // Validate seller phone number
      final sellerPhone = _sellerData?['phone'];
      if (sellerPhone == null || sellerPhone.toString().trim().isEmpty) {
        throw Exception('Seller phone number not available');
      }

      // Validate buyer MoMo number
      final buyerMomoNumber = _momoNumberController.text.trim();
      if (buyerMomoNumber.isEmpty) {
        throw Exception('Please enter your MoMo number');
      }

      // Update payment status to processing
      await FirebaseFirestore.instance
          .collection('purchases')
          .doc(purchaseId)
          .update({
            'paymentStatus': 'processing',
            'paymentProcessedAt': Timestamp.now(),
            'paymentDetails': {
              'type': 'mobile_money',
              'buyerMomoNumber': buyerMomoNumber,
              'sellerPhoneNumber': sellerPhone,
              'provider': _detectMomoProvider(buyerMomoNumber),
              'paymentMethod': 'mobile_money_to_seller',
            },
            'updatedAt': Timestamp.now(),
          });

      // Simulate mobile money payment processing
      // In a real app, this would integrate with MTN MoMo, Vodafone Cash, or Airtel Money APIs
      await Future.delayed(const Duration(seconds: 2));

      // Simulate payment success
      await FirebaseFirestore.instance
          .collection('purchases')
          .doc(purchaseId)
          .update({
            'paymentStatus': 'completed',
            'status': 'confirmed',
            'paymentCompletedAt': Timestamp.now(),
            'paymentDetails': {
              'type': 'mobile_money',
              'buyerMomoNumber': buyerMomoNumber,
              'sellerPhoneNumber': sellerPhone,
              'provider': _detectMomoProvider(buyerMomoNumber),
              'paymentMethod': 'mobile_money_to_seller',
              'transactionId': 'MMO_${DateTime.now().millisecondsSinceEpoch}',
              'paymentStatus': 'success',
            },
            'updatedAt': Timestamp.now(),
          });

      // Create payment success notification
      await _createPaymentSuccessNotification(
        purchaseId,
        sellerPhone,
        buyerMomoNumber,
      );
    } catch (e) {
      print('Payment processing error: $e');
      // Update payment status to failed
      await FirebaseFirestore.instance
          .collection('purchases')
          .doc(purchaseId)
          .update({
            'paymentStatus': 'failed',
            'paymentError': e.toString(),
            'paymentDetails': {
              'type': 'mobile_money',
              'buyerMomoNumber': _momoNumberController.text.trim(),
              'sellerPhoneNumber': _sellerData?['phone'] ?? 'Unknown',
              'provider': _detectMomoProvider(
                _momoNumberController.text.trim(),
              ),
              'paymentMethod': 'mobile_money_to_seller',
              'error': e.toString(),
            },
            'updatedAt': Timestamp.now(),
          });

      // Re-throw to show error to user
      rethrow;
    }
  }

  Future<void> _createPaymentSuccessNotification(
    String purchaseId,
    String sellerPhone,
    String buyerMomoNumber,
  ) async {
    try {
      // Notify seller about successful payment
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': widget.sellerId,
        'type': 'payment_received',
        'title': 'Payment Received!',
        'message':
            'You have received GHS ${widget.itemData['price']} from ${_nameController.text.trim()} via mobile money',
        'data': {
          'purchaseId': purchaseId,
          'itemId': widget.itemId,
          'buyerId': FirebaseAuth.instance.currentUser!.uid,
          'itemName': widget.itemData['name'],
          'amount': widget.itemData['price'],
          'buyerPhone': buyerMomoNumber,
          'paymentMethod': 'mobile_money',
        },
        'isRead': false,
        'createdAt': Timestamp.now(),
      });

      // Notify buyer about successful payment
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'type': 'payment_sent',
        'title': 'Payment Sent Successfully!',
        'message':
            'Your payment of GHS ${widget.itemData['price']} has been sent to ${_sellerData?['name'] ?? 'Seller'}',
        'data': {
          'purchaseId': purchaseId,
          'itemId': widget.itemId,
          'sellerId': widget.sellerId,
          'itemName': widget.itemData['name'],
          'amount': widget.itemData['price'],
          'sellerPhone': sellerPhone,
          'paymentMethod': 'mobile_money',
        },
        'isRead': false,
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error creating payment success notifications: $e');
    }
  }

  Future<void> _createSellerNotification(
    String buyerId,
    String purchaseId,
    bool isFreeItem,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': widget.sellerId,
        'type': isFreeItem ? 'item_claimed' : 'item_purchased',
        'title': isFreeItem ? 'Item Claimed!' : 'Item Purchased!',
        'message':
            '${_nameController.text.trim()} has ${isFreeItem ? 'claimed' : 'purchased'} your item: ${widget.itemData['name']}',
        'data': {
          'purchaseId': purchaseId,
          'itemId': widget.itemId,
          'buyerId': buyerId,
          'itemName': widget.itemData['name'],
        },
        'isRead': false,
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error creating seller notification: $e');
    }
  }

  Future<void> _createBuyerNotification(
    String buyerId,
    String purchaseId,
    bool isFreeItem,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': buyerId,
        'type': isFreeItem ? 'claim_confirmed' : 'purchase_confirmed',
        'title': isFreeItem ? 'Claim Confirmed!' : 'Purchase Confirmed!',
        'message':
            'Your ${isFreeItem ? 'claim' : 'purchase'} of ${widget.itemData['name']} has been confirmed. You will be contacted soon.',
        'data': {
          'purchaseId': purchaseId,
          'itemId': widget.itemId,
          'sellerId': widget.sellerId,
          'itemName': widget.itemData['name'],
        },
        'isRead': false,
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error creating buyer notification: $e');
    }
  }

  Future<void> _updateUserPurchaseHistory(
    String userId,
    String purchaseId,
  ) async {
    try {
      // Try to update users collection first
      try {
        await FirebaseFirestore.instance.collection('users').doc(userId).update(
          {
            'purchaseHistory': FieldValue.arrayUnion([purchaseId]),
            'totalPurchases': FieldValue.increment(1),
            'lastPurchaseAt': Timestamp.now(),
          },
        );
        return;
      } catch (e) {
        // If user not found, try collectors collection
        await FirebaseFirestore.instance
            .collection('collectors')
            .doc(userId)
            .update({
              'purchaseHistory': FieldValue.arrayUnion([purchaseId]),
              'totalPurchases': FieldValue.increment(1),
              'lastPurchaseAt': Timestamp.now(),
            });
      }
    } catch (e) {
      print('Error updating user purchase history: $e');
    }
  }

  Map<String, dynamic> _getPaymentDetails() {
    return {
      'type': 'mobile_money',
      'buyerMomoNumber': _momoNumberController.text.trim(),
      'sellerPhoneNumber': _sellerData?['phone'] ?? 'Unknown',
      'provider': _detectMomoProvider(_momoNumberController.text.trim()),
      'maskedBuyerNumber': _maskPhoneNumber(_momoNumberController.text.trim()),
      'paymentMethod': 'mobile_money_to_seller',
    };
  }

  String _detectMomoProvider(String phoneNumber) {
    final number = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (number.startsWith('024') ||
        number.startsWith('054') ||
        number.startsWith('055')) {
      return 'MTN';
    } else if (number.startsWith('020') || number.startsWith('050')) {
      return 'Vodafone';
    } else if (number.startsWith('027') || number.startsWith('057')) {
      return 'AirtelTigo';
    }
    return 'Unknown';
  }

  String _maskPhoneNumber(String phoneNumber) {
    if (phoneNumber.length >= 10) {
      return '***-***-${phoneNumber.substring(phoneNumber.length - 4)}';
    }
    return phoneNumber;
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFreeItem = widget.itemData['price'] == 0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(isFreeItem ? 'Claim Item' : 'Complete Purchase'),
        backgroundColor: const Color.fromARGB(255, 34, 125, 69),
        foregroundColor: const Color.fromARGB(221, 250, 249, 249),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item summary card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        widget.itemData['imageUrl'] ?? '',
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[300],
                            child: const Icon(Icons.image, size: 32),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.itemData['name'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.itemData['condition'] ?? '',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isFreeItem
                                ? 'FREE'
                                : 'GHS ${widget.itemData['price']}',
                            style: TextStyle(
                              color: isFreeItem
                                  ? Colors.green
                                  : Colors.blue[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Buyer Information Section
              _buildSectionTitle('Your Information'),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _nameController,
                label: 'Full Name',
                icon: Icons.person,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              _buildTextField(
                controller: _phoneController,
                label: 'Phone Number',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your phone number';
                  }
                  if (value.trim().length < 10) {
                    return 'Please enter a valid phone number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              _buildTextField(
                controller: _locationController,
                label: 'Your Location',
                icon: Icons.location_on,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your location';
                  }
                  return null;
                },
              ),

              // Payment section (only for paid items)
              if (!isFreeItem) ...[
                const SizedBox(height: 32),
                _buildSectionTitle('Payment Method'),
                const SizedBox(height: 12),

                // Payment method selection - Mobile Money Only
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.mobile_friendly,
                              color: Colors.green[600],
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Mobile Money Payment',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.green[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Payment will be sent directly to the seller\'s mobile money number',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Payment details form - Mobile Money Only
                _buildMoMoForm(),
              ],

              const SizedBox(height: 32),

              // Terms and conditions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _agreedToTerms,
                          onChanged: (value) {
                            setState(() {
                              _agreedToTerms = value ?? false;
                            });
                          },
                        ),
                        Expanded(
                          child: Text(
                            'I agree to the terms and conditions and privacy policy',
                            style: TextStyle(color: Colors.blue[800]),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isFreeItem
                          ? 'By claiming this item, you agree to pick it up from the seller at the agreed location.'
                          : 'By proceeding with payment, you agree to our refund policy and pickup arrangements.',
                      style: TextStyle(color: Colors.blue[700], fontSize: 12),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _processPurchase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          isFreeItem ? 'Claim Item' : 'Complete Purchase',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Security note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.security, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your payment information is secure and encrypted',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    String? hintText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        keyboardType: keyboardType,
        validator: validator,
        inputFormatters: inputFormatters,
      ),
    );
  }

  Widget _buildMoMoForm() {
    final sellerPhone = _sellerData?['phone'] ?? 'Not available';
    final sellerName = _sellerData?['name'] ?? 'Seller';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mobile_friendly, color: Colors.green[600]),
              const SizedBox(width: 8),
              const Text(
                'Mobile Money Payment Details',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Seller information
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person, color: Colors.blue[700], size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Payment Recipient: $sellerName',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.phone, color: Colors.blue[700], size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Seller Phone: $sellerPhone',
                      style: TextStyle(color: Colors.blue[700], fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Buyer MoMo number
          _buildTextField(
            controller: _momoNumberController,
            label: 'Your MoMo Phone Number',
            icon: Icons.phone_android,
            keyboardType: TextInputType.phone,
            hintText: 'e.g., 0241234567',
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your MoMo number';
              }
              if (value.trim().length < 10) {
                return 'Please enter a valid phone number';
              }
              return null;
            },
          ),

          const SizedBox(height: 12),

          // Payment amount display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.payment, color: Colors.orange[700], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Amount: GHS ${widget.itemData['price']}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Processing Fee: GHS ${_calculateProcessingFee(widget.itemData['price'])}',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Total: GHS ${widget.itemData['price'] + _calculateProcessingFee(widget.itemData['price'])}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[900],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Payment instructions
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Instructions:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '1. Enter your MoMo number above\n'
                  '2. Click "Complete Purchase" to proceed\n'
                  '3. You will receive a payment prompt on your phone\n'
                  '4. Enter your MoMo PIN to authorize payment\n'
                  '5. Payment will be sent directly to $sellerName\n'
                  '6. You will receive confirmation SMS',
                  style: TextStyle(color: Colors.green[700], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
