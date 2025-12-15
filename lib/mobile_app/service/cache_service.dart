import 'package:flutter_application_1/mobile_app/constants/app_constants.dart';
import 'package:flutter_application_1/mobile_app/service/logging_service.dart';

/// Model for cached data
class CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  final Duration ttl;

  CacheEntry({required this.data, required this.timestamp, required this.ttl});

  bool isExpired() {
    return DateTime.now().difference(timestamp) > ttl;
  }

  int getAgeInSeconds() {
    return DateTime.now().difference(timestamp).inSeconds;
  }
}

/// Local in-memory cache service for frequently accessed data
class CacheService {
  static final CacheService _instance = CacheService._internal();
  final Map<String, CacheEntry<dynamic>> _cache = {};

  factory CacheService() {
    return _instance;
  }

  CacheService._internal();

  /// Set cache value
  static void set<T>(String key, T value, {Duration? ttl}) {
    final duration =
        ttl ?? Duration(minutes: AppConstants.cacheDurationMinutes);
    _instance._cache[key] = CacheEntry(
      data: value,
      timestamp: DateTime.now(),
      ttl: duration,
    );

    LoggingService.logCacheOperation('SET', key);
  }

  /// Get cache value
  static T? get<T>(String key) {
    final entry = _instance._cache[key];

    if (entry == null) {
      LoggingService.logCacheOperation('MISS', key, hit: false);
      return null;
    }

    if (entry.isExpired()) {
      _instance._cache.remove(key);
      LoggingService.logCacheOperation('EXPIRED', key, hit: false);
      return null;
    }

    LoggingService.logCacheOperation('HIT', key, hit: true);
    return entry.data as T;
  }

  /// Check if key exists and is valid
  static bool has(String key) {
    final entry = _instance._cache[key];
    if (entry == null) return false;
    if (entry.isExpired()) {
      _instance._cache.remove(key);
      return false;
    }
    return true;
  }

  /// Remove specific cache entry
  static void remove(String key) {
    _instance._cache.remove(key);
    LoggingService.logCacheOperation('REMOVE', key);
  }

  /// Clear all cache
  static void clear() {
    _instance._cache.clear();
    LoggingService.info('Cache cleared');
  }

  /// Get cache statistics
  static Map<String, dynamic> getStats() {
    int validEntries = 0;
    int expiredEntries = 0;

    for (final entry in _instance._cache.values) {
      if (entry.isExpired()) {
        expiredEntries++;
      } else {
        validEntries++;
      }
    }

    return {
      'totalEntries': _instance._cache.length,
      'validEntries': validEntries,
      'expiredEntries': expiredEntries,
      'memorySizeBytes': _estimateMemorySize(),
    };
  }

  /// Cache marketplace items
  static void cacheMarketplaceItems(String key, List<dynamic> items) {
    set(
      'marketplace_items_$key',
      items,
      ttl: Duration(minutes: AppConstants.cacheDurationMinutes),
    );
  }

  /// Get cached marketplace items
  static List<dynamic>? getMarketplaceItems(String key) {
    return get<List<dynamic>>('marketplace_items_$key');
  }

  /// Cache user data
  static void cacheUserData(String userId, Map<String, dynamic> userData) {
    set(
      'user_$userId',
      userData,
      ttl: Duration(minutes: AppConstants.userCacheDurationMinutes),
    );
  }

  /// Get cached user data
  static Map<String, dynamic>? getUserData(String userId) {
    return get<Map<String, dynamic>>('user_$userId');
  }

  /// Cache collector data
  static void cacheCollectorData(
    String collectorId,
    Map<String, dynamic> data,
  ) {
    set(
      'collector_$collectorId',
      data,
      ttl: Duration(minutes: AppConstants.userCacheDurationMinutes),
    );
  }

  /// Get cached collector data
  static Map<String, dynamic>? getCollectorData(String collectorId) {
    return get<Map<String, dynamic>>('collector_$collectorId');
  }

  /// Cache search results
  static void cacheSearchResults(String query, List<dynamic> results) {
    set('search_$query', results, ttl: Duration(minutes: 15));
  }

  /// Get cached search results
  static List<dynamic>? getSearchResults(String query) {
    return get<List<dynamic>>('search_$query');
  }

  /// Invalidate user-specific cache
  static void invalidateUserCache(String userId) {
    _instance._cache.removeWhere((key, _) => key.contains(userId));
    LoggingService.info('User cache invalidated: $userId');
  }

  /// Invalidate marketplace cache
  static void invalidateMarketplaceCache() {
    _instance._cache.removeWhere(
      (key, _) => key.startsWith('marketplace_items_'),
    );
    LoggingService.info('Marketplace cache invalidated');
  }

  /// Get all cache keys
  static List<String> getKeys() {
    return _instance._cache.keys.toList();
  }

  /// Get cache entry age in minutes
  static int? getEntryAgeMinutes(String key) {
    final entry = _instance._cache[key];
    if (entry == null) return null;
    return entry.getAgeInSeconds() ~/ 60;
  }

  /// Cleanup expired entries
  static int cleanupExpired() {
    int count = 0;
    _instance._cache.removeWhere((key, entry) {
      if (entry.isExpired()) {
        count++;
        return true;
      }
      return false;
    });

    LoggingService.info('Cleanup: Removed $count expired entries');
    return count;
  }

  /// Get cache size
  static int getCacheSize() {
    return _instance._cache.length;
  }

  /// Estimate memory size (rough estimate)
  static int _estimateMemorySize() {
    int size = 0;
    for (final entry in _instance._cache.values) {
      size += _estimateDataSize(entry.data);
    }
    return size;
  }

  /// Estimate size of data object
  static int _estimateDataSize(dynamic data) {
    if (data == null) return 0;
    if (data is String) return data.length * 2;
    if (data is List) {
      return data.fold(0, (sum, item) => sum + _estimateDataSize(item));
    }
    if (data is Map) {
      return data.entries.fold(
        0,
        (sum, entry) =>
            sum + _estimateDataSize(entry.key) + _estimateDataSize(entry.value),
      );
    }
    return 100; // Default estimate for objects
  }
}
