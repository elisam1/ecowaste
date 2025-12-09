import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/mobile_app/provider/provider.dart';
import 'package:provider/provider.dart';

class CollectorProfileEditPage extends StatefulWidget {
  const CollectorProfileEditPage({super.key});

  @override
  State<CollectorProfileEditPage> createState() =>
      _CollectorProfileEditPageState();
}

class _CollectorProfileEditPageState extends State<CollectorProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _townController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneNumberController = TextEditingController();

  bool _isLoading = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isChangingPassword = false;

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      final provider = Provider.of<CollectorProvider>(context, listen: false);
      await provider
          .fetchCollectorData(); // Make sure it populates `name`, `email`, `town`

      setState(() {
        _usernameController.text = provider.name ?? 'Guest';
        _emailController.text = provider.email ?? '';
        _townController.text = provider.town ?? '';
        _phoneNumberController.text = provider.phone ?? '';
      });
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _townController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _phoneNumberController.dispose();

    super.dispose();
  }

  String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Enter full name is required';
    }
    if (value.length < 4) {
      return 'Name must be at least 4 characters';
    }
    // if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
    //   return 'Username can only contain letters, numbers, and underscores';
    // }
    return null;
  }

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone Number is required';
    }
    if (value.length < 10 || value.length > 10) {
      return 'Phone Number be 10 characters';
    }
    // if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
    //   return 'Username can only contain letters, numbers, and underscores';
    // }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!value.contains('@')) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validateTown(String? value) {
    if (value == null || value.isEmpty) {
      return 'Town is required';
    }
    if (value.length < 2) {
      return 'Town name must be at least 2 characters';
    }
    return null;
  }

  String? _validateCurrentPassword(String? value) {
    if (_isChangingPassword && (value == null || value.isEmpty)) {
      return 'Current password is required';
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    if (_isChangingPassword) {
      if (value == null || value.isEmpty) {
        return 'New password is required';
      }
      if (value.length < 8) {
        return 'Password must be at least 8 characters';
      }
      // if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(value)) {
      //   return 'Password must contain uppercase, lowercase, and number';
      // }
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (_isChangingPassword) {
      if (value == null || value.isEmpty) {
        return 'Please confirm your password';
      }
      if (value != _newPasswordController.text) {
        return 'Passwords do not match';
      }
    }
    return null;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final uid = user.uid;

        //  Handle password change if enabled
        if (_isChangingPassword) {
          final cred = EmailAuthProvider.credential(
            email: user.email!,
            password: _currentPasswordController.text.trim(),
          );

          // Reauthenticate the user
          await user.reauthenticateWithCredential(cred);

          // Update the password
          await user.updatePassword(_newPasswordController.text.trim());
        }

        //  Update email if it changed
        if (_emailController.text.trim() != user.email) {
          await user.updateEmail(_emailController.text.trim());
        }

        //  Update Firestore user profile
        await FirebaseFirestore.instance
            .collection('collectors')
            .doc(uid)
            .update({
              'name': _usernameController.text.trim(),
              'town': _townController.text.trim().toLowerCase(),
              'email': _emailController.text.trim(),
              'phone': _phoneNumberController.text.trim(),
              // optionally keep this
            });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          if (_isChangingPassword) {
            _currentPasswordController.clear();
            _newPasswordController.clear();
            _confirmPasswordController.clear();
            setState(() {
              _isChangingPassword = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.green[700],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.green[100],
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.green[700],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Update Your Profile',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Profile Information Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_outline, color: Colors.green[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Personal Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Username Field
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        hintText: 'Enter your username',
                        prefixIcon: const Icon(Icons.account_circle),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.green[700]!),
                        ),
                      ),
                      validator: _validateUsername,
                    ),

                    const SizedBox(height: 16),

                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'Enter your email address',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.green[700]!),
                        ),
                      ),
                      validator: _validateEmail,
                    ),

                    const SizedBox(height: 16),

                    // Town Field
                    TextFormField(
                      controller: _townController,
                      decoration: InputDecoration(
                        labelText: 'Town',
                        hintText: 'Enter your town',
                        prefixIcon: const Icon(Icons.location_city),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.green[700]!),
                        ),
                      ),
                      validator: _validateTown,
                    ),
                    const SizedBox(height: 16),
                    // Username Field
                    TextFormField(
                      controller: _phoneNumberController,
                      decoration: InputDecoration(
                        labelText: 'phone',
                        hintText: 'Enter your phone Number',
                        prefixIcon: const Icon(Icons.account_circle),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.green[700]!),
                        ),
                      ),
                      validator: _validatePhoneNumber,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Password Change Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lock_outline, color: Colors.green[700]),
                            const SizedBox(width: 8),
                            Text(
                              'Change Password',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _isChangingPassword,
                          onChanged: (value) {
                            setState(() {
                              _isChangingPassword = value;
                              if (!value) {
                                _currentPasswordController.clear();
                                _newPasswordController.clear();
                                _confirmPasswordController.clear();
                              }
                            });
                          },
                          activeColor: Colors.green[700],
                        ),
                      ],
                    ),

                    if (_isChangingPassword) ...[
                      const SizedBox(height: 20),

                      // Current Password Field
                      TextFormField(
                        controller: _currentPasswordController,
                        obscureText: _obscureCurrentPassword,
                        decoration: InputDecoration(
                          labelText: 'Current Password',
                          hintText: 'Enter your current password',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureCurrentPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureCurrentPassword =
                                    !_obscureCurrentPassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.green[700]!),
                          ),
                        ),
                        validator: _validateCurrentPassword,
                      ),

                      const SizedBox(height: 16),

                      // New Password Field
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: _obscureNewPassword,
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          hintText: 'Enter your new password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNewPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureNewPassword = !_obscureNewPassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.green[700]!),
                          ),
                        ),
                        validator: _validateNewPassword,
                      ),

                      const SizedBox(height: 16),

                      // Confirm Password Field
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'Confirm New Password',
                          hintText: 'Confirm your new password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.green[700]!),
                          ),
                        ),
                        validator: _validateConfirmPassword,
                      ),

                      const SizedBox(height: 12),

                      // Password Requirements
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
                            Text(
                              'Password Requirements:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '• At least 8 characters long\n'
                              '• Contains uppercase and lowercase letters\n'
                              '• Contains at least one number',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Save Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // Cancel Button
              SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.of(context).pop();
                        },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[400]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
