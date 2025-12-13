import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart' show GoRouterState;
import 'package:jsonschema/core/util.dart';
import 'package:jsonschema/feature/design/page_designer.dart';
import 'package:jsonschema/pages/router_generic_page.dart';

LruCache cacheLinkPage = LruCache(5);

// ignore: must_be_immutable
class AppsPageDesigner extends GenericPageStateless {
  AppsPageDesigner({super.key});
  String query = '';
  bool isLoading = false;
  Widget? cache;
  String? url;

  @override
  Widget build(BuildContext context) {
    return PageDesigner();
  }

  @override
  NavigationInfo? initNavigation(
    GoRouterState routerState,
    BuildContext context,
    PageInit? pageInit,
  ) {
    query = routerState.uri.queryParameters['id'] ?? "";
    return NavigationInfo();
  }
}
