import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/core/widget_catalog/cw_mask_helper.dart';
import 'package:jsonschema/core/designer/editor/view/prop_editor/helper_editor.dart';
import 'package:jsonschema/core/designer/editor/view/prop_editor/generic_editor.dart';

class TextEditor extends GenericEditor {
  const TextEditor({
    super.key,
    required super.json,
    required super.onJsonChanged,
    required super.config,
    required this.info,
  });

  final TextfieldBuilderInfo info;

  @override
  State<TextEditor> createState() => _TextEditorState();
}

class _TextEditorState extends State<TextEditor> with HelperEditor {
  late TextEditingController controller;
  FormatterTextfield formatter = FormatterTextfield();

  @override
  void initState() {
    super.initState();
    formatter.initMaskAndValidatorInfo(widget.info);

    controller = TextEditingController(
      text: widget.json[widget.config.id]?.toString() ?? '',
    );

    // écoute les changements en direct
    controller.addListener(() {
      var v = controller.text;
      var unmaskedValue = widget.info.getUnmaskedValue(formatter, v);
      if (v.isEmpty || unmaskedValue == null) {
        widget.json.remove(widget.config.id);
      } else {
        widget.json[widget.config.id] = unmaskedValue;
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
    var buildCounter =
        widget.info.maxLength == null
            ? null
            : (
              context, {
              required currentLength,
              required isFocused,
              required maxLength,
            }) {
              return counterWidget(
                currentLength: currentLength,
                isFocused: isFocused,
                maxLength: maxLength,
              );
            };

    return TextField(
      controller: controller,
      decoration: getInputDecoration(
        widget.config.name,
        0,
        info: widget.info,
        deleteController: controller,
      ),

      maxLength: widget.info.maxLength,
      buildCounter: buildCounter,
      keyboardType: formatter.inputType,
      readOnly: !widget.info.editable,
      enabled: widget.info.enable,
      enableInteractiveSelection: widget.info.editable,
      // scrollPadding: const EdgeInsets.all(0),
      inputFormatters: formatter.formatters,
      autocorrect: false,
      textAlign: formatter.isNum ? TextAlign.right : TextAlign.start,
    );
  }
}

Widget? counterWidget({
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) {
  if (!isFocused) return null;

  return SizedBox(
    height: 10,
    child: OverflowBox(
      maxHeight: 20,
      maxWidth: 200,
      minHeight: 20,
      minWidth: 200,
      alignment: Alignment.topRight,
      child: Container(
        height: 20,
        width: 100,
        transform: Matrix4.translationValues(0, -5, 0),
        child: Text(
          textAlign: TextAlign.right,
          '$currentLength/$maxLength',
          style: TextStyle(fontSize: 10.0),
        ),
      ),
    ),
  );
}
