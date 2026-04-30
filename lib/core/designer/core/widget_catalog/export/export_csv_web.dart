import 'dart:convert';
import 'dart:typed_data';
import 'package:jsonschema/core/designer/core/widget_catalog/export/export.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';

Future<String?> exportCsv(
  CsvResult csvContent, {
  String fileName = "result.csv",
}) async {
  // var encode = utf8.encode(csvContent.csv);
  var encode = Uint8List.fromList(csvContent.bytes);
  final bytes = encode.toJS;
  final blob = web.Blob([bytes].toJS, web.BlobPropertyBag(type: "text/csv"));

  final url = web.URL.createObjectURL(blob);
  final anchor =
      web.HTMLAnchorElement()
        ..href = url
        ..download = fileName;

  anchor.click();
  web.URL.revokeObjectURL(url);

  return null; // pas de chemin sur Web/WASM
}

Future<String?> exportFile(
  String content, {
  String fileName = "result.html",
}) async {
  var encode = utf8.encode(content);

  final bytes = encode.toJS;
  final blob = web.Blob([bytes].toJS, web.BlobPropertyBag(type: "text/html"));

  final url = web.URL.createObjectURL(blob);
  final anchor =
      web.HTMLAnchorElement()
        ..href = url
        ..download = fileName;

  anchor.click();
  web.URL.revokeObjectURL(url);

  return null; // pas de chemin sur Web/WASM
}

Future<void> openHtmlInChrome(String? path, String spec) async {
  var encode = utf8.encode(spec);

  final bytes = encode.toJS;
  final blob = web.Blob([bytes].toJS, web.BlobPropertyBag(type: "text/html"));

  final url = web.URL.createObjectURL(blob);

  web.window.open(url, '_blank');

  Future.delayed(Duration(seconds: 2), () {
    web.URL.revokeObjectURL(url);
  });
}
