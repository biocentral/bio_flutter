import 'cif_token.dart';

/// Scans CIF 1.1 text into tokens, without mmCIF-specific knowledge.
///
/// Lexical rules:
///  - whitespace separates unquoted words;
///  - a quote closes a quoted value only when followed by whitespace or the
///    end of input, so `O5'` and `'it's fine'` need no escaping;
///  - a `;` in column 1 opens a text field that runs verbatim until the next
///    line starting with `;`;
///  - `#` at a token start begins a comment, which is discarded.
///
/// `save_` and `global_` frames are scanned as ordinary words.
List<CifToken> tokenizeCif(String content) {
  // Normalized so the rules below only handle '\n'.
  final String text = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final int len = text.length;

  final List<CifToken> tokens = [];
  int idx = 0;
  // Text fields start only at true column 1.
  bool atLineStart = true;

  while (idx < len) {
    if (atLineStart && text[idx] == ';') {
      idx++;
      final StringBuffer buffer = StringBuffer();
      bool firstLine = true;
      while (true) {
        final int lineEnd = text.indexOf('\n', idx);
        final int contentEnd = lineEnd == -1 ? len : lineEnd;
        final String line = text.substring(idx, contentEnd);
        if (line.startsWith(';')) {
          idx = lineEnd == -1 ? len : lineEnd + 1;
          atLineStart = true;
          break;
        }
        if (!firstLine) buffer.write('\n');
        buffer.write(_stripTrailingBlank(line));
        firstLine = false;
        if (lineEnd == -1) {
          // Unterminated text field: keep what was read.
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
      if (idx < len) idx++;
      atLineStart = false;
      tokens.add(CifToken(CifTokenKind.quoted, value));
      continue;
    }

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
