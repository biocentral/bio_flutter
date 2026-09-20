// Adapted from Biotite's annotate_sse implementation. See THIRD_PARTY_NOTICES.md.
import 'package:vector_math/vector_math.dart';

import '../model/chain.dart';
import '../model/molecular_structure.dart';
import '../model/residue.dart';
import '../model/secondary_structure.dart';
import '../scene/backbone_segment.dart' show sequenceGapInfo;
import 'vector_geometry.dart';

/// Assigns secondary structure from Cα geometry using a P-SEA-style method.
///
/// The method uses distances and dihedral angles, without hydrogen-bond
/// analysis. It is intended for mmCIF files without header annotations.

// Geometric thresholds, converted to radians where needed.

// These angle ranges cannot be compile-time constants because they use _deg.
final (double, double) _rHelix = (_deg(89 - 12), _deg(89 + 12));
final (double, double) _aHelix = (_deg(50 - 20), _deg(50 + 20));
const (double, double) _d3Helix = (5.3 - 0.5, 5.3 + 0.5);
const (double, double) _d4Helix = (6.4 - 0.6, 6.4 + 0.6);

final (double, double) _rStrand = (_deg(124 - 14), _deg(124 + 14));
// Two disjoint ranges: a dihedral angle is periodic, and the strand
// criterion's target value sits right at the +/-180 degree wraparound.
final (double, double) _aStrandNeg = (-_pi, _deg(-125));
final (double, double) _aStrandPos = (_deg(145), _pi);
const (double, double) _d2Strand = (6.7 - 0.6, 6.7 + 0.6);
const (double, double) _d3Strand = (9.9 - 0.9, 9.9 + 0.9);
const (double, double) _d4Strand = (12.4 - 1.1, 12.4 + 1.1);

const double _pi = 3.14159265358979323846;
double _deg(num degrees) => degrees * _pi / 180;

bool _inRange(double? value, (double, double) range) =>
    value != null && value >= range.$1 && value <= range.$2;

/// Assigns a secondary-structure type to every residue in [structure].
///
/// Chains are processed independently and windows never cross numbering gaps.
/// Contact checks use Cα atoms from all chains. Residues without Cα remain loops.
List<Chain> assignGeometricSecondaryStructure(MolecularStructure structure) {
  final List<Vector3> allResolvedCaPositions = [
    for (final atom in structure.atoms)
      if (atom.isAlphaCarbon) atom.position,
  ];

  return [
    for (final chain in structure.chains)
      Chain(
        id: chain.id,
        authChainId: chain.authChainId,
        residues: _assignForChain(chain, allResolvedCaPositions),
      ),
  ];
}

List<Residue> _assignForChain(
  Chain chain,
  List<Vector3> allResolvedCaPositions,
) {
  final List<Residue> withCa = [
    for (final r in chain.residues)
      if (r.alphaCarbon != null) r,
  ];

  // No geometric window can fit in a chain this short.
  if (withCa.length <= 5) {
    return [
      for (final r in chain.residues)
        r.withSecondaryStructure(SecondaryStructureType.loop),
    ];
  }

  // Null slots prevent geometric windows from crossing a numbering gap.
  final List<Vector3?> pos = [];
  final List<int> sourceIndex = [];
  for (int i = 0; i < withCa.length; i++) {
    if (i > 0) {
      final (bool hasGap, _) = sequenceGapInfo(
        chain,
        withCa[i - 1].id,
        withCa[i].id,
      );
      if (hasGap) {
        pos.add(null);
        sourceIndex.add(-1);
      }
    }
    pos.add(withCa[i].alphaCarbon!.position);
    sourceIndex.add(i);
  }

  final int length = pos.length;
  final List<double?> d2 = List.filled(length, null);
  final List<double?> d3 = List.filled(length, null);
  final List<double?> d4 = List.filled(length, null);
  final List<double?> r = List.filled(length, null);
  final List<double?> a = List.filled(length, null);

  double? dist(Vector3? p, Vector3? q) =>
      (p == null || q == null) ? null : p.distanceTo(q);
  double? ang(Vector3? p, Vector3? q, Vector3? s) =>
      (p == null || q == null || s == null) ? null : angleAt(p, q, s);
  double? dih(Vector3? p, Vector3? q, Vector3? s, Vector3? t) =>
      (p == null || q == null || s == null || t == null)
      ? null
      : dihedralAngle(p, q, s, t);

  for (int i = 1; i <= length - 2; i++) {
    d2[i] = dist(pos[i - 1], pos[i + 1]);
    r[i] = ang(pos[i - 1], pos[i], pos[i + 1]);
  }
  for (int i = 1; i <= length - 3; i++) {
    d3[i] = dist(pos[i - 1], pos[i + 2]);
    a[i] = dih(pos[i - 1], pos[i], pos[i + 1], pos[i + 2]);
  }
  for (int i = 1; i <= length - 4; i++) {
    d4[i] = dist(pos[i - 1], pos[i + 3]);
  }

  final List<bool> relaxedHelix = List.generate(
    length,
    (i) => _inRange(d3[i], _d3Helix) || _inRange(r[i], _rHelix),
  );
  final List<bool> strictHelix = List.generate(
    length,
    (i) =>
        (_inRange(d3[i], _d3Helix) && _inRange(d4[i], _d4Helix)) ||
        (_inRange(r[i], _rHelix) && _inRange(a[i], _aHelix)),
  );

  final List<bool> relaxedStrand = List.generate(
    length,
    (i) => _inRange(d3[i], _d3Strand),
  );
  final List<bool> strictStrand = List.generate(
    length,
    (i) =>
        (_inRange(d2[i], _d2Strand) &&
            _inRange(d3[i], _d3Strand) &&
            _inRange(d4[i], _d4Strand)) ||
        (_inRange(r[i], _rStrand) &&
            (_inRange(a[i], _aStrandNeg) || _inRange(a[i], _aStrandPos))),
  );

  final List<bool> helixMask = _extendRegion(
    _maskConsecutive(strictHelix, 5),
    relaxedHelix,
  );

  final List<bool> strandRuns = _maskConsecutive(strictStrand, 4);
  final List<bool> shortStrandCandidates = _maskConsecutive(strictStrand, 3);
  final List<bool> shortStrandMask = _maskRegionsWithContacts(
    positions: pos,
    candidateMask: shortStrandCandidates,
    allContactPositions: allResolvedCaPositions,
    minContacts: 5,
    minDistance: 4.2,
    maxDistance: 5.2,
  );
  final List<bool> strandMask = _extendRegion(
    _or(strandRuns, shortStrandMask),
    relaxedStrand,
  );

  // Map computed type back onto each CA-bearing residue's identity, then
  // apply to every residue in the chain (CA-less residues simply never
  // appear in this map and default to loop).
  final Map<ResidueId, SecondaryStructureType> typeByResidueId = {};
  for (int i = 0; i < length; i++) {
    final int source = sourceIndex[i];
    if (source == -1) continue; // virtual gap slot
    typeByResidueId[withCa[source].id] = helixMask[i]
        ? SecondaryStructureType.helix
        : (strandMask[i]
              ? SecondaryStructureType.sheet
              : SecondaryStructureType.loop);
  }

  return [
    for (final residue in chain.residues)
      residue.withSecondaryStructure(
        typeByResidueId[residue.id] ?? SecondaryStructureType.loop,
      ),
  ];
}

List<bool> _or(List<bool> a, List<bool> b) => [
  for (int i = 0; i < a.length; i++) a[i] || b[i],
];

/// Marks every element in a run of at least [number] true values.
List<bool> _maskConsecutive(List<bool> mask, int number) {
  final int length = mask.length;
  final List<bool> output = List.filled(length, false);
  int i = 0;
  while (i < length) {
    if (!mask[i]) {
      i++;
      continue;
    }
    final int start = i;
    while (i < length && mask[i]) {
      i++;
    }
    if (i - start >= number) {
      for (int k = start; k < i; k++) {
        output[k] = true;
      }
    }
  }
  return output;
}

/// Extends each true region by one matching neighbor on either side.
List<bool> _extendRegion(List<bool> base, List<bool> extension) {
  final int length = base.length;
  final List<bool> output = List.of(base);
  int i = 0;
  while (i < length) {
    if (!base[i]) {
      i++;
      continue;
    }
    final int start = i;
    while (i < length && base[i]) {
      i++;
    }
    final int end = i; // exclusive
    if (start > 0 && extension[start - 1]) output[start - 1] = true;
    if (end < length && extension[end]) output[end] = true;
  }
  return output;
}

/// Marks candidate regions with at least [minContacts] nearby Cα contacts.
///
/// The distance search is quadratic in the number of candidate and contact points.
List<bool> _maskRegionsWithContacts({
  required List<Vector3?> positions,
  required List<bool> candidateMask,
  required List<Vector3> allContactPositions,
  required int minContacts,
  required double minDistance,
  required double maxDistance,
}) {
  final int length = positions.length;
  final List<int> contacts = List.filled(length, 0);
  for (int i = 0; i < length; i++) {
    if (!candidateMask[i]) continue;
    final Vector3? p = positions[i];
    if (p == null) continue;
    int count = 0;
    for (final Vector3 other in allContactPositions) {
      final double d = p.distanceTo(other);
      if (d > minDistance && d <= maxDistance) count++;
    }
    contacts[i] = count;
  }

  final List<bool> output = List.filled(length, false);
  int i = 0;
  while (i < length) {
    if (!candidateMask[i]) {
      i++;
      continue;
    }
    final int start = i;
    int total = 0;
    while (i < length && candidateMask[i]) {
      total += contacts[i];
      i++;
    }
    if (total >= minContacts) {
      for (int k = start; k < i; k++) {
        output[k] = true;
      }
    }
  }
  return output;
}
