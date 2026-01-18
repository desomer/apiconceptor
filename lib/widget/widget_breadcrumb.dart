import 'package:assorted_layout_widgets/assorted_layout_widgets.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/list_editor/widget_choise.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';

class BreadCrumbNavigator extends StatefulWidget {
  static GlobalKey keyBreadcrumb = GlobalKey(debugLabel: 'keyBreadcrumb');

  const BreadCrumbNavigator({super.key, required this.getList});
  final Function getList;

  @override
  State<StatefulWidget> createState() {
    return _BreadCrumbNavigatorState();
  }
}

// class BreadNode {
//   BreadNode({required this.name});
//   String name;
//   String? tooltip;
//   Function? onTap;
// }

const _textStyle = TextStyle(color: Colors.white, fontSize: 15);
const _textStyleDisable = TextStyle(color: Colors.grey, fontSize: 15);

class _BreadCrumbNavigatorState extends State<BreadCrumbNavigator>
    with WidgetHelper {
  @override
  Widget build(BuildContext context) {
    List<BreadNode> currentPathOnStack = [];
    List<BreadNode> listPath = widget.getList();
    int i = 0;
    for (var element in listPath) {
      currentPathOnStack.add(element..idx = i);
      i++;
    }

    List<Widget> widgets = [];
    int index = 0;
    for (BreadNode route in currentPathOnStack) {
      Widget? child;

      if (route.type == BreadNodeType.domain) {
        GlobalKey keyDomain = GlobalKey(debugLabel: 'keyDomain');
        child = InkWell(
          onTap: () {
            dialogBuilderBelow(
              context,
              WidgetChoise(
                model: currentCompany.listDomain,
                onSelected: (AttributInfo sel) {
                  prefs.setString("currentDomain", sel.masterID!);
                  currentCompany.listDomain.setCurrentAttr(sel);
                  Navigator.of(context).pop();

                  Future.delayed(Duration(milliseconds: 200)).then((timeStamp) {
                    // attend fermeture du popup
                    forceNewPage = 2;
                    // ignore: use_build_context_synchronously
                    context.pushReplacement(
                      '${route.path}?id=${currentCompany.currentNameSpace}',
                    );
                  });
                  //setState(() {});
                },
              ),
              keyDomain,
              Offset.zero,
              (BuildContext ctx) {},
            );
          },
          child: SizedBox(
            key: keyDomain,
            height: 18,
            child: Row(
              spacing: 5,
              children: [
                Icon(Icons.domain, size: 18),
                Text(
                  currentCompany.listDomain.selectedAttr?.info.name ?? '?',
                  style: _textStyle,
                ),
                Icon(Icons.arrow_drop_down, size: 20),
              ],
            ),
          ),
        );
      }

      Widget btn = _BreadButton(
        route.type,
        currentPathOnStack[index].settings.name ?? '',
        index == 0,
        route.type == BreadNodeType.domain ||
            (route.path != null || route.onTap != null),
        child: child,
      );

      if (route.onTap != null || route.path != null) {
        btn = InkWell(
          onTap: () {
            if (route.onTap != null) {
              route.onTap!();
            }
            if (route.path != null) {
              context.push(route.path!);
            }
          },
          child: btn,
        );
      }

      widgets.add(Tooltip(message: route.tooltip ?? 'help', child: btn));

      index++;
    }

    return RowSuper(
      mainAxisSize: MainAxisSize.min,
      innerDistance: -15,
      children: widgets,
    );
  }
}

enum BreadNodeType { widget, domain }

class BreadNode extends Route {
  BreadNode({
    super.settings,
    required this.type,
    this.icon,
    this.path,
    this.onTap,
  });
  int idx = 0;
  Icon? icon;
  BreadNodeType type;
  String? tooltip;
  String? path;
  Function? onTap;
}

class _BreadButton extends StatelessWidget {
  final String text;
  final bool isFirstButton;
  final BreadNodeType type;
  final Widget? child;

  final bool enable;

  // ignore: unused_element_parameter
  const _BreadButton(
    this.type,
    this.text,
    this.isFirstButton,
    this.enable, {
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: TriangleClipper(!isFirstButton),
      child: Container(
        color:
            type == BreadNodeType.domain
                ? Colors.blue
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
                style: enable ? _textStyle : _textStyleDisable,
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
