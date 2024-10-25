/// Represents the orientation of a DNA/RNA strand or genomic feature.
///
/// In genomics, strand information indicates whether a feature is located on the:
/// * Forward/plus/positive (+) strand
/// * Reverse/minus/negative (-) strand
/// * Or if the strand is unknown/unspecified (.)
enum Strand {
  /// Forward/plus strand (+)
  ///
  /// Represents the 5' → 3' direction matching the reference genome.
  positive(symbol: '+', label: 'forward'),

  /// Reverse/minus strand (-)
  ///
  /// Represents the 5' → 3' direction opposite to the reference genome.
  negative(symbol: '-', label: 'reverse'),

  /// Unknown or unspecified strand (.)
  ///
  /// Used when strand information is not applicable or unknown.
  unspecified(symbol: '.', label: 'unspecified');

  /// Creates a new strand value.
  const Strand({
    required this.symbol,
    required this.label,
  });

  /// The standard symbol used in genomic formats ('+', '-', or '.').
  final String symbol;

  /// A human-readable label for the strand.
  final String label;

  /// Creates a Strand from its standard symbol.
  ///
  /// ```dart
  /// final strand = Strand.fromSymbol('+'); // Returns Strand.positive
  /// ```
  ///
  /// Throws [ArgumentError] if the symbol is not valid.
  static Strand fromSymbol(String symbol) {
    return switch (tryFromSymbol(symbol)) {
      final strand? => strand,
      null => throw ArgumentError.value(
          symbol,
          'symbol',
          'Invalid strand symbol. Use "+", "-", or "."',
        ),
    };
  }

  /// Attempts to create a Strand from its standard symbol.
  ///
  /// ```dart
  /// final strand = Strand.tryFromSymbol('+'); // Returns Strand.positive
  /// final invalid = Strand.tryFromSymbol('x'); // Returns null
  /// ```
  static Strand? tryFromSymbol(String symbol) {
    return switch (symbol) {
      '+' => Strand.positive,
      '-' => Strand.negative,
      '.' => Strand.unspecified,
      _ => null,
    };
  }

  /// Returns true if the strand is specified (positive or negative).
  bool get isSpecified => this != Strand.unspecified;

  /// Returns the complementary strand.
  ///
  /// ```dart
  /// final complement = Strand.positive.complement; // Returns Strand.negative
  /// ```
  ///
  /// Returns [Strand.unspecified] if the current strand is unspecified.
  Strand get complement => switch (this) {
        Strand.positive => Strand.negative,
        Strand.negative => Strand.positive,
        Strand.unspecified => Strand.unspecified,
      };

  /// Returns true if this strand is the complement of the other strand.
  ///
  /// ```dart
  /// Strand.positive.isComplementOf(Strand.negative); // Returns true
  /// ```
  bool isComplementOf(Strand other) =>
      isSpecified && other.isSpecified && this == other.complement;

  /// Returns a single-character representation of the strand.
  @override
  String toString() => symbol;
}

/// Extension to parse strand information from common string representations
extension StrandParsing on String {
  /// Converts a string to a Strand.
  ///
  /// Accepts various common representations:
  /// * '+', 'plus', 'forward', '1' for positive strand
  /// * '-', 'minus', 'reverse', '-1' for negative strand
  /// * '.', 'none', 'unspecified', '0' for unspecified strand
  ///
  /// ```dart
  /// '+'.toStrand();     // Returns Strand.positive
  /// 'forward'.toStrand(); // Returns Strand.positive
  /// ```
  ///
  /// Throws [FormatException] if the string is not a valid strand representation.
  Strand toStrand() {
    final lower = toLowerCase().trim();
    return switch (lower) {
      '+' || 'plus' || 'forward' || '1' => Strand.positive,
      '-' || 'minus' || 'reverse' || '-1' => Strand.negative,
      '.' || 'none' || 'unspecified' || '0' => Strand.unspecified,
      _ => throw FormatException('Invalid strand representation: $this'),
    };
  }

  /// Attempts to convert a string to a Strand.
  ///
  /// ```dart
  /// '+'.tryToStrand();     // Returns Strand.positive
  /// 'invalid'.tryToStrand(); // Returns null
  /// ```
  ///
  /// TODO-EASYFIX: Make this API match the one we use in Strand type,
  /// where to... wraps tryFrom... and throws an error if null.
  Strand? tryToStrand() {
    try {
      return toStrand();
    } on FormatException {
      return null;
    }
  }
}
