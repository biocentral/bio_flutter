import 'package:flutter_test/flutter_test.dart';
import 'package:bio_flutter/src/structure/cif/cif_document.dart';
import 'package:bio_flutter/src/structure/mmcif/secondary_structure_reader.dart';
import 'package:bio_flutter/src/structure/model/chain.dart';
import 'package:bio_flutter/src/structure/model/residue.dart';
import 'package:bio_flutter/src/structure/model/secondary_structure.dart';

Chain _chain(String id, List<int> seqIds) => Chain(
  id: id,
  authChainId: id,
  residues: [
    for (final seq in seqIds)
      Residue(
        id: ResidueId(seq, ''),
        name: 'ALA',
        atoms: const [],
        secondaryStructure: SecondaryStructureType.loop,
      ),
  ],
);

void main() {
  group('readSecondaryStructureRanges', () {
    test('a single-row (non-loop) struct_conf still yields one range', () {
      final doc = parseCifDocument('''
data_TEST
_struct_conf.conf_type_id HELX_P
_struct_conf.beg_label_asym_id A
_struct_conf.beg_label_seq_id 10
_struct_conf.end_label_asym_id A
_struct_conf.end_label_seq_id 20
''');
      final ranges = readSecondaryStructureRanges(doc.firstBlock!, [
        _chain('A', [15]),
      ]);
      expect(ranges, hasLength(1));
      expect(ranges.single.type, SecondaryStructureType.helix);
      expect(ranges.single.begin, const ResidueId(10, ''));
      expect(ranges.single.end, const ResidueId(20, ''));
    });

    test('non-HELX conf_type_id rows are excluded', () {
      final doc = parseCifDocument('''
data_TEST
loop_
_struct_conf.conf_type_id
_struct_conf.beg_label_asym_id
_struct_conf.beg_label_seq_id
_struct_conf.end_label_asym_id
_struct_conf.end_label_seq_id
TURN_P A 1 A 3
''');
      expect(
        readSecondaryStructureRanges(doc.firstBlock!, [
          _chain('A', [2]),
        ]),
        isEmpty,
      );
    });

    test('every struct_sheet_range row counts as sheet', () {
      final doc = parseCifDocument('''
data_TEST
loop_
_struct_sheet_range.beg_label_asym_id
_struct_sheet_range.beg_label_seq_id
_struct_sheet_range.end_label_asym_id
_struct_sheet_range.end_label_seq_id
A 5 A 8
''');
      final ranges = readSecondaryStructureRanges(doc.firstBlock!, [
        _chain('A', [6]),
      ]);
      expect(ranges.single.type, SecondaryStructureType.sheet);
    });

    test('falls back to auth_asym_id, translated via the built chains, when label is absent', () {
      final doc = parseCifDocument('''
data_TEST
_struct_conf.conf_type_id HELX_P
_struct_conf.beg_auth_asym_id X
_struct_conf.beg_auth_seq_id 10
_struct_conf.end_auth_asym_id X
_struct_conf.end_auth_seq_id 20
''');
      // Chain's internal id is 'A' (label_asym_id) but its display/auth id
      // is 'X' — exactly the auth != label case this fallback exists for.
      final chain = Chain(id: 'A', authChainId: 'X', residues: []);
      final ranges = readSecondaryStructureRanges(doc.firstBlock!, [chain]);
      expect(ranges.single.chainId, 'A');
    });

    test(
      'insertion codes on range boundaries are read, not defaulted away',
      () {
        final doc = parseCifDocument('''
data_TEST
_struct_conf.conf_type_id HELX_P
_struct_conf.beg_label_asym_id A
_struct_conf.beg_label_seq_id 10
_struct_conf.pdbx_beg_PDB_ins_code A
_struct_conf.end_label_asym_id A
_struct_conf.end_label_seq_id 20
''');
        final ranges = readSecondaryStructureRanges(doc.firstBlock!, [
          _chain('A', [10]),
        ]);
        expect(ranges.single.begin, const ResidueId(10, 'A'));
      },
    );

    test('no struct_conf/struct_sheet_range categories at all yields an empty list, not an error', () {
      final doc = parseCifDocument('data_TEST\n_entry.id X\n');
      expect(
        readSecondaryStructureRanges(doc.firstBlock!, [
          _chain('A', [1]),
        ]),
        isEmpty,
      );
    });
  });

  group('applySecondaryStructure', () {
    test(
      'assigns from the first covering range and defaults to loop otherwise',
      () {
        final chains = [
          _chain('A', [5, 15, 25]),
        ];
        final ranges = [
          const SecondaryStructureRange(
            chainId: 'A',
            begin: ResidueId(10, ''),
            end: ResidueId(20, ''),
            type: SecondaryStructureType.helix,
          ),
        ];
        final result = applySecondaryStructure(chains, ranges);
        final types = result.single.residues
            .map((r) => r.secondaryStructure)
            .toList();
        expect(types, [
          SecondaryStructureType.loop,
          SecondaryStructureType.helix,
          SecondaryStructureType.loop,
        ]);
      },
    );

    test('an inserted residue past a range end is not swept in', () {
      final chains = [
        Chain(
          id: 'A',
          authChainId: 'A',
          residues: [
            Residue(
              id: const ResidueId(20, ''),
              name: 'ALA',
              atoms: const [],
              secondaryStructure: SecondaryStructureType.loop,
            ),
            Residue(
              id: const ResidueId(20, 'A'),
              name: 'ALA',
              atoms: const [],
              secondaryStructure: SecondaryStructureType.loop,
            ),
          ],
        ),
      ];
      final ranges = [
        const SecondaryStructureRange(
          chainId: 'A',
          begin: ResidueId(10, ''),
          end: ResidueId(20, ''),
          type: SecondaryStructureType.helix,
        ),
      ];
      final result = applySecondaryStructure(chains, ranges);
      expect(
        result.single.residues[0].secondaryStructure,
        SecondaryStructureType.helix,
      );
      expect(
        result.single.residues[1].secondaryStructure,
        SecondaryStructureType.loop,
      );
    });
  });
}
