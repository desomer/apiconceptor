import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/miro_like/widget_miro_like.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';

// ignore: must_be_immutable
class AppFlowEditorPage extends GenericPageStateless {
  AppFlowEditorPage({super.key});
  String? query;

  @override
  Widget build(BuildContext context) {
    return MiroLikeWidget(query: query);
  }

  @override
  NavigationInfo initNavigation(
    GoRouterState routerState,
    BuildContext context,
    GlobalKey keyPage,
    PageInit? pageInit,
  ) {
    query = routerState.uri.queryParameters['id'];

    var flow = currentCompany.currentFlow?.nodeByMasterId[query];
    String flowName = flow?.firstOrNull?.info.name ?? 'Application flow';
    String? flowTitle = flow?.firstOrNull?.info.properties?['title'];

    return NavigationInfo()
      ..breadcrumbs = [
        BreadNode(
          settings: const RouteSettings(name: 'List apps flow'),
          type: BreadNodeType.widget,
          path: Pages.appFlow.urlpath,
        ),        
        BreadNode(
          icon: const Icon(Icons.account_tree_outlined),
          settings: RouteSettings(name: flowName),
          type: BreadNodeType.widget,
        ),
        if (flowTitle != null)
          BreadNode(
            settings: RouteSettings(name: flowTitle),
            type: BreadNodeType.widget,
          ),
      ];
  }
}
