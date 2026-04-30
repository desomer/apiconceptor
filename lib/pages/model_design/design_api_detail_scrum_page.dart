import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart' show GoRouterState, GoRouterHelper;
import 'package:jsonschema/core/api/call_api_manager.dart';
import 'package:jsonschema/core/api/widget_api_helper.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/feature/documentation/pan_scrum.dart';
import 'package:jsonschema/pages/model_design/design_api_detail_page.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';

// ignore: must_be_immutable
class DesignApiDetailScrumPage extends GenericPageStateless {
  DesignApiDetailScrumPage({super.key});
  String query = '';
  late WidgetAPIHelper requestHelper;

  @override
  Widget build(BuildContext context) {
    var attr = currentCompany.listAPI!.getNodeByMasterIdPath(query)!;
    currentCompany.listAPI!.selectedAttr = attr;

    requestHelper = WidgetAPIHelper(
      apiNode: attr,
      apiCallInfo: getAPICall(
        currentCompany.currentNameSpace,
        currentCompany.listAPI!.selectedAttr!,
      ),
    );
    return PanScrumModel(mode: ScrumModeEnum.api, requestHelper: requestHelper);
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
    var goTo = ApiRequestNavigator();

    return NavigationInfo()
      ..navLeft = getLeftNavApi(query)
      ..breadcrumbs = [
        BreadNode(
          settings: const RouteSettings(name: 'Domain'),
          type: BreadNodeType.domain,
          path: Pages.api.urlpath,
        ),
        BreadNode(
          settings: const RouteSettings(name: 'List API'),
          type: BreadNodeType.widget,
          path: Pages.api.urlpath,
          onTap: () {
            context.pop();
          },
        ),
        ...goTo.getBreadcrumbApi(query),
      ];
  }
}
