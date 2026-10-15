import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:bio_flutter/src/structure/mmcif/mmcif_structure_parser.dart';
import 'package:bio_flutter/src/structure/model/secondary_structure.dart';
import 'package:bio_flutter/src/structure/scene/backbone_segment.dart'
    show buildContinuousRuns;
import 'package:bio_flutter/src/structure/ss/p_sea.dart'
    show assignGeometricSecondaryStructure;

/// Hides the header SS categories so the parser falls back to geometry,
/// reusing a real fixture's coordinates.
String _withoutSecondaryStructureHeaders(String content) => content
    .replaceAll('_struct_conf.', '_disabled_struct_conf.')
    .replaceAll('_struct_sheet_range.', '_disabled_struct_sheet_range.');

/// Moves every 1L2Y helix range 500 residues away, so ranges exist but cover
/// no residue.
String _withMisnumberedHelices(String content) => content
    .split('\n')
    .map(
      (line) => line.startsWith('HELX_P HELX_P1 ')
          ? 'HELX_P HELX_P1 1 ASN A 501 ? ASP A 509 ? ASN A 501 ASP A 509 1 ? 9'
          : line.startsWith('HELX_P HELX_P2 ')
          ? 'HELX_P HELX_P2 2 GLY A 510 ? GLY A 515 ? GLY A 510 GLY A 515 5 ? 6'
          : line,
    )
    .join('\n');

/// Appends 1L2Y's first model as chain B, 100 Å away. The header ranges name
/// only chain A.
String _withUnannotatedSecondChain(String content) {
  final List<String> lines = content.split('\n');
  final List<String> copies = [];
  int lastAtom = 0;
  for (int i = 0; i < lines.length; i++) {
    if (!lines[i].startsWith('ATOM')) continue;
    lastAtom = i;
    final List<String> fields = lines[i].trim().split(RegExp(r'\s+'));
    if (fields[20] != '1') continue;
    fields[1] = '${int.parse(fields[1]) + 100000}';
    fields[6] = 'B';
    fields[10] = '${double.parse(fields[10]) + 100}';
    fields[18] = 'B';
    copies.add(fields.join(' '));
  }
  lines.insertAll(lastAtom + 1, copies);
  return lines.join('\n');
}

/// Biotite's published P-SEA assignment for 1L2Y; see p_sea_test.dart.
final List<SecondaryStructureType> _pSea1L2Y = [
  SecondaryStructureType.loop,
  ...List.filled(8, SecondaryStructureType.helix),
  ...List.filled(11, SecondaryStructureType.loop),
];

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
_atom_site.label_seq_id
_atom_site.auth_asym_id
_atom_site.auth_seq_id
_atom_site.Cartn_x
_atom_site.Cartn_y
_atom_site.Cartn_z
ATOM 1 C CA A 1 1 A 1 1.0 1.0 1.0
ATOM 2 C CA A 1 2 A 2 2.0 2.0 2.0
ATOM 3 C CA A 1 3 A 3 3.0 3.0 3.0
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
      // The two algorithms need not agree, so compare with a direct call.
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

    test('header ranges that cover no residue fall back to geometry, with a warning', () {
      final content = File('test/structure/fixtures/1L2Y.cif')
          .readAsStringSync();
      final result = parseMmcifStructure(_withMisnumberedHelices(content));
      final types = result.structure.chains.single.residues
          .map((r) => r.secondaryStructure)
          .toList();
      expect(types, _pSea1L2Y);
      expect(
        result.warnings,
        contains(contains('chain A: no header secondary-structure range')),
      );
    });

    test('only chains without a covered residue fall back', () {
      final content = File('test/structure/fixtures/1L2Y.cif')
          .readAsStringSync();
      final result = parseMmcifStructure(_withUnannotatedSecondChain(content));
      final chains = {for (final c in result.structure.chains) c.id: c};
      List<SecondaryStructureType> typesOf(String id) =>
          chains[id]!.residues.map((r) => r.secondaryStructure).toList();

      // Chain A keeps the header: helix over residues 1-15.
      expect(typesOf('A'), [
        ...List.filled(15, SecondaryStructureType.helix),
        ...List.filled(5, SecondaryStructureType.loop),
      ]);
      expect(typesOf('B'), _pSea1L2Y);
      expect(
        result.warnings.where((w) => w.contains('secondary-structure range')),
        [contains('chain B:')],
      );
    });

    test('a fully covered file adds no fallback warning', () {
      final result = parseMmcifStructure(
        File('test/structure/fixtures/1L2Y.cif').readAsStringSync(),
      );
      expect(
        result.warnings.where((w) => w.contains('secondary-structure range')),
        isEmpty,
      );
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
_atom_site.label_seq_id
_atom_site.auth_asym_id
_atom_site.auth_seq_id
_atom_site.Cartn_x
_atom_site.Cartn_y
_atom_site.Cartn_z
ATOM 1 C CA A 1 1 A 1 1.0 1.0 1.0
ATOM 2 C CA A 1 2 A 2 2.0 2.0 2.0
ATOM 3 C CA A 1 3 A 3 3.0 3.0 3.0
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
      // One present category is enough to skip the fallback.
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
      // This entry's polymer chains contain HETATM-flagged backbone residues.
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

    test('header ranges land on the right residues despite the author-numbering offset', () {
      // The chromophore (CRO, author 66) replaces residues 65-67, so after
      // it author numbers run 2 ahead of label numbers. HELX_P3 is label
      // 66-70 / author 68-72, HELX_P4 label 73-79 / author 75-81, and strand
      // A 9 label 90-98 / author 92-100.
      final result = parseMmcifStructure(content);
      final chainA = result.structure.chains.firstWhere((c) => c.id == 'A');
      SecondaryStructureType typeAt(int auth) => chainA.residues
          .firstWhere((r) => r.id == ResidueId(auth, ''))
          .secondaryStructure;

      for (final auth in [68, 72, 75, 81]) {
        expect(typeAt(auth), SecondaryStructureType.helix, reason: '$auth');
      }
      for (final auth in [73, 74]) {
        expect(typeAt(auth), SecondaryStructureType.loop, reason: '$auth');
      }
      for (final auth in [92, 99, 100]) {
        expect(typeAt(auth), SecondaryStructureType.sheet, reason: '$auth');
      }
      for (final auth in [90, 91]) {
        expect(typeAt(auth), SecondaryStructureType.loop, reason: '$auth');
      }
    });

    test('the chromophore does not split the backbone into separate runs', () {
      final result = parseMmcifStructure(content);
      final chromophore = result.structure.chains
          .firstWhere((c) => c.id == 'A')
          .residues
          .firstWhere((r) => r.name == 'CRO');
      expect(chromophore.id, const ResidueId(66, ''));
      expect(chromophore.labelSeqId, 65);
      expect(chromophore.alphaCarbon, isNull);

      for (final run in buildContinuousRuns(result.structure)) {
        final ids = run.residues.map((r) => r.id.authSeqId).toSet();
        // Whichever run reaches author 64 must continue across CRO to 68.
        if (ids.contains(64)) {
          expect(ids, contains(68), reason: 'chain ${run.chainId}');
        }
      }
    });
  });
}
