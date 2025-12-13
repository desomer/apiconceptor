import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/component/helper/helper_editor.dart';
import 'package:jsonschema/core/designer/component/prop_editor/generic_editor.dart';

class TextEditor extends GenericEditor {
  const TextEditor({
    super.key,
    required super.json,
    required super.onJsonChanged,
    required super.config,
  });

  @override
  State<TextEditor> createState() => _TextEditorState();
}

class _TextEditorState extends State<TextEditor> with HelperEditor {
  late TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(
      text: widget.json[widget.config.id]?.toString() ?? '',
    );

    // écoute les changements en direct
    controller.addListener(() {
      var v = controller.text;
      if (v.isEmpty) {
        widget.json.remove(widget.config.id);
      } else {
        widget.json[widget.config.id] = v;
      }
      widget.onJsonChanged?.call(widget.json);
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: getInputDecoration(widget.config.name, 0),
    );
  }
}
