/// The kind of a raw [CifToken] produced by the character-level scanner.
///
/// Kind is what lets the assembler (see `cif_document.dart`) tell a *tag*
/// from a *value* correctly: an unquoted word starting with `_` is only
/// ever a candidate tag; the same text arriving as a quoted or text-field
/// value is always data, never structure, no matter what it looks like.
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

  /// True for `?`/`.` only when they arrived unquoted — these are the CIF
  /// null markers. A quoted `'.'` or `'?'` is a literal one-character
  /// string, not null.
  bool get isNullMarker =>
      kind == CifTokenKind.word && (text == '?' || text == '.');

  @override
  String toString() =>
      '${kind.name}(${text.length > 40 ? '${text.substring(0, 40)}…' : text})';
}
