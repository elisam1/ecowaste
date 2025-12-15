import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  static const Duration _defaultCacheDuration = Duration(hours: 24);
  static const int _maxMemoryCacheSize = 50;
  static const int _maxDiskCacheSize = 100 * 1024 * 1024; // 100MB

  final Map<String, _CacheEntry> _memoryCache = {};
  Directory? _cacheDir;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _cacheDir = await getApplicationCacheDirectory();
      await _ensureCacheDirectoryExists();

      // Clean up old cache files on startup
      await _cleanupOldCacheFiles();

      _initialized = true;
      debugPrint('CacheManager initialized');
    } catch (e) {
      debugPrint('Failed to initialize CacheManager: $e');
    }
  }

  Future<void> _ensureCacheDirectoryExists() async {
    if (_cacheDir == null) return;

    final cacheSubDir = Directory(
      path.join(_cacheDir!.path, 'eco_waste_cache'),
    );
    if (!await cacheSubDir.exists()) {
      await cacheSubDir.create(recursive: true);
    }
    _cacheDir = cacheSubDir;
  }

  // Memory cache operations
  Future<T?> getFromMemory<T>(String key) async {
    final entry = _memoryCache[key];
    if (entry == null || entry.isExpired) {
      _memoryCache.remove(key);
      return null;
    }
    return entry.data as T?;
  }

  Future<void> setInMemory<T>(String key, T data, {Duration? duration}) async {
    final expiryTime = DateTime.now().add(duration ?? _defaultCacheDuration);
    _memoryCache[key] = _CacheEntry(data, expiryTime);

    // Maintain cache size limit
    if (_memoryCache.length > _maxMemoryCacheSize) {
      _evictOldestMemoryEntries();
    }
  }

  void _evictOldestMemoryEntries() {
    if (_memoryCache.isEmpty) return;

    // Find oldest entry
    String? oldestKey;
    DateTime? oldestTime;

    _memoryCache.forEach((key, entry) {
      if (oldestTime == null || entry.expiryTime.isBefore(oldestTime!)) {
        oldestTime = entry.expiryTime;
        oldestKey = key;
      }
    });

    if (oldestKey != null) {
      _memoryCache.remove(oldestKey);
    }
  }

  // Disk cache operations
  String _generateCacheKey(String key) {
    return sha256.convert(utf8.encode(key)).toString();
  }

  Future<T?> getFromDisk<T>(String key) async {
    if (!_initialized || _cacheDir == null) return null;

    try {
      final cacheKey = _generateCacheKey(key);
      final file = File(path.join(_cacheDir!.path, cacheKey));

      if (!await file.exists()) return null;

      final content = await file.readAsString();
      final jsonData = json.decode(content);

      final entry = _CacheEntry.fromJson(jsonData);
      if (entry.isExpired) {
        await file.delete();
        return null;
      }

      return entry.data as T?;
    } catch (e) {
      debugPrint('Error reading from disk cache: $e');
      return null;
    }
  }

  Future<void> setOnDisk<T>(String key, T data, {Duration? duration}) async {
    if (!_initialized || _cacheDir == null) return;

    try {
      final cacheKey = _generateCacheKey(key);
      final file = File(path.join(_cacheDir!.path, cacheKey));

      final entry = _CacheEntry(
        data,
        DateTime.now().add(duration ?? _defaultCacheDuration),
      );
      final jsonData = entry.toJson();

      await file.writeAsString(json.encode(jsonData));

      // Maintain disk cache size limit
      await _maintainDiskCacheSize();
    } catch (e) {
      debugPrint('Error writing to disk cache: $e');
    }
  }

  Future<void> _maintainDiskCacheSize() async {
    if (_cacheDir == null) return;

    try {
      final files = await _cacheDir!.list().toList();
      int totalSize = 0;
      final fileInfo = <File, DateTime>{};

      for (final entity in files) {
        if (entity is File) {
          final stat = await entity.stat();
          totalSize += stat.size;
          fileInfo[entity] = stat.modified;
        }
      }

      // If cache is too large, delete oldest files
      if (totalSize > _maxDiskCacheSize) {
        final sortedFiles = fileInfo.entries.toList()
          ..sort(
            (a, b) => a.value.compareTo(b.value),
          ); // Sort by modification time

        int sizeToFree =
            totalSize - (_maxDiskCacheSize * 0.8).toInt(); // Free 20% of cache

        for (final entry in sortedFiles) {
          if (sizeToFree <= 0) break;

          final file = entry.key;
          final stat = await file.stat();
          await file.delete();
          sizeToFree -= stat.size;
        }
      }
    } catch (e) {
      debugPrint('Error maintaining disk cache size: $e');
    }
  }

  // Combined cache operations (memory first, then disk)
  Future<T?> get<T>(String key) async {
    // Try memory cache first
    T? data = await getFromMemory<T>(key);
    if (data != null) {
      return data;
    }

    // Try disk cache
    data = await getFromDisk<T>(key);
    if (data != null) {
      // Promote to memory cache
      await setInMemory(key, data);
    }

    return data;
  }

  Future<void> set<T>(String key, T data, {Duration? duration}) async {
    // Set in both memory and disk cache
    await setInMemory(key, data, duration: duration);
    await setOnDisk(key, data, duration: duration);
  }

  Future<void> remove(String key) async {
    _memoryCache.remove(key);

    if (_initialized && _cacheDir != null) {
      try {
        final cacheKey = _generateCacheKey(key);
        final file = File(path.join(_cacheDir!.path, cacheKey));
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Error removing from disk cache: $e');
      }
    }
  }

  Future<void> clear() async {
    _memoryCache.clear();

    if (_initialized && _cacheDir != null) {
      try {
        final files = await _cacheDir!.list().toList();
        for (final entity in files) {
          if (entity is File) {
            await entity.delete();
          }
        }
      } catch (e) {
        debugPrint('Error clearing disk cache: $e');
      }
    }
  }

  Future<void> _cleanupOldCacheFiles() async {
    if (_cacheDir == null) return;

    try {
      final files = await _cacheDir!.list().toList();
      final now = DateTime.now();

      for (final entity in files) {
        if (entity is File) {
          final stat = await entity.stat();
          // Delete files older than 7 days
          if (now.difference(stat.modified).inDays > 7) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up old cache files: $e');
    }
  }

  // Image caching specifically
  Future<String?> getCachedImageUrl(String imageUrl) async {
    final cacheKey = 'image_${_generateCacheKey(imageUrl)}';
    return await get<String>(cacheKey);
  }

  Future<void> cacheImageUrl(String imageUrl, String cachedPath) async {
    final cacheKey = 'image_${_generateCacheKey(imageUrl)}';
    await set(cacheKey, cachedPath, duration: const Duration(days: 7));
  }

  // API response caching
  Future<Map<String, dynamic>?> getApiResponse(
    String endpoint, {
    Map<String, dynamic>? params,
  }) async {
    final queryString = params != null
        ? Uri(
            queryParameters: params.map((k, v) => MapEntry(k, v.toString())),
          ).query
        : '';
    final cacheKey = 'api_${endpoint}_${queryString}';
    return await get<Map<String, dynamic>>(cacheKey);
  }

  Future<void> cacheApiResponse(
    String endpoint,
    Map<String, dynamic> response, {
    Map<String, dynamic>? params,
  }) async {
    final queryString = params != null
        ? Uri(
            queryParameters: params.map((k, v) => MapEntry(k, v.toString())),
          ).query
        : '';
    final cacheKey = 'api_${endpoint}_${queryString}';
    await set(cacheKey, response, duration: const Duration(minutes: 30));
  }

  // User data caching
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    final cacheKey = 'user_data_$userId';
    return await get<Map<String, dynamic>>(cacheKey);
  }

  Future<void> cacheUserData(
    String userId,
    Map<String, dynamic> userData,
  ) async {
    final cacheKey = 'user_data_$userId';
    await set(cacheKey, userData, duration: const Duration(hours: 1));
  }

  // Marketplace data caching
  Future<List<Map<String, dynamic>>?> getMarketplaceItems({
    String? category,
    int? limit,
  }) async {
    final cacheKey = 'marketplace_${category ?? 'all'}_${limit ?? 50}';
    return await get<List<Map<String, dynamic>>>(cacheKey);
  }

  Future<void> cacheMarketplaceItems(
    List<Map<String, dynamic>> items, {
    String? category,
    int? limit,
  }) async {
    final cacheKey = 'marketplace_${category ?? 'all'}_${limit ?? 50}';
    await set(cacheKey, items, duration: const Duration(minutes: 15));
  }

  // Cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    final memoryCacheSize = _memoryCache.length;
    int diskCacheSize = 0;
    int diskFileCount = 0;

    if (_initialized && _cacheDir != null) {
      try {
        final files = await _cacheDir!.list().toList();
        diskFileCount = files.length;

        for (final entity in files) {
          if (entity is File) {
            diskCacheSize += await entity.length();
          }
        }
      } catch (e) {
        debugPrint('Error getting disk cache stats: $e');
      }
    }

    return {
      'memoryCacheEntries': memoryCacheSize,
      'diskCacheFiles': diskFileCount,
      'diskCacheSizeBytes': diskCacheSize,
      'diskCacheSizeMB': (diskCacheSize / (1024 * 1024)).toStringAsFixed(2),
    };
  }
}

class _CacheEntry<T> {
  final T data;
  final DateTime expiryTime;

  _CacheEntry(this.data, this.expiryTime);

  bool get isExpired => DateTime.now().isAfter(expiryTime);

  Map<String, dynamic> toJson() {
    return {'data': data, 'expiryTime': expiryTime.toIso8601String()};
  }

  factory _CacheEntry.fromJson(Map<String, dynamic> json) {
    return _CacheEntry(json['data'], DateTime.parse(json['expiryTime']));
  }
}

// HTTP client with caching
class CachedHttpClient {
  final http.Client _client = http.Client();
  final CacheManager _cacheManager = CacheManager();

  Future<http.Response> get(Uri url, {Duration? cacheDuration}) async {
    final cacheKey = 'http_get_${url.toString()}';

    // Try to get from cache first
    final cachedResponse = await _cacheManager.get<Map<String, dynamic>>(
      cacheKey,
    );
    if (cachedResponse != null) {
      return http.Response(
        cachedResponse['body'],
        cachedResponse['statusCode'],
        headers: Map<String, String>.from(cachedResponse['headers']),
        request: http.Request('GET', url),
      );
    }

    // Make actual request
    final response = await _client.get(url);

    // Cache successful responses
    if (response.statusCode == 200) {
      await _cacheManager.set(cacheKey, {
        'body': response.body,
        'statusCode': response.statusCode,
        'headers': response.headers,
      }, duration: cacheDuration ?? const Duration(minutes: 30));
    }

    return response;
  }

  void dispose() {
    _client.close();
  }
}

// Cache-aware widgets
class CachedNetworkImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CachedNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<CachedNetworkImage> createState() => _CachedNetworkImageState();
}

class _CachedNetworkImageState extends State<CachedNetworkImage> {
  final CacheManager _cacheManager = CacheManager();
  String? _cachedImagePath;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      _cachedImagePath = await _cacheManager.getCachedImageUrl(widget.imageUrl);

      if (_cachedImagePath == null) {
        // Download and cache image
        // In a real implementation, you'd use flutter_cache_manager or similar
        // For now, we'll just simulate
        await Future.delayed(const Duration(seconds: 1));
        _cachedImagePath = widget.imageUrl; // Placeholder
        await _cacheManager.cacheImageUrl(widget.imageUrl, widget.imageUrl);
      }

      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return widget.placeholder ?? const CircularProgressIndicator();
    }

    if (_error || _cachedImagePath == null) {
      return widget.errorWidget ?? const Icon(Icons.error);
    }

    return Image.network(
      _cachedImagePath!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return widget.placeholder ?? const CircularProgressIndicator();
      },
      errorBuilder: (context, error, stackTrace) {
        return widget.errorWidget ?? const Icon(Icons.error);
      },
    );
  }
}
