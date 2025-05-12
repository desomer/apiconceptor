import 'package:flutter/material.dart';
import 'package:highlight/languages/yaml.dart' show yaml;
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/editor/cell_prop_editor.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/json_browser/export2json_schema.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/pan_api_editor.dart';
import 'package:jsonschema/widget/json_editor/widget_json_tree.dart';
import 'package:jsonschema/widget/widget_keep_alive.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/editor/code_editor.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget/widget_tab.dart';
import 'package:jsonschema/widget_state/state_api.dart';
import 'package:yaml/yaml.dart';

class PanAPISelector extends StatelessWidget with WidgetModelHelper {
  const PanAPISelector({super.key});

  @override
  Widget build(BuildContext context) {
    return getBrowser(context);
  }

  Widget getBrowser(BuildContext context) {
    getJsonYaml() {
      return currentCompany.listAPI!.modelYaml;
    }

    var model = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 500,
          height: double.infinity,
          child: getStructureModel(),
        ),
        Expanded(
          child: JsonEditor(
            key: stateApi.keyListAPIInfo,
            config:
                JsonTreeConfig(
                    getModel: () => currentCompany.listAPI!,
                    onTap: (NodeAttribut node) {
                      goToAPI(node);
                    },
                  )
                  ..widthTree = 500
                  ..getJson = getJsonYaml
                  ..getRow = getWidgetModelInfo,
          ),
        ),
      ],
    );

    return WidgetTab(
      listTab: [
        Tab(text: 'API'),
        Tab(text: 'Proxy Mock'),
        Tab(text: 'Proxy random error'),
      ],
      listTabCont: [KeepAliveWidget(child: model), Container(), Container()],
      heightTab: 40,
    );
  }

  Widget getWidgetModelInfo(NodeAttribut attr, ModelSchemaDetail schema) {
    if (attr.info.type == 'root') {
      return Container(height: rowHeight);
    }

    List<Widget> row = [SizedBox(width: 10)];
    row.add(
      CellEditor(
        inArray: true,
        key: ValueKey('${attr.hashCode}#summary'),
        acces: ModelAccessorAttr(
          info: attr.info,
          schema: currentCompany.listAPI!,
          propName: 'summary',
        ),
      ),
    );

    //addWidgetMasterId(attr, row);

    if (attr.info.type == 'api') {
      row.add(
        TextButton.icon(
          onPressed: () async {
            await goToAPI(attr);
          },
          label: Icon(Icons.remove_red_eye),
        ),
      );
      row.add(
        TextButton.icon(
          icon: Icon(Icons.import_export),
          onPressed: () async {
            if (attr.info.type == 'api') {
              var key = attr.info.properties![constMasterID];
              var model = ModelSchemaDetail(
                type: YamlType.api,
                name: attr.info.name,
                id: key,
                infoManager: InfoManagerAPIParam(),
              );
              await model.loadYamlAndProperties(cache: false);
              await ExportJsonSchema2clipboard().doExport(model);
            }
          },
          label: Text('Json schemas'),
        ),
      );
    }

    var ret = SizedBox(
      height: rowHeight,
      child: InkWell(
        onDoubleTap: () async {
          await goToAPI(attr);
        },
        child: Card(
          key: ObjectKey(attr),
          margin: EdgeInsets.all(1),
          child: Row(children: row),
        ),
      ),
    );
    attr.info.cache = ret;
    return ret;
  }

  Future<void> goToAPI(NodeAttribut attr) async {
    if (attr.info.type == 'api') {
      stateApi.tabDisable.clear();
      // ignore: invalid_use_of_protected_member
      stateApi.keyTab.currentState?.setState(() {});

      NodeAttribut? n = attr.parent;
      var modelPath = [];
      while (n != null) {
        if (n.parent != null) {
          modelPath.insert(0, n.info.name);
        }

        n = n.parent;
      }

      stateApi.path = ["API", ...modelPath, "0.0.1", "draft"];
      // ignore: invalid_use_of_protected_member
      stateApi.keyBreadcrumb.currentState?.setState(() {});

      var key = attr.info.properties![constMasterID];
      currentCompany.currentAPI = ModelSchemaDetail(
        type: YamlType.api,
        infoManager: InfoManagerAPIParam(),
        name: attr.info.name,
        id: key,
      );
      currentCompany.listAPI!.currentAttr = attr;
      await currentCompany.currentAPI!.loadYamlAndProperties(cache: false);
      stateApi.tabApi.animateTo(1);
    }
  }

  Widget getStructureModel() {
    void onYamlChange(String yaml, TextConfig config) {
      if (currentCompany.listAPI!.modelYaml != yaml) {
        currentCompany.listAPI!.modelYaml = yaml;
        bddStorage.setItem('api', currentCompany.listAPI!.modelYaml);
        bool parseOk = false;
        try {
          currentCompany.listAPI!.mapModelYaml = loadYaml(
            currentCompany.listAPI!.modelYaml,
          );
          parseOk = true;
          config.notifError.value = '';
        } catch (e) {
          config.notifError.value = '$e';
        }

        if (parseOk) {
          // ignore: invalid_use_of_protected_member
          stateApi.keyListAPIInfo.currentState?.setState(() {});
        }
      }
    }

    getYaml() {
      return currentCompany.listAPI!.modelYaml;
    }

    return Container(
      color: Colors.black,
      child: TextEditor(
        header: "API routes",
        key: stateApi.keyListAPI,
        config: TextConfig(
          mode: yaml,
          notifError: notifierModelErrorYaml,
          onChange: onYamlChange,
          getText: getYaml,
        ),
      ),
    );
  }
}
