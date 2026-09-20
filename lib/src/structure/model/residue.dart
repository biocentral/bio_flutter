import 'atom.dart';
import 'secondary_structure.dart';

export 'secondary_structure.dart' show ResidueId;

/// One polymer residue: its identity, its resolved atoms (never more than
/// one conformer per atom name), and its secondary-structure label.
class Residue {
  Residue({
    required this.id,
    required this.name,
    required Iterable<Atom> atoms,
    required this.secondaryStructure,
  }) : atoms = List.unmodifiable(atoms);

  final ResidueId id;

  /// The component id (e.g. `ALA`, `MSE`), verbatim from the file. Not
  /// validated against any fixed amino-acid table, non-standard/modified
  /// residues are accepted as-is; nothing in this package treats an
  /// unrecognized name as fatal.
  final String name;

  final List<Atom> atoms;
  final SecondaryStructureType secondaryStructure;

  Atom? get alphaCarbon {
    for (final atom in atoms) {
      if (atom.isAlphaCarbon) return atom;
    }
    return null;
  }

  /// Returns a copy with the supplied secondary-structure label.
  Residue withSecondaryStructure(SecondaryStructureType type) =>
      Residue(id: id, name: name, atoms: atoms, secondaryStructure: type);

  @override
  String toString() =>
      'Residue($name $id, ${atoms.length} atoms, $secondaryStructure)';
}
