import 'residue.dart';

/// An amino acid chain identified by mmCIF `label_asym_id`.
///
/// Author chain names are display metadata and need not be unique.
class Chain {
  Chain({
    required this.id,
    required this.authChainId,
    required Iterable<Residue> residues,
  }) : residues = List.unmodifiable(residues);

  /// `label_asym_id`: the grouping/identity key.
  final String id;

  /// `auth_asym_id`: for display only. May be shared with a *different*
  /// chain's [id] (a polymer and its associated hetero groups commonly
  /// share one `auth_asym_id`), which is exactly why [id] and not this is
  /// used for grouping.
  final String authChainId;

  final List<Residue> residues;
}
