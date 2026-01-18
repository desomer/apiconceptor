import 'package:flutter/material.dart';
import 'package:jsonschema/authorization_manager.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
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

class WidgetModelMain extends StatelessWidget with WidgetHelper {
  const WidgetModelMain({super.key});

  @override
  Widget build(BuildContext context) {
    return getBrowser(context);
  }

  Widget getBrowser(BuildContext context) {
    PanModelSelector panModelSelector = PanModelSelector(
      getSchemaFct: () async {
        await Future.delayed(Duration(milliseconds: gotoDelay));
        currentCompany.listModel = await loadSchema(
          TypeMD.listmodel,
          'model',
          'Business models',
          TypeModelBreadcrumb.businessmodel,
          namespace: currentCompany.currentNameSpace,
        );
        return currentCompany.listModel!;
      },
    );

    // pour import
    // stateModel.panModelSelector = panModelSelector;

    return Column(
      children: [
        PanModelActionHub(panModelSelector: panModelSelector),
        Expanded(child: WidgetTab(
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
        )),
      ],
    );
  }

  Widget getTrashcan(BuildContext context) {
    return PanModelTrashcan(
      getModelFct: () async {
        var trash = ModelSchema(
          category: Category.allModel,
          headerName: 'All models',
          id: 'model',
          infoManager: InfoManagerTrashAPI(),
          ref: currentCompany.listModel,
        );
        trash.autoSaveProperties = false;

        await bddStorage.getTrashSupabase(trash, 'model', 'trash model');

        StringBuffer yamlTrash = StringBuffer();
        yamlTrash.writeln('trash model:');
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
