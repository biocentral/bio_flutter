import 'package:flutter/foundation.dart';

import '../mmcif/mmcif_structure_parser.dart' as internal;
import '../model/molecular_structure.dart';

/// A recoverable issue encountered while interpreting mmCIF data.
class ParseDiagnostic {
  const ParseDiagnostic({required this.code, required this.message});

  /// A machine-readable category. More specific categories may be added later.
  final String code;
  final String message;
}

/// A parsed structure and warnings about omitted or ambiguous input.
class MmcifParseResult {
  MmcifParseResult(this.structure, Iterable<ParseDiagnostic> diagnostics)
    : diagnostics = List.unmodifiable(diagnostics);

  final MolecularStructure structure;
  final List<ParseDiagnostic> diagnostics;
}

/// Parses mmCIF text without performing file or network access.
abstract final class MmcifParser {
  /// Parses the first data block and first encountered coordinate model.
  ///
  /// Retains amino acid chains only, resolving atom alternates by occupancy.
  /// Uses geometric secondary structure when no usable header ranges remain.
  /// Throws [FormatException] for invalid CIF syntax. Missing protein data
  /// produces an empty structure, with diagnostics where available.
  ///
  /// Runs in an isolate on native platforms. On web, [compute] executes on
  /// the current event loop; large files can still block the browser UI.
  static Future<MmcifParseResult> parse(String content) =>
      compute(_parse, content);
}

MmcifParseResult _parse(String content) {
  final result = internal.parseMmcifStructure(content);
  return MmcifParseResult(result.structure, [
    for (final warning in result.warnings)
      ParseDiagnostic(code: 'mmcif.warning', message: warning),
  ]);
}
