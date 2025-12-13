import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:jsonschema/core/designer/core/widget_animated_drag.dart';
import 'package:jsonschema/core/designer/core/widget_drag_utils.dart';
import 'package:jsonschema/core/designer/core/widget_event_bus.dart';
import 'package:jsonschema/core/designer/cw_slot.dart';
import 'package:jsonschema/feature/content/pan_browser.dart';
import 'package:jsonschema/core/designer/component/pages_viewer.dart';
import 'package:jsonschema/core/designer/cw_widget.dart';

var currentSelectorManager = WidgetSelectorManager();

class WidgetSelectorManager {
  var lastHoverTime = DateTime.now().millisecondsSinceEpoch;
  WidgetSelectableState? lastHover;
  List<WidgetSelectableState> listDragOpen = [];

  var lastSelectedTime = DateTime.now().millisecondsSinceEpoch;
  WidgetSelectableState? lastSelected;

  bool isSelected(WidgetSelectableState sel) {
    int t = DateTime.now().millisecondsSinceEpoch;
    if (t - lastSelectedTime > 200) {
      lastSelectedTime = DateTime.now().millisecondsSinceEpoch;
      lastSelected = sel;
      return true;
    }
    return false;
  }

  void removeDrag() {
    var old = listDragOpen;
    listDragOpen = [];
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      for (var element in old) {
        if (!listDragOpen.contains(element)) {
          print('remove drag zone ${element.widget.getPath()}');
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
    var currentPath = lastHover?.widget.getPath();

    if (isExiting) {
      if (widgetState == lastHover) {
        lastHover = null;
      }
      SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
        print("isExiting onHover $isExiting  $currentPath");
        // ignore: invalid_use_of_protected_member
        widgetState.setState(() {});
      });
    }

    var aPath = widgetState.widget.getPath();

    if (!isExiting && widgetState != lastHover) {
      //if (t - lastHoverTime < 500) {

      if (currentPath != aPath) {
        if (currentPath?.startsWith(aPath) ?? false) {
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

      print("onHover $aPath $isExiting  $currentPath");

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
    required this.slotConfig,
    this.withAnimatedDropZone = true,
  });
  final Widget child;
  final bool withDragAndDrop;
  final PanInfo? panInfo;
  final CwSlotConfig? slotConfig;
  final bool withAnimatedDropZone;

  String getPath() {
    return slotConfig?.ctx.aPath ?? panInfo?.pathDataInTemplate ?? "";
  }

  @override
  State<WidgetSelectable> createState() => WidgetSelectableState();
}

class WidgetSelectableState extends State<WidgetSelectable> {
  bool isViewHoverEnable = false;

  bool isHover = false;
  bool menuIsOpen = false;

  GlobalKey? captureKey;
  Size? sizeOnDropAccept;

  Widget? dragZoneDetail;
  ValueNotifier<int> drawIndicatorMode = ValueNotifier(0);

  Widget getAnimatedZoneRow(Widget child) {
    return AnimatedZoneRow(
      modeNotifier: drawIndicatorMode,
      height: sizeOnDropAccept?.height ?? 0,
      child: child,
    );
  }

  Widget _getDroppableWithAnimatedZone(bool isHoverByDrag, Widget eventWidget) {
    isHover = currentSelectorManager.isHover(this);

    return Stack(
      fit: StackFit.passthrough,
      children: [
        if (widget.withAnimatedDropZone) getAnimatedZoneRow(eventWidget),
        if (!widget.withAnimatedDropZone) eventWidget,

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
    print('rebuild selectable ${widget.slotConfig?.ctx.aPath}');
    captureKey ??= GlobalKey(debugLabel: 'captureKey');
    widget.slotConfig?.ctx.keyCapture = captureKey;

    var withDrag = widget.withDragAndDrop;
    var withDrop = widget.withDragAndDrop;

    var eventWidget = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      child: GestureDetector(
        key: withDrag ? null : captureKey,
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
      ),
    );

    if (withDrop && !withDrag) {
      return getDropTargetWidget(eventWidget);
    } else if (withDrop && withDrag) {
      return getDraggableWidget(getDropTargetWidget(eventWidget));
    } else {
      return eventWidget;
    }
  }

  Widget getDraggableWidget(Widget droppable) {
    return Draggable<DragCtx>(
      dragAnchorStrategy: dragAnchorStrategy,
      data: DragCtx(),
      childWhenDragging:
          Container(), // remplace par un container vide pendant le drag
      onDragEnd: (details) {
        currentSelectorManager.removeDrag();
        currentSelectorManager.doHover(this, null, isExiting: true);
        setState(() {});
      },
      feedbackOffset: const Offset(0, 0),
      feedback: Container(
        color: Colors.black38,
        child: const Material(
          elevation: 10,
          borderOnForeground: false,
          child: CWSlotImage(), // affiche l'image capturée
        ),
      ),
      child: droppable,
    );
  }

  Widget getDropTargetWidget(Widget eventWidget) {
    return DragTarget<DragCtx>(
      onWillAcceptWithDetails: (details) {
        final RenderBox box =
            captureKey!.currentContext!.findRenderObject() as RenderBox;
        sizeOnDropAccept = box.size;
        return true;
      },
      onAcceptWithDetails: (details) {
        final RenderBox box =
            captureKey!.currentContext!.findRenderObject() as RenderBox;
        final Offset localOffset = box.globalToLocal(details.offset);
        print('Position relative dans le DragTarget : $localOffset');
        details.data.doDragOn(this, context);
        currentSelectorManager.removeDrag();
      },
      builder: (context, candidateData, rejectedData) {
        final isHoverWithDrag = candidateData.isNotEmpty;

        if (widget.withAnimatedDropZone &&
            isHoverWithDrag &&
            widget.slotConfig?.innerWidget != null) {
          // ajoute les zone de drap
          currentSelectorManager.addDrag(this);
          currentSelectorManager.doHover(this, null, isExiting: false);
          dragZoneDetail = getZoneBox();
        }

        return _getDroppableWithAnimatedZone(isHoverWithDrag, eventWidget);
      },
    );
  }

  Widget getZoneBox() {
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        _getZoneDrag(
          width: sizeOnDropAccept!.width * 0.3,
          color: null,
          message: 'move left',
          mDrag: 1,
        ),
        Expanded(
          child: _getZoneDrag(
            width: null,
            color: Colors.red,
            message: 'swap',
            mDrag: 2,
          ),
        ),
        _getZoneDrag(
          width: sizeOnDropAccept!.width * 0.3,
          color: null,
          message: 'move right',
          mDrag: 3,
        ),
      ],
    );
  }

  Widget _getZoneDrag({
    required double? width,
    required Color? color,
    required String message,
    required int mDrag,
  }) {
    return DragTarget<DragCtx>(
      onWillAcceptWithDetails: (details) {
        drawIndicatorMode.value = mDrag;
        return true;
      },
      onAcceptWithDetails: (details) {
        print('Drop accepted on $message $details');
        currentSelectorManager.removeDrag();
      },
      builder: (context, candidateData, rejectedData) {
        return Tooltip(
          message: message,
          preferBelow: false,
          child: Container(
            height: sizeOnDropAccept!.height,
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
    // if (dragZoneDetail != null) {
    //   print("onExit dragZoneDetail");
    //   setState(() {});
    //   dragZoneDetail = null;
    // }
  }

  void onPointerDown(PointerDownEvent d) {
    if (menuIsOpen) return;

    // print("onPointerDown ${widget.panInfo?.getPathAttrInTemplate()}");

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

    bool isSel = currentSelectorManager.isSelected(this);

    if (isHover || isSel) {
      String id =
          widget.slotConfig?.ctx.aPath ??
          widget.panInfo?.pathDataInTemplate ??
          "?";
      emit(
        CDDesignEvent.select,
        CWEventCtx()
          ..ctx = widget.slotConfig?.ctx
          ..id = id
          ..keybox = captureKey,
      );
      if (widget.withDragAndDrop) {
        _capturePng();
      }
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

    CWSlotImageState.imageCmp = Image.memory(
      imageBytes!,
      scale: 1,
      //opacity: const AlwaysStoppedAnimation<double>(0.8),
    );

    // debugPrint(
    //   'Capture PNG ===========> ${image.toString()} ${imageBytes.length}',
    // );
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

class CWEventCtx {
  GlobalKey? keybox;
  String? id;
  CwWidgetCtx? ctx;
}
