import 'package:firebase_app_check/firebase_app_check.dart'
    show FirebaseAppCheck, AndroidProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/mobile_app/chat_page/chat_page.dart';
import 'package:flutter_application_1/mobile_app/chat_page/chatlist_page.dart';
import 'package:flutter_application_1/mobile_app/ecomarketplace/add_items.dart';
import 'package:flutter_application_1/mobile_app/ecomarketplace/buyerform.dart';
import 'package:flutter_application_1/mobile_app/ecomarketplace/homescreen.dart';
//import 'package:flutter_application_1/mobile_app/ecomarketplace/add_item_screen.dart';
import 'package:flutter_application_1/mobile_app/ecomarketplace/my_listing_page.dart';
//import 'package:flutter_application_1/mobile_app/ecomarketplace/my_listings_screen.dart';
import 'package:flutter_application_1/mobile_app/ecomarketplace/itemdetails.dart';
//import 'package:flutter_application_1/mobile_app/ecomarketplace/buyer_form_screen.dart';
import 'package:flutter_application_1/mobile_app/provider/provider.dart';
import 'package:flutter_application_1/mobile_app/provider/notification_provider.dart';
//import 'package:flutter_application_1/mobile_app/provider/sort_score_provider.dart';
import 'package:flutter_application_1/mobile_app/routes/app_route.dart';
import 'package:flutter_application_1/mobile_app/service/component/leaderboard.dart';
import 'package:flutter_application_1/mobile_app/user_screen/about_screen.dart';
import 'package:flutter_application_1/mobile_app/user_screen/edit_profile.dart';
//import 'package:flutter_application_1/user_screen/forms.dart';
import 'package:flutter_application_1/mobile_app/user_screen/log_in/sign_in_screen.dart';
import 'package:flutter_application_1/mobile_app/user_screen/pickup_history_service.dart';

import 'package:flutter_application_1/mobile_app/user_screen/waste_form.dart';
import 'package:flutter_application_1/mobile_app/waste_collector/collectorMapScreen.dart';
import 'package:flutter_application_1/mobile_app/waste_collector/collector_about.dart';
import 'package:flutter_application_1/mobile_app/waste_collector/collector_signup.dart';
import 'package:flutter_application_1/mobile_app/waste_collector/editing_page.dart';
import 'package:flutter_application_1/mobile_app/waste_collector/collector_homepage.dart';
import 'package:flutter_application_1/mobile_app/waste_collector/pickup.dart';
import 'package:flutter_application_1/mobile_app/waste_collector/profile_screen.dart';
import 'package:flutter_application_1/mobile_app/waste_collector/notification_page.dart';
import 'package:flutter_application_1/mobile_app/user_screen/notification_page.dart';
import 'package:flutter_application_1/mobile_app/user_screen/user_tracking_collector.dart';
import 'package:flutter_application_1/mobile_app/user_screen/user_request_screen.dart';
import 'package:flutter_application_1/mobile_app/service/welcome_screen.dart';
import 'package:flutter_application_1/mobile_app/user_screen/bottombar.dart';
import 'package:flutter_application_1/mobile_app/user_screen/log_in/sign_up.dart';
import 'package:flutter_application_1/mobile_app/user_screen/profile_screen.dart';
import 'package:flutter_application_1/mobile_app/service/role_selection.dart';
import 'package:flutter_application_1/mobile_app/waste_collector/scheduling_week.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Admin imports - only loaded when neededflu
// import 'package:flutter_application_1/admin/providers/admin_provider.dart';
// import 'package:flutter_application_1/admin/screens/admin_login_screen.dart';
// import 'package:flutter_application_1/admin/screens/admin_dashboard.dart';

import 'firebase_options.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Background message received
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => CollectorProvider()),
        ChangeNotifierProvider(create: (_) => SortScoreProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        // AdminProvider commented out for mobile app
        // ChangeNotifierProvider(create: (_) => AdminProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Widget _initialScreen;

  @override
  void initState() {
    super.initState();
    _setupFCM();
    final user = FirebaseAuth.instance.currentUser;
    _initialScreen = user != null ? const HomeScreen() : const WelcomeScreen();
  }

  void _setupFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      String? token = await messaging.getToken();

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (userDoc.exists) {
          // It's a normal user
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'fcmToken': token,
          });
        } else {
          // Assume it's a collector
          await FirebaseFirestore.instance
              .collection('collectors')
              .doc(uid)
              .update({'fcmToken': token});
        }
      }
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Handle foreground notifications
      // You can use flutter_local_notifications here to show custom local popup if needed
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // Handle notification tap when app is in background
      // Navigate to chat or pickup screen if needed
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Waste Classification',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: _initialScreen,
      onGenerateRoute: _generateRoute,
    );
  }

  static PageRouteBuilder _createRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;

        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  Route<dynamic>? _generateRoute(RouteSettings settings) {
    final args = settings.arguments as Map<String, dynamic>? ?? {};
    switch (settings.name) {
      case AppRoutes.welcome:
        return _createRoute(const WelcomeScreen());
      case AppRoutes.signIn:
        return _createRoute(const SignInScreen());
      case AppRoutes.signUp:
        final role = args['role'] ?? 'user';
        return _createRoute(SignUpScreen(role: role));
      case AppRoutes.collectorSignup:
        final role = args['role'] ?? 'collector';
        return _createRoute(CollectorSignup(role: role));
      case AppRoutes.roleSelection:
        return _createRoute(const RoleSelectionScreen());
      case AppRoutes.home:
        return _createRoute(const HomeScreen());
      case AppRoutes.leaderboard:
        return _createRoute(const LeaderboardScreen());
      case AppRoutes.pickuphistory:
        final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

        return _createRoute(PickupHistoryScreen(userId: userId));
      case AppRoutes.profile:
        return _createRoute(const ProfileScreen());
      case AppRoutes.wastepickupformupdated:
        final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
        return _createRoute(WastePickupFormUpdated(userId: userId));
      case AppRoutes.chatpage:
        return _createRoute(
          ChatPage(
            collectorName: args['collectorName'],
            collectorId: args['collectorId'],
            requestId: args['requestId'],
          ),
        );
      case AppRoutes.collectorHome:
        return _createRoute(const CollectorMainScreen());
      case AppRoutes.pickup:
        final collectorId = args['collectorId'] as String?;
        if (collectorId != null) {
          return _createRoute(
            PickupManagementPage(
              collectorId: collectorId,
              collectorName: '',
              collectorTown:
                  '', // This will be updated when the route is called from collector homepage
            ),
          );
        } else {
          return _createRoute(
            const Scaffold(
              body: Center(child: Text('Collector ID is missing')),
            ),
          );
        }
      case AppRoutes.collectorProfile:
        return _createRoute(const CollectorProfileScreen());
      case '/collector-notifications':
        return _createRoute(const CollectorNotificationPage());
      case '/user-notifications':
        return _createRoute(const UserNotificationPage());
      case '/user-tracking':
        return _createRoute(
          UserCollectorTrackingScreen(
            requestId: args['requestId'] ?? '',
            userId: args['userId'] ?? '',
          ),
        );
      case '/chat':
        return _createRoute(
          ChatPage(
            collectorId: args['collectorId'] ?? '',
            requestId: args['requestId'] ?? '',
            collectorName: args['collectorName'] ?? 'Collector',
            userName: args['userName'] ?? 'User',
          ),
        );
      case '/user-requests':
        return _createRoute(UserRequestsScreen(userId: args['userId'] ?? ''));
      case '/add-item':
        return _createRoute(const AddItemScreen());
      case '/my-listings':
        return _createRoute(const MyListingsScreen());
      case '/item-detail':
        return _createRoute(
          ItemDetailScreen(
            itemId: args['itemId'] ?? '',
            itemData: args['itemData'] ?? {},
          ),
        );
      case '/buyer-form':
        return _createRoute(
          BuyerFormScreen(
            itemData: args['itemData'] ?? {},
            itemId: args['itemId'] ?? '',
            sellerId: args['sellerId'] ?? '',
          ),
        );
      case AppRoutes.collectorProfileEditPage:
        return _createRoute(const CollectorProfileEditPage());
      case AppRoutes.userProfileEditPage:
        return _createRoute(const UserProfileEditPage());
      case AppRoutes.aboutus:
        return _createRoute(const AboutPage());
      case AppRoutes.markethomescreen:
        return _createRoute(const MarketHomeScreen());
      case AppRoutes.weeklyScheduling:
        final collectorId = args['collectorId'] as String?;
        if (collectorId != null) {
          // Create WeeklySchedulingPage with default suggested towns
          return _createRoute(WeeklySchedulingPage(
            collectorId: collectorId,
            // The suggestedTowns will use the default value from the constructor
          ));
        } else {
          return _createRoute(
            const Scaffold(
              body: Center(child: Text('Collector ID is missing')),
            ),
          );
        }
      case AppRoutes.chatlistpage:
        return _createRoute(const ChatListPage());
      case AppRoutes.collectorabout:
        return _createRoute(const CollectorAboutPage());
      // case AppRoutes.classifywaste:
      //   return _createRoute(const Classifywaste());
      case AppRoutes.collectormapscreen:
        final collectorId = args['collectorId'];
        return _createRoute(CollectorMapScreen(collectorId: collectorId));
      // Admin routes commented out for mobile app
      // case AppRoutes.adminLogin:
      //   return _createRoute(const AdminLoginScreen());
      // case AppRoutes.adminDashboard:
      //   return _createRoute(const AdminDashboard());
      default:
        return _createRoute(
          Scaffold(
            appBar: AppBar(title: const Text('404')),
            body: const Center(child: Text('Page not found')),
          ),
        );
    }
  }
}
