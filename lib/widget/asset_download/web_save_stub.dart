import 'dart:typed_data';

enum WebSaveOutcome { saved, cancelled, unsupported }

/// Construit le contenu a ecrire une fois que l'utilisateur a choisi sa
/// destination. [chosenPath] est le nom retourne par le navigateur (l'API ne
/// donne jamais le chemin disque reel, pour des raisons de securite).
typedef WebBytesBuilder = Future<Uint8List> Function(String chosenPath);

/// Un fichier a ecrire, sous forme de couple (builder de contenu, nom de fichier).
typedef WebFileEntry = (WebBytesBuilder bytesBuilder, String fileName);

/// Hors Web (desktop/mobile), la File System Access API n'existe pas.
Future<WebSaveOutcome> saveWithFileSystemAccess(
  WebBytesBuilder bytesBuilder,
  String fileName, {
  List<WebFileEntry>? extraFiles,
}) async {
  return WebSaveOutcome.unsupported;
}
