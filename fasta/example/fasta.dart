// Copyright (c) 2024 Fabrizio Guidotti
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import 'dart:io';

import 'package:fasta/fasta.dart' as fasta_lib;
import 'package:readers/readers.dart';

void main() {
  final source = SyncFileSource(File('./test/data/fasta1.fa'))..open();

  final reads = handleSync(
    fasta_lib.readAllSequences,
    source,
  );

  print(
      reads); // (FastaRead(header: sequence1, length: 26), FastaRead(header: sequence2, length: 22), FastaRead(header: sequence3, length: 22))

  source.close();
}
