import 'package:drift/drift.dart';

import '../local_db/app_database.dart';
import '../local_db/chobo_records.dart';
import '../models/search_models.dart';

class TransactionSearchRepository {
  TransactionSearchRepository(this._db);

  final AppDatabase _db;

  Future<SearchResult<ChoboTransactionRecord>> search(
    SearchQuery query,
  ) async {
    if (query.filter.isEmpty) {
      final transactions = await _listRecentTransactions(
        query.limit,
        query.offset,
      );
      final total = await _countRecentTransactions();
      return SearchResult(
        items: transactions,
        totalCount: total,
        hasMore: query.offset + transactions.length < total,
      );
    }

    final conditions = <String>[];
    final variables = <Variable>[];

    _buildConditions(query.filter, conditions, variables);

    final whereClause =
        conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

    final needsEntriesJoin = query.filter.accountIds != null;
    final needsTagsJoin = query.filter.tagIds != null;

    final orderColumn = switch (query.sortField) {
      SortField.date => 't.date',
      SortField.amount => 'e.amount',
      SortField.createdAt => 't.created_at',
    };

    final orderDirection =
        query.sortOrder == SortOrder.ascending ? 'ASC' : 'DESC';

    final baseSql = '''
      SELECT DISTINCT t.transaction_id, t.date, t.type, t.status,
             t.description, t.counterparty, t.counterparty_id,
             t.external_ref, t.original_transaction_id, t.refund_type,
             t.period_lock_state, t.created_at, t.updated_at
      FROM transactions t
      ${needsEntriesJoin ? 'INNER JOIN entries e ON t.transaction_id = e.transaction_id' : ''}
      ${needsTagsJoin ? 'INNER JOIN transaction_tags tt ON t.transaction_id = tt.transaction_id' : ''}
      $whereClause
      ORDER BY $orderColumn $orderDirection
      LIMIT ? OFFSET ?
    ''';

    final countSql = '''
      SELECT COUNT(DISTINCT t.transaction_id) as count
      FROM transactions t
      ${needsEntriesJoin ? 'INNER JOIN entries e ON t.transaction_id = e.transaction_id' : ''}
      ${needsTagsJoin ? 'INNER JOIN transaction_tags tt ON t.transaction_id = tt.transaction_id' : ''}
      $whereClause
    ''';

    final allVariables = [
      ...variables,
      Variable(query.limit),
      Variable(query.offset)
    ];
    final rows = await _db.customSelect(baseSql, variables: allVariables).get();
    final transactions = rows.map(ChoboTransactionRecord.fromRow).toList();

    final countRows =
        await _db.customSelect(countSql, variables: variables).get();
    final totalCount = countRows.first.read<int>('count');

    return SearchResult(
      items: transactions,
      totalCount: totalCount,
      hasMore: query.offset + transactions.length < totalCount,
    );
  }

  void _buildConditions(
    SearchFilter filter,
    List<String> conditions,
    List<Variable> variables,
  ) {
    if (filter.dateFrom != null) {
      conditions.add('t.date >= ?');
      variables.add(Variable(filter.dateFrom!));
    }
    if (filter.dateTo != null) {
      conditions.add('t.date <= ?');
      variables.add(Variable(filter.dateTo!));
    }
    if (filter.type != null) {
      conditions.add('t.type = ?');
      variables.add(Variable(filter.type!));
    }
    if (filter.status != null) {
      conditions.add('t.status = ?');
      variables.add(Variable(filter.status!));
    }
    if (filter.accountIds != null && filter.accountIds!.isNotEmpty) {
      final placeholders = filter.accountIds!.map((_) => '?').join(', ');
      conditions.add('e.account_id IN ($placeholders)');
      variables.addAll(filter.accountIds!.map((id) => Variable(id)));
    }
    if (filter.tagIds != null && filter.tagIds!.isNotEmpty) {
      final placeholders = filter.tagIds!.map((_) => '?').join(', ');
      conditions.add('tt.tag_id IN ($placeholders)');
      variables.addAll(filter.tagIds!.map((id) => Variable(id)));
    }
    if (filter.counterpartyId != null) {
      conditions.add('t.counterparty_id = ?');
      variables.add(Variable(filter.counterpartyId!));
    }
    if (filter.descriptionContains != null &&
        filter.descriptionContains!.isNotEmpty) {
      conditions.add('t.description LIKE ?');
      variables.add(Variable('%${filter.descriptionContains!}%'));
    }
  }

  Future<List<ChoboTransactionRecord>> _listRecentTransactions(
    int limit,
    int offset,
  ) async {
    final rows = await _db.customSelect(
      '''
      SELECT transaction_id, date, type, status, description, counterparty,
             counterparty_id, external_ref, original_transaction_id, refund_type,
             period_lock_state, created_at, updated_at
      FROM transactions
      ORDER BY date DESC, created_at DESC, transaction_id DESC
      LIMIT ? OFFSET ?
      ''',
      variables: <Variable>[Variable(limit), Variable(offset)],
    ).get();
    return rows.map(ChoboTransactionRecord.fromRow).toList();
  }

  Future<int> _countRecentTransactions() async {
    final rows = await _db
        .customSelect(
          'SELECT COUNT(*) as count FROM transactions',
        )
        .get();
    return rows.first.read<int>('count');
  }
}
