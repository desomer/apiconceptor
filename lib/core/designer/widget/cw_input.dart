import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/component/helper/helper_editor.dart';
import 'package:jsonschema/core/designer/cw_factory.dart';
import 'package:jsonschema/core/designer/cw_widget.dart';

class CwInput extends CwWidget {
  const CwInput({super.key, required super.ctx});

  @override
  State<CwInput> createState() => _CwInputState();

  static void initFactory(WidgetFactory factory) {
    factory.builderWidget['input'] = (ctx) {
      return CwInput(ctx: ctx);
    };

    factory.builderConfig['input'] = (ctx) {
      return CwWidgetConfig(
        id: 'input',
      ).addProp(CwWidgetProperties(id: 'label', name: 'label')..isText(ctx));
    };

    factory.builderDragConfig['input'] = (ctx, drag) {
      drag.childData![cwProps]['label'] = 'Title';
    };
  }
}

class _CwInputState extends CwWidgetState<CwInput> with HelperEditor {
  @override
  Widget build(BuildContext context) {
    return buildWidget((ctx) {
      return Text(getStringProp(widget.ctx, 'label') ?? '');
    });
  }
}
