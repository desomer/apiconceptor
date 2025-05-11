import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:highlight/highlight_core.dart';
import 'package:jsonschema/widget/widget_error_banner.dart';

class TextEditor extends StatefulWidget {
  const TextEditor({super.key, required this.config, required this.header});
  final TextConfig config;
  final String header;

  @override
  State<TextEditor> createState() => _TextEditorState();
}

class _TextEditorState extends State<TextEditor> {
  late CodeController controller;
  late ScrollController c;

  @override
  void initState() {
    widget.config.state = this;
    controller = CodeController(
      language: widget.config.mode,
    );
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
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Icon(Icons.help_outline, size: 20),
              ),
            ],
          ),
        ),
        Expanded(
          child: CodeTheme(
            data: CodeThemeData(styles: monokaiSublimeTheme),
            child: Scrollbar(
              controller: c,
              thumbVisibility: true,
              trackVisibility: true,
              child: SingleChildScrollView(
                controller: c,
                child: CodeField(
                  controller: controller,
                  expands: false,
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

class TextConfig {
  TextConfig({
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
  late State state;

  doRebind() {
    // ignore: invalid_use_of_protected_member
    state.setState(() {});
  }
}
