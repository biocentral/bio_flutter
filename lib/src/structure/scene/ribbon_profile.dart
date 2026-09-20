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

/// Returns the color for [type], using [defaultColorScheme] when omitted.
Vector4 colorFor(
  SecondaryStructureType type, {
  SecondaryStructureColorScheme? scheme,
}) {
  final SecondaryStructureColorScheme resolved = scheme ?? defaultColorScheme;
  return switch (type) {
    SecondaryStructureType.helix => resolved.helix,
    SecondaryStructureType.sheet => resolved.sheet,
    SecondaryStructureType.loop => resolved.loop,
  };
}

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
      // The tip's *size* converges to whatever follows (or to a true zero
      // point at a run's actual terminus) exactly as before, but its
      // `rectFactor` deliberately stays at the sheet's own (1.0) rather
      // than following the next segment's — otherwise the round/rect shape
      // morph would land across the arrowhead taper itself, softening
      // exactly the corner the rectangular profile exists to sharpen. The
      // shape morph instead happens over the following segment's own
      // residues, right after the tip, where the cross-section is already
      // small and round-vs-square is barely distinguishable.
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

  // `ScenePath.parameterAtDistance` (and so `OrientedFrame.naturalParameter`,
  // what callers actually query these samples with) is normalized to 0..1
  // across the *whole* path, not 0..(totalResidues - 1) — one residue-index
  // step is worth 1 / (totalResidues - 1) of that range. Every `t` stored
  // here has to be in that same normalized space, or a query never reaches
  // past the first residue or two before hitting the `t >= samples.last.t`
  // clamp in `profileSizeAtParameter`, and the whole rest of the ribbon
  // reads as one frozen (tubular) cross-section.
  final double residueSpan = totalResidues > 1
      ? (totalResidues - 1).toDouble()
      : 1.0;
  double normalize(double residueIndex) => residueIndex / residueSpan;

  final List<ProfileSizeSample> samples = [];
  for (int i = 0; i < totalResidues; i++) {
    // A shoulder residue's own base value is already the flared width;
    // the sample just before it (still at the previous, normal width)
    // pins the ramp-in to a short stretch instead of the whole prior
    // residue. Skipped when there's no room for it (the shoulder is the
    // run's very first residue) — nothing precedes it to ramp from.
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

/// Returns one RGBA color per residue in [run].
List<Vector4> ribbonColors(
  ContinuousRun run, {
  SecondaryStructureColorScheme? scheme,
}) => [
  for (final segment in run.segments)
    for (final _ in segment.residues) colorFor(segment.type, scheme: scheme),
];

/// Interpolates profile samples at normalized path parameter [t].
ProfileSize profileSizeAtParameter(List<ProfileSizeSample> samples, double t) {
  final int n = samples.length;
  if (n == 1) return samples[0].size;
  if (t <= samples.first.t) return samples.first.size;
  if (t >= samples.last.t) return samples.last.size;

  // Binary search for the first sample whose t exceeds the query -- samples
  // are constructed in ascending t order, so this is always valid.
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
