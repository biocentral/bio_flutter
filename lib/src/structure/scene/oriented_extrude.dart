import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart' show ScenePath;
import 'package:vector_math/vector_math.dart';

import 'oriented_frame.dart';
import 'ribbon_profile.dart';

/// Vertex attributes for `MeshGeometry.fromArrays` and residue ownership data.
typedef OrientedExtrudeArrays = ({
  Float32List positions,
  Float32List normals,
  Float32List texCoords,
  Float32List colors,
  List<int> indices,
  List<int> residueForVertex,
});

/// Returns cross-section dimensions at normalized path parameter `t`.
typedef ProfileSizeAt = ProfileSize Function(double t);

/// Returns cross-section color at normalized path parameter `t`.
typedef ColorAt = Vector4 Function(double t);

/// Returns the residue index at normalized path parameter `t`.
typedef ResidueIndexAt = int Function(double t);

/// Sweeps a variable profile along [path], producing a continuous ribbon mesh.
///
/// Round and rectangular profiles are blended per station. Colors and residue
/// indices are written to the generated vertex attributes.
OrientedExtrudeArrays buildOrientedExtrudeArrays({
  required ScenePath path,
  required List<Vector3> residueDirectionVectors,
  required List<Vector2> roundProfile,
  required List<Vector2> rectProfile,
  required ProfileSizeAt sizeAt,
  required ColorAt colorAt,
  required ResidueIndexAt residueIndexAt,
  int stations = 64,
  bool caps = true,
}) {
  if (roundProfile.length < 3) {
    throw ArgumentError.value(
      roundProfile.length,
      'roundProfile',
      'needs at least three points',
    );
  }
  if (rectProfile.length != roundProfile.length) {
    throw ArgumentError.value(
      rectProfile.length,
      'rectProfile',
      "must match roundProfile's length for index-wise blending",
    );
  }
  final List<OrientedFrame> frames = computeOrientedFrames(
    positionPath: path,
    residueDirectionVectors: residueDirectionVectors,
    stations: stations,
  );
  final double length = path.length;
  final int pointCount = roundProfile.length;
  final _MeshAccumulator accumulator = _MeshAccumulator();
  final List<int> ringBases = [];

  for (int i = 0; i < stations; i++) {
    final OrientedFrame frame = frames[i];
    final double t = frame.naturalParameter;
    final double v = stations == 1 ? 0.0 : length * i / (stations - 1);
    final ProfileSize size = sizeAt(t);
    final Vector4 color = colorAt(t);
    final int residueIndex = residueIndexAt(t);
    final List<Vector2> shapeProfile = _blendProfile(
      roundProfile,
      rectProfile,
      size.rectFactor,
    );
    final List<Vector2> scaledProfile = [
      for (final p in shapeProfile)
        Vector2(p.x * size.halfThickness, p.y * size.halfWidth),
    ];
    final List<Vector2> profileNormals = _profileNormals(scaledProfile);

    ringBases.add(accumulator.vertexCount);
    // One extra vertex closes the loop so the texture seam is clean.
    for (int k = 0; k <= pointCount; k++) {
      final Vector2 point = scaledProfile[k % pointCount];
      final Vector2 profileNormal = profileNormals[k % pointCount];
      final Vector3 position =
          frame.position + frame.thinAxis * point.x + frame.wideAxis * point.y;
      final Vector3 normal =
          (frame.thinAxis * profileNormal.x + frame.wideAxis * profileNormal.y)
              .normalized();
      accumulator.addVertex(
        position,
        normal,
        k / pointCount,
        v,
        color,
        residueIndex,
      );
    }
  }

  _stitchRings(accumulator, ringBases, pointCount + 1);

  if (caps) {
    final ProfileSize startSize = sizeAt(frames.first.naturalParameter);
    final ProfileSize endSize = sizeAt(frames.last.naturalParameter);
    if (startSize.halfThickness > 1e-6 || startSize.halfWidth > 1e-6) {
      final List<Vector2> startShape = _blendProfile(
        roundProfile,
        rectProfile,
        startSize.rectFactor,
      );
      final List<Vector2> profile = [
        for (final p in startShape)
          Vector2(p.x * startSize.halfThickness, p.y * startSize.halfWidth),
      ];
      _addProfileCap(
        accumulator,
        frames.first,
        profile,
        colorAt(frames.first.naturalParameter),
        residueIndexAt(frames.first.naturalParameter),
        atEnd: false,
      );
    }
    if (endSize.halfThickness > 1e-6 || endSize.halfWidth > 1e-6) {
      final List<Vector2> endShape = _blendProfile(
        roundProfile,
        rectProfile,
        endSize.rectFactor,
      );
      final List<Vector2> profile = [
        for (final p in endShape)
          Vector2(p.x * endSize.halfThickness, p.y * endSize.halfWidth),
      ];
      _addProfileCap(
        accumulator,
        frames.last,
        profile,
        colorAt(frames.last.naturalParameter),
        residueIndexAt(frames.last.naturalParameter),
        atEnd: true,
      );
    }
  }

  return accumulator.toArrays();
}

/// Blends two equal-length profiles by [factor].
List<Vector2> _blendProfile(
  List<Vector2> round,
  List<Vector2> rect,
  double factor,
) {
  if (factor <= 0.0) return round;
  if (factor >= 1.0) return rect;
  return [
    for (int k = 0; k < round.length; k++)
      Vector2(
        round[k].x + (rect[k].x - round[k].x) * factor,
        round[k].y + (rect[k].y - round[k].y) * factor,
      ),
  ];
}

void _addProfileCap(
  _MeshAccumulator accumulator,
  OrientedFrame frame,
  List<Vector2> profile,
  Vector4 color,
  int residueIndex, {
  required bool atEnd,
}) {
  double centerX = 0.0;
  double centerY = 0.0;
  for (final point in profile) {
    centerX += point.x;
    centerY += point.y;
  }
  centerX /= profile.length;
  centerY /= profile.length;

  Vector3 lift(double x, double y) =>
      frame.position + frame.thinAxis * x + frame.wideAxis * y;

  final int centerIndex = accumulator.addVertex(
    lift(centerX, centerY),
    atEnd ? frame.tangent : -frame.tangent,
    centerX,
    centerY,
    color,
    residueIndex,
  );
  final List<int> ringIndices = [
    for (final point in profile)
      accumulator.addVertex(
        lift(point.x, point.y),
        atEnd ? frame.tangent : -frame.tangent,
        point.x,
        point.y,
        color,
        residueIndex,
      ),
  ];
  final int count = ringIndices.length;
  for (int k = 0; k < count; k++) {
    final int next = (k + 1) % count;
    if (atEnd) {
      accumulator.addTriangle(centerIndex, ringIndices[k], ringIndices[next]);
    } else {
      accumulator.addTriangle(centerIndex, ringIndices[next], ringIndices[k]);
    }
  }
}

void _stitchRings(
  _MeshAccumulator accumulator,
  List<int> ringBases,
  int ringSize,
) {
  for (int s = 0; s < ringBases.length - 1; s++) {
    final int base = ringBases[s];
    final int nextBase = ringBases[s + 1];
    for (int j = 0; j < ringSize - 1; j++) {
      final int a = base + j;
      final int b = base + j + 1;
      final int c = nextBase + j;
      final int d = nextBase + j + 1;
      accumulator
        ..addTriangle(a, c, b)
        ..addTriangle(b, c, d);
    }
  }
}

// Per-vertex outward 2D normals for a closed profile. The polygon's
// signed area picks the outward direction, so either winding works.
// (Mirrors flutter_scene's own private `_profileNormals` in
// swept_geometry.dart, which isn't exported for reuse.)
List<Vector2> _profileNormals(List<Vector2> profile) {
  final int count = profile.length;
  double doubledArea = 0.0;
  for (int k = 0; k < count; k++) {
    final Vector2 a = profile[k];
    final Vector2 b = profile[(k + 1) % count];
    doubledArea += a.x * b.y - b.x * a.y;
  }
  final double sign = doubledArea >= 0.0 ? 1.0 : -1.0;

  Vector2 edgeNormal(Vector2 edge) => Vector2(edge.y, -edge.x) * sign;

  return [
    for (int k = 0; k < count; k++)
      () {
        final Vector2 previous = profile[(k - 1 + count) % count];
        final Vector2 current = profile[k];
        final Vector2 next = profile[(k + 1) % count];
        Vector2 normal =
            edgeNormal(current - previous) + edgeNormal(next - current);
        if (normal.length2 < 1e-12) normal = edgeNormal(next - current);
        if (normal.length2 < 1e-12) normal = Vector2(1.0, 0.0);
        return normal.normalized();
      }(),
  ];
}

/// Growable vertex and index buffers for the extruded mesh.
class _MeshAccumulator {
  final List<double> _positions = [];
  final List<double> _normals = [];
  final List<double> _texCoords = [];
  final List<double> _colors = [];
  final List<int> _indices = [];
  final List<int> _residueForVertex = [];

  int get vertexCount => _positions.length ~/ 3;

  int addVertex(
    Vector3 position,
    Vector3 normal,
    double u,
    double v,
    Vector4 color,
    int residueIndex,
  ) {
    final int index = vertexCount;
    _positions
      ..add(position.x)
      ..add(position.y)
      ..add(position.z);
    _normals
      ..add(normal.x)
      ..add(normal.y)
      ..add(normal.z);
    _texCoords
      ..add(u)
      ..add(v);
    _colors
      ..add(color.x)
      ..add(color.y)
      ..add(color.z)
      ..add(color.w);
    _residueForVertex.add(residueIndex);
    return index;
  }

  void addTriangle(int a, int b, int c) {
    _indices
      ..add(a)
      ..add(b)
      ..add(c);
  }

  OrientedExtrudeArrays toArrays() => (
    positions: Float32List.fromList(_positions),
    normals: Float32List.fromList(_normals),
    texCoords: Float32List.fromList(_texCoords),
    colors: Float32List.fromList(_colors),
    indices: _indices,
    residueForVertex: _residueForVertex,
  );
}

/// Returns a unit-circle profile for the extruder.
List<Vector2> unitCircleProfile({int segments = 12}) {
  final List<Vector2> profile = [];
  for (int i = 0; i < segments; i++) {
    final double theta = 2 * math.pi * i / segments;
    profile.add(Vector2(math.cos(theta), math.sin(theta)));
  }
  return profile;
}

/// Returns matching round and rectangular profiles for blending.
///
/// [segments] must be a multiple of eight. Rectangle corners are duplicated
/// so adjacent faces retain independent normals.
({List<Vector2> round, List<Vector2> rect}) ribbonUnitProfiles({
  int segments = 16,
}) {
  if (segments % 8 != 0) {
    throw ArgumentError.value(
      segments,
      'segments',
      'must be a multiple of 8 so corners land on exact angles',
    );
  }
  final int period = segments ~/ 4;
  final int cornerOffset = segments ~/ 8;
  final List<Vector2> round = [];
  final List<Vector2> rect = [];
  for (int i = 0; i < segments; i++) {
    final double theta = 2 * math.pi * i / segments;
    final Vector2 p = Vector2(math.cos(theta), math.sin(theta));
    round.add(p);
    rect.add(_toRectPoint(p));
    if (i % period == cornerOffset) {
      round.add(p);
      rect.add(_toRectPoint(p));
    }
  }
  return (round: round, rect: rect);
}

/// Maps a unit-circle point to the boundary of a unit square.
Vector2 _toRectPoint(Vector2 p) {
  final double denom = math.max(p.x.abs(), p.y.abs());
  return denom < 1e-9 ? p : p / denom;
}
