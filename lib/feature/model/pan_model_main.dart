import 'package:flutter/material.dart';
import 'package:jsonschema/authorization_manager.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/model/pan_model_action_hub.dart';
import 'package:jsonschema/feature/model/pan_model_selector.dart';
import 'package:jsonschema/feature/model/pan_model_trashcan.dart';
import 'package:jsonschema/json_browser/browse_api.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_md_doc.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget/widget_tab.dart';
import 'package:yaml/yaml.dart';

class WidgetModelMain extends StatefulWidget with WidgetHelper {
  const WidgetModelMain({super.key});

  @override
  State<WidgetModelMain> createState() => _WidgetModelMainState();
}

class _WidgetModelMainState extends State<WidgetModelMain> {
  @override
  Widget build(BuildContext context) {
    return getBrowser(context);
  }

  Widget getBrowser(BuildContext context) {
    PanModelSelector panModelSelector = PanModelSelector(
      type: TypeModelSelector.model,
      getSchemaFct: () async {
        await Future.delayed(Duration(milliseconds: gotoDelay));
        currentCompany.listModel = await loadSchema(
          TypeMD.listmodel,
          'model',
          'Business models',
          TypeModelBreadcrumb.businessmodel,
          namespace: currentCompany.currentNameSpace,
          config: BrowserConfig(),
        );
        currentCompany.listModel!.isReadOnlyModel =
            isDomainAllowed(currentCompany.currentNameSpace) == false;
        return currentCompany.listModel!;
      },
    );

    // pour import
    // stateModel.panModelSelector = panModelSelector;

    return Column(
      children: [
        PanModelActionHub(panModelSelector: panModelSelector),
        Expanded(
          child: WidgetTab(
            onInitController: (TabController tab) {
              // stateModel.tabSubModel = tab;
              tab.addListener(() {
                // stateModel.setTab();
              });
            },
            listTab: [
              Tab(text: 'Business models'),
              //  Tab(text: 'ORM Entities'),
              Tab(text: 'Trashcan'),
            ],
            listTabCont: [
              panModelSelector,
              // KeepAliveWidget(child: stateModel.panDtoSelector),
              // KeepAliveWidget(child: stateModel.panComponentSelector),
              getTrashcan(context),
            ],
            heightTab: 40,
          ),
        ),
      ],
    );
  }

  Widget getTrashcan(BuildContext context) {
    return PanModelTrashcan(
      getSchemaFct: () async {
        //getModelFct: () async {
        var trash = ModelSchema(
          category: Category.allModel,
          headerName: 'Trash models',
          id: 'model',
          infoManager: InfoManagerTrash(),
          refDomain: currentCompany.listModel,
        );
        trash.withHistory = false;
        trash.autoSaveProperties = false;

        await bddStorage.getTrashSupabase(trash, trash.id, 'trash');

        StringBuffer yamlTrash = StringBuffer();
        yamlTrash.writeln('trash:');
        for (var trashElem in trash.mapInfoByTreePath.entries) {
          yamlTrash.writeln(
            ' ${trashElem.value.masterID} : ${trashElem.value.path}',
          );
        }

        // trash.mapInfoByTreePath.clear();

        // await bddStorage.getTrashSupabase(
        //   trash,
        //   'component',
        //   'trash component',
        // );

        // yamlTrash.writeln('trash component:');
        // for (var trashElem in trash.mapInfoByTreePath.entries) {
        //   yamlTrash.writeln(
        //     ' ${trashElem.value.masterID} : ${trashElem.value.path}',
        //   );
        // }
        // trash.mapInfoByTreePath.clear();

        // await bddStorage.getTrashSupabase(trash, 'request', 'trash request');

        // yamlTrash.writeln('trash request:');
        // for (var trashElem in trash.mapInfoByTreePath.entries) {
        //   yamlTrash.writeln(
        //     ' ${trashElem.value.masterID} : ${trashElem.value.path}',
        //   );
        // }
        // trash.mapInfoByTreePath.clear();

        trash.mapModelYaml = loadYaml(yamlTrash.toString(), recover: true);

        return trash;
      },
    );
  }
}
