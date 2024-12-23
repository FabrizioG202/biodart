import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
  final i = (log(bytes) / log(1024)).floor();
  return '${(bytes / pow(1024, i)).toStringAsFixed(2)} ${suffixes[i]}';
}

String _formatDuration(Duration d) {
  final micros = d.inMicroseconds;
  if (micros < 1000) return '$micros µs';
  if (micros < 1000000) return '${(micros / 1000).toStringAsFixed(2)} ms';
  return '${(micros / 1000000).toStringAsFixed(2)} s';
}

Future<File?> pullFile(
  String url,
  Directory destinationFolder, {
  String? destinationFileName,
  bool skipIfExists = true,
  Logger? logger,
}) async {
  final client = http.Client();
  try {
    final uri = Uri.parse(url);
    final filename = destinationFileName ?? path.basename(uri.path);
    final savePath = path.join(destinationFolder.path, filename);

    if (!destinationFolder.existsSync()) {
      await destinationFolder.create(recursive: true);
    }

    if (skipIfExists && File(savePath).existsSync()) {
      logger?.info('File already exists at $savePath');
      return File(savePath);
    }

    logger?.info('Downloading $url to $savePath');

    final request = await client.send(http.Request('GET', uri));
    if (request.statusCode != 200) {
      logger?.severe('Download failed with status ${request.statusCode}');
      return null;
    }

    final file = File(savePath);
    final sink = file.openWrite();
    final totalBytes = request.contentLength ?? 0;
    var downloadedBytes = 0;
    var lastLogTime = DateTime.now();

    await for (final chunk in request.stream) {
      sink.add(chunk);
      downloadedBytes += chunk.length;

      // Log progress every second
      final now = DateTime.now();
      if (now.difference(lastLogTime).inSeconds >= 1) {
        final progress = totalBytes > 0 ? '${(downloadedBytes / totalBytes * 100).toStringAsFixed(1)}%' : '';
        logger?.info('Downloaded ${_formatBytes(downloadedBytes)} $progress');
        lastLogTime = now;
      }
    }

    await sink.close();
    logger?.info('Download completed successfully');
    return file;
  } catch (e) {
    logger?.severe('Error downloading file: $e');
    return null;
  } finally {
    client.close();
  }
}

/// Runs a synchronous operation [n] times and measures execution time.
/// [setupAll] runs once before all iterations
/// [setup] runs before each iteration
/// [cleanup] runs after each iteration
List<Duration> benchmark(
  void Function() operation,
  int n, {
  void Function()? setupAll,
  void Function()? setup,
  void Function()? cleanup,
  void Function()? cleanupAll,
}) {
  final times = <Duration>[];

  setupAll?.call();
  final stopwatch = Stopwatch();
  for (var i = 0; i < n; i++) {
    setup?.call();
    stopwatch.start();
    operation();

    stopwatch.stop();
    times.add(stopwatch.elapsed);
    stopwatch.reset();
    cleanup?.call();
  }

  cleanupAll?.call();

  return times;
}

/// Calculates and prints statistical information about a list of [Duration] measurements.
///
/// This function computes the average, minimum, and maximum values from the provided
/// list of durations and outputs them using the optional [logger].
///
/// Parameters:
/// - [durations]: A list of [Duration] objects to analyze
/// - [logger]: Optional logger instance to output the results. If null, no output is produced
///
/// The function will return immediately if the [durations] list is empty.
///
/// Example:
/// ```dart
/// final measurements = [Duration(milliseconds: 100), Duration(milliseconds: 200)];
/// printDurationStats(measurements, logger: myLogger);
/// ```
///
/// The output format for each duration is handled by an internal formatting function.
void printDurationStats(List<Duration> durations, {Logger? logger}) {
  if (durations.isEmpty) return;

  final avg = durations.reduce((a, b) => a + b) ~/ durations.length;
  final min = durations.reduce((a, b) => a < b ? a : b);
  final max = durations.reduce((a, b) => a > b ? a : b);

  logger?.info('Duration Statistics:');
  logger?.info('  Average: ${_formatDuration(avg)}');
  logger?.info('  Min: ${_formatDuration(min)}');
  logger?.info('  Max: ${_formatDuration(max)}');
}

/// Logs a value to a CSV file with the given key.
/// If the key exists, updates the row, otherwise appends a new row.
/// CSV format: key,value
Future<void> logToCsv(
  String filepath,
  String key,
  num value, {
  Logger? logger,
}) async {
  final file = File(filepath);
  if (!file.existsSync()) {
    await file.writeAsString('key,value\n');
  }

  final lines = await file.readAsLines();
  var found = false;
  final newLines = <String>[];

  // Skip header
  newLines.add(lines.first);

  // Look for existing key
  for (var i = 1; i < lines.length; i++) {
    final parts = lines[i].split(',');
    if (parts[0] == key) {
      newLines.add('$key,$value');
      found = true;
    } else {
      newLines.add(lines[i]);
    }
  }

  // Append if key not found
  if (!found) {
    newLines.add('$key,$value');
  }

  await file.writeAsString(newLines.join('\n') + '\n');
  logger?.info('${found ? 'Updated' : 'Appended'} value for key "$key"');
}
