import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

/// The pseudo bond angle at [b], formed by points [a], [b], [c] — radians
/// in `[0, pi]`.
double angleAt(Vector3 a, Vector3 b, Vector3 c) {
  final Vector3 ba = a - b;
  final Vector3 bc = c - b;
  // Clamped: floating-point error can push the cosine a hair outside
  // [-1, 1] for near-collinear points, which would otherwise make acos
  // return NaN.
  final double cosTheta = (ba.dot(bc) / (ba.length * bc.length)).clamp(
    -1.0,
    1.0,
  );
  return math.acos(cosTheta);
}

/// Returns the signed dihedral angle for four points in radians.
///
/// The sign convention matches the one used by the secondary-structure
/// assignment.
double dihedralAngle(Vector3 p0, Vector3 p1, Vector3 p2, Vector3 p3) {
  final Vector3 b1 = p1 - p0;
  final Vector3 b2 = p2 - p1;
  final Vector3 b3 = p3 - p2;

  final Vector3 n1 = b1.cross(b2);
  final Vector3 n2 = b2.cross(b3);
  final Vector3 m1 = n1.cross(b2.normalized());

  final double x = n1.dot(n2);
  final double y = m1.dot(n2);
  return -math.atan2(y, x);
}
