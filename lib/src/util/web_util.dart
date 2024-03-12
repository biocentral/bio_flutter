import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

/// Web-specific file download handling
Future<void> triggerFileDownload(Uint8List bytes, String fileName) async {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute("download", fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
