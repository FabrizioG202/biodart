// Copyright (c) 2024 Fabrizio Guidotti
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import 'dart:io';

import 'package:fasta/fasta.dart' as fasta_lib;
import 'package:readers/readers.dart';

void main() {
  // Create a source from the file and open it.
  final source = SyncFileSource(
    File(
      './test/data/fasta1.fa',
    ),
  )..open();

  final reads = parseSync(
    (b) => fasta_lib.readEntries(b),
    source,
  ).toList();

  print(reads);

  // Close the source.
  source.close();
}
