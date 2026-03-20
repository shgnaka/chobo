class BackupHeader {
  const BackupHeader({
    required this.appVersion,
    required this.schemaVersion,
    required this.createdAt,
    required this.encryptionScheme,
    required this.keyWrapScheme,
    required this.payloadFormat,
    required this.deviceId,
    this.backupVersion = 1,
  });

  final String appVersion;
  final int schemaVersion;
  final DateTime createdAt;
  final String encryptionScheme;
  final String keyWrapScheme;
  final String payloadFormat;
  final String? deviceId;
  final int backupVersion;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'backup_version': backupVersion,
      'app_version': appVersion,
      'schema_version': schemaVersion,
      'created_at': createdAt.toUtc().toIso8601String(),
      'encryption_scheme': encryptionScheme,
      'key_wrap_scheme': keyWrapScheme,
      'payload_format': payloadFormat,
      'device_id': deviceId,
    };
  }

  static BackupHeader fromJson(Map<String, Object?> json) {
    return BackupHeader(
      backupVersion: json['backup_version'] as int? ?? 1,
      appVersion: json['app_version'] as String,
      schemaVersion: json['schema_version'] as int,
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
      encryptionScheme: json['encryption_scheme'] as String,
      keyWrapScheme: json['key_wrap_scheme'] as String,
      payloadFormat: json['payload_format'] as String,
      deviceId: json['device_id'] as String?,
    );
  }
}
