import 'dart:developer' as dev show log;

import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/core/widget_event_bus.dart';
import 'package:jsonschema/core/designer/core/widget_selectable.dart';

class WidgetOverlySelector extends StatefulWidget {
  const WidgetOverlySelector({super.key});

  @override
  State<WidgetOverlySelector> createState() => _WidgetOverlySelectorState();
}

class _WidgetOverlySelectorState extends State<WidgetOverlySelector> {
  CWRec position = CWRec();

  ZoneDesc bottomZone = ZoneDesc();
  ZoneDesc topZone = ZoneDesc();
  ZoneDesc rightZone = ZoneDesc();
  ZoneDesc leftZone = ZoneDesc();
  ZoneDesc deleteZone = ZoneDesc();
  ZoneDesc sizeZone = ZoneDesc();

  @override
  void dispose() {
    removeAllListener(CDDesignEvent.select);
    super.dispose();
  }

  CWEventCtx? currentSelect;

  @override
  void initState() {
    initActionZone();
    removeAllListener(CDDesignEvent.select);
    removeAllListener(CDDesignEvent.reselect);

    on(CDDesignEvent.select, (selected) {
      CWEventCtx ctx = selected;

      //var keybox = ctx.ctx?.selectableState?.captureKey;

      var keybox = ctx.ctx?.getBoxKey();

      var displayProps = (ctx.extra?['displayProps'] ?? true) == true;
      if (keybox == null) {
        dev.log("*********** no keybox for ${ctx.path}");
        return;
      }

      initRecWithKeyPosition(keybox, ctx.ctx!.aFactory.designerKey, position, ctx.ctx!);

      final RenderBox? b =
          keybox.currentContext?.findRenderObject() as RenderBox?;
      ctx.ctx?.selectorCtxIfDesign?.lastSize = b?.size;

      // var h = position.bottom - position.top;
      // var w = position.right - position.left;
      //dev.log("size for ${ctx.path} : $w x $h");

      setState(() {}); // postionne l'indicateur

      if (displayProps) {
        currentSelect = ctx;
        currentSelectorManager.lastSelectedCtx = ctx.ctx;
        dev.log("select ${ctx.path}");
        if (ctx.ctx != null) {
          var ctxW = ctx.ctx!;
          ctxW.aFactory.displayProps(ctxW);
        }
      }
      ctx.callback?.call();
    });

    on(CDDesignEvent.reselect, (selected) {
      if (currentSelect == null) {
        return;
      }
      if (selected != null) {
        currentSelect!.ctx!.aFactory.displayProps(currentSelect!.ctx!);
      }

      CWEventCtx ctx = currentSelect!;
      currentSelect = ctx;
      initRecWithKeyPosition(
        ctx.ctx!.getBoxKey()!,
        ctx.ctx!.aFactory.designerKey,
        position,
        ctx.ctx!,
      );

      var h = position.bottom - position.top;
      var w = position.right - position.left;
      dev.log("reselect size for ${currentSelect!.ctx!.aWidgetPath} : $w x $h");

      if (mounted) {
        setState(() {}); // postionne l'indicateur
      }
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {

    var width = position.right - position.left;
    var height = position.bottom - position.top;

    if (width <= 0 || height <= 0) {
      return Container();
    }

    List<Widget> childrenAction = [];
    childrenAction.add(getZone(deleteZone, position));
    childrenAction.add(getZone(sizeZone, position));
    childrenAction.add(getZone(topZone, position));
    childrenAction.add(getZone(bottomZone, position));
    childrenAction.add(getZone(rightZone, position));
    childrenAction.add(getZone(leftZone, position));

    childrenAction.add(
      AnimatedPositioned(
        duration: Duration(milliseconds: 200),
        top: position.top,
        left: position.left,
        child: IgnorePointer(
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.deepOrange, width: 1.5),
            ),
            child: OuterGlowBorder(
              color: Colors.deepOrange,
              radius: 0,
              strokeWidth: 2,
            ),
          ),
        ),
      ),
    );

    return Stack(children: childrenAction);
  }

  var dragInProgess = false;

  Positioned getZone(ZoneDesc z, CWRec r) {
    z.initPosFct!(r);

    return Positioned(
      top: z.top,
      left: z.left,
      bottom: z.bottom,
      right: z.right,
      // ignore: sized_box_for_whitespace
      child: Container(
        width: z.width,
        height: z.height,
        //color: Colors.blueAccent.withOpacity(0.3),
        child: Stack(
          children: [
            Visibility(
              visible: z.visibility,
              maintainAnimation: true,
              maintainState: true,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                curve: Curves.fastOutSlowIn,
                opacity: z.visibility ? 1 : 0,
                child: Stack(children: z.actions),
              ),
            ),
            MouseRegion(
              opaque: false,
              onEnter: (event) {
                if (!dragInProgess) {
                  setState(() {
                    z.visibility = true;
                  });
                }
              },
              onExit: (event) {
                if (!dragInProgess) {
                  setState(() {
                    z.visibility = false;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void initActionZone() {
    //////////////////////////////////////////////////////////////////////////
    bottomZone.initPosFct = (CWRec r) {
      bottomZone.top = r.bottom - 10;
      bottomZone.left = r.left;
      bottomZone.width = r.right - r.left;
      bottomZone.height = 40;

      int da = -25;
      int db = 5;
      if (bottomZone.width! < 60) {
        bottomZone.width = 60;
        bottomZone.left = r.left - (60 - (r.right - r.left)) / 2;
        da = -20;
        db = -5;
      }

      double topBtn = 10;
      double leftBtn = bottomZone.width! / 2;

      bottomZone.actions = [];

      addAction(
        bottomZone.actions,
        getPositionedAction(
          topBtn,
          leftBtn + da,
          Icons.expand_more,
          DesignAction.moveBottom,
        ),
      );

      addAction(
        bottomZone.actions,
        getPositionedAction(
          topBtn,
          leftBtn + db,
          Icons.add,
          DesignAction.addBottom,
        ),
      );
    };

    topZone.initPosFct = (CWRec r) {
      topZone.top = r.top - 30;
      topZone.left = r.left;
      topZone.width = r.right - r.left;
      topZone.height = 40;

      int da = -25;
      int db = 5;
      if (topZone.width! < 60) {
        topZone.width = 60;
        topZone.left = r.left - (60 - (r.right - r.left)) / 2;
        da = -20;
        db = -5;
      }

      double topBtn = 10;
      double leftBtn = topZone.width! / 2;
      topZone.actions = [];

      addAction(
        topZone.actions,
        getPositionedAction(
          topBtn,
          leftBtn + da,
          Icons.expand_less,
          DesignAction.moveTop,
        ),
      );
      addAction(
        topZone.actions,
        getPositionedAction(
          topBtn,
          leftBtn + db,
          Icons.add,
          DesignAction.addTop,
        ),
      );
    };

    rightZone.initPosFct = (CWRec r) {
      rightZone.top = r.top;
      rightZone.left = r.right - 10;
      rightZone.width = 40;
      rightZone.height = r.bottom - r.top;

      int da = -25;
      int db = 5;

      if (rightZone.height! < 60) {
        rightZone.height = 60;
        rightZone.top = r.top - (60 - (r.bottom - r.top)) / 2;
        da = -20;
        db = -5;
      }

      double topBtn = rightZone.height! / 2;
      double leftBtn = 10;

      rightZone.actions = [];
      addAction(
        rightZone.actions,
        getPositionedAction(
          topBtn + da,
          leftBtn,
          Icons.navigate_next,
          DesignAction.moveRight,
        ),
      );

      addAction(
        rightZone.actions,
        getPositionedAction(
          topBtn + db,
          leftBtn,
          Icons.add,
          DesignAction.addRight,
        ),
      );
    };

    leftZone.initPosFct = (CWRec r) {
      leftZone.top = r.top;
      leftZone.left = r.left - 30;
      leftZone.width = 40;
      leftZone.height = r.bottom - r.top;
      int da = -25;
      int db = 5;

      if (leftZone.height! < 60) {
        leftZone.height = 60;
        leftZone.top = r.top - (60 - (r.bottom - r.top)) / 2;
        da = -20;
        db = -5;
      }

      double topBtn = leftZone.height! / 2;
      double leftBtn = 10;

      leftZone.actions = [];

      addAction(
        leftZone.actions,
        getPositionedAction(
          topBtn + da,
          leftBtn,
          Icons.navigate_before,
          DesignAction.moveLeft,
        ),
      );
      addAction(
        leftZone.actions,
        getPositionedAction(
          topBtn + db,
          leftBtn,
          Icons.add,
          DesignAction.addLeft,
        ),
      );
    };

    deleteZone.initPosFct = (CWRec r) {
      deleteZone.top = r.bottom - 20;
      deleteZone.left = r.left - 20;
      deleteZone.width = 60;
      deleteZone.height = 60;

      double topBtn = 15;
      double leftBtn = 5;

      deleteZone.actions = [];
      addAction(
        deleteZone.actions,
        getPositionedAction(topBtn, leftBtn, Icons.delete, DesignAction.delete),
      );
    };

    sizeZone.initPosFct = (CWRec r) {
      sizeZone.top = r.bottom - 20;
      sizeZone.left = r.right - 20;
      sizeZone.width = 60;
      sizeZone.height = 60;

      double topBtn = 15;
      double leftBtn = 15;

      // sizeZone.actions = [
      //   //getAddDrag(topBtn, leftBtn, Icons.open_in_full, DesignAction.size),
      // ];
      sizeZone.actions = [];
      addAction(
        sizeZone.actions,
        getPositionedAction(
          topBtn,
          leftBtn,
          Icons.open_in_full,
          DesignAction.size,
        ),
      );
    };
  }

  void addAction(List<Widget> a, Widget? w) {
    if (w != null) a.add(w);
  }

  Positioned? getPositionedAction(
    double top,
    double left,
    IconData ic,
    DesignAction action,
  ) {
    return canAction(action)
        ? Positioned(
          top: top,
          left: left,
          child: SizedBox(
            height: 20,
            width: 20,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                padding: const EdgeInsets.all(0),
              ),
              child: Icon(ic, size: 15),
              onPressed: () {
                debugPrint('doAction $action');
                doAction(action);
              },
            ),
          ),
        )
        : null;
  }

  bool canAction(DesignAction action) {
    return true;
  }

  void doAction(DesignAction action) {
    currentSelect?.ctx?.slotProps?.onAction?.call(currentSelect!.ctx!, action);
  }
}

//----------------------------------------------------------------------------------
class ZoneDesc {
  bool visibility = false;
  double? bottom;
  double? left;
  double? top;
  double? right;
  double? width;
  double? height;
  Function? initPosFct;
  List<Widget> actions = [];
}

enum DesignAction {
  delete,
  size,
  addTop,
  addBottom,
  moveBottom,
  moveTop,
  addRight,
  addLeft,
  moveRight,
  moveLeft,
  none,
}

class OuterGlowBorder extends StatelessWidget {
  final Color color;
  final double radius;
  final double strokeWidth;

  const OuterGlowBorder({
    super.key,
    required this.color,
    this.radius = 16,
    this.strokeWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OuterGlowPainter(
        color: color,
        radius: radius,
        strokeWidth: strokeWidth,
      ),
      child: Container(), // intérieur totalement transparent
    );
  }
}

class _OuterGlowPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;

  _OuterGlowPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Halo externe uniquement
    final glowPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 5);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
