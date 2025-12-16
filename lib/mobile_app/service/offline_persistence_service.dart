import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:logger/logger.dart';

/// Service to manage offline persistence and local caching
class OfflinePersistenceService {
  static final OfflinePersistenceService _instance =
      OfflinePersistenceService._internal();
  static final _logger = Logger();
  late SharedPreferences _prefs;

  // Cache keys
  static const String _userDataKey = 'cached_user_data';
  static const String _pickupRequestsKey = 'cached_pickup_requests';
  static const String _marketplaceItemsKey = 'cached_marketplace_items';
  static const String _collectorsKey = 'cached_collectors';
  static const String _notificationsKey = 'cached_notifications';
  static const String _timestampKey = 'cache_timestamp_';

  factory OfflinePersistenceService() {
    return _instance;
  }

  OfflinePersistenceService._internal();

  /// Initialize the offline persistence service
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();

      // Enable Firestore offline persistence
      await FirebaseFirestore.instance.enableNetwork();
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      _logger.i('✅ Offline persistence service initialized');
    } catch (e) {
      _logger.e('❌ Failed to initialize offline persistence: $e');
    }
  }

  /// Cache user data locally
  Future<void> cacheUserData(Map<String, dynamic> userData) async {
    try {
      await _prefs.setString(_userDataKey, jsonEncode(userData));
      await _prefs.setInt(
        '$_timestampKey$_userDataKey',
        DateTime.now().millisecondsSinceEpoch,
      );
      _logger.i('💾 User data cached');
    } catch (e) {
      _logger.e('Failed to cache user data: $e');
    }
  }

  /// Retrieve cached user data
  Future<Map<String, dynamic>?> getCachedUserData() async {
    try {
      final data = _prefs.getString(_userDataKey);
      if (data != null) {
        _logger.i('📂 Retrieved cached user data');
        return jsonDecode(data) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      _logger.e('Failed to retrieve cached user data: $e');
      return null;
    }
  }

  /// Cache pickup requests
  Future<void> cachePickupRequests(List<Map<String, dynamic>> requests) async {
    try {
      await _prefs.setString(_pickupRequestsKey, jsonEncode(requests));
      await _prefs.setInt(
        '$_timestampKey$_pickupRequestsKey',
        DateTime.now().millisecondsSinceEpoch,
      );
      _logger.i('💾 ${requests.length} pickup requests cached');
    } catch (e) {
      _logger.e('Failed to cache pickup requests: $e');
    }
  }

  /// Retrieve cached pickup requests
  Future<List<Map<String, dynamic>>?> getCachedPickupRequests() async {
    try {
      final data = _prefs.getString(_pickupRequestsKey);
      if (data != null) {
        final List<dynamic> decoded = jsonDecode(data);
        _logger.i('📂 Retrieved ${decoded.length} cached pickup requests');
        return List<Map<String, dynamic>>.from(decoded);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to retrieve cached pickup requests: $e');
      return null;
    }
  }

  /// Cache marketplace items
  Future<void> cacheMarketplaceItems(List<Map<String, dynamic>> items) async {
    try {
      await _prefs.setString(_marketplaceItemsKey, jsonEncode(items));
      await _prefs.setInt(
        '$_timestampKey$_marketplaceItemsKey',
        DateTime.now().millisecondsSinceEpoch,
      );
      _logger.i('💾 ${items.length} marketplace items cached');
    } catch (e) {
      _logger.e('Failed to cache marketplace items: $e');
    }
  }

  /// Retrieve cached marketplace items
  Future<List<Map<String, dynamic>>?> getCachedMarketplaceItems() async {
    try {
      final data = _prefs.getString(_marketplaceItemsKey);
      if (data != null) {
        final List<dynamic> decoded = jsonDecode(data);
        _logger.i('📂 Retrieved ${decoded.length} cached marketplace items');
        return List<Map<String, dynamic>>.from(decoded);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to retrieve cached marketplace items: $e');
      return null;
    }
  }

  /// Cache collectors
  Future<void> cacheCollectors(List<Map<String, dynamic>> collectors) async {
    try {
      await _prefs.setString(_collectorsKey, jsonEncode(collectors));
      await _prefs.setInt(
        '$_timestampKey$_collectorsKey',
        DateTime.now().millisecondsSinceEpoch,
      );
      _logger.i('💾 ${collectors.length} collectors cached');
    } catch (e) {
      _logger.e('Failed to cache collectors: $e');
    }
  }

  /// Retrieve cached collectors
  Future<List<Map<String, dynamic>>?> getCachedCollectors() async {
    try {
      final data = _prefs.getString(_collectorsKey);
      if (data != null) {
        final List<dynamic> decoded = jsonDecode(data);
        _logger.i('📂 Retrieved ${decoded.length} cached collectors');
        return List<Map<String, dynamic>>.from(decoded);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to retrieve cached collectors: $e');
      return null;
    }
  }

  /// Cache notifications
  Future<void> cacheNotifications(
    List<Map<String, dynamic>> notifications,
  ) async {
    try {
      await _prefs.setString(_notificationsKey, jsonEncode(notifications));
      await _prefs.setInt(
        '$_timestampKey$_notificationsKey',
        DateTime.now().millisecondsSinceEpoch,
      );
      _logger.i('💾 ${notifications.length} notifications cached');
    } catch (e) {
      _logger.e('Failed to cache notifications: $e');
    }
  }

  /// Retrieve cached notifications
  Future<List<Map<String, dynamic>>?> getCachedNotifications() async {
    try {
      final data = _prefs.getString(_notificationsKey);
      if (data != null) {
        final List<dynamic> decoded = jsonDecode(data);
        _logger.i('📂 Retrieved ${decoded.length} cached notifications');
        return List<Map<String, dynamic>>.from(decoded);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to retrieve cached notifications: $e');
      return null;
    }
  }

  /// Get cache age in minutes
  int? getCacheAgeInMinutes(String cacheKey) {
    try {
      final timestamp = _prefs.getInt('$_timestampKey$cacheKey');
      if (timestamp != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        return ((now - timestamp) / (1000 * 60)).round();
      }
      return null;
    } catch (e) {
      _logger.e('Failed to get cache age: $e');
      return null;
    }
  }

  /// Check if cache is stale (older than maxAgeMinutes)
  bool isCacheStale(String cacheKey, {int maxAgeMinutes = 30}) {
    final age = getCacheAgeInMinutes(cacheKey);
    if (age == null) return true;
    return age > maxAgeMinutes;
  }

  /// Clear all cached data
  Future<void> clearAllCache() async {
    try {
      await _prefs.remove(_userDataKey);
      await _prefs.remove(_pickupRequestsKey);
      await _prefs.remove(_marketplaceItemsKey);
      await _prefs.remove(_collectorsKey);
      await _prefs.remove(_notificationsKey);
      _logger.i('🗑️ All cache cleared');
    } catch (e) {
      _logger.e('Failed to clear cache: $e');
    }
  }

  /// Clear specific cache
  Future<void> clearSpecificCache(String cacheKey) async {
    try {
      await _prefs.remove(cacheKey);
      await _prefs.remove('$_timestampKey$cacheKey');
      _logger.i('🗑️ Cache cleared for: $cacheKey');
    } catch (e) {
      _logger.e('Failed to clear specific cache: $e');
    }
  }
}
