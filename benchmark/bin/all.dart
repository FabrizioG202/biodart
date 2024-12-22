// Copyright (c) 2024 Fabrizio Guidotti
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

// Pionites Leucogaster (white bellied caique) genome.
import 'dart:io';

import 'package:benchmark/benchmark.dart';
import 'package:logging/logging.dart';
import 'package:fasta/fasta.dart';
import 'package:readers/readers.dart';

const kPionitesLeucogasterGenomeUrl =
    "https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/025/448/055/GCA_025448055.1_ASM2544805v1/GCA_025448055.1_ASM2544805v1_genomic.fna.gz";

Future<void> main() async {
  // Cache directory for the files
  // ! DO NOT check this into source control as it will contain large files.
  final kCacheDirectory = Directory('.data/');
  final logger = Logger('file-downloading');

  // ignore: avoid_print
  final loggingSubscription = logger.onRecord.listen((e) => print(e));

  // download the fasta file
  final genomeFile = await pullFile(kPionitesLeucogasterGenomeUrl, kCacheDirectory, logger: logger);

  final source = SyncFileSource(genomeFile!)..open();

  final first5Sequences = parseSync(
    (b) => zlibDecode(b, readEntries),
    source,
  ).take(5).toList();

  print(first5Sequences);

  await loggingSubscription.cancel();
}
