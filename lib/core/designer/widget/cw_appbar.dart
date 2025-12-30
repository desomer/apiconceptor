// ignore_for_file: dead_code

import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/component/helper/helper_editor.dart';
import 'package:jsonschema/core/designer/core/widget_drag_utils.dart';
import 'package:jsonschema/core/designer/core/widget_overlay_selector.dart';
import 'package:jsonschema/core/designer/cw_factory.dart';
import 'package:jsonschema/core/designer/cw_factory_action.dart';
import 'package:jsonschema/core/designer/cw_slot.dart';
import 'package:jsonschema/core/designer/cw_widget.dart';

class CwAppBar extends CwWidget {
  const CwAppBar({super.key, required super.ctx});

  static void initFactory(WidgetFactory factory) {
    config(CwWidgetCtx ctx) {
      return CwWidgetConfig();
    }

    factory.register(
      id: 'appbar',
      build: (ctx) => CwAppBar(ctx: ctx),
      config: config,
    );
  }

  @override
  State<CwAppBar> createState() => _CwPageState();
}

class _CwPageState extends CwWidgetState<CwAppBar> with HelperEditor {
  void onAction(CwWidgetCtx ctx, DesignAction action) {
    String actionStr = '';

    switch (action) {
      case DesignAction.delete:
        actionStr = 'delete';
        break;
      case DesignAction.addLeft:
        actionStr = 'before';
        break;
      case DesignAction.addRight:
        actionStr = 'after';
        break;
      default:
    }

    var actMgr = CwFactoryAction(ctx: ctx);
    if (actionStr == 'delete') {
      // cannot delete appbar
      return;
    } else if (actionStr == 'before') {
      var slotFrom = 'actions';
      var slotTo = 'cell_1';
      actMgr.surround(slotFrom, slotTo, {
        cwType: 'container',
        cwProps: <String, dynamic>{
          'type': 'row',
          'flow': true,
          'noStretch': true,
          "#autoInsert": true,
          "#autoInsertAtStart": true,
          "crossAxisAlign": "center",
        },
      });
    } else if (actionStr == 'after') {
      var slotFrom = 'actions';
      var slotTo = 'cell_0';
      actMgr.surround(slotFrom, slotTo, {
        cwType: 'container',
        cwProps: <String, dynamic>{
          'type': 'row',
          'flow': true,
          'noStretch': true,
          "#autoInsert": true,
          "#autoInsertAtStart": true,
          "crossAxisAlign": "center",
        },
      });
    }
    setState(() {});
    ctx.selectParentOnDesigner();
  }

  @override
  Widget build(BuildContext context) {
    return buildWidget(false, (ctx, constraints) {
      void onDrop(CwWidgetCtx ctx, DropCtx drop) {
        var type = drop.childData![cwType];
        var cd = drop.childData!;
        if (type == 'action') {
          cd[cwProps]['type'] = 'icon';
          if (drop.forConfigOnly) {
            drop.forConfigOnly = false;
          } else {
            drop.childData = <String, dynamic>{
              cwType: 'container',
              cwProps: <String, dynamic>{
                'type': 'row',
                'flow': true,
                'noStretch': true,
                "#autoInsert": true,
                "#autoInsertAtStart": true,
                "crossAxisAlign": "center",
              },
            };
            ctx.aFactory.addInSlot(drop.childData!, 'cell_1', cd);
          }
        }
      }

      return AppBar(
        title: getSlot(CwSlotProp(id: 'title', name: 'app title')),
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 40),
                child: getSlot(
                  CwSlotProp(
                    id: 'actions',
                    name: 'actions',
                    onAction: onAction,
                    onDrop: onDrop,
                  ),
                ),
              ),
            ],
          ),
          // getSlot(
          //   CwSlotProp(id: 'actions', name: 'actions', onAction: onAction),
          // ),
        ],
      );
    });
  }
}
