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
    ctx.selectorCtxIfDesign?.slotState?.widget.config.innerWidget = null;
    // ignore: invalid_use_of_protected_member
    ctx.selectorCtxIfDesign?.slotState?.setState(() {});
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

//------------------------------------------------------------------------------
void onActionCellTable(CwWidgetCtx ctx, DesignAction action) {
  var props = ctx.parentCtx!.initPropsIfNeeded();
  int nb = HelperEditor.getIntProp(ctx.parentCtx!, 'nbchild') ?? 0;
  int idx = int.parse(ctx.slotId.split('_').last);
  var actMgr = CwFactoryAction(ctx: ctx);
  var slotName = ctx.slotId.split('_').first;
  String? displaySelectorName;
  CwWidgetCtx? moveCtx;

  print('OnActionCell action=$action');
  switch (action) {
    case DesignAction.delete:
      props['nbchild'] = nb - 1;
      actMgr.deleteSlot('header_', idx, nb);
      actMgr.deleteSlot('cell_', idx, nb);
      if (nb - 1 > idx) {
        //le suivant prend la place
        displaySelectorName = '${slotName}_$idx';
      } else if (idx == nb - 1 && nb > 1) {
        //le precedent prend la place
        displaySelectorName = '${slotName}_${idx - 1}';
      } else {
        moveCtx = ctx.parentCtx!;
      }
      break;
    case DesignAction.addLeft:
      props['nbchild'] = nb + 1;
      actMgr.moveSlot('header_', nb, idx);
      actMgr.moveSlot('cell_', nb, idx);
      displaySelectorName = '${slotName}_$idx';
      break;
    case DesignAction.addRight:
      props['nbchild'] = nb + 1;
      actMgr.moveSlot('header_', nb, idx + 1);
      actMgr.moveSlot('cell_', nb, idx + 1);
      displaySelectorName = '${slotName}_${idx + 1}';
      break;
    case DesignAction.addBottom:
      int idx = int.parse(ctx.slotId.split('_').last);
      var actMgr = CwFactoryAction(ctx: ctx);
      var slotFrom = '${ctx.slotId.split('_').first}_$idx';
      var slotTo = 'cell_0';
      actMgr.surround(slotFrom, slotTo, {
        cwImplement: 'container',
        cwProps: <String, dynamic>{'type': 'column'},
      });
      break;
    case DesignAction.addTop:
      // var slotFrom = 'cell_$idx';
      // var slotTo = 'cell_1';
      // actMgr.surround(slotFrom, slotTo, {
      //   cwImplement: 'container',
      //   cwProps: <String, dynamic>{'type':'column'},
      // });
      break;
    case DesignAction.moveLeft:
      actMgr.swapSlot('header_', idx, idx - 1);
      actMgr.swapSlot('cell_', idx, idx - 1);
      displaySelectorName = '${slotName}_${idx - 1}';
      break;
    case DesignAction.moveRight:
      actMgr.swapSlot('header_', idx, idx + 1);
      actMgr.swapSlot('cell_', idx, idx + 1);
      displaySelectorName = '${slotName}_${idx + 1}';
      break;

    default:
  }
  ctx.parentCtx!.widgetState?.clearWidgetCache();
  SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
    ctx.repaint();
    ctx.parentCtx!.repaint();
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      if (displaySelectorName != null) {
        moveCtx = ctx.parentCtx!.childrenCtx?[displaySelectorName];
        // if (displaySelectorNameNext != null) {
        //   moveCtx = moveCtx?.childrenCtx?[displaySelectorNameNext];
        // }
      }
      (moveCtx ?? ctx).selectOnDesigner();
    });
  });
}

//-------------------------------------------------------------------------------
void onActionCellTab(CwWidgetCtx ctx, DesignAction action) {
  int nbCol = HelperEditor.getIntProp(ctx.parentCtx!, 'nbchild') ?? 1;
  var props = ctx.parentCtx!.initPropsIfNeeded();
  int idx = int.parse(ctx.slotId.split('_').last);
  var actMgr = CwFactoryAction(ctx: ctx);
  print('OnActionCell action=$action');
  switch (action) {
    case DesignAction.delete:
      break;
    case DesignAction.addLeft:
      props['nbchild'] = nbCol + 1;
      actMgr.moveSlot('tab_', nbCol, idx);
      actMgr.moveSlot('tabview_', nbCol, idx);
      break;
    case DesignAction.addRight:
      props['nbchild'] = nbCol + 1;
      actMgr.moveSlot('tab_', nbCol, idx + 1);
      actMgr.moveSlot('tabview_', nbCol, idx + 1);
      break;
    case DesignAction.addBottom:
      break;
    case DesignAction.addTop:
      break;
    default:
  }
  SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
    ctx.repaint();
    ctx.selectParentOnDesigner();
  });
}

//-------------------------------------------------------------------------------
const actionMapHorz = {
  DesignAction.delete: 'delete',
  DesignAction.addLeft: 'before',
  DesignAction.addRight: 'after',
  DesignAction.moveRight: 'moveAfter',
  DesignAction.moveLeft: 'moveBefore',
  DesignAction.addBottom: 'surround',
  DesignAction.addTop: 'surround1',
};

const actionMapVert = {
  DesignAction.delete: 'delete',
  DesignAction.addTop: 'before',
  DesignAction.addBottom: 'after',
  DesignAction.moveBottom: 'moveAfter',
  DesignAction.moveTop: 'moveBefore',
  DesignAction.addRight: 'surround',
  DesignAction.addLeft: 'surround1',
};

void onActionCellContainer(CwWidgetCtx ctx, DesignAction action) {
  var props = ctx.parentCtx!.initPropsIfNeeded();
  var horiz = HelperEditor.getStringProp(ctx.parentCtx!, 'type') == 'row';

  String? actionStr = horiz ? actionMapHorz[action] : actionMapVert[action];

  int nb = HelperEditor.getIntProp(ctx.parentCtx!, 'nbchild') ?? 2;
  int idx = int.parse(ctx.slotId.split('_').last);
  var actMgr = CwFactoryAction(ctx: ctx);
  var slotName = ctx.slotId.split('_').first;
  String? displaySelectorName;
  String? displaySelectorNameNext;
  CwWidgetCtx? moveCtx;

  switch (actionStr) {
    case "delete":
      props['nbchild'] = nb - 1;
      actMgr.deleteSlot('cell_', idx, nb);
      if (nb - 1 > idx) {
        //le suivant prend la place
        displaySelectorName = '${slotName}_$idx';
      } else if (idx == nb - 1 && nb > 1) {
        //le precedent prend la place
        displaySelectorName = '${slotName}_${idx - 1}';
      } else {
        moveCtx = ctx.parentCtx!;
      }
      break;
    case 'surround':
      var slotFrom = 'cell_$idx';
      var slotTo = 'cell_0';
      actMgr.surround(slotFrom, slotTo, {
        cwImplement: 'container',
        cwProps: <String, dynamic>{'type': horiz ? 'column' : 'row'},
      });
      displaySelectorName = '${slotName}_$idx';
      displaySelectorNameNext = 'cell_1';
      break;
    case 'surround1':
      var slotFrom = 'cell_$idx';
      var slotTo = 'cell_1';
      actMgr.surround(slotFrom, slotTo, {
        cwImplement: 'container',
        cwProps: <String, dynamic>{'type': horiz ? 'column' : 'row'},
      });
      displaySelectorName = '${slotName}_$idx';
      displaySelectorNameNext = 'cell_0';
      break;
    case 'before':
      props['nbchild'] = nb + 1;
      actMgr.moveSlot('cell_', nb, idx);
      displaySelectorName = '${slotName}_$idx';
      break;
    case "after":
      props['nbchild'] = nb + 1;
      actMgr.moveSlot('cell_', nb, idx + 1);
      displaySelectorName = '${slotName}_${idx + 1}';
      break;
    case 'moveBefore':
      actMgr.swapSlot('cell_', idx, idx - 1);
      displaySelectorName = '${slotName}_${idx - 1}';
      break;
    case "moveAfter":
      actMgr.swapSlot('cell_', idx, idx + 1);
      displaySelectorName = '${slotName}_${idx + 1}';
      break;
    default:
  }
  SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
    ctx.parentCtx!.repaint();
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      if (displaySelectorName != null) {
        moveCtx = ctx.parentCtx!.childrenCtx?[displaySelectorName];
        if (displaySelectorNameNext != null) {
          moveCtx = moveCtx?.childrenCtx?[displaySelectorNameNext];
        }
      }
      (moveCtx ?? ctx).selectOnDesigner();
    });
  });
}

//-------------------------------------------------------------------------------
void onActionPageBody(CwWidgetCtx ctx, DesignAction action) {
  var props = ctx.parentCtx!.initPropsIfNeeded();
  var horiz = HelperEditor.getStringProp(ctx, 'type') == 'row';

  String? actionStr = horiz ? actionMapHorz[action] : actionMapVert[action];

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

//-------------------------------------------------------------------------------

  void onActionBarAction(CwWidgetCtx ctx, DesignAction action) {
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
    ctx.repaint();
    ctx.selectParentOnDesigner();
  }

  void onActionTitleBar(CwWidgetCtx ctx, DesignAction action) {
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
    ctx.repaint();
    ctx.parentCtx?.repaint();
    ctx.selectParentOnDesigner();
  }