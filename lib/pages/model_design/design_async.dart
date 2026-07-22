import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart' show GoRouterState;
import 'package:jsonschema/feature/async_api/pan_async_selector.dart';
import 'package:jsonschema/feature/home/background_screen.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';
import 'package:jsonschema/widget/widget_glowing_halo.dart';

class DesignAsyncPage extends GenericPageStateless {
  const DesignAsyncPage({super.key, this.state});
  final GoRouterState? state;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const BackgroundScreen(num: 1),
        Container(
          color: Colors.black87,
          child: Column(
            children: [
              getAction(),
              Expanded(
                child: PanAsyncSelector(
                  key: ValueKey(state?.uri.toString() ?? ''),
                  getSchemaFct: () async {
                    await Future.delayed(Duration(milliseconds: gotoDelay));
                    await loadAsync(currentCompany.currentNameSpace, false);
                    return currentCompany.listAsync!;
                  },
                  type: TypeAsyncSelector.model,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget getAction() {
    var style = ElevatedButton.styleFrom(
      backgroundColor: Colors.blueGrey.shade800,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5), // button's shape
      ),
      elevation: 5, // button's elevation when it's pressed
    );

    return SizedBox(
      height: 30,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        spacing: 10,
        children: [
          SizedBox(width: 1),
          GlowingHalo(
            child: ElevatedButton.icon(
              icon: Icon(Icons.wifi),
              onPressed: () {
                // if (currentCompany.listAPI != null) {
                //   selector.showImportDialog(context);
                // }
              },
              style: style,
              label: Text('New Channel'),
            ),
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.storage_rounded),
            onPressed: () {
              // if (currentCompany.listAPI != null) {
              //   selector.showSwaggerDialog(context);
              // }
            },
            style: style,
            label: Text('New Bucket'),
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.create_new_folder_outlined),
            onPressed: () {
              // if (currentCompany.listAPI != null) {
              //   selector.showSwaggerDialog(context);
              // }
            },
            style: style,
            label: Text('New Ftp'),
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.schedule),
            onPressed: () {
              // if (currentCompany.listAPI != null) {
              //   selector.showSwaggerDialog(context);
              // }
            },
            style: style,
            label: Text('New Cron'),
          ),
        ],
      ),
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
    GlobalKey keyPage,
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
          settings: const RouteSettings(name: 'async events'),
          type: BreadNodeType.widget,
          path: Pages.models.urlpath,
        ),

        // BreadNode(
        //   icon: const Icon(Icons.dataset_rounded),
        //   settings: const RouteSettings(name: 'List ORM'),
        //   type: BreadNodeType.widget,
        // ),

        // BreadNode(
        //   icon: const Icon(Icons.bubble_chart),
        //   settings: const RouteSettings(name: 'Graph view'),
        //   type: BreadNodeType.widget,
        //   path: Pages.modelGraph.urlpath,
        // ),
      ]
      ..breadcrumbs = [
        BreadNode(
          settings: const RouteSettings(name: 'Domain'),
          type: BreadNodeType.domain,
          path: Pages.asyncApi.urlpath,
        ),
        // BreadNode(
        //   settings: const RouteSettings(name: 'List model'),
        //   type: BreadNodeType.widget,
        // ),
      ]
    //..actions = getDefaultActionModel()
    ;
  }
}
