import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:bio_flutter/src/structure/scene/helix_axis_orientation.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('helixAxisDirectionVectors', () {
    test('a straight line has no curvature signal at interior points (all zero vectors)', () {
      final positions = [for (int i = 0; i < 10; i++) Vector3(i * 3.8, 0, 0)];
      final directions = helixAxisDirectionVectors(
        positions,
        smoothingWindow: 0,
      );
      // Endpoints use a clamped (duplicated) neighbor, so their raw vector
      // is half of the boundary tangent rather than a true curvature --
      // `computeOrientedFrames` treats that the same way it treats any
      // other single unreliable station (low weight relative to its
      // neighbors' carried-forward axis), so it's not asserted on here.
      for (int i = 1; i < directions.length - 1; i++) {
        expect(directions[i], Vector3.zero());
      }
    });

    test('points on a circle curve toward the center at every point', () {
      const double radius = 5.0;
      final positions = [
        for (int i = 0; i < 20; i++)
          Vector3(radius * math.cos(i * 0.3), radius * math.sin(i * 0.3), 0),
      ];
      final directions = helixAxisDirectionVectors(
        positions,
        smoothingWindow: 0,
      );
      // Interior points (endpoints only have one real neighbor and are
      // noisier) should point roughly opposite their own radial (outward)
      // direction, i.e. toward the origin.
      for (int i = 2; i < positions.length - 2; i++) {
        final Vector3 outward = positions[i].normalized();
        expect(
          directions[i].dot(outward),
          lessThan(-0.9),
          reason: 'index $i should curve toward the circle center',
        );
      }
    });

    test('a helix curves toward its axis, consistently, with no sign flip along its length', () {
      const double radius = 2.3;
      const double rise = 1.5;
      const double twist = 100 * math.pi / 180;
      final positions = [
        for (int i = 0; i < 24; i++)
          Vector3(
            radius * math.cos(i * twist),
            radius * math.sin(i * twist),
            i * rise,
          ),
      ];
      final directions = helixAxisDirectionVectors(positions);

      for (int i = 3; i < positions.length - 3; i++) {
        // Points toward the axis: negligible Z component, and opposed to
        // the position's own radial (XY) direction.
        expect(directions[i].z.abs(), lessThan(0.3));
        final Vector3 radial = Vector3(
          positions[i].x,
          positions[i].y,
          0,
        ).normalized();
        expect(directions[i].dot(radial), lessThan(-0.8));
      }
      // The radial-inward direction itself rotates with the helix (~100
      // degrees per residue, same as the backbone's own twist) -- that's
      // expected, not a glitch. What should *not* happen is an
      // inconsistent/erratic rotation rate from step to step; every
      // consecutive pair should rotate by close to the same angle.
      final double expectedCos = math.cos(twist);
      for (int i = 4; i < positions.length - 3; i++) {
        expect(directions[i - 1].dot(directions[i]), closeTo(expectedCos, 0.1));
      }
    });

    test('regression: an oversized smoothing window (more than one helix turn) inverts the curvature sign', () {
      // Locks in a real bug found while choosing the default window: on a
      // 100 degree/residue (real alpha-helix rate) synthetic helix,
      // smoothingWindow: 2 (a 5-point average spanning ~400 degrees, over
      // a full turn) flips the curvature vector to point *away* from the
      // axis instead of toward it. Window 0 and 1 both get the sign
      // right; this pins the failure mode so the default never regresses
      // back into it.
      const double radius = 2.3, rise = 1.5;
      const double twist = 100 * math.pi / 180;
      final positions = [
        for (int i = 0; i < 24; i++)
          Vector3(
            radius * math.cos(i * twist),
            radius * math.sin(i * twist),
            i * rise,
          ),
      ];

      final good = helixAxisDirectionVectors(positions, smoothingWindow: 1);
      final bad = helixAxisDirectionVectors(positions, smoothingWindow: 2);
      const int probe = 10;
      final Vector3 radial = Vector3(
        positions[probe].x,
        positions[probe].y,
        0,
      ).normalized();
      expect(good[probe].dot(radial), lessThan(-0.8));
      expect(bad[probe].dot(radial), greaterThan(0.8));
    });

    test('fewer than two positions returns zero vectors without crashing', () {
      expect(helixAxisDirectionVectors([]), isEmpty);
      expect(helixAxisDirectionVectors([Vector3(0, 0, 0)]), [Vector3.zero()]);
    });
  });
}
