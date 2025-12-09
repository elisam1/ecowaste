// add_item_screen.dart
// ==========================================

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController locationController = TextEditingController();

  String? selectedCategory;
  String? selectedCondition;
  File? _image;
  bool _isLoading = false;

  final List<String> categories = [
    'Furniture',
    'Electronics',
    'Plastic',
    'Metal',
    'Books',
    'Clothing',
    'Tools',
    'Sports',
    'Home',
    'Other',
  ];

  final List<String> conditions = ['New', 'Exchange', 'Fair', 'Free'];

  @override
  void dispose() {
    nameController.dispose();
    descController.dispose();
    priceController.dispose();
    locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();

      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source != null) {
        final picked = await picker.pickImage(
          source: source,
          maxWidth: 1000,
          maxHeight: 1000,
          imageQuality: 85,
        );

        if (picked != null) {
          setState(() {
            _image = File(picked.path);
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  Future<String> _uploadImage(File imageFile) async {
    final String fileId = const Uuid().v4();
    final ref = FirebaseStorage.instance.ref().child(
      'marketplace_images/$fileId.jpg',
    );

    await ref.putFile(imageFile);
    return await ref.getDownloadURL();
  }

  Future<void> _submitItem() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar('Please fill all required fields');
      return;
    }

    if (_image == null) {
      _showErrorSnackBar('Please select an image');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String imageUrl = await _uploadImage(_image!);
      final userId = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance.collection('marketplace_items').add({
        'name': nameController.text.trim(),
        'description': descController.text.trim(),
        'price': double.tryParse(priceController.text.trim()) ?? 0.0,
        'location': locationController.text.trim(),
        'category': selectedCategory,
        'condition': selectedCondition,
        'imageUrl': imageUrl,
        'ownerId': userId,
        'status': 'available',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'isActive': true,
      });

      _showSuccessSnackBar('Item listed successfully!');
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error submitting item: $e');
      _showErrorSnackBar('Failed to list item. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Add New Item'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image picker section
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: _image == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo,
                              size: 50,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to add photo',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(_image!, fit: BoxFit.cover),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // Form fields
              _buildTextField(
                controller: nameController,
                label: 'Item Name',
                icon: Icons.shopping_bag,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter item name';
                  }
                  if (value.trim().length < 3) {
                    return 'Name must be at least 3 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              _buildTextField(
                controller: descController,
                label: 'Description',
                icon: Icons.description,
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter description';
                  }
                  if (value.trim().length < 10) {
                    return 'Description must be at least 10 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              _buildTextField(
                controller: priceController,
                label: 'Price (GHS)',
                icon: Icons.attach_money,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final price = double.tryParse(value);
                    if (price == null || price < 0) {
                      return 'Please enter a valid price';
                    }
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              _buildTextField(
                controller: locationController,
                label: 'Location',
                icon: Icons.location_on,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter location';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              _buildDropdown(
                value: selectedCategory,
                items: categories,
                label: 'Category',
                icon: Icons.category,
                onChanged: (value) => setState(() => selectedCategory = value),
              ),

              const SizedBox(height: 16),

              _buildDropdown(
                value: selectedCondition,
                items: conditions,
                label: 'Condition',
                icon: Icons.star,
                onChanged: (value) => setState(() => selectedCondition = value),
              ),

              const SizedBox(height: 32),

              SizedBox(
                height: 50,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: _submitItem,
                        icon: const Icon(Icons.publish),
                        label: const Text('List Item'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
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
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String label,
    required IconData icon,
    required void Function(String?) onChanged,
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
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        value: value,
        items: items.map((item) {
          return DropdownMenuItem(value: item, child: Text(item));
        }).toList(),
        onChanged: onChanged,
        validator: (value) => value == null ? 'Please select $label' : null,
      ),
    );
  }
}
