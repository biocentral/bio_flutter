import 'package:vector_math/vector_math.dart';

import '../model/chain.dart';
import '../model/molecular_structure.dart';
import '../model/residue.dart';
import '../model/secondary_structure.dart';

/// Assigns secondary structure from backbone hydrogen bonds.
///
/// Follows DSSP (Kabsch & Sander (1983), *Biopolymers* 22, 2577–2637,
/// https://doi.org/10.1002/bip.360221211), the method ChimeraX and Mol* use
/// for files without header annotations. Alpha, 3₁₀, and pi helices map to
/// [SecondaryStructureType.helix], and ladders of two or more bridges map to
/// [SecondaryStructureType.sheet]. Isolated bridges, turns, and bends stay
/// loops, and so do helices and strands shorter than three residues, as in
/// ChimeraX.
///
/// Residues without all of N, Cα, C, and O take no part and stay loops.
/// Bridges may pair residues of different chains.
List<Chain> assignDsspSecondaryStructure(MolecularStructure structure) {
  final List<_Backbone> backbone = [];
  final List<List<int?>> backboneIndexByChain = [];
  for (final chain in structure.chains) {
    final List<int?> backboneIndices = [];
    _Backbone? previous;
    for (final residue in chain.residues) {
      final _Backbone? current = _Backbone.of(residue, previous);
      backboneIndices.add(current == null ? null : backbone.length);
      if (current != null) backbone.add(current);
      previous = current;
    }
    backboneIndexByChain.add(backboneIndices);
  }

  final List<SecondaryStructureType> types = _assign(backbone);

  return [
    for (final (int c, Chain chain) in structure.chains.indexed)
      Chain(
        id: chain.id,
        authChainId: chain.authChainId,
        residues: [
          for (final (int r, Residue residue) in chain.residues.indexed)
            residue.withSecondaryStructure(switch (backboneIndexByChain[c][r]) {
              null => SecondaryStructureType.loop,
              final int i => types[i],
            }),
        ],
      ),
  ];
}

/// Whether [residue] has the N, Cα, C, and O atoms DSSP needs.
bool hasCompleteBackbone(Residue residue) =>
    _Backbone.of(residue, null) != null;

/// The longest C–N distance, in Å, still treated as a peptide bond.
const double _maxPeptideBondLength = 2.5;

/// The Cα distance, in Å, beyond which no hydrogen bond is searched.
const double _maxCaDistance = 9.0;

/// The energy, in kcal/mol, that a hydrogen bond must fall below.
const double _maxHBondEnergy = -0.5;

/// The energy, in kcal/mol, given to a bond whose atoms overlap.
const double _overlapHBondEnergy = -9.9;

/// The distance, in Å, below which two atoms are treated as overlapping.
const double _minAtomDistance = 0.5;

/// The shortest helix or strand, in residues, that is not shown as a loop.
const int _minElementLength = 3;

/// The backbone atoms of one residue, as DSSP uses them.
class _Backbone {
  _Backbone(
    this.n,
    this.ca,
    this.c,
    this.o,
    this.h, {
    required this.isBondedToPrevious,
  });

  /// Returns null when [residue] lacks N, Cα, C, or O.
  ///
  /// [previous] is the preceding residue of the same chain, if any. The
  /// amide hydrogen is the file's `H` atom when present, as in NMR models.
  /// Otherwise, after a peptide bond, it is placed opposite the previous
  /// carbonyl, as in DSSP; prolines have none.
  static _Backbone? of(Residue residue, _Backbone? previous) {
    Vector3? n, ca, c, o, hydrogen;
    for (final atom in residue.atoms) {
      switch (atom.atomName) {
        case 'H':
          hydrogen = atom.position;
        case 'N':
          n = atom.position;
        case 'CA':
          ca = atom.position;
        case 'C':
          c = atom.position;
        case 'O':
          o = atom.position;
      }
    }
    if (n == null || ca == null || c == null || o == null) return null;

    final bool isBonded =
        previous != null && previous.c.distanceTo(n) <= _maxPeptideBondLength;
    final Vector3? h =
        hydrogen ??
        (isBonded && residue.name != 'PRO'
            ? n + (previous.c - previous.o).normalized()
            : null);
    return _Backbone(n, ca, c, o, h, isBondedToPrevious: isBonded);
  }

  final Vector3 n;
  final Vector3 ca;
  final Vector3 c;
  final Vector3 o;

  /// The amide hydrogen, or null when the residue cannot donate a bond.
  final Vector3? h;

  /// Whether a peptide bond joins this residue to the preceding one.
  final bool isBondedToPrevious;
}

/// The electrostatic energy, in kcal/mol, of a hydrogen bond from [donor]'s
/// N–H to [acceptor]'s C=O, or 0 when [donor] has no amide hydrogen.
double _hBondEnergy(_Backbone donor, _Backbone acceptor) {
  final Vector3? h = donor.h;
  if (h == null) return 0;
  final double rON = donor.n.distanceTo(acceptor.o);
  final double rCH = h.distanceTo(acceptor.c);
  final double rOH = h.distanceTo(acceptor.o);
  final double rCN = donor.n.distanceTo(acceptor.c);
  if (rON < _minAtomDistance ||
      rCH < _minAtomDistance ||
      rOH < _minAtomDistance ||
      rCN < _minAtomDistance) {
    return _overlapHBondEnergy;
  }
  // 0.084 * 332: partial charges 0.42e and 0.20e times the unit factor.
  return 27.888 * (1 / rON + 1 / rCH - 1 / rOH - 1 / rCN);
}

/// The secondary structure of each residue in [backbone], which lists the
/// residues of all chains in order.
List<SecondaryStructureType> _assign(List<_Backbone> backbone) {
  final int length = backbone.length;

  // Peptide-bonded stretches; no turn or bridge may span two of them.
  final List<int> segments = List.filled(length, 0);
  for (int i = 1; i < length; i++) {
    segments[i] = backbone[i].isBondedToPrevious
        ? segments[i - 1]
        : segments[i - 1] + 1;
  }

  // acceptorsOf[d] holds every a whose C=O bonds to d's N–H.
  final List<Set<int>> acceptorsOf = List.generate(length, (_) => {});
  for (final (int i, int j) in _closePairs(backbone)) {
    for (final (int donor, int acceptor) in [(i, j), (j, i)]) {
      // The N–H right after a C=O belongs to the same peptide group.
      if (acceptor == donor - 1) continue;
      if (_hBondEnergy(backbone[donor], backbone[acceptor]) < _maxHBondEnergy) {
        acceptorsOf[donor].add(acceptor);
      }
    }
  }

  bool inRange(int i) => i >= 0 && i < length;
  bool hasBond(int acceptor, int donor) =>
      inRange(acceptor) &&
      inRange(donor) &&
      acceptorsOf[donor].contains(acceptor);
  bool inSameSegment(int a, int b) =>
      inRange(a) && inRange(b) && segments[a] == segments[b];

  // An n-turn at i is a bond from the C=O of i to the N–H of i + n. Two
  // consecutive n-turns at i - 1 and i make residues i to i + n - 1 a helix.
  List<bool> helixMask(int n) {
    final List<bool> mask = List.filled(length, false);
    for (int i = 1; i + n < length; i++) {
      if (inSameSegment(i - 1, i + n) &&
          hasBond(i - 1, i - 1 + n) &&
          hasBond(i, i + n)) {
        mask.fillRange(i, i + n, true);
      }
    }
    return mask;
  }

  final List<bool> alpha = helixMask(4);
  final List<bool> threeTen = helixMask(3);
  final List<bool> pi = helixMask(5);
  final List<bool> strand = _strandMask(
    length,
    acceptorsOf,
    hasBond,
    inSameSegment,
  );

  // DSSP's priority: alpha helix, then strand, then 3₁₀ and pi helices.
  final List<SecondaryStructureType> types = [
    for (int i = 0; i < length; i++)
      alpha[i]
          ? SecondaryStructureType.helix
          : strand[i]
          ? SecondaryStructureType.sheet
          : (threeTen[i] || pi[i])
          ? SecondaryStructureType.helix
          : SecondaryStructureType.loop,
  ];

  // Like ChimeraX, shows helices and strands shorter than three residues,
  // such as a two-bridge ladder, as loops. No element touches a chain break,
  // so runs never merge across one.
  int start = 0;
  for (int i = 1; i <= length; i++) {
    if (i < length && types[i] == types[start]) continue;
    if (i - start < _minElementLength) {
      types.fillRange(start, i, SecondaryStructureType.loop);
    }
    start = i;
  }
  return types;
}

/// A mask of the residues in ladders of at least two bridges, including the
/// extra residues of bulges that link two ladders.
List<bool> _strandMask(
  int length,
  List<Set<int>> acceptorsOf,
  bool Function(int acceptor, int donor) hasBond,
  bool Function(int a, int b) inSameSegment,
) {
  // Every bridge pattern contains a bond between the neighborhoods of its
  // two residues, so only pairs near a bond can form one.
  final Set<(int, int)> candidates = {};
  for (final (int donor, Set<int> acceptors) in acceptorsOf.indexed) {
    for (final int acceptor in acceptors) {
      for (int di = -1; di <= 1; di++) {
        for (int dj = -1; dj <= 1; dj++) {
          final int x = acceptor + di;
          final int y = donor + dj;
          final (int i, int j) = x < y ? (x, y) : (y, x);
          if (j - i >= 3) candidates.add((i, j));
        }
      }
    }
  }

  final List<_Ladder> ladders = [];
  for (final (int i, int j) in candidates.toList()..sort(_comparePairs)) {
    if (!inSameSegment(i - 1, i + 1) || !inSameSegment(j - 1, j + 1)) {
      continue;
    }
    final bool parallel =
        (hasBond(i - 1, j) && hasBond(j, i + 1)) ||
        (hasBond(j - 1, i) && hasBond(i, j + 1));
    final bool antiparallel =
        (hasBond(i, j) && hasBond(j, i)) ||
        (hasBond(i - 1, j + 1) && hasBond(j - 1, i + 1));
    if (!parallel && !antiparallel) continue;

    bool isExtended = false;
    for (final ladder in ladders) {
      if (ladder.isParallel != parallel || i != ladder.i.last + 1) continue;
      if (parallel && j == ladder.j.last + 1) {
        ladder.i.add(i);
        ladder.j.add(j);
        isExtended = true;
        break;
      }
      if (!parallel && j == ladder.j.first - 1) {
        ladder.i.add(i);
        ladder.j.insert(0, j);
        isExtended = true;
        break;
      }
    }
    if (!isExtended) {
      ladders.add(_Ladder(i: [i], j: [j], isParallel: parallel));
    }
  }

  // Links ladders of the same type across a bulge: at most one extra
  // residue on one strand and at most four on the other.
  for (int x = 0; x < ladders.length; x++) {
    for (int y = x + 1; y < ladders.length; y++) {
      final _Ladder a = ladders[x];
      final _Ladder b = ladders[y];
      final int gapI = b.i.first - a.i.last;
      if (a.isParallel != b.isParallel ||
          !inSameSegment(a.i.first, b.i.last) ||
          !inSameSegment(
            a.j.first < b.j.first ? a.j.first : b.j.first,
            a.j.last > b.j.last ? a.j.last : b.j.last,
          ) ||
          gapI < 1 ||
          gapI >= 6) {
        continue;
      }
      final int gapJ = a.isParallel
          ? b.j.first - a.j.last
          : a.j.first - b.j.last;
      final bool isBulge = gapJ >= 0 && (gapJ < 3 || (gapJ < 6 && gapI < 3));
      if (!isBulge) continue;
      a.i.addAll(b.i);
      if (a.isParallel) {
        a.j.addAll(b.j);
      } else {
        a.j.insertAll(0, b.j);
      }
      ladders.removeAt(y);
      y--;
    }
  }

  final List<bool> mask = List.filled(length, false);
  for (final ladder in ladders) {
    if (ladder.i.length < 2) continue;
    mask.fillRange(ladder.i.first, ladder.i.last + 1, true);
    mask.fillRange(ladder.j.first, ladder.j.last + 1, true);
  }
  return mask;
}

int _comparePairs((int, int) p, (int, int) q) =>
    p.$1 != q.$1 ? p.$1 - q.$1 : p.$2 - q.$2;

/// Consecutive bridges of one type between two strands.
class _Ladder {
  _Ladder({required this.i, required this.j, required this.isParallel});

  /// The residues of the first strand, ascending.
  final List<int> i;

  /// The partners of [i], ascending. In antiparallel ladders the order is
  /// reversed, so `j.first` pairs with `i.last`.
  final List<int> j;

  final bool isParallel;
}

/// All index pairs `i < j` whose Cα atoms are closer than [_maxCaDistance],
/// found with a uniform grid.
Iterable<(int, int)> _closePairs(List<_Backbone> backbone) sync* {
  (int, int, int) cellOf(Vector3 p) => (
    (p.x / _maxCaDistance).floor(),
    (p.y / _maxCaDistance).floor(),
    (p.z / _maxCaDistance).floor(),
  );
  final Map<(int, int, int), List<int>> grid = {};
  for (final (int i, _Backbone residue) in backbone.indexed) {
    grid.putIfAbsent(cellOf(residue.ca), () => []).add(i);
  }
  for (final (int i, _Backbone residue) in backbone.indexed) {
    final (int cx, int cy, int cz) = cellOf(residue.ca);
    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        for (int dz = -1; dz <= 1; dz++) {
          for (final int j in grid[(cx + dx, cy + dy, cz + dz)] ?? const []) {
            if (j > i &&
                residue.ca.distanceTo(backbone[j].ca) < _maxCaDistance) {
              yield (i, j);
            }
          }
        }
      }
    }
  }
}
