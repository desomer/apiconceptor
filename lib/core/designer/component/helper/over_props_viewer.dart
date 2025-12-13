import 'package:flutter/material.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';

class WidgetOverCmp extends StatefulWidget {
  const WidgetOverCmp(
      {required this.child, this.path, super.key, this.mode, this.overMgr});

  @override
  State<WidgetOverCmp> createState() => _WidgetOverCmpState();
  final Widget child;
  final String? path;
  final String? mode;
  final HoverCmpManager? overMgr;
}

class _WidgetOverCmpState extends State<WidgetOverCmp> {
  bool isOver = false;


  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
        onHover: (event) {
          setState(() {
            isOver = true;
            widget.overMgr?.onHover(widget.path!);
          });
        },
        onExit: (event) {
          setState(() {
            isOver = false;
            widget.overMgr?.onExit();
          });
        },
        child: getClip(getHoverBox(context)));
  }

  Widget getClip(Widget child) {
    if (widget.mode == 'clip') {
      return ClipPath(clipper: TriangleClipper(true), child: child);
    }
    if (widget.mode == '1clip') {
      return ClipPath(clipper: TriangleClipper(false), child: child);
    } else {
      return child;
    }
  }

  Container getHoverBox(BuildContext context) {
    return Container(
        decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            boxShadow: isOver
                ? [
                    BoxShadow(
                      color: Colors.deepOrange.withAlpha(128),
                      spreadRadius: 5,
                      blurRadius: 20,
                      // offset: const Offset(-20, -20), // changes position of shadow
                    ),
                  ]
                : null,
            border: Border.all(
                color: isOver ? Colors.deepOrange : Colors.transparent)),
        child: widget.child);
  }
}

class HoverCmpManager {
  String? path;

  void onHover(String onPath) {
    // var app = CWApplication.of();
    // if (app.loader.ctxLoader.mode == ModeRendering.design && path != onPath) {
    //   path = onPath;
    //   SlotConfig? config = app.factory.mapSlotConstraintByPath[onPath];
    //   var ctx = config?.slot?.ctx;
    //   CoreDesigner.emit(CDDesignEvent.over, ctx);
    // }
  }

  void onExit() {
    // var app = CWApplication.of();
    // path = null;
    // if (app.loader.ctxLoader.mode == ModeRendering.design) {
    //   CoreDesigner.emit(CDDesignEvent.reselect, null);
    // }
  }
}
