import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_popup_action.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_measure_size.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_event_bus.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_overlay_selector.dart';
import 'package:jsonschema/widget/device_preview/devise_iphone13.dart';
import 'package:jsonschema/widget/device_preview/frame.dart';

class PagesDesignerViewer extends StatefulWidget {
  const PagesDesignerViewer({
    super.key,
    required this.child,
    required this.cWDesignerMode,
    required this.aFactory,
  });
  final Widget child;
  final bool cWDesignerMode;
  final WidgetFactory? aFactory;

  @override
  State<PagesDesignerViewer> createState() => _PagesDesignerViewerState();
}

enum DeviseDisplayType { mobile, desktop }

class _PagesDesignerViewerState extends State<PagesDesignerViewer> {
  DeviseDisplayType mode = DeviseDisplayType.desktop;

  double marge = 15.0;

  Size grow(Size s, double factor) {
    return Size(s.width * factor, s.height * factor);
  }

  @override
  Widget build(BuildContext context) {
    return initFrame(widget.child);
  }

  Widget initFrame(Widget content) {
    if (!widget.cWDesignerMode) {
      return content;
    }

    List<Widget> indicator = [
      Positioned(
        left: 0,
        top: 0,
        child: SizedBox(
          key: widget.aFactory!.scaleKeyMin,
          //color: Colors.red,
          height: 1,
          width: 1,
        ),
      ),
      Positioned(
        left: 100,
        top: 100,
        child: SizedBox(
          key: widget.aFactory!.scaleKey100,
          //color: Colors.red,
          height: 1,
          width: 1,
        ),
      ),
      Positioned(
        right: 0,
        bottom: -marge,
        child: SizedBox(
          key: widget.aFactory!.scaleKeyMax,
          //color: Colors.red,
          height: 1,
          width: 1,
        ),
      ),
    ];

    Widget stackDesigner = Stack(
      key: widget.aFactory!.designViewPortKey,
      children: [content, ...indicator],
    );

    Widget designer;

    if (mode == DeviseDisplayType.mobile) {
      // retirer avec le retour de la preview
      designer = Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Center(
          child: DeviceFrame(
            isFrameVisible: true,
            device: deviceIphone,
            screen: getAnimatedWidth(stackDesigner),
          ),
        ),
      );
    } else {
      designer = Container(
        color: Colors.black,
        padding: EdgeInsets.all(marge),
        child: LayoutBuilder(
          builder: (context, constraints) {
            var size = grow(constraints.biggest, 1.3);
            return SizedBox.fromSize(
              // key: widget.aFactory!.designViewPortKey,
              size: constraints.biggest,
              child: FittedBox(
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: getAnimatedWidth(stackDesigner),
                ),
              ),
            );
          },
        ),
      );
    }

    var resizer = WidgetMeasureSize(
      key: widget.aFactory!.designerKey,
      onChange: (size) {
        debugPrint("Nouvelle taille : $size");
        widget.aFactory?.largeDesigner = size.width > 1600;
        resizeSelector();
      },

      child: Stack(
        children: [
          ZoomWithCtrl(
            onChange: () {
              unSelector();
            },
            child: designer,
          ),
          WidgetOverlySelector(),
          WidgetPopupAction(key: widget.aFactory!.popupActionKey),
        ],
      ),
    );
    return resizer;
  }

  void resizeSelector() {
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => emitLater(
        //waitFrame: 10,
        multiple: true,
        CDDesignEvent.reselect,
        null,
      ),
    );
  }

  void unSelector() {
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => emit(CDDesignEvent.unselect, null),
    );
  }

  GlobalKey keyAnimated = GlobalKey(debugLabel: "keyAnimated");

  Widget getAnimatedWidth(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        //print(' getAnimatedWidth  $constraints');
        return AnimatedContainer(
          width: constraints.maxWidth,
          key: keyAnimated,
          duration: Durations.short3,
          child: child,
        );
      },
    );
  }
}

//----------------------------------------------------------

class ZoomWithCtrl extends StatefulWidget {
  const ZoomWithCtrl({super.key, required this.child, required this.onChange});
  final Widget child;
  final Function onChange;

  @override
  State<ZoomWithCtrl> createState() => _ZoomWithCtrlState();
}

class _ZoomWithCtrlState extends State<ZoomWithCtrl> {
  final TransformationController _controller = TransformationController();
  bool _ctrlPressed = false;
  Offset? _lastFocalPoint;

  @override
  void initState() {
    super.initState();
    designZoomNotifier.addListener(onZoom);
  }

  void onZoom() {
    setState(() {
      double scaleFactor = designZoomNotifier.value / 100;

      // Appliquer le facteur de zoom compris ente 0.9 et 1.1
      Matrix4 newMatrix = Matrix4.identity();
      newMatrix= newMatrix.scaledByDouble(scaleFactor, scaleFactor, 1.0, 1.0);

      _controller.value = newMatrix;
      widget.onChange();
    });
  }

  @override
  void dispose() {
    designZoomNotifier.removeListener(onZoom);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: (event) {
        setState(() {
          _ctrlPressed =
              event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.controlLeft ||
              event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.controlRight;
        });
      },
      child: Listener(
        onPointerSignal: (pointerSignal) {
          if (pointerSignal is PointerScrollEvent && _ctrlPressed) {
            final delta = pointerSignal.scrollDelta.dy;

            // facteur de zoom
            final scaleFactor = delta > 0 ? 0.95 : 1.05;

            final Matrix4 newMatrix =
                _controller.value.clone()
                  ..scaleByDouble(scaleFactor, scaleFactor, 1.0, 1.0);

            _controller.value = newMatrix;
            widget.onChange();
          }
        },

        onPointerDown: (event) {
          if (_ctrlPressed) {
            _lastFocalPoint = event.localPosition;
          }
        },

        onPointerMove: (event) {
          
          if (_ctrlPressed && _lastFocalPoint != null) {
            final delta = event.localPosition - _lastFocalPoint!;
            final matrix =
                _controller.value.clone()
                  ..translateByDouble(delta.dx, delta.dy, 0, 1.0);
            _controller.value = matrix;

            _lastFocalPoint = event.localPosition;
            widget.onChange();
          }
        },

        onPointerUp: (_) => _lastFocalPoint = null,

        child: InteractiveViewer(
          scaleEnabled: false,
          panEnabled: false,
          transformationController: _controller,
          minScale: 0.1,
          maxScale: 10,
          child: widget.child,
        ),
      ),
    );
  }
}
