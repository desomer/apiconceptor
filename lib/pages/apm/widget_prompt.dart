import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:jsonschema/core/api/caller_api.dart';
import 'package:markdown_widget/markdown_widget.dart';

class PromptItem {
  const PromptItem({
    required this.name,
    required this.markdownKownledge,
    required this.markdownBuild,
    required this.isSelectable,
    required this.fileName,
  });

  final String name;
  final String markdownKownledge;
  final String markdownBuild;
  final bool isSelectable;
  final String fileName;
}

class WidgetPrompt extends StatefulWidget {
  const WidgetPrompt({super.key, required this.listPrompt});

  final List<PromptItem> listPrompt;

  @override
  State<WidgetPrompt> createState() => _WidgetPromptState();
}

class _WidgetPromptState extends State<WidgetPrompt> {
  @override
  void initState() {
    super.initState();
    items = widget.listPrompt;

    checked = List<bool>.filled(items.length, false);
    selectedIndex = 0;
  }

  late List<PromptItem> items;
  late List<bool> checked;
  late int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 320,
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isSelected = index == selectedIndex;

                    return CheckboxListTile(
                      value: checked[index],
                      onChanged: item.isSelectable
                          ? (value) {
                              setState(() {
                                checked[index] = value ?? false;
                              });
                            }
                          : null,
                      title: InkWell(
                        onTap: () {
                          setState(() {
                            selectedIndex = index;
                          });
                        },
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: item.isSelectable
                                ? null
                                : Theme.of(context).disabledColor,
                          ),
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () async {
                  // recuperer les prompts selectionnés et les copier dans le clipboard
                  String dateSortable = DateFormat(
                    'yyMMdd-HHmm',
                  ).format(DateTime.now());

                  int idxPrompt = 0;
                  for (int i = 0; i < items.length; i++) {
                    if (checked[i]) {
                      final cancelToken = CancelToken();

                      if (items[i].markdownKownledge.isNotEmpty) {
                        var ret2 = await CallerApi()
                            .sendApi('POST', "http://127.0.0.1:3128/pushfile", {
                              "path": '/knowledge/${items[i].fileName}',
                              "content": items[i].markdownKownledge,
                            }, cancelToken);

                        print(
                          "ret pushfile: ${ret2.reponse?.statusCode} ; ${ret2.reponse?.data}",
                        );
                      }

                      var ret = await CallerApi().sendApi(
                        'POST',
                        "http://127.0.0.1:3128/pushfile",
                        {
                          "path":
                              '/prompts/${dateSortable}_${idxPrompt}_${items[i].fileName}',
                          "content": items[i].markdownBuild,
                        },
                        cancelToken,
                      );
                      print(
                        "ret pushfile: ${ret.reponse?.statusCode} ; ${ret.reponse?.data}",
                      );
                      idxPrompt++;
                    }
                  }

                  // ScaffoldMessenger.of(context).showSnackBar(
                  //   const SnackBar(content: Text('Upload prompts')),
                  // );

                  showDialog(
                    // ignore: use_build_context_synchronously
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('Upload prompts'),
                        content: const Text(maxLines: 5, '''
Les prompts selectionnés ont été uploadés.
Tu peux les retrouver dans le dossier /prompts du container apiarchitec.
Lance la commande pour l'Agent IA dans ta fenêtre CLI IA de ton projet.
Pour reduire les couts et limiter les hallucinations, ouvre un nouveau chat/contexte de l'agent IA.
'''),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Command for Agent copied in clipboard',
                                  ),
                                ),
                              );
                              Clipboard.setData(
                                const ClipboardData(
                                  text:
                                      'Execute directement le contenu des prompts du dossier /prompts. Déplace le fichier dans un dossier archive si terminé correctement.',
                                ),
                              );
                            },
                            child: const Text('Close + cmd in clipboard '),
                          ),
                        ],
                      );
                    },
                  );
                },
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('upload prompts'),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    items[selectedIndex].name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: items[selectedIndex].markdownBuild),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Detail copie dans le clipboard'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Copier'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: MarkdownWidget(
                    data: items[selectedIndex].markdownBuild,
                    config: MarkdownConfig.darkConfig,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
