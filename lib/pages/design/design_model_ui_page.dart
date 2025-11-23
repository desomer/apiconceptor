import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart' show GoRouterState;
import 'package:jsonschema/feature/transform/pan_model_viewer.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';

// ignore: must_be_immutable
class DesignModelUIPage extends GenericPageStateless {
  DesignModelUIPage({super.key});
  String model = '';

  @override
  Widget build(BuildContext context) {
    return PanContentViewer(masterIdModel: model);
  }

  @override
  NavigationInfo initNavigation(
    GoRouterState routerState,
    BuildContext context,
    PageInit? pageInit,
  ) {
    model =
        routerState.uri.queryParameters['id'] ??
        currentCompany.currentModel!.id;
    var attr = currentCompany.listModel!.nodeByMasterId[model];
    var name = attr?.info.name;

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
          icon: const Icon(Icons.devices),
          settings: const RouteSettings(name: 'UI Design'),
          type: BreadNodeType.widget,
          path: Pages.modelUI.urlpath,
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
          path: Pages.models.urlpath,
        ),
        BreadNode(
          settings: const RouteSettings(name: 'Domain'),
          type: BreadNodeType.domain,
          path: Pages.models.urlpath,
        ),
        BreadNode(
          settings: RouteSettings(name: name),
          type: BreadNodeType.widget,
        ),
      ];
  }
}
