import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_db/app_database.dart';
import '../data/local_db/chobo_records.dart';
import '../data/local_db/database_manager.dart';
import '../backup/aes_gcm_v1_ciphertext_codec.dart';
import '../backup/auto_backup_manager.dart';
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
import '../data/repository/points_repository.dart';
import '../data/repository/counterparty_repository.dart';
import '../data/repository/recurring_template_repository.dart';
import '../data/repository/settings_repository.dart';
import '../data/repository/tag_repository.dart';
import '../data/repository/transaction_repository.dart';
import '../data/repository/budget_repository.dart';
import '../data/repository/budget_alert_repository.dart';
import '../data/service/reconciliation_service.dart';
import '../data/service/monthly_summary_service.dart';
import '../data/service/points_calculation_service.dart';
import '../data/service/budget_service.dart';
import '../data/service/forecast_service.dart';
import '../data/service/budget_alert_service.dart';
import '../data/service/notification_service.dart';
import '../core/auth_service.dart';
import '../core/audit_event_factory.dart';

export '../core/terminology_service.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return ref.watch(databaseManagerProvider);
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(
    ref.watch(appDatabaseProvider),
    auditEventFactory: ref.watch(auditEventFactoryProvider),
  );
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final monthlySummaryService = ref.watch(monthlySummaryServiceProvider);
  return TransactionRepository(
    ref.watch(appDatabaseProvider),
    auditEventFactory: ref.watch(auditEventFactoryProvider),
    onCacheInvalidation: (date) {
      monthlySummaryService.invalidateCache(affectedDate: date);
    },
  );
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
    auditEventFactory: ref.watch(auditEventFactoryProvider),
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
  final databaseManager = ref.read(databaseManagerProvider.notifier);
  return BackupService(
    payloadRepository: ref.watch(backupPayloadRepositoryProvider),
    loadMasterKey: masterKeyStore.load,
    requireAdditionalAuth: authService.requireAuthentication,
    fileCodec: BinaryBackupFileCodec(),
    headerCodec: const BackupHeaderJsonCodec(),
    keyWrapCodec: const OsSecureStorageV1KeyWrapCodec(),
    ciphertextCodec: const AesGcmV1CiphertextCodec(),
    payloadCodec: const BackupPayloadJsonCodec(),
    databaseManager: databaseManager,
    auditEventFactory: ref.watch(auditEventFactoryProvider),
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

final autoBackupManagerProvider = Provider<AutoBackupManager>((ref) {
  final backupService = ref.watch(backupServiceProvider);
  return AutoBackupManager(backupService: backupService);
});

final monthlySummaryServiceProvider = Provider<MonthlySummaryService>((ref) {
  return MonthlySummaryService(ref.watch(ledgerRepositoryProvider));
});

final auditEventFactoryProvider = Provider<AuditEventFactory>((ref) {
  return AuditEventFactory(ref.watch(auditEventRepositoryProvider));
});

final pointsRepositoryProvider = Provider<PointsRepository>((ref) {
  return PointsRepository(ref.watch(appDatabaseProvider));
});

final recurringTemplateRepositoryProvider =
    Provider<RecurringTemplateRepository>((ref) {
  return RecurringTemplateRepository(ref.watch(appDatabaseProvider));
});

final tagRepositoryProvider = Provider<TagRepository>((ref) {
  return TagRepository(ref.watch(appDatabaseProvider));
});

final counterpartyRepositoryProvider = Provider<CounterpartyRepository>((ref) {
  return CounterpartyRepository(ref.watch(appDatabaseProvider));
});

final tagsProvider = FutureProvider<List<ChoboTagRecord>>((ref) async {
  return ref.watch(tagRepositoryProvider).listTags();
});

final pointsCalculationServiceProvider =
    Provider<PointsCalculationService>((ref) {
  return PointsCalculationService(ref.watch(pointsRepositoryProvider));
});

final pointsAccountsProvider =
    FutureProvider<List<ChoboPointsAccountRecord>>((ref) async {
  return ref.watch(pointsRepositoryProvider).listPointsAccounts();
});

final recurringTemplatesProvider =
    FutureProvider<List<ChoboRecurringTemplateRecord>>((ref) async {
  return ref.watch(recurringTemplateRepositoryProvider).listTemplates();
});

final pointsBalanceProvider =
    FutureProvider.family<ChoboPointsBalanceRecord, String>(
        (ref, pointsAccountId) async {
  return ref.watch(pointsRepositoryProvider).getPointsBalance(pointsAccountId);
});

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(appDatabaseProvider));
});

final budgetAlertRepositoryProvider = Provider<BudgetAlertRepository>((ref) {
  return BudgetAlertRepository(ref.watch(appDatabaseProvider));
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final budgetServiceProvider = Provider<BudgetService>((ref) {
  return BudgetService(
    ref.watch(budgetRepositoryProvider),
    ref.watch(accountRepositoryProvider),
    ref.watch(appDatabaseProvider),
  );
});

final forecastServiceProvider = Provider<ForecastService>((ref) {
  return ForecastService(
    ref.watch(appDatabaseProvider),
    ref.watch(recurringTemplateRepositoryProvider),
  );
});

final budgetAlertServiceProvider = Provider<BudgetAlertService>((ref) {
  return BudgetAlertService(
    ref.watch(budgetAlertRepositoryProvider),
    ref.watch(budgetRepositoryProvider),
    ref.watch(budgetServiceProvider),
    ref.watch(notificationServiceProvider),
  );
});

final monthlyBudgetProvider =
    FutureProvider.family<MonthlyBudgetDto, String>((ref, month) async {
  return ref.watch(budgetServiceProvider).getMonthlyBudget(month);
});

final budgetComparisonsProvider =
    FutureProvider.family<List<BudgetComparisonDto>, String>(
        (ref, month) async {
  return ref.watch(budgetServiceProvider).getBudgetComparisons(month);
});

final endOfMonthForecastProvider =
    FutureProvider.family<EndOfMonthForecastDto, String>((ref, month) async {
  return ref.watch(forecastServiceProvider).getEndOfMonthForecast(month);
});

final recentBudgetAlertsProvider =
    FutureProvider<List<ChoboBudgetAlertRecord>>((ref) async {
  return ref.watch(budgetAlertServiceProvider).getRecentAlerts();
});
