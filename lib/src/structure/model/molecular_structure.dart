import 'atom.dart';
import 'chain.dart';

/// A parsed protein structure: its polymer chains, resolved to one model
/// and one conformer per atom. Waters, ligands, and ions are excluded.
class MolecularStructure {
  MolecularStructure({required Iterable<Chain> chains})
    : chains = List.unmodifiable(chains);

  /// Empty when the file has no protein chains, which is not an error.
  final List<Chain> chains;

  Iterable<Atom> get atoms =>
      chains.expand((c) => c.residues).expand((r) => r.atoms);
}
