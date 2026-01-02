import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/feature/home/background_screen.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';

mixin GenericPage {
  NavigationInfo? initNavigation(
    GoRouterState routerState,
    BuildContext context,
    PageInit? pageInit,
  );

  Widget getBackground(int num, Widget child) {
    return Stack(
      children: [
        BackgroundScreen(num: num),
        Container(color: Colors.black87, child: child),
      ],
    );
  }
}

abstract class PageInit with GenericPage {}

// ignore: must_be_immutable
abstract class GenericPageStateless extends StatelessWidget with GenericPage {
  void setUrlPath(String path) {}
  String? getUrlPath() {
    return null;
  }

  const GenericPageStateless({super.key});

  bool isCacheValid(GoRouterState state, String uri) {
    return true;
  }
}

// ignore: must_be_immutable
abstract class GenericPageStateful extends StatefulWidget with GenericPage {
  const GenericPageStateful({super.key});
}

abstract class GenericPageState<T extends StatefulWidget> extends State<T>
    with RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute? route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPush() {
    print('🟢 DetailsPage affichée $this');
  }

  @override
  void didPop() {
    print('🔴 DetailsPage quittée $this');
  }

  @override
  void didPopNext() {
    print('🔁 Retour sur DetailsPage $this');
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  Widget getBackground(int num, Widget child) {
    return Stack(
      children: [
        BackgroundScreen(num: num),
        Container(color: Colors.black87, child: child),
      ],
    );
  }
}

class NavigationInfo {
  List<BreadNode> breadcrumbs = [];
  List<BreadNode> navLeft = [];
}
