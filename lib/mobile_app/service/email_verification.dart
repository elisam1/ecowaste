import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/mobile_app/routes/app_route.dart'; // Update if needed

class VerifyEmailScreen extends StatefulWidget {
  final String role;

  const VerifyEmailScreen({super.key, required this.role});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool isEmailVerified = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();

    // Initial check
    isEmailVerified = FirebaseAuth.instance.currentUser!.emailVerified;

    if (!isEmailVerified) {
      sendVerificationEmail();

      // Start periodic check
      timer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => checkEmailVerified(),
      );
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> sendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      await user.sendEmailVerification();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Verification email sent')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to send email')));
    }
  }

  Future<void> checkEmailVerified() async {
    await FirebaseAuth.instance.currentUser?.reload();
    final user = FirebaseAuth.instance.currentUser;

    if (user != null && user.emailVerified) {
      setState(() {
        isEmailVerified = true;
      });

      timer?.cancel();

      // Redirect based on role
      if (widget.role == 'collector') {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.collectorHome,
          arguments: {'role': 'collector'},
        );
      } else {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.home,
          arguments: {'role': 'User'},
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Verify Email')),
    body: Padding(
      padding: const EdgeInsets.all(20.0),
      child: Center(
        child: isEmailVerified
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'A verification email has been sent to your email.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: sendVerificationEmail,
                    child: const Text('Resend Email'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      Navigator.pop(context);
                    },
                    child: const Text('Cancel & Logout'),
                  ),
                ],
              ),
      ),
    ),
  );
}
