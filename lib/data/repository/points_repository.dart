import 'package:drift/drift.dart';

import '../local_db/app_database.dart';
import '../local_db/chobo_records.dart';

class PointsRepository {
  PointsRepository(this._db);

  final AppDatabase _db;

  Future<void> createPointsAccount(ChoboPointsAccountRecord account) async {
    await _db.customInsert(
      '''
      INSERT INTO points_accounts (
        points_account_id,
        name,
        points_currency,
        exchange_rate,
        is_default,
        is_archived,
        created_at,
        updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      variables: _pointsAccountVariables(account),
    );
  }

  Future<ChoboPointsAccountRecord?> getPointsAccount(
      String pointsAccountId) async {
    final row = await _db.customSelect(
      '''
      SELECT points_account_id, name, points_currency, exchange_rate,
             is_default, is_archived, created_at, updated_at
      FROM points_accounts
      WHERE points_account_id = ?
      ''',
      variables: <Variable>[Variable(pointsAccountId)],
    ).getSingleOrNull();
    return row == null ? null : ChoboPointsAccountRecord.fromRow(row);
  }

  Future<List<ChoboPointsAccountRecord>> listPointsAccounts({
    bool includeArchived = false,
  }) async {
    final whereClause = includeArchived ? '' : 'WHERE is_archived = 0';
    final rows = await _db.customSelect(
      '''
      SELECT points_account_id, name, points_currency, exchange_rate,
             is_default, is_archived, created_at, updated_at
      FROM points_accounts
      $whereClause
      ORDER BY is_default DESC, name, points_account_id
      ''',
    ).get();
    return rows.map(ChoboPointsAccountRecord.fromRow).toList(growable: false);
  }

  Future<int> updatePointsAccount(ChoboPointsAccountRecord account) async {
    final original = await getPointsAccount(account.pointsAccountId);
    final preservedCreatedAt = original?.createdAt ?? account.createdAt;

    return _db.customUpdate(
      '''
      UPDATE points_accounts
      SET name = ?,
          points_currency = ?,
          exchange_rate = ?,
          is_default = ?,
          is_archived = ?,
          created_at = ?,
          updated_at = ?
      WHERE points_account_id = ?
      ''',
      variables: <Variable>[
        Variable(account.name),
        Variable(account.pointsCurrency),
        Variable(account.exchangeRate),
        Variable(account.isDefault ? 1 : 0),
        Variable(account.isArchived ? 1 : 0),
        Variable(preservedCreatedAt),
        Variable(account.updatedAt),
        Variable(account.pointsAccountId),
      ],
    );
  }

  Future<int> archivePointsAccount(
      String pointsAccountId, String updatedAt) async {
    return _db.customUpdate(
      '''
      UPDATE points_accounts
      SET is_archived = 1,
          updated_at = ?
      WHERE points_account_id = ?
      ''',
      variables: <Variable>[
        Variable(updatedAt),
        Variable(pointsAccountId),
      ],
    );
  }

  Future<void> earnPoints({
    required String pointsTransactionId,
    required String pointsAccountId,
    required int pointsAmount,
    required int jpyValue,
    required String occurredAt,
    String? transactionId,
    String? description,
    int? validityDays,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    String? expirationDate;
    if (validityDays != null) {
      final expDate = DateTime.now().add(Duration(days: validityDays));
      expirationDate = expDate.toIso8601String().substring(0, 10);
    }

    await _db.customInsert(
      '''
      INSERT INTO points_transactions (
        points_transaction_id,
        points_account_id,
        transaction_id,
        direction,
        points_amount,
        jpy_value,
        description,
        occurred_at,
        expiration_date,
        created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      variables: <Variable>[
        Variable(pointsTransactionId),
        Variable(pointsAccountId),
        Variable(transactionId),
        Variable('earned'),
        Variable(pointsAmount),
        Variable(jpyValue),
        Variable(description),
        Variable(occurredAt),
        Variable(expirationDate),
        Variable(now),
      ],
    );
  }

  Future<void> redeemPoints({
    required String pointsTransactionId,
    required String pointsAccountId,
    required int pointsAmount,
    required int jpyValue,
    required String occurredAt,
    String? transactionId,
    String? description,
  }) async {
    final balance = await getPointsBalance(pointsAccountId);
    if (balance.availableBalance < pointsAmount) {
      throw StateError(
        'Insufficient points balance. Available: ${balance.availableBalance}, Attempted: $pointsAmount',
      );
    }

    final now = DateTime.now().toUtc().toIso8601String();
    await _db.customInsert(
      '''
      INSERT INTO points_transactions (
        points_transaction_id,
        points_account_id,
        transaction_id,
        direction,
        points_amount,
        jpy_value,
        description,
        occurred_at,
        created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      variables: <Variable>[
        Variable(pointsTransactionId),
        Variable(pointsAccountId),
        Variable(transactionId),
        Variable('redeemed'),
        Variable(pointsAmount),
        Variable(jpyValue),
        Variable(description),
        Variable(occurredAt),
        Variable(now),
      ],
    );
  }

  Future<void> expirePoints({
    required String pointsTransactionId,
    required String pointsAccountId,
    required int pointsAmount,
    required String occurredAt,
    String? description,
  }) async {
    final balance = await getPointsBalance(pointsAccountId);
    if (balance.availableBalance < pointsAmount) {
      throw StateError(
        'Insufficient points balance for expiration. Available: ${balance.availableBalance}, Attempted: $pointsAmount',
      );
    }

    final now = DateTime.now().toUtc().toIso8601String();
    await _db.customInsert(
      '''
      INSERT INTO points_transactions (
        points_transaction_id,
        points_account_id,
        transaction_id,
        direction,
        points_amount,
        jpy_value,
        description,
        occurred_at,
        created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      variables: <Variable>[
        Variable(pointsTransactionId),
        Variable(pointsAccountId),
        Variable(null),
        Variable('expired'),
        Variable(pointsAmount),
        Variable(0),
        Variable(description),
        Variable(occurredAt),
        Variable(now),
      ],
    );
  }

  Future<void> adjustPoints({
    required String pointsTransactionId,
    required String pointsAccountId,
    required int pointsAmount,
    required String occurredAt,
    String? description,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.customInsert(
      '''
      INSERT INTO points_transactions (
        points_transaction_id,
        points_account_id,
        transaction_id,
        direction,
        points_amount,
        jpy_value,
        description,
        occurred_at,
        created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      variables: <Variable>[
        Variable(pointsTransactionId),
        Variable(pointsAccountId),
        Variable(null),
        Variable('adjusted'),
        Variable(pointsAmount),
        Variable(0),
        Variable(description),
        Variable(occurredAt),
        Variable(now),
      ],
    );
  }

  Future<ChoboPointsBalanceRecord> getPointsBalance(
      String pointsAccountId) async {
    final rows = await _db.customSelect(
      '''
      SELECT
        points_account_id,
        COALESCE(SUM(CASE WHEN direction = 'earned' THEN points_amount ELSE 0 END), 0) as total_earned,
        COALESCE(SUM(CASE WHEN direction = 'redeemed' THEN points_amount ELSE 0 END), 0) as total_redeemed,
        COALESCE(SUM(CASE WHEN direction = 'expired' THEN points_amount ELSE 0 END), 0) as total_expired,
        COALESCE(SUM(CASE WHEN direction = 'adjusted' THEN points_amount ELSE 0 END), 0) as total_adjusted
      FROM points_transactions
      WHERE points_account_id = ?
      GROUP BY points_account_id
      ''',
      variables: <Variable>[Variable(pointsAccountId)],
    ).getSingleOrNull();

    if (rows == null) {
      return ChoboPointsBalanceRecord(
        pointsAccountId: pointsAccountId,
        totalEarned: 0,
        totalRedeemed: 0,
        totalExpired: 0,
        totalAdjusted: 0,
        currentBalance: 0,
      );
    }

    final totalEarned = rows.read<int>('total_earned');
    final totalRedeemed = rows.read<int>('total_redeemed');
    final totalExpired = rows.read<int>('total_expired');
    final totalAdjusted = rows.read<int>('total_adjusted');
    final currentBalance =
        totalEarned - totalRedeemed - totalExpired + totalAdjusted;

    return ChoboPointsBalanceRecord(
      pointsAccountId: rows.read<String>('points_account_id'),
      totalEarned: totalEarned,
      totalRedeemed: totalRedeemed,
      totalExpired: totalExpired,
      totalAdjusted: totalAdjusted,
      currentBalance: currentBalance,
    );
  }

  Future<List<ChoboPointsTransactionRecord>> listPointsTransactions(
    String pointsAccountId, {
    String? dateFrom,
    String? dateTo,
    int? limit,
    int? offset,
  }) async {
    final conditions = <String>['points_account_id = ?'];
    final variables = <Variable>[Variable(pointsAccountId)];

    if (dateFrom != null) {
      conditions.add('occurred_at >= ?');
      variables.add(Variable(dateFrom));
    }
    if (dateTo != null) {
      conditions.add('occurred_at <= ?');
      variables.add(Variable(dateTo));
    }

    final whereClause = 'WHERE ${conditions.join(' AND ')}';
    final limitClause = limit != null ? 'LIMIT $limit' : '';
    final offsetClause = offset != null ? 'OFFSET $offset' : '';

    final rows = await _db.customSelect(
      '''
      SELECT points_transaction_id, points_account_id, transaction_id,
             direction, points_amount, jpy_value, description,
             occurred_at, created_at
      FROM points_transactions
      $whereClause
      ORDER BY occurred_at DESC, created_at DESC
      $limitClause $offsetClause
      ''',
      variables: variables,
    ).get();
    return rows
        .map(ChoboPointsTransactionRecord.fromRow)
        .toList(growable: false);
  }

  Future<Map<String, ChoboPointsBalanceRecord>> getAllPointsBalances() async {
    final rows = await _db.customSelect(
      '''
      SELECT
        points_account_id,
        COALESCE(SUM(CASE WHEN direction = 'earned' THEN points_amount ELSE 0 END), 0) as total_earned,
        COALESCE(SUM(CASE WHEN direction = 'redeemed' THEN points_amount ELSE 0 END), 0) as total_redeemed,
        COALESCE(SUM(CASE WHEN direction = 'expired' THEN points_amount ELSE 0 END), 0) as total_expired,
        COALESCE(SUM(CASE WHEN direction = 'adjusted' THEN points_amount ELSE 0 END), 0) as total_adjusted
      FROM points_transactions
      GROUP BY points_account_id
      ''',
    ).get();

    final balances = <String, ChoboPointsBalanceRecord>{};
    for (final row in rows) {
      final totalEarned = row.read<int>('total_earned');
      final totalRedeemed = row.read<int>('total_redeemed');
      final totalExpired = row.read<int>('total_expired');
      final totalAdjusted = row.read<int>('total_adjusted');
      final currentBalance =
          totalEarned - totalRedeemed - totalExpired + totalAdjusted;

      balances[row.read<String>('points_account_id')] =
          ChoboPointsBalanceRecord(
        pointsAccountId: row.read<String>('points_account_id'),
        totalEarned: totalEarned,
        totalRedeemed: totalRedeemed,
        totalExpired: totalExpired,
        totalAdjusted: totalAdjusted,
        currentBalance: currentBalance,
      );
    }
    return balances;
  }

  Future<int> getJpyValueForPoints({
    required String pointsAccountId,
    required int pointsAmount,
  }) async {
    final account = await getPointsAccount(pointsAccountId);
    if (account == null) {
      throw StateError('Points account $pointsAccountId not found');
    }
    return (pointsAmount * account.exchangeRate).round();
  }

  List<Variable> _pointsAccountVariables(ChoboPointsAccountRecord account) {
    return <Variable>[
      Variable(account.pointsAccountId),
      Variable(account.name),
      Variable(account.pointsCurrency),
      Variable(account.exchangeRate),
      Variable(account.isDefault ? 1 : 0),
      Variable(account.isArchived ? 1 : 0),
      Variable(account.createdAt),
      Variable(account.updatedAt),
    ];
  }

  Future<List<ChoboPointsTransactionRecord>> getExpiringPoints({
    required String pointsAccountId,
    required int daysThreshold,
  }) async {
    final thresholdDate = DateTime.now()
        .add(Duration(days: daysThreshold))
        .toIso8601String()
        .substring(0, 10);

    final now = DateTime.now().toIso8601String().substring(0, 10);

    final rows = await _db.customSelect(
      '''
      SELECT points_transaction_id, points_account_id, transaction_id,
             direction, points_amount, jpy_value, description,
             occurred_at, expiration_date, created_at
      FROM points_transactions
      WHERE points_account_id = ?
        AND direction = 'earned'
        AND expiration_date IS NOT NULL
        AND expiration_date > ?
        AND expiration_date <= ?
      ORDER BY expiration_date ASC
      ''',
      variables: <Variable>[
        Variable(pointsAccountId),
        Variable(now),
        Variable(thresholdDate),
      ],
    ).get();
    return rows
        .map(ChoboPointsTransactionRecord.fromRow)
        .toList(growable: false);
  }

  Future<int> getExpiringPointsCount({
    required String pointsAccountId,
    required int daysThreshold,
  }) async {
    final thresholdDate = DateTime.now()
        .add(Duration(days: daysThreshold))
        .toIso8601String()
        .substring(0, 10);

    final now = DateTime.now().toIso8601String().substring(0, 10);

    final result = await _db.customSelect(
      '''
      SELECT COALESCE(SUM(points_amount), 0) as total_expiring
      FROM points_transactions
      WHERE points_account_id = ?
        AND direction = 'earned'
        AND expiration_date IS NOT NULL
        AND expiration_date > ?
        AND expiration_date <= ?
      ''',
      variables: <Variable>[
        Variable(pointsAccountId),
        Variable(now),
        Variable(thresholdDate),
      ],
    ).getSingleOrNull();

    return result?.read<int>('total_expiring') ?? 0;
  }
}
