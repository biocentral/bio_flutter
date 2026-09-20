import 'package:flutter_test/flutter_test.dart';
import 'package:bio_flutter/src/structure/model/atom.dart';
import 'package:bio_flutter/src/structure/model/residue.dart';
import 'package:bio_flutter/src/structure/model/secondary_structure.dart';
import 'package:bio_flutter/src/structure/scene/backbone_segment.dart';
import 'package:bio_flutter/src/structure/scene/oriented_frame.dart';
import 'package:bio_flutter/src/structure/scene/picking_proxy.dart';
import 'package:vector_math/vector_math.dart';

Atom _ca(Vector3 pos) => Atom(
  serial: 1,
  element: 'C',
  atomName: 'CA',
  position: pos,
  occupancy: 1,
  bFactor: 20,
  isHeteroRecord: false,
);

Residue _residue(int seq, Vector3 pos, SecondaryStructureType type) => Residue(
  id: ResidueId(seq, ''),
  name: 'ALA',
  atoms: [_ca(pos)],
  secondaryStructure: type,
);

BackboneSegment _segment(
  SecondaryStructureType type,
  List<Vector3> positions,
) => BackboneSegment(
  chainId: 'A',
  type: type,
  residues: [
    for (int i = 0; i < positions.length; i++)
      _residue(i + 1, positions[i], type),
  ],
);

ContinuousRun _straightLoopRun(int residueCount, {double spacing = 3.8}) {
  final positions = [
    for (int i = 0; i < residueCount; i++) Vector3(i * spacing, 0, 0),
  ];
  return ContinuousRun(
    chainId: 'A',
    authChainId: 'A',
    segments: [_segment(SecondaryStructureType.loop, positions)],
  );
}

// An axis-aligned frame (tangent = +x, wideAxis = +y, thinAxis = +z) makes
// box-bounds assertions simple arithmetic rather than needing to project
// onto an arbitrary basis.
OrientedFrame _axisAlignedFrame() => OrientedFrame(
  position: Vector3.zero(),
  tangent: Vector3(1, 0, 0),
  wideAxis: Vector3(0, 1, 0),
  thinAxis: Vector3(0, 0, 1),
  naturalParameter: 0.5,
);

void main() {
  group('residueHitBoxVertices', () {
    test('emits 36 vertices (12 triangles, unindexed)', () {
      final vertices = residueHitBoxVertices(
        _axisAlignedFrame(),
        backSpan: 1.0,
        frontSpan: 2.0,
        halfWidth: 0.5,
        halfThickness: 0.3,
      );
      expect(vertices, hasLength(36));
    });

    // `Vector3` is Float32List-backed, so an exact-double bound like `-0.3`
    // can come back as `-0.30000001192092896` after a round trip through
    // float32 -- these tolerances absorb that, not real geometry slop.
    const eps = 1e-5;

    test('every vertex stays within the box bounds along each local axis', () {
      final vertices = residueHitBoxVertices(
        _axisAlignedFrame(),
        backSpan: 1.0,
        frontSpan: 2.0,
        halfWidth: 0.5,
        halfThickness: 0.3,
      );
      for (final v in vertices) {
        expect(
          v.x,
          inInclusiveRange(-1.0 - eps, 2.0 + eps),
        ); // -backSpan .. frontSpan
        expect(
          v.y,
          inInclusiveRange(-0.5 - eps, 0.5 + eps),
        ); // -halfWidth .. halfWidth
        expect(
          v.z,
          inInclusiveRange(-0.3 - eps, 0.3 + eps),
        ); // -halfThickness .. halfThickness
      }
    });

    test(
      'reaches all 8 corners, including the asymmetric back/front extremes',
      () {
        final vertices = residueHitBoxVertices(
          _axisAlignedFrame(),
          backSpan: 1.0,
          frontSpan: 2.0,
          halfWidth: 0.5,
          halfThickness: 0.3,
        );
        bool hasCorner(double x, double y, double z) => vertices.any(
          (v) =>
              (v.x - x).abs() < eps &&
              (v.y - y).abs() < eps &&
              (v.z - z).abs() < eps,
        );
        for (final xSign in [-1.0, 2.0]) {
          for (final ySign in [-0.5, 0.5]) {
            for (final zSign in [-0.3, 0.3]) {
              expect(
                hasCorner(xSign, ySign, zSign),
                isTrue,
                reason: '($xSign, $ySign, $zSign)',
              );
            }
          }
        }
      },
    );
  });

  group('residueIndexForProxyTriangle', () {
    test(
      'maps a run of triangle indices back to consecutive residue indices',
      () {
        expect(residueIndexForProxyTriangle(0), 0);
        expect(residueIndexForProxyTriangle(11), 0);
        expect(residueIndexForProxyTriangle(12), 1);
        expect(residueIndexForProxyTriangle(23), 1);
        expect(residueIndexForProxyTriangle(24), 2);
      },
    );
  });

  group('buildPickingProxyVertices', () {
    test('empty for a run with fewer than two residues', () {
      final run = _straightLoopRun(1);
      expect(buildPickingProxyVertices(run), isEmpty);
    });

    test('emits exactly 36 vertices (12 triangles) per residue', () {
      final run = _straightLoopRun(5);
      final vertices = buildPickingProxyVertices(run);
      expect(vertices, hasLength(5 * 36));
    });

    test(
      'each residue\'s box is centered near that residue\'s own CA position',
      () {
        // A straight, evenly-spaced synthetic backbone has exactly uniform
        // arc-length speed, so `computeOrientedFrames(stations: residueCount)`
        // lands frame i exactly at residue i's position -- no approximation
        // slack to account for here.
        final run = _straightLoopRun(5, spacing: 3.8);
        final vertices = buildPickingProxyVertices(run);
        for (int i = 0; i < 5; i++) {
          final boxVertices = vertices.sublist(i * 36, (i + 1) * 36);
          final double meanX =
              boxVertices.map((v) => v.x).reduce((a, b) => a + b) /
              boxVertices.length;
          expect(
            meanX,
            closeTo(i * 3.8, 1e-4),
          ); // float32-backed Vector3, not exact-double precision
        }
      },
    );

    test('adjacent residues\' boxes meet edge-to-edge, no gap or overlap', () {
      final run = _straightLoopRun(4, spacing: 3.8);
      final vertices = buildPickingProxyVertices(run);
      for (int i = 0; i < 3; i++) {
        final boxA = vertices.sublist(i * 36, (i + 1) * 36);
        final boxB = vertices.sublist((i + 1) * 36, (i + 2) * 36);
        final double frontOfA = boxA
            .map((v) => v.x)
            .reduce((a, b) => a > b ? a : b);
        final double backOfB = boxB
            .map((v) => v.x)
            .reduce((a, b) => a < b ? a : b);
        expect(
          frontOfA,
          closeTo(backOfB, 1e-4),
        ); // float32-backed Vector3, not exact-double precision
      }
    });

    test('a zero-size profile (a true beta-strand arrow tip) still gets a clickable, non-degenerate box', () {
      final sheet = _segment(SecondaryStructureType.sheet, [
        Vector3(0, 0, 0),
        Vector3(3.8, 0, 0),
        Vector3(7.6, 0, 0),
      ]);
      final run = ContinuousRun(
        chainId: 'A',
        authChainId: 'A',
        segments: [sheet],
      );
      final vertices = buildPickingProxyVertices(run);
      // Residue index 2 (the last of a 3-residue sheet with nothing
      // following) tapers to a true zero-width/zero-thickness point in
      // `ribbonProfileSizes` -- its box must still have real volume.
      final tipBox = vertices.sublist(2 * 36, 3 * 36);
      final double spreadY =
          tipBox.map((v) => v.y).reduce((a, b) => a > b ? a : b) -
          tipBox.map((v) => v.y).reduce((a, b) => a < b ? a : b);
      final double spreadZ =
          tipBox.map((v) => v.z).reduce((a, b) => a > b ? a : b) -
          tipBox.map((v) => v.z).reduce((a, b) => a < b ? a : b);
      expect(spreadY, greaterThan(0.0));
      expect(spreadZ, greaterThan(0.0));
    });
  });
}
