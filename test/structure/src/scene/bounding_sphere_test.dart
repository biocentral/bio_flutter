import 'package:flutter_test/flutter_test.dart';
import 'package:bio_flutter/src/structure/model/atom.dart';
import 'package:bio_flutter/src/structure/model/chain.dart';
import 'package:bio_flutter/src/structure/model/molecular_structure.dart';
import 'package:bio_flutter/src/structure/model/residue.dart';
import 'package:bio_flutter/src/structure/model/secondary_structure.dart';
import 'package:bio_flutter/src/structure/scene/bounding_sphere.dart';
import 'package:vector_math/vector_math.dart';

Atom _atomAt(Vector3 p) => Atom(
  serial: 1,
  element: 'C',
  atomName: 'CA',
  position: p,
  occupancy: 1,
  bFactor: 20,
  isHeteroRecord: false,
);

MolecularStructure _structureOf(List<Vector3> positions) => MolecularStructure(
  chains: [
    Chain(
      id: 'A',
      authChainId: 'A',
      residues: [
        for (int i = 0; i < positions.length; i++)
          Residue(
            id: ResidueId(i, ''),
            name: 'ALA',
            atoms: [_atomAt(positions[i])],
            secondaryStructure: SecondaryStructureType.loop,
          ),
      ],
    ),
  ],
);

void main() {
  group('BoundingSphere.of', () {
    test(
      'an empty structure falls back to a fixed, non-zero radius at the origin',
      () {
        final sphere = BoundingSphere.of(MolecularStructure(chains: []));
        expect(sphere.center, Vector3.zero());
        expect(sphere.radius, BoundingSphere.fallbackRadius);
      },
    );

    test(
      'every atom coinciding at one point falls back rather than a zero radius',
      () {
        final sphere = BoundingSphere.of(
          _structureOf([Vector3(5, 5, 5), Vector3(5, 5, 5)]),
        );
        expect(sphere.center, Vector3(5, 5, 5));
        expect(sphere.radius, BoundingSphere.fallbackRadius);
      },
    );

    test('contains every atom for a simple spread', () {
      final sphere = BoundingSphere.of(
        _structureOf([
          Vector3(-10, 0, 0),
          Vector3(10, 0, 0),
          Vector3(0, 10, 0),
        ]),
      );
      for (final p in [
        Vector3(-10, 0, 0),
        Vector3(10, 0, 0),
        Vector3(0, 10, 0),
      ]) {
        expect(
          p.distanceTo(sphere.center),
          lessThanOrEqualTo(sphere.radius + 1e-9),
        );
      }
    });
  });
}
