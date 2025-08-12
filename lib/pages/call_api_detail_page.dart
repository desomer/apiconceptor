import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/feature/api/pan_api_editor.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';

// ignore: must_be_immutable
class CallAPIPageDetail extends GenericPageStateless {
  CallAPIPageDetail({super.key});
  String query = '';

  @override
  Widget build(BuildContext context) {
    return getBackground(2, PanApiEditor(key: keyAPIEditor, idApi: query));
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

    return NavigationInfo()..breadcrumbs = goTo.getBreadcrumbApi(query);
  }
}
