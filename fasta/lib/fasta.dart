// Copyright (c) 2024 Fabrizio Guidotti
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import 'package:meta/meta.dart';
import 'package:readers/readers.dart';

/// Represents a single FASTA sequence entry.
@immutable
final class FastaRead {
  const FastaRead(this.header, this.sequence);

  /// Header of the FASTA sequence.
  final String header;

  /// Nucleotide sequence.
  final String sequence;

  /// Length of the sequence.
  int get length => sequence.length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FastaRead && other.header == header && other.sequence == sequence;

  @override
  int get hashCode => Object.hash(header, sequence);

  @override
  String toString() => 'FastaRead(header: $header, length: $length)';
}

/// Thrown when FASTA format is invalid
class FastaFormatException implements Exception {
  const FastaFormatException(this.message);

  final String message;

  @override
  String toString() => 'FastaFormatException: $message';
}

/// Reads all sequences from a FASTA format buffer.
ParseIterator<FastaRead> readAllSequences(ByteAccumulator buffer) sync* {
  var header = '';
  final sequence = StringBuffer();
  var isInHeader = false;
  var hasSequence = false;
  var position = 0;

  while (true) {
    yield const PartialReadRequest(maxCount: 1024);
    final view = buffer.getBytesView();
    if (view.isEmpty) break;

    // PERF: We might be better off by not mapping to string
    // but rather checking the character to known char indices
    // and only convert to string when adding to the buffer.
    // We might also be able to add bytes to the buffer directly.
    for (final char in view.map(String.fromCharCode)) {
      position++;

      switch (char) {
        case '>':
          if (hasSequence) {
            if (sequence.isEmpty) {
              throw FastaFormatException(
                'Empty sequence for header "$header" at position $position',
              );
            }
            final seq = sequence.toString().replaceAll(RegExp(r'\s'), '');
            yield CompleteParseResult.incomplete(FastaRead(header, seq));
            sequence.clear();
          }
          header = '';
          isInHeader = true;
          hasSequence = true;

        case '\n' || '\r':
          isInHeader = false;

        case String s:
          if (!hasSequence && !isInHeader && s.trim().isNotEmpty) {
            throw FastaFormatException(
              'Found sequence data before header at position $position',
            );
          }
          if (isInHeader) {
            header += s;
          } else if (s.trim().isNotEmpty) {
            sequence.write(s);
          }
      }
    }
    buffer.clear();
  }

  if (hasSequence) {
    if (sequence.isEmpty) {
      throw FastaFormatException(
        'Empty sequence for header "$header" at position $position',
      );
    }
    final seq = sequence.toString().replaceAll(RegExp(r'\s'), '');
    yield CompleteParseResult(FastaRead(header, seq));
  }
}
