import 'dart:math' as math;

import 'package:flutter_scene/scene.dart' show CatmullRomPath, ScenePath;
import 'package:vector_math/vector_math.dart';

/// A cross-section frame along a cartoon ribbon segment.
class OrientedFrame {
  const OrientedFrame({
    required this.position,
    required this.tangent,
    required this.wideAxis,
    required this.thinAxis,
    required this.naturalParameter,
  });

  final Vector3 position;

  /// Unit length, along the path.
  final Vector3 tangent;

  /// Unit length, perpendicular to [tangent]. This is the cross-section's
  /// "pointy"/wide direction — the axis a flattened ellipse or arrowhead's
  /// width runs along.
  final Vector3 wideAxis;

  /// Unit length, perpendicular to both [tangent] and [wideAxis]. The
  /// cross-section's thin direction.
  final Vector3 thinAxis;

  /// `positionPath`'s own natural parameter (`0..1`, evenly spaced per
  /// control point — i.e. the fractional residue index) at this station.
  /// Exposed so callers doing a *per-residue* lookup at this station (a
  /// ribbon profile size, a secondary-structure color) use the same
  /// residue-index-fraction meaning `ScenePath` itself uses, not the
  /// stations' own even-arc-length spacing, which is a different quantity
  /// whenever residues aren't perfectly evenly spaced along the path.
  final double naturalParameter;
}

/// Projection length above which the backbone orientation is fully trusted.
/// Below this value, confidence fades continuously to avoid frame snapping
/// when a helix's C=O direction approaches its tangent.
const double _fullConfidenceProjectionLength = 0.2;

/// Computes [stations] arc-length-spaced frames along [positionPath].
///
/// Direction vectors are smoothed and orthogonalized against the path tangent.
List<OrientedFrame> computeOrientedFrames({
  required ScenePath positionPath,
  required List<Vector3> residueDirectionVectors,
  required int stations,
}) {
  if (stations < 2) {
    throw ArgumentError.value(stations, 'stations', 'must be at least two');
  }
  if (residueDirectionVectors.length < 2) {
    throw ArgumentError.value(
      residueDirectionVectors.length,
      'residueDirectionVectors',
      'must have at least two entries, one per path control point',
    );
  }

  final CatmullRomPath directionPath = CatmullRomPath(residueDirectionVectors);
  final double length = positionPath.length;

  final List<OrientedFrame> frames = [];
  Vector3? previousWideAxis;
  for (int i = 0; i < stations; i++) {
    final double d = stations == 1 ? 0.0 : length * i / (stations - 1);
    final double t = positionPath.parameterAtDistance(d);
    final Vector3 position = positionPath.positionAt(t);

    Vector3 tangent = positionPath.tangentAt(t);
    tangent = tangent.length2 < 1e-12 ? Vector3(1, 0, 0) : tangent.normalized();

    final Vector3 rawDirection = directionPath.positionAt(t);
    final Vector3 projected =
        rawDirection - tangent * rawDirection.dot(tangent);
    final double projectedLength = projected.length;

    Vector3 wideAxis;
    if (previousWideAxis == null) {
      // First station: no prior axis to blend with or carry forward, so
      // this one has to be chosen from the raw signal alone (or, failing
      // that, arbitrarily) — everything from here on stays continuous
      // relative to it.
      wideAxis = projectedLength > 1e-9
          ? (projected / projectedLength)
          : _arbitraryPerpendicular(tangent);
    } else {
      // The previous axis, carried forward and re-orthogonalized against
      // *this* station's tangent — the fallback for zero confidence, and
      // one input to the blend otherwise.
      final Vector3 carriedRaw =
          previousWideAxis - tangent * previousWideAxis.dot(tangent);
      final Vector3 carried = carriedRaw.length2 > 1e-12
          ? carriedRaw.normalized()
          : _arbitraryPerpendicular(tangent);

      if (projectedLength < 1e-9) {
        wideAxis = carried;
      } else {
        Vector3 raw = projected / projectedLength;
        if (carried.dot(raw) < 0) raw = -raw;
        // Blend confidence continuously to avoid frame discontinuities.
        final double weight =
            (projectedLength / _fullConfidenceProjectionLength).clamp(0.0, 1.0);
        wideAxis = _slerpUnit(carried, raw, weight);
      }
    }

    final Vector3 thinAxis = tangent.cross(wideAxis).normalized();
    frames.add(
      OrientedFrame(
        position: position,
        tangent: tangent,
        wideAxis: wideAxis,
        thinAxis: thinAxis,
        naturalParameter: t,
      ),
    );
    previousWideAxis = wideAxis;
  }
  return frames;
}

Vector3 _arbitraryPerpendicular(Vector3 tangent) {
  final Vector3 reference = tangent.x.abs() < 0.9
      ? Vector3(1, 0, 0)
      : Vector3(0, 1, 0);
  return tangent.cross(reference).normalized();
}

/// Spherical linear interpolation between two unit vectors [a] and [b],
/// `t` in `0..1`. Falls back to linear blending (renormalized) when they're
/// too close together for the great-circle angle to be numerically
/// meaningful.
Vector3 _slerpUnit(Vector3 a, Vector3 b, double t) {
  final double dot = a.dot(b).clamp(-1.0, 1.0);
  final double theta = math.acos(dot);
  if (theta < 1e-6) return a;
  final double sinTheta = math.sin(theta);
  final double wa = math.sin((1 - t) * theta) / sinTheta;
  final double wb = math.sin(t * theta) / sinTheta;
  final Vector3 blended = a * wa + b * wb;
  return blended.length2 > 1e-12 ? blended.normalized() : a;
}
