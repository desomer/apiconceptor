import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jsonschema/core/api/caller_api.dart';
import 'package:markdown_widget/markdown_widget.dart';

class PromptItem {
  const PromptItem({
    required this.name,
    required this.markdown,
    required this.isSelectable,
    required this.fileName,
  });

  final String name;
  final String markdown;
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

                  for (int i = 0; i < items.length; i++) {
                    if (checked[i]) {
                      final cancelToken = CancelToken();
                      var ret = await CallerApi()
                          .sendApi('POST', "http://localhost:3128/pushfile", {
                            "path": '/prompts/${items[i].fileName}',
                            "content": items[i].markdown,
                          }, cancelToken);
                      print(
                        "ret pushfile: ${ret.reponse?.statusCode} ; ${ret.reponse?.data}",
                      );
                    }
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Upload prompts')),
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
                        ClipboardData(text: items[selectedIndex].markdown),
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
                    data: items[selectedIndex].markdown,
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
