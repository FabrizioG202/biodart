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
