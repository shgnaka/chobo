import 'dart:async';

import '../local_db/chobo_records.dart';
import '../repository/autocomplete_repository.dart';

class SuggestionResult {
  const SuggestionResult({
    required this.value,
    required this.displayText,
    this.subtitle,
    this.score = 0.0,
    this.source = SuggestionSource.recent,
  });

  final String value;
  final String displayText;
  final String? subtitle;
  final double score;
  final SuggestionSource source;

  SuggestionResult copyWith({
    String? value,
    String? displayText,
    String? subtitle,
    double? score,
    SuggestionSource? source,
  }) {
    return SuggestionResult(
      value: value ?? this.value,
      displayText: displayText ?? this.displayText,
      subtitle: subtitle ?? this.subtitle,
      score: score ?? this.score,
      source: source ?? this.source,
    );
  }
}

enum SuggestionSource {
  recent,
  frequent,
  smart,
  search,
  template,
}

class SuggestionService {
  SuggestionService(this._repository);

  final AutocompleteRepository _repository;

  DateTime? _lastCallTime;
  static const Duration _defaultDebounce = Duration(milliseconds: 300);

  Future<List<SuggestionResult>> getSuggestions({
    required SelectionFieldType fieldType,
    String? query,
    String? transactionType,
    int limit = 10,
    bool debounce = true,
  }) async {
    if (debounce) {
      final now = DateTime.now();
      final elapsed =
          _lastCallTime != null ? now.difference(_lastCallTime!) : null;
      if (elapsed != null && elapsed < _defaultDebounce) {
        await Future.delayed(_defaultDebounce - elapsed);
      }
      _lastCallTime = DateTime.now();
    }

    final recents = await _repository.getRecentSuggestions(
      fieldType: fieldType,
      transactionType: transactionType,
      limit: limit,
    );

    final frequents = await _repository.getFrequentSuggestions(
      fieldType: fieldType,
      transactionType: transactionType,
      limit: limit,
    );

    final smartSuggestions = await _repository.getSmartSuggestions(
      fieldType: fieldType,
      transactionType: transactionType,
      limit: limit,
    );

    final suggestions = <SuggestionResult>[];

    final seenValues = <String>{};

    for (final r in recents) {
      if (!seenValues.contains(r.fieldValue)) {
        seenValues.add(r.fieldValue);
        suggestions.add(_toSuggestionResult(r, SuggestionSource.recent));
      }
    }

    for (final f in frequents) {
      if (!seenValues.contains(f.fieldValue)) {
        seenValues.add(f.fieldValue);
        suggestions.add(_toSuggestionResult(f, SuggestionSource.frequent));
      }
    }

    for (final s in smartSuggestions) {
      if (!seenValues.contains(s.fieldValue)) {
        seenValues.add(s.fieldValue);
        suggestions.add(_toSuggestionResult(s, SuggestionSource.smart));
      }
    }

    if (query != null && query.isNotEmpty) {
      final filtered = suggestions.where((s) {
        return s.value.toLowerCase().contains(query.toLowerCase()) ||
            s.displayText.toLowerCase().contains(query.toLowerCase());
      }).toList();

      final sorted = _sortByRelevance(filtered, query);
      return sorted.take(limit).toList();
    }

    return _sortByScore(suggestions).take(limit).toList();
  }

  Future<List<SuggestionResult>> getQuickSuggestions({
    required SelectionFieldType fieldType,
    String? transactionType,
    int limit = 5,
  }) async {
    return getSuggestions(
      fieldType: fieldType,
      transactionType: transactionType,
      limit: limit,
      debounce: false,
    );
  }

  Future<void> recordSelection({
    required SelectionFieldType fieldType,
    required String value,
    String? transactionType,
  }) async {
    final record = ChoboRecentSelectionRecord(
      selectionId: 'sel_${DateTime.now().millisecondsSinceEpoch}',
      fieldType: fieldType,
      fieldValue: value,
      transactionType: transactionType,
      frequency: 1,
      lastSelectedAt: DateTime.now().toUtc().toIso8601String(),
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    await _repository.recordSelection(record);
  }

  Future<void> recordSelections({
    required List<SelectionFieldType> fieldTypes,
    required List<String> values,
    String? transactionType,
  }) async {
    for (int i = 0; i < fieldTypes.length && i < values.length; i++) {
      await recordSelection(
        fieldType: fieldTypes[i],
        value: values[i],
        transactionType: transactionType,
      );
    }
  }

  Future<void> pruneOldSelections({int maxAgeInDays = 90}) async {
    await _repository.pruneOldSelections(maxAgeInDays: maxAgeInDays);
  }

  SuggestionResult _toSuggestionResult(
    ChoboRecentSelectionRecord record,
    SuggestionSource source,
  ) {
    final score = switch (source) {
      SuggestionSource.recent => 0.4,
      SuggestionSource.frequent => 0.3,
      SuggestionSource.smart => 0.5,
      SuggestionSource.search => 0.2,
      SuggestionSource.template => 0.1,
    };

    return SuggestionResult(
      value: record.fieldValue,
      displayText: record.fieldValue,
      subtitle: _formatSubtitle(record),
      score: score + (record.frequency * 0.01),
      source: source,
    );
  }

  String? _formatSubtitle(ChoboRecentSelectionRecord record) {
    if (record.frequency > 1) {
      return '${record.frequency}回使用';
    }
    return null;
  }

  List<SuggestionResult> _sortByScore(List<SuggestionResult> suggestions) {
    final sorted = List<SuggestionResult>.from(suggestions);
    sorted.sort((a, b) => b.score.compareTo(a.score));
    return sorted;
  }

  List<SuggestionResult> _sortByRelevance(
    List<SuggestionResult> suggestions,
    String query,
  ) {
    final sorted = List<SuggestionResult>.from(suggestions);
    sorted.sort((a, b) {
      final aStartsWith = a.value.toLowerCase().startsWith(query.toLowerCase());
      final bStartsWith = b.value.toLowerCase().startsWith(query.toLowerCase());

      if (aStartsWith && !bStartsWith) return -1;
      if (!aStartsWith && bStartsWith) return 1;

      final aContains = a.value.toLowerCase().contains(query.toLowerCase());
      final bContains = b.value.toLowerCase().contains(query.toLowerCase());

      if (aContains && !bContains) return -1;
      if (!aContains && bContains) return 1;

      return b.score.compareTo(a.score);
    });
    return sorted;
  }

  void dispose() {
    // No timers to cancel in this implementation
  }
}
