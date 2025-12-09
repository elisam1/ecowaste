import 'package:flutter/material.dart';
import 'package:flutter_application_1/mobile_app/routes/app_route.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole = 'collector';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF004D40), // Deep teal green
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 80),

              // Recycling Logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.green[400],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.recycling,
                  size: 60,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 30),

              // App Title
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                      children: [
                        TextSpan(
                          text: 'y',
                          style: TextStyle(color: Colors.white),
                        ),
                        TextSpan(
                          text: '♻',
                          style: TextStyle(
                            color: Color(0xFF4CAF50),
                            fontSize: 40,
                          ),
                        ),
                        TextSpan(
                          text: 'ucan',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Subtitle
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Waste Collector ",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange[600],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "Beta",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              // Circular text around logo area
              const SizedBox(height: 20),
              Transform.rotate(
                angle: 0.3,
                child: const Text(
                  "MAKE THINGS BETTER",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 3,
                  ),
                ),
              ),

              const SizedBox(height: 80),

              // Role Selection with custom design
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedRole = 'collector');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _selectedRole == 'collector'
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _selectedRole == 'collector'
                                      ? const Color(0xFF004D40)
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: _selectedRole == 'collector'
                                        ? const Color(0xFF004D40)
                                        : Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: _selectedRole == 'collector'
                                    ? const Icon(
                                        Icons.check,
                                        size: 12,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Collector",
                                style: TextStyle(
                                  color: _selectedRole == 'collector'
                                      ? const Color(0xFF004D40)
                                      : Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedRole = 'User');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _selectedRole == 'User'
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _selectedRole == 'User'
                                      ? const Color(0xFF004D40)
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: _selectedRole == 'User'
                                        ? const Color(0xFF004D40)
                                        : Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: _selectedRole == 'User'
                                    ? const Icon(
                                        Icons.check,
                                        size: 12,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "User",
                                style: TextStyle(
                                  color: _selectedRole == 'User'
                                      ? const Color(0xFF004D40)
                                      : Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 50),

              // Continue Button
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: () {
                    if (_selectedRole == 'collector') {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.collectorSignup,
                        arguments: {'role': _selectedRole},
                      );
                    } else {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.signUp,
                        arguments: {'role': _selectedRole},
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Continue",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 50),

              // Admin Access Button - Commented out for mobile app
              // SizedBox(
              //   width: 200,
              //   child: OutlinedButton(
              //     onPressed: () {
              //       Navigator.pushNamed(context, AppRoutes.adminLogin);
              //     },
              //     style: OutlinedButton.styleFrom(
              //       foregroundColor: Colors.white70,
              //       side: const BorderSide(color: Colors.white70, width: 1),
              //       padding: const EdgeInsets.symmetric(vertical: 12),
              //       shape: RoundedRectangleBorder(
              //       borderRadius: BorderRadius.circular(30),
              //     ),
              //   ),
              //   child: const Row(
              //     mainAxisAlignment: MainAxisAlignment.center,
              //     children: [
              //       Icon(Icons.admin_panel_settings, size: 18),
              //       SizedBox(width: 8),
              //       Text(
              //         "Admin Access",
              //         style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              //       ),
              //     ],
              //   ),
              // ),
              const SizedBox(height: 50),

              // Language Section
              const Text(
                "🌐 Language",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),

              const Spacer(),

              // Terms and Conditions
              Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: Text(
                  "By continuing you agree to our\nTerms of Service & Privacy Policy.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                    height: 1.5,
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
