import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_selectable.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';
import 'package:jsonschema/core/designer/editor/view/bloc_drag_components.dart';
import 'package:jsonschema/core/designer/editor/view/bloc_drag_pages.dart';
import 'package:jsonschema/widget/widget_tab.dart';

class CwSlotProp {
  final String id;
  final String name;
  final String? type;
  BuilderWidgetConfig? slotConfig;
  OnDropWidgetConfig? onDrop;
  OnActionWidgetConfig? onAction;

  CwSlotProp({
    required this.id,
    required this.name,
    this.slotConfig,
    this.onDrop,
    this.onAction,
    this.type,
  });
}

OverlayEntry? activeOverlayEntry;

class CwSlot extends StatefulWidget implements PreferredSizeWidget {
  const CwSlot({super.key, required this.config});
  final CwSlotConfig config;

  void setDefaultLayout(TransitionBuilder builder) {
    config.builderDefault = builder;
  }

  @override
  State<CwSlot> createState() => CwSlotState();

  @override
  Size get preferredSize {
    var h = config.ctx.dataWidget?[cwProps]?['#heightOfSlot'] ?? kToolbarHeight;
    return Size.fromHeight(h);
  }
}

bool debugCreateSlotWidget = false;

class CwSlotState extends State<CwSlot> {
  @override
  Widget build(BuildContext context) {
    var ctx = widget.config.ctx;

    // pas posible si viewer car un ctx peut avoir plusieurs slots (si dans list)
    ctx.selectorCtxIfDesign?.slotState = this;

    if (ctx.getData()?[cwImplement] != null &&
        widget.config.innerWidget == null) {
      widget.config.innerWidget = ctx.aFactory.getWidget(ctx);
      if (debugCreateSlotWidget) {
        print("create CwWidget in slot ${ctx.aWidgetPath}");
      }
    } 


    if (ctx.aFactory.isModeViewer()) {
      return _getDefaultLayout(widget.config.innerWidget ?? const SizedBox());
    }

    return _getDefaultLayout(
      getSelectable(widget.config.innerWidget ?? getEmptySlot()),
    );
  }

  void repaint() {
    widget.config.innerWidget = null;
    if (mounted) {
      // ignore: invalid_use_of_protected_member
      setState(() {});
    }
  }

  Widget _getDefaultLayout(Widget child) {
    Widget wid;
    if (widget.config.builderDefault != null &&
        widget.config.innerWidget == null) {
      wid = widget.config.builderDefault!(context, child);
    } else {
      wid = child;
    }
    return wid;
  }

  Widget getEmptySlot() {
    return DottedBorder(
      options: RectDottedBorderOptions(
        color: Colors.orange,
        dashPattern: [5, 5],
        strokeWidth: 1,
      ),
      child: IconButton(
        padding: EdgeInsets.fromLTRB(
          10,
          0,
          10,
          0,
        ), //           EdgeInsets.zero, // supprime le padding interne
        constraints: const BoxConstraints(),
        onPressed: () {
          var ctx = widget.config.ctx;
          var ctxDesigner = ctx.aFactory.pageDesignerKey.currentContext!;

          if (activeOverlayEntry != null) {
            return;
          }
          showNonBlockingDialog(ctxDesigner);
        },
        icon: Icon(Icons.add_box_outlined),
        color: Colors.orange,
      ),
    );
  }

  void showNonBlockingDialog(BuildContext context) {
    // double h = MediaQuery.of(context).size.height * 0.8;

    activeOverlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: 0,
          left: 0,
          bottom: 0,

          child: Material(
            child: Column(
              children: [
                SizedBox(
                  width: 300,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue, // couleur du bouton
                      foregroundColor: Colors.white, // couleur du texte
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),

                    child: const Text('Close'),
                    onPressed: () {
                      activeOverlayEntry?.remove();
                      activeOverlayEntry = null;
                    },
                  ),
                ),
                Expanded(child: SizedBox(width: 300, child: getTabComponent())),
              ],
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(activeOverlayEntry!);
  }

  Widget getTabComponent() {
    var ctx = widget.config.ctx;
    return WidgetTab(
      listTab: [Tab(text: 'Components'), Tab(text: 'Pages & dialogs')],
      listTabCont: [
        WidgetChoiser(factory: ctx.aFactory, contextPopUp: activeOverlayEntry),
        WidgetPages(factory: ctx.aFactory, contextPopUp: activeOverlayEntry),
      ],
      heightTab: 30,
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
