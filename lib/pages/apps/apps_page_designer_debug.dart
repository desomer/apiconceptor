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
  const AppsPageDesignerDebug({super.key});

  @override
  bool isCacheValid(GoRouterState state, String uri) {
    return false;
  }

  String prettyPrintJson(dynamic input) {
    const JsonEncoder encoder = JsonEncoder.withIndent('   ');
    return encoder.convert(input);
  }

  @override
  Widget build(BuildContext context) {
    String keyFactory = 'factoryName';
    WidgetFactory f = getFactory(keyFactory);

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
