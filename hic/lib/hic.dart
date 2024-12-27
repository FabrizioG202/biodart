// Copyright (c) 2024 Fabrizio Guidotti
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

/// This file contains the full implementation of the HiC file format data structures and parsing functions.
/// It is a work in progress, and is not yet fully optimized.
/// Once the library is more mature, this file will be split into multiple files.
library hic;

import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:genomics/genomics.dart';
import 'package:hic/parsing.dart';
import 'package:meta/meta.dart';
import 'package:readers/readers.dart';

@protected
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
    return identical(this, other) || other.binSize == binSize && other.type == type;
  }

  @override
  int get hashCode => Object.hash(binSize, type);
}

/// Represents a region of a given file. Used in [ResolutionMetadata.blockIndex].
typedef FileRegion = ({int /* i64 */ offset, int /* i32 */ length});

/// A record in the contact matrix.
/// We use this class given the sparse nature of the matrix.
/// API?: Might make this an interface and have an optimized class
/// for when the contact matrix is dense.
typedef ContactRecord = (int binX, int binY, double value);

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
    this.expectedVectorsRegion,
  });

  final int version;
  final String genomeId;
  final HashMap<String /* nt-string*/, String /* nt-string */ > attributes;
  final IndexedGenome genome;
  final List<Resolution> resolutions;
  final int /* i64 */ footerPosition;

  /// The offset and size, in the file of the normalization data.
  /// This is known only after reading the master index.
  /// So, if no normalization is requested, this field
  /// will stay null.
  final FileRegion? expectedVectorsRegion;
  final Map<String, List<int /* i32 */ >> sites;

  int get masterIndexPosition => footerPosition + 4;

  Header copyWith({
    int? version,
    String? genomeId,
    HashMap<String, String>? attributes,
    IndexedGenome? genome,
    List<Resolution>? resolutions,
    int? footerPosition,
    FileRegion? expectedVectorsRegion,
    Map<String, List<int>>? sites,
  }) {
    return Header(
      version: version ?? this.version,
      genomeId: genomeId ?? this.genomeId,
      attributes: attributes ?? this.attributes,
      genome: genome ?? this.genome,
      resolutions: resolutions ?? this.resolutions,
      footerPosition: footerPosition ?? this.footerPosition,
      expectedVectorsRegion: expectedVectorsRegion ?? this.expectedVectorsRegion,
      sites: sites ?? this.sites,
    );
  }

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

@protected
typedef MasterIndex = Map<String, (int, int)>;

final class HiCFile {
  HiCFile();

  /// Header of the file, contains information about the genome
  /// and the resolutions available in the file.
  /// [HiCFile.readHeader] must have been called before this field is accessed.
  Header get header => _header ?? _throwStateError('Header was not parsed');
  Header? _header;

  /// Contains the position and length of the matrices in the file.
  /// [HiCFile.readMasterIndex] must have been called before this field is accessed.
  MasterIndex get masterIndex => _masterIndex ?? _throwStateError('Master index was not parsed');
  MasterIndex? _masterIndex;

  /// Contains the expected values for the file.
  /// [HiCFile.readExpectedValueVectors] must have been called before this field is accessed.
  List<ExpectedValues> get expectedValues => _expectedValues ?? _throwStateError('Expected values were not parsed');
  List<ExpectedValues>? _expectedValues;

  ExpectedValues? getExpectedValues(
    Resolution resolution, [
    String? normalization,
  ]) =>
      expectedValues.firstWhereOrNull(
        (e) => e.resolution == resolution && e.normalizationType == normalization,
      );

  /// Read the header of the file.
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

    // here we update the header to contain the position of the normalization data.
    _header = header.copyWith(
      expectedVectorsRegion: (offset: cursor.position + header.footerPosition, length: nBytes + 4),
    );
    yield CompleteParseResult(_masterIndex = masterIndex);
  }

  /// For now, [HiCFile.readMasterIndex] must have been called before this function.
  /// Do not call this directly, unless you really know what you're
  /// doing, if you do not, use [iterateContacts] instead.
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
    // we still read them only to advance the cursor.
    final cursor = SliceCursor.collapsed();
    getInt32(buffer, cursor); // chr1Idx
    getInt32(buffer, cursor); // chr2Idx
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
  ParseIterator<ContactRecord> iterateContacts(
    ByteAccumulator buffer,
    GenomicRange xRange,
    GenomicRange yRange,
    Resolution resolution, {
    ContactsKind kind = ContactsKind.observed,
  }) sync* {
    // This is always necessary
    final header = this.header;
    final seq1 = xRange.chromosomeName;
    final seq2 = yRange.chromosomeName;

    var seqIdx1 = header.genome.indexOf(seq1);
    var seqIdx2 = header.genome.indexOf(seq2);

    // ignore: unused_local_variable
    final sameChr = seqIdx1 == seqIdx2;

    // swap the sequences of indices around if needed.
    // similar to how hicFile.js does it.
    if (seqIdx1 > seqIdx2) {
      (seqIdx1, seqIdx2) = (seqIdx2, seqIdx1);
    }

    // Get the master index key
    final masterIndexKey = '${seqIdx1}_$seqIdx2';

    // We create the cursor only here since we have not
    // done any reading up to this point.
    final cursor = SliceCursor.collapsed();

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
    ) = allMetadata
        .expect(
          'Failed to parse metadata',
        )
        .firstWhere(
          (e) => e.resolution == resolution,
          orElse: () => throw StateError('Resolution not found: $resolution'),
        );

    // Normalization related stuff.
    // I do not like this design too much but it works.
    final expectedValueNormalizator = switch (kind) {
      _Observed() => null,
      _OverExpected() => getExpectedValues(resolution),
      _Normalized(:final normalizationType) => getExpectedValues(resolution, normalizationType),
    };

    final chrScaleNormalization = expectedValueNormalizator?.scaleFactorForChromosomeIndices(
          seqIdx1,
          seqIdx2,
        ) ??
        1.0;

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
    Iterable<int> getV8Blocks() sync* {
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

    for (final flatBlockIndex in getV8Blocks()) {
      final region = blockIndex[flatBlockIndex];
      if (region == null) continue;

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
      final blockBuffer = ByteAccumulator.withData(Uint8List.fromList(zlib.decode(blockBytes)));
      final blockCursor = SliceCursor.collapsed();

      // ignore: unused_local_variable
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
                yield ((getInt16(blockBuffer, blockCursor) + binXOffset), (binYOffset + rowNumber));
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
              final col = i + row * w;
              yield (row + binXOffset, col + binYOffset);
            }
          },
        _ => throw StateError(
            'Invalid matrix representation: $matrixRepresentation',
          ),
      };

      for (final (binX, binY) in iterator()) {
        // PERFORMANCE: We might save some time by not parsing the number if the
        // bin is not in the range and just skipping the bytes.
        final value = useFloat ? getFloat32(blockBuffer, blockCursor) : getInt16(blockBuffer, blockCursor).toDouble();

        if (xRangeInBins.contains(binX) && yRangeInBins.contains(binY)) {
          // normalize the value if needed
          final normalizedValue = expectedValueNormalizator != null
              ? value / (expectedValueNormalizator.valueForDistance((binX - binY).abs()) * chrScaleNormalization)
              : value;

          yield CompleteParseResult.incomplete((binX, binY, normalizedValue));
        }
      }
    }
  }

  /// Quickly iterate to find the region of the file that contains the expected values
  /// (normalized if available) for the given resolution.
  /// This will add the content of the buffer to the [HiCFile] object.
  ParseIterator<List<ExpectedValues>> readExpectedValueVectors(
    ByteAccumulator buffer,
  ) sync* {
    // check that we have the normalization position
    final filePosition =
        header.expectedVectorsRegion.expect('Normalization position not found, call readMasterIndex first');

    // Expected value vectors
    final cursor = SliceCursor.collapsed();

    // Just position us at the start of the normalization data.
    yield PartialReadRequest(sourcePosition: filePosition.offset);

    // Reset the file's expected values
    final expectedValues = _expectedValues = [];

    // kinda sketchy way to minimize code duplication
    // basically:
    // null = still to read the un-normalized values and the normalized values
    // false = still to read the normalized values
    // true = done
    // TODO: Check if this is actually the best way of doing this.
    bool? normalizedRead;
    while (normalizedRead != true) {
      yield const ExactReadRequest(count: 4);
      final nExpectedValueVectors = getInt32(buffer, cursor);

      for (var i = 0; i < nExpectedValueVectors; i++) {
        buffer.clear(startAfter: cursor.position);
        cursor.reset();

        // Normalization type
        final String? thisNormalizationTypeString;
        if (normalizedRead == false) {
          yield* buffer.advanceToByte(cursor, byte: 0x00);
          thisNormalizationTypeString = getStringSlice(buffer, cursor);
        } else {
          thisNormalizationTypeString = null;
        }

        // Unit (null terminated string)
        yield* buffer.advanceToByte(cursor, byte: 0x00);
        final unit = getStringSlice(buffer, cursor);

        yield const ExactReadRequest(count: 4);
        final binSize = getInt32(buffer, cursor);

        final resolution = Resolution._(
          binSize,
          switch (unit) {
            'BP' => ResolutionType.bp,
            'FRAG' => ResolutionType.frag,
            _ => throw StateError('Invalid unit: $unit'),
          },
        );

        // EXPECTED VALUES VECTOR
        // Perf: this is terrible for performance.
        final values = <double>[];
        {
          yield const ExactReadRequest(count: 4);
          final nExpectedValues = getInt32(buffer, cursor);

          // perf: ask for all the expected values at once
          yield ExactReadRequest(count: 8 * nExpectedValues);
          for (var j = 0; j < nExpectedValues; j++) {
            final expectedValue = getFloat64(buffer, cursor);
            values.add(expectedValue);
          }
        }

        // CHR SCALE FACTORS
        // Perf: this is terrible for performance as well, would you look at that.
        final chrScaleFactors = <(int index, double scaleFactor)>[];
        {
          // Read the chrScaleFactors
          yield const ExactReadRequest(count: 4);
          final nChrScaleFactors = getInt32(buffer, cursor);

          // PERF: Ask for all the chrScaleFactors at once
          yield ExactReadRequest(count: 12 * nChrScaleFactors);
          for (var j = 0; j < nChrScaleFactors; j++) {
            final chrIndex = getInt32(buffer, cursor);
            final nValues = getFloat64(buffer, cursor);
            chrScaleFactors.add((chrIndex, nValues));
          }
        }

        expectedValues.add(
          ExpectedValues(
            values: Float64List.fromList(values),
            chrScaleFactors: chrScaleFactors,
            normalizationType: thisNormalizationTypeString,
            resolution: resolution,
          ),
        );
      }

      // If the value is null, we set it to false
      // if it is false, we set it to true.
      // TODO: Check if this is actually needed.
      normalizedRead = switch (normalizedRead) {
        null => false,
        _ => true,
      };
    }

    yield CompleteParseResult(expectedValues);
  }

  /// API: A dummy contacts iterator might be provided.
  /// To compute generally expected values, independently of the observed contacts.
  Iterable<ContactRecord> normalizeContacts(
    Iterable<ContactRecord> contacts,
    ExpectedValues data,
    GenomicRange xRange,
    GenomicRange yRange,
  ) sync* {
    final header = this.header;

    final (_, chr1ScaleFactor) = data.chrScaleFactors
        .firstWhereOrNull(
          (e) => e.$1 == header.genome.indexOf(xRange.chromosomeName),
        )
        .expect(
          'Scale Factor not found for: ${xRange.chromosomeName}',
        );

    final (_, chr2ScaleFactor) = data.chrScaleFactors
        .firstWhereOrNull(
          (e) => e.$1 == header.genome.indexOf(yRange.chromosomeName),
        )
        .expect(
          'Scale Factor not found for: ${yRange.chromosomeName}',
        );

    // Loop over the contacts and normalize them.
    for (final (binX, binY, value) in contacts) {
      // is this correct? who knows, I think so.
      final expectedValueBasedOnDistance = data.valueForDistance(
        (binX - binY).abs(),
      );

      yield (
        binX,
        binY,

        // divide the value by the expected value based on distance
        // TODO: this might produce a NaN if the expected value is 0
        // so maybe handle that case...
        (value / (expectedValueBasedOnDistance * chr1ScaleFactor * chr2ScaleFactor))
      );
    }
  }
}

final class ExpectedValues {
  final String? normalizationType;
  final Resolution resolution;
  final Float64List values;
  final List<(int index, double scaleFactor)> chrScaleFactors;

  ExpectedValues({
    required this.values,
    required this.chrScaleFactors,
    this.normalizationType,
    required this.resolution,
  });

  double valueForDistance(int distance) => values[distance.clamp(0, values.length - 1)];

  double scaleFactorForChromosomeIndices(int chr1, int chr2) =>
      chrScaleFactors
          .firstWhereOrNull(
            (e) => e.$1 == chr1,
          )
          .expect(
            'Scale Factor not found for: $chr1',
          )
          .$2 *
      chrScaleFactors
          .firstWhereOrNull(
            (e) => e.$1 == chr2,
          )
          .expect(
            'Scale Factor not found for: $chr2',
          )
          .$2;
}

sealed class ContactsKind {
  const ContactsKind();
  static const observed = _Observed();
  static const overExpected = _OverExpected();
  factory ContactsKind.normalized(String normalizationType) => _Normalized(normalizationType);
}

final class _Observed extends ContactsKind {
  const _Observed();
}

/// TODO: find a better name for this.
final class _OverExpected extends ContactsKind {
  const _OverExpected();
}

final class _Normalized extends ContactsKind {
  final String normalizationType;
  const _Normalized(this.normalizationType);
}

/// Below here I have thrown some utility functions that I have used
/// to validate and pase data. They might or might not stick around
/// to the final version of the library. Though, if they do, they will
/// probably be moved to a separate file, or more likely a custom
/// package.
///

/// The only reason I have this function is to avoid the following syntax,
/// which I find not particularly pleasant:
/// ```dart
/// value = value ?? (throw StateError('Value is null'));
/// ```
@pragma('vm:prefer-inline')
Never _throwStateError(String message) => throw StateError(message);

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
  Y validate<Y, E extends Error>(MapValidator<T, Y, E> validator) => validator(this);
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
