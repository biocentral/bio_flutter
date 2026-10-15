import 'package:flutter_scene/scene.dart' show CatmullRomPath;
import 'package:flutter_test/flutter_test.dart';
import 'package:bio_flutter/src/structure/scene/oriented_extrude.dart';
import 'package:bio_flutter/src/structure/scene/ribbon_profile.dart';
import 'package:vector_math/vector_math.dart';

/// A straight synthetic backbone with 3.8 Å spacing and a constant direction
/// vector. Shape does not matter for vertex bookkeeping.
({List<Vector3> positions, List<Vector3> directions}) _straightBackbone(
  int residueCount,
) => (
  positions: [for (int i = 0; i < residueCount; i++) Vector3(i * 3.8, 0, 0)],
  directions: List.filled(residueCount, Vector3(0, 1, 0)),
);

void main() {
  group('ribbonUnitProfiles', () {
    test('rejects a segment count that is not a multiple of 8', () {
      expect(() => ribbonUnitProfiles(segments: 12), throwsArgumentError);
    });

    test('round and rect profiles have matching, longer-than-segments length (4 duplicated corners)', () {
      final profiles = ribbonUnitProfiles(segments: 16);
      expect(profiles.round, hasLength(20));
      expect(profiles.rect, hasLength(20));
    });

    test('every round point lies on the unit circle', () {
      final profiles = ribbonUnitProfiles(segments: 16);
      for (final p in profiles.round) {
        expect(p.length, closeTo(1.0, 1e-6));
      }
    });

    test('every rect point lies on the unit square boundary', () {
      final profiles = ribbonUnitProfiles(segments: 16);
      for (final p in profiles.rect) {
        expect(p.x.abs() <= 1.0 + 1e-9 && p.y.abs() <= 1.0 + 1e-9, isTrue);
        expect(p.x.abs() > 1.0 - 1e-6 || p.y.abs() > 1.0 - 1e-6, isTrue);
      }
    });

    test('rect profile actually reaches the four exact corners', () {
      final profiles = ribbonUnitProfiles(segments: 16);
      bool hasCorner(double sx, double sy) => profiles.rect.any(
        (p) => (p.x - sx).abs() < 1e-9 && (p.y - sy).abs() < 1e-9,
      );
      expect(hasCorner(1.0, 1.0), isTrue);
      expect(hasCorner(-1.0, 1.0), isTrue);
      expect(hasCorner(-1.0, -1.0), isTrue);
      expect(hasCorner(1.0, -1.0), isTrue);
    });

    test('each corner is duplicated (two coincident points, one per adjacent face)', () {
      final profiles = ribbonUnitProfiles(segments: 16);
      int occurrences(double x, double y) => profiles.rect
          .where((p) => (p.x - x).abs() < 1e-9 && (p.y - y).abs() < 1e-9)
          .length;
      expect(occurrences(1.0, 1.0), 2);
    });
  });

  group('buildOrientedExtrudeArrays residueForVertex', () {
    // Constant round profile: these tests cover vertex-to-residue bookkeeping.
    const ProfileSize size = (
      halfThickness: 0.2,
      halfWidth: 0.2,
      rectFactor: 0.0,
    );
    final profiles = ribbonUnitProfiles(segments: 16);

    // One distinct color per residue, so baked colors can be checked against
    // residueForVertex.
    final baseColors = [
      for (int i = 0; i < 5; i++) Vector4(i.toDouble(), 0, 0, 1),
    ];

    ({List<Vector3> positions, List<Vector3> directions})
    fiveResidueBackbone() => _straightBackbone(5);

    void expectColorsMatchResidueForVertex(
      OrientedExtrudeArrays arrays,
      List<Vector4> colors,
    ) {
      for (int v = 0; v < arrays.residueForVertex.length; v++) {
        final Vector4 expected = colors[arrays.residueForVertex[v]];
        expect(
          arrays.colors[v * 4],
          expected.x,
          reason: 'vertex $v red channel',
        );
        expect(
          arrays.colors[v * 4 + 1],
          expected.y,
          reason: 'vertex $v green channel',
        );
      }
    }

    test('every vertex gets a residue index, one entry per vertex', () {
      final backbone = fiveResidueBackbone();
      final arrays = buildOrientedExtrudeArrays(
        path: CatmullRomPath(backbone.positions),
        residueDirectionVectors: backbone.directions,
        roundProfile: profiles.round,
        rectProfile: profiles.rect,
        sizeAt: (t) => size,
        colorAt: (t) => colorAtParameter(baseColors, t),
        residueIndexAt: (t) => residueIndexAtParameter(5, t),
        stations: (backbone.positions.length - 1) * 8 + 1,
      );
      expect(arrays.residueForVertex, hasLength(arrays.positions.length ~/ 3));
    });

    test(
      'residue indices stay in range and are non-decreasing along the sweep',
      () {
        final backbone = fiveResidueBackbone();
        final arrays = buildOrientedExtrudeArrays(
          path: CatmullRomPath(backbone.positions),
          residueDirectionVectors: backbone.directions,
          roundProfile: profiles.round,
          rectProfile: profiles.rect,
          sizeAt: (t) => size,
          colorAt: (t) => colorAtParameter(baseColors, t),
          residueIndexAt: (t) => residueIndexAtParameter(5, t),
          stations: (backbone.positions.length - 1) * 8 + 1,
        );
        for (final r in arrays.residueForVertex) {
          expect(r, inInclusiveRange(0, 4));
        }
        // The swept-ring portion (everything but the two end caps) is
        // stations-in-order, so within it residue index is monotonically
        // non-decreasing.
        final ringSize =
            (profiles.round.length +
            1); // see buildOrientedExtrudeArrays' own ring-size comment
        final stations = (backbone.positions.length - 1) * 8 + 1;
        final ringVertexCount = ringSize * stations;
        final sweptPortion = arrays.residueForVertex
            .take(ringVertexCount)
            .toList();
        for (int i = 1; i < sweptPortion.length; i++) {
          expect(sweptPortion[i], greaterThanOrEqualTo(sweptPortion[i - 1]));
        }
      },
    );

    test('the first and last swept stations map to the run\'s first and last residues', () {
      final backbone = fiveResidueBackbone();
      final arrays = buildOrientedExtrudeArrays(
        path: CatmullRomPath(backbone.positions),
        residueDirectionVectors: backbone.directions,
        roundProfile: profiles.round,
        rectProfile: profiles.rect,
        sizeAt: (t) => size,
        colorAt: (t) => colorAtParameter(baseColors, t),
        residueIndexAt: (t) => residueIndexAtParameter(5, t),
        stations: (backbone.positions.length - 1) * 8 + 1,
      );
      expect(arrays.residueForVertex.first, 0);
      expect(arrays.residueForVertex.last, 4);
    });

    test(
      'every vertex\'s baked color matches baseColors[residueForVertex[v]]',
      () {
        final backbone = fiveResidueBackbone();
        final arrays = buildOrientedExtrudeArrays(
          path: CatmullRomPath(backbone.positions),
          residueDirectionVectors: backbone.directions,
          roundProfile: profiles.round,
          rectProfile: profiles.rect,
          sizeAt: (t) => size,
          colorAt: (t) => colorAtParameter(baseColors, t),
          residueIndexAt: (t) => residueIndexAtParameter(5, t),
          stations: (backbone.positions.length - 1) * 8 + 1,
        );
        expectColorsMatchResidueForVertex(arrays, baseColors);
      },
    );

    test('the invariant holds through a skipped cap too (near-zero size at one end, an arrow-tip shape)', () {
      // Zero size at the end, like an arrow tip, so no end cap is emitted.
      final backbone = _straightBackbone(3);
      final colors = baseColors.sublist(0, 3);
      final arrays = buildOrientedExtrudeArrays(
        path: CatmullRomPath(backbone.positions),
        residueDirectionVectors: backbone.directions,
        roundProfile: profiles.round,
        rectProfile: profiles.rect,
        sizeAt: (t) => t >= 1.0
            ? (halfThickness: 0.0, halfWidth: 0.0, rectFactor: 0.0)
            : size,
        colorAt: (t) => colorAtParameter(colors, t),
        residueIndexAt: (t) => residueIndexAtParameter(3, t),
        stations: (backbone.positions.length - 1) * 8 + 1,
      );
      expect(arrays.residueForVertex, hasLength(arrays.positions.length ~/ 3));
      expectColorsMatchResidueForVertex(arrays, colors);
      // Only the start cap should have been emitted (end size is zero).
      expect(arrays.residueForVertex.where((r) => r == 0), isNotEmpty);
    });
  });
}
