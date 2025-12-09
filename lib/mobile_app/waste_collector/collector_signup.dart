import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/mobile_app/routes/app_route.dart';
// import 'package:geolocator/geolocator.dart';

class CollectorSignup extends StatefulWidget {
  final String role;
  const CollectorSignup({super.key, required this.role});

  @override
  State<CollectorSignup> createState() => _CollectorSignup();
}

class _CollectorSignup extends State<CollectorSignup>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final phoneController = TextEditingController();
  //final townController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  //Position? _currentPosition;
  //String _locationStatus = 'Location not set';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    //townController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32), Color(0xFF1B5E20)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  _buildHeader(),
                  const SizedBox(height: 30),
                  _buildSignUpForm(),
                  const SizedBox(height: 30),
                  _buildSignInLink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 15,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_shipping,
                size: 50,
                color: Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Join as Collector',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    offset: Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Help make the world cleaner',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpForm() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Create Collector Account',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Start your collection journey',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              _buildNameField(),
              const SizedBox(height: 20),
              _buildEmailField(),
              const SizedBox(height: 20),
              _buildPasswordField(),
              const SizedBox(height: 20),
              // _buildTownField(),
              // const SizedBox(height: 20),
              _buildPhoneField(),
              // const SizedBox(height: 20),
              // _buildLocationButton(),
              const SizedBox(height: 30),
              _buildSignUpButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: nameController,
      decoration: _buildInputDecoration('Full Name', Icons.person_outline),
      validator: (value) => value == null || value.trim().isEmpty
          ? 'Please enter your full name'
          : null,
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: _buildInputDecoration('Email', Icons.email_outlined),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        }
        if (!value.contains('@')) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF4CAF50)),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey[600],
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: (value) => value == null || value.length < 6
          ? 'Password must be at least 6 characters'
          : null,
    );
  }

  // Widget _buildTownField() {
  //   return TextFormField(
  //     controller: townController,
  //     decoration: _buildInputDecoration('Town', Icons.location_city_outlined),
  //     validator: (value) =>
  //         value == null || value.trim().isEmpty ? 'Please enter town' : null,
  //   );
  // }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: phoneController,
      keyboardType: TextInputType.phone,
      decoration: _buildInputDecoration('Phone Number', Icons.phone_outlined),
      validator: (value) => value == null || value.trim().isEmpty
          ? 'Please enter your phone number'
          : null,
    );
  }

  Widget _buildSignUpButton() {
    return Container(
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSignUp,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                'Create Collector Account',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Widget _buildSignInLink() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Already have an account? ",
            style: TextStyle(color: Colors.white70),
          ),
          TextButton(
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.signIn);
            },
            child: const Text(
              'Sign In',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String labelText, IconData icon) {
    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(icon, color: const Color(0xFF4CAF50)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
      ),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }

  void _handleSignUp() async {
    if (_formKey.currentState!.validate()) {
      // if (_currentPosition == null) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(
      //       content: Text("Please set your location"),
      //       backgroundColor: Colors.red,
      //     ),
      //   );
      //   return;
      // }

      setState(() => _isLoading = true);

      try {
        final userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: emailController.text.trim(),
              password: passwordController.text.trim(),
            );

        final uid = userCredential.user!.uid;

        await FirebaseFirestore.instance.collection('collectors').doc(uid).set({
          'name': nameController.text.trim(),
          'email': emailController.text.trim(),
          'role': widget.role,
          'phone': phoneController.text.trim(),
          // 'town': townController.text.trim().toLowerCase(),
          'isActive': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        setState(() => _isLoading = false);

        Navigator.pushNamed(
          context,
          AppRoutes.collectorHome,
          arguments: {'role': 'collector'},
        );
      } on FirebaseAuthException catch (e) {
        setState(() => _isLoading = false);
        String errorMsg = 'An error occurred';
        if (e.code == 'email-already-in-use') {
          errorMsg = 'This email is already in use.';
        } else if (e.code == 'weak-password') {
          errorMsg = 'Password should be at least 6 characters.';
        } else {
          errorMsg = e.message ?? errorMsg;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    }
  }
}
