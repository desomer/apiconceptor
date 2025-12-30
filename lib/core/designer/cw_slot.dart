import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/cw_factory.dart';
import 'package:jsonschema/core/designer/core/widget_selectable.dart';
import 'package:jsonschema/core/designer/cw_widget.dart';
import 'package:jsonschema/feature/design/page_designer.dart';

class CwSlotProp {
  final String id;
  final String name;
  BuilderWidgetConfig? slotConfig;
  OnDropWidgetConfig? onDrop;
  OnActionWidgetConfig? onAction;

  CwSlotProp({
    required this.id,
    required this.name,
    this.slotConfig,
    this.onDrop,
    this.onAction,
  });
}

class CwSlot extends StatefulWidget implements PreferredSizeWidget {
  const CwSlot({super.key, required this.config});
  final CwSlotConfig config;

  void setDefaultLayout(TransitionBuilder builder) {
    config.builderDefault = builder;
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);

  @override
  State<CwSlot> createState() => _CwSlotState();
}

class _CwSlotState extends State<CwSlot> {
  @override
  Widget build(BuildContext context) {
    var ctx = widget.config.ctx;
    if (ctx.getData()?[cwType] != null && widget.config.innerWidget == null) {
      widget.config.innerWidget = ctx.aFactory.getWidget(ctx);
    }

    if (ctx.aFactory.mode == DesignMode.viewer) {
      return getDefaultLayout(widget.config.innerWidget ?? SizedBox());
    }

    return getDefaultLayout(
      getSelectable(widget.config.innerWidget ?? getEmptySlot()),
    );
  }

  Widget getDefaultLayout(Widget child) {
    if (widget.config.builderDefault != null &&
        widget.config.innerWidget == null) {
      return widget.config.builderDefault!(context, child);
    } else {
      return child;
    }
  }

  Widget getEmptySlot() {
    return DottedBorder(
      options: RectDottedBorderOptions(
        color: Colors.orange,
        dashPattern: [5, 5],
        strokeWidth: 1,
      ),
      child: IconButton(
        padding:  EdgeInsets.fromLTRB(10, 0, 10, 0), //           EdgeInsets.zero, // supprime le padding interne
        constraints: const BoxConstraints(),
        onPressed: () {},
        icon: Icon(Icons.add_box_outlined),
        color: Colors.orange,
      ),
    );
  }

  Widget getSelectable(Widget child) {
    return WidgetSelectable(
      slotConfig: widget.config,
      withDragAndDrop: widget.config.withDragAndDrop,
      withAnimatedDropZone: false,
      panInfo: null,
      child: child,
    );
  }
}

class CwSlotConfig {
  bool withDragAndDrop = true;
  CwWidget? innerWidget;
  final CwWidgetCtx ctx;
  TransitionBuilder? builderDefault;

  CwSlotConfig({required this.ctx});
}
