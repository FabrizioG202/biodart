// Copyright (c) 2024 Fabrizio Guidotti
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import 'package:meta/meta.dart';

/// Represents a single FASTA sequence entry.
/// The bytes for the entire entry, including the header and the sequence,
/// are stored in memory as strings.
///
/// For long reads which are not necessarily needed to be stored in memory,
/// consider using a different representation.
///
/// TODO: (Implement a more memory-efficient representation)
@immutable
final class FastaRead {
  const FastaRead(this.header, this.sequence);

  /// Header of the FASTA sequence.
  final String header;

  /// Nucleotide sequence as a string, trimmed of any whitespace.
  final String sequence;

  /// Length of the sequence.
  int get length {
    return sequence.length;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is FastaRead &&
            other.header == header &&
            other.sequence == sequence;
  }

  @override
  int get hashCode {
    return Object.hash(
      header,
      sequence,
    );
  }

  @override
  String toString() => 'FastaRead(header: $header, length: $length)';
}
