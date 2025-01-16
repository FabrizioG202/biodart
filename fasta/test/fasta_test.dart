import 'dart:io';
import 'package:fasta/fasta.dart';
import 'package:readers/readers.dart';
import 'package:test/test.dart';

void main() {
  const expectedSequences = [
    ('>sequence1', 'ATCGTAGCTAGCTAGCTAGCTAGCTA', 26),
    ('>sequence2', 'GGCATCGATCGATCGATCGATT', 22),
    ('>sequence3', 'TTAGGCGTAGCTAGCATCGGTA', 22),
  ];

  void runParserTests(
    String filename,
    ParserGenerator<FastaRecordMixin> parser,
  ) {
    late SyncFileSource source;
    late List<FastaRecordMixin> sequences;

    setUp(() {
      source = SyncFileSource(File('test/data/$filename'))..open();
      sequences = parseSync(parser, source).toList();
    });

    tearDown(() => source.close());

    test('parses all sequences correctly', () {
      expect(sequences.length, equals(expectedSequences.length));

      for (var i = 0; i < sequences.length; i++) {
        final seq = sequences[i];
        final (header, sequence, length) = expectedSequences[i];
        expect(seq.getHeader(), equals(header));
        expect(seq.getSequence(), equals(sequence));
        expect(seq.getSequence().length, equals(length));
      }
    });
  }

  group('Uncompressed FASTA', () {
    runParserTests('fasta1.fa', iterateReads);
  });

  group('Compressed FASTA', () {
    runParserTests('fasta1.fa.gz', (b) => zlibDecode(b, iterateReads));
  });

  group('Error Handling', () {
    test('throws on missing file', () {
      final badSource = SyncFileSource(File('non_existent.fa'));
      expect(() => badSource.open(), throwsA(isA<FileSystemException>()));
    });

    // TODO (?) Exceptions have not been implemented with the new
    // parser.
    // test('throws on missing initial header', () {
    //   final source = SyncFileSource(File('test/data/broken1.fa'))..open();
    //   expect(
    //     () => parseSync(yieldReads, source).toList(),
    //     throwsA(
    //       isA<Exception>().having(
    //         (e) => e.toString(),
    //         'message',
    //         contains('Found sequence data before header'),
    //       ),
    //     ),
    //   );
    //   source.close();
    // });

    // TODO (?) Exceptions have not been implemented with the new
    // parser.
    // test('throws on empty sequence', () {
    //   final source = SyncFileSource(File('test/data/broken2.fa'))..open();
    //   expect(
    //     () => parseSync(yieldReads, source).toList(),
    //     throwsA(
    //       isA<FastaFormatException>().having(
    //         (e) => e.toString(),
    //         'message',
    //         contains('empty sequence'),
    //       ),
    //     ),
    //   );
    //   source.close();
    // });
  });
}
