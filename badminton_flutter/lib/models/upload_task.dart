/// One queued video upload (mobile-only). `sessionId` is the LOCAL sqflite
/// session id — the server treats it as an opaque correlation key and hands
/// it back on the analysis job, which is how the report finds its way to
/// the right session.
enum UploadStatus { pending, uploading, paused, done, failed }

class UploadTask {
  final String id;
  final String sessionId;
  final String playerId; // server-side player (from AnalysisServerSettings)
  final String mode; // 'footwork' | 'biomech' | 'full'
  final String filePath;
  final int totalBytes;
  final int sentBytes;
  final UploadStatus status;

  /// The server upload URL once created — tus resumes against this.
  final String? tusUrl;
  final String? error;

  const UploadTask({
    required this.id,
    required this.sessionId,
    required this.playerId,
    required this.mode,
    required this.filePath,
    required this.totalBytes,
    this.sentBytes = 0,
    this.status = UploadStatus.pending,
    this.tusUrl,
    this.error,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'sessionId': sessionId,
        'playerId': playerId,
        'mode': mode,
        'filePath': filePath,
        'totalBytes': totalBytes,
        'sentBytes': sentBytes,
        'status': status.name,
        'tusUrl': tusUrl,
        'error': error,
      };

  factory UploadTask.fromMap(Map<String, dynamic> map) => UploadTask(
        id: map['id'] as String,
        sessionId: map['sessionId'] as String,
        playerId: map['playerId'] as String,
        mode: map['mode'] as String,
        filePath: map['filePath'] as String,
        totalBytes: map['totalBytes'] as int,
        sentBytes: (map['sentBytes'] as int?) ?? 0,
        // A status written by a future app version must not brick the queue.
        status: UploadStatus.values.asNameMap()[map['status']] ??
            UploadStatus.failed,
        tusUrl: map['tusUrl'] as String?,
        error: map['error'] as String?,
      );

  UploadTask copyWith({
    int? sentBytes,
    UploadStatus? status,
    String? tusUrl,
    String? error,
  }) =>
      UploadTask(
        id: id,
        sessionId: sessionId,
        playerId: playerId,
        mode: mode,
        filePath: filePath,
        totalBytes: totalBytes,
        sentBytes: sentBytes ?? this.sentBytes,
        status: status ?? this.status,
        tusUrl: tusUrl ?? this.tusUrl,
        error: error ?? this.error,
      );
}
