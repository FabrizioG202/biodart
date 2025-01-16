// ignore_for_file: avoid_print

import 'dart:io';

import 'package:fasta/fasta.dart' as fasta_lib;
import 'package:readers/readers.dart';

void main() {
  // Create a source from the file and open it.
  final source = SyncFileSource(File('./test/data/fasta1.fa.gz'))..open();

  final reads =
      parseSync((comp) {
        return zlibDecode(comp, (buff) {
          return fasta_lib.iterateReads(buff);
        });
      }, source).toList();

  for (final read in reads) {
    print(read.getHeader());
    print(read.getSequence());
    print(read.getSequence().length);
  }

  // Close the source.
  source.close();
}
