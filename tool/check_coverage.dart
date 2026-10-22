import 'dart:io';

/// Fails the build when line coverage drops below the current baseline.
///
/// Usage: dart tool/check_coverage.dart [lcovPath] [minimumPercent]
void main(List<String> args) {
  final lcovPath = args.isNotEmpty ? args[0] : 'coverage/lcov.info';
  final minimum = args.length > 1 ? double.parse(args[1]) : 28.5;

  final file = File(lcovPath);
  if (!file.existsSync()) {
    stderr.writeln('Coverage file not found: $lcovPath');
    exit(2);
  }

  var found = 0;
  var hit = 0;
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('LF:')) {
      found += int.tryParse(line.substring(3)) ?? 0;
    } else if (line.startsWith('LH:')) {
      hit += int.tryParse(line.substring(3)) ?? 0;
    }
  }

  if (found == 0) {
    stderr.writeln('Coverage file contains no line records: $lcovPath');
    exit(2);
  }

  final percent = hit * 100 / found;
  stdout.writeln(
    'Line coverage: $hit/$found (${percent.toStringAsFixed(2)}%), '
    'minimum ${minimum.toStringAsFixed(2)}%.',
  );
  if (percent < minimum) {
    stderr.writeln('Coverage regression: below the configured baseline.');
    exit(1);
  }
}
