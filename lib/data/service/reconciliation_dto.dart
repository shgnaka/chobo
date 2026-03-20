class ReconciliationResultDto {
  const ReconciliationResultDto({
    required this.accountId,
    required this.bookBalance,
    required this.actualBalance,
    required this.difference,
    required this.reconciledAt,
    this.auditEventId,
  });

  final String accountId;
  final int bookBalance;
  final int actualBalance;
  final int difference;
  final String reconciledAt;
  final String? auditEventId;

  bool get isBalanced => difference == 0;
}
