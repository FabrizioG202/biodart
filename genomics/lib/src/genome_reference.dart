import 'package:genomics/src/chromosome.dart';

/// A mixin that defines the interface for working with genomic reference sequences.
///
/// This mixin provides a standardized way to interact with different genome
/// assemblies (e.g., hg19, hg38, mm10) by exposing methods and properties to
/// access chromosomes and their properties.
mixin GenomeReference {
  /// Returns a map of sequence names to their lengths.
  ///
  /// This is the primary data that implementations must provide.
  /// All other methods in this mixin derive from this map.
  Map<String, int> get sizeMap;

  /// The total number of chromosomes in this genome assembly.
  int get chromosomeCount => sizeMap.length;

  /// Returns an unmodifiable list of chromosome names.
  ///
  /// Names are typically returned in a standard order (e.g., chr1, chr2, ..., chrX, chrY).
  List<String> get chromosomeNames => List.unmodifiable(sizeMap.keys);

  /// Returns an unmodifiable list of chromosome lengths.
  ///
  /// The order corresponds to [chromosomeNames].
  List<int> get chromosomeLengths => List.unmodifiable(sizeMap.values);

  /// Returns the length of a specific chromosome by name.
  ///
  /// ```dart
  /// final chr1Length = genome['chr1']; // Returns length of chromosome 1
  /// ```
  ///
  /// Returns null if the chromosome name is not found.
  int? operator [](String chromosomeName) => sizeMap[chromosomeName];

  /// Returns a list of Chromosome objects.
  ///
  /// Useful for accessing both names and lengths with proper typing.
  /// ```dart
  /// for (final chromosome in genome.chromosomes) {
  ///   print('${chromosome.name}: ${chromosome.length} bp');
  /// }
  /// ```
  List<Chromosome> get chromosomes => List.unmodifiable(
        sizeMap.entries.map(
          (e) => Chromosome(name: e.key, length: e.value),
        ),
      );

  /// The total length of all chromosomes combined.
  int get totalLength => sizeMap.values.fold(0, (a, b) => a + b);

  /// Validates if a given chromosome name exists in this genome assembly.
  bool hasChromosome(String chromosomeName) =>
      sizeMap.containsKey(chromosomeName);

  /// Returns a Chromosome object for the given name.
  ///
  /// Throws [ArgumentError] if the chromosome is not found.
  Chromosome getChromosome(String chromosomeName) {
    final length = sizeMap[chromosomeName];
    if (length == null) {
      throw ArgumentError.value(
        chromosomeName,
        'chromosomeName',
        'Chromosome not found in genome assembly',
      );
    }
    return Chromosome(name: chromosomeName, length: length);
  }

  /// Throws if the chromosome name doesn't exist in this genome assembly.
  void validateChromosome(String chromosomeName) {
    if (!hasChromosome(chromosomeName)) {
      throw ArgumentError.value(
        chromosomeName,
        'chromosomeName',
        'Chromosome not found in genome assembly',
      );
    }
  }
}
