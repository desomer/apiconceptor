import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart' show GoRouterState;
import 'package:jsonschema/core/designer/cw_factory.dart';
import 'package:jsonschema/core/util.dart';
import 'package:jsonschema/feature/design/page_designer.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';

LruCache cacheLinkPage = LruCache(5);

// ignore: must_be_immutable
class AppsPageDesigner extends GenericPageStateless {
  AppsPageDesigner({super.key, required this.mode});
  String query = '';
  bool isLoading = false;
  Widget? cache;
  String? url;
  final DesignMode mode;

  @override
  Widget build(BuildContext context) {
    String key = 'f1';
    WidgetFactory? f;
    f = cacheLinkPage.get(key);
    if (f == null) {
      f = WidgetFactory();
      cacheLinkPage.put(key, f);
    }
    return PageDesigner(mode: mode, factory: f);
  }

  @override
  NavigationInfo? initNavigation(
    GoRouterState routerState,
    BuildContext context,
    PageInit? pageInit,
  ) {
    query = routerState.uri.queryParameters['id'] ?? "";
    return NavigationInfo()
      ..navLeft = [
        BreadNode(
          icon: const Icon(Icons.edit),
          settings: const RouteSettings(name: 'Edit Page'),
          type: BreadNodeType.widget,
          path: Pages.pageDesigner.urlpath,
        ),
        BreadNode(
          icon: const Icon(Icons.play_arrow_rounded),
          settings: const RouteSettings(name: 'Test Page'),
          type: BreadNodeType.widget,
          path: Pages.pageViewer.urlpath,
        ),
      ];
  }
}
