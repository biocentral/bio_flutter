import 'package:flutter_scene/scene.dart' show CatmullRomPath;
import 'package:flutter_test/flutter_test.dart';
import 'package:bio_flutter/src/structure/scene/oriented_extrude.dart';
import 'package:bio_flutter/src/structure/scene/ribbon_profile.dart';
import 'package:vector_math/vector_math.dart';

/// A straight, evenly-spaced synthetic backbone -- real Cα spacing (~3.8
/// Å), a constant perpendicular direction vector (non-degenerate, so
/// `computeOrientedFrames` doesn't need to fall back to an arbitrary
/// axis). Good enough for exercising `buildOrientedExtrudeArrays`'
/// bookkeeping (vertex/residue attribution), which doesn't depend on the
/// path's actual shape.
({List<Vector3> positions, List<Vector3> directions}) _straightBackbone(
  int residueCount,
) => (
  positions: [for (int i = 0; i < residueCount; i++) Vector3(i * 3.8, 0, 0)],
  directions: List.filled(residueCount, Vector3(0, 1, 0)),
);

void main() {
  group('unitCircleProfile', () {
    test('every point lies on the unit circle', () {
      final profile = unitCircleProfile(segments: 12);
      expect(profile, hasLength(12));
      for (final p in profile) {
        expect(p.length, closeTo(1.0, 1e-6));
      }
    });

    test('respects a custom segment count', () {
      expect(unitCircleProfile(segments: 6), hasLength(6));
    });
  });

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
    // Constant, always-round, non-degenerate profile -- these tests are
    // about vertex→residue bookkeeping, not shape/size.
    const ProfileSize size = (
      halfThickness: 0.2,
      halfWidth: 0.2,
      rectFactor: 0.0,
    );
    final profiles = ribbonUnitProfiles(segments: 16);

    // One *distinct* color per residue -- `colorAt` and `residueIndexAt`
    // are built from the same `colorAtParameter`/`residueIndexAtParameter`
    // rounding, matching how `cartoon_builder.dart` actually wires them, so
    // "vertex v's baked color equals baseColors[residueForVertex[v]]" is a
    // real invariant to check, not just "every vertex got tagged with
    // *some* number" (which `_MeshAccumulator.addVertex` guarantees by
    // construction and can't fail).
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
      // Mirrors a beta-strand arrow tip: the end station has ~zero size, so
      // `buildOrientedExtrudeArrays` skips emitting a cap there -- must not
      // desync `residueForVertex` (or the colors it should agree with) from
      // the vertex count it's still building up to that point.
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
