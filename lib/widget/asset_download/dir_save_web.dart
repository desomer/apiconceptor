import 'package:jsonschema/widget/asset_download/web_save.dart'
    show WebFileEntry;

/// Sur le Web, l'enregistrement multi-fichiers passe par [saveWithFileSystemAccess].
Future<String?> saveFilesToDirectory(
  List<WebFileEntry> files, {
  String? dialogTitle,
}) async {
  return null;
}
