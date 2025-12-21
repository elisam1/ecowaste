import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/mobile_app/service/welcome_screen.dart';
import 'package:flutter_application_1/mobile_app/user_screen/bottombar.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _logoController;
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _particleController;
  late AnimationController _textController;
  late AnimationController _progressController;
  late AnimationController _fadeOutController;

  // Animations
  late Animation<double> _logoScale;
  late Animation<double> _logoRotation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _progressAnimation;
  late Animation<double> _fadeOutAnimation;

  // Particles
  final List<Particle> _particles = [];
  final int _particleCount = 50;

  // State
  bool _showTagline = false;
  bool _showProgress = false;
  String _loadingText = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _generateParticles();
    _startAnimationSequence();

    // Set status bar style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  void _initializeAnimations() {
    // Logo animation controller - faster
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _logoScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.2,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.2,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
    ]).animate(_logoController);

    _logoRotation = Tween<double>(begin: -0.3, end: 0.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );

    // Pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Wave animation
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(parent: _waveController, curve: Curves.linear));

    // Particle animation
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 8000),
      vsync: this,
    )..repeat();

    // Text animation - faster
    _textController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeInOut),
    );

    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
        );

    // Progress animation - faster
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    // Fade out animation - faster
    _fadeOutController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeOutAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeOutController, curve: Curves.easeInOut),
    );
  }

  void _generateParticles() {
    final random = math.Random();
    for (int i = 0; i < _particleCount; i++) {
      _particles.add(
        Particle(
          x: random.nextDouble(),
          y: random.nextDouble(),
          size: random.nextDouble() * 6 + 2,
          speed: random.nextDouble() * 0.5 + 0.2,
          opacity: random.nextDouble() * 0.6 + 0.2,
          angle: random.nextDouble() * 2 * math.pi,
        ),
      );
    }
  }

  void _startAnimationSequence() async {
    // Start logo animation
    _logoController.forward();

    // Start pulse after logo appears
    await Future.delayed(const Duration(milliseconds: 800));
    _pulseController.repeat(reverse: true);

    // Show tagline
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() {
      _showTagline = true;
    });
    _textController.forward();

    // Show progress
    await Future.delayed(const Duration(milliseconds: 400));
    setState(() {
      _showProgress = true;
      _loadingText = 'Loading...';
    });
    _progressController.forward();

    // Update loading text
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() {
        _loadingText = 'Almost ready...';
      });
    }

    // Wait for progress to complete
    await Future.delayed(const Duration(milliseconds: 400));

    // Fade out and navigate
    await _fadeOutController.forward();

    if (mounted) {
      _navigateToNextScreen();
    }
  }

  void _navigateToNextScreen() {
    final user = FirebaseAuth.instance.currentUser;
    final nextScreen = user != null
        ? const HomeScreen()
        : const WelcomeScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    _particleController.dispose();
    _textController.dispose();
    _progressController.dispose();
    _fadeOutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeOutAnimation,
        child: Container(
          width: size.width,
          height: size.height,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0D3B2E),
                Color(0xFF1A5D4A),
                Color(0xFF2E7D5F),
                Color(0xFF1A5D4A),
                Color(0xFF0D3B2E),
              ],
              stops: [0.0, 0.25, 0.5, 0.75, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // Animated wave background
              _buildWaveBackground(size),

              // Floating particles
              _buildParticles(size),

              // Glowing circles
              _buildGlowingCircles(size),

              // Main content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),

                    // Animated logo
                    _buildAnimatedLogo(),

                    const SizedBox(height: 40),

                    // App name
                    _buildAppName(),

                    const SizedBox(height: 16),

                    // Tagline
                    if (_showTagline) _buildTagline(),

                    const Spacer(flex: 2),

                    // Loading progress
                    if (_showProgress) _buildLoadingProgress(),

                    const SizedBox(height: 60),
                  ],
                ),
              ),

              // Shine effect overlay
              _buildShineEffect(size),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaveBackground(Size size) {
    return AnimatedBuilder(
      animation: _waveAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: size,
          painter: WavePainter(
            waveAnimation: _waveAnimation.value,
            color: Colors.white.withValues(alpha: 0.05),
          ),
        );
      },
    );
  }

  Widget _buildParticles(Size size) {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, child) {
        return CustomPaint(
          size: size,
          painter: ParticlePainter(
            particles: _particles,
            animation: _particleController.value,
          ),
        );
      },
    );
  }

  Widget _buildGlowingCircles(Size size) {
    return Stack(
      children: [
        // Top left glow
        Positioned(
          top: -size.height * 0.15,
          left: -size.width * 0.2,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: size.width * 0.6,
                  height: size.width * 0.6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF4CAF50).withValues(alpha: 0.3),
                        const Color(0xFF4CAF50).withValues(alpha: 0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Bottom right glow
        Positioned(
          bottom: -size.height * 0.1,
          right: -size.width * 0.15,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: 2.0 - _pulseAnimation.value,
                child: Container(
                  width: size.width * 0.5,
                  height: size.width * 0.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF81C784).withValues(alpha: 0.25),
                        const Color(0xFF81C784).withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: Listenable.merge([_logoController, _pulseController]),
      builder: (context, child) {
        return Transform.scale(
          scale:
              _logoScale.value *
              (_pulseController.isAnimating ? _pulseAnimation.value : 1.0),
          child: Transform.rotate(
            angle: _logoRotation.value,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF66BB6A),
                    Color(0xFF43A047),
                    Color(0xFF2E7D32),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.5),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                  BoxShadow(
                    color: const Color(0xFF81C784).withValues(alpha: 0.3),
                    blurRadius: 60,
                    spreadRadius: 20,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Inner glow
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                  ),
                  // Icon
                  const Icon(Icons.recycling, size: 70, color: Colors.white),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppName() {
    return ScaleTransition(
      scale: _logoScale,
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [Colors.white, Color(0xFFE0E0E0), Colors.white],
        ).createShader(bounds),
        child: const Text(
          'EcoWaste',
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 3,
            shadows: [
              Shadow(
                color: Colors.black26,
                offset: Offset(2, 2),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagline() {
    return FadeTransition(
      opacity: _textFade,
      child: SlideTransition(
        position: _textSlide,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Text(
                'Smart Waste Management',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Making Ghana Cleaner, One Pickup at a Time',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingProgress() {
    return FadeTransition(
      opacity: _textFade,
      child: Column(
        children: [
          SizedBox(
            width: 200,
            child: AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _progressAnimation.value,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF81C784),
                        ),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _loadingText,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShineEffect(Size size) {
    return AnimatedBuilder(
      animation: _waveAnimation,
      builder: (context, child) {
        final shinePosition = (_waveAnimation.value / (2 * math.pi)) * 2 - 0.5;
        return Positioned(
          left: size.width * shinePosition,
          top: 0,
          child: Container(
            width: size.width * 0.3,
            height: size.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.03),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Particle class
class Particle {
  double x;
  double y;
  final double size;
  final double speed;
  final double opacity;
  final double angle;

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.angle,
  });
}

// Particle painter
class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double animation;

  ParticlePainter({required this.particles, required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: particle.opacity * 0.6)
        ..style = PaintingStyle.fill;

      // Calculate position based on animation
      final progress = (animation + particle.speed) % 1.0;
      final x =
          particle.x * size.width +
          math.sin(progress * 2 * math.pi + particle.angle) * 20;
      final y =
          ((particle.y + progress * particle.speed * 2) % 1.0) * size.height;

      canvas.drawCircle(Offset(x, y), particle.size, paint);

      // Draw glow
      final glowPaint = Paint()
        ..color = const Color(
          0xFF81C784,
        ).withValues(alpha: particle.opacity * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(x, y), particle.size * 1.5, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Wave painter
class WavePainter extends CustomPainter {
  final double waveAnimation;
  final Color color;

  WavePainter({required this.waveAnimation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw multiple waves
    for (int i = 0; i < 3; i++) {
      final path = Path();
      final waveHeight = 30.0 + i * 15;
      final offset = waveAnimation + i * 0.5;

      path.moveTo(0, size.height);

      for (double x = 0; x <= size.width; x += 1) {
        final y =
            size.height * 0.7 +
            math.sin((x / size.width * 4 * math.pi) + offset) * waveHeight +
            math.cos((x / size.width * 2 * math.pi) + offset * 1.5) *
                waveHeight *
                0.5;
        path.lineTo(x, y);
      }

      path.lineTo(size.width, size.height);
      path.close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
