import 'package:vector_math/vector_math.dart';

/// One atom record from `atom_site`, already resolved to a single
/// conformer. Can never be one of several `label_alt_id` alternates for the same
/// (chain, seq, insertion code, atom name). See the `atom_site` reader for
/// the occupancy-based resolution rule.
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

  /// Whether the source row was written as `HETATM` rather than `ATOM`.
  /// **Metadata only** — not the signal for "is this part of the protein
  /// chain". Some polymer residues (e.g. a chromophore formed from
  /// cyclized standard residues) are legitimately written as `HETATM`
  /// while still being part of the backbone; polymer membership is decided
  /// per-residue from entity classification instead. See the `atom_site`
  /// reader.
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
