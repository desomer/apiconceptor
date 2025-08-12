import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:highlight/highlight_core.dart';
import 'package:jsonschema/core/yaml_browser.dart';
import 'package:jsonschema/widget/widget_error_banner.dart';
// ignore: implementation_imports
import 'package:flutter_code_editor/src/code_field/actions/tab.dart';
import 'package:yaml/yaml.dart';

class TextEditor extends StatefulWidget {
  const TextEditor({
    super.key,
    required this.config,
    required this.header,
    this.actions,
    this.onHelp,
    this.onSelection,
  });
  final YamlEditorConfig config;
  final String header;
  final List<Widget>? actions;
  final Function? onHelp;
  final Function? onSelection;

  @override
  State<TextEditor> createState() => TextEditorState();
}

class TabKeyAction2 extends Action<TabKeyIntent> {
  final CodeController controller;

  TabKeyAction2({required this.controller});

  @override
  Object? invoke(TabKeyIntent intent) {
    controller.indentSelection();
    return null;
  }
}

class TextEditorState extends State<TextEditor> {
  late CodeController controller;
  late ScrollController verticalScroll;
  late ScrollController horizontalScroll;

  @override
  void initState() {
    controller = CodeController(language: widget.config.mode);

    controller.actions[TabKeyIntent] = TabKeyAction2(controller: controller);

    controller.popupController.enabled = false;
    horizontalScroll = ScrollController();
    verticalScroll = ScrollController();
    controller.addListener(() {
      if (dispatch) {
        widget.config.onChange(controller.fullText, widget.config);
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    verticalScroll.dispose();
    horizontalScroll.dispose();
    controller.dispose();
    super.dispose();
  }

  bool dispatch = true;

  @override
  Widget build(BuildContext context) {
    widget.config.textYamlState = this;

    var aText = widget.config.getText();
    if (aText == null) {
      return Text('select model first');
    }
    if (aText != controller.fullText) {
      controller.fullText = aText;
    }

    // dispatch = false;
    // controller.text = widget.config.getYaml();
    // dispatch = true;
    return Column(
      children: [
        Container(
          color: Colors.grey.shade800,
          height: 25,
          width: double.infinity,
          child: Row(
            children: [
              Expanded(child: Center(child: Text(widget.header))),
              ...widget.actions ?? [],
              InkWell(
                onTap: () {
                  // if (widget.onHelp != null) widget.onHelp!(context);
                },
                child: const Icon(Icons.history, size: 20),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                child: InkWell(
                  onTap: () {
                    if (widget.onHelp != null) widget.onHelp!(context);
                  },
                  child: const Icon(Icons.help_outline, size: 20),
                ),
              ),
              if (widget.onSelection != null)
                InkWell(
                  child: Icon(Icons.double_arrow_sharp),
                  onTap: () {
                    //print(controller.selection);
                    var curPos = controller.selection.baseOffset;
                    YamlDocument doc = loadYamlDocument(controller.fullText);
                    YamlDoc docYaml = YamlDoc();
                    docYaml.doAnalyse(doc, controller.fullText);

                    String path = '';

                    for (var line in docYaml.listYamlLine) {
                      if (curPos > line.idxCharStart &&
                          curPos < line.idxCharStop) {
                        YamlLine? l = line;
                        while (l != null) {
                          if (path.isNotEmpty) {
                            path = '>$path';
                          }
                          path = '${l.name}$path';
                          l = l.parent;
                        }
                        path = 'root>$path';
                        widget.onSelection!(path);
                        break;
                      }
                    }
                  },
                ),
            ],
          ),
        ),
        Expanded(
          child: CodeTheme(
            data: CodeThemeData(styles: monokaiSublimeTheme),
            child: Scrollbar(
              controller: verticalScroll,
              thumbVisibility: true,
              trackVisibility: true,
              child: SingleChildScrollView(
                controller: verticalScroll,
                child: CodeField(
                  gutterStyle: const GutterStyle(
                    textStyle: TextStyle(height: 1.5),
                    margin: 0,
                    width: 80,
                    showErrors: true,
                    showFoldingHandles: true,
                    showLineNumbers: true,
                  ),
                  controller: controller,
                  readOnly: widget.config.readOnly,
                ),
              ),
            ),
          ),
        ),
        WidgetErrorBanner(error: widget.config.notifError),
      ],
    );
  }
}

class YamlEditorConfig {
  YamlEditorConfig({
    required this.mode,
    required this.getText,
    required this.onChange,
    required this.notifError,
    this.readOnly = false,
  });
  Mode mode;
  late Function onChange;
  late Function getText;
  late ValueNotifier<String> notifError;
  bool readOnly;

  TextEditorState? textYamlState;
  State? treeJsonState;

  void repaintYaml() {
    // ignore: invalid_use_of_protected_member
    textYamlState?.setState(() {});
  }
}
