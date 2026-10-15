import 'residue.dart';

/// A residue identified by its unique mmCIF chain and author numbering.
///
/// Keys are scoped to one structure. [chainId] is `label_asym_id`, not the
/// potentially shared author chain name. Map sequence positions through the
/// parsed chains; sequence indices are not residue IDs.
class ResidueKey {
  const ResidueKey(this.chainId, this.residueId);

  final String chainId;
  final ResidueId residueId;

  @override
  bool operator ==(Object other) =>
      other is ResidueKey &&
      other.chainId == chainId &&
      other.residueId == residueId;

  @override
  int get hashCode => Object.hash(chainId, residueId);

  @override
  String toString() => '$chainId:$residueId';
}
