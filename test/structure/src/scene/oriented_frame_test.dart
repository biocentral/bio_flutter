import 'dart:math' as math;

import 'package:flutter_scene/scene.dart' show CatmullRomPath;
import 'package:flutter_test/flutter_test.dart';
import 'package:bio_flutter/src/structure/scene/oriented_frame.dart';
import 'package:vector_math/vector_math.dart';

/// An idealized helix whose C->O vectors tilt [tiltDegrees] off the axis:
/// the near-axial case that stresses the degenerate-frame guard.
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

      // wideAxis must change over the helix rather than freeze at its first value.
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
      // Alternating near-axial and clean tilts must not reverse wideAxis between
      // stations.
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
        // Two straight strands 4.5 Å apart along Y, running along X, with C->O
        // vectors pointing toward the other strand as in interstrand H-bonds.
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
          // wideAxis is close to the Y axis, in either direction.
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
