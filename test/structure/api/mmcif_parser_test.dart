import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:bio_flutter/bio_flutter.dart';
import 'package:vector_math/vector_math.dart' show Vector3;

void main() {
  test(
    'public async parser retains fixture chains and immutable data',
    () async {
      final result = await MmcifParser.parse(
        File('test/structure/fixtures/2QLE.cif').readAsStringSync(),
      );
      expect(result.structure.chains, hasLength(4));
      expect(() => result.structure.chains.clear(), throwsUnsupportedError);
      final chain = result.structure.chains.first;
      expect(() => chain.residues.clear(), throwsUnsupportedError);
      final residue = chain.residues.first;
      expect(() => residue.atoms.clear(), throwsUnsupportedError);
      final atom = residue.atoms.first;
      final before = atom.position;
      atom.position.setZero();
      expect(atom.position, before);
    },
  );

  test('constructors snapshot caller-owned collections and coordinates', () {
    final position = Vector3(1, 2, 3);
    final atom = Atom(
      serial: 1,
      element: 'C',
      atomName: 'CA',
      position: position,
      occupancy: 1,
      bFactor: 0,
      isHeteroRecord: false,
    );
    final atoms = [atom];
    final residue = Residue(
      id: const ResidueId(1, ''),
      name: 'ALA',
      atoms: atoms,
      secondaryStructure: SecondaryStructureType.loop,
    );
    position.setZero();
    atoms.clear();
    expect(residue.atoms.single.position, Vector3(1, 2, 3));
  });

  test(
    'invalid input throws and missing coordinates produce diagnostics',
    () async {
      await expectLater(MmcifParser.parse('not mmcif'), throwsFormatException);
      final result = await MmcifParser.parse('data_empty\n');
      expect(result.structure.chains, isEmpty);
      expect(result.diagnostics, isNotEmpty);
      expect(() => result.diagnostics.clear(), throwsUnsupportedError);
    },
  );
}
