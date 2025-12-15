import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Connectivity _connectivity;

  StreamSubscription? _connectivitySubscription;

  Future<void> initialize() async {
    _connectivity = Connectivity();
    // Set up global error handling
    FlutterError.onError = _handleFlutterError;

    // Set up connectivity monitoring
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChange,
    );

    // Handle platform errors (Android/iOS)
    PlatformDispatcher.instance.onError = (error, stack) {
      _handlePlatformError(error, stack);
      return true;
    };
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  void _handleFlutterError(FlutterErrorDetails details) {
    _logError(
      error: details.exception,
      stackTrace: details.stack,
      context: details.context?.toString(),
      errorType: 'Flutter Error',
      additionalData: {'library': details.library, 'silent': details.silent},
    );
  }

  bool _handlePlatformError(Object error, StackTrace stack) {
    _logError(error: error, stackTrace: stack, errorType: 'Platform Error');
    return true;
  }

  Future<void> handleError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
    String? userId,
    Map<String, dynamic>? additionalData,
  }) async {
    await _logError(
      error: error,
      stackTrace: stackTrace,
      context: context,
      userId: userId,
      additionalData: additionalData,
    );
  }

  Future<void> _logError({
    required dynamic error,
    StackTrace? stackTrace,
    String? context,
    String? userId,
    String? errorType = 'Application Error',
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final deviceInfo = await _getDeviceInfo();
      final packageInfo = await _getPackageInfo();
      final connectivity = await _connectivity.checkConnectivity();

      final errorData = {
        'error': error.toString(),
        'stackTrace': stackTrace?.toString(),
        'context': context,
        'errorType': errorType,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': userId ?? FirebaseAuth.instance.currentUser?.uid,
        'deviceInfo': deviceInfo,
        'packageInfo': packageInfo,
        'connectivity': connectivity.name,
        'platform': Platform.operatingSystem,
        'additionalData': additionalData,
      };

      // Log to Firestore
      await _firestore.collection('error_logs').add(errorData);

      // In debug mode, also print to console
      if (kDebugMode) {
        debugPrint('🚨 ERROR: $error');
        if (stackTrace != null) {
          debugPrint('Stack trace: $stackTrace');
        }
        if (context != null) {
          debugPrint('Context: $context');
        }
      }
    } catch (loggingError) {
      // If logging fails, at least print to console
      debugPrint('Failed to log error: $loggingError');
      debugPrint('Original error: $error');
    }
  }

  Future<Map<String, dynamic>> _getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final info = await deviceInfo.deviceInfo;

      if (Platform.isAndroid) {
        final androidInfo = info as AndroidDeviceInfo;
        return {
          'platform': 'Android',
          'model': androidInfo.model,
          'manufacturer': androidInfo.manufacturer,
          'version': androidInfo.version.release,
          'sdkVersion': androidInfo.version.sdkInt,
          'brand': androidInfo.brand,
        };
      } else if (Platform.isIOS) {
        final iosInfo = info as IosDeviceInfo;
        return {
          'platform': 'iOS',
          'model': iosInfo.model,
          'systemVersion': iosInfo.systemVersion,
          'name': iosInfo.name,
        };
      }

      return {'platform': Platform.operatingSystem};
    } catch (e) {
      return {'error': 'Failed to get device info: $e'};
    }
  }

  Future<Map<String, dynamic>> _getPackageInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return {
        'appName': packageInfo.appName,
        'packageName': packageInfo.packageName,
        'version': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
      };
    } catch (e) {
      return {'error': 'Failed to get package info: $e'};
    }
  }

  void _handleConnectivityChange(dynamic result) {
    final connectivityStatus = result.toString();

    // Log connectivity changes
    _logError(
      error: 'Connectivity changed: $connectivityStatus',
      errorType: 'Connectivity Change',
      additionalData: {'newStatus': connectivityStatus},
    );

    // You could implement offline queue processing here
    if (result == ConnectivityResult.none) {
      // Handle offline state
      debugPrint('Device went offline');
    } else {
      // Handle back online
      debugPrint('Device back online: $connectivityStatus');
    }
  }

  // User-friendly error messages
  String getUserFriendlyErrorMessage(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'You don\'t have permission to perform this action.';
        case 'not-found':
          return 'The requested item was not found.';
        case 'already-exists':
          return 'This item already exists.';
        case 'failed-precondition':
          return 'Operation failed. Please try again.';
        case 'unavailable':
          return 'Service temporarily unavailable. Please check your connection.';
        default:
          return 'A database error occurred. Please try again.';
      }
    }

    if (error is SocketException) {
      return 'No internet connection. Please check your network.';
    }

    if (error.toString().contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    // Generic fallback
    return 'Something went wrong. Please try again.';
  }

  // Error recovery suggestions
  List<String> getErrorRecoverySuggestions(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return [
            'Try logging out and logging back in',
            'Contact support if the problem persists',
          ];
        case 'unavailable':
          return [
            'Check your internet connection',
            'Try again in a few minutes',
            'Restart the app',
          ];
        case 'failed-precondition':
          return [
            'Make sure all required information is provided',
            'Try refreshing the page',
          ];
        default:
          return [
            'Try again',
            'Restart the app',
            'Contact support if the problem continues',
          ];
      }
    }

    if (error is SocketException) {
      return [
        'Check your Wi-Fi or mobile data connection',
        'Try switching between Wi-Fi and mobile data',
        'Contact your network provider if issues persist',
      ];
    }

    return [
      'Try again',
      'Check your internet connection',
      'Restart the app',
      'Contact support if the problem continues',
    ];
  }

  // Performance monitoring
  Future<void> logPerformanceMetric(
    String metricName,
    Duration duration, {
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      await _firestore.collection('performance_logs').add({
        'metricName': metricName,
        'durationMs': duration.inMilliseconds,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'additionalData': additionalData,
      });
    } catch (e) {
      debugPrint('Failed to log performance metric: $e');
    }
  }

  // User action tracking
  Future<void> logUserAction(
    String action,
    String screen, {
    Map<String, dynamic>? parameters,
  }) async {
    try {
      await _firestore.collection('user_actions').add({
        'action': action,
        'screen': screen,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'parameters': parameters,
      });
    } catch (e) {
      debugPrint('Failed to log user action: $e');
    }
  }

  // App health monitoring
  Future<Map<String, dynamic>> getAppHealthMetrics() async {
    try {
      final now = DateTime.now();
      final last24Hours = now.subtract(const Duration(hours: 24));

      // Get error count
      final errorQuery = await _firestore
          .collection('error_logs')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(last24Hours))
          .count()
          .get();

      // Get user action count
      final actionQuery = await _firestore
          .collection('user_actions')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(last24Hours))
          .count()
          .get();

      // Get active users (rough estimate)
      final userQuery = await _firestore
          .collection('user_actions')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(last24Hours))
          .get();

      final uniqueUsers = userQuery.docs
          .map((doc) => doc.data()['userId'])
          .where((id) => id != null)
          .toSet()
          .length;

      return {
        'errorCount': errorQuery.count,
        'userActionCount': actionQuery.count,
        'activeUsers': uniqueUsers,
        'period': 'last 24 hours',
      };
    } catch (e) {
      debugPrint('Failed to get health metrics: $e');
      return {'error': 'Failed to retrieve metrics'};
    }
  }
}

// Extension for easy error handling
extension ErrorHandlerExtension on BuildContext {
  Future<void> handleError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
  }) async {
    await ErrorHandler().handleError(
      error,
      stackTrace: stackTrace,
      context: context,
      userId: FirebaseAuth.instance.currentUser?.uid,
    );

    // Show user-friendly error message
    final errorMessage = ErrorHandler().getUserFriendlyErrorMessage(error);
    final suggestions = ErrorHandler().getErrorRecoverySuggestions(error);

    if (mounted) {
      showDialog(
        context: this,
        builder: (context) => AlertDialog(
          title: const Text('Oops! Something went wrong'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(errorMessage),
              const SizedBox(height: 16),
              const Text(
                'Try these solutions:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...suggestions.map(
                (suggestion) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Text('• ', style: TextStyle(color: Colors.green)),
                      Expanded(child: Text(suggestion)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}

// Performance monitoring wrapper
class PerformanceMonitor {
  static Future<T> measure<T>(
    String operationName,
    Future<T> Function() operation, {
    Map<String, dynamic>? additionalData,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await operation();
      stopwatch.stop();

      await ErrorHandler().logPerformanceMetric(
        operationName,
        stopwatch.elapsed,
        additionalData: additionalData,
      );

      return result;
    } catch (e) {
      stopwatch.stop();
      await ErrorHandler().logPerformanceMetric(
        '$operationName (failed)',
        stopwatch.elapsed,
        additionalData: {...?additionalData, 'error': e.toString()},
      );
      rethrow;
    }
  }
}
