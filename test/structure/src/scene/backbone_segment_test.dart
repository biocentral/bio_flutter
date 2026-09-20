import 'package:flutter_test/flutter_test.dart';
import 'package:bio_flutter/src/structure/model/atom.dart';
import 'package:bio_flutter/src/structure/model/chain.dart';
import 'package:bio_flutter/src/structure/model/molecular_structure.dart';
import 'package:bio_flutter/src/structure/model/residue.dart';
import 'package:bio_flutter/src/structure/model/secondary_structure.dart';
import 'package:bio_flutter/src/structure/scene/backbone_segment.dart';
import 'package:vector_math/vector_math.dart';

Atom _ca(double x) => Atom(
  serial: 1,
  element: 'C',
  atomName: 'CA',
  position: Vector3(x, 0, 0),
  occupancy: 1,
  bFactor: 20,
  isHeteroRecord: false,
);

Residue _residue(
  int seq,
  String icode,
  double x,
  SecondaryStructureType type, {
  bool withCa = true,
}) => Residue(
  id: ResidueId(seq, icode),
  name: 'ALA',
  atoms: withCa ? [_ca(x)] : const [],
  secondaryStructure: type,
);

Chain _chainOf(List<Residue> residues, {String chainId = 'A'}) =>
    Chain(id: chainId, authChainId: chainId, residues: residues);

MolecularStructure _structureOf(
  List<Residue> residues, {
  String chainId = 'A',
}) => MolecularStructure(chains: [_chainOf(residues, chainId: chainId)]);

void main() {
  group('isChainContiguous', () {
    test('a normal 3.8 A step is contiguous', () {
      final residues = [
        _residue(1, '', 0.0, SecondaryStructureType.loop),
        _residue(2, '', 3.8, SecondaryStructureType.loop),
      ];
      final chain = _chainOf(residues);
      expect(isChainContiguous(chain, residues[0], residues[1]), isTrue);
    });

    test('a numerically adjacent pair that is far apart in space is not contiguous (a real gap)', () {
      // auth_seq_id 49 -> 50 looks adjacent, but the file has no residues
      // in between and the modeled backbone doesn't actually connect them.
      final residues = [
        _residue(49, '', 0.0, SecondaryStructureType.loop),
        _residue(50, '', 20.0, SecondaryStructureType.loop),
      ];
      final chain = _chainOf(residues);
      expect(isChainContiguous(chain, residues[0], residues[1]), isFalse);
    });

    test(
      'an insertion-code residue at close range is contiguous (49 -> 49A)',
      () {
        final residues = [
          _residue(49, '', 0.0, SecondaryStructureType.loop),
          _residue(49, 'A', 3.8, SecondaryStructureType.loop),
        ];
        final chain = _chainOf(residues);
        expect(isChainContiguous(chain, residues[0], residues[1]), isTrue);
      },
    );

    test('stepping from an insertion back to the next integer is contiguous (49A -> 50)', () {
      final residues = [
        _residue(49, 'A', 0.0, SecondaryStructureType.loop),
        _residue(50, '', 3.8, SecondaryStructureType.loop),
      ];
      final chain = _chainOf(residues);
      expect(isChainContiguous(chain, residues[0], residues[1]), isTrue);
    });

    test('spatially close but not sequentially adjacent is not contiguous', () {
      // A chain looping back near itself: close in space, far in sequence.
      final residues = [
        _residue(10, '', 0.0, SecondaryStructureType.loop),
        _residue(80, '', 1.0, SecondaryStructureType.loop),
      ];
      final chain = _chainOf(residues);
      expect(isChainContiguous(chain, residues[0], residues[1]), isFalse);
    });

    test('a genuine gap hiding underneath a run of CA-less residues is still detected', () {
      // 1 has CA; 2 exists (has some other atom) but no CA, and then the
      // file jumps straight to 40 with no entry in between -- a true gap
      // that happens to fall inside the CA-less run.
      final residues = [
        _residue(1, '', 0.0, SecondaryStructureType.loop),
        _residue(2, '', 3.8, SecondaryStructureType.loop, withCa: false),
        _residue(40, '', 7.6, SecondaryStructureType.loop, withCa: false),
        _residue(41, '', 11.4, SecondaryStructureType.loop),
      ];
      final chain = _chainOf(residues);
      expect(isChainContiguous(chain, residues[0], residues[3]), isFalse);
    });

    test('bridging one CA-less-but-present residue allows roughly two peptide steps of distance', () {
      final residues = [
        _residue(1, '', 0.0, SecondaryStructureType.loop),
        _residue(2, '', 3.8, SecondaryStructureType.loop, withCa: false),
        _residue(3, '', 7.6, SecondaryStructureType.loop),
      ];
      final chain = _chainOf(residues);
      expect(isChainContiguous(chain, residues[0], residues[2]), isTrue);
    });

    test('bridging two CA-less-but-present residues in a row scales the allowance further', () {
      final residues = [
        _residue(1, '', 0.0, SecondaryStructureType.loop),
        _residue(2, '', 3.8, SecondaryStructureType.loop, withCa: false),
        _residue(3, '', 7.6, SecondaryStructureType.loop, withCa: false),
        _residue(4, '', 11.4, SecondaryStructureType.loop),
      ];
      final chain = _chainOf(residues);
      expect(isChainContiguous(chain, residues[0], residues[3]), isTrue);
      // But it's not unlimited: comfortably past 3 steps' worth is still a break.
      final farResidues = [
        _residue(1, '', 0.0, SecondaryStructureType.loop),
        _residue(2, '', 3.8, SecondaryStructureType.loop, withCa: false),
        _residue(3, '', 7.6, SecondaryStructureType.loop, withCa: false),
        _residue(4, '', 100.0, SecondaryStructureType.loop),
      ];
      final farChain = _chainOf(farResidues);
      expect(
        isChainContiguous(farChain, farResidues[0], farResidues[3]),
        isFalse,
      );
    });
  });

  group('buildBackboneSegments', () {
    test('a contiguous same-type run becomes one segment', () {
      final structure = _structureOf([
        _residue(1, '', 0.0, SecondaryStructureType.helix),
        _residue(2, '', 3.8, SecondaryStructureType.helix),
        _residue(3, '', 7.6, SecondaryStructureType.helix),
      ]);
      final segments = buildBackboneSegments(structure);
      expect(segments, hasLength(1));
      expect(segments.single.residues, hasLength(3));
    });

    test('a secondary-structure change splits into two segments', () {
      final structure = _structureOf([
        _residue(1, '', 0.0, SecondaryStructureType.helix),
        _residue(2, '', 3.8, SecondaryStructureType.sheet),
      ]);
      final segments = buildBackboneSegments(structure);
      expect(segments, hasLength(2));
      expect(segments[0].type, SecondaryStructureType.helix);
      expect(segments[1].type, SecondaryStructureType.sheet);
    });

    test(
      'a real gap (missing density) splits into two segments of the same type',
      () {
        final structure = _structureOf([
          _residue(1, '', 0.0, SecondaryStructureType.loop),
          _residue(2, '', 3.8, SecondaryStructureType.loop),
          // Residues 3-9 missing from the file entirely (unresolved loop).
          _residue(10, '', 40.0, SecondaryStructureType.loop),
        ]);
        final segments = buildBackboneSegments(structure);
        expect(segments, hasLength(2));
        expect(segments[0].residues.map((r) => r.id.authSeqId), [1, 2]);
        expect(segments[1].residues.map((r) => r.id.authSeqId), [10]);
      },
    );

    test(
      'residues without a resolved CA are dropped, not treated as a break',
      () {
        final structure = _structureOf([
          _residue(1, '', 0.0, SecondaryStructureType.loop),
          _residue(
            2,
            '',
            3.8,
            SecondaryStructureType.loop,
            withCa: false,
          ), // no CA
          _residue(3, '', 7.6, SecondaryStructureType.loop),
        ]);
        final segments = buildBackboneSegments(structure);
        expect(segments, hasLength(1));
        expect(segments.single.residues.map((r) => r.id.authSeqId), [1, 3]);
      },
    );

    test('segments never span chains', () {
      final structure = MolecularStructure(
        chains: [
          Chain(
            id: 'A',
            authChainId: 'A',
            residues: [_residue(1, '', 0.0, SecondaryStructureType.loop)],
          ),
          Chain(
            id: 'B',
            authChainId: 'B',
            residues: [_residue(1, '', 0.0, SecondaryStructureType.loop)],
          ),
        ],
      );
      final segments = buildBackboneSegments(structure);
      expect(segments, hasLength(2));
      expect(segments.map((s) => s.chainId).toSet(), {'A', 'B'});
    });

    test('a chain with no residues bearing a CA at all yields no segments', () {
      final structure = _structureOf([
        _residue(1, '', 0.0, SecondaryStructureType.loop, withCa: false),
      ]);
      expect(buildBackboneSegments(structure), isEmpty);
    });

    test('an empty structure yields no segments', () {
      expect(buildBackboneSegments(MolecularStructure(chains: [])), isEmpty);
    });
  });

  group('buildContinuousRuns', () {
    test('a secondary-structure change alone does not split a run', () {
      final structure = _structureOf([
        _residue(1, '', 0.0, SecondaryStructureType.loop),
        _residue(2, '', 3.8, SecondaryStructureType.helix),
        _residue(3, '', 7.6, SecondaryStructureType.helix),
        _residue(4, '', 11.4, SecondaryStructureType.sheet),
      ]);
      final runs = buildContinuousRuns(structure);
      expect(runs, hasLength(1));
      expect(runs.single.residues.map((r) => r.id.authSeqId), [1, 2, 3, 4]);
      // The underlying per-type segments are still there, just merged into one run.
      expect(runs.single.segments.map((s) => s.type), [
        SecondaryStructureType.loop,
        SecondaryStructureType.helix,
        SecondaryStructureType.sheet,
      ]);
    });

    test('a real gap still splits into two runs', () {
      final structure = _structureOf([
        _residue(1, '', 0.0, SecondaryStructureType.loop),
        _residue(2, '', 3.8, SecondaryStructureType.helix),
        // Residues 3-9 missing entirely (unresolved loop) -- a real break.
        _residue(10, '', 40.0, SecondaryStructureType.sheet),
      ]);
      final runs = buildContinuousRuns(structure);
      expect(runs, hasLength(2));
      expect(runs[0].residues.map((r) => r.id.authSeqId), [1, 2]);
      expect(runs[1].residues.map((r) => r.id.authSeqId), [10]);
    });

    test('runs never span chains, even without any gap or type change', () {
      final structure = MolecularStructure(
        chains: [
          Chain(
            id: 'A',
            authChainId: 'A',
            residues: [_residue(1, '', 0.0, SecondaryStructureType.loop)],
          ),
          Chain(
            id: 'B',
            authChainId: 'B',
            residues: [_residue(1, '', 0.0, SecondaryStructureType.loop)],
          ),
        ],
      );
      final runs = buildContinuousRuns(structure);
      expect(runs, hasLength(2));
      expect(runs.map((r) => r.chainId).toSet(), {'A', 'B'});
    });

    test('an empty structure yields no runs', () {
      expect(buildContinuousRuns(MolecularStructure(chains: [])), isEmpty);
    });

    test(
      'authChainId is resolved from the chain, distinct from the label chainId',
      () {
        // A polymer chain and its associated hetero groups commonly share one
        // auth_asym_id while having different label_asym_ids (see Chain's own
        // doc comment) -- exercise that mismatch directly rather than a
        // fixture where they happen to coincide.
        final structure = MolecularStructure(
          chains: [
            Chain(
              id: 'A',
              authChainId: 'X',
              residues: [_residue(1, '', 0.0, SecondaryStructureType.loop)],
            ),
          ],
        );
        final runs = buildContinuousRuns(structure);
        expect(runs.single.chainId, 'A');
        expect(runs.single.authChainId, 'X');
      },
    );
  });
}
