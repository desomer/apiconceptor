import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/core/api/call_api_manager.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/api/widget_request_helper.dart';
import 'package:jsonschema/feature/transform/pan_response_viewer.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';

// ignore: must_be_immutable
class CallAPIPageDetailUI extends GenericPageStateless {
  CallAPIPageDetailUI({super.key});
  String query = '';
  late WidgetRequestHelper requestHelper;

  @override
  Widget build(BuildContext context) {
    var attr = currentCompany.listAPI!.nodeByMasterId[query]!;
    currentCompany.listAPI!.selectedAttr = attr;

    requestHelper = WidgetRequestHelper(
      apiNode: attr,
      apiCallInfo: getAPICall(
        currentCompany.currentNameSpace,
        currentCompany.listAPI!.selectedAttr!,
      ),
    );

    return PanResponseViewer(requestHelper: requestHelper);
  }

  APICallManager getAPICall(String namespace, NodeAttribut attr) {
    String httpOpe = attr.info.name.toLowerCase();
    var apiCallInfo = APICallManager(
      namespace: namespace,
      attrApi: attr.info,
      httpOperation: httpOpe,
    );
    return apiCallInfo;
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
          path: Pages.apiDetail.id(query),
        ),

        BreadNode(
          icon: const Icon(Icons.api_outlined),
          settings: const RouteSettings(name: 'API UI'),
          type: BreadNodeType.widget,
          path: Pages.apiUI.id(query),
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
        ...goTo.getBreadcrumbApi(query),
      ];
  }
}


  //  return NavigationInfo()..breadcrumbs = goTo.getBreadcrumbApi(query);
  
