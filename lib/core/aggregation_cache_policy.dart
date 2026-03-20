import '../data/local_db/chobo_records.dart';

class AggregationCachePolicy {
  AggregationCachePolicy({
    int? cacheDurationSeconds,
  }) : _cacheDurationSeconds = cacheDurationSeconds ??
            ChoboAppSettings.defaultCacheDurationSeconds;

  final int _cacheDurationSeconds;

  int get cacheDurationSeconds => _cacheDurationSeconds;

  Duration get cacheDuration => Duration(seconds: _cacheDurationSeconds);

  bool isCacheValid(DateTime cachedAt) {
    final now = DateTime.now();
    return now.difference(cachedAt) < cacheDuration;
  }
}

class CachedMonthlySummary {
  CachedMonthlySummary({
    required this.summary,
    required this.cachedAt,
  });

  final dynamic summary;
  final DateTime cachedAt;
}

class AggregationCache {
  AggregationCache();

  final Map<String, CachedMonthlySummary> _monthCache = {};

  CachedMonthlySummary? get(String month) {
    return _monthCache[month];
  }

  void set(String month, CachedMonthlySummary cached) {
    _monthCache[month] = cached;
  }

  void invalidate(String month) {
    _monthCache.remove(month);
  }

  void invalidateAll() {
    _monthCache.clear();
  }

  void invalidateMonthsAffectedByDate(String date) {
    final month = date.substring(0, 7);
    invalidate(month);
    invalidatePreviousMonths(month);
  }

  void invalidatePreviousMonths(String currentMonth) {
    final keysToRemove = _monthCache.keys
        .where((key) => key.compareTo(currentMonth) < 0)
        .toList();
    for (final key in keysToRemove) {
      _monthCache.remove(key);
    }
  }
}
