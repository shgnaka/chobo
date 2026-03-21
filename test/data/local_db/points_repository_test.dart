import 'package:chobo/data/local_db/app_database.dart';
import 'package:chobo/data/local_db/chobo_records.dart';
import 'package:chobo/data/repository/points_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PointsRepository', () {
    test('creates a points account', () async {
      final db = _openDb();
      addTearDown(db.close);
      final points = PointsRepository(db);

      await points.createPointsAccount(_samplePointsAccount());

      final account = await points.getPointsAccount('points:tpoint');
      expect(account, isNotNull);
      expect(account!.name, 'T-Point');
      expect(account.pointsCurrency, 'T');
      expect(account.exchangeRate, 1);
    });

    test('lists points accounts', () async {
      final db = _openDb();
      addTearDown(db.close);
      final points = PointsRepository(db);

      await points.createPointsAccount(_samplePointsAccount(
        pointsAccountId: 'points:tpoint',
        name: 'T-Point',
      ));
      await points.createPointsAccount(_samplePointsAccount(
        pointsAccountId: 'points:rakuten',
        name: 'Rakuten',
      ));

      final accounts = await points.listPointsAccounts();
      expect(accounts.length, 2);
    });

    test('archives a points account', () async {
      final db = _openDb();
      addTearDown(db.close);
      final points = PointsRepository(db);

      await points.createPointsAccount(_samplePointsAccount());
      await points.archivePointsAccount(
          'points:tpoint', '2026-03-20T10:00:00Z');

      final accounts = await points.listPointsAccounts();
      expect(accounts.length, 0);

      final allAccounts =
          await points.listPointsAccounts(includeArchived: true);
      expect(allAccounts.length, 1);
      expect(allAccounts.first.isArchived, isTrue);
    });

    test('earns points and updates balance', () async {
      final db = _openDb();
      addTearDown(db.close);
      final points = PointsRepository(db);

      await points.createPointsAccount(_samplePointsAccount());
      await points.earnPoints(
        pointsTransactionId: 'ptxn_001',
        pointsAccountId: 'points:tpoint',
        pointsAmount: 100,
        jpyValue: 100,
        occurredAt: '2026-03-20',
        description: 'Earned from purchase',
      );

      final balance = await points.getPointsBalance('points:tpoint');
      expect(balance.totalEarned, 100);
      expect(balance.currentBalance, 100);
      expect(balance.availableBalance, 100);
    });

    test('redeems points with sufficient balance', () async {
      final db = _openDb();
      addTearDown(db.close);
      final points = PointsRepository(db);

      await points.createPointsAccount(_samplePointsAccount());
      await points.earnPoints(
        pointsTransactionId: 'ptxn_001',
        pointsAccountId: 'points:tpoint',
        pointsAmount: 100,
        jpyValue: 100,
        occurredAt: '2026-03-20',
      );
      await points.redeemPoints(
        pointsTransactionId: 'ptxn_002',
        pointsAccountId: 'points:tpoint',
        pointsAmount: 50,
        jpyValue: 50,
        occurredAt: '2026-03-21',
      );

      final balance = await points.getPointsBalance('points:tpoint');
      expect(balance.totalEarned, 100);
      expect(balance.totalRedeemed, 50);
      expect(balance.currentBalance, 50);
    });

    test('rejects redemption with insufficient balance', () async {
      final db = _openDb();
      addTearDown(db.close);
      final points = PointsRepository(db);

      await points.createPointsAccount(_samplePointsAccount());
      await points.earnPoints(
        pointsTransactionId: 'ptxn_001',
        pointsAccountId: 'points:tpoint',
        pointsAmount: 100,
        jpyValue: 100,
        occurredAt: '2026-03-20',
      );

      await expectLater(
        points.redeemPoints(
          pointsTransactionId: 'ptxn_002',
          pointsAccountId: 'points:tpoint',
          pointsAmount: 150,
          jpyValue: 150,
          occurredAt: '2026-03-21',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('expires points with sufficient balance', () async {
      final db = _openDb();
      addTearDown(db.close);
      final points = PointsRepository(db);

      await points.createPointsAccount(_samplePointsAccount());
      await points.earnPoints(
        pointsTransactionId: 'ptxn_001',
        pointsAccountId: 'points:tpoint',
        pointsAmount: 100,
        jpyValue: 100,
        occurredAt: '2026-03-20',
      );
      await points.expirePoints(
        pointsTransactionId: 'ptxn_002',
        pointsAccountId: 'points:tpoint',
        pointsAmount: 20,
        occurredAt: '2026-03-21',
        description: 'Points expired',
      );

      final balance = await points.getPointsBalance('points:tpoint');
      expect(balance.totalEarned, 100);
      expect(balance.totalExpired, 20);
      expect(balance.currentBalance, 80);
    });

    test('adjusts points (positive correction)', () async {
      final db = _openDb();
      addTearDown(db.close);
      final points = PointsRepository(db);

      await points.createPointsAccount(_samplePointsAccount());
      await points.earnPoints(
        pointsTransactionId: 'ptxn_001',
        pointsAccountId: 'points:tpoint',
        pointsAmount: 100,
        jpyValue: 100,
        occurredAt: '2026-03-20',
      );
      await points.adjustPoints(
        pointsTransactionId: 'ptxn_002',
        pointsAccountId: 'points:tpoint',
        pointsAmount: 10,
        occurredAt: '2026-03-21',
        description: 'Corrected erroneous deduction',
      );

      final balance = await points.getPointsBalance('points:tpoint');
      expect(balance.totalAdjusted, 10);
      expect(balance.currentBalance, 110);
    });

    test('lists points transactions in order', () async {
      final db = _openDb();
      addTearDown(db.close);
      final points = PointsRepository(db);

      await points.createPointsAccount(_samplePointsAccount());
      await points.earnPoints(
        pointsTransactionId: 'ptxn_001',
        pointsAccountId: 'points:tpoint',
        pointsAmount: 100,
        jpyValue: 100,
        occurredAt: '2026-03-20',
      );
      await points.earnPoints(
        pointsTransactionId: 'ptxn_002',
        pointsAccountId: 'points:tpoint',
        pointsAmount: 50,
        jpyValue: 50,
        occurredAt: '2026-03-21',
      );

      final transactions = await points.listPointsTransactions('points:tpoint');
      expect(transactions.length, 2);
      expect(transactions[0].pointsTransactionId, 'ptxn_002');
      expect(transactions[1].pointsTransactionId, 'ptxn_001');
    });

    test('filters points transactions by date range', () async {
      final db = _openDb();
      addTearDown(db.close);
      final points = PointsRepository(db);

      await points.createPointsAccount(_samplePointsAccount());
      await points.earnPoints(
        pointsTransactionId: 'ptxn_001',
        pointsAccountId: 'points:tpoint',
        pointsAmount: 100,
        jpyValue: 100,
        occurredAt: '2026-03-15',
      );
      await points.earnPoints(
        pointsTransactionId: 'ptxn_002',
        pointsAccountId: 'points:tpoint',
        pointsAmount: 50,
        jpyValue: 50,
        occurredAt: '2026-03-25',
      );

      final transactions = await points.listPointsTransactions(
        'points:tpoint',
        dateFrom: '2026-03-20',
        dateTo: '2026-03-31',
      );
      expect(transactions.length, 1);
      expect(transactions.first.pointsTransactionId, 'ptxn_002');
    });

    test('gets all points balances across accounts', () async {
      final db = _openDb();
      addTearDown(db.close);
      final points = PointsRepository(db);

      await points.createPointsAccount(_samplePointsAccount(
        pointsAccountId: 'points:tpoint',
        name: 'T-Point',
      ));
      await points.createPointsAccount(_samplePointsAccount(
        pointsAccountId: 'points:rakuten',
        name: 'Rakuten',
      ));
      await points.earnPoints(
        pointsTransactionId: 'ptxn_001',
        pointsAccountId: 'points:tpoint',
        pointsAmount: 100,
        jpyValue: 100,
        occurredAt: '2026-03-20',
      );
      await points.earnPoints(
        pointsTransactionId: 'ptxn_002',
        pointsAccountId: 'points:rakuten',
        pointsAmount: 200,
        jpyValue: 200,
        occurredAt: '2026-03-20',
      );

      final balances = await points.getAllPointsBalances();
      expect(balances.length, 2);
      expect(balances['points:tpoint']!.currentBalance, 100);
      expect(balances['points:rakuten']!.currentBalance, 200);
    });

    test('calculates JPY value for points', () async {
      final db = _openDb();
      addTearDown(db.close);
      final points = PointsRepository(db);

      await points.createPointsAccount(_samplePointsAccount(
        pointsAccountId: 'points:tpoint',
        name: 'T-Point',
        exchangeRate: 1,
      ));

      final jpyValue = await points.getJpyValueForPoints(
        pointsAccountId: 'points:tpoint',
        pointsAmount: 100,
      );
      expect(jpyValue, 100);
    });

    test('returns zero balance for non-existent account', () async {
      final db = _openDb();
      addTearDown(db.close);
      final points = PointsRepository(db);

      final balance = await points.getPointsBalance('points:nonexistent');
      expect(balance.currentBalance, 0);
      expect(balance.totalEarned, 0);
    });

    test('updates points account info', () async {
      final db = _openDb();
      addTearDown(db.close);
      final points = PointsRepository(db);

      await points.createPointsAccount(_samplePointsAccount());
      await points.updatePointsAccount(
        _samplePointsAccount(
          name: 'Updated T-Point',
          exchangeRate: 2,
        ),
      );

      final account = await points.getPointsAccount('points:tpoint');
      expect(account!.name, 'Updated T-Point');
      expect(account.exchangeRate, 2);
    });
  });
}

AppDatabase _openDb() {
  return AppDatabase(
    NativeDatabase.memory(
      setup: (database) {
        database.execute('PRAGMA foreign_keys = ON;');
      },
    ),
  );
}

ChoboPointsAccountRecord _samplePointsAccount({
  String pointsAccountId = 'points:tpoint',
  String name = 'T-Point',
  String pointsCurrency = 'T',
  int exchangeRate = 1,
}) {
  return ChoboPointsAccountRecord(
    pointsAccountId: pointsAccountId,
    name: name,
    pointsCurrency: pointsCurrency,
    exchangeRate: exchangeRate,
    isDefault: false,
    isArchived: false,
    createdAt: '2026-03-20T09:00:00Z',
    updatedAt: '2026-03-20T09:00:00Z',
  );
}
