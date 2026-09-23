import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:jsonschema/widget/asset_download/web_save.dart'
    show WebFileEntry;

/// Demande un dossier de destination puis y ecrit tous les [files]. Chaque
/// builder recoit le chemin absolu reel du fichier a ecrire.
/// Retourne le chemin du dossier choisi, ou `null` si l'utilisateur annule.
Future<String?> saveFilesToDirectory(
  List<WebFileEntry> files, {
  String? dialogTitle,
}) async {
  final dirPath = await FilePicker.getDirectoryPath(dialogTitle: dialogTitle);
  if (dirPath == null) return null; // annule par l'utilisateur

  for (final (bytesBuilder, fileName) in files) {
    final filePath = '$dirPath${Platform.pathSeparator}$fileName';
    final bytes = await bytesBuilder(filePath);
    final file = File(filePath);
    await file.writeAsBytes(bytes);
  }
  return dirPath;
}
