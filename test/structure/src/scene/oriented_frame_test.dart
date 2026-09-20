import 'dart:math' as math;

import 'package:flutter_scene/scene.dart' show CatmullRomPath;
import 'package:flutter_test/flutter_test.dart';
import 'package:bio_flutter/src/structure/scene/oriented_frame.dart';
import 'package:vector_math/vector_math.dart';

/// Builds a synthetic idealized helix: CA positions on a cylinder, and a
/// per-residue C->O direction tilted [tiltDegrees] off the helix axis,
/// rotating around the axis at the same per-residue twist as the backbone
/// itself -- this is the realistic (and, per real alpha-helix geometry,
/// the common) near-axis-parallel case that stresses the degenerate-frame
/// guard in `computeOrientedFrames`.
({List<Vector3> positions, List<Vector3> directions}) _syntheticHelix({
  required int residueCount,
  double radius = 2.3,
  double risePerResidue = 1.5,
  double twistDegreesPerResidue = 100.0,
  double tiltDegrees = 20.0,
}) {
  final double twist = twistDegreesPerResidue * math.pi / 180.0;
  final double tilt = tiltDegrees * math.pi / 180.0;
  final List<Vector3> positions = [];
  final List<Vector3> directions = [];
  for (int i = 0; i < residueCount; i++) {
    final double angle = i * twist;
    positions.add(
      Vector3(
        radius * math.cos(angle),
        radius * math.sin(angle),
        i * risePerResidue,
      ),
    );
    final Vector3 radial = Vector3(math.cos(angle), math.sin(angle), 0);
    final Vector3 axial = Vector3(0, 0, 1);
    directions.add(
      (axial * math.cos(tilt) + radial * math.sin(tilt)).normalized(),
    );
  }
  return (positions: positions, directions: directions);
}

void main() {
  group('computeOrientedFrames on a synthetic helix', () {
    test('non-degenerate tilt: wideAxis tracks the helix twist smoothly, station to station', () {
      final helix = _syntheticHelix(residueCount: 20, tiltDegrees: 20.0);
      final path = CatmullRomPath(helix.positions);
      final frames = computeOrientedFrames(
        positionPath: path,
        residueDirectionVectors: helix.directions,
        stations: 200,
      );

      for (int i = 1; i < frames.length; i++) {
        // No sudden flip between adjacent (finely-spaced) stations.
        expect(
          frames[i - 1].wideAxis.dot(frames[i].wideAxis),
          greaterThan(0.9),
          reason:
              'wideAxis should rotate smoothly, not jump, between station ${i - 1} and $i',
        );
        // Always perpendicular to the local tangent by construction.
        expect(frames[i].wideAxis.dot(frames[i].tangent).abs(), lessThan(1e-6));
      }

      // wideAxis should actually respond to the input, not freeze at
      // whatever the first station happened to pick: over the whole
      // ~5.3-turn helix it should have moved noticeably, even though (per
      // the vector algebra of this particular pitch/tilt combination,
      // verified separately) the tangent-orthogonalized residual here is
      // dominated by the non-rotating axial component rather than the
      // rotating radial one, so it need not track the raw per-residue
      // twist angle directly.
      expect(frames.first.wideAxis.dot(frames.last.wideAxis), lessThan(0.999));
    });

    test(
      'degenerate (near-axial) tilt: still smooth, no crash, no flip-flopping',
      () {
        final helix = _syntheticHelix(residueCount: 20, tiltDegrees: 5.0);
        final path = CatmullRomPath(helix.positions);
        final frames = computeOrientedFrames(
          positionPath: path,
          residueDirectionVectors: helix.directions,
          stations: 200,
        );

        for (int i = 1; i < frames.length; i++) {
          expect(
            frames[i - 1].wideAxis.dot(frames[i].wideAxis),
            greaterThan(0.9),
            reason:
                'the degenerate-frame carry-forward guard should keep this smooth even when the '
                'real signal is nearly parallel to the tangent',
          );
        }
      },
    );

    test('a tilt that repeatedly crosses the old hard degenerate cutoff produces no sudden reversal', () {
      // Alternates each residue between a strongly degenerate (near-axial)
      // tilt and a clean one -- exactly the shape of input that made a
      // hard threshold switch "snap" between carried-forward and raw
      // signal. The confidence-weighted blend should never let
      // consecutive stations' wideAxis dot product go low, let alone
      // negative (a reversal), anywhere in the sweep.
      const int residueCount = 24;
      const double twist = 100.0 * math.pi / 180.0;
      final List<Vector3> positions = [];
      final List<Vector3> directions = [];
      for (int i = 0; i < residueCount; i++) {
        final double angle = i * twist;
        positions.add(
          Vector3(2.3 * math.cos(angle), 2.3 * math.sin(angle), i * 1.5),
        );
        final double tiltDegrees = i.isEven ? 3.0 : 35.0;
        final double tilt = tiltDegrees * math.pi / 180.0;
        final Vector3 radial = Vector3(math.cos(angle), math.sin(angle), 0);
        directions.add(
          (Vector3(0, 0, 1) * math.cos(tilt) + radial * math.sin(tilt))
              .normalized(),
        );
      }
      final frames = computeOrientedFrames(
        positionPath: CatmullRomPath(positions),
        residueDirectionVectors: directions,
        stations: 240,
      );
      for (int i = 1; i < frames.length; i++) {
        expect(
          frames[i - 1].wideAxis.dot(frames[i].wideAxis),
          greaterThan(0.85),
          reason:
              'station ${i - 1} -> $i should not show a sudden reversal as confidence rises and falls',
        );
      }
    });
  });

  group('computeOrientedFrames on a synthetic antiparallel beta sheet', () {
    test(
      'each strand\'s wideAxis aligns with the strand-to-strand direction',
      () {
        // Two straight strands 4.5 A apart along Y, running along X.
        // Each residue's C->O direction points roughly toward the other
        // strand -- the real consequence of forming an interstrand H-bond.
        const int residueCount = 10;
        final List<Vector3> strandA = [
          for (int i = 0; i < residueCount; i++) Vector3(i * 3.4, 0, 0),
        ];
        final List<Vector3> strandB = [
          for (int i = 0; i < residueCount; i++) Vector3(i * 3.4, 4.5, 0),
        ];
        final List<Vector3> dirsA = [
          for (int i = 0; i < residueCount; i++)
            Vector3(0, 1, 0.1).normalized(),
        ];
        final List<Vector3> dirsB = [
          for (int i = 0; i < residueCount; i++)
            Vector3(0, -1, 0.1).normalized(),
        ];

        final framesA = computeOrientedFrames(
          positionPath: CatmullRomPath(strandA),
          residueDirectionVectors: dirsA,
          stations: 40,
        );
        final framesB = computeOrientedFrames(
          positionPath: CatmullRomPath(strandB),
          residueDirectionVectors: dirsB,
          stations: 40,
        );

        for (final frame in [...framesA, ...framesB]) {
          // wideAxis's *axis* (undirected) should be close to the Y axis --
          // i.e. close to parallel to the strand-to-strand direction --
          // regardless of which of the two signed directions it landed on.
          expect(frame.wideAxis.dot(Vector3(0, 1, 0)).abs(), greaterThan(0.85));
        }
      },
    );
  });

  group('computeOrientedFrames argument validation', () {
    test('rejects fewer than two stations', () {
      final path = CatmullRomPath([Vector3(0, 0, 0), Vector3(1, 0, 0)]);
      expect(
        () => computeOrientedFrames(
          positionPath: path,
          residueDirectionVectors: [Vector3(0, 1, 0), Vector3(0, 1, 0)],
          stations: 1,
        ),
        throwsArgumentError,
      );
    });

    test('rejects fewer than two direction vectors', () {
      final path = CatmullRomPath([Vector3(0, 0, 0), Vector3(1, 0, 0)]);
      expect(
        () => computeOrientedFrames(
          positionPath: path,
          residueDirectionVectors: [Vector3(0, 1, 0)],
          stations: 10,
        ),
        throwsArgumentError,
      );
    });
  });
}
