import 'package:flutter/scheduler.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_overlay_selector.dart';
import 'package:jsonschema/core/designer/editor/view/prop_editor/helper_editor.dart';

class CwFactoryAction {
  final CwWidgetCtx ctx;

  CwFactoryAction({required this.ctx});

  void delete() {
    ctx.dataWidget?.remove(cwImplement);
    ctx.dataWidget?.remove(cwProps);
    ctx.parentCtx!.dataWidget![cwSlots]?.remove(ctx.slotId);
    ctx.selectorCtx.slotState?.widget.config.innerWidget = null;
    // ignore: invalid_use_of_protected_member
    ctx.selectorCtx.slotState?.setState(() {});
    ctx.selectOnDesigner();
  }

  void deleteSlot(String suffixSlot, int idx, int nbSlots) {
    ctx.dataWidget?.remove(cwImplement);
    ctx.dataWidget?.remove(cwProps);

    for (var i = idx; i < nbSlots; i++) {
      var slotFrom = '$suffixSlot${i + 1}';
      var slotTo = '$suffixSlot$i';
      var dataFrom = ctx.parentCtx!.dataWidget![cwSlots]?[slotFrom];
      if (dataFrom != null) {
        dataFrom[cwSlotId] = slotTo;
        ctx.parentCtx!.dataWidget![cwSlots]?[slotTo] = dataFrom;
        ctx.parentCtx!.dataWidget![cwSlots]?.remove(slotFrom);
      } else {
        ctx.parentCtx!.dataWidget![cwSlots]?.remove(slotTo);
      }
    }
  }

  void surround(String slotFrom, String slotTo, Map<String, dynamic> child) {
    var dataFrom = ctx.parentCtx!.dataWidget![cwSlots]?[slotFrom];
    dataFrom[cwSlotId] = slotTo;
    // remplace le slot
    var newContainer = ctx.aFactory.addInSlot(
      ctx.parentCtx!.dataWidget!,
      slotFrom,
      child,
    );
    ctx.aFactory.addInSlot(newContainer, slotTo, dataFrom!);
  }

  void moveSlot(String suffixSlot, int nb, int idx) {
    for (var i = nb - 1; i >= idx; i--) {
      var slotFrom = '$suffixSlot$i';
      var slotTo = '$suffixSlot${i + 1}';
      var dataFrom = ctx.parentCtx!.dataWidget![cwSlots]?[slotFrom];
      if (dataFrom != null) {
        dataFrom[cwSlotId] = slotTo;
        ctx.parentCtx!.dataWidget![cwSlots]?[slotTo] = dataFrom;
        ctx.parentCtx!.dataWidget![cwSlots]?.remove(slotFrom);
      } else {
        ctx.parentCtx!.dataWidget![cwSlots]?.remove(slotTo);
      }
    }
  }

  void swapSlot(String suffixSlot, int idx, int idx2) {
    var slotFrom = '$suffixSlot$idx';
    var slotTo = '$suffixSlot$idx2';
    var dataFrom = ctx.parentCtx!.dataWidget![cwSlots]?[slotFrom];
    var dataTo = ctx.parentCtx!.dataWidget![cwSlots]?[slotTo];
    if (dataFrom != null) {
      dataFrom[cwSlotId] = slotTo;
      ctx.parentCtx!.dataWidget![cwSlots]?[slotTo] = dataFrom;
    }
    if (dataTo != null) {
      dataTo[cwSlotId] = slotFrom;
      ctx.parentCtx!.dataWidget![cwSlots]?[slotFrom] = dataTo;
    }
    if (dataFrom == null) {
      ctx.parentCtx!.dataWidget![cwSlots]?.remove(slotTo);
    }
    if (dataTo == null) {
      ctx.parentCtx!.dataWidget![cwSlots]?.remove(slotFrom);
    }
  }
}

//-------------------------------------------------------------------------------
void onActionCellContainer(CwWidgetCtx ctx, DesignAction action) {
  var props = ctx.parentCtx!.initPropsIfNeeded();
  var horiz = HelperEditor.getStringProp(ctx.parentCtx!, 'type') == 'row';

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
      case DesignAction.moveRight:
        actionStr = 'moveBefore';
        break;
      case DesignAction.moveLeft:
        actionStr = 'moveAfter';
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
      case DesignAction.moveBottom:
        actionStr = 'moveAfter';
        break;
      case DesignAction.moveTop:
        actionStr = 'moveBefore';
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

  int nb = HelperEditor.getIntProp(ctx.parentCtx!, 'nbchild') ?? 2;
  int idx = int.parse(ctx.slotId.split('_').last);
  var actMgr = CwFactoryAction(ctx: ctx);

  switch (actionStr) {
    case "delete":
      props['nbchild'] = nb - 1;
      actMgr.deleteSlot('cell_', idx, nb);
      break;
    case 'surround':
      var slotFrom = 'cell_$idx';
      var slotTo = 'cell_0';
      actMgr.surround(slotFrom, slotTo, {
        cwImplement: 'container',
        cwProps: <String, dynamic>{'type': horiz ? 'column' : 'row'},
      });
      break;
    case 'surround1':
      var slotFrom = 'cell_$idx';
      var slotTo = 'cell_1';
      actMgr.surround(slotFrom, slotTo, {
        cwImplement: 'container',
        cwProps: <String, dynamic>{'type': horiz ? 'column' : 'row'},
      });
      break;
    case 'before':
      props['nbchild'] = nb + 1;
      actMgr.moveSlot('cell_', nb, idx);
      break;
    case "after":
      props['nbchild'] = nb + 1;
      actMgr.moveSlot('cell_', nb, idx + 1);
      break;
    case 'moveBefore':
      actMgr.swapSlot('cell_', idx, idx - 1);
      break;
    case "moveAfter":
      actMgr.swapSlot('cell_', idx, idx + 1);
      break;
    default:
  }
  SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
    ctx.parentCtx!.repaint();
    ctx.selectParentOnDesigner();
  });
}

//-------------------------------------------------------------------------------
void onActionCellBody(CwWidgetCtx ctx, DesignAction action) {
  var props = ctx.parentCtx!.initPropsIfNeeded();
  var horiz = HelperEditor.getStringProp(ctx, 'type') == 'row';

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
      case DesignAction.moveRight:
        actionStr = 'moveBefore';
        break;
      case DesignAction.moveLeft:
        actionStr = 'moveAfter';
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
      case DesignAction.moveBottom:
        actionStr = 'moveAfter';
        break;
      case DesignAction.moveTop:
        actionStr = 'moveBefore';
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

  switch (actionStr) {
    case "delete":
      // props['nbchild'] = nb - 1;
      // actMgr.deleteSlot('cell_', idx, nb);
      break;
    case 'surround':
      var slotFrom = 'body';
      var slotTo = 'cell_0';
      var actMgr = CwFactoryAction(ctx: ctx);
      actMgr.surround(slotFrom, slotTo, {
        cwImplement: 'container',
        cwProps: <String, dynamic>{'type': horiz ? 'column' : 'row'},
      });
      break;
    case 'surround1':
      var slotFrom = 'body';
      var slotTo = 'cell_1';
      var actMgr = CwFactoryAction(ctx: ctx);
      actMgr.surround(slotFrom, slotTo, {
        cwImplement: 'container',
        cwProps: <String, dynamic>{'type': horiz ? 'column' : 'row'},
      });
      break;
    case 'before':
      int nb = HelperEditor.getIntProp(ctx, 'nbchild') ?? 2;
      int idx = int.parse(ctx.slotId.split('_').lastOrNull ?? '0');
      var actMgr = CwFactoryAction(ctx: ctx);
      props['nbchild'] = nb + 1;
      actMgr.moveSlot('cell_', nb, idx);
      break;
    case "after":
      int nb = HelperEditor.getIntProp(ctx, 'nbchild') ?? 2;
      int idx = int.parse(ctx.slotId.split('_').lastOrNull ?? '0');
      var actMgr = CwFactoryAction(ctx: ctx);
      props['nbchild'] = nb + 1;
      actMgr.moveSlot('cell_', nb, idx + 1);
      break;
    // case 'moveBefore':
    //   actMgr.swapSlot('cell_', idx, idx - 1);
    //   break;
    // case "moveAfter":
    //   actMgr.swapSlot('cell_', idx, idx + 1);
    //   break;
    default:
  }
  SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
    ctx.parentCtx!.repaint();
    ctx.selectParentOnDesigner();
  });
}
