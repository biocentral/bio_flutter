import 'package:vector_math/vector_math.dart';

import '../model/atom.dart';
import '../model/residue.dart';

/// The peptide carbonyl oxygen's atom name — including the terminal
/// carboxylate variants a chain's C-terminal residue may use instead of
/// plain `O`.
const List<String> _oxygenAtomNames = [
  'O',
  'OXT',
  'OC1',
  'O1',
  'OX1',
  'OT1',
  'OT2',
];

/// Returns one unit C→O orientation vector for each residue.
///
/// Missing atoms reuse the previous valid vector. Consecutive vectors are
/// sign-aligned to prevent 180-degree frame flips.
List<Vector3> backboneOrientationVectors(List<Residue> residues) {
  final List<Vector3?> raw = [for (final r in residues) _rawDirection(r)];

  // Backfill any leading residues missing C/O from the first residue that
  // does have both.
  final int firstKnown = raw.indexWhere((v) => v != null);
  if (firstKnown == -1) {
    // No residue in this run has both atoms -- there is no biological
    // signal to orient by. An arbitrary-but-fixed vector still gives a
    // consistent (if not meaningful) twist, which is better than
    // crashing or defaulting to per-station randomness.
    return [for (final _ in residues) Vector3(0, 1, 0)];
  }
  for (int i = 0; i < firstKnown; i++) {
    raw[i] = raw[firstKnown];
  }
  // Forward-fill everything else.
  for (int i = 1; i < raw.length; i++) {
    raw[i] ??= raw[i - 1];
  }

  final List<Vector3> corrected = [];
  Vector3? previous;
  for (final Vector3? v in raw) {
    Vector3 current = v!;
    if (previous != null && previous.dot(current) < 0) {
      current = -current;
    }
    corrected.add(current);
    previous = current;
  }
  return corrected;
}

Vector3? _rawDirection(Residue residue) {
  Atom? findByName(Iterable<String> names) {
    for (final name in names) {
      for (final atom in residue.atoms) {
        if (atom.atomName == name) return atom;
      }
    }
    return null;
  }

  final Atom? carbon = findByName(const ['C']);
  final Atom? oxygen = findByName(_oxygenAtomNames);
  if (carbon == null || oxygen == null) return null;

  final Vector3 direction = oxygen.position - carbon.position;
  if (direction.length2 < 1e-12) return null; // coincident atoms, unusable
  return direction.normalized();
}
