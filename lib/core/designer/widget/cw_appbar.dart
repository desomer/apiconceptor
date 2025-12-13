// ignore_for_file: dead_code

import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/component/helper/helper_editor.dart';
import 'package:jsonschema/core/designer/cw_factory.dart';
import 'package:jsonschema/core/designer/cw_slot.dart';
import 'package:jsonschema/core/designer/cw_widget.dart';

class CwAppBar extends CwWidget {
  const CwAppBar({super.key, required super.ctx});

  static void initFactory(WidgetFactory factory) {
    factory.builderWidget['appbar'] = (ctx) {
      return CwAppBar(ctx: ctx);
    };

    factory.builderConfig['appbar'] = (ctx) {
      return CwWidgetConfig(id: "appbar")
          .addProp(
            CwWidgetProperties(id: 'drawer', name: 'with drawer')..isBool(
              ctx,
              onJsonChanged: (value) {
                ctx.onValueChange(repaint: false)(value);
                ctx.parentCtx!.onValueChange()(value);
              },
            ),
          )
          .addProp(
            CwWidgetProperties(id: 'fixDrawer', name: 'fix drawer on desktop')..isBool(
              ctx,
              onJsonChanged: (value) {
                ctx.onValueChange(repaint: false)(value);
                ctx.parentCtx!.onValueChange()(value);
              },
            ),
          );
    };
  }

  @override
  State<CwAppBar> createState() => _CwPageState();
}

class _CwPageState extends CwWidgetState<CwAppBar> with HelperEditor {
  @override
  Widget build(BuildContext context) {
    return buildWidget((ctx) {
      return AppBar(
        title: getSlot(CwSlotProp(id: 'title', name: 'app title')),
        actions: [getSlot(CwSlotProp(id: 'actions', name: 'actions'))],
      );
    });
  }
}
