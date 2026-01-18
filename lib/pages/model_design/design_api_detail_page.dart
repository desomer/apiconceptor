import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/feature/api/pan_api_editor.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';


// ignore: must_be_immutable
class CallAPIPageDetail extends GenericPageStateless {
  CallAPIPageDetail({super.key});
  String query = '';

  @override
  Widget build(BuildContext context) {
    return getBackground(2, PanApiEditor(idApi: query));
  }

  @override
  NavigationInfo initNavigation(
    GoRouterState routerState,
    BuildContext context,
    PageInit? pageInit,
  ) {
    query = routerState.uri.queryParameters['id']!;
    var goTo = GoTo();
    // goTo.initApi(query);


    return NavigationInfo()
      ..navLeft = [
        BreadNode(
          icon: const Icon(Icons.api_outlined),
          settings: const RouteSettings(name: 'API Definition'),
          type: BreadNodeType.widget,
          path: Pages.apiDetail.id(query)
        ),

        BreadNode(
          icon: const Icon(Icons.api_outlined),
          settings: const RouteSettings(name: 'API UI'),
          type: BreadNodeType.widget,
          path: Pages.apiUI.id(query)
        ),

      ]
      ..breadcrumbs = [
        BreadNode(
          settings: const RouteSettings(name: 'List API'),
          type: BreadNodeType.widget,
          path: Pages.api.urlpath,    
          onTap: () {
            context.pop();
          },                
        ),
        BreadNode(
          settings: const RouteSettings(name: 'Domain'),
          type: BreadNodeType.domain,
          path: Pages.api.urlpath,
        ),
        ...goTo.getBreadcrumbApi(query)
      ];
  }
}


  //  return NavigationInfo()..breadcrumbs = goTo.getBreadcrumbApi(query);
  
