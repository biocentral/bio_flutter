import '../model/chain.dart';
import '../model/molecular_structure.dart';
import '../model/residue.dart';
import '../model/secondary_structure.dart';

/// Cα-Cα distance (Å) above which residues count as a chain break, even when
/// their numbering is consecutive. Bonded neighbors are about 3.8 Å apart.
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
}

/// Splits each chain's Cα trace into [BackboneSegment]s at
/// secondary-structure changes and chain breaks.
///
/// Residues without Cα are left out of the trace but are not breaks by
/// themselves; see [isChainContiguous].
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

/// A maximal run of one chain's residues with no chain break, rendered as
/// one mesh so secondary-structure transitions have no seams.
class ContinuousRun {
  const ContinuousRun({
    required this.chainId,
    required this.authChainId,
    required this.segments,
  });

  /// `label_asym_id`, the grouping key (see [Chain.id]).
  final String chainId;

  /// `auth_asym_id` (see [Chain.authChainId]): display metadata only.
  /// Picking and highlighting key on [chainId], as `ResidueKey` does.
  final String authChainId;

  /// In sequence order; consecutive segments are bonded neighbors.
  final List<BackboneSegment> segments;

  List<Residue> get residues => [
    for (final segment in segments) ...segment.residues,
  ];
}

/// Groups [buildBackboneSegments] output into [ContinuousRun]s, merging
/// consecutive segments that are bonded neighbors.
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
/// Both sequence continuity (see [sequenceGapInfo]) and the distance
/// threshold must pass. Missing-Cα residues increase the permitted distance
/// for the bridged interval.
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

/// Returns whether there is a sequence gap from [from] to [to], and how many
/// residues without Cα lie between them.
///
/// Uses `label_seq_id` when both neighbors have it, because author numbering
/// can skip numbers without a break; otherwise author numbering. A step of
/// zero (insertion code) or one is continuous.
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
    final Residue previous = chain.residues[i - 1];
    final Residue next = chain.residues[i];
    final int? previousLabel = previous.labelSeqId;
    final int? nextLabel = next.labelSeqId;
    final int diff = previousLabel != null && nextLabel != null
        ? nextLabel - previousLabel
        : next.id.authSeqId - previous.id.authSeqId;
    if (diff != 0 && diff != 1) return (true, 0);
  }
  return (false, toIndex - fromIndex - 1);
}
