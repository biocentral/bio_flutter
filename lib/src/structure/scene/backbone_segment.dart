import 'package:vector_math/vector_math.dart';

import '../model/chain.dart';
import '../model/molecular_structure.dart';
import '../model/residue.dart';
import '../model/secondary_structure.dart';

/// Above this Cα–Cα distance (Å), two candidate neighbor residues are
/// treated as not physically bonded — a genuine chain break (missing
/// density) — even if their sequence numbers look adjacent. Comfortably
/// above the ~3.8 Å typical spacing along a modeled backbone, to tolerate
/// normal geometric variation, and comfortably below the distance a real
/// gap produces in practice.
const double maxBondedCaDistance = 5.0;

/// A contiguous run of one chain's residues sharing the same
/// [SecondaryStructureType], with no chain break in between.
class BackboneSegment {
  const BackboneSegment({
    required this.chainId,
    required this.type,
    required this.residues,
  });

  final String chainId;
  final SecondaryStructureType type;

  /// Every residue here has a non-null [Residue.alphaCarbon].
  final List<Residue> residues;

  List<Vector3> get alphaCarbonPositions => [
    for (final r in residues) r.alphaCarbon!.position,
  ];
}

/// Splits every chain's alpha-carbon trace into [BackboneSegment]s.
///
/// A segment ends, and a new one starts, whenever either the next kept
/// residue's secondary-structure type differs, or [isChainContiguous]
/// says the previous and next kept residues aren't bonded neighbors.
///
/// Residues without a resolved CA are dropped from the trace — but,
/// critically, **not treated as a break by themselves**: such a residue
/// still has other atoms in the file (that's how it has a chain entry at
/// all — a residue entirely absent from the file never becomes a
/// [Residue] to begin with), so skipping over it while building the trace
/// must not be confused with a genuine gap. See [isChainContiguous] for
/// how the distinction is made.
List<BackboneSegment> buildBackboneSegments(MolecularStructure structure) {
  final List<BackboneSegment> segments = [];

  for (final Chain chain in structure.chains) {
    final List<Residue> withCa = [
      for (final r in chain.residues)
        if (r.alphaCarbon != null) r,
    ];
    if (withCa.isEmpty) continue;

    SecondaryStructureType currentType = withCa.first.secondaryStructure;
    List<Residue> current = [withCa.first];

    void flush() {
      segments.add(
        BackboneSegment(
          chainId: chain.id,
          type: currentType,
          residues: current,
        ),
      );
    }

    for (int i = 1; i < withCa.length; i++) {
      final Residue residue = withCa[i];
      final Residue previous = withCa[i - 1];
      final bool sameType = residue.secondaryStructure == currentType;

      if (sameType && isChainContiguous(chain, previous, residue)) {
        current.add(residue);
      } else {
        flush();
        currentType = residue.secondaryStructure;
        current = [residue];
      }
    }
    flush();
  }

  return segments;
}

/// A maximal run of one chain's residues with **no chain break** — unlike
/// [BackboneSegment], not split by secondary-structure type. This is the
/// unit the cartoon renderer sweeps as a single connected mesh, so a
/// helix-to-loop or loop-to-sheet transition never shows the seam a
/// separately-capped mesh boundary would.
///
/// Built by grouping the [BackboneSegment]s already produced by
/// [buildBackboneSegments] — not by walking chain residues a second time,
/// which could drift out of agreement with that function's own
/// break/no-break decisions.
class ContinuousRun {
  const ContinuousRun({
    required this.chainId,
    required this.authChainId,
    required this.segments,
  });

  /// `label_asym_id` — the internal grouping key (see [Chain.id]).
  final String chainId;

  /// `auth_asym_id` (see [Chain.authChainId]) — resolved once here, at
  /// [buildContinuousRuns] time, so picking/highlighting code (which keys
  /// externally on auth chain ID, matching [ResidueId]'s own auth-space
  /// `authSeqId`) never needs to re-look this up from a chain map alongside
  /// a [ContinuousRun] it already has.
  final String authChainId;

  /// In sequence order; consecutive segments here are guaranteed bonded
  /// neighbors ([isChainContiguous]), so nothing here is a real break.
  final List<BackboneSegment> segments;

  List<Residue> get residues => [
    for (final segment in segments) ...segment.residues,
  ];
}

/// Groups [buildBackboneSegments]' output into [ContinuousRun]s: still one
/// [BackboneSegment] per secondary-structure run, but consecutive segments
/// of a chain that are bonded neighbors (a plain secondary-structure
/// change, not a real gap) are merged into the same run.
List<ContinuousRun> buildContinuousRuns(MolecularStructure structure) {
  final List<BackboneSegment> segments = buildBackboneSegments(structure);
  final Map<String, Chain> chainById = {
    for (final c in structure.chains) c.id: c,
  };

  final List<ContinuousRun> runs = [];
  List<BackboneSegment>? current;

  for (final BackboneSegment segment in segments) {
    if (current != null &&
        current.last.chainId == segment.chainId &&
        isChainContiguous(
          chainById[segment.chainId]!,
          current.last.residues.last,
          segment.residues.first,
        )) {
      current.add(segment);
    } else {
      if (current != null) {
        runs.add(
          ContinuousRun(
            chainId: current.first.chainId,
            authChainId: chainById[current.first.chainId]!.authChainId,
            segments: current,
          ),
        );
      }
      current = [segment];
    }
  }
  if (current != null) {
    runs.add(
      ContinuousRun(
        chainId: current.first.chainId,
        authChainId: chainById[current.first.chainId]!.authChainId,
        segments: current,
      ),
    );
  }

  return runs;
}

/// Whether two Cα residues are bonded neighbors.
///
/// Both sequence continuity and the distance threshold must pass. Missing-Cα
/// residues increase the permitted distance for the bridged interval.
bool isChainContiguous(Chain chain, Residue previous, Residue next) {
  final (bool hasGap, int skippedCaLessResidues) = sequenceGapInfo(
    chain,
    previous.id,
    next.id,
  );
  if (hasGap) return false;

  final double allowedDistance =
      maxBondedCaDistance * (1 + skippedCaLessResidues);
  final double distance = previous.alphaCarbon!.position.distanceTo(
    next.alphaCarbon!.position,
  );
  return distance <= allowedDistance;
}

/// Returns sequence continuity and the number of intervening residues without Cα.
(bool hasGap, int skippedCount) sequenceGapInfo(
  Chain chain,
  ResidueId from,
  ResidueId to,
) {
  final int fromIndex = chain.residues.indexWhere((r) => r.id == from);
  final int toIndex = chain.residues.indexWhere((r) => r.id == to);
  if (fromIndex == -1 || toIndex == -1 || toIndex <= fromIndex) {
    // Shouldn't happen for two residues drawn from this same chain in
    // file order; be lenient rather than throwing.
    return (false, 0);
  }
  for (int i = fromIndex + 1; i <= toIndex; i++) {
    final int diff =
        chain.residues[i].id.authSeqId - chain.residues[i - 1].id.authSeqId;
    if (diff != 0 && diff != 1) return (true, 0);
  }
  return (false, toIndex - fromIndex - 1);
}
