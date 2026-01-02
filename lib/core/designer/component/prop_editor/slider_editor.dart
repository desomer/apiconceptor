import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/component/helper/helper_editor.dart';
import 'package:jsonschema/core/designer/component/prop_editor/generic_editor.dart';

class SliderEditor extends GenericEditor {
  final int min;
  final int max;
  final IconData? icon;

  const SliderEditor({
    super.key,
    required super.json,
    required super.onJsonChanged,
    required super.config,
    required this.min,
    required this.max,
    this.icon,
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
        widget.json[widget.config.id] = int.tryParse(v);
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
    List<Widget> ret = [const SizedBox(width: 5)];
    if (widget.icon != null) {
      ret.addAll([Icon(widget.icon), const SizedBox(width: 5)]);
    }
    ret.addAll([
      Text(widget.config.name),
      const Spacer(),
      SizedBox(
        width: 100,
        child: Slider(
          padding: const EdgeInsets.fromLTRB(10, 10, 5, 5),
          value: double.tryParse(controller.text) ?? 0.0,
          min: widget.min.toDouble(),
          max: widget.max.toDouble(),
          divisions: 10,
          label: controller.text,
          onChanged: (double value) {
            setState(() {
              print(" slider changed: ${controller.hashCode} to $value");
              controller.text = value.toStringAsFixed(0);
            });
          },
        ),
      ),
      getTextEditable(45, true),
      const SizedBox(width: 5),
    ]);

    // slider avec label + title
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: ret,
    );
  }

  Widget getTextEditable(double width, bool border) {
    return SizedBox(
      width: width,
      child: TextField(
        decoration: InputDecoration(
          border: border ? const OutlineInputBorder() : InputBorder.none,
          isDense: true,
          contentPadding:
              border
                  ? const EdgeInsets.fromLTRB(5, 5, 5, 5)
                  : const EdgeInsets.fromLTRB(5, 0, 5, 0),
        ),
        controller: controller,
      ),
    );
  }
}
