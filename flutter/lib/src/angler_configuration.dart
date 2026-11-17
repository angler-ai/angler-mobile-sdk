/// Configuration for [Angler.configure]. Fields left null use the native defaults.
class AnglerConfiguration {
  const AnglerConfiguration({
    required this.workspaceId,
    required this.token,
    this.domain,
    this.clientId,
    this.trackLifecycleEvents,
    this.flushAt,
    this.flushIntervalSeconds,
    this.maxQueueSize,
    this.debugLogging,
  });

  final String workspaceId;

  /// The workspace JWT.
  final String token;

  /// `data.getangler.ai` (default) or `dev-data.getangler.ai`.
  final String? domain;

  /// Overrides `client_id`. Defaults to the install ID.
  final String? clientId;
  final bool? trackLifecycleEvents;

  /// Number of queued events that triggers a flush (default 20).
  final int? flushAt;

  /// Seconds between periodic flushes (default 30).
  final int? flushIntervalSeconds;

  /// When full, the oldest event is dropped (default 1000).
  final int? maxQueueSize;
  final bool? debugLogging;

  /// The channel arguments: null fields are left out, and `wrapper` is `flutter`.
  Map<String, Object?> toMap() {
    final map = <String, Object?>{
      'workspaceId': workspaceId,
      'token': token,
      'domain': domain,
      'clientId': clientId,
      'trackLifecycleEvents': trackLifecycleEvents,
      'flushAt': flushAt,
      'flushIntervalSeconds': flushIntervalSeconds,
      'maxQueueSize': maxQueueSize,
      'debugLogging': debugLogging,
    }..removeWhere((_, v) => v == null);
    map['wrapper'] = 'flutter';
    return map;
  }
}
