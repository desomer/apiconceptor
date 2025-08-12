import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart' show GoRouterState, GoRouterHelper;
import 'package:jsonschema/feature/home/background_screen.dart';
import 'package:jsonschema/feature/model/pan_model_editor.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';

// ignore: must_be_immutable
class DesignModelDetailPage extends GenericPageStateless {
  DesignModelDetailPage({super.key});
  String query = '';

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [const BackgroundScreen(num: 1), PanModelEditorMain(idModel: query)],
    );
  }

  @override
  NavigationInfo initNavigation(
    GoRouterState routerState,
    BuildContext context,
    PageInit? pageInit,
  ) {
    query = routerState.uri.queryParameters['id']!;
    var attr = currentCompany.listModel!.nodeByMasterId[query]!;

    return NavigationInfo()
      ..navLeft = [
        BreadNode(
          icon: const Icon(Icons.data_object),
          settings: const RouteSettings(name: 'Design model'),
          type: BreadNodeType.widget,
          path: Pages.modelDetail.urlpath,
        ),

        BreadNode(
          icon: const Icon(Icons.verified),
          settings: const RouteSettings(name: 'Json schema'),
          type: BreadNodeType.widget,
          path: Pages.modelJsonSchema.urlpath,
        ),

        BreadNode(
          icon: const Icon(Icons.bubble_chart),
          settings: const RouteSettings(name: 'Graph view'),
          type: BreadNodeType.widget,
        ),

        BreadNode(
          icon: const Icon(Icons.airplane_ticket),
          settings: const RouteSettings(name: 'Scrum'),
          type: BreadNodeType.widget,
          path: Pages.modelScrum.urlpath,
        ),
      ]
      ..breadcrumbs = [
        BreadNode(
          settings: const RouteSettings(name: 'List model'),
          type: BreadNodeType.widget,
          onTap: () {
            context.pop();
          },
        ),
        BreadNode(
          settings: const RouteSettings(name: 'Domain'),
          type: BreadNodeType.domain,
        ),
        BreadNode(
          settings: RouteSettings(
            name: attr.info.name,
          ),
          type: BreadNodeType.widget,
        ),
      ];
  }
}
