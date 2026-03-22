import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/chobo_providers.dart';
import '../../data/local_db/chobo_records.dart';
import '../../data/models/search_models.dart';
import '../home/transaction_list_tile.dart';

final transactionSearchQueryProvider = StateProvider<SearchQuery>((ref) {
  return const SearchQuery(filter: SearchFilter());
});

final transactionSearchResultsProvider =
    FutureProvider.autoDispose<SearchResult<ChoboTransactionRecord>>(
        (ref) async {
  final query = ref.watch(transactionSearchQueryProvider);
  final repository = ref.watch(transactionSearchRepositoryProvider);
  return repository.search(query);
});

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _descriptionController = TextEditingController();
  String? _selectedType;
  String? _selectedStatus;
  DateTimeRange? _dateRange;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _updateSearch() {
    final filter = SearchFilter(
      dateFrom: _dateRange?.start.toIso8601String().split('T').first,
      dateTo: _dateRange?.end.toIso8601String().split('T').first,
      type: _selectedType,
      status: _selectedStatus,
      descriptionContains: _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text,
    );

    ref.read(transactionSearchQueryProvider.notifier).state =
        SearchQuery(filter: filter);
  }

  void _clearFilters() {
    setState(() {
      _descriptionController.clear();
      _selectedType = null;
      _selectedStatus = null;
      _dateRange = null;
    });
    ref.read(transactionSearchQueryProvider.notifier).state = const SearchQuery(
      filter: SearchFilter(),
    );
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
      _updateSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(transactionSearchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('検索'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_off),
            onPressed: _clearFilters,
            tooltip: 'フィルターをクリア',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          const Divider(height: 1),
          Expanded(
            child: resultsAsync.when(
              data: (result) => _buildResults(result),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('検索エラー: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _descriptionController,
        decoration: InputDecoration(
          hintText: '説明文で検索...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _descriptionController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _descriptionController.clear();
                    _updateSearch();
                  },
                )
              : null,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        onChanged: (_) => _updateSearch(),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            label: Text(_dateRange != null
                ? '${_formatDate(_dateRange!.start)} - ${_formatDate(_dateRange!.end)}'
                : '日付範囲'),
            selected: _dateRange != null,
            onSelected: (_) => _selectDateRange(),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('すべて'),
            selected: _selectedType == null,
            onSelected: (_) {
              setState(() => _selectedType = null);
              _updateSearch();
            },
          ),
          const SizedBox(width: 8),
          ...const [
            'income',
            'expense',
            'transfer',
            'credit_expense',
            'liability_payment',
            'advance_payment',
            'reimbursement'
          ].map((type) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(_typeLabel(type)),
                  selected: _selectedType == type,
                  onSelected: (selected) {
                    setState(() => _selectedType = selected ? type : null);
                    _updateSearch();
                  },
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildResults(SearchResult<ChoboTransactionRecord> result) {
    if (result.items.isEmpty) {
      return const Center(
        child: Text('検索結果がありません'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '${result.totalCount}件中 ${result.items.length}件を表示',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: result.items.length,
            itemBuilder: (context, index) {
              final transaction = result.items[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TransactionListTile(transaction: transaction),
              );
            },
          ),
        ),
        if (result.hasMore)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: TextButton(
                onPressed: () {
                  final currentQuery = ref.read(transactionSearchQueryProvider);
                  ref.read(transactionSearchQueryProvider.notifier).state =
                      currentQuery.copyWith(
                    offset: currentQuery.offset + currentQuery.limit,
                  );
                },
                child: const Text('もっと見る'),
              ),
            ),
          ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  String _typeLabel(String type) {
    return switch (type) {
      'income' => '収入',
      'expense' => '支出',
      'transfer' => '振替',
      'credit_expense' => '請求',
      'liability_payment' => '支払',
      'advance_payment' => '立替',
      'reimbursement' => '精算',
      _ => type,
    };
  }
}
