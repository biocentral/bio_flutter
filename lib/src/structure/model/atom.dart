import 'package:vector_math/vector_math.dart';

/// One `atom_site` atom, resolved to a single conformer.
class Atom {
  Atom({
    required this.serial,
    required this.element,
    required this.atomName,
    required Vector3 position,
    required this.occupancy,
    required this.bFactor,
    required this.isHeteroRecord,
  }) : _position = position.clone();

  final int serial;
  final String element;
  final String atomName;
  final Vector3 _position;

  /// A copy of the atom's coordinates in ångströms.
  Vector3 get position => _position.clone();
  final double occupancy;
  final double bFactor;

  /// Whether the source row was `HETATM`. Metadata only: polymer residues
  /// such as a chromophore may be `HETATM`, so chain membership comes from
  /// entity classification instead.
  final bool isHeteroRecord;

  bool get isAlphaCarbon => atomName == 'CA';

  @override
  bool operator ==(Object other) =>
      other is Atom &&
      other.serial == serial &&
      other.element == element &&
      other.atomName == atomName &&
      other._position == _position &&
      other.occupancy == occupancy &&
      other.bFactor == bFactor &&
      other.isHeteroRecord == isHeteroRecord;

  @override
  int get hashCode => Object.hash(
    serial,
    element,
    atomName,
    _position,
    occupancy,
    bFactor,
    isHeteroRecord,
  );

  @override
  String toString() => 'Atom(#$serial $atomName $element @ $position)';
}
