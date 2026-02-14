import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/editor/view/prop_editor/helper_editor.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';

class CwIndicator extends CwWidget {
  const CwIndicator({
    super.key,
    required super.ctx,
    required super.cacheWidget,
  });

  static void initFactory(WidgetFactory factory) {
    factory.register(
      id: 'indicator',
      build:
          (ctx) => CwIndicator(
            key: ctx.getKey(),
            ctx: ctx,
            cacheWidget: CachedWidget(),
          ),
      config: (ctx) {
        return CwWidgetConfig()
        // .addProp(
        //   CwWidgetProperties(id: 'type', name: 'view type')..isToogle(ctx, [
        //     {'icon': Icons.horizontal_rule, 'value': 'divider'},
        //     {'icon': Icons.settings_ethernet, 'value': 'spacer'},
        //   ], defaultValue: 'divider'),
        // )
        // .addProp(
        //   CwWidgetProperties(id: 'label', name: 'label')..isText(ctx),
        // )
        ;
      },
    );
  }

  @override
  State<CwIndicator> createState() => _CwIndicatorState();
}

class _CwIndicatorState extends CwWidgetState<CwIndicator> with HelperEditor {
  @override
  Widget build(BuildContext context) {
    return buildWidget(true, ModeBuilderWidget.constraintBuilder, (
      ctx,
      constraints,
      _,
    ) {
      return Icon(Icons.abc);
    });
  }
}
