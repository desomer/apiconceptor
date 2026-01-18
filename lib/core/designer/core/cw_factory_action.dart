import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';

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
