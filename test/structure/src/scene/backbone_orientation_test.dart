import 'package:flutter_test/flutter_test.dart';
import 'package:bio_flutter/src/structure/model/atom.dart';
import 'package:bio_flutter/src/structure/model/residue.dart';
import 'package:bio_flutter/src/structure/model/secondary_structure.dart';
import 'package:bio_flutter/src/structure/scene/backbone_orientation.dart';
import 'package:vector_math/vector_math.dart';

Atom _atom(String name, Vector3 position) => Atom(
  serial: 1,
  element: name.startsWith('C') ? 'C' : 'O',
  atomName: name,
  position: position,
  occupancy: 1,
  bFactor: 20,
  isHeteroRecord: false,
);

Residue _residue(int seq, {Vector3? c, Vector3? o}) => Residue(
  id: ResidueId(seq, ''),
  name: 'ALA',
  atoms: [if (c != null) _atom('C', c), if (o != null) _atom('O', o)],
  secondaryStructure: SecondaryStructureType.loop,
);

void main() {
  group('backboneOrientationVectors', () {
    test('returns the unit C->O vector when both atoms are present', () {
      final residues = [
        _residue(1, c: Vector3(0, 0, 0), o: Vector3(0, 1, 0)),
        _residue(2, c: Vector3(1, 0, 0), o: Vector3(1, 1, 0)),
      ];
      final vectors = backboneOrientationVectors(residues);
      expect(vectors, hasLength(2));
      for (final v in vectors) {
        expect(v.length, closeTo(1.0, 1e-9));
        expect(v.x, closeTo(0.0, 1e-9));
        expect(v.y, closeTo(1.0, 1e-9));
      }
    });

    test('flips a residue whose raw C->O vector points >90 degrees away from the previous one', () {
      final residues = [
        _residue(1, c: Vector3(0, 0, 0), o: Vector3(0, 1, 0)), // +Y
        _residue(
          2,
          c: Vector3(1, 0, 0),
          o: Vector3(1, -1, 0),
        ), // -Y (opposite hemisphere -- real strand pleat)
      ];
      final vectors = backboneOrientationVectors(residues);
      // Corrected, not raw: consecutive vectors must end up on the same side.
      expect(vectors[0].dot(vectors[1]), greaterThan(0));
      // The correction flipped vector 1 to +Y, not vector 0.
      expect(vectors[1].y, closeTo(1.0, 1e-9));
    });

    test(
      'propagates sign correction across a run of alternating raw vectors',
      () {
        final residues = [
          _residue(1, c: Vector3(0, 0, 0), o: Vector3(0, 1, 0)),
          _residue(2, c: Vector3(1, 0, 0), o: Vector3(1, -1, 0)),
          _residue(3, c: Vector3(2, 0, 0), o: Vector3(2, 1, 0)),
          _residue(4, c: Vector3(3, 0, 0), o: Vector3(3, -1, 0)),
        ];
        final vectors = backboneOrientationVectors(residues);
        for (int i = 1; i < vectors.length; i++) {
          expect(
            vectors[i - 1].dot(vectors[i]),
            greaterThan(0),
            reason: 'index $i should not flip relative to ${i - 1}',
          );
        }
      },
    );

    test(
      'a residue missing C or O carries the previous corrected vector forward',
      () {
        final residues = [
          _residue(1, c: Vector3(0, 0, 0), o: Vector3(0, 1, 0)),
          _residue(2), // no atoms at all
          _residue(
            3,
            c: Vector3(2, 0, 0),
            o: Vector3(2, 0, 1),
          ), // would be +Z if not carried forward
        ];
        final vectors = backboneOrientationVectors(residues);
        expect(vectors[1], vectors[0]);
        // Residue 3's real vector still gets sign-corrected relative to what
        // residue 2 carried forward (dot >= 0), not against its own raw self.
        expect(vectors[1].dot(vectors[2]), greaterThanOrEqualTo(0));
      },
    );

    test('leading residues missing C or O are backfilled from the first known vector', () {
      final residues = [
        _residue(1),
        _residue(2),
        _residue(3, c: Vector3(0, 0, 0), o: Vector3(0, 0, 1)),
      ];
      final vectors = backboneOrientationVectors(residues);
      expect(vectors[0], vectors[2]);
      expect(vectors[1], vectors[2]);
    });

    test('falls back to a fixed vector without crashing when no residue has both atoms', () {
      final residues = [_residue(1), _residue(2), _residue(3)];
      final vectors = backboneOrientationVectors(residues);
      expect(vectors, hasLength(3));
      for (final v in vectors) {
        expect(v.length, closeTo(1.0, 1e-9));
      }
    });

    test('recognizes a terminal OXT in place of O', () {
      final residues = [
        _residue(1, c: Vector3(0, 0, 0), o: Vector3(0, 1, 0)),
        Residue(
          id: const ResidueId(2, ''),
          name: 'ALA',
          atoms: [_atom('C', Vector3(1, 0, 0)), _atom('OXT', Vector3(1, 1, 0))],
          secondaryStructure: SecondaryStructureType.loop,
        ),
      ];
      final vectors = backboneOrientationVectors(residues);
      expect(vectors[1].y, closeTo(1.0, 1e-9));
    });
  });
}
