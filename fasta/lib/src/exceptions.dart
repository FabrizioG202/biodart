// Copyright (c) 2024 Fabrizio Guidotti
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

/// Base class for all exceptions thrown by this library.
/// TODO: Create more specific exceptions for different error types.
class FastaFormatException implements Exception {
  const FastaFormatException(this.message);

  final String message;

  @override
  String toString() => 'FastaFormatException: $message';
}
