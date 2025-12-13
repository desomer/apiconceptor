import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/core/widget_overlay_selector.dart';
import 'package:jsonschema/widget/device_preview/devise_iphone13.dart';
import 'package:jsonschema/widget/device_preview/frame.dart';

class PagesDesignerViewer extends StatefulWidget {
  const PagesDesignerViewer({
    super.key,
    required this.child,
    required this.cWDesignerMode,
  });
  final Widget child;
  final bool cWDesignerMode;

  @override
  State<PagesDesignerViewer> createState() => _PagesDesignerViewerState();
}

enum DeviseDisplayType { mobile, desktop }

GlobalKey designViewPortKey = GlobalKey(debugLabel: 'designViewPortKey');
GlobalKey designerKey = GlobalKey(debugLabel: 'designerKey');
GlobalKey scaleKeyMin = GlobalKey(debugLabel: 'scaleKeyMin');
GlobalKey scaleKey100 = GlobalKey(debugLabel: 'scaleKey100');
GlobalKey scaleKeyMax = GlobalKey(debugLabel: 'scaleKeyMax');

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
        bottom: -marge,
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
      designer = Container(
        color: Colors.black,
        padding: EdgeInsets.all(marge),
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
