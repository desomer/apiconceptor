import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart' show GoRouterState;
import 'package:jsonschema/feature/home/background_screen.dart';
import 'package:jsonschema/feature/model/pan_model_main.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';

class DesignModelPage extends GenericPageStateless {
  const DesignModelPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const BackgroundScreen(num: 1),
        Container(color: Colors.black87, child: WidgetModelMain()),
      ],
    );
  }

  // Widget build2(BuildContext context) {
  //   return WidgetTab(
  //     key: stateModel.keyTab,
  //     onInitController: (TabController tab) {
  //       stateModel.tabModel = tab;
  //       tab.addListener(() {
  //         if (tab.index == 0) {
  //           stateModel.setTab();
  //         }
  //       });
  //     },
  //     tabDisable: stateModel.tabDisable,
  //     listTab: [
  //       Tab(text: 'Models Browser'),
  //       Tab(text: 'Model Editor'),
  //       Tab(text: 'Json schema'),
  //     ],
  //     listTabCont: [
  //       Column(
  //         children: [
  //           PanModelActionHub(),
  //           Expanded(child: KeepAliveWidget(child: WidgetModelMain())),
  //         ],
  //       ),
  //       KeepAliveWidget(
  //         child: WidgetModelEditor(key: stateModel.keyModelEditor),
  //       ),
  //       WidgetJsonValidator(),
  //     ],
  //     heightTab: 40,
  //   );
  // }

  @override
  NavigationInfo initNavigation(
    GoRouterState routerState,
    BuildContext context,
    PageInit? pageInit,
  ) {
    String query = routerState.uri.queryParameters['id'] ?? '? ';
    print("query model: $query");
    //var goTo = GoTo();
    // goTo.initApi(query);
    // goTo.getBreadcrumbApi(query);

    return NavigationInfo()
      ..navLeft = [
        BreadNode(
          icon: const Icon(Icons.data_object),
          settings: const RouteSettings(name: 'List model'),
          type: BreadNodeType.widget,
          path: Pages.models.urlpath,
        ),

        BreadNode(
          icon: const Icon(Icons.dataset_rounded),
          settings: const RouteSettings(name: 'List ORM'),
          type: BreadNodeType.widget,
        ),

        BreadNode(
          icon: const Icon(Icons.bubble_chart),
          settings: const RouteSettings(name: 'Graph view'),
          type: BreadNodeType.widget,
          path: Pages.modelGraph.urlpath,
        ),
      ]
      ..breadcrumbs = [
        BreadNode(
          settings: const RouteSettings(name: 'Domain'),
          type: BreadNodeType.domain,
          path: Pages.models.urlpath,
        ),
        BreadNode(
          settings: const RouteSettings(name: 'List model'),
          type: BreadNodeType.widget,
        ),
      ];
  }
}
