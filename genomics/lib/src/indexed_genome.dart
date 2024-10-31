import 'package:genomics/src/chromosome.dart';
import 'package:genomics/src/genome_reference.dart';
import 'package:meta/meta.dart';

/// An immutable implementation of a genome reference that stores chromosomes
/// in an indexed list for efficient access by both name and position.
@immutable
class IndexedGenome with GenomeReference {
  /// Creates an indexed genome from a list of chromosome records.
  ///
  /// The list should contain tuples of (chromosome name, length).
  /// The order of chromosomes in the list is preserved.
  ///
  /// ```dart
  /// final genome = IndexedGenome.fromChromosomeList([
  ///   ('chr1', 248956422),
  ///   ('chr2', 242193529),
  ///   ('chrX', 156040895),
  /// ]);
  /// ```
  IndexedGenome.fromChromosomeList(
    List<(String name, int length)> chromosomeList,
  ) : _chromosomes = List.unmodifiable(
          chromosomeList.map((record) => Chromosome.fromRecord(record)),
        );

  /// Creates an indexed genome from a list of Chromosome objects.
  ///
  /// ```dart
  /// final genome = IndexedGenome.fromChromosomes([
  ///   Chromosome(name: 'chr1', length: 248956422),
  ///   Chromosome(name: 'chr2', length: 242193529),
  ///   Chromosome(name: 'chrX', length: 156040895),
  /// ]);
  /// ```
  IndexedGenome.fromChromosomes(
    List<Chromosome> chromosomes,
  ) : _chromosomes = List.unmodifiable(chromosomes);

  /// The internal list of chromosomes.
  final List<Chromosome> _chromosomes;

  /// Returns the index of a chromosome by name.
  ///
  /// Throws [ArgumentError] if the chromosome is not found.
  int indexOf(String chromosomeName) {
    final index = _chromosomes.indexWhere(
      (chr) => chr.name == chromosomeName,
    );
    if (index == -1) {
      throw ArgumentError.value(
        chromosomeName,
        'chromosomeName',
        'Chromosome not found in genome',
      );
    }
    return index;
  }

  /// Returns the length of the chromosome at the given index.
  ///
  /// Returns null if the index is out of bounds.
  int? lengthAt(int index) {
    if (index >= 0 && index < _chromosomes.length) {
      return _chromosomes[index].length;
    }
    return null;
  }

  /// Returns the name of the chromosome at the given index.
  ///
  /// Returns null if the index is out of bounds.
  String? nameAt(int index) {
    if (index >= 0 && index < _chromosomes.length) {
      return _chromosomes[index].name;
    }
    return null;
  }

  /// Returns true if the index is valid for this genome.
  bool containsIndex(int index) => index >= 0 && index < _chromosomes.length;

  @override
  Map<String, int> get sizeMap => Map.unmodifiable(
        Map.fromEntries(
          _chromosomes.map(
            (chr) => MapEntry(chr.name, chr.length),
          ),
        ),
      );

  @override
  List<Chromosome> get chromosomes => _chromosomes;

  @override
  String toString() => 'IndexedGenome($_chromosomes)';
}
