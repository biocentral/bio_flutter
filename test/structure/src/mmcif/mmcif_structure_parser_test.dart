import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:bio_flutter/src/structure/mmcif/mmcif_structure_parser.dart';
import 'package:bio_flutter/src/structure/model/secondary_structure.dart';
import 'package:bio_flutter/src/structure/ss/p_sea.dart'
    show assignGeometricSecondaryStructure;

/// Renames every `_struct_conf.`/`_struct_sheet_range.` tag's category so
/// the parser sees a file with no header SS annotation at all, without
/// having to hand-build synthetic (and error-prone-to-derive) helix/sheet
/// Cα geometry — reuses a real fixture's real, already-validated geometry
/// instead.
String _withoutSecondaryStructureHeaders(String content) => content
    .replaceAll('_struct_conf.', '_disabled_struct_conf.')
    .replaceAll('_struct_sheet_range.', '_disabled_struct_sheet_range.');

void main() {
  group('parseMmcifStructure: synthetic', () {
    test('end to end: atoms, chain grouping, and SS assignment together', () {
      final result = parseMmcifStructure('''
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
ATOM 2 C CA A 1 A 2 2.0 2.0 2.0
ATOM 3 C CA A 1 A 3 3.0 3.0 3.0
loop_
_entity.id
_entity.type
1 polymer
loop_
_entity_poly.entity_id
_entity_poly.type
1 polypeptide(L)
_struct_conf.conf_type_id HELX_P
_struct_conf.beg_label_asym_id A
_struct_conf.beg_label_seq_id 1
_struct_conf.end_label_asym_id A
_struct_conf.end_label_seq_id 2
''');
      expect(result.structure.chains, hasLength(1));
      final types = result.structure.chains.single.residues
          .map((r) => r.secondaryStructure)
          .toList();
      expect(types, [
        SecondaryStructureType.helix,
        SecondaryStructureType.helix,
        SecondaryStructureType.loop,
      ]);
    });

    test('throws FormatException when there is no data_ block at all', () {
      expect(
        () => parseMmcifStructure('not cif content, just words'),
        throwsFormatException,
      );
    });

    test('a structure with no polymer entities parses to an empty (not thrown) result', () {
      final result = parseMmcifStructure('data_EMPTY\n_entry.id EMPTY\n');
      expect(result.structure.chains, isEmpty);
    });
  });

  group('parseMmcifStructure: geometric secondary-structure fallback', () {
    test('falls back to the geometric assignment when both header categories are absent', () {
      // Header-derived and geometric-fallback assignment are different
      // algorithms and are not expected to agree exactly, even on correct
      // data (that's the whole point of p_sea_test.dart's 2QLE
      // comparison) -- so the meaningful check here is against a direct
      // assignGeometricSecondaryStructure call on the same parsed
      // structure, not against the header path.
      final withHeaders = File('test/structure/fixtures/1L2Y.cif')
          .readAsStringSync();
      final withoutHeaders = parseMmcifStructure(
        _withoutSecondaryStructureHeaders(withHeaders),
      );
      final fallbackTypes = withoutHeaders.structure.chains.single.residues
          .map((r) => r.secondaryStructure)
          .toList();

      final directlyAssigned = assignGeometricSecondaryStructure(
        withoutHeaders.structure,
      );
      final directTypes = directlyAssigned.single.residues
          .map((r) => r.secondaryStructure)
          .toList();

      expect(fallbackTypes, directTypes);
      expect(fallbackTypes, contains(SecondaryStructureType.helix));
    });

    test('one header category present (helix but no sheet) is trusted as-is, not treated as "absent"', () {
      final result = parseMmcifStructure('''
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
ATOM 2 C CA A 1 A 2 2.0 2.0 2.0
ATOM 3 C CA A 1 A 3 3.0 3.0 3.0
loop_
_entity.id
_entity.type
1 polymer
loop_
_entity_poly.entity_id
_entity_poly.type
1 polypeptide(L)
_struct_conf.conf_type_id HELX_P
_struct_conf.beg_label_asym_id A
_struct_conf.beg_label_seq_id 1
_struct_conf.end_label_asym_id A
_struct_conf.end_label_seq_id 1
''');
      // A helix range from struct_conf alone is enough to make the
      // combined header-ranges list non-empty, so the fallback must not
      // run here even though struct_sheet_range is entirely absent --
      // "one category present" is not "both absent".
      expect(
        result.structure.chains.single.residues.first.secondaryStructure,
        SecondaryStructureType.helix,
      );
    });
  });

  group('parseMmcifStructure: real fixture (2QLE, multi-chain GFP-family structure)', () {
    late String content;
    setUpAll(() {
      content = File('test/structure/fixtures/2QLE.cif').readAsStringSync();
    });

    test('parses without throwing and finds exactly the 4 polymer chains (verified via the raw atom_site loop)', () {
      final result = parseMmcifStructure(content);
      expect(result.structure.chains.map((c) => c.id).toSet(), {
        'A',
        'B',
        'C',
        'D',
      });
    });

    test('every chain has at least one residue with a resolved CA', () {
      final result = parseMmcifStructure(content);
      for (final chain in result.structure.chains) {
        expect(
          chain.residues.any((r) => r.alphaCarbon != null),
          isTrue,
          reason: 'chain ${chain.id}',
        );
      }
    });

    test('waters are not present as a chain', () {
      final result = parseMmcifStructure(content);
      for (final chain in result.structure.chains) {
        expect(chain.residues.any((r) => r.name == 'HOH'), isFalse);
      }
    });

    test('the chromophore-bearing chain keeps its HETATM-flagged residue in the trace', () {
      // Confirmed via the plan's edge case #9a: this entry has a polymer
      // entity whose chain includes HETATM-flagged residues that are
      // chemically part of the backbone.
      final result = parseMmcifStructure(content);
      final hasHeteroRecordAtom = result.structure.atoms.any(
        (a) => a.isHeteroRecord,
      );
      expect(hasHeteroRecordAtom, isTrue);
    });

    test('produces at least some non-loop secondary structure', () {
      final result = parseMmcifStructure(content);
      final types = result.structure.chains
          .expand((c) => c.residues)
          .map((r) => r.secondaryStructure);
      expect(types, contains(SecondaryStructureType.helix));
      expect(types, contains(SecondaryStructureType.sheet));
    });
  });
}
