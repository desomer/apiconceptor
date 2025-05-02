import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:highlight/languages/yaml.dart';
import 'package:jsonschema/widget_error_banner.dart';

class YamlEditor extends StatefulWidget {
  const YamlEditor({super.key, required this.config});
  final YamlConfig config;

  @override
  State<YamlEditor> createState() => _YamlEditorState();
}

class _YamlEditorState extends State<YamlEditor> {
  late CodeController controller;
  late ScrollController c;

  @override
  void initState() {
    controller = CodeController(text: widget.config.getYaml(), language: yaml);
    c = ScrollController();
    controller.addListener(() {
      if (dispatch) {
        widget.config.onChange(controller.fullText, widget.config);
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    c.dispose();
    controller.dispose();
    super.dispose();
  }

  bool dispatch = true;

  @override
  Widget build(BuildContext context) {
    // dispatch = false;
    // controller.text = widget.config.getYaml();
    // dispatch = true;
    return Column(
      children: [
        Expanded(
          child: CodeTheme(
            data: CodeThemeData(styles: monokaiSublimeTheme),
            child: Scrollbar(
              controller: c,
              thumbVisibility: true,
              trackVisibility: true,
              child: SingleChildScrollView(
                controller: c,
                child: CodeField(controller: controller, expands: false),
              ),
            ),
          ),
        ),
        WidgetErrorBanner(error: widget.config.notifError),
      ],
    );
  }
}

class YamlConfig {
  late Function onChange;
  late Function getYaml;
  late ValueNotifier<String> notifError;
}
