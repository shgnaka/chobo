import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_db/app_database.dart';
import '../data/local_db/chobo_records.dart';
import '../data/repository/account_repository.dart';
import '../data/repository/entry_repository.dart';
import '../data/repository/ledger_repository.dart';
import '../data/repository/transaction_repository.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(ref.watch(appDatabaseProvider));
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(appDatabaseProvider));
});

final entryRepositoryProvider = Provider<EntryRepository>((ref) {
  return EntryRepository(ref.watch(appDatabaseProvider));
});

final ledgerRepositoryProvider = Provider<LedgerRepository>((ref) {
  return LedgerRepository(ref.watch(appDatabaseProvider));
});

final accountsProvider = FutureProvider<List<ChoboAccountRecord>>((ref) async {
  return ref.watch(accountRepositoryProvider).listAccounts();
});

final transactionsProvider =
    FutureProvider<List<ChoboTransactionRecord>>((ref) async {
  return ref.watch(transactionRepositoryProvider).listTransactions();
});

final transactionProvider =
    FutureProvider.family<ChoboTransactionRecord?, String>(
        (ref, transactionId) async {
  return ref.watch(transactionRepositoryProvider).getTransaction(transactionId);
});

final voidDecisionProvider =
    FutureProvider.family<VoidTransactionDecision, String>(
        (ref, transactionId) async {
  return ref
      .watch(transactionRepositoryProvider)
      .canVoidTransaction(transactionId);
});

final transactionSaveDecisionProvider =
    FutureProvider.family<TransactionSaveDecision, String>(
        (ref, transactionId) async {
  return ref
      .watch(transactionRepositoryProvider)
      .canUpdateTransaction(transactionId);
});

final transactionEntriesProvider =
    FutureProvider.family<List<ChoboEntryRecord>, String>(
        (ref, transactionId) async {
  return ref.watch(entryRepositoryProvider).listEntriesForTransaction(
        transactionId,
      );
});
