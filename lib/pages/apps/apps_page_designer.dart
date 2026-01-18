import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart' show GoRouterState;
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/feature/design/page_designer.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';

// ignore: must_be_immutable
class AppsPageDesigner extends GenericPageStateless {
  AppsPageDesigner({super.key, required this.mode});
  String query = '';
  bool isLoading = false;
  Widget? cache;
  String? url;
  final DesignMode mode;

  @override
  bool isCacheValid(GoRouterState state, String uri) {
    String keyFactory = 'factoryName';
    WidgetFactory f = getFactory(keyFactory);
    f.listPropsEditor = [];
    f.rootCtx = null;
    f.onStarted = () {
      f.onStarted = null;
      Future.delayed(Duration(milliseconds: 1000), () {
        // ignore: invalid_use_of_protected_member
        f.pageDesignerKey.currentState?.setState(() {});
        // ignore: invalid_use_of_protected_member
        f.rootCtx?.widgetState?.setState(() {});
        if (f.isModeDesigner()) {
          SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
            f.rootCtx?.selectOnDesigner();
          });
        }
      });
    };

    return true;
  }

  @override
  Widget build(BuildContext context) {
    String keyFactory = 'factoryName';
    WidgetFactory f = getFactory(keyFactory);
    f.initAllGlobalKeys();

    return PageDesigner(key: f.pageDesignerKey, mode: mode, factory: f);
  }

  WidgetFactory getFactory(String keyFactory) {
    WidgetFactory? f = cacheLinkPage.get(keyFactory);
    if (f == null) {
      f = WidgetFactory();
      cacheLinkPage.put(keyFactory, f);
    }
    return f;
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
        BreadNode(
          icon: const Icon(Icons.bug_report),
          settings: const RouteSettings(name: 'Debug app'),
          type: BreadNodeType.widget,
          path: Pages.pageDebug.urlpath,
        ),
      ];
  }
}
