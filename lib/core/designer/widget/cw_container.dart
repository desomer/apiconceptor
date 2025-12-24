import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/component/helper/helper_editor.dart';
import 'package:jsonschema/core/designer/core/widget_drag_utils.dart';
import 'package:jsonschema/core/designer/core/widget_overlay_selector.dart';
import 'package:jsonschema/core/designer/cw_factory.dart';
import 'package:jsonschema/core/designer/cw_factory_action.dart';
import 'package:jsonschema/core/designer/cw_slot.dart';
import 'package:jsonschema/core/designer/cw_widget.dart';

List listAxisCol = [
  {'icon': Icons.align_vertical_top, 'value': 'start'},
  {'icon': Icons.align_vertical_center, 'value': 'center'},
  {'icon': Icons.align_vertical_bottom, 'value': 'end'},
  {'icon': Icons.vertical_distribute_rounded, 'value': 'spaceAround'},
  {'icon': Icons.format_line_spacing_rounded, 'value': 'spaceBetween'},
  {'icon': Icons.vertical_distribute_rounded, 'value': 'spaceEvenly'},
];

List listCrossCol = [
  {'icon': Icons.align_horizontal_left, 'value': 'start'},
  {'icon': Icons.align_horizontal_center, 'value': 'center'},
  {'icon': Icons.align_horizontal_right, 'value': 'end'},
  {'icon': Icons.settings_ethernet, 'value': 'stretch'},
];

List listAxisRow = [
  {'icon': Icons.align_horizontal_left, 'value': 'start'},
  {'icon': Icons.align_horizontal_center, 'value': 'center'},
  {'icon': Icons.align_horizontal_right, 'value': 'end'},
  {'icon': Icons.horizontal_distribute, 'value': 'spaceAround'},
  {'icon': Icons.view_column_rounded, 'value': 'spaceBetween'},
  {'icon': Icons.horizontal_distribute, 'value': 'spaceEvenly'},
];

List listCrossRow = [
  {'icon': Icons.align_vertical_top, 'value': 'start'},
  {'icon': Icons.align_vertical_center, 'value': 'center'},
  {'icon': Icons.align_vertical_bottom, 'value': 'end'},
  {'icon': Icons.settings_ethernet, 'value': 'stretch', 'quarterTurns': 1},
  //{'icon': Icons.format_strikethrough, 'value': 'baseline'}
];

class CwContainer extends CwWidget with HelperEditor {
  const CwContainer({super.key, required super.ctx});

  @override
  State<CwContainer> createState() => _CwContainerState();

  static void initFactory(WidgetFactory factory) {
    factory.register(
      id: 'container',
      build: (ctx) => CwContainer(ctx: ctx),
      config: (ctx) {
        var horz = HelperEditor.getStringProp(ctx, 'style') == 'row';

        var ret = CwWidgetConfig()
            .addProp(
              CwWidgetProperties(id: 'style', name: 'style')..isToogle(ctx, [
                {'icon': Icons.table_rows_rounded, 'value': 'column'},
                {'icon': Icons.view_week, 'value': 'row'},
                //{'icon': Icons.grid_view, 'value': 'grid'},
              ], defaultValue: 'column'),
            )
            .addProp(
              CwWidgetProperties(id: 'layout', name: 'layout')..isToogle(ctx, [
                {
                  'icon': Icons.format_line_spacing,
                  'value': 'fill',
                  'quarterTurns': horz ? 3 : 0,
                },
                {
                  'icon': Icons.vertical_align_top,
                  'value': 'flow',
                  'quarterTurns': horz ? 3 : 0,
                },
                {'icon': Icons.list_alt_rounded, 'value': 'form'},
              ], defaultValue: 'fill'),
            );

        var noStretch = ctx.extraRenderingData?['noStretch'] == true;
        ret
            .addProp(
              CwWidgetProperties(id: 'mainAxisAlign', name: 'alignment')
                ..isToogle(
                  ctx,
                  horz ? listAxisRow : listAxisCol,
                  defaultValue: 'start',
                ),
            )
            .addProp(
              CwWidgetProperties(id: 'crossAxisAlign', name: 'cross align')
                ..isToogle(
                  ctx,
                  horz ? listCrossRow : listCrossCol,
                  defaultValue: noStretch ? 'start' : 'stretch',
                ),
            );

        return ret;
      },
    );
  }
}

class _CwContainerState extends CwWidgetState<CwContainer> with HelperEditor {
  CwWidgetConfig slotConfig(CwWidgetCtx ctx) {
    return CwWidgetConfig()
        .addProp(
          CwWidgetProperties(id: 'fit', name: 'fit')..isToogle(ctx, [
            {'icon': Icons.open_in_full, 'value': 'tight'},
            {'icon': Icons.close_fullscreen, 'value': 'inner'},
            {'icon': Icons.fit_screen, 'value': 'loose'},
          ], defaultValue: 'tight'),
        )
        .addProp(
          CwWidgetProperties(id: 'flex', name: 'flex ratio')..isInt(ctx),
        );
  }

  void onDropOnCell(CwWidgetCtx ctx, DropCtx drop) {
    if (drop.forConfigOnly) {
      return;
    }

    var type = drop.childData![cwType];

    if (type == 'input') {
      drop.childData![cwProps]['label'] = 'New Cell';
    } else if (type == 'container') {
      var horiz = drop.parentData![cwProps]?['style'] == 'row';
      if (!horiz && drop.childData?[cwProps]?['style'] == null) {
        // default is row si parent is column
        drop.childData![cwProps]['style'] = 'row';
      }
    }

    bool autoInsert = getBoolProp(ctx.parentCtx!, '#autoInsert') ?? false;
    if (ctx.parentCtx!.extraRenderingData?['autoInsert'] == true) {
      autoInsert = true;
    }
    if (autoInsert) {
      int nb = getIntProp(ctx.parentCtx!, 'nbchild') ?? 2;
      int nbFill = 0;
      for (var i = 0; i < nb; i++) {
        var slotData = ctx.parentCtx!.dataWidget![cwSlots]?['cell_$i'];
        if (slotData != null || ctx.id == 'cell_$i') {
          nbFill++;
        }
      }
      if (nbFill == nb) {
        var props = ctx.parentCtx!.initPropsIfNeeded();
        props['nbchild'] = nb + 1;
        bool autoInsertAtStart =
            getBoolProp(ctx.parentCtx!, '#autoInsertAtStart') ?? false;

        if (autoInsertAtStart) {
          drop.afterAdded = () {
            var actMgr = CwFactoryAction(ctx: ctx);
            actMgr.moveSlot(nb + 1, 0);
          };
        }
      }
    }
  }

  void onActionCell(CwWidgetCtx ctx, DesignAction action) {
    var props = ctx.parentCtx!.initPropsIfNeeded();
    var horiz = HelperEditor.getStringProp(ctx.parentCtx!, 'style') == 'row';

    String actionStr = '';
    if (horiz) {
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
        case DesignAction.addBottom:
          actionStr = 'surround';
          break;
        case DesignAction.addTop:
          actionStr = 'surround1';
          break;
        default:
      }
    } else {
      switch (action) {
        case DesignAction.delete:
          actionStr = 'delete';
          break;
        case DesignAction.addTop:
          actionStr = 'before';
          break;
        case DesignAction.addBottom:
          actionStr = 'after';
          break;
        case DesignAction.addRight:
          actionStr = 'surround';
          break;
        case DesignAction.addLeft:
          actionStr = 'surround1';
          break;
        default:
      }
    }

    int nb = getIntProp(ctx.parentCtx!, 'nbchild') ?? 2;
    int idx = int.parse(ctx.id.split('_').last);
    var actMgr = CwFactoryAction(ctx: ctx);

    switch (actionStr) {
      case "delete":
        props['nbchild'] = nb - 1;
        actMgr.deleteSlot(idx, nb);
        break;
      case 'surround':
        var slotFrom = 'cell_$idx';
        var slotTo = 'cell_0';
        actMgr.surround(slotFrom, slotTo, {
          cwType: 'container',
          cwProps: <String, dynamic>{'style': horiz ? 'column' : 'row'},
        });
        break;
      case 'surround1':
        var slotFrom = 'cell_$idx';
        var slotTo = 'cell_1';
        actMgr.surround(slotFrom, slotTo, {
          cwType: 'container',
          cwProps: <String, dynamic>{'style': horiz ? 'column' : 'row'},
        });
        break;
      case 'before':
        props['nbchild'] = nb + 1;
        actMgr.moveSlot(nb, idx);
        break;
      case "after":
        props['nbchild'] = nb + 1;
        actMgr.moveSlot(nb, idx + 1);
        break;
      default:
    }
    setState(() {});
    ctx.selectParent();
  }

  @override
  Widget build(BuildContext context) {
    return buildWidget(true, (ctx, constraints) {
      List<Widget> child = [];
      var horiz = getStringProp(ctx, 'style') == 'row';
      bool noStretch = getBoolProp(ctx, 'noStretch') ?? false;
      bool flow = getBoolProp(ctx, 'flow') ?? false;
      bool disableFlex = false;
      bool hasBoundedHeight = constraints?.hasBoundedHeight ?? true;
      bool hasBoundedWidth = constraints?.hasBoundedWidth ?? true;
      ctx.extraRenderingData ??= {};

      if (!hasBoundedHeight && horiz) {
        // pas de hauteur contrainte en horizontal => pas de stretch possible
        noStretch = true;
        ctx.extraRenderingData!['noStretch'] = true;
      }
      if (!hasBoundedWidth && !horiz) {
        // pas de largeur contrainte en vertical => pas de stretch possible
        noStretch = true;
        ctx.extraRenderingData!['noStretch'] = true;
      }
      if (!hasBoundedHeight && !horiz) {
        disableFlex = true;
        ctx.extraRenderingData!['disableFlex'] = true;
      }
      if (!hasBoundedWidth && horiz) {
        disableFlex = true;
        ctx.extraRenderingData!['disableFlex'] = true;
      }

      int nb = getIntProp(ctx, 'nbchild') ?? 2;
      var layout = getStringProp(ctx, 'layout');
      ['flow', 'form'].contains(layout) ? flow = true : null;
      if (['flow', 'form'].contains(layout)) {
        ctx.extraRenderingData ??= {};
        ctx.extraRenderingData!['autoInsert'] = true;
      }

      for (var i = 0; i < nb; i++) {
        var slot = getSlot(
          CwSlotProp(
            id: 'cell_$i',
            name: 'cell',
            slotConfig: slotConfig,
            onDrop: onDropOnCell,
            onAction: onActionCell,
          ),
        );
        var ctxSlot = slot.config.ctx.cloneForSlot();
        if (flow) {
          if (noStretch) {
            child.add(slot);
          } else {
            child.add(Flexible(flex: 0, fit: FlexFit.loose, child: slot));
          }
        } else {
          var fit = getStringProp(ctxSlot, 'fit');
          if (disableFlex) {
            fit = 'inner';
          }
          var flex = getIntProp(ctxSlot, 'flex');
          child.add(
            Flexible(
              flex: fit == 'inner' ? 0 : (flex ?? 1), // 1 par defaut
              fit: fit != 'loose' ? FlexFit.tight : FlexFit.loose,
              child: slot,
            ),
          );
        }
      }

      return Flex(
        spacing: layout == 'form' ? 8.0 : 0.0,
        direction: horiz ? Axis.horizontal : Axis.vertical,
        mainAxisSize: flow ? MainAxisSize.min : MainAxisSize.max,
        mainAxisAlignment: getMainAxisAlignment('mainAxisAlign'),
        crossAxisAlignment: getCrossAxisAlignment(noStretch, 'crossAxisAlign'),
        children: child,
      );
    });
  }

  MainAxisAlignment getMainAxisAlignment(String name) {
    String v = getStringProp(widget.ctx, name) ?? '';
    switch (v) {
      case 'start':
        return MainAxisAlignment.start;
      case 'end':
        return MainAxisAlignment.end;
      case 'center':
        return MainAxisAlignment.center;
      case 'spaceAround':
        return MainAxisAlignment.spaceAround;
      case 'spaceBetween':
        return MainAxisAlignment.spaceBetween;
      case 'spaceEvenly':
        return MainAxisAlignment.spaceEvenly;
      default:
        return MainAxisAlignment.start;
    }
  }

  CrossAxisAlignment getCrossAxisAlignment(bool noStretch, String name) {
    String v = getStringProp(widget.ctx, name) ?? '';
    switch (v) {
      case 'start':
        return CrossAxisAlignment.start;
      case 'end':
        return CrossAxisAlignment.end;
      case 'center':
        return CrossAxisAlignment.center;
      case 'stretch':
        if (noStretch) {
          return CrossAxisAlignment.center;
        }
        return CrossAxisAlignment.stretch;
      case 'baseline':
        return CrossAxisAlignment.baseline;
      default:
        if (noStretch) {
          return CrossAxisAlignment.center;
        }
        return CrossAxisAlignment.stretch;
    }
  }
}
