import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/editor/view/prop_editor/helper_editor.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';

class CwDivider extends CwWidget {
  const CwDivider({super.key, required super.ctx});

  static void initFactory(WidgetFactory factory) {
    factory.register(
      id: 'divider',
      build: (ctx) => CwDivider(key: ctx.getKey(), ctx: ctx),
      config: (ctx) {
        return CwWidgetConfig()
            .addProp(
              CwWidgetProperties(id: 'type', name: 'view type')..isToogle(ctx, [
                {'icon': Icons.horizontal_rule, 'value': 'divider'},
                {'icon': Icons.settings_ethernet, 'value': 'spacer'},
              ], defaultValue: 'divider'),
            )
            .addProp(
              CwWidgetProperties(id: 'label', name: 'label')..isText(ctx),
            );
      },
    );
  }

  @override
  State<CwDivider> createState() => _CwTabBarState();
}

class _CwTabBarState extends CwWidgetState<CwDivider> with HelperEditor {
  @override
  Widget build(BuildContext context) {
    return buildWidget(true, ModeBuilderWidget.constraintBuilder, (ctx, constraints) {
      double height = 1;
      var label = getStringProp(ctx, 'label');
      var spacer = getStringProp(ctx, 'type') == 'spacer';
      if (spacer) {
        return getSizeDesignBox(const Spacer());
      } else {
        return label != null
            ? getDividerWithLabel(height, label)
            : getSizeDesignBox(Divider(height: height));
      }
    });
  }

  Widget getSizeDesignBox(Widget design) {
    if (widget.ctx.aFactory.isModeViewer()) return design;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 20, minWidth: 20),
      child: design,
    );
  }

  Row getDividerWithLabel(double height, String label) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(left: 10.0, right: 15.0),
            child: Divider(color: Colors.black, height: height),
          ),
        ),
        Text(label),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(left: 15.0, right: 10.0),
            child: Divider(color: Colors.black, height: height),
          ),
        ),
      ],
    );
  }
}
