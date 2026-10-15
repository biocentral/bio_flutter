import '../model/chain.dart';
import '../model/molecular_structure.dart';
import 'dssp.dart';
import 'p_sea.dart';

/// Assigns secondary structure from coordinates, for chains without header
/// annotation.
///
/// Uses [assignDsspSecondaryStructure] for every chain with at least one
/// complete backbone residue, and [assignPseaSecondaryStructure] for
/// Cα-only chains, which DSSP cannot handle.
List<Chain> assignGeometricSecondaryStructure(MolecularStructure structure) {
  final List<Chain> dssp = assignDsspSecondaryStructure(structure);
  final List<bool> caOnly = [
    for (final chain in structure.chains)
      !chain.residues.any(hasCompleteBackbone),
  ];
  if (!caOnly.contains(true)) return dssp;

  final List<Chain> pSea = assignPseaSecondaryStructure(structure);
  return [for (int i = 0; i < dssp.length; i++) caOnly[i] ? pSea[i] : dssp[i]];
}
