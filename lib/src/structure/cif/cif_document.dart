import 'cif_token.dart';
import 'cif_tokenizer.dart';

/// One mmCIF category's data — e.g. `atom_site`, `struct_conf` — with a
/// **unified row API regardless of whether the source used `loop_` or
/// bare key-value syntax.**
///
/// This is the fix for the most consequential gap found in prior Dart mmCIF
/// parsing attempts: a category written as single-row key-value (legal, and
/// common for e.g. `_struct_conf`/`_struct_sheet_range` when a structure has
/// exactly one helix or strand) is indistinguishable here from the same
/// category written as a one-row `loop_` — both produce a [CifCategory]
/// with one row. Category-extraction code downstream never needs to know
/// which syntax form the file used.
class CifCategory {
  CifCategory(this.name, this.rows);

  /// Lowercased category name (e.g. `atom_site`), per CIF's
  /// case-insensitive data names.
  final String name;

  /// One map per row; keys are lowercased field names. A value is `null`
  /// only when it was an *unquoted* `?`/`.` — CIF's null markers. A row
  /// from non-loop key-value syntax is simply a list of length 1.
  final List<Map<String, String?>> rows;

  /// [row]'s value for [field], or `null` if absent or a CIF null marker.
  /// Does not throw on missing fields — most categories are optional and
  /// most fields within them are too.
  static String? value(Map<String, String?> row, String field) =>
      row[field.toLowerCase()];
}

/// One `data_` block: its categories, keyed by lowercased category name.
class CifBlock {
  CifBlock(this.name, this.categories);

  final String name;
  final Map<String, CifCategory> categories;

  CifCategory? category(String name) => categories[name.toLowerCase()];
}

/// A parsed CIF document: an ordered list of `data_` blocks.
///
/// mmCIF structure files served by RCSB always have exactly one block;
/// this type still supports more than one for general CIF correctness, but
/// callers parsing a single structure should use [firstBlock].
class CifDocument {
  CifDocument(this.blocks);

  final List<CifBlock> blocks;

  CifBlock? get firstBlock => blocks.isEmpty ? null : blocks.first;
}

/// Parses [content] into a [CifDocument].
///
/// Implements the CIF 1.1 grammar this package's input needs: `data_`
/// blocks, `loop_` tables, bare key-value pairs, quoted and `;...;`
/// multi-line values, case-insensitive keywords and tags (never values),
/// and comments — see `cif_tokenizer.dart` for the lexical rules and their
/// scope. Does not implement `save_`/`global_` dictionary-file frames.
CifDocument parseCifDocument(String content) {
  final List<CifToken> tokens = tokenizeCif(content);
  int i = 0;

  bool isWord(CifToken t) => t.kind == CifTokenKind.word;
  // A tag is only ever an *unquoted* word starting with '_' — never a
  // quoted or text-field value, no matter what its text looks like.
  bool isTag(CifToken t) => isWord(t) && t.text.startsWith('_');
  bool isLoopKeyword(CifToken t) =>
      isWord(t) && t.text.toLowerCase() == 'loop_';
  bool isDataBlockKeyword(CifToken t) =>
      isWord(t) && t.text.toLowerCase().startsWith('data_');

  (String category, String field) splitTag(String rawTag) {
    final String tag = rawTag
        .substring(1)
        .toLowerCase(); // drop leading '_', lowercase
    final int dot = tag.indexOf('.');
    if (dot == -1) return (tag, '');
    return (tag.substring(0, dot), tag.substring(dot + 1));
  }

  String? cellValue(CifToken t) => t.isNullMarker ? null : t.text;

  final List<CifBlock> blocks = [];
  String currentBlockName = '';
  // category name -> accumulated rows, in the order first encountered.
  // Non-loop (key-value) categories accumulate into a single row (rows[0]);
  // a loop_ for a category that already has key-value data overwrites it
  // (documented last-wins policy for duplicate/conflicting category data).
  Map<String, List<Map<String, String?>>> currentCategories = {};

  void flushBlock() {
    if (currentBlockName.isEmpty && currentCategories.isEmpty) return;
    blocks.add(
      CifBlock(currentBlockName, {
        for (final entry in currentCategories.entries)
          entry.key: CifCategory(entry.key, entry.value),
      }),
    );
  }

  while (i < tokens.length) {
    final CifToken token = tokens[i];

    if (isDataBlockKeyword(token)) {
      flushBlock();
      currentBlockName = token.text.substring(5); // after 'data_'
      currentCategories = {};
      i++;
      continue;
    }

    if (isLoopKeyword(token)) {
      i++;
      // Collect the tag list. All tags in one loop_ are expected to share
      // one category (true for every RCSB-authored mmCIF category this
      // package targets); a tag from a different category ends the list.
      final List<String> columns = [];
      String? category;
      while (i < tokens.length && isTag(tokens[i])) {
        final (String cat, String field) = splitTag(tokens[i].text);
        category ??= cat;
        if (cat != category) break;
        columns.add(field);
        i++;
      }
      if (category == null || columns.isEmpty) {
        continue; // malformed loop_, skip
      }

      // Collect data values until the next tag, loop_, or data_ — i.e.
      // until whatever comes next isn't plain data.
      final List<String?> values = [];
      while (i < tokens.length &&
          !isTag(tokens[i]) &&
          !isLoopKeyword(tokens[i]) &&
          !isDataBlockKeyword(tokens[i])) {
        values.add(cellValue(tokens[i]));
        i++;
      }

      final List<Map<String, String?>> rows = [];
      for (
        int v = 0;
        v + columns.length <= values.length;
        v += columns.length
      ) {
        rows.add({
          for (int c = 0; c < columns.length; c++) columns[c]: values[v + c],
        });
      }
      // Any remainder (values.length not a multiple of columns.length) is
      // a malformed trailing partial row — dropped, matching this parser's
      // general lenient-skip policy for malformed input.
      currentCategories[category] = rows;
      continue;
    }

    if (isTag(token)) {
      // Bare key-value: one tag, one value, contributing one field to that
      // category's single accumulated row.
      final (String category, String field) = splitTag(token.text);
      i++;
      if (i >= tokens.length ||
          isTag(tokens[i]) ||
          isLoopKeyword(tokens[i]) ||
          isDataBlockKeyword(tokens[i])) {
        // Tag with no value token following (malformed) — skip it.
        continue;
      }
      final String? value = cellValue(tokens[i]);
      i++;
      final List<Map<String, String?>> rows = currentCategories.putIfAbsent(
        category,
        () => [<String, String?>{}],
      );
      if (rows.isEmpty) rows.add({});
      rows.first[field] = value;
      continue;
    }

    // A stray value token outside of any tag/loop context (malformed) —
    // skip it rather than throwing, matching the lenient policy elsewhere.
    i++;
  }
  flushBlock();

  return CifDocument(blocks);
}
