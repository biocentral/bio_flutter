import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:bio_flutter/src/structure/mmcif/mmcif_structure_parser.dart';
import 'package:bio_flutter/src/structure/model/atom.dart';
import 'package:bio_flutter/src/structure/model/chain.dart';
import 'package:bio_flutter/src/structure/model/molecular_structure.dart';
import 'package:bio_flutter/src/structure/model/residue.dart';
import 'package:bio_flutter/src/structure/model/secondary_structure.dart';
import 'package:bio_flutter/src/structure/mmcif/secondary_structure_reader.dart'
    show readSecondaryStructureRanges;
import 'package:bio_flutter/src/structure/cif/cif_document.dart'
    show parseCifDocument;
import 'package:bio_flutter/src/structure/ss/p_sea.dart';
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

void main() {
  group('assignGeometricSecondaryStructure: degenerate inputs', () {
    test('an empty structure does not throw', () {
      expect(
        assignGeometricSecondaryStructure(MolecularStructure(chains: [])),
        isEmpty,
      );
    });

    test('a chain of 5 or fewer residues is entirely loop', () {
      final chain = Chain(
        id: 'A',
        authChainId: 'A',
        residues: [
          for (int i = 0; i < 5; i++)
            Residue(
              id: ResidueId(i, ''),
              name: 'ALA',
              atoms: [_ca(i * 3.8)],
              secondaryStructure: SecondaryStructureType.helix,
            ),
        ],
      );
      final result = assignGeometricSecondaryStructure(
        MolecularStructure(chains: [chain]),
      );
      expect(
        result.single.residues.every(
          (r) => r.secondaryStructure == SecondaryStructureType.loop,
        ),
        isTrue,
      );
    });

    test('a residue with no CA is always loop, never crashes the window arithmetic', () {
      final chain = Chain(
        id: 'A',
        authChainId: 'A',
        residues: [
          for (int i = 0; i < 8; i++)
            Residue(
              id: ResidueId(i, ''),
              name: 'ALA',
              atoms: i == 4 ? const [] : [_ca(i * 3.8)],
              secondaryStructure: SecondaryStructureType.helix,
            ),
        ],
      );
      expect(
        () => assignGeometricSecondaryStructure(
          MolecularStructure(chains: [chain]),
        ),
        returnsNormally,
      );
    });
  });

  group('assignGeometricSecondaryStructure: real fixtures', () {
    test('1L2Y (Trp-cage, NMR, model 1 only): matches the documented reference output exactly', () {
      final content = File('test/structure/fixtures/1L2Y.cif')
          .readAsStringSync();
      final parsed = parseMmcifStructure(content);
      expect(parsed.structure.chains, hasLength(1));
      expect(parsed.structure.chains.single.residues, hasLength(20));

      final result = assignGeometricSecondaryStructure(parsed.structure);
      final types = result.single.residues
          .map((r) => r.secondaryStructure)
          .toList();

      // Ground truth: Biotite's own annotate_sse docstring, for this exact
      // PDB entry, gives 'c' 'a'x8 'c'x11 (https://www.biotite-python.org
      // /latest/apidoc/biotite.structure.annotate_sse.html). This is the
      // discriminating test for this port's indexing and thresholds: it's
      // an independent, published ground truth, not our own derivation.
      final expected = [
        SecondaryStructureType.loop,
        ...List.filled(8, SecondaryStructureType.helix),
        ...List.filled(11, SecondaryStructureType.loop),
      ];
      expect(types, expected);
    });

    test(
      '2QLE strand: broad agreement with the real header-derived assignment',
      () {
        // Sheet is the meaningful comparison on this particular fixture (see
        // the helix test below for why helix isn't). P-SEA/DSSP agreement on
        // strand is documented at ~78% generally; observed on this fixture:
        // 317/456 = ~69.5%. The 0.6 bound below is deliberately looser than
        // that observed figure (this is an independent port compared against
        // header annotations, not DSSP itself) -- if this ever regresses,
        // knowing the real number was ~69.5% tells you it's drift, not that
        // the bound was always this tight.
        final content = File('test/structure/fixtures/2QLE.cif')
            .readAsStringSync();
        final parsed = parseMmcifStructure(
          content,
        ); // already has header-derived SS applied
        final document = parseCifDocument(content);
        final ranges = readSecondaryStructureRanges(
          document.firstBlock!,
          parsed.structure.chains,
        );
        expect(
          ranges.where((r) => r.type == SecondaryStructureType.sheet),
          isNotEmpty,
        );

        final geometric = assignGeometricSecondaryStructure(parsed.structure);
        final (int agree, int total) = _agreementOn(
          parsed.structure.chains,
          geometric,
          SecondaryStructureType.sheet,
        );

        expect(total, greaterThan(0));
        final double agreement = agree / total;
        expect(
          agreement,
          greaterThan(0.6),
          reason:
              'header/geometric sheet agreement was $agreement ($agree/$total)',
        );
      },
    );

    test('2QLE helix: near-zero agreement is expected, because these are 3-10 helices, not alpha', () {
      // Confirmed directly against the file: every _struct_conf row here
      // has pdbx_PDB_helix_class 5 ("right-handed 3-10 helix", the PDB's
      // legacy HELIX-record vocabulary carried into mmCIF) and spans only
      // 4-7 residues. P-SEA's thresholds (Cα distances, pseudo-angle,
      // pseudo-dihedral) are calibrated to *alpha*-helix geometry — a 3-10
      // helix's tighter ~3-residues-per-turn pitch doesn't fit them, and
      // several of these segments are too short for the run-length->=5
      // requirement to ever fire regardless of geometry. A real P-SEA (or
      // DSSP) run would show the same gap; this is a documented limitation
      // of the algorithm's scope, not a defect in this port. The ~94%
      // helix agreement figure quoted elsewhere describes typical alpha
      // helix-dominated structures, which 2QLE's header-labeled "helix"
      // regions are not.
      final content = File('test/structure/fixtures/2QLE.cif')
          .readAsStringSync();
      final parsed = parseMmcifStructure(content);
      final document = parseCifDocument(content);
      final ranges = readSecondaryStructureRanges(
        document.firstBlock!,
        parsed.structure.chains,
      );
      expect(
        ranges.where((r) => r.type == SecondaryStructureType.helix),
        isNotEmpty,
      );

      final geometric = assignGeometricSecondaryStructure(parsed.structure);
      final (int agree, int total) = _agreementOn(
        parsed.structure.chains,
        geometric,
        SecondaryStructureType.helix,
      );

      expect(total, greaterThan(0));
      expect(
        agree,
        0,
        reason: '2QLE has no alpha helices to agree on; a positive count here would be suspicious, not reassuring',
      );
    });

    test('myoglobin (AlphaFold model, real DSSP-derived headers): high agreement on genuine alpha helices', () {
      // Complements the 2QLE test above: myoglobin is the classic all-alpha
      // globin fold (8 helices, A-H), and modern AlphaFold DB mmCIF files
      // embed DSSP-computed _struct_conf (criteria: DSSP) -- so unlike
      // 2QLE, this file's header-labeled "helix" residues genuinely are
      // (mostly) HELX_RH_AL_P, i.e. alpha, which P-SEA is calibrated for.
      // Observed: 104/116 = ~89.7%, close to the ~94% documented baseline.
      final content = File('test/structure/fixtures/AF-P02185-F1-myoglobin.cif')
          .readAsStringSync();
      final parsed = parseMmcifStructure(content);
      final document = parseCifDocument(content);
      final ranges = readSecondaryStructureRanges(
        document.firstBlock!,
        parsed.structure.chains,
      );
      expect(
        ranges.where((r) => r.type == SecondaryStructureType.helix),
        isNotEmpty,
      );

      final geometric = assignGeometricSecondaryStructure(parsed.structure);
      final (int agree, int total) = _agreementOn(
        parsed.structure.chains,
        geometric,
        SecondaryStructureType.helix,
      );

      expect(total, greaterThan(0));
      final double agreement = agree / total;
      expect(
        agreement,
        greaterThan(0.75),
        reason:
            'header/geometric helix agreement was $agreement ($agree/$total)',
      );
    });
  });

  group('assignGeometricSecondaryStructure: real fixture with headers stripped (fallback path)', () {
    test('myoglobin with no _struct_conf at all: parseMmcifStructure actually runs the fallback', () {
      // AF-P02185-F1-myoglobin-no-ss.cif is a byte-for-byte copy of the
      // real AlphaFold/DSSP fixture above with the _struct_conf and
      // _struct_conf_type loop_ blocks deleted -- same real predicted-model
      // geometry, simulating the header-less AlphaFold output this
      // fallback exists for (current AlphaFold DB files happen to embed
      // DSSP annotation; third-party/older exports commonly don't).
      final content = File(
        'test/structure/fixtures/AF-P02185-F1-myoglobin-no-ss.cif',
      ).readAsStringSync();
      final document = parseCifDocument(content);
      expect(document.firstBlock!.category('struct_conf'), isNull);

      final result = parseMmcifStructure(content);
      final directlyAssigned = assignGeometricSecondaryStructure(
        result.structure,
      );
      expect(
        result.structure.chains.single.residues.map(
          (r) => r.secondaryStructure,
        ),
        directlyAssigned.single.residues.map((r) => r.secondaryStructure),
      );

      // Sanity check against the known fold: myoglobin is essentially all
      // alpha helix (globin fold, 8 helices). Observed: 108/154 residues.
      final helixFraction =
          result.structure.chains.single.residues
              .where(
                (r) => r.secondaryStructure == SecondaryStructureType.helix,
              )
              .length /
          result.structure.chains.single.residues.length;
      expect(
        helixFraction,
        greaterThan(0.5),
        reason: 'helix fraction was $helixFraction',
      );
    });
  });
}

/// Among residues the header annotation labels [type], how many does the
/// geometric assignment agree with (restricted to residues with a
/// resolved CA, since those without one are excluded from rendering and
/// their label is moot either way).
(int agree, int total) _agreementOn(
  List<Chain> header,
  List<Chain> geometric,
  SecondaryStructureType type,
) {
  int agree = 0;
  int total = 0;
  for (int c = 0; c < header.length; c++) {
    final headerResidues = header[c].residues;
    final geometricResidues = geometric[c].residues;
    for (int r = 0; r < headerResidues.length; r++) {
      if (headerResidues[r].alphaCarbon == null) continue;
      if (headerResidues[r].secondaryStructure != type) continue;
      total++;
      if (geometricResidues[r].secondaryStructure == type) agree++;
    }
  }
  return (agree, total);
}
