import 'cif_token.dart';
import 'cif_tokenizer.dart';

/// One mmCIF category's rows, e.g. `atom_site` or `struct_conf`.
///
/// Key-value syntax yields the same single row as a one-row `loop_`, so
/// readers need not know which syntax the file used.
class CifCategory {
  CifCategory(this.name, this.rows);

  /// Lowercased category name (e.g. `atom_site`), per CIF's
  /// case-insensitive data names.
  final String name;

  /// One map per row, keyed by lowercased field name. A value is null only
  /// for an unquoted `?` or `.`, the CIF null markers.
  final List<Map<String, String?>> rows;

  /// [row]'s value for [field], or null if absent or a CIF null marker.
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

/// A parsed CIF document: its `data_` blocks in file order.
///
/// Coordinate files contain a single block; see [firstBlock].
class CifDocument {
  CifDocument(this.blocks);

  final List<CifBlock> blocks;

  CifBlock? get firstBlock => blocks.isEmpty ? null : blocks.first;
}

/// Parses [content] into a [CifDocument].
///
/// Supports `data_` blocks, `loop_` tables, key-value pairs, quoted and
/// text-field values, and comments. Keywords and tags are case-insensitive.
/// `save_` and `global_` frames are not supported. Malformed input is
/// skipped rather than rejected.
CifDocument parseCifDocument(String content) {
  final List<CifToken> tokens = tokenizeCif(content);
  int i = 0;

  bool isWord(CifToken t) => t.kind == CifTokenKind.word;
  // Only unquoted words can be tags.
  bool isTag(CifToken t) => isWord(t) && t.text.startsWith('_');
  bool isLoopKeyword(CifToken t) =>
      isWord(t) && t.text.toLowerCase() == 'loop_';
  bool isDataBlockKeyword(CifToken t) =>
      isWord(t) && t.text.toLowerCase().startsWith('data_');

  (String category, String field) splitTag(String rawTag) {
    final String tag = rawTag.substring(1).toLowerCase();
    final int dot = tag.indexOf('.');
    if (dot == -1) return (tag, '');
    return (tag.substring(0, dot), tag.substring(dot + 1));
  }

  String? cellValue(CifToken t) => t.isNullMarker ? null : t.text;

  final List<CifBlock> blocks = [];
  String currentBlockName = '';
  // Last wins: a loop_ replaces earlier key-value data for its category.
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
      currentBlockName = token.text.substring(5);
      currentCategories = {};
      i++;
      continue;
    }

    if (isLoopKeyword(token)) {
      i++;
      // A loop_'s tags share one category; a tag from another category ends it.
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
        continue;
      }

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
      // A trailing partial row is malformed and dropped.
      currentCategories[category] = rows;
      continue;
    }

    if (isTag(token)) {
      final (String category, String field) = splitTag(token.text);
      i++;
      if (i >= tokens.length ||
          isTag(tokens[i]) ||
          isLoopKeyword(tokens[i]) ||
          isDataBlockKeyword(tokens[i])) {
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

    i++;
  }
  flushBlock();

  return CifDocument(blocks);
}
