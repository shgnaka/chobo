import 'dart:async';

import '../local_db/chobo_records.dart';
import '../models/search_models.dart';
import '../repository/transaction_search_repository.dart';

class TransactionSearchService {
  TransactionSearchService(this._repository);

  final TransactionSearchRepository _repository;

  final List<SearchQuery> _recentSearches = [];
  static const int _maxRecentSearches = 10;

  DateTime? _lastSearchTime;
  static const Duration _debounceDuration = Duration(milliseconds: 300);

  Future<SearchResult<ChoboTransactionRecord>> search(
    SearchQuery query, {
    bool debounce = true,
  }) async {
    if (debounce) {
      final now = DateTime.now();
      final elapsed =
          _lastSearchTime != null ? now.difference(_lastSearchTime!) : null;
      if (elapsed != null && elapsed < _debounceDuration) {
        await Future.delayed(_debounceDuration - elapsed);
      }
      _lastSearchTime = DateTime.now();
    }

    final result = await _repository.search(query);

    _addToRecentSearches(query);

    return result;
  }

  Future<SearchResult<ChoboTransactionRecord>> quickSearch({
    String? description,
    String? accountId,
    int limit = 20,
  }) async {
    final filter = SearchFilter(
      descriptionContains: description,
      accountIds: accountId != null ? [accountId] : null,
    );

    final query = SearchQuery(
      filter: filter,
      limit: limit,
    );

    return search(query, debounce: false);
  }

  List<SearchQuery> getRecentSearches() {
    return List.unmodifiable(_recentSearches);
  }

  void clearRecentSearches() {
    _recentSearches.clear();
  }

  void _addToRecentSearches(SearchQuery query) {
    if (query.filter.isEmpty) return;

    _recentSearches.removeWhere(
      (q) => q.filter == query.filter,
    );

    _recentSearches.insert(0, query);

    if (_recentSearches.length > _maxRecentSearches) {
      _recentSearches.removeLast();
    }
  }

  void dispose() {
    // No timers to cancel in this implementation
  }
}
