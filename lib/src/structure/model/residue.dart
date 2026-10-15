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
    this.labelSeqId,
  }) : atoms = List.unmodifiable(atoms);

  /// Author numbering (`auth_seq_id` and insertion code): the identity used
  /// by `ResidueKey`-based selection and shown to users.
  final ResidueId id;

  /// mmCIF `label_seq_id`: the 1-based position in the entity sequence
  /// (`_entity_poly_seq`). Consecutive along the polymer, unlike author
  /// numbering, which may skip numbers or use insertion codes. Null when the
  /// file does not provide it.
  final int? labelSeqId;

  /// The component ID, such as `ALA` or `MSE`, verbatim from the file.
  /// Nonstandard names are accepted.
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
  Residue withSecondaryStructure(SecondaryStructureType type) => Residue(
    id: id,
    name: name,
    atoms: atoms,
    secondaryStructure: type,
    labelSeqId: labelSeqId,
  );

  @override
  String toString() =>
      'Residue($name $id, ${atoms.length} atoms, $secondaryStructure)';
}
