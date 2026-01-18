import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';

class WidgetHoverCmp extends StatefulWidget {
  const WidgetHoverCmp({
    required this.child,
    this.path,
    super.key,
    this.mode,
    this.overMgr,
  });

  @override
  State<WidgetHoverCmp> createState() => _WidgetHoverCmpState();
  final Widget child;
  final CwWidgetCtx? path;
  final String? mode;
  final HoverCmpManager? overMgr;
}

class _WidgetHoverCmpState extends State<WidgetHoverCmp> {
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
      child: getClip(getHoverBox(context)),
    );
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
        boxShadow:
            isOver
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
          color: isOver ? Colors.deepOrange : Colors.transparent,
        ),
      ),
      child: widget.child,
    );
  }
}

class HoverCmpManager {
  void onHover(CwWidgetCtx onCtx) {}

  void onExit() {
    // var app = CWApplication.of();
    // path = null;
    // if (app.loader.ctxLoader.mode == ModeRendering.design) {
    //   CoreDesigner.emit(CDDesignEvent.reselect, null);
    // }
  }
}
