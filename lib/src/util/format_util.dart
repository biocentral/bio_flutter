import 'dart:math';

String shorten(String? stringToShorten, int maxChars) {
  if(stringToShorten == null) {
    return "";
  }
  int strLen = stringToShorten.length;
  return "${stringToShorten.substring(0, min(strLen, maxChars))}${strLen > maxChars ? ".." : ""}";
}