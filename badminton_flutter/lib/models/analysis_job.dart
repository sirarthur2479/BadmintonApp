/// A server-side analysis job as returned by `GET /jobs?sessionId=...`.
/// `sessionId` is the phone's own local session id echoed back — that's the
/// correlation key that attaches the finished report to the right session.
enum AnalysisJobStatus { queued, analyzing, done, failed }

class AnalysisJob {
  final String id;
  final String sessionId;
  final String mode;
  final AnalysisJobStatus status;
  final String? errorMessage;

  const AnalysisJob({
    required this.id,
    required this.sessionId,
    required this.mode,
    required this.status,
    this.errorMessage,
  });

  bool get isTerminal =>
      status == AnalysisJobStatus.done || status == AnalysisJobStatus.failed;

  factory AnalysisJob.fromJson(Map<String, dynamic> json) => AnalysisJob(
        id: json['id'] as String,
        sessionId: json['sessionId'] as String,
        mode: json['mode'] as String,
        // An unknown status from a newer server shows as failed rather than
        // crashing the poller.
        status: AnalysisJobStatus.values.asNameMap()[json['status']] ??
            AnalysisJobStatus.failed,
        errorMessage: json['errorMessage'] as String?,
      );
}
