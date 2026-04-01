import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/feature/home/background_screen.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_layout.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';
import 'package:jsonschema/widget/widget_zoom_selector.dart';

mixin GenericPage {
  NavigationInfo? initNavigation(
    GoRouterState routerState,
    BuildContext context,
    PageInit? pageInit,
  );

  List<Widget> getDefaultActionModel() {
    return [
      WidgetSearchText(),
      Text('   Open factor '),
      WidgetZoomSelector(zoom: openFactor),
      // IconButton(
      //   icon: const Icon(Icons.search),
      //   tooltip: 'Rechercher',
      //   onPressed: () {
      //     // Action de recherche
      //   },
      // ),
      // IconButton(
      //   icon: const Icon(Icons.notifications),
      //   tooltip: 'Notifications',
      //   onPressed: () {
      //     // Action de notification
      //   },
      // ),
    ];
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

abstract class PageInit with GenericPage {}

// ignore: must_be_immutable
abstract class GenericPageStateless extends StatelessWidget with GenericPage {
  void setUrlPath(String path) {}
  String? getUrlPath() {
    return null;
  }

  const GenericPageStateless({super.key});

  bool isCacheValid(GoRouterState state, String uri, BuildContext context) {
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
  List<Widget> actions = [];
}
