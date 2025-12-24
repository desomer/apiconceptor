import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/component/helper/helper_editor.dart';
import 'package:jsonschema/core/designer/cw_factory.dart';
import 'package:jsonschema/core/designer/cw_widget.dart';

class CwInput extends CwWidget {
  const CwInput({super.key, required super.ctx});

  @override
  State<CwInput> createState() => _CwInputState();

  static void initFactory(WidgetFactory factory) {
    factory.register(
      id: 'input',
      build: (ctx) => CwInput(ctx: ctx),
      config: (ctx) {
        return CwWidgetConfig()
            .addProp(
              CwWidgetProperties(id: 'style', name: 'style')..isToogle(ctx, [
                {'icon': Icons.label, 'value': 'label'},
                {'icon': Icons.text_fields, 'value': 'textfield'},
                {'icon': Icons.check_box, 'value': 'checkbox'},
              ], defaultValue: 'label'),
            )
            .addProp(
              CwWidgetProperties(id: 'label', name: 'label')..isText(ctx),
            );
      },
      drag: (ctx, drag) {
        drag.childData![cwProps]['label'] = 'Title';
      },
    );
  }
}

class _CwInputState extends CwWidgetState<CwInput> with HelperEditor {
  @override
  Widget build(BuildContext context) {
    return buildWidget(false, (ctx, constraints) {
      String style = getStringProp(widget.ctx, 'style') ?? 'label';

      if (style == 'textfield') {
        return TextField(
          decoration: InputDecoration(
            labelText: getStringProp(widget.ctx, 'label') ?? '',
            border: OutlineInputBorder(),
          ),
        );
      } else if (style == 'checkbox') {
        return Row(
          spacing: 8,
          children: [
            Text(getStringProp(widget.ctx, 'label') ?? ''),
            Checkbox(value: false, onChanged: (value) {}),
          ],
        );
      } else {
        return Text(getStringProp(widget.ctx, 'label') ?? '');
      }
    });
  }
}
