import '../cif/cif_document.dart';
import '../model/chain.dart';
import '../model/residue.dart';
import '../model/secondary_structure.dart';

/// Reads helix (`_struct_conf` rows of `HELX` type) and sheet
/// (`_struct_sheet_range`) ranges, keyed by `label_asym_id`. Files that give
/// only `auth_asym_id` are translated through [chains].
///
/// Boundaries are read in both label and author numbering; see
/// [SecondaryStructureRange.covers]. Returns an empty list when neither
/// category is present; the caller decides on a fallback.
List<SecondaryStructureRange> readSecondaryStructureRanges(
  CifBlock block,
  List<Chain> chains,
) {
  // Unambiguous while each author chain name maps to one retained chain.
  final Map<String, String> authToLabel = {
    for (final chain in chains) chain.authChainId: chain.id,
  };

  final List<SecondaryStructureRange> ranges = [];

  final CifCategory? helixCategory = block.category('struct_conf');
  if (helixCategory != null) {
    for (final row in helixCategory.rows) {
      final String confType = (row['conf_type_id'] ?? '').toUpperCase();
      if (!confType.startsWith('HELX')) continue;
      final SecondaryStructureRange? range = _rangeFromRow(
        row,
        SecondaryStructureType.helix,
        authToLabel,
      );
      if (range != null) ranges.add(range);
    }
  }

  final CifCategory? sheetCategory = block.category('struct_sheet_range');
  if (sheetCategory != null) {
    for (final row in sheetCategory.rows) {
      final SecondaryStructureRange? range = _rangeFromRow(
        row,
        SecondaryStructureType.sheet,
        authToLabel,
      );
      if (range != null) ranges.add(range);
    }
  }

  return ranges;
}

/// Returns [chains] with each residue's type taken from the first covering
/// range, or [SecondaryStructureType.loop] if none covers it.
List<Chain> applySecondaryStructure(
  List<Chain> chains,
  List<SecondaryStructureRange> ranges,
) {
  return [
    for (final chain in chains)
      Chain(
        id: chain.id,
        authChainId: chain.authChainId,
        residues: [
          for (final residue in chain.residues)
            residue.withSecondaryStructure(_typeFor(chain.id, residue, ranges)),
        ],
      ),
  ];
}

SecondaryStructureType _typeFor(
  String chainId,
  Residue residue,
  List<SecondaryStructureRange> ranges,
) {
  for (final range in ranges) {
    if (range.covers(chainId, residue.id, labelSeqId: residue.labelSeqId)) {
      return range.type;
    }
  }
  return SecondaryStructureType.loop;
}

SecondaryStructureRange? _rangeFromRow(
  Map<String, String?> row,
  SecondaryStructureType type,
  Map<String, String> authToLabel,
) {
  final String? chainId =
      row['beg_label_asym_id'] ??
      _translatedAuthChain(row['beg_auth_asym_id'], authToLabel);
  if (chainId == null) return null;

  final int? beginLabel = int.tryParse(row['beg_label_seq_id'] ?? '');
  final int? endLabel = int.tryParse(row['end_label_seq_id'] ?? '');
  final bool hasLabel = beginLabel != null && endLabel != null;

  // Insertion codes belong to author numbering only.
  final int? beginAuth = int.tryParse(row['beg_auth_seq_id'] ?? '');
  final int? endAuth = int.tryParse(row['end_auth_seq_id'] ?? '');
  final bool hasAuth = beginAuth != null && endAuth != null;

  if (!hasLabel && !hasAuth) return null;
  return SecondaryStructureRange(
    chainId: chainId,
    type: type,
    beginLabelSeqId: hasLabel ? beginLabel : null,
    endLabelSeqId: hasLabel ? endLabel : null,
    begin: hasAuth
        ? ResidueId(beginAuth, row['pdbx_beg_pdb_ins_code'] ?? '')
        : null,
    end: hasAuth
        ? ResidueId(endAuth, row['pdbx_end_pdb_ins_code'] ?? '')
        : null,
  );
}

String? _translatedAuthChain(
  String? authChainId,
  Map<String, String> authToLabel,
) {
  if (authChainId == null) return null;
  return authToLabel[authChainId];
}
