import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_popup_action.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
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

  double marge = 20.0;

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
        child: getAnimatedWidth(stackDesigner),
      );
    }

    var resizer = WidgetMeasureSize(
      onChange: (size) {
        debugPrint("Nouvelle taille : $size");
        resizeSelector();
      },

      child: Stack(
        key: widget.aFactory!.designerKey,
        children: [
          designer,
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
