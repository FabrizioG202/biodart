import 'dart:io';

import 'package:hic/hic.dart';
import 'package:hic/passthrough.dart';
import 'package:readers/readers.dart';

/// Export the expected contacts in the given region to a CSV file.
void main() {
  final source = SyncFileSource(File('../.data/v8.hic'))..open();
  final file = HiCFile();

  handleSync(
    (b) sync* {
      yield* file.readHeader(b).passthrough<void>();
      yield* file.readMasterIndex(b).passthrough<void>();
    },
    source,
    clearOnPassthrough: true,
  ).toList();

  // We want to save the contacts for the full chromosome 1 at 100kb resolution.
  final chr1 = file.header.genome.getChromosome('1').asRange();
  const resolution = Resolution.bp(100000);
  final chr1at100Kb = handleSync(
    (b) => file.iterateContacts(
      b,
      chr1,
      chr1,
      resolution,
    ),
    source,
  ).toList();

  // Close the source.
  source.close();

  // Write the contacts to a CSV file.
  // *this logic is irrelevant to the hic library
  File('../.data/contacts.csv').writeAsString(
    [
      'bin1,bin2,contact_count', // header
      ...chr1at100Kb.map(
        (c) {
          final (binX, binY, count) = c;
          return '${binX * resolution.binSize},${binY * resolution.binSize},$count';
        },
      ),
    ].join('\n'),
  );
}
