import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart' show GoRouterState, GoRouterHelper;
import 'package:jsonschema/feature/documentation/pan_scrum.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';


class DesignModelDetailScrumPage extends GenericPageStateless {
  const DesignModelDetailScrumPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PanScrum();
  }

  @override
  NavigationInfo initNavigation(
    GoRouterState routerState,
    BuildContext context,
    PageInit? pageInit
  ) {
    return NavigationInfo()
      ..navLeft = [
        BreadNode(
          icon: const Icon(Icons.data_object),
          settings: const RouteSettings(name: 'Design model'),
          type: BreadNodeType.widget,
          path: Pages.modelDetail.urlpath
        ),

        BreadNode(
          icon: const Icon(Icons.verified),
          settings: const RouteSettings(name: 'Json schema'),
          type: BreadNodeType.widget,
          path: Pages.modelJsonSchema.urlpath
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
          path: Pages.modelScrum.urlpath
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
          path: Pages.models.urlpath
        ),
        BreadNode(
          settings: RouteSettings(
            name: '${currentCompany.currentModel?.headerName}',
          ),
          type: BreadNodeType.widget,
        ),
      ];
  }
}
