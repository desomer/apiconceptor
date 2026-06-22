import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

// Colors (same as in widget_miro_like.dart)
const Color colorTextPrimary = Color.fromARGB(255, 255, 255, 255);
const Color colorTextSecondary = Color.fromARGB(255, 230, 230, 230);
const Color colorTextError = Color.fromARGB(255, 244, 67, 54);

typedef OnExport = String Function();
typedef OnImport = void Function(Map<String, dynamic> decoded);

class ImportExportManager {
  final BuildContext context;
  final OnExport generateBoardJson;
  final OnImport importBoard;

  ImportExportManager({
    required this.context,
    required this.generateBoardJson,
    required this.importBoard,
  });

  Future<void> showExportDialog() async {
    final jsonText = generateBoardJson();
    if (!context.mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Export JSON'),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(child: SelectableText(jsonText)),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: jsonText));
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('JSON copie dans le presse-papiers'),
                  ),
                );
              },
              child: const Text('Copier'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> showImportDialog() async {
    final controller = TextEditingController();
    String? error;

    if (!context.mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Import JSON'),
              content: SizedBox(
                width: 640,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      minLines: 10,
                      maxLines: 18,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Collez le JSON ici',
                      ),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          error!,
                          style: const TextStyle(color: colorTextError),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () {
                    try {
                      final decoded = jsonDecode(controller.text);
                      if (decoded is! Map<String, dynamic>) {
                        throw const FormatException(
                          'Le JSON racine doit etre un objet',
                        );
                      }

                      importBoard(decoded);

                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Import JSON termine')),
                      );
                    } catch (e) {
                      setLocalState(() {
                        error = 'Import impossible: $e';
                      });
                    }
                  },
                  child: const Text('Importer'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
