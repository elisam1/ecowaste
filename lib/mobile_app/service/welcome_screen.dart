import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/mobile_app/routes/app_route.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _rotateController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
        );

    _rotateAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
    );

    // Start animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _slideController.forward();
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      _rotateController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1A1A1A),
                    const Color(0xFF2D4A3D),
                    const Color(0xFF004D40),
                  ]
                : [
                    const Color(0xFF004D40),
                    const Color(0xFF00695C),
                    const Color(0xFF00796B),
                  ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Floating background elements
              _buildFloatingElements(),

              // Main content
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated recycling icon
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: RotationTransition(
                            turns: _rotateAnimation,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(60),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.recycling,
                                size: 70,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Title with slide animation
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Colors.white, Colors.white70],
                            ).createShader(bounds),
                            child: const Text(
                              'Waste Classifier &\nEnvironmental Guide',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.3,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Subtitle with fade animation
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: const Text(
                            'Helping you recycle smarter and cleaner.\nIdentify waste and learn its impact.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 50),

                      // Features row
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // _buildFeatureItem(
                            //   icon: Icons.camera_alt,
                            //   label: 'Scan',
                            // ),
                            // _buildFeatureItem(
                            //   icon: Icons.insights,
                            //   label: 'Analyze',
                            // ),
                            _buildFeatureItem(
                              icon: Icons.eco,
                              label: 'Recycle',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 50),

                      // Get Started button with hover effect
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          width: double.infinity,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4CAF50).withOpacity(0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.roleSelection,
                                );
                              },
                              child: const Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Get Started',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Admin Access Button - Commented out for mobile app
                      // FadeTransition(
                      //   opacity: _fadeAnimation,
                      //   child: Container(
                      //     width: double.infinity,
                      //     height: 50,
                      //     decoration: BoxDecoration(
                      //       borderRadius: BorderRadius.circular(16),
                      //       border: Border.all(
                      //         color: Colors.white.withOpacity(0.3),
                      //         width: 1.5,
                      //       ),
                      //       color: Colors.transparent,
                      //     ),
                      //     child: Material(
                      //       color: Colors.transparent,
                      //       child: InkWell(
                      //         borderRadius: BorderRadius.circular(16),
                      //         onTap: () {
                      //           HapticFeedback.lightImpact();
                      //           Navigator.pushNamed(
                      //             context,
                      //             AppRoutes.adminLogin,
                      //           );
                      //         },
                      //         child: const Center(
                      //           child: Row(
                      //             mainAxisAlignment: MainAxisAlignment.center,
                      //             children: [
                      //               Icon(
                      //               Icons.admin_panel_settings,
                      //               color: Colors.white70,
                      //               size: 20,
                      //             ),
                      //             SizedBox(width: 8),
                      //             Text(
                      //               'Admin Access',
                      //               style: TextStyle(
                      //               fontSize: 16,
                      //               fontWeight: FontWeight.w500,
                      //               color: Colors.white70,
                      //               letterSpacing: 0.3,
                      //             ),
                      //           ),
                      //         ),
                      //       ),
                      //     ),
                      //   ),
                      // ),
                      const SizedBox(height: 30),

                      // Bottom info
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Text(
                          'Join thousands making a difference',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.6),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem({required IconData icon, required String label}) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingElements() {
    return Stack(
      children: [
        // Floating circles
        Positioned(
          top: 100,
          right: 30,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(40),
              ),
            ),
          ),
        ),
        Positioned(
          top: 200,
          left: 20,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 150,
          right: 50,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
        // More floating elements for visual interest
        Positioned(
          top: 300,
          right: 100,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Icon(
              Icons.eco,
              color: Colors.white.withOpacity(0.1),
              size: 30,
            ),
          ),
        ),
        Positioned(
          bottom: 250,
          left: 40,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Icon(
              Icons.recycling,
              color: Colors.white.withOpacity(0.08),
              size: 25,
            ),
          ),
        ),
      ],
    );
  }
}
