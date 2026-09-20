import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

import 'backbone_orientation.dart';
import 'backbone_segment.dart';
import 'oriented_frame.dart';
import 'ribbon_profile.dart';

/// Fixed triangle count per picking box, allowing direct residue lookup.
/// Ribbon caps have variable triangle counts, so picking uses separate boxes.
const int triangleCountPerResidue = 12;

/// Minimum half-extent (Å) for a residue picking box.
const double _minPickHalfExtent = 0.12;

/// The residue index (into a [ContinuousRun]'s `residues`) a picking-proxy
/// raycast hit's `triangleIndex` resolves to.
int residueIndexForProxyTriangle(int triangleIndex) =>
    triangleIndex ~/ triangleCountPerResidue;

/// Returns the unindexed triangles for one residue's oriented hit box.
///
/// The box spans adjacent residues along the tangent and follows the ribbon's
/// cross-section axes.
List<Vector3> residueHitBoxVertices(
  OrientedFrame frame, {
  required double backSpan,
  required double frontSpan,
  required double halfWidth,
  required double halfThickness,
}) {
  // Bits: s (0 = toward previous residue, 1 = toward next), w (wideAxis
  // sign), t (thinAxis sign). `corners[s*4 + w*2 + t]`.
  final List<Vector3> corners = [
    for (int s = 0; s < 2; s++)
      for (int w = 0; w < 2; w++)
        for (int t = 0; t < 2; t++)
          frame.position +
              frame.tangent * (s == 0 ? -backSpan : frontSpan) +
              frame.wideAxis * ((w == 0 ? -1.0 : 1.0) * halfWidth) +
              frame.thinAxis * ((t == 0 ? -1.0 : 1.0) * halfThickness),
  ];
  Vector3 at(int s, int w, int t) => corners[s * 4 + w * 2 + t];

  final List<Vector3> out = [];
  void quad(Vector3 a, Vector3 b, Vector3 c, Vector3 d) {
    out
      ..add(a)
      ..add(b)
      ..add(c)
      ..add(a)
      ..add(c)
      ..add(d);
  }

  quad(
    at(0, 0, 0),
    at(0, 1, 0),
    at(0, 1, 1),
    at(0, 0, 1),
  ); // toward-previous face
  quad(at(1, 0, 0), at(1, 1, 0), at(1, 1, 1), at(1, 0, 1)); // toward-next face
  quad(at(0, 0, 0), at(1, 0, 0), at(1, 0, 1), at(0, 0, 1)); // wideAxis- face
  quad(at(0, 1, 0), at(1, 1, 0), at(1, 1, 1), at(0, 1, 1)); // wideAxis+ face
  quad(at(0, 0, 0), at(1, 0, 0), at(1, 1, 0), at(0, 1, 0)); // thinAxis- face
  quad(at(0, 0, 1), at(1, 0, 1), at(1, 1, 1), at(0, 1, 1)); // thinAxis+ face

  return out;
}

/// Returns all residue hit boxes in run order.
List<Vector3> buildPickingProxyVertices(ContinuousRun run) {
  final List<Vector3> points = [
    for (final r in run.residues) r.alphaCarbon!.position,
  ];
  if (points.length < 2) return const [];

  final List<Vector3> directions = backboneOrientationVectors(run.residues);
  final CatmullRomPath path = CatmullRomPath(points);
  // One frame per *residue*, not one per mesh station — the render mesh's
  // 8x/16x-per-residue sweep resolution buys smoothness picking doesn't
  // need. `computeOrientedFrames` distributes stations evenly by arc
  // length, which only approximately (not exactly) lands each frame at
  // its same-index residue's true position, since real inter-residue
  // spacing isn't perfectly uniform — an approximation the render mesh
  // already relies on at every other station count, and one a
  // residue-sized hit box comfortably absorbs.
  final List<OrientedFrame> frames = computeOrientedFrames(
    positionPath: path,
    residueDirectionVectors: directions,
    stations: points.length,
  );
  final List<ProfileSizeSample> sizes = ribbonProfileSizes(run);

  final List<Vector3> out = [];
  for (int i = 0; i < points.length; i++) {
    final OrientedFrame frame = frames[i];
    final ProfileSize size = profileSizeAtParameter(
      sizes,
      frame.naturalParameter,
    );
    final double distToPrev = i > 0
        ? frames[i - 1].position.distanceTo(frame.position)
        : double.nan;
    final double distToNext = i < points.length - 1
        ? frame.position.distanceTo(frames[i + 1].position)
        : double.nan;
    // A terminus residue has only one real neighbor distance; mirror it to
    // the other side rather than leaving that side unbounded or zero.
    final double backSpan = (i > 0 ? distToPrev : distToNext) / 2;
    final double frontSpan =
        (i < points.length - 1 ? distToNext : distToPrev) / 2;

    out.addAll(
      residueHitBoxVertices(
        frame,
        backSpan: backSpan,
        frontSpan: frontSpan,
        halfWidth: size.halfWidth < _minPickHalfExtent
            ? _minPickHalfExtent
            : size.halfWidth,
        halfThickness: size.halfThickness < _minPickHalfExtent
            ? _minPickHalfExtent
            : size.halfThickness,
      ),
    );
  }
  return out;
}

/// Builds an invisible picking proxy, or null for a run with fewer than two residues.
/// Raycasts must enable `includeInvisible` to intersect it.
Node? buildPickingProxyNode(ContinuousRun run) {
  final List<Vector3> vertices = buildPickingProxyVertices(run);
  if (vertices.isEmpty) return null;

  final Float32List positions = Float32List(vertices.length * 3);
  for (int i = 0; i < vertices.length; i++) {
    positions[i * 3] = vertices[i].x;
    positions[i * 3 + 1] = vertices[i].y;
    positions[i * 3 + 2] = vertices[i].z;
  }

  // The proxy is a triangle soup used only for raycasting.
  final MeshGeometry geometry = MeshGeometry.fromArrays(positions: positions);
  final Node node = Node(mesh: Mesh(geometry, UnlitMaterial()))
    ..visible = false
    ..raycastable = true;
  return node;
}
