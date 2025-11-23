import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/widget_overlay_selector.dart';
import 'package:jsonschema/widget/device_preview/devise_iphone13.dart';
import 'package:jsonschema/widget/device_preview/frame.dart';

class PagesDesigner extends StatefulWidget {
  const PagesDesigner({super.key, required this.child});
  final Widget child;

  @override
  State<PagesDesigner> createState() => _PagesDesignerState();
}

enum DeviseDisplayType { mobile, desktop }

bool cWDesignerMode = false;

GlobalKey designViewPortKey = GlobalKey(debugLabel: 'designViewPortKey');
GlobalKey designerKey = GlobalKey(debugLabel: 'designerKey');
GlobalKey scaleKeyMin = GlobalKey(debugLabel: 'scaleKeyMin');
GlobalKey scaleKey100 = GlobalKey(debugLabel: 'scaleKey100');
GlobalKey scaleKeyMax = GlobalKey(debugLabel: 'scaleKeyMax');

class _PagesDesignerState extends State<PagesDesigner> {
  DeviseDisplayType mode = DeviseDisplayType.desktop;

  @override
  Widget build(BuildContext context) {
    return initFrame(widget.child);
  }

  Widget initFrame(Widget content) {
    if (!cWDesignerMode) {
      return content;
    }

    // ignore: dead_code
    List<Widget> indicator = [
      Positioned(
        left: 0,
        top: 0,
        child: SizedBox(
          key: scaleKeyMin,
          //color: Colors.red,
          height: 1,
          width: 1,
        ),
      ),
      Positioned(
        left: 100,
        top: 100,
        child: SizedBox(
          key: scaleKey100,
          //color: Colors.red,
          height: 1,
          width: 1,
        ),
      ),
      Positioned(
        right: 0,
        bottom: 0,
        child: SizedBox(
          key: scaleKeyMax,
          //color: Colors.red,
          height: 1,
          width: 1,
        ),
      ),
    ];

    Widget stackDesigner = Stack(
      key: designViewPortKey,
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
      designer = Padding(
        padding: const EdgeInsets.all(0),
        child: getAnimatedWidth(stackDesigner),
      );
    }

    return Stack(
      key: designerKey,
      children: [designer, WidgetOverlySelector()],
    );
  }

  Widget getStackDesigner(Widget content) {
    return Stack(
      children: [
        initFrame(content),
        // SelectorActionWidget(key: SelectorActionWidget.actionPanKey),
        // WidgetPopupMenu(key: SelectorActionWidget.popupMenuKey),
      ],
    );
  }

  GlobalKey keyAnimated = GlobalKey();

  Widget getAnimatedWidth(Widget child) {
    return Align(
      alignment: AlignmentGeometry.topCenter,
      child: LayoutBuilder(
        builder: (context, constraints) {
          //print(' getAnimatedWidth  $constraints');
          return AnimatedContainer(
            width: constraints.maxWidth,
            key: keyAnimated,
            duration: Durations.short3,
            child: child,
          );
        },
      ),
    );
  }
}
