import 'package:logger/logger.dart';

/// Centralized logging service for consistent logging across the app
class LoggingService {
  static final _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
    ),
  );

  /// Log debug information
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Log info messages
  static void info(String message) {
    _logger.i(message);
  }

  /// Log warning messages
  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// Log error messages
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Log error with full context
  static void errorWithContext(
    String context,
    String message, {
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _logger.e('[$context] $message', error: error, stackTrace: stackTrace);
  }

  /// Log success messages
  static void success(String message) {
    _logger.i('✅ $message');
  }

  /// Log feature/action tracking
  static void trackAction(String action, [Map<String, dynamic>? data]) {
    final message = data != null
        ? '📊 Action: $action | Data: ${data.toString()}'
        : '📊 Action: $action';
    _logger.i(message);
  }

  /// Log Firebase operations
  static void logFirebaseOperation(
    String operation,
    String collection, {
    String? documentId,
    dynamic data,
  }) {
    final doc = documentId ?? 'N/A';
    final message = '🔥 [$operation] Collection: $collection | Doc: $doc';
    _logger.i(message);
    if (data != null) {
      _logger.d('Payload: $data');
    }
  }

  /// Log API calls
  static void logApiCall(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) {
    _logger.i('🌐 $method $endpoint');
    if (body != null) {
      _logger.d('Body: $body');
    }
    if (headers != null) {
      _logger.d('Headers: $headers');
    }
  }

  /// Log API response
  static void logApiResponse(
    int statusCode,
    String endpoint, {
    dynamic response,
  }) {
    final emoji = statusCode >= 200 && statusCode < 300 ? '✅' : '❌';
    _logger.i('$emoji [$statusCode] $endpoint');
    if (response != null) {
      _logger.d('Response: $response');
    }
  }

  /// Log authentication events
  static void logAuthEvent(String event, [String? userId]) {
    final user = userId ?? 'Unknown';
    _logger.i('🔐 Auth: $event | User: $user');
  }

  /// Log location updates
  static void logLocation(String context, double latitude, double longitude,
      [double? accuracy]) {
    final acc = accuracy != null ? ' | Accuracy: ${accuracy.toStringAsFixed(2)}m' : '';
    _logger.i(
        '📍 [$context] Lat: ${latitude.toStringAsFixed(6)}, Lon: ${longitude.toStringAsFixed(6)}$acc');
  }

  /// Log image operations
  static void logImageOperation(
    String operation, {
    String? filename,
    int? sizeMB,
    int? width,
    int? height,
  }) {
    String details = '';
    if (filename != null) details += ' | File: $filename';
    if (sizeMB != null) details += ' | Size: ${sizeMB}MB';
    if (width != null && height != null) details += ' | Dims: ${width}x$height';
    _logger.i('🖼️ Image $operation$details');
  }

  /// Log performance metrics
  static void logPerformance(String operation, Duration duration) {
    final ms = duration.inMilliseconds;
    final emoji = ms < 100 ? '⚡' : ms < 500 ? '⏱️' : '🐢';
    _logger.i('$emoji Performance: $operation took ${ms}ms');
  }

  /// Log cache operations
  static void logCacheOperation(
    String operation,
    String key, {
    bool hit = false,
  }) {
    final status = hit ? 'HIT' : 'MISS';
    _logger.i('💾 Cache [$status] $operation | Key: $key');
  }

  /// Log notification
  static void logNotification(String type, String title, [String? body]) {
    final msg = body != null ? '$title - $body' : title;
    _logger.i('🔔 Notification [$type]: $msg');
  }

  /// Log payment operation
  static void logPaymentOperation(
    String operation, {
    double? amount,
    String? transactionId,
    String? status,
  }) {
    String details = '';
    if (amount != null) details += ' | Amount: \$$amount';
    if (transactionId != null) details += ' | TxID: $transactionId';
    if (status != null) details += ' | Status: $status';
    _logger.i('💳 Payment: $operation$details');
  }

  /// Log form submission
  static void logFormSubmission(String formName, [Map<String, dynamic>? fields]) {
    _logger.i('📝 Form Submitted: $formName');
    if (fields != null) {
      // Don't log sensitive fields
      final safe = Map.from(fields);
      safe.remove('password');
      safe.remove('fcmToken');
      _logger.d('Fields: $safe');
    }
  }

  /// Log database query
  static void logDatabaseQuery(
    String collection, {
    Map<String, dynamic>? filters,
    int? resultCount,
  }) {
    String query = 'collection("$collection")';
    if (filters != null && filters.isNotEmpty) {
      query += ' where ${filters.entries.map((e) => '${e.key}=${e.value}').join(', ')}';
    }
    if (resultCount != null) {
      query += ' | Results: $resultCount';
    }
    _logger.i('📚 $query');
  }
}
