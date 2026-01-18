import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/editor/view/prop_editor/helper_editor.dart';
import 'package:jsonschema/core/designer/editor/view/prop_editor/generic_editor.dart';

class BoolEditor extends GenericEditor {
  const BoolEditor({
    super.key,
    required super.json,
    required super.onJsonChanged,
    required super.config,
  });

  @override
  State<BoolEditor> createState() => _BoolEditorState();
}

class _BoolEditorState extends State<BoolEditor> with HelperEditor {
  late TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(
      text: widget.json[widget.config.id]?.toString() ?? 'false',
    );

    // écoute les changements en direct
    controller.addListener(() {
      bool value = controller.text.toLowerCase() == 'true' ? true : false;
      widget.json[widget.config.id] = value;
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
    return SwitchListTile(
      contentPadding: const EdgeInsets.fromLTRB(5, 1, 5, 0),
      dense: true,
      title: Text(widget.config.name),
      // This bool value toggles the switch.
      value: controller.text.toLowerCase() == 'true',
      onChanged: (v) {
        setState(() {
          controller.text = v.toString();
          if (v == false) {
            widget.json.remove(widget.config.id);
          } else {
            widget.json[widget.config.id] = v;
          }
        });
      },
    );
  }
}
