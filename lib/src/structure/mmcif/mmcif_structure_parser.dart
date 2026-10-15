import '../cif/cif_document.dart';
import '../model/chain.dart';
import '../model/molecular_structure.dart';
import '../model/secondary_structure.dart';
import '../ss/p_sea.dart';
import 'atom_site_reader.dart';
import 'secondary_structure_reader.dart';

/// A parsed structure and recoverable reader warnings.
class MmcifParseResult {
  const MmcifParseResult(this.structure, this.warnings);

  final MolecularStructure structure;
  final List<String> warnings;
}

/// Parses the first mmCIF data block into amino acid chains.
///
/// Uses geometric secondary structure for chains that no header range
/// covers. Throws [FormatException] when there is no data block.
MmcifParseResult parseMmcifStructure(String content) {
  final CifDocument document = parseCifDocument(content);
  final CifBlock? block = document.firstBlock;
  if (block == null) {
    throw const FormatException('not a valid mmCIF file: no data_ block found');
  }

  final AtomSiteResult atomSite = readAtomSite(block);
  final ranges = readSecondaryStructureRanges(block, atomSite.chains);

  final List<Chain> fromHeader = applySecondaryStructure(
    atomSite.chains,
    ranges,
  );
  final List<bool> uncovered = [
    for (final chain in fromHeader)
      chain.residues.every(
        (r) => r.secondaryStructure == SecondaryStructureType.loop,
      ),
  ];
  if (!uncovered.contains(true)) {
    return MmcifParseResult(
      MolecularStructure(chains: fromHeader),
      atomSite.warnings,
    );
  }

  final List<String> warnings = [...atomSite.warnings];
  if (ranges.isNotEmpty) {
    for (int i = 0; i < fromHeader.length; i++) {
      if (uncovered[i]) {
        warnings.add(
          'chain ${fromHeader[i].id}: no header secondary-structure range '
          'covers a residue; using geometric assignment',
        );
      }
    }
  }
  final List<Chain> geometric = assignGeometricSecondaryStructure(
    MolecularStructure(chains: atomSite.chains),
  );
  return MmcifParseResult(
    MolecularStructure(
      chains: [
        for (int i = 0; i < fromHeader.length; i++)
          uncovered[i] ? geometric[i] : fromHeader[i],
      ],
    ),
    warnings,
  );
}
