import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/component/helper/helper_editor.dart';
import 'package:jsonschema/core/designer/component/prop_editor/generic_editor.dart';

class SliderEditor extends GenericEditor {
  const SliderEditor({
    super.key,
    required super.json,
    required super.onJsonChanged,
    required super.config,
  });

  @override
  State<SliderEditor> createState() => _SlideEditorState();
}

class _SlideEditorState extends State<SliderEditor> with HelperEditor {
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
    // slider avec label + title
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(5, 5, 5, 0),
          child: Text(widget.config.name),
        ),
        Slider(
          value: double.tryParse(controller.text) ?? 0.0,
          min: 0.0,
          max: 100.0,
          divisions: 10,
          label: controller.text,
          onChanged: (double value) {
            setState(() {
              controller.text = value.toStringAsFixed(0);
            });
          },
        ),
      ],
    );
  }
}
