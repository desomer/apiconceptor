import 'package:jsonschema/core/designer/cw_factory.dart';
import 'package:jsonschema/core/designer/cw_widget.dart';

class CwFactoryAction {
  final CwWidgetCtx ctx;

  CwFactoryAction({required this.ctx});

  void deleteSlot(int idx, int nbSlots) {
    ctx.dataWidget?.remove(cwType);
    ctx.dataWidget?.remove(cwProps);

    for (var i = idx; i < nbSlots - 1; i++) {
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
  }

  void surround(String slotFrom, String slotTo, Map<String, dynamic> child) {
    var dataFrom = ctx.parentCtx!.dataWidget![cwSlots]?[slotFrom];
    dataFrom[cwId] = slotTo;
    // remplace le slot
    var newContainer = ctx.aFactory.addInSlot(
      ctx.parentCtx!.dataWidget!,
      slotFrom,
      child,
    );
    ctx.aFactory.addInSlot(newContainer, slotTo, dataFrom!);
  }

  void moveSlot(int nb, int idx) {
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
}
