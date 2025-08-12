import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart' show GoRouterState, GoRouterHelper;
import 'package:jsonschema/feature/model/pan_model_json_validator.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';


class DesignModelDetailJsonPage extends GenericPageStateless {
  const DesignModelDetailJsonPage({super.key});

  @override
  Widget build(BuildContext context) {
    return WidgetJsonValidator();
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
            name: '${currentCompany.currentModel?.headerName}',
          ),
          type: BreadNodeType.widget,
        ),
      ];
  }
}
