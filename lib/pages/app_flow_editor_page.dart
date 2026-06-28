import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/widget/miro_like/widget_miro_like.dart';

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

    return NavigationInfo();
  }
}
