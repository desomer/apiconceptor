import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:jsonschema/core/designer/widget_animated_drag.dart';
import 'package:jsonschema/core/designer/widget_drag_utils.dart';
import 'package:jsonschema/core/designer/widget_event_bus.dart';
import 'package:jsonschema/feature/content/pan_browser.dart';
import 'package:jsonschema/core/designer/pages_designer.dart';

var currentSelectorManager = WidgetSelectorManager();

class WidgetSelectorManager {
  var lastHoverTime = DateTime.now().millisecondsSinceEpoch;
  WidgetSelectableState? lastHover;
  List<WidgetSelectableState> listDragOpen = [];

  void removeDrag() {
    var old = listDragOpen;
    listDragOpen = [];
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      for (var element in old) {
        if (!listDragOpen.contains(element)) {
          element.dragZoneDetail = null;
          // ignore: invalid_use_of_protected_member
          element.setState(() {});
          element.drawIndicatorMode.value = 0;
        }
      }
    });
  }

  void addDrag(WidgetSelectableState widgetState) {
    removeDrag();
    listDragOpen.add(widgetState);
  }

  void doHover(
    WidgetSelectableState widgetState,
    PointerEvent? event, {
    required bool isExiting,
  }) {
    var t = DateTime.now().millisecondsSinceEpoch;
    var currentPath = lastHover?.widget.panInfo?.getPathAttrInTemplate();

    if (isExiting) {
      if (widgetState == lastHover) {
        lastHover = null;
      }
      SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
        // ignore: invalid_use_of_protected_member
        widgetState.setState(() {});
      });
    }

    var aPath = widgetState.widget.panInfo?.getPathAttrInTemplate();
    //print("onHover $aPath $isExiting  $currentPath");

    if (!isExiting && widgetState != lastHover) {
      //if (t - lastHoverTime < 500) {

      if (currentPath != aPath) {
        if (currentPath?.startsWith(aPath ?? '') ?? false) {
          //print('no hover $aPath car $currentPath');
          return;
        }
        if (widgetState.widget.panInfo?.type == 'Row') {
          //print('no hover $aPath car Row');
          return;
        }
      }

      var old = lastHover;
      lastHoverTime = t;
      lastHover = widgetState;

      if (event != null) {
        repaint(old, widgetState);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
          repaint(old, widgetState);
        });
      }
    }
  }

  void repaint(WidgetSelectableState? old, WidgetSelectableState widgetState) {
    // ignore: invalid_use_of_protected_member
    lastHover?.setState(() {});
    if (old != widgetState && (old?.mounted ?? false)) {
      // ignore: invalid_use_of_protected_member
      old?.setState(() {});
    }
  }

  bool isHover(WidgetSelectableState widgetState) {
    return lastHover == widgetState;
  }
}

//----------------------------------------------------------------
class WidgetSelectable extends StatefulWidget {
  const WidgetSelectable({
    super.key,
    required this.child,
    required this.withDragAndDrop,
    required this.panInfo,
  });
  final Widget child;
  final bool withDragAndDrop;
  final PanInfo? panInfo;

  @override
  State<WidgetSelectable> createState() => WidgetSelectableState();
}

class WidgetSelectableState extends State<WidgetSelectable> {
  bool isViewHoverEnable = false;

  bool isHover = false;
  bool menuIsOpen = false;

  GlobalKey? captureKey;
  Size? size;

  Widget? dragZoneDetail;
  ValueNotifier<int> drawIndicatorMode = ValueNotifier(0);

  Widget getDraggableContent(bool isHoverByDrag, Widget eventWidget) {
    isHover = currentSelectorManager.isHover(this);

    return Stack(
      children: [
        AnimatedZoneRow(
          modeNotifier: drawIndicatorMode,
          height: size?.height ?? 0,
          child: eventWidget,
        ),

        if (dragZoneDetail != null) dragZoneDetail!,
        if (isViewHoverEnable)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border:
                      (isHover || dragZoneDetail != null || isHoverByDrag) &&
                              drawIndicatorMode.value == 0
                          ? Border.all(color: Colors.amberAccent)
                          : null,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    captureKey ??= GlobalKey(debugLabel: 'captureKey');

    var withDrag = widget.withDragAndDrop;
    var withDrop = widget.withDragAndDrop;

    var eventWidget = GestureDetector(
      // onDoubleTap: () {
      //   print('select widget');
      //   //dialogOverlayKey.currentState?.minimized(false, null);
      // },
      child: MouseRegion(
        onHover: onHover,
        onExit: onExit,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: onPointerDown,
          child:
              withDrag
                  ? RepaintBoundary(key: captureKey, child: widget.child)
                  : widget.child,
        ),
      ),
    );

    if (!withDrag && withDrop) {
      return getDraggableContent(false, eventWidget);
    } else if (withDrop) {
      Widget droppable = eventWidget;
      if (withDrag) {
        droppable = getDragTargetWidget(eventWidget);
      }

      Widget draggable = getDraggableWidget(droppable);
      return draggable;
    } else {
      return eventWidget;
    }
  }

  Widget getDraggableWidget(Widget droppable) {
    return Draggable<DragComponentCtx>(
      dragAnchorStrategy: dragAnchorStrategy,
      data: DragComponentCtx(),
      childWhenDragging: Container(),
      onDragEnd: (details) {
        currentSelectorManager.removeDrag();
        currentSelectorManager.doHover(this, null, isExiting: true);
        setState(() {});
      },
      feedback: Container(
        color: Colors.white,
        child: const Material(
          elevation: 10,
          borderOnForeground: false,
          child: CWSlotImage(),
        ),
      ),
      child: droppable,
    );
  }

  Widget getDragTargetWidget(Widget eventWidget) {
    return DragTarget<DragComponentCtx>(
      onWillAcceptWithDetails: (details) {
        final RenderBox box =
            captureKey!.currentContext!.findRenderObject() as RenderBox;
        size = box.size;
        return true;
      },
      onAcceptWithDetails: (details) {
        final RenderBox box =
            captureKey!.currentContext!.findRenderObject() as RenderBox;
        final Offset localOffset = box.globalToLocal(details.offset);
        print('Position relative dans le DragTarget : $localOffset');
      },
      builder: (context, candidateData, rejectedData) {
        final isHoverByDrag = candidateData.isNotEmpty;

        if (isHoverByDrag) {
          currentSelectorManager.addDrag(this);
          currentSelectorManager.doHover(this, null, isExiting: false);
          dragZoneDetail = getZoneBox();
        }

        return getDraggableContent(isHoverByDrag, eventWidget);
      },
    );
  }

  Widget getZoneBox() {
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        getZoneDrag(
          width: size!.width * 0.3,
          color: null,
          message: 'move left',
          mDrag: 1,
        ),
        Expanded(
          child: getZoneDrag(
            width: null,
            color: null,
            message: 'swap',
            mDrag: 2,
          ),
        ),
        getZoneDrag(
          width: size!.width * 0.3,
          color: null,
          message: 'move right',
          mDrag: 3,
        ),
      ],
    );
  }

  Widget getZoneDrag({
    required double? width,
    required Color? color,
    required String message,
    required int mDrag,
  }) {
    return DragTarget<DragComponentCtx>(
      onWillAcceptWithDetails: (details) {
        drawIndicatorMode.value = mDrag;
        return true;
      },
      onAcceptWithDetails: (details) {},
      builder: (context, candidateData, rejectedData) {
        return Tooltip(
          message: message,
          preferBelow: false,
          child: Container(
            height: size!.height,
            width: width,
            color: color?.withAlpha(50),
          ),
        );
      },
    );
  }

  void doRightSelection(PointerDownEvent d) {
    menuIsOpen = true;
    Future.delayed(const Duration(milliseconds: 200), () {
      menuIsOpen = false;
    });

    // var p = TKPosition.getPosition(SelectorActionWidget.popupMenuKey, rootKey);

    // CWRec recSlot = CWRec();
    // SelectorActionWidget.initRecWithKeyPosition(
    //     captureKey!, SelectorActionWidget.viewKey, recSlot);
    // recSlot.top += p!.dy + d.localPosition.dy;
    // recSlot.left += p.dx + d.localPosition.dx;

    // SelectorActionWidget.popupMenuKey.currentState?.open(recSlot);

    // debugPrint('$p $recSlot');
  }

  // lock le block (pour drag) aprés une selection
  bool isLock() {
    return false;
  }

  void onHover(PointerHoverEvent d) {
    currentSelectorManager.doHover(this, d, isExiting: false);
  }

  void onExit(PointerExitEvent d) {
    currentSelectorManager.doHover(this, d, isExiting: true);
    if (dragZoneDetail != null) {
      setState(() {});
      dragZoneDetail = null;
    }
  }

  void onPointerDown(PointerDownEvent d) {
    if (menuIsOpen) return;

    print("onPointerDown ${widget.panInfo?.getPathAttrInTemplate()}");

    //widget.ctx.lastEvent = d;

    if (isLock()) {
      setState(() {});
      return;
    }

    if (d.buttons == 2) {
      doRightSelection(d);
    }

    // if (isHover) {
    //   bool isSelectionChange = !widget.ctx.isSelected();

    //   if (isSelectionChange) {
    //     CoreDesigner.emit(CDDesignEvent.select, widget.ctx);
    //     setState(() {});
    //   }
    if (isHover) {
      emit(CDDesignEvent.select, CWContext()..keybox = captureKey);
      _capturePng();
    }
    // }
  }

  Future _capturePng() async {
    RenderRepaintBoundary? boundary =
        captureKey?.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;

    if (boundary == null) return;

    /// convert boundary to image
    final image = await boundary.toImage(pixelRatio: 0.9);
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    final imageBytes = byteData?.buffer.asUint8List();

    CWSlotImageState.wi = Image.memory(imageBytes!, scale: 1);

    // debugPrint(
    //     'Capture PNG ===========> ${image.toString()} ${imageBytes.length}');
  }

  Offset dragAnchorStrategy(
    Draggable<Object> d,
    BuildContext context,
    Offset position,
  ) {
    // Offset positionRefMin = TKPosition.getPosition(
    //     SelectorActionWidget.scaleKeyMin, designerViewKey)!;
    // Offset positionRef100 = TKPosition.getPosition(
    //     SelectorActionWidget.scaleKey2, designerViewKey)!;
    // Offset positionRefMax = TKPosition.getPosition(
    //     SelectorActionWidget.scaleKeyMax, designerViewKey)!;

    // double previewPixelRatio = (positionRef100.dx - positionRefMin.dx) / 100;
    // double hDis = positionRefMax.dy - positionRefMin.dy;
    // double hInner = hDis / previewPixelRatio;

    // final RenderBox renderObject =
    //     SelectorActionWidget.scaleKeyMin.currentContext?.findRenderObject()!
    //         as RenderBox;
    // var pt = renderObject.globalToLocal(position);
    // double deltaBottom = hInner - pt.dy;

    // double delta = pt.dy - ((hInner - deltaBottom) * previewPixelRatio);

    // print(
    //     '${d.feedbackOffset} $previewPixelRatio $position $hInner $pt $deltaBottom $delta');

    double delta = 0;

    return Offset(d.feedbackOffset.dx + 10, d.feedbackOffset.dy - delta);
  }
}

//---------------------------------------------------------------------------------------
void initRecWithKeyPosition(
  GlobalKey selectedKey,
  GlobalKey sourceKey,
  CWRec rectToInit,
) {
  final Offset? position = TKPosition.getPosition(selectedKey, sourceKey);

  if (position == null) {
    print('*******************error initRecWithKeyPosition $selectedKey');
    return;
  }

  var designerKey = designViewPortKey;

  Offset positionRefMin = TKPosition.getPosition(scaleKeyMin, designerKey)!;
  Offset positionRef100 = TKPosition.getPosition(scaleKey100, designerKey)!;
  Offset positionRefMax = TKPosition.getPosition(scaleKeyMax, designerKey)!;

  double previewPixelRatio = (positionRef100.dx - positionRefMin.dx) / 100;

  final RenderBox box =
      selectedKey.currentContext!.findRenderObject() as RenderBox;

  rectToInit.left = position.dx * previewPixelRatio + positionRefMin.dx;
  rectToInit.bottom =
      position.dy * previewPixelRatio +
      positionRefMin.dy +
      box.size.height * previewPixelRatio;
  rectToInit.top = position.dy * previewPixelRatio + positionRefMin.dy;
  rectToInit.right =
      position.dx * previewPixelRatio +
      positionRefMin.dx +
      box.size.width * previewPixelRatio;

  if (rectToInit.top < positionRefMin.dy) {
    rectToInit.top = positionRefMin.dy;
  }
  if (rectToInit.bottom > positionRefMax.dy) {
    rectToInit.bottom = positionRefMax.dy;
  }
}

//---------------------------------------------------------------------------------------
class TKPosition {
  static Offset? getPosition(GlobalKey key, GlobalKey origin) {
    // ignore: cast_nullable_to_non_nullable
    final RenderObject? box = key.currentContext?.findRenderObject();

    // ignore: cast_nullable_to_non_nullable
    final RenderBox rootBox =
        origin.currentContext?.findRenderObject() as RenderBox;

    Offset? position;
    if (box != null) {
      position = (box as RenderBox).localToGlobal(
        Offset.zero,
        ancestor: rootBox,
      ); //this is global position
    }
    return position;
  }

  static Rect? getPositionRect(GlobalKey key, GlobalKey origin) {
    // ignore: cast_nullable_to_non_nullable
    final RenderObject? box = key.currentContext?.findRenderObject();

    if (box is RenderBox) {
      // ignore: cast_nullable_to_non_nullable
      final RenderBox rootBox =
          origin.currentContext!.findRenderObject() as RenderBox;

      final Offset position = box.localToGlobal(
        Offset.zero,
        ancestor: rootBox,
      ); //this is global position

      return Rect.fromLTWH(
        position.dx,
        position.dy,
        box.size.width,
        box.size.height,
      );
    }

    return null;
  }
}

class CWRec {
  double bottom = 10;
  double left = 10;
  double top = 10;
  double right = 10;

  @override
  String toString() {
    return 'b=$bottom t=$top l=$left r=$right';
  }

  bool equals(CWRec r) {
    return r.bottom == bottom &&
        r.left == left &&
        r.top == top &&
        r.right == right;
  }
}

class CWContext {
  GlobalKey? keybox;
}
