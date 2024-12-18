// Copyright (c) 2024 Fabrizio Guidotti
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import 'dart:convert';
import 'dart:typed_data';

import 'package:readers/readers.dart';

// This file contains naive, low-level parsing functions.
// These are by no means optimal, and are only used for
// the initial implementation.
// The goal is to replace these with more efficient
// implementations in the future once we have a better reading
// and parsing framework.
// If you're learning to code, please don't use this as an example,
// thank you.

int getInt32(
  ByteAccumulator buffer,
  SliceCursor cursor, {
  Endian endian = Endian.little,
}) {
  cursor.advance(4);
  return cursor.slice(buffer).buffer.asByteData().getInt32(0, endian);
}

int getInt64(
  ByteAccumulator buffer,
  SliceCursor cursor, {
  Endian endian = Endian.little,
}) {
  cursor.advance(8);
  return cursor.slice(buffer).buffer.asByteData().getInt64(0, endian);
}

int getInt16(
  ByteAccumulator buffer,
  SliceCursor cursor, {
  Endian endian = Endian.little,
}) {
  cursor.advance(2);
  return cursor.slice(buffer).buffer.asByteData().getInt16(0, endian);
}

int getByte(
  ByteAccumulator buffer,
  SliceCursor cursor,
) {
  cursor.advance(1);
  return cursor.slice(buffer).buffer.asByteData().getInt8(0);
}

double getFloat32(
  ByteAccumulator buffer,
  SliceCursor cursor, {
  Endian endian = Endian.little,
}) {
  cursor.advance(4);
  return cursor.slice(buffer).buffer.asByteData().getFloat32(0, endian);
}

double getFloat64(
  ByteAccumulator buffer,
  SliceCursor cursor, {
  Endian endian = Endian.little,
}) {
  cursor.advance(8);
  return cursor.slice(buffer).buffer.asByteData().getFloat64(0, endian);
}

String getStringSlice(
  ByteAccumulator buffer,
  SliceCursor cursor, {
  Encoding encoding = ascii,
}) {
  // print(slice);
  // ?? Not the best thing to do, I think, since the slice will get collapsed
  // even if the decoding fails...
  final bytes = cursor.slice(buffer, cursor.position - 1);
  return encoding.decode(
    bytes,
  );
}
