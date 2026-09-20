import 'atom.dart';
import 'chain.dart';

/// A single, fully parsed protein structure: its polymer chains, already
/// resolved to one model and one conformer per atom.
///
/// Hetero groups (waters, ligands, ions) are intentionally not modeled
/// here, this package's scope is proteins only. They're still read off
/// the file (so their presence can't corrupt polymer chain/residue
/// grouping) but never become part of this structure; see the `atom_site`
/// reader for how polymer-vs-hetero membership is decided.
class MolecularStructure {
  MolecularStructure({required Iterable<Chain> chains})
    : chains = List.unmodifiable(chains);

  /// Empty when nothing in the file matched (e.g. no polymer entities at
  /// all). An empty structure is a valid, non-error result; callers
  /// should render nothing rather than treat this as failure.
  final List<Chain> chains;

  Iterable<Atom> get atoms =>
      chains.expand((c) => c.residues).expand((r) => r.atoms);
}
