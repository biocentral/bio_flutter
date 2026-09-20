import 'cif_token.dart';

/// Scans raw CIF 1.1 text into a flat stream of [CifToken]s.
///
/// This is a character-level scanner with **zero mmCIF-specific
/// knowledge** — it doesn't know what `loop_`, `data_`, or a tag are; it
/// only knows CIF's low-level lexical rules:
///
///  - whitespace (space, tab, newline) separates unquoted words;
///  - `'...'`/`"..."` delimit a quoted value, where the closing quote must
///    be immediately followed by whitespace or end-of-input — this is what
///    lets an unquoted atom name like `O5'` keep its apostrophe without
///    being misread as opening a quote, and lets a quoted value contain an
///    embedded, non-closing apostrophe (`'it's fine'` reads as `it's
///    fine`) with no escape syntax needed;
///  - a `;` that is the very first character of a physical line opens a
///    multi-line text field, which runs verbatim (including embedded
///    whitespace, blank lines, and `#`) until a line that again starts
///    with `;` closes it;
///  - `#` starts a comment to end of line, but only where a new token
///    could start (immediately after whitespace or at start of line) — a
///    `#` embedded inside a word (impossible to reach here, since the
///    word-scanning branch already consumes it) never triggers this;
///  - comments are discarded entirely, not emitted as tokens, so they are
///    fully transparent to anything consuming the token stream (including
///    row assembly inside a `loop_` — a comment line between data rows
///    does not interrupt them).
///
/// What this scanner deliberately does not implement: `save_`/`global_`
/// frames (dictionary-file constructs, never present in RCSB coordinate
/// files) are tokenized as ordinary words rather than recognized as
/// keywords. That's fine for this package's input (mmCIF structure files),
/// and is called out here rather than silently assumed.
List<CifToken> tokenizeCif(String content) {
  // Normalizing line endings up front means every other rule only has to
  // reason about '\n'.
  final String text = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final int len = text.length;

  final List<CifToken> tokens = [];
  int idx = 0;
  // True at the very start of input and immediately after consuming '\n'.
  // This is what makes ';' text-field detection require true column 1,
  // not merely "first non-blank character of the line".
  bool atLineStart = true;

  while (idx < len) {
    // Text field: ';' at true column 1.
    if (atLineStart && text[idx] == ';') {
      idx++; // consume the opening ';'
      final StringBuffer buffer = StringBuffer();
      bool firstLine = true;
      while (true) {
        final int lineEnd = text.indexOf('\n', idx);
        final int contentEnd = lineEnd == -1 ? len : lineEnd;
        final String line = text.substring(idx, contentEnd);
        if (line.startsWith(';')) {
          // Closing delimiter. Its own ';' and the line it's on are not
          // part of the value.
          idx = lineEnd == -1 ? len : lineEnd + 1;
          atLineStart = true;
          break;
        }
        if (!firstLine) buffer.write('\n');
        buffer.write(_stripTrailingBlank(line));
        firstLine = false;
        if (lineEnd == -1) {
          // Unterminated text field (no closing ';' before EOF). Lenient:
          // take what we have rather than throwing.
          idx = len;
          atLineStart = true;
          break;
        }
        idx = lineEnd + 1;
      }
      tokens.add(CifToken(CifTokenKind.textField, buffer.toString()));
      continue;
    }

    final String ch = text[idx];

    if (ch == ' ' || ch == '\t') {
      idx++;
      atLineStart = false;
      continue;
    }
    if (ch == '\n') {
      idx++;
      atLineStart = true;
      continue;
    }
    if (ch == '#') {
      // Only reached at a token-start position (see class doc) — comment
      // to end of line, discarded.
      final int nl = text.indexOf('\n', idx);
      idx = nl == -1 ? len : nl;
      continue;
    }
    if (ch == "'" || ch == '"') {
      final String closing = ch;
      idx++;
      final int start = idx;
      while (idx < len) {
        final bool isClosingQuote =
            text[idx] == closing &&
            (idx + 1 >= len ||
                text[idx + 1] == ' ' ||
                text[idx + 1] == '\t' ||
                text[idx + 1] == '\n');
        if (isClosingQuote) break;
        idx++;
      }
      final String value = text.substring(start, idx);
      if (idx < len) idx++; // consume closing quote; lenient if unterminated
      atLineStart = false;
      tokens.add(CifToken(CifTokenKind.quoted, value));
      continue;
    }

    // Unquoted word: everything up to the next whitespace.
    final int start = idx;
    while (idx < len &&
        text[idx] != ' ' &&
        text[idx] != '\t' &&
        text[idx] != '\n') {
      idx++;
    }
    atLineStart = false;
    tokens.add(CifToken(CifTokenKind.word, text.substring(start, idx)));
  }

  return tokens;
}

/// Strips trailing spaces/tabs from one line of a text field's content, as
/// required by the CIF spec ("trailing white space on a line may however
/// be elided"); leading whitespace is preserved verbatim.
String _stripTrailingBlank(String line) {
  int end = line.length;
  while (end > 0 && (line[end - 1] == ' ' || line[end - 1] == '\t')) {
    end--;
  }
  return line.substring(0, end);
}
