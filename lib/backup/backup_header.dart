class BackupHeader {
  const BackupHeader({
    required this.appVersion,
    required this.schemaVersion,
    required this.createdAt,
    required this.encryptionScheme,
    required this.keyWrapScheme,
    required this.payloadFormat,
    required this.deviceId,
  });

  final String appVersion;
  final int schemaVersion;
  final DateTime createdAt;
  final String encryptionScheme;
  final String keyWrapScheme;
  final String payloadFormat;
  final String? deviceId;

  Map<String, Object?> toJson() {
    return <String, Object?>{
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
