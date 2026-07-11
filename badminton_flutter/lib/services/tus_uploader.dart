import '../models/upload_task.dart';

/// The queue's view of a tus client. Wrapping the `tusc` package behind
/// this interface keeps the provider fully unit-testable (FakeTusUploader)
/// and the package swappable.
abstract class TusUploader {
  /// Starts or resumes [task]'s transfer.
  ///
  /// [onTusUrl] fires once the server-side upload exists (the URL later
  /// PATCHes/HEAD-probes resume against); [onProgress] fires with the total
  /// bytes confirmed by the server so far. The future completes when the
  /// last byte is acknowledged and throws on any unrecoverable failure.
  Future<void> upload(
    UploadTask task, {
    required void Function(int sentBytes) onProgress,
    required void Function(String tusUrl) onTusUrl,
  });

  /// Stops the in-flight transfer without discarding server state — a later
  /// [upload] resumes from the server's confirmed offset.
  Future<void> pause();
}
