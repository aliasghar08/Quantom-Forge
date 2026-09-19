import 'dart:html' as html;
import 'dart:convert';

Future<void> exportForAvogadro(String filename, String xyzData) async {
  final bytes = utf8.encode(xyzData);
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
