// ignore_for_file: unused_local_variable

import 'dart:io';
import 'dart:typed_data';

import 'package:hic/hic.dart';
import 'package:hic/passthrough.dart';
import 'package:readers/readers.dart';

void main() {
  // Create a source to read the file.
  // For now, only the Version 8 of the format is supported.
  final source = SyncFileSource(File('../.data/v8.hic'))..open();

  // Create a HiC file object.
  // This is more of a container for the file, and does not
  // read the file itself.
  final file = HiCFile();

  // This is not optimal, I am working
  // on a way to make this better.
  // The funky syntax is due to the design of the library,
  // In particular, I am trying to make the library as
  // explicit as possible, so that the user knows what is
  // happening at each step, while also balancing the
  // verbosity of the code and performance.
  // and of the `readers` package, which is used to read the file.
  handleSync(
    (b) sync* {
      // Read the header and master index
      yield* file.readHeader(b).passthrough<void>();
      yield* file.readMasterIndex(b).passthrough<void>();

      // Stop the parser
      yield PartialParseResult.stop;
    },
    source,
    clearOnPassthrough: true,
  );

  // Now that the header is read, get chr1, using
  final chr1 = file.header.genome.getChromosome('1').asRange();

  // Read the contacts for chr1 at 50kb resolution
  // These are the observed counts, since normalization
  // is not ready yet.
  //
  // I am working on a way to make this better.
  final (
    Float32List data, //2D matrix, flattened to a 1D array (row-major order)
    (
      int width,
      int height,
    ) shape // Shape of the matrix,
  ) = handleSync(
    (b) => file.readContactsAsMatrix(
      b,
      chr1,
      chr1,
      const Resolution.bp(50000),
    ),
    source,
  );

  // Close the source.
  source.close();
}
