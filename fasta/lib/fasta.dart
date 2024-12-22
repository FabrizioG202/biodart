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

// Very Naive Implementation of a FastA file parser.
// It is mainly
ParseIterable<FastaRead> readEntries(ByteAccumulator buffer) sync* {
  final cursor = Cursor();

  // Fasta Stuff
  var header = '';
  final sequence = StringBuffer();
  var isInHeader = false;
  var hasSequence = false;
  var position = 0;

  while (true) {
    // Request 5 bytes.
    // This is an arbitrary length to not read too much data at the same time.
    yield ByteRangeRequest(cursor.position, cursor.position + 5, purgePreceding: true);

    // Get the view bytes and, since exact is false,
    // we might have read less bytes than 5, we advance the cursor only
    // to that point.
    final view = buffer.viewRange(cursor.position, buffer.lengthInBytes);
    cursor.advance(view.length);

    // No more bytes were read.
    if (view.isEmpty) break;

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
            yield ParseResult(FastaRead(header, seq));
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
  }

  if (hasSequence) {
    if (sequence.isEmpty) {
      throw FastaFormatException(
        'Empty sequence for header "$header" at position $position',
      );
    }
    final seq = sequence.toString().replaceAll(RegExp(r'\s'), '');
    yield ParseResult(FastaRead(header, seq));
  }
}
