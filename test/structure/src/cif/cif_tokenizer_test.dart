import 'package:flutter_test/flutter_test.dart';
import 'package:bio_flutter/src/structure/cif/cif_token.dart';
import 'package:bio_flutter/src/structure/cif/cif_tokenizer.dart';

void main() {
  group('tokenizeCif', () {
    test('splits unquoted whitespace-delimited words', () {
      final tokens = tokenizeCif('foo bar\tbaz\nqux');
      expect(tokens.map((t) => t.text), ['foo', 'bar', 'baz', 'qux']);
      expect(tokens.every((t) => t.kind == CifTokenKind.word), isTrue);
    });

    test('keeps an internal apostrophe as part of an unquoted word (O5\')', () {
      final tokens = tokenizeCif("_atom_site.label_atom_id O5'");
      expect(tokens.last.kind, CifTokenKind.word);
      expect(tokens.last.text, "O5'");
    });

    test('quoted value: closing quote must be followed by whitespace/EOL', () {
      // The apostrophe in "it's" is not followed by whitespace, so it does
      // not close the string; only the final apostrophe (followed by EOL)
      // does.
      final tokens = tokenizeCif("'it's fine'");
      expect(tokens, hasLength(1));
      expect(tokens.single.kind, CifTokenKind.quoted);
      expect(tokens.single.text, "it's fine");
    });

    test('double-quoted value may contain an unescaped single quote', () {
      final tokens = tokenizeCif('"5\' end"');
      expect(tokens.single.kind, CifTokenKind.quoted);
      expect(tokens.single.text, "5' end");
    });

    test('a quoted value that looks like a tag is still just data', () {
      final tokens = tokenizeCif("'_entry.id'");
      expect(tokens.single.kind, CifTokenKind.quoted);
      expect(tokens.single.text, '_entry.id');
    });

    test('text field: ";" at true column 1 opens and closes it', () {
      final tokens = tokenizeCif(
        '_entity_poly.pdbx_seq_one_letter_code\n;MKT\nAYI\n;\n_entity_poly.type polymer',
      );
      expect(tokens[0].text, '_entity_poly.pdbx_seq_one_letter_code');
      expect(tokens[1].kind, CifTokenKind.textField);
      expect(tokens[1].text, 'MKT\nAYI');
      expect(tokens[2].text, '_entity_poly.type');
      expect(tokens[3].text, 'polymer');
    });

    test('a ";" not at column 1 does not open a text field', () {
      final tokens = tokenizeCif('foo ;notatextfield');
      expect(tokens.map((t) => t.text), ['foo', ';notatextfield']);
      expect(tokens.every((t) => t.kind == CifTokenKind.word), isTrue);
    });

    test(
      'text field content preserves leading whitespace, strips trailing',
      () {
        final tokens = tokenizeCif(';  indented line  \nsecond\n;\n');
        expect(tokens.single.text, '  indented line\nsecond');
      },
    );

    test('comment runs to end of line and is discarded', () {
      final tokens = tokenizeCif('foo # a comment with words\nbar');
      expect(tokens.map((t) => t.text), ['foo', 'bar']);
    });

    test('comment inside a would-be data stream does not become a token', () {
      final tokens = tokenizeCif('a b\n# comment\nc d');
      expect(tokens.map((t) => t.text), ['a', 'b', 'c', 'd']);
    });

    test('unquoted "?" and "." are ordinary word tokens (null-ness is the assembler\'s job)', () {
      final tokens = tokenizeCif('? .');
      expect(tokens.map((t) => t.text), ['?', '.']);
      expect(tokens.every((t) => t.isNullMarker), isTrue);
    });

    test('a quoted "." is not a null marker', () {
      final tokens = tokenizeCif("'.'");
      expect(tokens.single.isNullMarker, isFalse);
      expect(tokens.single.text, '.');
    });

    test('CRLF line endings are normalized', () {
      final tokens = tokenizeCif('foo\r\nbar');
      expect(tokens.map((t) => t.text), ['foo', 'bar']);
    });
  });
}
