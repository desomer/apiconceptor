import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/authorization_manager.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/api/pan_api_action_hub.dart';
import 'package:jsonschema/feature/api/pan_api_selector.dart';
import 'package:jsonschema/feature/api/pan_api_trashcan.dart';
import 'package:jsonschema/json_browser/browse_api.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';
import 'package:jsonschema/widget/widget_tab.dart';
import 'package:yaml/yaml.dart';

class DesignAPIPage extends GenericPageStateless {
  const DesignAPIPage({super.key});

  //final GlobalKey keySel = GlobalKey();

  @override
  Widget build(BuildContext context) {
    var panAPISelector = PanAPISelector(
      browseOnly: false,
      onSelModel: null,
      getSchemaFct: () async {
        await Future.delayed(Duration(milliseconds: gotoDelay));

        await loadAllAPIGlobal();
        return currentCompany.listAPI!;
      },
    );

    return getBackground(
      2,
      WidgetTab(
        onInitController: (TabController tab) {
          //stateApi.tabApi = tab;
        },
        listTab: [Tab(text: 'API Browser'), Tab(text: 'Trashcan')],
        listTabCont: [
          Column(
            children: [
              PanApiActionHub(selector: panAPISelector),
              Expanded(child: panAPISelector),
            ],
          ),
          PanAPITrashcan(
            getModelFct: () async {
              var trash = ModelSchema(
                category: Category.allApi,
                headerName: 'All trash',
                id: 'api',
                infoManager: InfoManagerTrashAPI(),
                ref: null,
              );
              trash.autoSaveProperties = false;

              await bddStorage.getTrashSupabase(trash, trash.id, 'trash');

              StringBuffer yamlTrash = StringBuffer();
              yamlTrash.writeln('trash:');
              for (var trashElem in trash.mapInfoByTreePath.entries) {
                yamlTrash.writeln(
                  ' ${trashElem.value.masterID} : ${trashElem.value.path}',
                );
              }
              trash.mapInfoByTreePath.clear();
              // Swagger2Schema().import();
              // print(yamlTrash.toString());
              trash.mapModelYaml = loadYaml(
                yamlTrash.toString(),
                recover: true,
              );

              return trash;
            },
          ),
        ],
        heightTab: 40,
      ),
    );
  }

  @override
  NavigationInfo initNavigation(
    GoRouterState routerState,
    BuildContext context,
    PageInit? pageInit,
  ) {
    return NavigationInfo()
      ..navLeft = [
        BreadNode(
          icon: const Icon(Icons.api_outlined),
          settings: const RouteSettings(name: 'API Tree'),
          type: BreadNodeType.widget,
          path: Pages.api.urlpath,
        ),

        BreadNode(
          icon: const Icon(Icons.tag),
          settings: const RouteSettings(name: 'API by tag'),
          type: BreadNodeType.widget,
        ),

        BreadNode(
          icon: const Icon(Icons.bubble_chart),
          settings: const RouteSettings(name: 'Graph view'),
          type: BreadNodeType.widget,
        ),
      ]
      ..breadcrumbs = [
        BreadNode(
          settings: const RouteSettings(name: 'List API'),
          type: BreadNodeType.widget,
        ),
        BreadNode(
          settings: const RouteSettings(name: 'Domain'),
          type: BreadNodeType.domain,
          path: Pages.api.urlpath,
        ),
      ];
  }
}
