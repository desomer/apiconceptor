import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart' show GoRouterState;
import 'package:highlight/languages/json.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';

// ignore: must_be_immutable
class AppsPageDesignerDebug extends GenericPageStateless {
  AppsPageDesignerDebug({super.key});
  String query = 'factoryName';

  @override
  bool isCacheValid(GoRouterState state, String uri, BuildContext context) {
    return false;
  }

  String prettyPrintJson(dynamic input) {
    const JsonEncoder encoder = JsonEncoder.withIndent('   ');
    return encoder.convert(input);
  }

  @override
  Widget build(BuildContext context) {
    String keyFactory = query;
    WidgetFactory f = getFactory(keyFactory, context);

    return TextEditor(
      config: CodeEditorConfig(
        readOnly: true,
        mode: json,
        getText: () => prettyPrintJson(f.appData),
        onChange: (String json, CodeEditorConfig config) {
          // Handle changes if needed
        },
        notifError: ValueNotifier(''),
      ),
      header: 'Parameters',
    );
  }

  WidgetFactory getFactory(String keyFactory, BuildContext context) {
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
          path: Pages.pageDesigner.id(query),
        ),
        BreadNode(
          icon: const Icon(Icons.play_arrow_rounded),
          settings: const RouteSettings(name: 'Test Page'),
          type: BreadNodeType.widget,
          path: Pages.pageViewer.id(query),
        ),
        BreadNode(
          icon: const Icon(Icons.bug_report),
          settings: const RouteSettings(name: 'Debug app'),
          type: BreadNodeType.widget,
          path: Pages.pageDebug.id(query),
        ),
      ];
  }
}
