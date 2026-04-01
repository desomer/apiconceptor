import 'dart:io';
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
