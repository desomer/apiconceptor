import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/component/helper/helper_editor.dart';
import 'package:jsonschema/core/designer/core/widget_drag_utils.dart';
import 'package:jsonschema/core/designer/core/widget_event_bus.dart';
import 'package:jsonschema/core/designer/core/widget_overlay_selector.dart';
import 'package:jsonschema/core/designer/core/widget_selectable.dart';
import 'package:jsonschema/core/designer/cw_factory.dart';
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
  {'icon': Icons.settings_ethernet, 'value': 'stretch'},
  //{'icon': Icons.format_strikethrough, 'value': 'baseline'}
];

class CwContainer extends CwWidget with HelperEditor {
  const CwContainer({super.key, required super.ctx});

  @override
  State<CwContainer> createState() => _CwContainerState();

  static void initFactory(WidgetFactory factory) {
    factory.builderWidget['container'] = (ctx) {
      return CwContainer(ctx: ctx);
    };

    factory.builderConfig['container'] = (ctx) {
      var ret = CwWidgetConfig(id: 'container')
          .addProp(
            CwWidgetProperties(id: 'horiz', name: 'horizontal')..isBool(ctx),
          )
          .addProp(
            CwWidgetProperties(id: 'nbchild', name: 'nb child')..isInt(ctx),
          );

      var horz = HelperEditor.getBoolProp(ctx, 'horiz') ?? false;
      ret
          .addProp(
            CwWidgetProperties(id: 'mainAxisAlign', name: 'alignment')
              ..isToogle(ctx, horz ? listAxisRow : listAxisCol),
          )
          .addProp(
            CwWidgetProperties(id: 'crossAxisAlign', name: 'cross align')
              ..isToogle(ctx, horz ? listCrossRow : listCrossCol),
          );

      return ret;
    };
  }
}

class _CwContainerState extends CwWidgetState<CwContainer> with HelperEditor {
  CwWidgetConfig slotConfig(CwWidgetCtx ctx) {
    return CwWidgetConfig(id: 'cell')
        .addProp(
          CwWidgetProperties(id: 'fit', name: 'fit')..isToogle(ctx, [
            {'icon': Icons.close_fullscreen, 'value': 'inner'},
            {'icon': Icons.open_in_full, 'value': 'tight'},
            {'icon': Icons.fit_screen, 'value': 'loose'},
          ]),
        )
        .addProp(
          CwWidgetProperties(id: 'flex', name: 'flex')
            ..isInt(ctx, defaultValue: 0),
        );
  }

  void onDrop(CwWidgetCtx ctx, DropCtx drop) {
    var type = drop.childData![cwType];
    if (type == 'input') {
      drop.childData![cwProps]['label'] = 'New Cell';
    } else if (type == 'container') {
      var horiz = drop.parentData![cwProps]?['horiz'] ?? false;
      if (!horiz) {
        drop.childData![cwProps]['horiz'] = true;
      }
    }
  }

  void onAction(CwWidgetCtx ctx, DesignAction action) {
    print('onAction');
    var props = ctx.parentCtx!.initPropsIfNeeded();
    var horiz = props['horiz'] ?? false;

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
    // vertical
    switch (actionStr) {
      case "delete":
        for (var i = idx; i < nb - 1; i++) {
          var slotFrom = 'cell_${i + 1}';
          var slotTo = 'cell_$i';
          var dataFrom = ctx.parentCtx!.dataWidget![cwSlots]?[slotFrom];
          if (dataFrom != null) {
            dataFrom[cwId] = slotTo;
            ctx.parentCtx!.dataWidget![cwSlots]?[slotTo] = dataFrom;
            ctx.parentCtx!.dataWidget![cwSlots]?.remove(slotFrom);
          } else {
            ctx.parentCtx!.dataWidget![cwSlots]?.remove(slotTo);
          }
        }

        ctx.dataWidget?.remove(cwType);
        ctx.dataWidget?.remove(cwProps);
        props['nbchild'] = nb - 1;
        setState(() {});
        emit(
          CDDesignEvent.select,
          CWEventCtx()
            ..ctx = ctx.parentCtx
            ..id = ctx.parentCtx!.aPath
            ..keybox = ctx.parentCtx!.keyCapture,
        );
        break;

      case 'surround':
        surround(idx, 0, !horiz, ctx);
        setState(() {});
        selectParent(ctx);
        break;

      case 'surround1':
        surround(idx, 1, !horiz, ctx);
        setState(() {});
        selectParent(ctx);
        break;

      case 'before':
        props['nbchild'] = nb + 1;
        moveSlot(nb, idx, ctx);
        setState(() {});
        selectParent(ctx);
        break;
      case "after":
        props['nbchild'] = nb + 1;
        moveSlot(nb, idx + 1, ctx);
        setState(() {});
        selectParent(ctx);
        break;
      default:
    }
  }

  void surround(int idx, int idxDest, bool horiz, CwWidgetCtx ctx) {
    var slotFrom = 'cell_$idx';
    var slotTo = 'cell_$idxDest';
    var dataFrom = ctx.parentCtx!.dataWidget![cwSlots]?[slotFrom];
    dataFrom[cwId] = slotTo;
    var newContainer = ctx.aFactory.addInSlot(
      ctx.parentCtx!.dataWidget!,
      slotFrom,
      {
        cwType: 'container',
        cwProps: <String, dynamic>{'horiz': horiz},
      },
    );
    ctx.aFactory.addInSlot(newContainer, slotTo, dataFrom!);
  }

  void selectParent(CwWidgetCtx ctx) {
    emit(
      CDDesignEvent.select,
      CWEventCtx()
        ..ctx = ctx.parentCtx
        ..id = ctx.parentCtx!.aPath
        ..keybox = ctx.parentCtx!.keyCapture,
    );
  }

  void moveSlot(int nb, int idx, CwWidgetCtx ctx) {
    for (var i = nb - 1; i >= idx; i--) {
      var slotFrom = 'cell_$i';
      var slotTo = 'cell_${i + 1}';
      var dataFrom = ctx.parentCtx!.dataWidget![cwSlots]?[slotFrom];
      if (dataFrom != null) {
        dataFrom[cwId] = slotTo;
        ctx.parentCtx!.dataWidget![cwSlots]?[slotTo] = dataFrom;
        ctx.parentCtx!.dataWidget![cwSlots]?.remove(slotFrom);
      } else {
        ctx.parentCtx!.dataWidget![cwSlots]?.remove(slotTo);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return buildWidget((ctx) {
      List<Widget> child = [];
      int nb = getIntProp(ctx, 'nbchild') ?? 2;

      for (var i = 0; i < nb; i++) {
        var slot = getSlot(
          CwSlotProp(
            id: 'cell_$i',
            name: 'cell',
            slotConfig: slotConfig,
            onDrop: onDrop,
            onAction: onAction,
          ),
        );
        var ctxSlot = slot.config.ctx.cloneForSlot();
        var fit = getStringProp(ctxSlot, 'fit');
        var flex = getIntProp(ctxSlot, 'flex');
        child.add(
          Flexible(
            flex: fit == 'inner' ? 0 : (flex ?? 1),
            fit: fit != 'loose' ? FlexFit.tight : FlexFit.loose,
            child: slot,
          ),
        );
      }

      return Flex(
        //key: GlobalKey(),
        direction:
            getBoolProp(widget.ctx, 'horiz') ?? false
                ? Axis.horizontal
                : Axis.vertical,
        //mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: getMainAxisAlignment('mainAxisAlign'),
        crossAxisAlignment: getCrossAxisAlignment('crossAxisAlign'),
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

  CrossAxisAlignment getCrossAxisAlignment(String name) {
    String v = getStringProp(widget.ctx, name) ?? '';
    switch (v) {
      case 'start':
        return CrossAxisAlignment.start;
      case 'end':
        return CrossAxisAlignment.end;
      case 'center':
        return CrossAxisAlignment.center;
      case 'stretch':
        return CrossAxisAlignment.stretch;
      case 'baseline':
        return CrossAxisAlignment.baseline;
      default:
        return CrossAxisAlignment.stretch;
    }
  }
}
