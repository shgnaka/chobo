import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_db/app_database.dart';
import '../data/local_db/chobo_records.dart';
import '../backup/aes_gcm_v1_ciphertext_codec.dart';
import '../backup/backup_header_json_codec.dart';
import '../backup/backup_payload_json_codec.dart';
import '../backup/backup_service.dart';
import '../backup/binary_backup_file_codec.dart';
import '../backup/flutter_secure_storage_backup_master_key_store.dart';
import '../backup/local_auth_backup_authorization.dart';
import '../backup/os_secure_storage_v1_key_wrap_codec.dart';
import '../data/repository/audit_event_repository.dart';
import '../data/repository/account_repository.dart';
import '../data/repository/backup_payload_repository.dart';
import '../data/repository/closure_repository.dart';
import '../data/repository/entry_repository.dart';
import '../data/repository/ledger_repository.dart';
import '../data/repository/settings_repository.dart';
import '../data/repository/transaction_repository.dart';
import '../data/service/reconciliation_service.dart';
import '../core/auth_service.dart';

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

final backupPayloadRepositoryProvider =
    Provider<BackupPayloadRepository>((ref) {
  return BackupPayloadRepository(ref.watch(appDatabaseProvider));
});

final closureRepositoryProvider = Provider<ClosureRepository>((ref) {
  return ClosureRepository(ref.watch(appDatabaseProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(appDatabaseProvider));
});

final auditEventRepositoryProvider = Provider<AuditEventRepository>((ref) {
  return AuditEventRepository(ref.watch(appDatabaseProvider));
});

final entryRepositoryProvider = Provider<EntryRepository>((ref) {
  return EntryRepository(ref.watch(appDatabaseProvider));
});

final ledgerRepositoryProvider = Provider<LedgerRepository>((ref) {
  return LedgerRepository(ref.watch(appDatabaseProvider));
});

final reconciliationServiceProvider = Provider<ReconciliationService>((ref) {
  return ReconciliationService(
    ledgerRepository: ref.watch(ledgerRepositoryProvider),
    auditEventRepository: ref.watch(auditEventRepositoryProvider),
  );
});

final backupMasterKeyStoreProvider =
    Provider<FlutterSecureStorageBackupMasterKeyStore>((ref) {
  return FlutterSecureStorageBackupMasterKeyStore();
});

final backupAuthorizationProvider =
    Provider<LocalAuthBackupAuthorization>((ref) {
  return LocalAuthBackupAuthorization();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final backupServiceProvider = Provider<BackupService>((ref) {
  final masterKeyStore = ref.watch(backupMasterKeyStoreProvider);
  final authService = ref.watch(authServiceProvider);
  return BackupService(
    payloadRepository: ref.watch(backupPayloadRepositoryProvider),
    loadMasterKey: masterKeyStore.load,
    requireAdditionalAuth: authService.requireAuthentication,
    fileCodec: BinaryBackupFileCodec(),
    headerCodec: const BackupHeaderJsonCodec(),
    keyWrapCodec: const OsSecureStorageV1KeyWrapCodec(),
    ciphertextCodec: const AesGcmV1CiphertextCodec(),
    payloadCodec: const BackupPayloadJsonCodec(),
  );
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
