/// The lexical kind of a [CifToken].
///
/// Only unquoted words can be tags or keywords; quoted and text-field values
/// are always data.
enum CifTokenKind {
  /// An unquoted, whitespace-delimited word. May be a tag (starts with
  /// `_`), the `loop_`/`data_...` keywords (case-insensitive), a null
  /// marker (`?` or `.`), or an ordinary unquoted value.
  word,

  /// A value delimited by `'...'` or `"..."`. Always data, regardless of
  /// its text (a quoted `_entry.id` is the three-word string, not a tag).
  quoted,

  /// A multi-line value delimited by `<eol>;` ... `<eol>;` (a "text
  /// field"). Always data, regardless of its text.
  textField,
}

/// One token from the CIF character-level scan: raw text plus enough
/// information for the assembler to classify it without re-inspecting the
/// source text.
class CifToken {
  const CifToken(this.kind, this.text);

  final CifTokenKind kind;
  final String text;

  /// Whether this is a CIF null marker: an unquoted `?` or `.`.
  bool get isNullMarker =>
      kind == CifTokenKind.word && (text == '?' || text == '.');

  @override
  String toString() =>
      '${kind.name}(${text.length > 40 ? '${text.substring(0, 40)}…' : text})';
}
