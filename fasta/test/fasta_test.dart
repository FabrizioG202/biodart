// // Copyright (c) 2024 Fabrizio Guidotti
// //
// // This software is released under the MIT License.
// // https://opensource.org/licenses/MIT

import 'dart:io';
import 'package:fasta/fasta.dart';
import 'package:readers/readers.dart';
import 'package:test/test.dart';

void main() {
  group('FASTA Parser Tests', () {
    late SyncFileSource source;
    late List<FastaRead> sequences;

    setUp(() {
      source = SyncFileSource(File('test/data/fasta1.fa'))..open();
      sequences = parseSync(readEntries, source).toList();
    });

    tearDown(() {
      source.close();
    });

    test('reads correct number of sequences', () {
      expect(sequences.length, equals(3));
    });

    test('parses headers correctly', () {
      expect(sequences[0].header, equals('sequence1'));
      expect(sequences[1].header, equals('sequence2'));
      expect(sequences[2].header, equals('sequence3'));
    });

    test('handles multi-line sequences', () {
      expect(sequences[0].sequence, equals('ATCGTAGCTAGCTAGCTAGCTAGCTA'));
      expect(sequences[2].sequence, equals('TTAGGCGTAGCTAGCATCGGTA'));
    });

    test('sequence lengths are correct', () {
      expect(sequences[0].length, equals(26));
      expect(sequences[1].length, equals(22));
      expect(sequences[2].length, equals(22));
    });

    test('throws on missing file', () {
      final badSource = SyncFileSource(File('non_existent.fa'));
      expect(
        () => badSource.open(),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('parses individual sequences', () {
      var count = 0;
      for (final seq in sequences) {
        expect(seq.header, isNotEmpty);
        expect(seq.sequence, isNotEmpty);
        count++;
      }
      expect(count, equals(3));
    });
  });

  group('FASTA Error Handling', () {
    test('throws on missing initial header', () {
      final source = SyncFileSource(File('test/data/broken1.fa'))..open();
      expect(
        () => parseSync(readEntries, source).toList(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Found sequence data before header'),
          ),
        ),
      );
      source.close();
    });

    test('throws on empty sequence', () {
      final source = SyncFileSource(File('test/data/broken2.fa'))..open();
      expect(
        () => parseSync(readEntries, source).toList(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Empty sequence for header'),
          ),
        ),
      );
      source.close();
    });
  });
}
