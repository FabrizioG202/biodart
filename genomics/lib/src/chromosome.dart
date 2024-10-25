import 'package:genomics/src/genomic_range.dart';
import 'package:meta/meta.dart';

/// Represents a chromosome or other genomic sequence with its length.
///
/// Provides a type-safe way to handle chromosome information.
/// Can be extended by implementations, if more information is needed,
/// for a particular genome assembly.
@immutable
class Chromosome {
  /// Creates a new chromosome with the specified name and length.
  ///
  /// [name] typically follows standard nomenclature (e.g., 'chr1', 'chrX').
  /// [length] is the number of base pairs in the sequence.
  const Chromosome({
    required this.name,
    required this.length,
  });

  /// The name or identifier of the chromosome (e.g., 'chr1', 'chrX').
  final String name;

  /// The length of the chromosome in base pairs.
  final int length;

  /// Creates a Chromosome instance from a (String, int) record.
  factory Chromosome.fromRecord((String, int) record) =>
      Chromosome(name: record.$1, length: record.$2);

  /// Converts the chromosome to a (String, int) record.
  (String, int) toRecord() => (name, length);

  /// Creates a [GenomicRange], representing this range (
  /// with optional start and end positions).
  GenomicRange asRange({int start = 1, int? end}) =>
      GenomicRange(name, start, end ?? length);

  @override
  String toString() => 'Chromosome($name: $length bp)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Chromosome &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          length == other.length;

  @override
  int get hashCode => Object.hash(name, length);

  /// Creates a copy of this Chromosome with the given fields replaced with new values.
  Chromosome copyWith({
    String? name,
    int? length,
  }) =>
      Chromosome(
        name: name ?? this.name,
        length: length ?? this.length,
      );
}
