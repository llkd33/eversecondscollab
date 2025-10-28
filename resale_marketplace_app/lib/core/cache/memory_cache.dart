/// 간단한 메모리 캐시 구현
class MemoryCache<T> {
  final Map<String, _CacheEntry<T>> _cache = {};
  final Duration ttl;

  MemoryCache({this.ttl = const Duration(minutes: 5)});

  /// 캐시에 값 저장
  void set(String key, T value) {
    _cache[key] = _CacheEntry(
      value: value,
      expiry: DateTime.now().add(ttl),
    );
  }

  /// 캐시에서 값 조회
  T? get(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }

    return entry.value;
  }

  /// 캐시 전체 삭제
  void clear() {
    _cache.clear();
  }

  /// 특정 키 삭제
  void remove(String key) {
    _cache.remove(key);
  }

  /// 패턴에 맞는 키들 삭제
  void removeWhere(bool Function(String key) test) {
    _cache.removeWhere((key, _) => test(key));
  }

  /// 만료된 항목 정리
  void cleanExpired() {
    _cache.removeWhere((_, entry) => entry.isExpired);
  }

  /// 캐시 크기 조회
  int get size => _cache.length;

  /// 캐시 통계
  Map<String, dynamic> get stats {
    final now = DateTime.now();
    final expired = _cache.values.where((e) => e.isExpired).length;
    final valid = _cache.length - expired;

    return {
      'total': _cache.length,
      'valid': valid,
      'expired': expired,
      'ttl_minutes': ttl.inMinutes,
    };
  }
}

class _CacheEntry<T> {
  final T value;
  final DateTime expiry;

  _CacheEntry({required this.value, required this.expiry});

  bool get isExpired => DateTime.now().isAfter(expiry);
}
