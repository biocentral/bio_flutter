/// A per-residue secondary-structure label.
///
/// From header annotation, [helix] covers any depositor helix type (alpha,
/// 3₁₀, or pi). From the geometric fallback, it means alpha helix only.
enum SecondaryStructureType { loop, helix, sheet }

/// One header secondary-structure range of one chain, inclusive.
///
/// Boundaries may be in label numbering, author numbering, or both. Label
/// numbering is preferred because author numbering can skip numbers and
/// drift from it. Author boundaries include insertion codes, so `82A` lies
/// after a range ending at `82`.
class SecondaryStructureRange {
  const SecondaryStructureRange({
    required this.chainId,
    required this.type,
    this.beginLabelSeqId,
    this.endLabelSeqId,
    this.begin,
    this.end,
  });

  /// `label_asym_id` of the chain this range belongs to.
  final String chainId;
  final SecondaryStructureType type;

  /// Label-numbered boundaries; both or neither are set.
  final int? beginLabelSeqId;
  final int? endLabelSeqId;

  /// Author-numbered boundaries; both or neither are set.
  final ResidueId? begin;
  final ResidueId? end;

  /// Whether the residue identified by [id] and [labelSeqId] lies in range.
  ///
  /// Uses label numbering when both the range and the residue have it,
  /// otherwise author numbering when the range has it.
  bool covers(String chainId, ResidueId id, {int? labelSeqId}) {
    if (chainId != this.chainId) return false;
    final int? beginLabel = beginLabelSeqId;
    final int? endLabel = endLabelSeqId;
    if (labelSeqId != null && beginLabel != null && endLabel != null) {
      return labelSeqId >= beginLabel && labelSeqId <= endLabel;
    }
    final ResidueId? beginAuth = begin;
    final ResidueId? endAuth = end;
    if (beginAuth == null || endAuth == null) return false;
    return id.compareTo(beginAuth) >= 0 && id.compareTo(endAuth) <= 0;
  }
}

/// A residue's author identity: `auth_seq_id` and insertion code.
class ResidueId implements Comparable<ResidueId> {
  const ResidueId(this.authSeqId, this.insertionCode);

  final int authSeqId;

  /// Empty string when the residue has no insertion code.
  final String insertionCode;

  @override
  int compareTo(ResidueId other) {
    final int seqCmp = authSeqId.compareTo(other.authSeqId);
    if (seqCmp != 0) return seqCmp;
    // '' sorts before any letter, matching PDB convention: residue `82`
    // precedes `82A`.
    return insertionCode.compareTo(other.insertionCode);
  }

  @override
  bool operator ==(Object other) =>
      other is ResidueId &&
      other.authSeqId == authSeqId &&
      other.insertionCode == insertionCode;

  @override
  int get hashCode => Object.hash(authSeqId, insertionCode);

  @override
  String toString() => '$authSeqId$insertionCode';
}
