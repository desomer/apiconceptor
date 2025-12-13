import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/core/widget_selectable.dart';
import 'package:jsonschema/core/designer/cw_factory.dart';

class DropCtx {
  final Map<String, dynamic>? parentData;
  final Map<String, dynamic>? childData;
  final String componentId;
  DropCtx({
    required this.parentData,
    required this.childData,
    required this.componentId,
  });
}

class DragCtx {
  void doDragOn(WidgetSelectableState state, BuildContext context) {}
}

class DragComponentCtx extends DragCtx {
  DragComponentCtx();

  @override
  void doDragOn(WidgetSelectableState state, BuildContext context) {}
}

class DragNewComponentCtx extends DragCtx {
  final String idComponent;
  DragNewComponentCtx({required this.idComponent});

  @override
  void doDragOn(WidgetSelectableState state, BuildContext context) {
    var ctx = state.widget.slotConfig!.ctx;
    var param = <String, dynamic>{
      cwType: idComponent,
      cwProps: <String, dynamic>{},
    };

    var drop = DropCtx(
      parentData: ctx.parentCtx?.dataWidget,
      childData: param,
      componentId: idComponent,
    );

    state.widget.slotConfig!.ctx.aFactory.builderDragConfig[idComponent]?.call(
      ctx,
      drop,
    );

    if (ctx.slotProps?.onDrop != null) {
      ctx.slotProps!.onDrop!(ctx, drop);
    }
    ctx.aFactory.addInSlot(ctx.parentCtx!.dataWidget!, ctx.id, param);
    //state.widget.cwCtx.
    // ignore: invalid_use_of_protected_member
    ctx.parentCtx!.state?.setState(() {});
  }
}

//-----------------------------------------------------------

class CWSlotImage extends StatefulWidget {
  const CWSlotImage({super.key});

  @override
  CWSlotImageState createState() => CWSlotImageState();
}

class CWSlotImageState extends State<CWSlotImage> {
  static Widget? imageCmp;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black45,
      child: imageCmp ?? const Text('vide'),
    );
  }
}
