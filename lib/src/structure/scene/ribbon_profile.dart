import 'package:vector_math/vector_math.dart';

import '../model/secondary_structure.dart';
import 'backbone_segment.dart';

/// Cross-section dimensions and round-to-rectangular blend for one station.
typedef ProfileSize = ({
  double halfThickness,
  double halfWidth,
  double rectFactor,
});

const ProfileSize _loopSize = (
  halfThickness: 0.18,
  halfWidth: 0.18,
  rectFactor: 0.0,
);
const ProfileSize _helixSize = (
  halfThickness: 0.28,
  halfWidth: 0.9,
  rectFactor: 0.0,
);
const ProfileSize _sheetSize = (
  halfThickness: 0.2,
  halfWidth: 0.8,
  rectFactor: 1.0,
);

/// Width multiplier for a beta-strand arrowhead shoulder.
const double arrowWidthFactor = 2.8;

/// Number of trailing residues used for a beta-strand arrowhead.
const int arrowheadResidueCount = 2;

/// Natural-parameter width of the arrowhead shoulder ramp.
const double _arrowShoulderRampFraction = 0.01;

/// A profile sample at a natural path parameter.
typedef ProfileSizeSample = ({double t, ProfileSize size});

/// RGBA colors for the three secondary-structure types.
typedef SecondaryStructureColorScheme = ({
  Vector4 helix,
  Vector4 sheet,
  Vector4 loop,
});

/// Default secondary-structure colors.
final SecondaryStructureColorScheme defaultColorScheme = (
  helix: Vector4(0.85, 0.25, 0.25, 1.0),
  sheet: Vector4(0.90, 0.80, 0.20, 1.0),
  loop: Vector4(0.80, 0.80, 0.80, 1.0),
);

/// Returns the default color for [type].
Vector4 colorFor(SecondaryStructureType type) => switch (type) {
  SecondaryStructureType.helix => defaultColorScheme.helix,
  SecondaryStructureType.sheet => defaultColorScheme.sheet,
  SecondaryStructureType.loop => defaultColorScheme.loop,
};

ProfileSize _normalSizeFor(SecondaryStructureType type) => switch (type) {
  SecondaryStructureType.helix => _helixSize,
  SecondaryStructureType.sheet => _sheetSize,
  SecondaryStructureType.loop => _loopSize,
};

/// Widens the arrowhead shoulder while preserving ribbon thickness.
ProfileSize _widened(ProfileSize size, double factor) => (
  halfThickness: size.halfThickness,
  halfWidth: size.halfWidth * factor,
  rectFactor: size.rectFactor,
);

/// Returns profile samples for [run], including beta-strand arrowheads.
List<ProfileSizeSample> ribbonProfileSizes(ContinuousRun run) {
  final int totalResidues = run.residues.length;
  final List<ProfileSize> base = List<ProfileSize>.filled(
    totalResidues,
    _loopSize,
  );
  final Set<int> shoulderIndices = {};

  int index = 0;
  for (int segIndex = 0; segIndex < run.segments.length; segIndex++) {
    final BackboneSegment segment = run.segments[segIndex];
    final int segStart = index;
    final int segLen = segment.residues.length;
    final ProfileSize normal = _normalSizeFor(segment.type);
    for (int j = 0; j < segLen; j++) {
      base[segStart + j] = normal;
    }

    if (segment.type == SecondaryStructureType.sheet && segLen >= 1) {
      final bool hasNext = segIndex < run.segments.length - 1;
      // The tip shrinks to the next segment's size, or to a point at the run's
      // end, but keeps the sheet's rectangular shape so arrowhead corners stay
      // sharp.
      final ProfileSize nextNormal = hasNext
          ? _normalSizeFor(run.segments[segIndex + 1].type)
          : normal;
      final ProfileSize tip = hasNext
          ? (
              halfThickness: nextNormal.halfThickness,
              halfWidth: nextNormal.halfWidth,
              rectFactor: normal.rectFactor,
            )
          : (halfThickness: 0.0, halfWidth: 0.0, rectFactor: normal.rectFactor);
      base[segStart + segLen - 1] = tip;
      if (segLen >= 2) {
        final int flareCount = arrowheadResidueCount - 1 < segLen - 1
            ? arrowheadResidueCount - 1
            : segLen - 1;
        for (int k = 1; k <= flareCount; k++) {
          final int shoulderIndex = segStart + segLen - 1 - k;
          base[shoulderIndex] = _widened(normal, arrowWidthFactor);
          shoulderIndices.add(shoulderIndex);
        }
      }
    }

    index += segLen;
  }

  // Sample t is normalized to the whole path, matching
  // OrientedFrame.naturalParameter.
  final double residueSpan = totalResidues > 1
      ? (totalResidues - 1).toDouble()
      : 1.0;
  double normalize(double residueIndex) => residueIndex / residueSpan;

  final List<ProfileSizeSample> samples = [];
  for (int i = 0; i < totalResidues; i++) {
    // A sample just before each shoulder keeps the flare short.
    if (shoulderIndices.contains(i) && i > 0) {
      samples.add((
        t: normalize(i - _arrowShoulderRampFraction),
        size: base[i - 1],
      ));
    }
    samples.add((t: normalize(i.toDouble()), size: base[i]));
  }

  return samples;
}

/// Returns one default RGBA color per residue in [run].
///
/// These colors are baked into the initial mesh; the viewer replaces them
/// with `CartoonStyle` colors before the first frame.
List<Vector4> ribbonColors(ContinuousRun run) => [
  for (final segment in run.segments)
    for (final _ in segment.residues) colorFor(segment.type),
];

/// Interpolates profile samples at normalized path parameter [t].
ProfileSize profileSizeAtParameter(List<ProfileSizeSample> samples, double t) {
  final int n = samples.length;
  if (n == 1) return samples[0].size;
  if (t <= samples.first.t) return samples.first.size;
  if (t >= samples.last.t) return samples.last.size;

  // Samples are in ascending t order.
  int lo = 0;
  int hi = n - 1;
  while (lo < hi - 1) {
    final int mid = (lo + hi) ~/ 2;
    if (samples[mid].t <= t) {
      lo = mid;
    } else {
      hi = mid;
    }
  }

  final ProfileSizeSample a = samples[lo];
  final ProfileSizeSample b = samples[hi];
  final double span = b.t - a.t;
  final double frac = span <= 0.0 ? 0.0 : (t - a.t) / span;
  return (
    halfThickness:
        a.size.halfThickness +
        (b.size.halfThickness - a.size.halfThickness) * frac,
    halfWidth: a.size.halfWidth + (b.size.halfWidth - a.size.halfWidth) * frac,
    rectFactor:
        a.size.rectFactor + (b.size.rectFactor - a.size.rectFactor) * frac,
  );
}

/// Returns the nearest residue color at normalized path parameter [t].
Vector4 colorAtParameter(List<Vector4> perResidue, double t) =>
    perResidue[residueIndexAtParameter(perResidue.length, t)];

/// Maps normalized path parameter [t] to the nearest residue index.
int residueIndexAtParameter(int totalResidues, double t) {
  if (totalResidues == 1) return 0;
  return (t.clamp(0.0, 1.0) * (totalResidues - 1)).round().clamp(
    0,
    totalResidues - 1,
  );
}
