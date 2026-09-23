import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

enum WebSaveOutcome { saved, cancelled, unsupported }

/// Construit le contenu a ecrire une fois que l'utilisateur a choisi sa
/// destination. [chosenPath] est le nom retourne par le navigateur (l'API ne
/// donne jamais le chemin disque reel, pour des raisons de securite).
typedef WebBytesBuilder = Future<Uint8List> Function(String chosenPath);

/// Un fichier a ecrire, sous forme de couple (builder de contenu, nom de fichier).
typedef WebFileEntry = (WebBytesBuilder bytesBuilder, String fileName);

/// Utilise la File System Access API pour laisser l'utilisateur choisir
/// precisement le fichier/dossier de destination.
///
/// Si [extraFiles] est fourni (en plus de [bytesBuilder]/[fileName]), un
/// unique dossier est demande via `showDirectoryPicker` et tous les fichiers y
/// sont ecrits en une seule fois. Sinon, `showSaveFilePicker` est utilise pour
/// un unique fichier.
///
/// Retourne [WebSaveOutcome.unsupported] si le navigateur ne supporte pas
/// l'API (Firefox, Safari...), auquel cas l'appelant doit se rabattre sur
/// un telechargement classique.
Future<WebSaveOutcome> saveWithFileSystemAccess(
  WebBytesBuilder bytesBuilder,
  String fileName, {
  List<WebFileEntry>? extraFiles,
}) async {
  final global = globalContext;

  if (extraFiles != null && extraFiles.isNotEmpty) {
    return _saveManyToDirectory(global, [
      (bytesBuilder, fileName),
      ...extraFiles,
    ]);
  }

  if (!global.has('showSaveFilePicker')) {
    return WebSaveOutcome.unsupported;
  }

  try {
    final options = JSObject()
      ..setProperty('suggestedName'.toJS, fileName.toJS);

    final handle = await (global.callMethod<JSObject>(
      'showSaveFilePicker'.toJS,
      options,
    ) as JSPromise<JSObject>).toDart;

    final chosenPath = handle.getProperty<JSString>('name'.toJS).toDart;
    final bytes = await bytesBuilder(chosenPath);
    await _writeToFileHandle(handle, bytes);

    return WebSaveOutcome.saved;
  } catch (e) {
    // L'utilisateur annule la boite de dialogue -> DOMException "AbortError".
    if (e.toString().toLowerCase().contains('abort')) {
      return WebSaveOutcome.cancelled;
    }
    rethrow;
  }
}

Future<WebSaveOutcome> _saveManyToDirectory(
  JSObject global,
  List<WebFileEntry> files,
) async {
  if (!global.has('showDirectoryPicker')) {
    return WebSaveOutcome.unsupported;
  }

  try {
    final dirHandle = await (global.callMethod<JSObject>(
      'showDirectoryPicker'.toJS,
    ) as JSPromise<JSObject>).toDart;

    final dirName = dirHandle.getProperty<JSString>('name'.toJS).toDart;

    for (final (bytesBuilder, fileName) in files) {
      final fileOptions = JSObject()..setProperty('create'.toJS, true.toJS);
      final fileHandle = await (dirHandle.callMethod<JSObject>(
        'getFileHandle'.toJS,
        fileName.toJS,
        fileOptions,
      ) as JSPromise<JSObject>).toDart;

      final bytes = await bytesBuilder(dirName);
      await _writeToFileHandle(fileHandle, bytes);
    }

    return WebSaveOutcome.saved;
  } catch (e) {
    if (e.toString().toLowerCase().contains('abort')) {
      return WebSaveOutcome.cancelled;
    }
    rethrow;
  }
}

Future<void> _writeToFileHandle(JSObject fileHandle, Uint8List bytes) async {
  final writable = await (fileHandle.callMethod<JSObject>(
    'createWritable'.toJS,
  ) as JSPromise<JSObject>).toDart;

  await (writable.callMethod<JSObject?>(
    'write'.toJS,
    bytes.toJS,
  ) as JSPromise<JSAny?>).toDart;

  await (writable.callMethod<JSObject?>(
    'close'.toJS,
  ) as JSPromise<JSAny?>).toDart;
}
