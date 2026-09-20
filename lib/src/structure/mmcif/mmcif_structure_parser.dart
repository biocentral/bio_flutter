import '../cif/cif_document.dart';
import '../model/chain.dart';
import '../model/molecular_structure.dart';
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
/// Uses geometric secondary structure when no usable header ranges remain.
/// Throws [FormatException] for invalid CIF syntax or a missing data block.
MmcifParseResult parseMmcifStructure(String content) {
  final CifDocument document = parseCifDocument(content);
  final CifBlock? block = document.firstBlock;
  if (block == null) {
    throw const FormatException('not a valid mmCIF file: no data_ block found');
  }

  final AtomSiteResult atomSite = readAtomSite(block);
  final ranges = readSecondaryStructureRanges(block, atomSite.chains);

  final List<Chain> chains = ranges.isEmpty
      ? assignGeometricSecondaryStructure(
          MolecularStructure(chains: atomSite.chains),
        )
      : applySecondaryStructure(atomSite.chains, ranges);

  return MmcifParseResult(
    MolecularStructure(chains: chains),
    atomSite.warnings,
  );
}
