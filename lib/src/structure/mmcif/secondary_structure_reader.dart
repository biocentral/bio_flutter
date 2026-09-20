import '../cif/cif_document.dart';
import '../model/chain.dart';
import '../model/residue.dart';
import '../model/secondary_structure.dart';

/// Reads `_struct_conf` (kept only where `conf_type_id` starts with
/// `HELX`) and `_struct_sheet_range` (every row counts as sheet) into
/// [SecondaryStructureRange]s, keyed by `label_asym_id` — matching how
/// [Chain]s are grouped in `atom_site_reader.dart` — with a fallback to
/// `auth_asym_id` when a file only provides that.
///
/// Range boundaries use the `..._label_seq_id`/`pdbx_..._PDB_ins_code`
/// pair when present (falling back to the `auth_*` equivalents), so a
/// residue sharing a numeric seqId with a range boundary but a different
/// insertion code is classified correctly — see [ResidueId] and
/// [SecondaryStructureRange.covers].
///
/// Returns an empty list (not null, not an error) when both categories are
/// absent or empty — callers should treat that as "no header SS
/// annotation available" and either leave every residue as
/// [SecondaryStructureType.loop] or apply a geometric fallback assignment;
/// this reader does not decide that policy.
List<SecondaryStructureRange> readSecondaryStructureRanges(
  CifBlock block,
  List<Chain> chains,
) {
  // A file's struct_conf/struct_sheet_range use label_asym_id in the
  // overwhelming common case (mandatory in the current dictionary). When a
  // minimal/older file only has the auth_asym_id variant, translate via
  // the already-built (protein-only) chains — unambiguous as long as one
  // auth_asym_id maps to at most one *retained* protein chain, which holds
  // for every structure this package's scope covers.
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

/// Applies [ranges] to [chains], returning new [Chain]/[Residue] instances
/// with each residue's secondary structure set from the first covering
/// range (matching the existing convention: first match wins), defaulting
/// to [SecondaryStructureType.loop] when no range covers a residue.
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
            residue.withSecondaryStructure(
              _typeFor(chain.id, residue.id, ranges),
            ),
        ],
      ),
  ];
}

SecondaryStructureType _typeFor(
  String chainId,
  ResidueId id,
  List<SecondaryStructureRange> ranges,
) {
  for (final range in ranges) {
    if (range.covers(chainId, id)) return range.type;
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
  final int? beginSeq = int.tryParse(
    row['beg_label_seq_id'] ?? row['beg_auth_seq_id'] ?? '',
  );
  final int? endSeq = int.tryParse(
    row['end_label_seq_id'] ?? row['end_auth_seq_id'] ?? '',
  );
  if (chainId == null || beginSeq == null || endSeq == null) return null;

  final String beginIns = row['pdbx_beg_pdb_ins_code'] ?? '';
  final String endIns = row['pdbx_end_pdb_ins_code'] ?? '';

  return SecondaryStructureRange(
    chainId: chainId,
    begin: ResidueId(beginSeq, beginIns),
    end: ResidueId(endSeq, endIns),
    type: type,
  );
}

String? _translatedAuthChain(
  String? authChainId,
  Map<String, String> authToLabel,
) {
  if (authChainId == null) return null;
  return authToLabel[authChainId];
}
