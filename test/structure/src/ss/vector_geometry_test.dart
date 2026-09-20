import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:bio_flutter/src/structure/ss/vector_geometry.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('angleAt', () {
    test('a right angle', () {
      final angle = angleAt(
        Vector3(1, 0, 0),
        Vector3(0, 0, 0),
        Vector3(0, 1, 0),
      );
      expect(angle, closeTo(math.pi / 2, 1e-9));
    });

    test('a straight (collinear, opposite direction) angle', () {
      final angle = angleAt(
        Vector3(-1, 0, 0),
        Vector3(0, 0, 0),
        Vector3(1, 0, 0),
      );
      expect(angle, closeTo(math.pi, 1e-9));
    });

    test('a zero angle (collinear, same direction)', () {
      final angle = angleAt(
        Vector3(1, 0, 0),
        Vector3(0, 0, 0),
        Vector3(2, 0, 0),
      );
      expect(angle, closeTo(0, 1e-9));
    });
  });

  group('dihedralAngle', () {
    // A planar zigzag in the z=0 plane, verified by hand-computing the
    // Praxeolitic formula's cross products for each case below.
    final Vector3 p0 = Vector3(0, 1, 0);
    final Vector3 p1 = Vector3(0, 0, 0);
    final Vector3 p2 = Vector3(1, 0, 0);

    test('a cis (U-shaped) arrangement is 0 degrees', () {
      final angle = dihedralAngle(p0, p1, p2, Vector3(1, 1, 0));
      expect(angle, closeTo(0, 1e-9));
    });

    test('a trans (Z-shaped) arrangement is 180 degrees', () {
      final angle = dihedralAngle(p0, p1, p2, Vector3(1, -1, 0));
      expect(angle.abs(), closeTo(math.pi, 1e-9));
    });

    test(
      'an out-of-plane arrangement is +90 degrees (Biotite sign convention)',
      () {
        final angle = dihedralAngle(p0, p1, p2, Vector3(1, 0, 1));
        expect(angle, closeTo(math.pi / 2, 1e-9));
      },
    );
  });
}
