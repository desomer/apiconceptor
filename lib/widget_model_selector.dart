import 'package:flutter/material.dart';
import 'package:jsonschema/cell_editor.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/json_tree.dart';
import 'package:jsonschema/keepAlive.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/widget_model_helper.dart';
import 'package:jsonschema/widget_tab.dart';
import 'package:jsonschema/yaml_editor.dart';
import 'package:localstorage/localstorage.dart';
import 'package:yaml/yaml.dart';

class WidgetModelSelector extends StatelessWidget with WidgetModelHelper {
  const WidgetModelSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return getBrowser();
  }

  Widget getBrowser() {
    getJsonYaml() {
      return currentCompany.mapListModelYaml;
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

    row.add(
      TextButton.icon(onPressed: () {}, label: Icon(Icons.remove_red_eye)),
    );

    addWidgetMasterId(attr, row);

    attr.cache = SizedBox(
      height: rowHeight,
      child: InkWell(
        onDoubleTap: () {
          if (attr.info.type == 'model') {
            var key = attr.info.properties![constMasterID];
            currentCompany.currentModel = ModelSchemaDetail(name: attr.info.name, id: key);
            currentCompany.currentModel!.load();
            // // ignore: invalid_use_of_protected_member
            // keyModelEditor.currentState?.setState(() {});
            // keyModelInfo.currentState?.setState(() {});

            tabModel.animateTo(1);
          }
        },
        child: Card(
          key: ObjectKey(attr),
          margin: EdgeInsets.all(1),
          child: Row(children: row),
        ),
      ),
    );
    return attr.cache!;
  }

  Widget getStructureModel() {
    void onYamlChange(String yaml, YamlConfig config) {
      if (currentCompany.listModelYaml != yaml) {
        currentCompany.listModelYaml = yaml;
        localStorage.setItem('model', currentCompany.listModelYaml);
        bool parseOk = false;
        try {
          currentCompany.mapListModelYaml = loadYaml(
            currentCompany.listModelYaml,
          );
          parseOk = true;
        } catch (e) {
          print(e);
        }

        if (parseOk) {
          // ignore: invalid_use_of_protected_member
          keyListModelInfo.currentState?.setState(() {});
        }
      }
    }

    getYaml() {
      return currentCompany.listModelYaml;
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
