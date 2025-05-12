import 'package:assorted_layout_widgets/assorted_layout_widgets.dart';
import 'package:flutter/material.dart';

class BreadCrumbNavigator extends StatefulWidget {
  const BreadCrumbNavigator({super.key, required this.getList});
  final Function getList;

  @override
  State<StatefulWidget> createState() {
    return _BreadCrumbNavigatorState();
  }
}

class _BreadCrumbNavigatorState extends State<BreadCrumbNavigator> {
  @override
  Widget build(BuildContext context) {
    List<RouteCmp> currentPathOnStack = [];
    List<String> listPath = widget.getList();
    int i = 0;
    for (var element in listPath) {
      currentPathOnStack.add(
        RouteCmp(
          type: RouteCmpType.widget,
          idx: i,
          settings: RouteSettings(name: element),
        ),
      );
      i++;
    }

    List<Widget> widgets = [];
    int index = 0;
    for (RouteCmp route in currentPathOnStack) {
      var btn = _BreadButton(route.type, listPath[index], index == 0);

      widgets.add(Tooltip(message: "ddd", child: btn));

      index++;
    }

    return RowSuper(
      mainAxisSize: MainAxisSize.min,
      innerDistance: -15,
      children: widgets,
    );
  }
}

enum RouteCmpType { widget, cellidx, layout }

class RouteCmp extends Route {
  RouteCmp({required this.idx, super.settings, required this.type});
  int idx;
  RouteCmpType type;
}

class _BreadButton extends StatelessWidget {
  final String text;
  final bool isFirstButton;
  final RouteCmpType type;
  final Widget? child;

  // ignore: unused_element_parameter
  const _BreadButton(this.type, this.text, this.isFirstButton, {this.child});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: TriangleClipper(!isFirstButton),
      child: Container(
        color:
            type == RouteCmpType.layout
                ? Colors.deepOrangeAccent
                : Theme.of(context).highlightColor,
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: isFirstButton ? 8 : 30,
            end: 28,
            top: 8,
            bottom: 8,
          ),
          child:
              child ??
              Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
        ),
      ),
    );
  }
}

class TriangleClipper extends CustomClipper<Path> {
  final bool twoSideClip;

  TriangleClipper(this.twoSideClip);

  @override
  Path getClip(Size size) {
    final Path path = Path();
    if (twoSideClip) {
      path.moveTo(0, 0.0);
      path.lineTo(20.0, size.height / 2);
      path.lineTo(0, size.height);
    } else {
      path.lineTo(0, size.height);
    }
    path.lineTo(size.width - 20, size.height);
    path.lineTo(size.width, size.height / 2);
    path.lineTo(size.width - 20, 0);
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return true;
  }
}
