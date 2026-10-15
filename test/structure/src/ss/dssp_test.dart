import 'dart:io';

import 'package:bio_flutter/src/structure/mmcif/mmcif_structure_parser.dart';
import 'package:bio_flutter/src/structure/model/atom.dart';
import 'package:bio_flutter/src/structure/model/chain.dart';
import 'package:bio_flutter/src/structure/model/molecular_structure.dart';
import 'package:bio_flutter/src/structure/model/residue.dart';
import 'package:bio_flutter/src/structure/model/secondary_structure.dart';
import 'package:bio_flutter/src/structure/ss/dssp.dart';
import 'package:bio_flutter/src/structure/ss/geometric_secondary_structure.dart';
import 'package:bio_flutter/src/structure/ss/p_sea.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

// References from ChimeraX 1.12 (`dssp` with default parameters, then each
// residue's is_helix and is_strand): H helix, E strand, - loop.
const String _chimeraX1L2Y = '-HHHHHHH--HHHH------';
const Map<String, String> _chimeraX2QLE = {
  'A':
      '-HHHH--EEEEEEEEEEEE--EEEEEEEEEEEEHHH-EEEEEEEE--------HHHH------HHH----'
      'HHHHHH-HHHH-----EEEEEEEEE----EEEEEEEEEEE--EEEEEEEEEEE---------------'
      '----EEEEEEEE----EEEEEEEEEEE-----EEEEEEEEEEEE-----------EEEEEEEEEE----'
      '----EEEEEEEEEEE-----',
  'B':
      '-HHHH--EEEEEEEEEEEE--EEEEEEEEEEEE----EEEEEEEE--------HHHH------HHH----'
      'HHHHHH-HHHH-----EEEEEEEEE----EEEEEEEEEEE--EEEEEEEEEEE---------------'
      '----EEEEEEE------EEEEEEEEEE-----EEEEEEEEEEEE-----------EEEEEEEEEE----'
      '----EEEEEEEEEEE----',
  'C':
      '-HHHH---EEEEEEEEEEE--EEEEEEEEEEEE----EEEEEEEE--------HHHH------HHH----'
      'HHHHHH-HHHH-----EEEEEEEEE----EEEEEEEEEEE--EEEEEEEEEEE---------------'
      '----EEEEEEEEHHH-EEEEEEEEEEE-----EEEEEEEEEEEE-----------EEEEEEEEEE----'
      '----EEEEEEEEEEE----',
  'D':
      '-HHHH---EEEEEEEEEEE--EEEEEEEEEEEE----EEEEEEEE--------HHHH------HHH----'
      'HHHHHH-HHHH-----EEEEEEEEE----EEEEEEEEEEE--EEEEEEEEEEE---------------'
      '----EEEEEEEE----EEEEEEEEEEE-----EEEEEEEEEEEE-----------EEEEEEEEEE----'
      '----EEEEEEEEEEE----',
};
const String _chimeraX2KRU =
    '-------HHHHHHHHH--HHHHHHHHHHHHHHHHHH------HHHHHHHHHHHH---------';
const String _chimeraXMyoglobin =
    '----HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH-HHHHHH---------HHHHHH-HHHHHHHHHHHH'
    'HHHHHHHH----HHHHHHHHHHHHHH----HHHHHHHHHHHHHHHHHH------HHHHHHHHHHHHHHHH'
    'HHHHHHHH-----';

String _code(Chain chain) => chain.residues
    .map(
      (r) => switch (r.secondaryStructure) {
        SecondaryStructureType.helix => 'H',
        SecondaryStructureType.sheet => 'E',
        SecondaryStructureType.loop => '-',
      },
    )
    .join();

MolecularStructure _parse(String fixture) => parseMmcifStructure(
  File('test/structure/fixtures/$fixture').readAsStringSync(),
).structure;

Residue _caOnly(int i) => Residue(
  id: ResidueId(i, ''),
  name: 'ALA',
  atoms: [
    Atom(
      serial: i,
      element: 'C',
      atomName: 'CA',
      position: Vector3(i * 3.8, 0, 0),
      occupancy: 1,
      bFactor: 0,
      isHeteroRecord: false,
    ),
  ],
  secondaryStructure: SecondaryStructureType.helix,
);

void main() {
  group('assignDsspSecondaryStructure: ChimeraX references', () {
    test('1L2Y: alpha helix then 3-10 helix', () {
      final chains = assignDsspSecondaryStructure(_parse('1L2Y.cif'));
      expect(_code(chains.single), _chimeraX1L2Y);
    });

    test(
      '2QLE: strands, short 3-10 helices, and alpha helices in 4 chains',
      () {
        final chains = assignDsspSecondaryStructure(_parse('2QLE.cif'));
        expect({for (final c in chains) c.id: _code(c)}, _chimeraX2QLE);
      },
    );

    test('2KRU: two-residue strands are dropped', () {
      // The fixture is PDB entry 2KRU reduced to its first NMR model.
      final chains = assignDsspSecondaryStructure(_parse('2KRU-model1.cif'));
      expect(_code(chains.single), _chimeraX2KRU);
    });

    test('myoglobin: all alpha', () {
      final chains = assignDsspSecondaryStructure(
        _parse('AF-P02185-F1-myoglobin.cif'),
      );
      expect(_code(chains.single), _chimeraXMyoglobin);
    });
  });

  group('assignDsspSecondaryStructure: inputs', () {
    test("uses the file's amide hydrogens when present", () {
      // Moving 1L2Y's NMR hydrogens away removes every bond. Virtual
      // hydrogens would have kept the helices.
      final Chain chain = _parse('1L2Y.cif').chains.single;
      final Chain moved = Chain(
        id: chain.id,
        authChainId: chain.authChainId,
        residues: [
          for (final r in chain.residues)
            Residue(
              id: r.id,
              name: r.name,
              atoms: [
                for (final a in r.atoms)
                  a.atomName == 'H'
                      ? Atom(
                          serial: a.serial,
                          element: a.element,
                          atomName: a.atomName,
                          position: a.position + Vector3(100, 0, 0),
                          occupancy: a.occupancy,
                          bFactor: a.bFactor,
                          isHeteroRecord: a.isHeteroRecord,
                        )
                      : a,
              ],
              secondaryStructure: SecondaryStructureType.loop,
            ),
        ],
      );
      final result = assignDsspSecondaryStructure(
        MolecularStructure(chains: [moved]),
      );
      expect(_code(result.single), '-' * 20);
    });

    test('an empty structure yields no chains', () {
      expect(
        assignDsspSecondaryStructure(MolecularStructure(chains: [])),
        isEmpty,
      );
    });

    test('residues without a complete backbone are loops', () {
      final chain = Chain(
        id: 'A',
        authChainId: 'A',
        residues: [for (int i = 0; i < 8; i++) _caOnly(i)],
      );
      final result = assignDsspSecondaryStructure(
        MolecularStructure(chains: [chain]),
      );
      expect(_code(result.single), '--------');
    });

    test('no helix spans a missing residue', () {
      // Without residue 4, residues 3 and 5 are not peptide bonded, though
      // the bonds around the gap remain within reach.
      final Chain chain = _parse('1L2Y.cif').chains.single;
      final Chain gapped = Chain(
        id: chain.id,
        authChainId: chain.authChainId,
        residues: [...chain.residues.take(3), ...chain.residues.skip(4)],
      );
      final result = assignDsspSecondaryStructure(
        MolecularStructure(chains: [gapped]),
      );
      expect(_code(result.single), '---------HHHH------');
    });

    test('bridges pair residues of different chains', () {
      // Splitting 2QLE chain A inside the turn of its first hairpin leaves
      // each strand in a different chain.
      final Chain chain = _parse('2QLE.cif').chains.first;
      final result = assignDsspSecondaryStructure(
        MolecularStructure(
          chains: [
            Chain(id: 'X', authChainId: 'X', residues: chain.residues.take(20)),
            Chain(id: 'Y', authChainId: 'Y', residues: chain.residues.skip(20)),
          ],
        ),
      );
      expect(result.map(_code).join(), _chimeraX2QLE['A']);
    });
  });

  group('assignGeometricSecondaryStructure', () {
    test('header-less AlphaFold output goes through DSSP in the parser', () {
      final structure = _parse('AF-P02185-F1-myoglobin-no-ss.cif');
      expect(_code(structure.chains.single), _chimeraXMyoglobin);
    });

    test('Cα-only chains fall back to P-SEA, others keep DSSP', () {
      final Chain full = _parse('1L2Y.cif').chains.single;
      final Chain caOnly = Chain(
        id: 'B',
        authChainId: 'B',
        residues: [
          for (final r in full.residues)
            Residue(
              id: r.id,
              name: r.name,
              atoms: [r.alphaCarbon!],
              secondaryStructure: SecondaryStructureType.loop,
            ),
        ],
      );
      final structure = MolecularStructure(chains: [full, caOnly]);
      final result = assignGeometricSecondaryStructure(structure);

      expect(_code(result[0]), _chimeraX1L2Y);
      expect(
        _code(result[1]),
        _code(assignPseaSecondaryStructure(structure)[1]),
      );
      expect(_code(result[1]), contains('H'));
    });
  });
}
