import '../repository/audit_event_repository.dart';
import '../repository/ledger_repository.dart';
import 'reconciliation_dto.dart';

class ReconciliationService {
  ReconciliationService({
    required LedgerRepository ledgerRepository,
    required AuditEventRepository auditEventRepository,
    String Function()? now,
    String Function()? idGenerator,
  })  : _ledgerRepository = ledgerRepository,
        _auditEventRepository = auditEventRepository,
        _now = now ?? (() => DateTime.now().toUtc().toIso8601String()),
        _idGenerator = idGenerator ?? _defaultIdGenerator;

  final LedgerRepository _ledgerRepository;
  final AuditEventRepository _auditEventRepository;
  final String Function() _now;
  final String Function() _idGenerator;

  Future<ReconciliationResultDto> compareAccountBalance({
    required String accountId,
    required int actualBalance,
    String? asOfDateInclusive,
  }) async {
    final balances = await _ledgerRepository.calculateAccountBalances(
      asOfDateInclusive: asOfDateInclusive,
    );
    final bookBalance = balances[accountId] ?? 0;
    final difference = actualBalance - bookBalance;
    return ReconciliationResultDto(
      accountId: accountId,
      bookBalance: bookBalance,
      actualBalance: actualBalance,
      difference: difference,
      reconciledAt: _now(),
    );
  }

  Future<ReconciliationResultDto> completeReconciliation({
    required String accountId,
    required int actualBalance,
    String? asOfDateInclusive,
  }) async {
    final result = await compareAccountBalance(
      accountId: accountId,
      actualBalance: actualBalance,
      asOfDateInclusive: asOfDateInclusive,
    );
    final auditEventId = _idGenerator();
    await _auditEventRepository.recordJsonEvent(
      auditEventId: auditEventId,
      eventType: 'reconciliation_completed',
      targetId: accountId,
      payload: <String, Object?>{
        'account_id': accountId,
        'book_balance': result.bookBalance,
        'actual_balance': result.actualBalance,
        'difference': result.difference,
        'as_of_date_inclusive': asOfDateInclusive,
        'reconciled_at': result.reconciledAt,
      },
      createdAt: result.reconciledAt,
    );
    return ReconciliationResultDto(
      accountId: result.accountId,
      bookBalance: result.bookBalance,
      actualBalance: result.actualBalance,
      difference: result.difference,
      reconciledAt: result.reconciledAt,
      auditEventId: auditEventId,
    );
  }

  static String _defaultIdGenerator() {
    return 'recon_${DateTime.now().microsecondsSinceEpoch}';
  }
}
