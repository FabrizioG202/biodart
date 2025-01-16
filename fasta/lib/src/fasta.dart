import 'dart:convert' show Encoding, ascii;
import 'dart:math' show max;
import 'dart:typed_data' show Uint8List;

import 'package:meta/meta.dart' show immutable, internal;
import 'package:readers/readers.dart'
    show
        ByteAccumulator,
        CollapseBuffer,
        Cursor,
        ParseIterable,
        ParseResult,
        RequestRangeForReading;

// TODO: We might make this a static field on the [Cursor] class.
// so it is easier to check and account for.
// ignore: constant_identifier_names
const _EOF = -2;

ParseIterable<LazyBytesFastaRecord> iterateReads(
  ByteAccumulator accumulator, {
  int seekChunkSize = 8,
}) sync* {
  final Cursor cursor = Cursor(-1);
  int readStart;

  final offsetsAccumulator = ByteAccumulator.zeros(initialSize: 8);

  for (;;) {
    readStart = cursor.position;
    cursor.next();
    yield* digestRead(
      accumulator,
      cursor,
      max(readStart, 0),
      offsetsAccumulator,
      seekChunkSize: seekChunkSize,
    );

    if (readStart >= 0 && cursor.position != readStart) {
      final chunkEnd =
          cursor.position == _EOF ? accumulator.lastOffset : cursor.position;

      final readBytes = accumulator.getRange(readStart, chunkEnd);
      yield ParseResult(
        LazyBytesFastaRecord(
          readBytes,
          offsetsAccumulator.getRange(0, offsetsAccumulator.lastOffset),
        ),
      );
    }

    // Collapse the buffer to free up memory.
    yield const CollapseBuffer();

    // We finished reading the file.
    if (cursor.position < 0) {
      break;
    }

    // For now, the byte ranges are always 0-based,
    // since we sublist the buffer starting from the cursor position.
    // and since the
    offsetsAccumulator.trimToRange(startOffset: 0, endOffset: 1);
  }
}

@internal
Iterable<RequestRangeForReading> digestRead(
  ByteAccumulator acc,
  Cursor cursor,
  int startFrom,
  ByteAccumulator offsets, {
  required int seekChunkSize,
}) sync* {
  // The first offset (in buffer-coordinates) that we want to
  // be able to read.
  final dataStart = startFrom;

  while (true) {
    if (acc.lastOffset <= cursor.position) {
      // we ran out of bytes to read.
      // ask to read 4 bytes
      yield RequestRangeForReading(dataStart, cursor.position + seekChunkSize);

      // if the buffer length matches the cursor.position,
      // we read 0 bytes, and we should break.
      if (acc.lastOffset == cursor.position) {
        offsets.setByte(offsets.lastOffset - 1, cursor.position - dataStart);
        cursor.positionAt(_EOF);
        return;
      }

      // otherwise, we continue to the next chunk.
      continue;
    }

    final byte = acc.getByte(cursor.position);
    if (byte == 62) {
      return;
    } else if (byte == 10 || byte == 13) {
      // offsets.add(cursor.position - dataStart);
      offsets.setByte(offsets.lastOffset - 1, cursor.position - dataStart);
    }

    cursor.next();
  }
}

/// A mixin for FASTA records.
mixin FastaRecordMixin {
  /// Returns the header of the FASTA record.
  String getHeader();

  /// Returns the sequence of the FASTA record.
  String getSequence();
}

/// A Fasta record class backed by a single Uint8List and a list of offsets, where,
/// the second offset represents the start of the header, and from the third on,
/// the index of each whitespace character in the sequence (for now \n and \r).
@immutable
class LazyBytesFastaRecord with FastaRecordMixin {
  const LazyBytesFastaRecord(this.bytes, this.offsets)
    : assert(
        offsets.length > 2,
        'There must be at least one offset (the end of the header).',
      );

  /// Underlying bytes of the record.
  final Uint8List bytes;
  final List<int> offsets;

  @override
  String getHeader({Encoding encoding = ascii}) {
    return encoding.decode(bytes.sublist(offsets[0], offsets[1]));
  }

  @override
  String getSequence({Encoding encoding = ascii}) {
    final sequenceBytes = <int>[];
    for (int i = 1; i < offsets.length - 1; i++) {
      // start is the position of whitespace char, so we skip it.
      final start = offsets[i];
      final end = offsets[i + 1];
      if (start == end) {
        continue;
      }
      sequenceBytes.addAll(bytes.sublist(start + 1, end));
    }
    return encoding.decode(sequenceBytes);
  }
}
