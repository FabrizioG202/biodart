// Copyright (c) 2024 Fabrizio Guidotti
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

// Pionites Leucogaster (white bellied caique) genome.
import 'dart:io';

import 'package:benchmark/benchmark.dart';
import 'package:fasta/fasta.dart';
import 'package:logging/logging.dart';
import 'package:readers/readers.dart';

/// Genome of white-bellied parrot (Pionites Leucogaster), contains ~90K sequences
/// and has a (compressed) size of ~1GB
const kPionitesLeucogasterGenomeUrl =
    "https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/025/448/055/GCA_025448055.1_ASM2544805v1/GCA_025448055.1_ASM2544805v1_genomic.fna.gz";

Future<void> main() async {
  final kCacheDirectory = Directory('.data/');
  final logger = Logger('benchmark');

  // ignore: avoid_print
  final loggingSubscription = logger.onRecord.listen((e) => print(e));

  final genomeFile = await pullFile(
    kPionitesLeucogasterGenomeUrl,
    kCacheDirectory,
    logger: logger,
  );
  if (genomeFile == null) return;

  final source = SyncFileSource(genomeFile);
  List<FastaRecordMixin> allSequences = [];

  final durations = benchmark(
    () {
      allSequences =
          parseSync(
            (b) => zlibDecode(
              b,
              (b) => iterateReads(b, seekChunkSize: 1024),
              decompressChunkSize: 4096,
            ),
            source,
          ).take(1000).toList();
    },
    10,
    setupAll: () => source.open(),
    cleanupAll: () => source.close(),
  );

  printDurationStats(durations, logger: logger);
  logger.info('Parsed ${allSequences.length} sequences');

  await loggingSubscription.cancel();
}
