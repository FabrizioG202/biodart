// Copyright (c) 2024 Fabrizio Guidotti
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import 'dart:typed_data';

import 'package:fasta/src/exceptions.dart';
import 'package:fasta/src/read.dart';
import 'package:meta/meta.dart';
import 'package:readers/readers.dart';

const kCarriageReturn = 13;
const kGreaterThan = 62;
const kNewline = 10;

/// Parses a FASTA file and yields [FastaRead] entries.
/// Expects a [ByteAccumulator] buffer to read from, where data is already decoded.
ParseIterable<FastaRead> readEntries(
  ByteAccumulator buffer, {
  int chunkReadSize = 1024,
}) sync* {
  final cursor = Cursor();
  var state = const FastaParserState.blank();
  String? header;

  // Buffer where we store the read temporarily, to nicely
  // handle multiline strings.
  final sequenceReadBuffer = BytesBuilder(copy: false);

  @pragma('vm:prefer-inline')
  FastaRead generateRead() {
    return FastaRead(
      header!,
      String.fromCharCodes(sequenceReadBuffer.takeBytes()),
    );
  }

  while (true) {
    // Request at minimium [chunkReadSize]
    yield ByteRangeRequest(cursor.position, cursor.position + chunkReadSize);

    // grab the chunk we just read.
    final chunk = buffer.viewRange(cursor.position, buffer.lengthInBytes);

    // Grab a reference to the current position
    final chunkStartAbsoluteOffset = cursor.position;
    cursor.advance(chunk.length);

    // We read no data, we are at the end of the file
    // and thus read nothing, break out of the mainloop
    if (chunk.isEmpty) break;

    for (var i = 0; i < chunk.length; i++) {
      final char = chunk[i];
      final absoluteBufferPos = i + chunkStartAbsoluteOffset;

      switch (char) {
        case (kNewline) when state is _Blank:
          break;
        case kGreaterThan when state is _Blank:

          // we also yield the previous sequence
          // here maybe we should have a check to
          // say that the sequence should not be empty.
          // since that would mean a repeated header (i believe)
          if (header != null) {
            if (sequenceReadBuffer.isEmpty) {
              throw FastaFormatException(
                'Found empty sequence for header: $header',
              );
            }

            yield ParseResult(generateRead());

            // Reset the sequence buffer and header
            sequenceReadBuffer.clear();
            header = null;
          }

          // entering into header
          state = FastaParserState.inHeader(absoluteBufferPos);

        case _ when state is _Blank:
          // if we are here and do not have an header,
          if (header == null) {
            throw const FastaFormatException(
              'Found sequence data before header',
            );
          }

          // move to sequence state
          state = FastaParserState.inSequence(absoluteBufferPos);

        case (kNewline || kCarriageReturn) when state is _InHeader:
          // We have a header, and we are at the end of the header
          // if we are here, we should not have an header already.
          header = String.fromCharCodes(
            buffer.viewRange(
              state.startPosition + 1 /* Skip the > symbol */,
              absoluteBufferPos,
            ),
          );

          // We are now in the sequence
          state = const _Blank();
        case _ when state is _InHeader:
          break;

        case (kNewline || kCarriageReturn) when state is _InSequence:

          // We could either be at a split in a sequence or at the end of it.
          // since we do not know, we simply add the sequence to the buffer
          // and continue.
          sequenceReadBuffer
              .add(buffer.viewRange(state.thisChunkStart, absoluteBufferPos));
          state = const _Blank();

        case (_) when state is _InSequence:
          break;
      }
    }
  }

  // If we are here, we have read the entire file
  // and we should yield the last sequence.
  if (header != null) {
    if (state case _InSequence(:final thisChunkStart)) {
      sequenceReadBuffer
          .add(buffer.viewRange(thisChunkStart, buffer.lengthInBytes));
    }

    yield ParseResult(generateRead());
  }
}

@immutable
sealed class FastaParserState {
  const FastaParserState();

  const factory FastaParserState.blank() = _Blank;
  const factory FastaParserState.inHeader(int startPosition) = _InHeader;
  const factory FastaParserState.inSequence(int thisChunkStart) = _InSequence;
}

final class _Blank extends FastaParserState {
  const _Blank();

  @override
  String toString() => '_Blank()';
}

final class _InHeader extends FastaParserState {
  const _InHeader(this.startPosition);

  // The index of the start position
  final int startPosition;

  @override
  String toString() => '_InHeader(startPosition: $startPosition)';
}

final class _InSequence extends FastaParserState {
  const _InSequence(this.thisChunkStart);

  // Might be superfluos since we now have the thisChunkStart.
  final int thisChunkStart;

  @override
  String toString() => '_InSequence(thisChunkStart: $thisChunkStart)';
}
