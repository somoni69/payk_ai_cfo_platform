import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'app_error_reporter.dart';

const int _maxLogBytes = 1024 * 1024;

/// Appends sanitized errors to a local, size-capped log for support/diagnostics.
///
/// This is not a remote crash reporter; it keeps diagnostics on-device until a
/// company telemetry sink is configured.
Future<void> installFileErrorSink() async {
  final directory = await getApplicationSupportDirectory();
  final file = File('${directory.path}/payk-errors.log');

  AppErrorReporter.addSink((error, stackTrace, context) async {
    if (await file.exists() && await file.length() > _maxLogBytes) {
      final rotated = File('${file.path}.1');
      if (await rotated.exists()) await rotated.delete();
      await file.rename(rotated.path);
    }

    final entry = jsonEncode({
      'at': DateTime.now().toUtc().toIso8601String(),
      'context': context,
      'error': '$error',
      'stack': stackTrace.toString(),
    });
    await file.writeAsString('$entry\n', mode: FileMode.append, flush: true);
  });
}
