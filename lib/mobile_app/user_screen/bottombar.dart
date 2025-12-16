import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/mobile_app/constants/app_colors.dart';
//import 'package:flutter_application_1/mobile_app/ecomarketplace/homescreen.dart';

import 'package:flutter_application_1/mobile_app/user_screen/home_redesign.dart';
import 'package:flutter_application_1/mobile_app/user_screen/profile_screen.dart';

import 'package:flutter_application_1/mobile_app/user_screen/user_request_screen.dart';
import 'package:logger/logger.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int myIndex = 1;
  final log = Logger();
  @override
  Widget build(BuildContext context) {
    //final rank = context.watch<SortScoreProvider>().rank;

    final List<Widget> screens = [
      UserRequestsScreen(userId: FirebaseAuth.instance.currentUser?.uid ?? ''),
      const RedesignedHomePage(),
      const ProfileScreen(),
    ];
    return Scaffold(
      backgroundColor: AppColors.background,

      body: screens[myIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          selectedItemColor: AppColors.indigo,
          unselectedItemColor: AppColors.textSecondary,
          currentIndex: myIndex,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.indigo.withValues(alpha: 0.9),
          ),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary.withValues(alpha: 0.9),
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_outlined),
              activeIcon: Icon(Icons.list_alt),
              label: 'Pickup',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
          onTap: (index) {
            setState(() {
              myIndex = index;
            });
          },
        ),
      ),
    );
  }
}
