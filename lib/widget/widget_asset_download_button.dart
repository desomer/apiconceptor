import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:jsonschema/widget/asset_download/dir_save.dart';
import 'package:jsonschema/widget/asset_download/web_save.dart';

/// Un asset supplementaire a telecharger en meme temps que l'asset principal.
class AssetFileSpec {
  const AssetFileSpec({required this.contentBuilder, required this.fileName});

  /// Builder du contenu de l'asset. Le parametre est le chemin propose pour le fichier.
  final Future<Uint8List> Function(String) contentBuilder;

  /// Nom de fichier propose lors de l'enregistrement.
  final String fileName;
}

/// Bouton permettant de telecharger un fichier d'asset embarque dans l'app.
///
/// Sur desktop, une boite de dialogue "enregistrer sous" laisse l'utilisateur
/// choisir le dossier (et le nom) de destination. Sur le Web, cela declenche
/// le telechargement du fichier via le navigateur.
class WidgetAssetDownloadButton extends StatefulWidget {
  const WidgetAssetDownloadButton({
    super.key,
    required this.assetPath,
    required this.fileName,
    this.extraAssets = const [],
    this.label = 'Telecharger',
    this.icon = Icons.download,
    this.tooltip,
  });

  /// Chemin de l'asset tel que declare dans pubspec.yaml, ex: "assets/vendor/foo.zip".
  final String assetPath;

  /// Nom de fichier propose lors de l'enregistrement.
  final String fileName;

  /// Assets additionnels a telecharger simultanement dans le meme dossier.
  final List<AssetFileSpec> extraAssets;

  final String label;
  final IconData icon;
  final String? tooltip;

  @override
  State<WidgetAssetDownloadButton> createState() =>
      _WidgetAssetDownloadButtonState();
}

class _WidgetAssetDownloadButtonState extends State<WidgetAssetDownloadButton> {
  bool _isDownloading = false;

  Future<void> _download() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      Future<Uint8List> loadAsset(String assetPath) async {
        final data = await rootBundle.load(assetPath);
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      }

      // Le path/nom choisi par l'utilisateur n'est pas utilise ici : le
      // contenu de l'asset ne depend pas de la destination.
      Future<Uint8List> mainBytesBuilder(String _) =>
          loadAsset(widget.assetPath);

      final extraEntries = <WebFileEntry>[
        for (final extra in widget.extraAssets)
          (
            (String path) async {
              return extra.contentBuilder(path);
            },
            extra.fileName,
          ),
      ];

      if (kIsWeb) {
        // Chrome/Edge: laisse l'utilisateur choisir le fichier/dossier de destination.
        final outcome = await saveWithFileSystemAccess(
          mainBytesBuilder,
          widget.fileName,
          extraFiles: extraEntries.isEmpty ? null : extraEntries,
        );
        if (outcome == WebSaveOutcome.cancelled) {
          return; // annule par l'utilisateur
        }
        if (outcome == WebSaveOutcome.saved) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fichier telecharge : ${widget.fileName}')),
          );
          return;
        }
        // WebSaveOutcome.unsupported (Firefox/Safari) -> repli ci-dessous.
      }

      if (extraEntries.isNotEmpty) {
        final dirPath = await saveFilesToDirectory([
          (mainBytesBuilder, widget.fileName),
          ...extraEntries,
        ], dialogTitle: 'Choisir le dossier de destination');
        if (!mounted) return;
        if (dirPath == null) {
          return; // annule par l'utilisateur
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fichiers telecharges dans : $dirPath')),
        );
        return;
      }

      final bytes = await mainBytesBuilder(widget.fileName);
      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Enregistrer ${widget.fileName}',
        fileName: widget.fileName,
        bytes: bytes,
      );

      if (!mounted) return;
      if (savedPath == null) {
        return; // annule par l'utilisateur
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fichier telecharge : ${widget.fileName}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Echec du telechargement : $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton.icon(
      onPressed: _isDownloading ? null : _download,
      icon: _isDownloading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(widget.icon),
      label: Text(widget.label),
    );

    if (widget.tooltip == null) return button;
    return Tooltip(message: widget.tooltip!, child: button);
  }
}
