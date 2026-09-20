import 'package:flutter_test/flutter_test.dart';
import 'package:bio_flutter/src/structure/model/atom.dart';
import 'package:bio_flutter/src/structure/model/residue.dart';
import 'package:bio_flutter/src/structure/model/secondary_structure.dart';
import 'package:bio_flutter/src/structure/scene/backbone_segment.dart';
import 'package:bio_flutter/src/structure/scene/ribbon_profile.dart';
import 'package:vector_math/vector_math.dart';

Atom _ca(double x) => Atom(
  serial: 1,
  element: 'C',
  atomName: 'CA',
  position: Vector3(x, 0, 0),
  occupancy: 1,
  bFactor: 20,
  isHeteroRecord: false,
);

Residue _residue(int seq, double x, SecondaryStructureType type) => Residue(
  id: ResidueId(seq, ''),
  name: 'ALA',
  atoms: [_ca(x)],
  secondaryStructure: type,
);

BackboneSegment _segment(SecondaryStructureType type, List<int> seqIds) =>
    BackboneSegment(
      chainId: 'A',
      type: type,
      residues: [for (final seq in seqIds) _residue(seq, seq * 3.8, type)],
    );

// `ribbonProfileSizes` stores `t` normalized to the path's own 0..1 range
// (see the comment in ribbon_profile.dart on why), not a raw residue index
// -- this converts a residue index into that same normalized space for
// test assertions, given a run of [totalResidues] residues.
double _normalizedT(int residueIndex, int totalResidues) =>
    totalResidues > 1 ? residueIndex / (totalResidues - 1) : 0.0;

void main() {
  group('ribbonProfileSizes', () {
    test('plain loop residues all get the loop size', () {
      final run = ContinuousRun(
        chainId: 'A',
        authChainId: 'A',
        segments: [
          _segment(SecondaryStructureType.loop, [1, 2, 3, 4]),
        ],
      );
      final samples = ribbonProfileSizes(run);
      // No arrowhead shoulder in a run with no sheet segment, so no extra
      // ramp-in sample is inserted: exactly one sample per residue.
      expect(samples, hasLength(4));
      expect(samples.map((s) => s.t), [0.0, 1 / 3, 2 / 3, 1.0]);
      for (final sample in samples) {
        expect(sample.size.halfWidth, sample.size.halfThickness);
      }
    });

    test('a sheet segment followed by another segment tapers its last residue to the following size, not zero', () {
      final sheet = _segment(SecondaryStructureType.sheet, [1, 2, 3, 4, 5]);
      final loop = _segment(SecondaryStructureType.loop, [6, 7, 8]);
      final run = ContinuousRun(
        chainId: 'A',
        authChainId: 'A',
        segments: [sheet, loop],
      );
      final samples = ribbonProfileSizes(run);

      // The sheet's last residue is at residue index 4 (id 5) of 8 total.
      final tipSample = samples.firstWhere((s) => s.t == _normalizedT(4, 8));
      final loopSize = ribbonProfileSizes(
        ContinuousRun(chainId: 'A', authChainId: 'A', segments: [loop]),
      ).first.size;
      expect(tipSample.size.halfWidth, closeTo(loopSize.halfWidth, 1e-9));
      expect(
        tipSample.size.halfThickness,
        closeTo(loopSize.halfThickness, 1e-9),
      );
      expect(tipSample.size.halfWidth, isNot(0.0));
    });

    test('a sheet segment with nothing following tapers its last residue to zero (a true arrow tip)', () {
      final sheet = _segment(SecondaryStructureType.sheet, [1, 2, 3, 4, 5]);
      final run = ContinuousRun(
        chainId: 'A',
        authChainId: 'A',
        segments: [sheet],
      );
      final samples = ribbonProfileSizes(run);
      final tipSample = samples.firstWhere((s) => s.t == _normalizedT(4, 5));
      expect(tipSample.size.halfWidth, 0.0);
      expect(tipSample.size.halfThickness, 0.0);
    });

    test('the second-to-last residue of a sheet segment flares wider than normal, via a short ramp-in', () {
      final sheet = _segment(SecondaryStructureType.sheet, [1, 2, 3, 4, 5]);
      final run = ContinuousRun(
        chainId: 'A',
        authChainId: 'A',
        segments: [sheet],
      );
      final samples = ribbonProfileSizes(run);
      final normalSize =
          samples.first.size; // an unaffected, normal-width residue

      // The shoulder residue itself (residue index 3 of 5) is at full flare
      // width. Thickness stays put -- a real ribbon arrow flares in width
      // only, not thickness (flaring both reads as a lens/box lump rather
      // than a flat wedge, especially once the rectangular sheet profile
      // is in play -- see `_widened` in ribbon_profile.dart).
      final shoulderT = _normalizedT(3, 5);
      final shoulderSample = samples.firstWhere((s) => s.t == shoulderT);
      expect(shoulderSample.size.halfWidth, greaterThan(normalSize.halfWidth));
      expect(
        shoulderSample.size.halfThickness,
        closeTo(normalSize.halfThickness, 1e-9),
      );

      // A short ramp-in sample sits just before it, still at normal width --
      // this is what keeps the flare-out sharp instead of spread across the
      // whole preceding residue.
      final rampSample = samples.firstWhere(
        (s) => s.t > _normalizedT(2, 5) && s.t < shoulderT,
      );
      expect(rampSample.t, closeTo(shoulderT, 0.2));
      expect(rampSample.size, normalSize);
    });

    test('residues before the arrowhead region keep normal sheet size', () {
      final sheet = _segment(SecondaryStructureType.sheet, [1, 2, 3, 4, 5, 6]);
      final run = ContinuousRun(
        chainId: 'A',
        authChainId: 'A',
        segments: [sheet],
      );
      final samples = ribbonProfileSizes(run);
      final normalSize = samples.first.size;
      for (int i = 0; i < 3; i++) {
        expect(
          samples.firstWhere((s) => s.t == _normalizedT(i, 6)).size,
          normalSize,
        );
      }
    });

    test(
      'a 1-residue sheet segment does not crash and still tapers to its tip',
      () {
        final sheet = _segment(SecondaryStructureType.sheet, [1]);
        final run = ContinuousRun(
          chainId: 'A',
          authChainId: 'A',
          segments: [sheet],
        );
        final samples = ribbonProfileSizes(run);
        expect(samples, hasLength(1));
        expect(samples[0].size.halfWidth, 0.0);
      },
    );

    test('regression: samples span the full 0..1 path range, not a fixed per-residue step', () {
      // A run realistically longer than a couple of residues -- if `t` were
      // ever stored as a raw residue index instead of normalized against
      // path length, every query in `[0, 1]` would land between the first
      // two samples only, freezing the whole rest of the ribbon at (near)
      // the first residue's size -- reported as "it was all tubular".
      final sheet = _segment(
        SecondaryStructureType.sheet,
        List.generate(200, (i) => i + 1),
      );
      final run = ContinuousRun(
        chainId: 'A',
        authChainId: 'A',
        segments: [sheet],
      );
      final samples = ribbonProfileSizes(run);
      expect(samples.first.t, 0.0);
      expect(samples.last.t, 1.0);
      // A query near the end of the path must resolve near the run's own
      // end (partway down the taper into the near-zero arrow tip), not
      // near the first residue's normal width.
      final nearEnd = profileSizeAtParameter(samples, 0.999);
      expect(nearEnd.halfWidth, lessThan(samples.first.size.halfWidth));
    });

    test('a 2-residue sheet segment at the very start of a run has no ramp-in sample to insert', () {
      final sheet = _segment(SecondaryStructureType.sheet, [1, 2]);
      final run = ContinuousRun(
        chainId: 'A',
        authChainId: 'A',
        segments: [sheet],
      );
      final samples = ribbonProfileSizes(run);
      // Shoulder is residue 0 -- nothing precedes it to ramp from, so just
      // the plain per-residue samples, no crash, no negative t.
      expect(samples, hasLength(2));
      expect(samples.map((s) => s.t), [0.0, 1.0]);
    });
  });

  group('ribbonColors', () {
    test(
      'one color per residue, matching that residue\'s own segment type',
      () {
        final helix = _segment(SecondaryStructureType.helix, [1, 2]);
        final loop = _segment(SecondaryStructureType.loop, [3, 4, 5]);
        final run = ContinuousRun(
          chainId: 'A',
          authChainId: 'A',
          segments: [helix, loop],
        );
        final colors = ribbonColors(run);
        expect(colors, hasLength(5));
        expect(colors[0], colors[1]);
        expect(colors[2], colors[3]);
        expect(colors[3], colors[4]);
        expect(colors[0], isNot(colors[2]));
      },
    );
  });

  group('profileSizeAtParameter', () {
    test('returns the exact sample value at its own t', () {
      const samples = [
        (t: 0.0, size: (halfThickness: 0.3, halfWidth: 0.3, rectFactor: 0.0)),
        (t: 1.0, size: (halfThickness: 0.9, halfWidth: 0.28, rectFactor: 0.0)),
        (t: 2.0, size: (halfThickness: 0.2, halfWidth: 0.8, rectFactor: 1.0)),
      ];
      expect(profileSizeAtParameter(samples, 0.0), samples[0].size);
      expect(profileSizeAtParameter(samples, 1.0), samples[1].size);
      expect(profileSizeAtParameter(samples, 2.0), samples[2].size);
    });

    test('interpolates linearly between samples', () {
      const samples = [
        (t: 0.0, size: (halfThickness: 0.0, halfWidth: 0.0, rectFactor: 0.0)),
        (t: 1.0, size: (halfThickness: 1.0, halfWidth: 2.0, rectFactor: 1.0)),
      ];
      final mid = profileSizeAtParameter(samples, 0.5);
      expect(mid.halfThickness, closeTo(0.5, 1e-9));
      expect(mid.halfWidth, closeTo(1.0, 1e-9));
      expect(mid.rectFactor, closeTo(0.5, 1e-9));
    });

    test('respects uneven spacing between samples', () {
      // Mirrors the arrowhead ramp-in shape: flat, then a short sharp ramp.
      const samples = [
        (t: 0.0, size: (halfThickness: 0.3, halfWidth: 0.3, rectFactor: 1.0)),
        (t: 0.9, size: (halfThickness: 0.3, halfWidth: 0.3, rectFactor: 1.0)),
        (t: 1.0, size: (halfThickness: 0.6, halfWidth: 0.6, rectFactor: 1.0)),
      ];
      // Still flat right up to the ramp.
      expect(
        profileSizeAtParameter(samples, 0.85).halfWidth,
        closeTo(0.3, 1e-9),
      );
      // Roughly midway through the short ramp.
      expect(
        profileSizeAtParameter(samples, 0.95).halfWidth,
        closeTo(0.45, 1e-9),
      );
    });

    test('a single entry is returned regardless of t', () {
      const samples = [
        (t: 0.0, size: (halfThickness: 0.4, halfWidth: 0.4, rectFactor: 0.0)),
      ];
      expect(profileSizeAtParameter(samples, 0.0), samples[0].size);
      expect(profileSizeAtParameter(samples, 1.0), samples[0].size);
    });
  });

  group('colorAtParameter', () {
    test('picks the nearest residue\'s color without blending', () {
      final colors = [
        Vector4(1, 0, 0, 1),
        Vector4(0, 1, 0, 1),
        Vector4(0, 0, 1, 1),
      ];
      expect(colorAtParameter(colors, 0.0), colors[0]);
      expect(colorAtParameter(colors, 0.1), colors[0]);
      expect(colorAtParameter(colors, 0.4), colors[1]);
      expect(colorAtParameter(colors, 1.0), colors[2]);
    });
  });
}
