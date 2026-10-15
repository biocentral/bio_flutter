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
  group('assignPseaSecondaryStructure: degenerate inputs', () {
    test('an empty structure does not throw', () {
      expect(
        assignPseaSecondaryStructure(MolecularStructure(chains: [])),
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
      final result = assignPseaSecondaryStructure(
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
        () => assignPseaSecondaryStructure(MolecularStructure(chains: [chain])),
        returnsNormally,
      );
    });
  });

  group('assignPseaSecondaryStructure: real fixtures', () {
    test('1L2Y (Trp-cage, NMR, model 1 only): matches the documented reference output exactly', () {
      final content = File('test/structure/fixtures/1L2Y.cif')
          .readAsStringSync();
      final parsed = parseMmcifStructure(content);
      expect(parsed.structure.chains, hasLength(1));
      expect(parsed.structure.chains.single.residues, hasLength(20));

      final result = assignPseaSecondaryStructure(parsed.structure);
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
        // Sheet is the meaningful comparison here; see the helix test below.
        // P-SEA/DSSP strand agreement is typically ~78%; observed here: 338/456
        // (~74.1%). The 0.6 bound leaves room below that.
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

        final geometric = assignPseaSecondaryStructure(parsed.structure);
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
      // 17 of the 21 helix rows are 3-10 helices (class 5), which P-SEA's
      // alpha-calibrated thresholds do not detect, and all rows span only 4-7
      // residues. The four alpha rows (author 82-87) are not detected either.
      // Observed: 0/124.
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

      final geometric = assignPseaSecondaryStructure(parsed.structure);
      final (int agree, int total) = _agreementOn(
        parsed.structure.chains,
        geometric,
        SecondaryStructureType.helix,
      );

      expect(total, greaterThan(0));
      expect(
        agree,
        0,
        reason: 'P-SEA was observed to assign no helix in 2QLE; a change means the assignment itself changed',
      );
    });

    test('myoglobin (AlphaFold model, real DSSP-derived headers): high agreement on genuine alpha helices', () {
      // Myoglobin is all alpha, and AlphaFold DB files embed DSSP helices, which
      // P-SEA is calibrated for. Observed: 104/116 (~89.7%), near the ~94%
      // documented baseline.
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

      final geometric = assignPseaSecondaryStructure(parsed.structure);
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
