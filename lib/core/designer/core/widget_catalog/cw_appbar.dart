// ignore_for_file: dead_code

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jsonschema/core/designer/editor/view/prop_editor/helper_editor.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_drag_utils.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_overlay_selector.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/core/cw_factory_action.dart';
import 'package:jsonschema/core/designer/core/cw_slot.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';

class CwAppBar extends CwWidget {
  const CwAppBar({super.key, required super.ctx});

  static void initFactory(WidgetFactory factory) {
    config(CwWidgetCtx ctx) {
      return CwWidgetConfig().addProp(
        CwWidgetProperties(id: 'bottomBar', name: 'bottom Navigation Bar')
          ..isBool(
            ctx,
            onJsonChanged: (value) {
              ctx.onValueChange(repaint: true)(value);
              SchedulerBinding.instance.addPostFrameCallback((_) {
                ctx.parentCtx!.repaint();
              });
            },
          ),
      );
    }

    factory.register(
      id: 'appbar',
      build: (ctx) => CwAppBar(key: ctx.getKey(), ctx: ctx),
      config: config,
    );
  }

  @override
  State<CwAppBar> createState() => _CwPageState();
}

class _CwPageState extends CwWidgetState<CwAppBar> with HelperEditor {
  void onAction1(CwWidgetCtx ctx, DesignAction action) {
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
        cwImplement: 'container',
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
        cwImplement: 'container',
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

  void onAction2(CwWidgetCtx ctx, DesignAction action) {
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
      var slotFrom = 'title';
      var slotTo = 'cell_1';
      actMgr.surround(slotFrom, slotTo, {
        cwImplement: 'container',
        cwProps: <String, dynamic>{
          'type': 'row',
          'flow': true,
          'noStretch': true,
          "#autoInsert": true,
          "crossAxisAlign": "center",
        },
      });
    } else if (actionStr == 'after') {
      var slotFrom = 'title';
      var slotTo = 'cell_0';
      actMgr.surround(slotFrom, slotTo, {
        cwImplement: 'container',
        cwProps: <String, dynamic>{
          'type': 'row',
          'flow': true,
          'noStretch': true,
          "#autoInsert": true,
          "crossAxisAlign": "center",
        },
      });
    }
    setState(() {});
    ctx.selectParentOnDesigner();
  }

  @override
  Widget build(BuildContext context) {
    return buildWidget(false, ModeBuilderWidget.noConstraint, (
      ctx,
      constraints,
    ) {
      void onDrop(CwWidgetCtx ctx, DropCtx drop) {
        var type = drop.childData![cwImplement];
        var cd = drop.childData!;
        if (type == 'action') {
          cd[cwProps]['type'] = 'icon';
          if (drop.forConfigOnly) {
            drop.forConfigOnly = false;
          } else {
            drop.childData = <String, dynamic>{
              cwImplement: 'container',
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

      bool bottomBar = getBoolProp(ctx, 'bottomBar') ?? false;
      ctx.dataWidget?[cwProps]?['#heightOfSlot'] =
          bottomBar ? (kToolbarHeight + 36) : kToolbarHeight;

      Color? bgColor = HelperEditor.getColorProp(widget.ctx, 'bgColor', [
        cwStyle,
      ]);
      Color? fgColor = HelperEditor.getColorProp(widget.ctx, 'fgColor', [
        cwStyle,
      ]);
      var elevation = styleFactory.getElevation();

      var appbar = AppBar(
        elevation: elevation,
        backgroundColor: bgColor,
        foregroundColor: fgColor,
        title: getSlot(
          CwSlotProp(id: 'title', name: 'app title', onAction: onAction2),
        ),
        bottom:
            bottomBar
                ? getSlot(
                  CwSlotProp(
                    id: 'bottomBar',
                    name: 'bottom navigation bar',
                    type: 'appbarbottom',
                  ),
                )
                : null,
        actions: [
          // Row(
          //   mainAxisSize: MainAxisSize.min,
          //   children: [
          getSlot(
            CwSlotProp(
              id: 'actions',
              name: 'actions',
              onAction: onAction1,
              onDrop: onDrop,
            ),
          ),
        ],
        //         ),
        //       ],
      );
      if (elevation == null || elevation == 0) {
        return appbar;
      }
      return Material(
        elevation: elevation,
        //shadowColor: Colors.black26,
        child: appbar,
      );
    });
  }
}
