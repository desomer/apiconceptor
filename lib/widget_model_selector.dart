import 'package:flutter/material.dart';
import 'package:jsonschema/bdd/data_acces.dart';
import 'package:jsonschema/cell_editor.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/export/export2json_schema.dart';
import 'package:jsonschema/export/json_browser.dart';
import 'package:jsonschema/json_tree.dart';
import 'package:jsonschema/keepAlive.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/widget_model_helper.dart';
import 'package:jsonschema/widget_tab.dart';
import 'package:jsonschema/yaml_editor.dart';
import 'package:yaml/yaml.dart';

class WidgetModelSelector extends StatelessWidget with WidgetModelHelper {
  const WidgetModelSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return getBrowser(context);
  }

  Widget getBrowser(BuildContext context) {
    getJsonYaml() {
      return currentCompany.listModel!.modelYaml;
    }

    var model = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 300,
          height: double.infinity,
          child: getStructureModel(),
        ),
        Expanded(
          child: JsonEditor(
            key: keyListModelInfo,
            config:
                JsonTreeConfig(getModel: () => currentCompany.listModel!)
                  ..getJson = getJsonYaml
                  ..getRow = getWidgetModelInfo,
          ),
        ),
      ],
    );

    return WidgetTab(
      listTab: [Tab(text: 'Business Model'), Tab(text: 'Component')],
      listTabCont: [KeepAliveWidget(child: model), Container()],
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
        key: ValueKey('${attr.hashCode}#description'),
        info: attr.info,
        propName: 'description',
        schema: schema,
      ),
    );

    addWidgetMasterId(attr, row);

    if (attr.info.type == 'model') {
      row.add(
        TextButton.icon(
          onPressed: () async {
            await goToModel(attr);
          },
          label: Icon(Icons.remove_red_eye),
        ),
      );
      row.add(
        TextButton.icon(
          icon: Icon(Icons.import_export),
          onPressed: () async {
            if (attr.info.type == 'model') {
              var key = attr.info.properties![constMasterID];
              var model = ModelSchemaDetail(name: attr.info.name, id: key);
              await model.loadYamlAndProperties(cache: false);
              await ExportToJsonSchema().doExport(model);
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
          await goToModel(attr);
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

  Future<void> goToModel(NodeAttribut attr) async {
    if (attr.info.type == 'model') {
      var key = attr.info.properties![constMasterID];
      currentCompany.currentModel = ModelSchemaDetail(
        name: attr.info.name,
        id: key,
      );
      await currentCompany.currentModel!.loadYamlAndProperties(cache: false);
      tabModel.animateTo(1);
    }
  }

  Widget getStructureModel() {
    void onYamlChange(String yaml, YamlConfig config) {
      if (currentCompany.listModel!.modelYaml != yaml) {
        currentCompany.listModel!.modelYaml = yaml;
        localStorage.setItem('model', currentCompany.listModel!.modelYaml);
        bool parseOk = false;
        try {
          currentCompany.listModel!.mapModelYaml = loadYaml(
            currentCompany.listModel!.modelYaml,
          );
          parseOk = true;
        } catch (e) {
          //print(e);
        }

        if (parseOk) {
          // ignore: invalid_use_of_protected_member
          keyListModelInfo.currentState?.setState(() {});
        }
      }
    }

    getYaml() {
      return currentCompany.listModel!.modelYaml;
    }

    //currentCompany.currentModel = ModelSchemaDetail(name: attr.info.name, id: 'model');
    return Container(
      color: Colors.black,
      child: YamlEditor(
        key: keyListModel,
        config:
            YamlConfig()
              ..notifError = notifierModelErrorYaml
              ..onChange = onYamlChange
              ..getYaml = getYaml,
      ),
    );
  }
}
