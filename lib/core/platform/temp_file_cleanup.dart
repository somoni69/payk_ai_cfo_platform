import 'dart:async';
import 'dart:io';

/// Removes a shared temp file after the receiving app has had time to read it.
void scheduleTempFileDeletion(
  File file, {
  Duration delay = const Duration(minutes: 5),
}) {
  unawaited(
    Future<void>.delayed(delay, () async {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {
        // The OS temp directory is cleared eventually.
      }
    }),
  );
}
