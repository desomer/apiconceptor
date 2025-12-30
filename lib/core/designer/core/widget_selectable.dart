import 'dart:async';
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

  WidgetSelectableState? draggingWidget;

  var lastSelectedTime = DateTime.now().millisecondsSinceEpoch;
  WidgetSelectableState? lastSelectedByClick;
  CwWidgetCtx? lastSelectedCtx;

  (bool hasFocus, bool change) isFirstStackSelected(
    WidgetSelectableState sel,
    CwWidgetCtx? ctx,
  ) {
    int t = DateTime.now().millisecondsSinceEpoch;
    if (t - lastSelectedTime > 200) {
      // ne selectionne que le premier dans la pile
      lastSelectedTime = DateTime.now().millisecondsSinceEpoch;
      if (sel == lastSelectedByClick) {
        return (true, false);
      }

      // dedrag last
      WidgetSelectableState? last = lastSelectedByClick;
      SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
        if (last?.mounted == true) {
          // ignore: invalid_use_of_protected_member
          last?.setState(() {});
        }
      });

      lastSelectedByClick = sel;
      lastSelectedCtx = ctx;

      return (true, true);
    }
    return (false, false);
  }

  String? getSelectedPath() {
    return lastSelectedCtx?.aPath ?? lastSelectedByClick?.widget.getPath();
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
      widgetState.canDrag.value = false;
      if (widgetState == lastHover) {
        lastHover = null;
      }
      SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
        print("isExiting onHover $isExiting  $currentPath");
        if (widgetState.mounted) {
          // ignore: invalid_use_of_protected_member
          widgetState.setState(() {});
        }
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

  GlobalKey captureKey = GlobalKey(debugLabel: 'captureKey');
  Size? sizeOnDropAccept;

  Widget? dragZoneDetail;
  ValueNotifier<int> drawIndicatorMode = ValueNotifier(0);

  bool _isValidDrop = false;
  bool _isLockByParent = false;

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
        if (isViewHoverEnable || _isValidDrop)
          // style du hover ou du drop valide
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border:
                      (_isValidDrop ||
                                  isHover ||
                                  dragZoneDetail != null ||
                                  isHoverByDrag) &&
                              drawIndicatorMode.value == 0
                          ? Border.all(color: Colors.orange, width: 2)
                          : null,
                  //borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
      ],
    );
  }

  GlobalKey draggableKey = GlobalKey(debugLabel: 'draggable');

  @override
  Widget build(BuildContext context) {
    //print('rebuild selectable ${widget.slotConfig?.ctx.aPath}');

    widget.slotConfig?.ctx.selectableState = this;

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

  ValueNotifier<bool> canDrag = ValueNotifier<bool>(false);

  Widget getDraggableWidget(Widget droppable) {
    if (widget.slotConfig == null) {
      return droppable;
    }

    // if (_isLockByParent) {
    //   return droppable;
    // }

    if (widget.slotConfig?.ctx.isEmptySlot() ?? true) {
      // pas de drag si le slot est vide
      return droppable;
    }

    print('build Draggable ${widget.slotConfig!.ctx.aPath}');

    bool isDragEnable =
        widget.slotConfig!.ctx.isDesignSelected() && _isLockByParent == false;

    // if (widget.slotConfig!.ctx.lastSize?.height == null) {
    //   // final RenderBox? b =
    //   //     captureKey?.currentContext?.findRenderObject() as RenderBox?;
    //   // widget.slotConfig!.ctx.lastSize = b?.size;
    // }

    return Draggable<DragComponentCtx>(
      key: draggableKey,
      dragAnchorStrategy: dragAnchorStrategy,
      data: DragComponentCtx(widget.slotConfig!.ctx),
      maxSimultaneousDrags: isDragEnable ? null : 0,
      // remplace par un container vide orange pendant le drag
      childWhenDragging: Container(
        color: Colors.orangeAccent.withAlpha(50),
        width: widget.slotConfig!.ctx.lastSize?.width ?? 20,
        height: widget.slotConfig!.ctx.lastSize?.height ?? 40,
      ),
      onDragEnd: (details) {
        currentSelectorManager.draggingWidget = null;
        currentSelectorManager.removeDrag();
        currentSelectorManager.doHover(this, null, isExiting: true);
        setState(() {});
      },
      onDragStarted: () {
        currentSelectorManager.draggingWidget = this;
        print('start drag ${widget.slotConfig!.ctx.aPath}');
        emitLater(
          multiple: true,
          CDDesignEvent.select,
          CWEventCtx()
            ..extra = {'displayProps': false}
            ..ctx = widget.slotConfig!.ctx
            ..path = widget.slotConfig!.ctx.aPath
            ..keybox = captureKey,
        );
      },
      feedbackOffset: const Offset(0, 0),
      feedback: Container(
        color: Colors.black38,
        child: Material(
          elevation: 10,
          borderOnForeground: false,
          //child: Container(width: 100, height: 100, color: Colors.red),
          child: CWSlotImage(selectableState: this), // affiche l'image capturée
        ),
      ),
      child: droppable,
    );
  }

  bool isDragLock() {
    String p = '${widget.slotConfig?.ctx.aPath}';
    String ps = '${currentSelectorManager.getSelectedPath()}';

    if (p != ps && p.startsWith(ps)) {
      print('lock drag $p  by  $ps');
      return true;
    }
    return false;
  }

  Widget getDropTargetWidget(Widget eventWidget) {
    return DragTarget<DragCtx>(
      onWillAcceptWithDetails: (details) {
        final RenderBox? box =
            captureKey.currentContext?.findRenderObject() as RenderBox?;
        sizeOnDropAccept = box?.size;

        if (widget.slotConfig?.ctx.isEmptySlot() == false) {
          // refuse le drop si le slot est vide
          return false;
        }
        setState(() {
          // pour changement visuel si valide
          _isValidDrop = true;
        });

        return true;
      },
      onLeave: (_) {
        setState(() {
          _isValidDrop = false;
        });
      },

      onAcceptWithDetails: (details) {
        // final RenderBox box =
        //     captureKey!.currentContext!.findRenderObject() as RenderBox;
        // final Offset localOffset = box.globalToLocal(details.offset);
        // print('Position relative dans le DragTarget : $localOffset');
        details.data.doDropOn(this, context);
        currentSelectorManager.removeDrag();
        _isValidDrop = false;
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
    return _isLockByParent;
  }

  void onHover(PointerHoverEvent d) {
    currentSelectorManager.doHover(this, d, isExiting: false);
    if (isDragLock() != _isLockByParent) {
      _isLockByParent = !_isLockByParent;
      //  SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      //if (mounted) {
      // ignore: invalid_use_of_protected_member
      setState(() {});
      //}
      // });
    }
  }

  void onExit(PointerExitEvent d) {
    currentSelectorManager.doHover(this, d, isExiting: true);
    // if (dragZoneDetail != null) {
    //   print("onExit dragZoneDetail");
    //   setState(() {});
    //   dragZoneDetail = null;
    // }
  }

  void onPointerDown(PointerDownEvent d) async {
    if (menuIsOpen) return;

    if (isLock() && currentSelectorManager.draggingWidget == null) {
      // unlock au click
      _isLockByParent = false;
      print("lock select ${widget.slotConfig?.ctx.aPath}");
      SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
        if (mounted) {
          print("lock select 2 ${widget.slotConfig?.ctx.aPath}");
          // ignore: invalid_use_of_protected_member
          setState(() {});
        }
      });
      Future.delayed(Duration(milliseconds: 200), () {
        if (currentSelectorManager.draggingWidget == null) {
          // SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
          if (mounted) {
            print("lock select 3 ${widget.slotConfig?.ctx.aPath}");
            onPointerDown(d);
          }
          // });
        }
      });
      return;
    }

    if (d.buttons == 2) {
      doRightSelection(d);
    }

    bool isSel = false;
    bool selectChange = false;
    (isSel, selectChange) = currentSelectorManager.isFirstStackSelected(
      this,
      widget.slotConfig?.ctx,
    );

    // autorise le drag aprés une selection
    if (selectChange && mounted) {
      // SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      if (mounted) {
        print("unlock drag by click ${widget.slotConfig?.ctx.aPath}");
        // ignore: invalid_use_of_protected_member
        setState(() {});
      }
      // });
    }

    if (isHover || isSel) {
      String id =
          widget.slotConfig?.ctx.aPath ??
          widget.panInfo?.pathDataInTemplate ??
          "?";
      emit(
        CDDesignEvent.select,
        CWEventCtx()
          ..ctx = widget.slotConfig?.ctx
          ..path = id
          ..keybox = captureKey,
      );
      if (widget.withDragAndDrop) {
        await capturePng();
      }
    }
  }

  Future<Widget?> capturePng() async {
    RenderRepaintBoundary? boundary =
        captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

    if (boundary == null) return null;
    widget.slotConfig?.ctx.lastSize = boundary.size;

    /// convert boundary to image
    final image = await boundary.toImage(pixelRatio: 0.9);
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    final imageBytes = byteData?.buffer.asUint8List();

    var imageCmp = Image.memory(imageBytes!, scale: 1);
    CWSlotImageState.imageCmp = imageCmp;
    CWSlotImageState.path = widget.getPath();
    return imageCmp;
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
RenderBox? initRecWithKeyPosition(
  GlobalKey selectedKey,
  GlobalKey sourceKey,
  CWRec rectToInit,
) {
  final Offset? position = TKPosition.getPosition(selectedKey, sourceKey);

  if (position == null) {
    print('*******************error initRecWithKeyPosition $selectedKey');
    return null;
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

  return box;
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
  String? path;
  CwWidgetCtx? ctx;
  Map<String, dynamic>? extra;
  Function? callback;
}
