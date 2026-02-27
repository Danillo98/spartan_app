import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Sistema de Cache Inteligente para Spartan App
///
/// Estratégia:
/// - Cache de contexto (academia, usuário): TTL 10min
/// - Cache de listagens: TTL 3min
/// - Invalidação automática em writes
/// - Compressão de dados para economizar memória
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  SharedPreferences? _prefs;
  final Map<String, _CacheEntry> _memoryCache = {};

  // TTL Configurations
  static const Duration _listTTL = Duration(minutes: 3);

  /// Initialize cache system
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _cleanExpiredCache();
  }

  /// Get cached data
  Future<T?> get<T>(
    String key, {
    Duration? customTTL,
    bool useMemoryOnly = false,
  }) async {
    // 1. Check memory cache first (fastest)
    if (_memoryCache.containsKey(key)) {
      final entry = _memoryCache[key]!;
      if (!entry.isExpired) {
        return entry.data as T?;
      } else {
        _memoryCache.remove(key);
      }
    }

    // 2. Check persistent cache
    if (!useMemoryOnly && _prefs != null) {
      final cached = _prefs!.getString(key);
      if (cached != null) {
        try {
          final decoded = jsonDecode(cached);
          final expiresAt = DateTime.parse(decoded['expiresAt']);

          if (DateTime.now().isBefore(expiresAt)) {
            final data = decoded['data'] as T;

            // Restore to memory cache
            _memoryCache[key] = _CacheEntry(
              data: data,
              expiresAt: expiresAt,
            );

            return data;
          } else {
            // Expired, remove
            await _prefs!.remove(key);
          }
        } catch (e) {
          print('Cache decode error for $key: $e');
          await _prefs!.remove(key);
        }
      }
    }

    return null;
  }

  /// Set cache data
  Future<void> set(
    String key,
    dynamic data, {
    Duration? customTTL,
    bool memoryOnly = false,
  }) async {
    final ttl = customTTL ?? _listTTL;
    final expiresAt = DateTime.now().add(ttl);

    // Always set in memory cache
    _memoryCache[key] = _CacheEntry(
      data: data,
      expiresAt: expiresAt,
    );

    // Optionally persist
    if (!memoryOnly && _prefs != null) {
      try {
        final encoded = jsonEncode({
          'data': data,
          'expiresAt': expiresAt.toIso8601String(),
        });
        await _prefs!.setString(key, encoded);
      } on Exception catch (e) {
        final msg = e.toString();
        // QuotaExceededError: too large for localStorage → keep in memory only
        if (msg.toLowerCase().contains('quota') ||
            msg.toLowerCase().contains('storage')) {
          print('[Cache] Quota excedida para "$key", mantendo só em memória.');
        } else {
          print('Cache encode error for $key: $e');
        }
      }
    }
  }

  /// Invalidate specific cache key
  Future<void> invalidate(String key) async {
    _memoryCache.remove(key);
    await _prefs?.remove(key);
  }

  /// Invalidate cache by pattern (e.g., 'diets_*')
  Future<void> invalidatePattern(String pattern) async {
    // Memory cache
    final keysToRemove =
        _memoryCache.keys.where((k) => _matchesPattern(k, pattern)).toList();

    for (final key in keysToRemove) {
      _memoryCache.remove(key);
    }

    // Persistent cache
    if (_prefs != null) {
      final allKeys = _prefs!.getKeys();
      for (final key in allKeys) {
        if (_matchesPattern(key, pattern)) {
          await _prefs!.remove(key);
        }
      }
    }
  }

  /// Clear all cache
  Future<void> clearAll() async {
    _memoryCache.clear();
    await _prefs?.clear();
  }

  /// Clean expired cache entries
  void _cleanExpiredCache() {
    // Memory cache
    _memoryCache.removeWhere((key, entry) => entry.isExpired);

    // Persistent cache (async)
    if (_prefs != null) {
      final allKeys = _prefs!.getKeys();
      for (final key in allKeys) {
        final cached = _prefs!.getString(key);
        if (cached != null) {
          try {
            final decoded = jsonDecode(cached);
            final expiresAt = DateTime.parse(decoded['expiresAt']);
            if (DateTime.now().isAfter(expiresAt)) {
              _prefs!.remove(key);
            }
          } catch (e) {
            _prefs!.remove(key);
          }
        }
      }
    }
  }

  /// Helper to match cache key patterns
  bool _matchesPattern(String key, String pattern) {
    if (pattern.endsWith('*')) {
      final prefix = pattern.substring(0, pattern.length - 1);
      return key.startsWith(prefix);
    }
    return key == pattern;
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    return {
      'memory_entries': _memoryCache.length,
      'persistent_entries': _prefs?.getKeys().length ?? 0,
      'memory_size_kb': _estimateMemorySize(),
    };
  }

  int _estimateMemorySize() {
    int totalSize = 0;
    for (final entry in _memoryCache.values) {
      try {
        totalSize += jsonEncode(entry.data).length;
      } catch (e) {
        // Skip non-serializable data
      }
    }
    return totalSize ~/ 1024; // Convert to KB
  }
}

/// Cache entry with expiration
class _CacheEntry {
  final dynamic data;
  final DateTime expiresAt;

  _CacheEntry({
    required this.data,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Cache key generators
class CacheKeys {
  // Context
  static String userContext(String userId) => 'context_user_$userId';

  // Diets
  static String allDiets(String academyId) => 'diets_all_$academyId';
  static String dietsByNutritionist(String nutriId) => 'diets_nutri_$nutriId';
  static String dietsByStudent(String studentId) => 'diets_student_$studentId';
  static String dietDetail(String dietId) => 'diet_detail_$dietId';

  // Workouts
  static String allWorkouts(String academyId) => 'workouts_all_$academyId';
  static String workoutsByPersonal(String personalId) =>
      'workouts_personal_$personalId';
  static String workoutsByStudent(String studentId) =>
      'workouts_student_$studentId';
  static String workoutDetail(String workoutId) => 'workout_detail_$workoutId';

  // Students
  static String myStudents(String professionalId) => 'students_$professionalId';

  // Users
  static String userProfile(String userId) => 'user_profile_$userId';
}
