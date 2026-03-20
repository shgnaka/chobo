class BackupPayloadEnvelope {
  const BackupPayloadEnvelope({
    required this.accounts,
    required this.transactions,
    required this.entries,
    required this.periodClosures,
    required this.settings,
    required this.auditEvents,
  });

  final List<Map<String, Object?>> accounts;
  final List<Map<String, Object?>> transactions;
  final List<Map<String, Object?>> entries;
  final List<Map<String, Object?>> periodClosures;
  final List<Map<String, Object?>> settings;
  final List<Map<String, Object?>> auditEvents;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'accounts': accounts,
      'transactions': transactions,
      'entries': entries,
      'period_closures': periodClosures,
      'settings': settings,
      'audit_events': auditEvents,
    };
  }

  static BackupPayloadEnvelope fromJson(Map<String, Object?> json) {
    List<Map<String, Object?>> readList(String key) {
      final value = json[key];
      if (value is! List) {
        throw FormatException('Expected list for $key');
      }
      return value.cast<Map<String, Object?>>();
    }

    return BackupPayloadEnvelope(
      accounts: readList('accounts'),
      transactions: readList('transactions'),
      entries: readList('entries'),
      periodClosures: readList('period_closures'),
      settings: readList('settings'),
      auditEvents: readList('audit_events'),
    );
  }
}
