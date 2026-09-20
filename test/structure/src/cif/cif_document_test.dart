import 'package:flutter_test/flutter_test.dart';
import 'package:bio_flutter/src/structure/cif/cif_document.dart';

void main() {
  group('parseCifDocument', () {
    test('loop_ category: multiple rows, lowercased columns', () {
      final doc = parseCifDocument('''
data_TEST
loop_
_atom_site.id
_atom_site.label_atom_id
1 N
2 CA
''');
      final rows = doc.firstBlock!.category('atom_site')!.rows;
      expect(rows, hasLength(2));
      expect(rows[0]['id'], '1');
      expect(rows[0]['label_atom_id'], 'N');
      expect(rows[1]['id'], '2');
      expect(rows[1]['label_atom_id'], 'CA');
    });

    test('single-row (non-loop) key-value category — the #12 fix', () {
      // A structure with exactly one helix legally writes struct_conf like
      // this instead of as a loop_. Prior Dart attempts silently produced
      // zero rows for this; this must produce exactly one.
      final doc = parseCifDocument('''
data_TEST
_struct_conf.id HELX1
_struct_conf.conf_type_id HELX_P
_struct_conf.beg_auth_seq_id 10
_struct_conf.end_auth_seq_id 20
''');
      final rows = doc.firstBlock!.category('struct_conf')!.rows;
      expect(rows, hasLength(1));
      expect(rows.single['conf_type_id'], 'HELX_P');
      expect(rows.single['beg_auth_seq_id'], '10');
      expect(rows.single['end_auth_seq_id'], '20');
    });

    test('a multi-line text field as one loop_ cell', () {
      final doc = parseCifDocument('''
data_TEST
loop_
_entity_poly.entity_id
_entity_poly.pdbx_seq_one_letter_code
1
;MKTAYI
AKQRQ
;
''');
      final rows = doc.firstBlock!.category('entity_poly')!.rows;
      expect(rows, hasLength(1));
      expect(rows.single['pdbx_seq_one_letter_code'], 'MKTAYI\nAKQRQ');
    });

    test(
      'unquoted apostrophe inside an atom name survives a real loop_ row',
      () {
        final doc = parseCifDocument('''
data_TEST
loop_
_atom_site.id
_atom_site.label_atom_id
1 O5'
''');
        expect(
          doc.firstBlock!.category('atom_site')!.rows.single["label_atom_id"],
          "O5'",
        );
      },
    );

    test('quoted value containing an embedded, non-closing quote', () {
      final doc = parseCifDocument('''
data_TEST
_struct.title 'it's a test'
''');
      expect(
        doc.firstBlock!.category('struct')!.rows.single['title'],
        "it's a test",
      );
    });

    test('mixed-case tags are unified under lowercase lookup', () {
      final doc = parseCifDocument('''
data_TEST
loop_
_Atom_Site.Cartn_X
_atom_site.cartn_y
1.0 2.0
''');
      final row = doc.firstBlock!.category('atom_site')!.rows.single;
      expect(row['cartn_x'], '1.0');
      expect(row['cartn_y'], '2.0');
    });

    test('a comment in the middle of a loop_ does not break row assembly', () {
      final doc = parseCifDocument('''
data_TEST
loop_
_atom_site.id
_atom_site.label_atom_id
1 N
# a comment between rows
2 CA
''');
      final rows = doc.firstBlock!.category('atom_site')!.rows;
      expect(rows, hasLength(2));
      expect(rows[1]['label_atom_id'], 'CA');
    });

    test('two data_ blocks stay separate', () {
      final doc = parseCifDocument('''
data_FIRST
_entry.id FIRST
data_SECOND
_entry.id SECOND
''');
      expect(doc.blocks, hasLength(2));
      expect(doc.blocks[0].name, 'FIRST');
      expect(doc.blocks[0].category('entry')!.rows.single['id'], 'FIRST');
      expect(doc.blocks[1].name, 'SECOND');
      expect(doc.blocks[1].category('entry')!.rows.single['id'], 'SECOND');
    });

    test('unquoted ? and . are null; quoted ones are literal strings', () {
      final doc = parseCifDocument('''
data_TEST
loop_
_atom_site.id
_atom_site.pdbx_PDB_ins_code
1 ?
2 .
3 '.'
''');
      final rows = doc.firstBlock!.category('atom_site')!.rows;
      expect(rows[0]['pdbx_pdb_ins_code'], isNull);
      expect(rows[1]['pdbx_pdb_ins_code'], isNull);
      expect(rows[2]['pdbx_pdb_ins_code'], '.');
    });

    test(
      'a value that looks exactly like a tag is only a tag in tag position',
      () {
        final doc = parseCifDocument('''
data_TEST
loop_
_atom_site.id
_atom_site.label_comp_id
1 '_entry.id'
''');
        expect(
          doc.firstBlock!.category('atom_site')!.rows.single['label_comp_id'],
          '_entry.id',
        );
        // And it must not have been misread as starting a new category.
        expect(doc.firstBlock!.category('entry'), isNull);
      },
    );

    test('a malformed trailing partial row is dropped, not fabricated', () {
      final doc = parseCifDocument('''
data_TEST
loop_
_atom_site.id
_atom_site.label_atom_id
1 N
2
''');
      final rows = doc.firstBlock!.category('atom_site')!.rows;
      expect(rows, hasLength(1));
      expect(rows.single['id'], '1');
    });

    test('a second loop_ for the same category overwrites the first (documented last-wins)', () {
      final doc = parseCifDocument('''
data_TEST
loop_
_atom_site.id
1
2
loop_
_atom_site.id
9
''');
      expect(doc.firstBlock!.category('atom_site')!.rows, hasLength(1));
      expect(doc.firstBlock!.category('atom_site')!.rows.single['id'], '9');
    });

    test('an unknown/absent category returns null, not a throw', () {
      final doc = parseCifDocument('data_TEST\n_entry.id X\n');
      expect(doc.firstBlock!.category('atom_site'), isNull);
    });
  });
}
