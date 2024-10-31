// Copyright (c) 2024 Fabrizio Guidotti
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

// ignore_for_file: unused_local_variable

/// This file contains the full implementation of the HiC file format data structures and parsing functions.
/// It is a work in progress, and is not yet fully optimized.
/// Once the library is more mature, this file will be split into multiple files.
library hic;

import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:genomics/genomics.dart';
import 'package:hic/parsing.dart';
import 'package:meta/meta.dart';
import 'package:readers/readers.dart';

enum ResolutionType {
  frag('FRAG'),
  bp('bp');

  const ResolutionType(this.stringKey);
  final String stringKey;
}

@immutable
final class Resolution {
  const Resolution.bp(int binSize) : this._(binSize, ResolutionType.bp);
  const Resolution.frag(int binSize) : this._(binSize, ResolutionType.frag);
  const Resolution._(this.binSize, this.type);

  final int binSize;
  final ResolutionType type;

  @override
  String toString() => 'Resolution('
      'binSize: $binSize, '
      'type: $type'
      ')';

  @override
  bool operator ==(covariant Resolution other) {
    return identical(this, other) ||
        other.binSize == binSize && other.type == type;
  }

  @override
  int get hashCode => Object.hash(binSize, type);
}

/// Represents a region of a given file. Used in [ResolutionMetadata.blockIndex].
typedef FileRegion = ({int /* i64 */ offset, int /* i32 */ length});

@immutable
final class Header {
  const Header({
    required this.version,
    required this.footerPosition,
    required this.genomeId,
    required this.attributes,
    required this.genome,
    required this.resolutions,
    this.sites = const {},
  });

  final int version;
  final String genomeId;
  final HashMap<String /* nt-string*/, String /* nt-string */ > attributes;
  final IndexedGenome genome;
  final List<Resolution> resolutions;
  final int /* i64 */ footerPosition;
  final Map<String, List<int /* i32 */ >> sites;

  int get masterIndexPosition => footerPosition + 4;

  @override
  String toString() => 'Header('
      'version: $version, '
      'footerPosition: $footerPosition, '
      "genomeId: '$genomeId', "
      'attributes: $attributes, '
      'genome: $genome, '
      'resolutions: $resolutions, '
      'sites: $sites, '
      ')';
}

@immutable
final class ResolutionMetadata {
  const ResolutionMetadata({
    required this.binSize,
    required this.sumCounts,
    required this.resolution,
    required this.blockSize,
    required this.blockColumnCount,
    required this.blockIndex,
  });

  final double sumCounts;
  final Resolution resolution;
  final int binSize;
  final int /* i32 */ blockSize;
  final int /* i32 */ blockColumnCount;
  final SplayTreeMap<int, FileRegion> blockIndex;

  @override
  String toString() => 'ResolutionMetadata('
      'sumCounts: $sumCounts, '
      'resolution: $resolution, '
      'binSize: $binSize, '
      'blockSize: $blockSize, '
      'blockColumnCount: $blockColumnCount, '
      'blockIndex: $blockIndex'
      ')';
}

final class HiCFile {
  HiCFile();

  /// Header of the file, contains information about the genome
  /// and the resolutions available in the file.
  /// [HiCFile.readHeader] must have been called before this field is accessed.
  Header get header => _header ?? (throw StateError('Header was not parsed'));
  Header? _header;

  /// Contains the position and length of the matrices in the file.
  /// [HiCFile.readMasterIndex] must have been called before this field is accessed.
  Map<String, (int, int)> get masterIndex =>
      _masterIndex ?? (throw StateError('Master-Index was not parsed'));
  Map<String, (int, int)>? _masterIndex;

  Iterable<PartialParseResult<Header>> readHeader(
    ByteAccumulator buffer,
  ) sync* {
    final cursor = SliceCursor.collapsed();

    // Arbitrary number, we can increase it if needed.
    yield const ExactReadRequest(count: 16, sourcePosition: 0);

    // Magic
    // In contrast to the straw.cpp's code, we are not reading a null terminated
    // string since if the file is not in the expected format, we might never have
    // a null character and we would stall on the first read.
    cursor.advance(4);
    final magic =
        ascii.decode(cursor.slice(buffer)).validate(_equals('HIC\x00'));

    // Version, for now we support only version 8.
    final version = getInt32(buffer, cursor).validate(_equals(8));
    final footerPosition = getInt64(buffer, cursor);

    yield* buffer.advanceToByte(cursor, byte: 0x00);
    final genomeId = getStringSlice(buffer, cursor);

    // Attributes, map of null-terminated strings to null-terminated strings.
    yield* buffer.extendToLength(cursor.position + 4);
    var attributesCount = getInt32(buffer, cursor);
    final attributes = <String, String>{};

    while (attributesCount-- > 0) {
      yield* buffer.advanceToByte(cursor, byte: 0x00);
      final key = getStringSlice(buffer, cursor, encoding: utf8);

      yield* buffer.advanceToByte(cursor, byte: 0x00);
      attributes[key] = getStringSlice(buffer, cursor, encoding: utf8);
    }

    // Genome.
    yield* buffer.extendToLength(cursor.position + 4);
    var chromosomesCount = getInt32(buffer, cursor);

    final genome = <(String, int)>[];
    while (chromosomesCount-- > 0) {
      yield* buffer.advanceToByte(cursor, byte: 0x00);
      final chr = getStringSlice(buffer, cursor, encoding: utf8);

      yield* buffer.extendToLength(cursor.position + 4);
      genome.add(
        (
          chr,
          getInt32(buffer, cursor),
        ),
      );
    }

    final indexedGenome = IndexedGenome.fromChromosomeList(genome);

    // Resolutions
    //  - BP resolutions
    yield* buffer.extendToLength(cursor.position + 4);
    var nBpResolutions = getInt32(buffer, cursor);
    final bpResolutions = <Resolution>[];

    while (nBpResolutions-- > 0) {
      // EASYFIX: We can prefetch the whole resolutions list,
      // since we know the number of resolutions.
      yield* buffer.extendToLength(cursor.position + 4);
      final binSize = getInt32(buffer, cursor);
      bpResolutions.add(Resolution.bp(binSize));
    }

    //  - FRAG resolutions
    yield* buffer.extendToLength(cursor.position + 4);
    var nFragResolutions = getInt32(buffer, cursor);
    final fragResolutions = <Resolution>[];

    while (nFragResolutions-- > 0) {
      // EASYFIX: We can prefetch the whole resolutions list,
      // since we know the number of resolutions.
      yield* buffer.extendToLength(cursor.position + 4);
      final binSize = getInt32(buffer, cursor);
      fragResolutions.add(Resolution.frag(binSize));
    }

    // SITES
    final sites = <String, List<int>>{};
    if (nFragResolutions > 0) {
      for (final (chr, _) in genome) {
        yield* buffer.extendToLength(cursor.position + 4);
        final nSites = getInt32(buffer, cursor);
        final siteList = <int>[];

        for (var i = 0; i < nSites; i++) {
          yield* buffer.extendToLength(cursor.position + 4);
          siteList.add(getInt32(buffer, cursor));
        }

        sites[chr] = siteList;
      }
    }

    yield CompleteParseResult(
      _header = Header(
        version: version,
        footerPosition: footerPosition,
        genomeId: genomeId,
        attributes: HashMap.from(attributes),
        genome: indexedGenome,
        resolutions: [...bpResolutions, ...fragResolutions],
        sites: sites,
      ),
    );
  }

  /// For now, [HiCFile.readHeader] must have been called before this function.
  /// Read the master index of the file.
  Iterable<PartialParseResult<Map<String, (int, int)>>> readMasterIndex(
    ByteAccumulator buffer,
  ) sync* {
    final cursor = SliceCursor.collapsed();
    final header = this.header;

    yield ExactReadRequest(
      count: switch (header.version) { < 9 => 8, _ => 12 },
      sourcePosition: header.footerPosition,
    );

    // Get the footer
    final nBytes = switch (header.version) {
      < 9 => getInt32,
      _ => getInt64,
    }(buffer, cursor);

    // Parsing the master index.
    var nEntries = getInt32(buffer, cursor);
    final masterIndex = <String, (int, int)>{};
    do {
      // Key is a null-terminated string.
      yield* buffer.advanceToByte(cursor, byte: 0x00);
      final key = getStringSlice(buffer, cursor);

      yield const ExactReadRequest(count: 12);
      final binPosition = getInt64(buffer, cursor);
      final nBlocks = getInt32(buffer, cursor);

      masterIndex[key] = (binPosition, nBlocks);
    } while (--nEntries > 0);

    yield CompleteParseResult(_masterIndex = masterIndex);
  }

  /// For now, [HiCFile.readMasterIndex] must have been called before this function.
  /// Do not call this directly, unless you really know what you're
  /// doing, if you do not, use [readContactsAsMatrix] instead.
  /// Read the metadata for the matrix.
  @protected
  @visibleForTesting
  ParseIterator<List<ResolutionMetadata>> getMatrixMetadatas(
    ByteAccumulator buffer,
    String masterIndexKey,
  ) sync* {
    final masterIndex = this.masterIndex;

    final (filePosition, length) = masterIndex[masterIndexKey].expectWith(
      () => StateError(
        'Master index key not found: $masterIndexKey',
      ),
    );

    yield ExactReadRequest(count: length, sourcePosition: filePosition);

    // The chromosome indices are not used right now
    // We might use them in the future to check that the
    // matrix is in the correct order.
    final cursor = SliceCursor.collapsed();
    final chr1Idx = getInt32(buffer, cursor);
    final chr2Idx = getInt32(buffer, cursor);
    final resolutionsCount = getInt32(buffer, cursor);
    final resolutions = <ResolutionMetadata>[];

    for (var i = 0; i < resolutionsCount; i++) {
      // Read the unit (null terminated string)
      // We do not use this value right now, since
      // we are accessing the resolution by its index only,.
      // so we just take the opportunity to validate the value.
      yield* buffer.advanceToByte(cursor, byte: 0x00);
      final unit = getStringSlice(buffer, cursor);
      if (unit != 'BP' && unit != 'FRAG') {
        throw StateError('Invalid unit: $unit, expected BP or FRAG');
      }

      final resolutionIdx = getInt32(buffer, cursor);
      final sumCounts = getFloat32(buffer, cursor);
      final occupiedCellCount = getInt32(buffer, cursor);
      final percent5 = getFloat32(buffer, cursor);
      final percent95 = getFloat32(buffer, cursor);
      final binSize = getInt32(buffer, cursor);
      final blockSize = getInt32(buffer, cursor);
      final blockColumnCount = getInt32(buffer, cursor);
      final blockCount = getInt32(buffer, cursor);

      assert(
        occupiedCellCount == 0 && percent5 == 0 && percent95 == 0,
        'In V8, values are expected to be 0, found occupiedCellCount: $occupiedCellCount, percent5: $percent5, percent95: $percent95',
      );

      resolutions.add(
        ResolutionMetadata(
          sumCounts: sumCounts,
          resolution: header.resolutions[resolutionIdx],
          binSize: binSize,
          blockSize: blockSize,
          blockColumnCount: blockColumnCount,
          blockIndex: SplayTreeMap<int, FileRegion>.from({
            for (var i = 0; i < blockCount; i++)
              getInt32(buffer, cursor): (
                offset: getInt64(buffer, cursor),
                length: getInt32(buffer, cursor),
              ),
          }),
        ),
      );
    }

    yield CompleteParseResult(resolutions);
  }

  /// Reads the matrix data for the given genomic ranges
  ParseIterator<(Float32List, (int, int))> readContactsAsMatrix(
    ByteAccumulator buffer,
    GenomicRange xRange,
    GenomicRange yRange,
    Resolution resolution,
  ) sync* {
    final header = this.header;
    final masterIndex = this.masterIndex;

    final seq1 = xRange.chromosomeName;
    final seq2 = yRange.chromosomeName;
    var seqIdx1 = header.genome.indexOf(seq1);
    var seqIdx2 = header.genome.indexOf(seq2);
    final sameChr = seqIdx1 == seqIdx2;

    // swap the sequences of indices around if needed.
    // similar to how hicFile.js does it.
    if (seqIdx1 > seqIdx2) {
      (seqIdx1, seqIdx2) = (seqIdx2, seqIdx1);
    }

    // Get the master index key
    final masterIndexKey = '${seqIdx1}_$seqIdx2';

    // we parse the metadata for the matrix
    List<ResolutionMetadata>? allMetadata;
    yield* passthrough(
      getMatrixMetadatas(buffer, masterIndexKey),
      onComplete: (metadata) {
        buffer.clear();
        allMetadata = metadata;
      },
    );

    // we need the resolution metadata
    // for the block index and block metadata.
    final ResolutionMetadata(
      :binSize,
      :blockIndex,
      :blockColumnCount,
      :blockSize,
      :sumCounts
    ) = allMetadata
        .expect(
          'Failed to parse metadata',
        )
        .firstWhere(
          (e) => e.resolution == resolution,
          orElse: () => throw StateError('Resolution not found: $resolution'),
        );

    // We round the range to the nearest bin
    final xRangeInBins = xRange.copyWith(
      start: (xRange.start / binSize).floor(),
      end: (xRange.end / binSize).ceil(),
    );
    final yRangeInBins = yRange.copyWith(
      start: (yRange.start / binSize).floor(),
      end: (yRange.end / binSize).ceil(),
    );

    // Returns the block numbers for the given range,
    // according to v8 specification.
    Iterable<int> blockNumbersV8() sync* {
      final xBlockStart = (xRangeInBins.start / blockSize).floor();
      final xBlockEnd = (xRangeInBins.end / blockSize).ceil();

      final yBlockStart = (yRangeInBins.start / blockSize).floor();
      final yBlockEnd = (yRangeInBins.end / blockSize).ceil();

      for (var xBlock = xBlockStart; xBlock < xBlockEnd; xBlock++) {
        for (var yBlock = yBlockStart; yBlock < yBlockEnd; yBlock++) {
          yield xBlock * blockColumnCount + yBlock;
        }
      }
    }

    // compute the size of the matrix
    final n = xRangeInBins.length;
    final m = yRangeInBins.length;

    // allocate the matrix
    final matrix = Float32List(n * m);
    var blockMisses = 0;
    var blockHits = 0;

    // We create the cursor only here since we have not
    // done any reading up to this point.
    final cursor = SliceCursor.collapsed();
    for (final flatBlockIndex in blockNumbersV8()) {
      final region = blockIndex[flatBlockIndex];

      if (region == null) {
        blockMisses++;
        continue;
      }

      blockHits++;
      final (:offset, :length) = region;

      // read the bytes
      buffer.clear();
      cursor.reset();

      yield ExactReadRequest(count: length, sourcePosition: offset);
      final blockBytes = buffer.getBytesView(0, length);

      // FIXME: this is kinda icky, maybe the signature of .withData should be changed
      // to allow for any kind of List<int> instead of just Uint8List
      // Also, at this point, we are currently storing both the compressed and decompressed
      // data in memory, which is not ideal.
      final blockBuffer =
          ByteAccumulator.withData(Uint8List.fromList(zlib.decode(blockBytes)));
      final blockCursor = SliceCursor.collapsed();

      final nRecords = getInt32(blockBuffer, blockCursor);
      final binXOffset = getInt32(blockBuffer, blockCursor);
      final binYOffset = getInt32(blockBuffer, blockCursor);
      final useFloat = getByte(blockBuffer, blockCursor) == 1;
      final matrixRepresentation = getByte(blockBuffer, blockCursor);

      final iterator = switch (matrixRepresentation) {
        // block data: list of rows
        1 => () sync* {
            final rowCount = getInt16(blockBuffer, blockCursor);
            for (var i = 0; i < rowCount; i++) {
              final rowNumber = getInt16(blockBuffer, blockCursor);

              assert(
                rowNumber >= 0 && rowNumber <= blockSize - 1,
                'Row number out of bounds: $rowNumber',
              );

              final recordCount = getInt16(blockBuffer, blockCursor);

              for (var j = 0; j < recordCount; j++) {
                yield (
                  (getInt16(blockBuffer, blockCursor) + binXOffset),
                  (binYOffset + rowNumber)
                );
              }
            }
          },

        // block data: dense
        2 => () sync* {
            final nRecords = getInt32(blockBuffer, blockCursor);

            // Width of the dense block (can be < blockSize, if the edge columns on either side are empty)
            final w = getInt16(blockBuffer, blockCursor);
            for (var i = 0; i < nRecords; i++) {
              final row = i ~/ w;
              final col = i = row * w;
              yield (
                (row + binXOffset),
                (col + binYOffset),
              );
            }
          },
        _ => throw StateError(
            'Invalid matrix representation: $matrixRepresentation',
          ),
      };

      for (final (binX, binY) in iterator()) {
        // PERFORMANCE: We might save some time by not parsing the number if the
        // bin is not in the range and just skipping the bytes.
        final value = useFloat
            ? getFloat32(blockBuffer, blockCursor)
            : getInt16(blockBuffer, blockCursor).toDouble();

        final x = binX - xRangeInBins.start;
        final y = binY - yRangeInBins.start;
        if (xRangeInBins.contains(binX) && yRangeInBins.contains(binY)) {
          matrix[x * m + y] = value;
          matrix[y * n + x] = value;
        }
      }
    }

    {
      // check the sum counts
      // ! This is just a quick method to check that the data is correct. It only works for
      // full matrices. I am using this while developing the package, and will remove it
      // as soon as I have a better way to validate the data. (mainly testing)
      final sum = matrix.fold<double>(0, (a, b) => a + b);
      print('Block hits: $blockHits, block misses: $blockMisses');
      print('Sum: $sum, sumCounts: $sumCounts');
    }

    // For now, return just an empty matrix
    yield CompleteParseResult((matrix, (n, m)));
  }
}

/// Below here I have thrown some utility functions that I have used
/// to validate and pase data. They might or might not stick around
/// to the final version of the library. Though, if they do, they will
/// probably be moved to a separate file, or more likely a custom
/// package.

extension UnwrapExt<T> on T? {
  T expect(String message) => switch (this) {
        null => throw StateError(message),
        final value => value,
      };

  T expectWith(Error Function() error) => switch (this) {
        null => throw error(),
        final value => value,
      };
}

// map validate
typedef MapValidator<X, Y, E extends Error> = Y Function(X x);

class ValidationError extends Error {
  final String message;

  ValidationError(this.message);

  @override
  String toString() => message;
}

extension ValidateExt<T> on T {
  @pragma('vm:prefer-inline')
  Y validate<Y, E extends Error>(MapValidator<T, Y, E> validator) =>
      validator(this);
}

// TODO: add the possibility of adding a custom error message.
// or at least a custom error message generator.
MapValidator<X, X, E> _equals<X, E extends Error>(
  X value,
) =>
    (X x) {
      if (x != value) {
        throw ValidationError('Expected $value, found $x');
      }
      return x;
    };
