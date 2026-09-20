import 'package:flutter_test/flutter_test.dart';
import 'package:bio_flutter/src/structure/cif/cif_document.dart';
import 'package:bio_flutter/src/structure/mmcif/atom_site_reader.dart';
import 'package:bio_flutter/src/structure/model/residue.dart';

AtomSiteResult _read(String cif) =>
    readAtomSite(parseCifDocument(cif).firstBlock!);

void main() {
  group('readAtomSite: model selection', () {
    test('keeps only the first model number encountered when the column is present', () {
      final result = _read('''
data_TEST
loop_
_atom_site.group_PDB
_atom_site.id
_atom_site.type_symbol
_atom_site.label_atom_id
_atom_site.label_asym_id
_atom_site.label_entity_id
_atom_site.auth_asym_id
_atom_site.auth_seq_id
_atom_site.Cartn_x
_atom_site.Cartn_y
_atom_site.Cartn_z
_atom_site.pdbx_PDB_model_num
ATOM 1 C CA A 1 A 1 1.0 1.0 1.0 1
ATOM 2 C CA A 1 A 1 9.0 9.0 9.0 2
loop_
_entity.id
_entity.type
1 polymer
loop_
_entity_poly.entity_id
_entity_poly.type
1 polypeptide(L)
''');
      final atoms = result.chains.single.residues.single.atoms;
      expect(atoms, hasLength(1));
      expect(atoms.single.position.x, 1.0);
    });

    test(
      'missing pdbx_PDB_model_num column means "one implicit model", not empty',
      () {
        final result = _read('''
data_TEST
loop_
_atom_site.group_PDB
_atom_site.id
_atom_site.type_symbol
_atom_site.label_atom_id
_atom_site.label_asym_id
_atom_site.label_entity_id
_atom_site.auth_asym_id
_atom_site.auth_seq_id
_atom_site.Cartn_x
_atom_site.Cartn_y
_atom_site.Cartn_z
ATOM 1 C CA A 1 A 1 1.0 1.0 1.0
loop_
_entity.id
_entity.type
1 polymer
loop_
_entity_poly.entity_id
_entity_poly.type
1 polypeptide(L)
''');
        expect(result.chains, hasLength(1));
        expect(result.chains.single.residues, hasLength(1));
      },
    );
  });

  group('readAtomSite: coordinates', () {
    test(
      'an unparsable coordinate drops the atom, never defaults to the origin',
      () {
        final result = _read('''
data_TEST
loop_
_atom_site.group_PDB
_atom_site.id
_atom_site.type_symbol
_atom_site.label_atom_id
_atom_site.label_asym_id
_atom_site.label_entity_id
_atom_site.auth_asym_id
_atom_site.auth_seq_id
_atom_site.Cartn_x
_atom_site.Cartn_y
_atom_site.Cartn_z
ATOM 1 C N  A 1 A 1 ?   1.0 1.0
ATOM 2 C CA A 1 A 1 2.0 2.0 2.0
loop_
_entity.id
_entity.type
1 polymer
loop_
_entity_poly.entity_id
_entity_poly.type
1 polypeptide(L)
''');
        final atoms = result.chains.single.residues.single.atoms;
        expect(atoms, hasLength(1));
        expect(atoms.single.atomName, 'CA');
        expect(result.warnings, isNotEmpty);
      },
    );
  });

  group('readAtomSite: alternate locations', () {
    test('keeps the highest-occupancy conformer even when it is not label_alt_id A', () {
      final result = _read('''
data_TEST
loop_
_atom_site.group_PDB
_atom_site.id
_atom_site.type_symbol
_atom_site.label_atom_id
_atom_site.label_alt_id
_atom_site.label_asym_id
_atom_site.label_entity_id
_atom_site.auth_asym_id
_atom_site.auth_seq_id
_atom_site.Cartn_x
_atom_site.Cartn_y
_atom_site.Cartn_z
_atom_site.occupancy
ATOM 1 C CA A A 1 A 1 1.0 1.0 1.0 0.30
ATOM 2 C CA B A 1 A 1 9.0 9.0 9.0 0.70
loop_
_entity.id
_entity.type
1 polymer
loop_
_entity_poly.entity_id
_entity_poly.type
1 polypeptide(L)
''');
      final atoms = result.chains.single.residues.single.atoms;
      expect(atoms, hasLength(1));
      expect(atoms.single.position.x, 9.0); // conformer B, higher occupancy
    });

    test('ties keep the first row in file order', () {
      final result = _read('''
data_TEST
loop_
_atom_site.group_PDB
_atom_site.id
_atom_site.type_symbol
_atom_site.label_atom_id
_atom_site.label_alt_id
_atom_site.label_asym_id
_atom_site.label_entity_id
_atom_site.auth_asym_id
_atom_site.auth_seq_id
_atom_site.Cartn_x
_atom_site.Cartn_y
_atom_site.Cartn_z
_atom_site.occupancy
ATOM 1 C CA A A 1 A 1 1.0 1.0 1.0 0.50
ATOM 2 C CA B A 1 A 1 9.0 9.0 9.0 0.50
loop_
_entity.id
_entity.type
1 polymer
loop_
_entity_poly.entity_id
_entity_poly.type
1 polypeptide(L)
''');
      expect(result.chains.single.residues.single.atoms.single.position.x, 1.0);
    });
  });

  group('readAtomSite: chain grouping and ordering', () {
    test('groups by label_asym_id, keeping polymer and hetero apart under one auth_asym_id', () {
      // Mirrors the verified 2QLE shape: polymer (entity 1, label A) and a
      // ligand (entity 2, label E) share auth_asym_id A.
      final result = _read('''
data_TEST
loop_
_atom_site.group_PDB
_atom_site.id
_atom_site.type_symbol
_atom_site.label_atom_id
_atom_site.label_asym_id
_atom_site.label_entity_id
_atom_site.auth_asym_id
_atom_site.auth_seq_id
_atom_site.Cartn_x
_atom_site.Cartn_y
_atom_site.Cartn_z
ATOM   1 C CA A 1 A 1 1.0 1.0 1.0
HETATM 2 O O  E 2 A 1 2.0 2.0 2.0
loop_
_entity.id
_entity.type
1 polymer
2 non-polymer
loop_
_entity_poly.entity_id
_entity_poly.type
1 polypeptide(L)
''');
      expect(result.chains, hasLength(1));
      expect(result.chains.single.id, 'A');
      expect(result.chains.single.residues, hasLength(1));
    });

    test('a HETATM-flagged residue within a polymer entity is kept (the GFP chromophore case)', () {
      final result = _read('''
data_TEST
loop_
_atom_site.group_PDB
_atom_site.id
_atom_site.type_symbol
_atom_site.label_atom_id
_atom_site.label_asym_id
_atom_site.label_entity_id
_atom_site.auth_asym_id
_atom_site.auth_seq_id
_atom_site.Cartn_x
_atom_site.Cartn_y
_atom_site.Cartn_z
ATOM   1 C CA A 1 A 65 1.0 1.0 1.0
HETATM 2 C CA A 1 A 66 2.0 2.0 2.0
ATOM   3 C CA A 1 A 67 3.0 3.0 3.0
loop_
_entity.id
_entity.type
1 polymer
loop_
_entity_poly.entity_id
_entity_poly.type
1 polypeptide(L)
''');
      expect(result.chains.single.residues, hasLength(3));
      expect(result.chains.single.residues.map((r) => r.id.authSeqId), [
        65,
        66,
        67,
      ]);
    });

    test('without any entity categories, falls back to the group-contains-ATOM heuristic', () {
      final result = _read('''
data_TEST
loop_
_atom_site.group_PDB
_atom_site.id
_atom_site.type_symbol
_atom_site.label_atom_id
_atom_site.label_asym_id
_atom_site.auth_asym_id
_atom_site.auth_seq_id
_atom_site.Cartn_x
_atom_site.Cartn_y
_atom_site.Cartn_z
ATOM   1 C CA A A 1 1.0 1.0 1.0
HETATM 2 O O  E A 2 2.0 2.0 2.0
''');
      expect(result.chains, hasLength(1));
      expect(result.chains.single.id, 'A');
      expect(result.warnings, isNotEmpty);
    });

    test('a pure-HETATM group with no ATOM rows is excluded by the fallback heuristic', () {
      final result = _read('''
data_TEST
loop_
_atom_site.group_PDB
_atom_site.id
_atom_site.type_symbol
_atom_site.label_atom_id
_atom_site.label_asym_id
_atom_site.auth_asym_id
_atom_site.auth_seq_id
_atom_site.Cartn_x
_atom_site.Cartn_y
_atom_site.Cartn_z
HETATM 1 O O E A 1 1.0 1.0 1.0
''');
      expect(result.chains, isEmpty);
    });

    test('residues keep file order, not numeric order', () {
      final result = _read('''
data_TEST
loop_
_atom_site.group_PDB
_atom_site.id
_atom_site.type_symbol
_atom_site.label_atom_id
_atom_site.label_asym_id
_atom_site.label_entity_id
_atom_site.auth_asym_id
_atom_site.auth_seq_id
_atom_site.Cartn_x
_atom_site.Cartn_y
_atom_site.Cartn_z
ATOM 1 C CA A 1 A 5 1.0 1.0 1.0
ATOM 2 C CA A 1 A 3 2.0 2.0 2.0
ATOM 3 C CA A 1 A 4 3.0 3.0 3.0
loop_
_entity.id
_entity.type
1 polymer
loop_
_entity_poly.entity_id
_entity_poly.type
1 polypeptide(L)
''');
      expect(result.chains.single.residues.map((r) => r.id.authSeqId), [
        5,
        3,
        4,
      ]);
    });

    test('insertion codes distinguish residues sharing a sequence number', () {
      final result = _read('''
data_TEST
loop_
_atom_site.group_PDB
_atom_site.id
_atom_site.type_symbol
_atom_site.label_atom_id
_atom_site.label_asym_id
_atom_site.label_entity_id
_atom_site.auth_asym_id
_atom_site.auth_seq_id
_atom_site.pdbx_PDB_ins_code
_atom_site.Cartn_x
_atom_site.Cartn_y
_atom_site.Cartn_z
ATOM 1 C CA A 1 A 82 ? 1.0 1.0 1.0
ATOM 2 C CA A 1 A 82 A 2.0 2.0 2.0
loop_
_entity.id
_entity.type
1 polymer
loop_
_entity_poly.entity_id
_entity_poly.type
1 polypeptide(L)
''');
      final ids = result.chains.single.residues.map((r) => r.id).toList();
      expect(ids, [const ResidueId(82, ''), const ResidueId(82, 'A')]);
    });
  });

  group('readAtomSite: malformed rows', () {
    test('a row missing label_asym_id is skipped, not fatal', () {
      final result = _read('''
data_TEST
loop_
_atom_site.group_PDB
_atom_site.id
_atom_site.type_symbol
_atom_site.label_atom_id
_atom_site.label_entity_id
_atom_site.auth_asym_id
_atom_site.auth_seq_id
_atom_site.Cartn_x
_atom_site.Cartn_y
_atom_site.Cartn_z
ATOM 1 C CA 1 A 1 1.0 1.0 1.0
''');
      expect(result.chains, isEmpty);
      expect(result.warnings, isNotEmpty);
    });

    test(
      'no atom_site category at all produces an empty, non-throwing result',
      () {
        final result = readAtomSite(
          parseCifDocument('data_TEST\n_entry.id X\n').firstBlock!,
        );
        expect(result.chains, isEmpty);
        expect(result.warnings, isNotEmpty);
      },
    );
  });
}
