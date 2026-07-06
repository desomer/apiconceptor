import 'dart:io';
import 'dart:typed_data';
import 'package:jsonschema/core/designer/core/widget_catalog/export/export.dart';
import 'package:path_provider/path_provider.dart';

Future<String?> exportCsv(
  CsvResult csvContent, {
  String fileName = "result.csv",
}) async {
  final dir = await getDownloadsDirectory();
  final file = File("${dir!.path}/$fileName");
  await file.writeAsString(csvContent.csv);
  return file.path;
}

Future<String?> exportFile(
  String content, {
  String fileName = "result.html",
}) async {
  final dir = await getDownloadsDirectory();
  final file = File("${dir!.path}/$fileName");
  await file.writeAsString(content);
  return file.path;
}

Future<String?> exportPng(
  Uint8List bytes, {
  String fileName = "result.png",
}) async {
  final dir = await getDownloadsDirectory();
  final file = File("${dir!.path}/$fileName");
  await file.writeAsBytes(bytes);
  return file.path;
}

Future<void> openHtmlInChrome(String? path, String spec) async {
  await Process.start('cmd', [
    '/c',
    'start',
    'chrome',
    path!,
  ], runInShell: true);
}
