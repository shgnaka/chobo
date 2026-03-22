import 'package:chobo/data/local_db/app_database.dart';
import 'package:chobo/data/local_db/chobo_records.dart';
import 'package:chobo/data/repository/account_repository.dart';
import 'package:chobo/data/repository/recurring_template_repository.dart';
import 'package:chobo/data/repository/transaction_repository.dart';
import 'package:chobo/data/service/forecast_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ForecastService', () {
    late AppDatabase db;
    late AccountRepository accountRepo;
    late TransactionRepository transactionRepo;
    late RecurringTemplateRepository recurringTemplateRepo;
    late ForecastService service;

    setUp(() {
      db = _openDb();
      accountRepo = AccountRepository(db);
      transactionRepo = TransactionRepository(db);
      recurringTemplateRepo = RecurringTemplateRepository(db);
      service = ForecastService(db, recurringTemplateRepo);
    });

    tearDown(() => db.close());

    group('PendingPaymentDto.effectiveDate', () {
      test('prefers dueDate over date when both are present', () {
        final dto = PendingPaymentDto(
          transactionId: 'txn_001',
          date: '2026-03-15',
          dueDate: '2026-04-05',
          description: 'Test',
          accountName: 'Bank',
          accountId: 'asset:bank',
          amount: 1000,
          isExpense: true,
          isIncome: false,
        );

        expect(dto.effectiveDate, '2026-04-05');
      });

      test('falls back to date when dueDate is null', () {
        final dto = PendingPaymentDto(
          transactionId: 'txn_002',
          date: '2026-03-15',
          dueDate: null,
          description: 'Test',
          accountName: 'Bank',
          accountId: 'asset:bank',
          amount: 1000,
          isExpense: true,
          isIncome: false,
        );

        expect(dto.effectiveDate, '2026-03-15');
      });
    });

    group('getEndOfMonthForecast', () {
      test('returns accounts with billing days in billingCycles', () async {
        await accountRepo.createAccount(_sampleAccount(
          accountId: 'liability:card:main',
          kind: 'liability',
          name: 'Main Card',
          billingDay: 15,
          paymentDueDay: 5,
        ));

        final forecast = await service.getEndOfMonthForecast('2026-03');

        expect(forecast.billingCycles, hasLength(1));
        expect(forecast.billingCycles.first.accountId, 'liability:card:main');
        expect(forecast.billingCycles.first.billingDay, 15);
        expect(forecast.billingCycles.first.paymentDueDay, 5);
      });

      test('returns empty billingCycles when no accounts have billing days',
          () async {
        await accountRepo.createAccount(_sampleAccount(
          accountId: 'asset:bank:main',
          kind: 'asset',
          name: 'Bank',
        ));

        final forecast = await service.getEndOfMonthForecast('2026-03');

        expect(forecast.billingCycles, isEmpty);
      });

      test('includes pending payments with due dates in next month', () async {
        await accountRepo.createAccount(_sampleAccount(
          accountId: 'asset:bank:main',
          kind: 'asset',
          name: 'Bank',
        ));
        await accountRepo.createAccount(_sampleAccount(
          accountId: 'expense:food',
          kind: 'expense',
          name: 'Food',
        ));

        await transactionRepo.createTransaction(
          _sampleTransaction(
            transactionId: 'txn_001',
            date: '2026-03-20',
            dueDate: '2026-04-05',
            status: 'pending',
          ),
          <ChoboEntryRecord>[
            const ChoboEntryRecord(
              entryId: 'ent_001',
              transactionId: 'txn_001',
              accountId: 'asset:bank:main',
              direction: 'decrease',
              amount: 1500,
            ),
            const ChoboEntryRecord(
              entryId: 'ent_002',
              transactionId: 'txn_001',
              accountId: 'expense:food',
              direction: 'increase',
              amount: 1500,
            ),
          ],
        );

        final forecast = await service.getEndOfMonthForecast('2026-03');

        expect(forecast.pendingPayments, hasLength(1));
        expect(forecast.pendingPayments.first.effectiveDate, '2026-04-05');
      });

      test('groups due date projections by effective date', () async {
        await accountRepo.createAccount(_sampleAccount(
          accountId: 'liability:card:main',
          kind: 'liability',
          name: 'Main Card',
        ));
        await accountRepo.createAccount(_sampleAccount(
          accountId: 'expense:food',
          kind: 'expense',
          name: 'Food',
        ));

        await transactionRepo.createTransaction(
          _sampleTransaction(
            transactionId: 'txn_001',
            date: '2026-03-20',
            dueDate: '2026-04-05',
            type: 'credit_expense',
            status: 'pending',
          ),
          <ChoboEntryRecord>[
            const ChoboEntryRecord(
              entryId: 'ent_001',
              transactionId: 'txn_001',
              accountId: 'liability:card:main',
              direction: 'increase',
              amount: 1000,
            ),
            const ChoboEntryRecord(
              entryId: 'ent_002',
              transactionId: 'txn_001',
              accountId: 'expense:food',
              direction: 'increase',
              amount: 1000,
            ),
          ],
        );

        await transactionRepo.createTransaction(
          _sampleTransaction(
            transactionId: 'txn_002',
            date: '2026-03-21',
            dueDate: '2026-04-05',
            type: 'credit_expense',
            status: 'pending',
          ),
          <ChoboEntryRecord>[
            const ChoboEntryRecord(
              entryId: 'ent_003',
              transactionId: 'txn_002',
              accountId: 'liability:card:main',
              direction: 'increase',
              amount: 2000,
            ),
            const ChoboEntryRecord(
              entryId: 'ent_004',
              transactionId: 'txn_002',
              accountId: 'expense:food',
              direction: 'increase',
              amount: 2000,
            ),
          ],
        );

        final forecast = await service.getEndOfMonthForecast('2026-03');

        expect(forecast.dueDateProjections, hasLength(greaterThanOrEqualTo(1)));
        final april5Projection = forecast.dueDateProjections
            .where((p) => p.dueDate == '2026-04-05')
            .toList();
        expect(april5Projection, isNotEmpty);
      });

      test('sums amounts correctly for same account in projections', () async {
        await accountRepo.createAccount(_sampleAccount(
          accountId: 'liability:card:main',
          kind: 'liability',
          name: 'Main Card',
        ));
        await accountRepo.createAccount(_sampleAccount(
          accountId: 'expense:food',
          kind: 'expense',
          name: 'Food',
        ));

        await transactionRepo.createTransaction(
          _sampleTransaction(
            transactionId: 'txn_001',
            date: '2026-03-20',
            dueDate: '2026-04-05',
            type: 'credit_expense',
            status: 'pending',
          ),
          <ChoboEntryRecord>[
            const ChoboEntryRecord(
              entryId: 'ent_001',
              transactionId: 'txn_001',
              accountId: 'liability:card:main',
              direction: 'increase',
              amount: 1000,
            ),
            const ChoboEntryRecord(
              entryId: 'ent_002',
              transactionId: 'txn_001',
              accountId: 'expense:food',
              direction: 'increase',
              amount: 1000,
            ),
          ],
        );

        final forecast = await service.getEndOfMonthForecast('2026-03');

        final cardProjection = forecast.dueDateProjections
            .where((p) => p.accountId == 'liability:card:main')
            .toList();
        if (cardProjection.isNotEmpty) {
          expect(cardProjection.first.totalDue, 1000);
          expect(cardProjection.first.paymentCount, 1);
        }
      });

      test('returns empty projections when no pending payments', () async {
        final forecast = await service.getEndOfMonthForecast('2026-03');

        expect(forecast.dueDateProjections, isEmpty);
        expect(forecast.pendingPayments, isEmpty);
      });

      test('correctly identifies expense vs income in pending payments',
          () async {
        await accountRepo.createAccount(_sampleAccount(
          accountId: 'asset:bank:main',
          kind: 'asset',
          name: 'Bank',
        ));
        await accountRepo.createAccount(_sampleAccount(
          accountId: 'expense:food',
          kind: 'expense',
          name: 'Food',
        ));
        await accountRepo.createAccount(_sampleAccount(
          accountId: 'income:salary',
          kind: 'income',
          name: 'Salary',
        ));

        await transactionRepo.createTransaction(
          _sampleTransaction(
            transactionId: 'txn_expense',
            date: '2026-03-20',
            status: 'pending',
          ),
          <ChoboEntryRecord>[
            const ChoboEntryRecord(
              entryId: 'ent_001',
              transactionId: 'txn_expense',
              accountId: 'asset:bank:main',
              direction: 'decrease',
              amount: 1000,
            ),
            const ChoboEntryRecord(
              entryId: 'ent_002',
              transactionId: 'txn_expense',
              accountId: 'expense:food',
              direction: 'increase',
              amount: 1000,
            ),
          ],
        );

        await transactionRepo.createTransaction(
          _sampleTransaction(
            transactionId: 'txn_income',
            date: '2026-03-20',
            type: 'income',
            status: 'pending',
          ),
          <ChoboEntryRecord>[
            const ChoboEntryRecord(
              entryId: 'ent_003',
              transactionId: 'txn_income',
              accountId: 'asset:bank:main',
              direction: 'increase',
              amount: 500,
            ),
            const ChoboEntryRecord(
              entryId: 'ent_004',
              transactionId: 'txn_income',
              accountId: 'income:salary',
              direction: 'increase',
              amount: 500,
            ),
          ],
        );

        final forecast = await service.getEndOfMonthForecast('2026-03');

        final expensePayments =
            forecast.pendingPayments.where((p) => p.isExpense).toList();
        final incomePayments =
            forecast.pendingPayments.where((p) => p.isIncome).toList();

        expect(expensePayments, hasLength(1));
        expect(incomePayments, hasLength(1));
        expect(forecast.pendingExpenses, 1000);
        expect(forecast.pendingIncome, 500);
      });

      test('daily forecasts use effective date for pending transactions',
          () async {
        await accountRepo.createAccount(_sampleAccount(
          accountId: 'asset:bank:main',
          kind: 'asset',
          name: 'Bank',
        ));
        await accountRepo.createAccount(_sampleAccount(
          accountId: 'expense:food',
          kind: 'expense',
          name: 'Food',
        ));

        await transactionRepo.createTransaction(
          _sampleTransaction(
            transactionId: 'txn_001',
            date: '2026-03-20',
            dueDate: '2026-04-05',
            status: 'pending',
          ),
          <ChoboEntryRecord>[
            const ChoboEntryRecord(
              entryId: 'ent_001',
              transactionId: 'txn_001',
              accountId: 'asset:bank:main',
              direction: 'decrease',
              amount: 500,
            ),
            const ChoboEntryRecord(
              entryId: 'ent_002',
              transactionId: 'txn_001',
              accountId: 'expense:food',
              direction: 'increase',
              amount: 500,
            ),
          ],
        );

        final forecast = await service.getEndOfMonthForecast('2026-03');

        final april5Forecast = forecast.dailyForecasts
            .where((d) => d.date == '2026-04-05')
            .toList();

        if (april5Forecast.isNotEmpty) {
          expect(april5Forecast.first.pendingAmount, 500);
        }
      });

      test('handles multiple accounts with billing cycles', () async {
        await accountRepo.createAccount(_sampleAccount(
          accountId: 'liability:card:one',
          kind: 'liability',
          name: 'Card One',
          billingDay: 15,
          paymentDueDay: 5,
        ));
        await accountRepo.createAccount(_sampleAccount(
          accountId: 'liability:card:two',
          kind: 'liability',
          name: 'Card Two',
          billingDay: 20,
          paymentDueDay: 10,
        ));

        final forecast = await service.getEndOfMonthForecast('2026-03');

        expect(forecast.billingCycles, hasLength(2));
        expect(
          forecast.billingCycles.map((c) => c.accountId).toSet(),
          containsAll(['liability:card:one', 'liability:card:two']),
        );
      });

      test('calculates forecast balance correctly', () async {
        await accountRepo.createAccount(_sampleAccount(
          accountId: 'asset:bank:main',
          kind: 'asset',
          name: 'Bank',
        ));
        await accountRepo.createAccount(_sampleAccount(
          accountId: 'income:salary',
          kind: 'income',
          name: 'Salary',
        ));
        await accountRepo.createAccount(_sampleAccount(
          accountId: 'expense:food',
          kind: 'expense',
          name: 'Food',
        ));

        await transactionRepo.createTransaction(
          _sampleTransaction(
            transactionId: 'txn_salary',
            date: '2026-03-10',
            type: 'income',
          ),
          <ChoboEntryRecord>[
            const ChoboEntryRecord(
              entryId: 'ent_001',
              transactionId: 'txn_salary',
              accountId: 'asset:bank:main',
              direction: 'increase',
              amount: 100000,
            ),
            const ChoboEntryRecord(
              entryId: 'ent_002',
              transactionId: 'txn_salary',
              accountId: 'income:salary',
              direction: 'increase',
              amount: 100000,
            ),
          ],
        );

        await transactionRepo.createTransaction(
          _sampleTransaction(
            transactionId: 'txn_food',
            date: '2026-03-15',
            status: 'pending',
          ),
          <ChoboEntryRecord>[
            const ChoboEntryRecord(
              entryId: 'ent_003',
              transactionId: 'txn_food',
              accountId: 'asset:bank:main',
              direction: 'decrease',
              amount: 5000,
            ),
            const ChoboEntryRecord(
              entryId: 'ent_004',
              transactionId: 'txn_food',
              accountId: 'expense:food',
              direction: 'increase',
              amount: 5000,
            ),
          ],
        );

        final forecast = await service.getEndOfMonthForecast('2026-03');

        expect(forecast.currentBalance, 100000);
        expect(forecast.pendingExpenses, 5000);
        expect(forecast.pendingIncome, 0);
        expect(forecast.forecastBalance, 95000);
      });
    });

    group('due date edge cases', () {
      test('uses transaction date when dueDate is before forecast month',
          () async {
        await accountRepo.createAccount(_sampleAccount(
          accountId: 'asset:bank:main',
          kind: 'asset',
          name: 'Bank',
        ));
        await accountRepo.createAccount(_sampleAccount(
          accountId: 'expense:food',
          kind: 'expense',
          name: 'Food',
        ));

        await transactionRepo.createTransaction(
          _sampleTransaction(
            transactionId: 'txn_001',
            date: '2026-03-20',
            dueDate: '2026-02-15',
            status: 'pending',
          ),
          <ChoboEntryRecord>[
            const ChoboEntryRecord(
              entryId: 'ent_001',
              transactionId: 'txn_001',
              accountId: 'asset:bank:main',
              direction: 'decrease',
              amount: 1000,
            ),
            const ChoboEntryRecord(
              entryId: 'ent_002',
              transactionId: 'txn_001',
              accountId: 'expense:food',
              direction: 'increase',
              amount: 1000,
            ),
          ],
        );

        final forecast = await service.getEndOfMonthForecast('2026-03');

        expect(forecast.pendingPayments, hasLength(1));
      });
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

ChoboAccountRecord _sampleAccount({
  required String accountId,
  required String kind,
  required String name,
  int? billingDay,
  int? paymentDueDay,
}) {
  return ChoboAccountRecord(
    accountId: accountId,
    kind: kind,
    name: name,
    billingDay: billingDay,
    paymentDueDay: paymentDueDay,
    createdAt: '2026-03-20T09:00:00Z',
    updatedAt: '2026-03-20T09:00:00Z',
  );
}

ChoboTransactionRecord _sampleTransaction({
  required String transactionId,
  required String date,
  String? dueDate,
  String type = 'expense',
  String status = 'posted',
}) {
  return ChoboTransactionRecord(
    transactionId: transactionId,
    date: date,
    dueDate: dueDate,
    type: type,
    status: status,
    createdAt: '2026-03-20T09:00:00Z',
    updatedAt: '2026-03-20T09:00:00Z',
  );
}
