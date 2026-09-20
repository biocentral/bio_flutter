import 'package:flutter_test/flutter_test.dart';
import 'package:bio_flutter/src/structure/model/atom.dart';
import 'package:bio_flutter/src/structure/model/chain.dart';
import 'package:bio_flutter/src/structure/model/molecular_structure.dart';
import 'package:bio_flutter/src/structure/model/residue.dart';
import 'package:bio_flutter/src/structure/model/secondary_structure.dart';
import 'package:vector_math/vector_math.dart';

Atom _atom(String name, {double x = 0}) => Atom(
  serial: 1,
  element: name == 'CA' ? 'C' : 'N',
  atomName: name,
  position: Vector3(x, 0, 0),
  occupancy: 1,
  bFactor: 20,
  isHeteroRecord: false,
);

void main() {
  group('ResidueId', () {
    test('orders by sequence number first', () {
      expect(
        const ResidueId(10, '').compareTo(const ResidueId(11, '')),
        lessThan(0),
      );
    });

    test('a bare sequence number sorts before its own insertion codes', () {
      expect(
        const ResidueId(82, '').compareTo(const ResidueId(82, 'A')),
        lessThan(0),
      );
    });

    test(
      'insertion codes sort alphabetically within the same sequence number',
      () {
        expect(
          const ResidueId(82, 'A').compareTo(const ResidueId(82, 'B')),
          lessThan(0),
        );
      },
    );

    test('equality is structural', () {
      expect(const ResidueId(82, 'A'), const ResidueId(82, 'A'));
      expect(const ResidueId(82, 'A') == const ResidueId(82, 'B'), isFalse);
    });
  });

  group('SecondaryStructureRange.covers', () {
    const range = SecondaryStructureRange(
      chainId: 'A',
      begin: ResidueId(10, ''),
      end: ResidueId(20, ''),
      type: SecondaryStructureType.helix,
    );

    test('covers residues strictly inside the range', () {
      expect(range.covers('A', const ResidueId(15, '')), isTrue);
    });

    test('covers the boundary residues', () {
      expect(range.covers('A', const ResidueId(10, '')), isTrue);
      expect(range.covers('A', const ResidueId(20, '')), isTrue);
    });

    test('does not cover a different chain even with matching numbering', () {
      expect(range.covers('B', const ResidueId(15, '')), isFalse);
    });

    test('an inserted residue sharing a numeric seqId with the end boundary is excluded', () {
      // Range ends at plain 20; 20A is a distinct, later residue.
      expect(range.covers('A', const ResidueId(20, 'A')), isFalse);
    });

    test('an inserted residue just past the begin boundary is included', () {
      const beginsAtInsertion = SecondaryStructureRange(
        chainId: 'A',
        begin: ResidueId(10, 'A'),
        end: ResidueId(20, ''),
        type: SecondaryStructureType.helix,
      );
      expect(beginsAtInsertion.covers('A', const ResidueId(10, 'B')), isTrue);
      expect(beginsAtInsertion.covers('A', const ResidueId(10, '')), isFalse);
    });
  });

  group('Residue', () {
    test('alphaCarbon finds the CA atom among several', () {
      final residue = Residue(
        id: const ResidueId(1, ''),
        name: 'ALA',
        atoms: [_atom('N'), _atom('CA'), _atom('C'), _atom('O')],
        secondaryStructure: SecondaryStructureType.loop,
      );
      expect(residue.alphaCarbon!.atomName, 'CA');
    });

    test('alphaCarbon is null when no CA is present', () {
      final residue = Residue(
        id: const ResidueId(1, ''),
        name: 'ALA',
        atoms: [_atom('N')],
        secondaryStructure: SecondaryStructureType.loop,
      );
      expect(residue.alphaCarbon, isNull);
    });

    test('withSecondaryStructure returns a new instance, leaving atoms/name/id untouched', () {
      final original = Residue(
        id: const ResidueId(1, ''),
        name: 'ALA',
        atoms: [_atom('CA')],
        secondaryStructure: SecondaryStructureType.loop,
      );
      final helical = original.withSecondaryStructure(
        SecondaryStructureType.helix,
      );
      expect(original.secondaryStructure, SecondaryStructureType.loop);
      expect(helical.secondaryStructure, SecondaryStructureType.helix);
      expect(helical.id, original.id);
      expect(helical.atoms, original.atoms);
    });
  });

  group('MolecularStructure', () {
    test('atoms flattens every chain/residue in order', () {
      final structure = MolecularStructure(
        chains: [
          Chain(
            id: 'A',
            authChainId: 'A',
            residues: [
              Residue(
                id: const ResidueId(1, ''),
                name: 'ALA',
                atoms: [_atom('N'), _atom('CA')],
                secondaryStructure: SecondaryStructureType.loop,
              ),
            ],
          ),
          Chain(
            id: 'B',
            authChainId: 'B',
            residues: [
              Residue(
                id: const ResidueId(1, ''),
                name: 'GLY',
                atoms: [_atom('CA')],
                secondaryStructure: SecondaryStructureType.loop,
              ),
            ],
          ),
        ],
      );
      expect(structure.atoms.map((a) => a.atomName), ['N', 'CA', 'CA']);
    });

    test('an empty structure is valid, not an error', () {
      final structure = MolecularStructure(chains: []);
      expect(structure.atoms, isEmpty);
    });
  });
}
