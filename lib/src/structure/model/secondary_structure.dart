/// A per-residue secondary-structure label. When it comes from real header
/// annotation (`_struct_conf`/`_struct_sheet_range`), [helix] means
/// whatever the depositor called a helix — alpha, 3₁₀, or pi alike. When it
/// comes from the geometric fallback instead (`ss/p_sea.dart`, used when a
/// file has no header annotation at all), [helix] means specifically
/// *alpha* helix — the P-SEA algorithm's distance/angle thresholds are
/// calibrated to alpha-helix geometry and will not detect a 3₁₀ or pi
/// helix, even a real one (confirmed against PDB 2QLE, whose header-labeled
/// 3₁₀ helices the geometric assignment correctly does not reproduce; see
/// `test/src/ss/p_sea_test.dart`).
enum SecondaryStructureType { loop, helix, sheet }

/// One `_struct_conf`/`_struct_sheet_range` range: `[begin, end]` of one
/// chain's author-numbered residues, inclusive, boundaries expressed as
/// full [ResidueId]s (sequence number *and* insertion code).
///
/// Using [ResidueId] rather than a bare integer range matters: a residue
/// sharing a numeric `auth_seq_id` with a range boundary but a different
/// insertion code (e.g. a range ending at `82` while the next residue is
/// `82A`) must not be misclassified — see [covers].
class SecondaryStructureRange {
  const SecondaryStructureRange({
    required this.chainId,
    required this.begin,
    required this.end,
    required this.type,
  });

  /// `label_asym_id` of the chain this range belongs to.
  final String chainId;

  final ResidueId begin;
  final ResidueId end;
  final SecondaryStructureType type;

  bool covers(String chainId, ResidueId id) =>
      chainId == this.chainId &&
      id.compareTo(begin) >= 0 &&
      id.compareTo(end) <= 0;
}

/// A residue's identity within its chain: mmCIF's author-assigned
/// `(auth_seq_id, insertion_code)` pair.
///
/// This lives here (rather than in `residue.dart`) because
/// [SecondaryStructureRange] needs it and `residue.dart` needs it too —
/// see `residue.dart` for its use as a residue's actual identity.
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
