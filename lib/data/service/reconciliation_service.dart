import '../repository/ledger_repository.dart';
import '../../core/audit_event_factory.dart';
import 'reconciliation_dto.dart';

class ReconciliationService {
  ReconciliationService({
    required LedgerRepository ledgerRepository,
    required AuditEventFactory auditEventFactory,
    String Function()? now,
  })  : _ledgerRepository = ledgerRepository,
        _auditEventFactory = auditEventFactory,
        _now = now ?? (() => DateTime.now().toUtc().toIso8601String());

  final LedgerRepository _ledgerRepository;
  final AuditEventFactory _auditEventFactory;
  final String Function() _now;

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

    final auditEventId = _auditEventFactory.generateId();
    await _auditEventFactory.recordAccountReconciled(
      accountId: accountId,
      bookBalance: result.bookBalance,
      actualBalance: result.actualBalance,
      diff: result.difference,
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
}
