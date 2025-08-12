import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/api/pan_api_selector.dart';
import 'package:jsonschema/feature/api/pan_api_trashcan.dart';
import 'package:jsonschema/json_browser/browse_api.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';
import 'package:jsonschema/widget/widget_show_error.dart';
import 'package:jsonschema/widget/widget_tab.dart';
import 'package:jsonschema/widget_state/state_api.dart';
import 'package:yaml/yaml.dart';

class DesignAPIPage extends GenericPageStateless {
  const DesignAPIPage({super.key});

  //final GlobalKey keySel = GlobalKey();

  @override
  Widget build(BuildContext context) {
    var panAPISelector = PanAPISelector(
      //   key: keySel,
      getSchemaFct: () async {
        await Future.delayed(Duration(milliseconds: gotoDelay));

        currentCompany.listAPI = ModelSchema(
          category: Category.allApi,
          headerName: 'API Route Path',
          id: 'api',
          infoManager: InfoManagerAPI(),
        );
        currentCompany.listAPI!.namespace = currentCompany.currentNameSpace;

        if (withBdd) {
          try {
            await currentCompany.listAPI!.loadYamlAndProperties(
              cache: false,
              withProperties: true,
            );
            BrowseAPI().browse(currentCompany.listAPI!, false);
          } on Exception catch (e) {
            print("$e");
            startError.add("$e");
          }
        }

        return currentCompany.listAPI!;
      },
    );

    return getBackground(
      2,
      WidgetTab(
        key: stateApi.keyTab,
        onInitController: (TabController tab) {},
        listTab: [Tab(text: 'API Browser'), Tab(text: 'Trashcan')],
        listTabCont: [
          Column(
            children: [
              //PanApiActionHub(selector: panAPISelector),
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
        ),
      ];
  }
}
