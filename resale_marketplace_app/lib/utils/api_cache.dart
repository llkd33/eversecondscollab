import 'dart:convert';
import 'package:flutter/foundation.dart';

/// 캐시 엔트리 클래스
class CacheEntry {
  final dynamic data;
  final DateTime timestamp;
  final Duration ttl;
  
  CacheEntry({
    required this.data,
    required this.timestamp,
    required this.ttl,
  });
  
  bool get isValid {
    return DateTime.now().difference(timestamp) < ttl;
  }
}

/// API 응답 캐시 관리 클래스
/// 네트워크 요청을 최적화하고 중복 요청을 방지
class ApiCache {
  static final ApiCache _instance = ApiCache._internal();
  factory ApiCache() => _instance;
  ApiCache._internal();
  
  // 캐시 저장소
  final Map<String, CacheEntry> _cache = {};
  
  // 기본 캐시 유효 기간
  final Duration defaultTTL = const Duration(minutes: 5);
  
  // 진행 중인 요청 추적 (중복 요청 방지)
  final Map<String, Future<dynamic>> _pendingRequests = {};
  
  /// 캐시 키 생성
  String generateKey(String endpoint, [Map<String, dynamic>? params]) {
    final sortedParams = params != null
        ? (params.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
        : [];
    final paramString = sortedParams
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    return '$endpoint?$paramString';
  }
  
  /// 캐시에서 데이터 가져오기
  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry != null && entry.isValid) {
      if (kDebugMode) {
        print('Cache hit: $key');
      }
      return entry.data as T;
    }
    
    // 만료된 엔트리 제거
    if (entry != null && !entry.isValid) {
      _cache.remove(key);
      if (kDebugMode) {
        print('Cache expired: $key');
      }
    }
    
    return null;
  }
  
  /// 캐시에 데이터 저장
  void set(String key, dynamic data, [Duration? ttl]) {
    _cache[key] = CacheEntry(
      data: data,
      timestamp: DateTime.now(),
      ttl: ttl ?? defaultTTL,
    );
    
    if (kDebugMode) {
      print('Cache set: $key');
    }
  }
  
  /// 중복 요청 방지를 위한 요청 관리
  Future<T> deduplicate<T>(
    String key,
    Future<T> Function() request,
  ) async {
    // 이미 진행 중인 요청이 있는지 확인
    if (_pendingRequests.containsKey(key)) {
      if (kDebugMode) {
        print('Deduplicating request: $key');
      }
      return await _pendingRequests[key] as T;
    }
    
    // 새 요청 시작
    final future = request();
    _pendingRequests[key] = future;
    
    try {
      final result = await future;
      return result;
    } finally {
      _pendingRequests.remove(key);
    }
  }
  
  /// 특정 패턴과 일치하는 캐시 항목 제거
  void invalidatePattern(String pattern) {
    final keysToRemove = _cache.keys
        .where((key) => key.contains(pattern))
        .toList();
    
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
    
    if (kDebugMode && keysToRemove.isNotEmpty) {
      print('Invalidated ${keysToRemove.length} cache entries matching: $pattern');
    }
  }
  
  /// 특정 키의 캐시 제거
  void invalidate(String key) {
    _cache.remove(key);
    if (kDebugMode) {
      print('Cache invalidated: $key');
    }
  }
  
  /// 전체 캐시 클리어
  void clear() {
    _cache.clear();
    _pendingRequests.clear();
    if (kDebugMode) {
      print('Cache cleared');
    }
  }
  
  /// 캐시 통계
  Map<String, dynamic> getStats() {
    final validEntries = _cache.entries
        .where((e) => e.value.isValid)
        .length;
    
    return {
      'total_entries': _cache.length,
      'valid_entries': validEntries,
      'expired_entries': _cache.length - validEntries,
      'pending_requests': _pendingRequests.length,
      'cache_size_estimate': _estimateCacheSize(),
    };
  }
  
  /// 캐시 크기 추정 (바이트)
  int _estimateCacheSize() {
    int totalSize = 0;
    for (final entry in _cache.values) {
      try {
        final jsonString = jsonEncode(entry.data);
        totalSize += jsonString.length * 2; // UTF-16 추정
      } catch (e) {
        // JSON 인코딩 불가능한 데이터는 건너뜀
      }
    }
    return totalSize;
  }
  
  /// 오래된 캐시 항목 정리
  void cleanup() {
    final keysToRemove = <String>[];
    
    _cache.forEach((key, entry) {
      if (!entry.isValid) {
        keysToRemove.add(key);
      }
    });
    
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
    
    if (kDebugMode && keysToRemove.isNotEmpty) {
      print('Cleaned up ${keysToRemove.length} expired cache entries');
    }
  }
}