import 'package:genomics/src/strand.dart';
import 'package:meta/meta.dart';

/// Represents a genomic interval on a specific chromosome.
///
/// A GenomicRange represents a continuous region on a chromosome with:
/// * Chromosome name (e.g., 'chr1')
/// * Start position (1-based, inclusive)
/// * End position (1-based, inclusive)
/// * Strand information (optional)
@immutable
base class GenomicRange {
  /// Creates a genomic range with the specified coordinates.
  ///
  /// [chromosomeName] is the name of the chromosome (e.g., 'chr1')
  /// [start] is the start position (1-based, inclusive)
  /// [end] is the end position (1-based, inclusive)
  /// [strand] is the strand orientation (defaults to unspecified)
  const GenomicRange(
    this.chromosomeName,
    this.start,
    this.end, {
    this.strand = Strand.unspecified,
  })  : assert(start <= end, 'Start must be less than or equal to end'),
        assert(start >= 1, 'Start position must be positive (1-based)');

  /// The name of the chromosome this range is on.
  final String chromosomeName;

  /// The start position (1-based, inclusive).
  final int start;

  /// The end position (1-based, inclusive).
  final int end;

  /// The strand orientation of this range.
  final Strand strand;

  /// The length of this range in base pairs.
  int get length => end - start + 1;

  /// Returns true if this range contains the specified position.
  bool contains(int position) => position >= start && position <= end;

  /// Returns a copy of this range with the specified fields replaced.
  GenomicRange copyWith({
    String? chromosomeName,
    int? start,
    int? end,
    Strand? strand,
  }) {
    return GenomicRange(
      chromosomeName ?? this.chromosomeName,
      start ?? this.start,
      end ?? this.end,
      strand: strand ?? this.strand,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GenomicRange &&
          runtimeType == other.runtimeType &&
          chromosomeName == other.chromosomeName &&
          start == other.start &&
          end == other.end &&
          strand == other.strand;

  @override
  int get hashCode =>
      chromosomeName.hashCode ^ start.hashCode ^ end.hashCode ^ strand.hashCode;

  @override
  String toString() =>
      'GenomicRange($chromosomeName:$start-$end${strand.isSpecified ? " ${strand.symbol}" : ""})';
}
